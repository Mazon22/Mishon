import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';

enum AppBootstrapPhase {
  idle,
  initializingServices,
  checkingConnectivity,
  preloadingCachedData,
  preloadingRemoteData,
  ready,
  offlineReady,
  failed,
}

@immutable
class AppBootstrapState {
  final AppBootstrapPhase phase;
  final bool isAuthenticated;
  final bool hasConnection;
  final int? userId;
  final String? errorMessage;
  final DateTime? lastRemoteSyncAt;

  const AppBootstrapState({
    required this.phase,
    required this.isAuthenticated,
    required this.hasConnection,
    required this.userId,
    this.errorMessage,
    this.lastRemoteSyncAt,
  });

  const AppBootstrapState.initial()
    : phase = AppBootstrapPhase.idle,
      isAuthenticated = false,
      hasConnection = false,
      userId = null,
      errorMessage = null,
      lastRemoteSyncAt = null;

  bool get isReady =>
      phase == AppBootstrapPhase.ready ||
      phase == AppBootstrapPhase.offlineReady ||
      phase == AppBootstrapPhase.failed;

  bool get allowsInteraction => isReady;

  AppBootstrapState copyWith({
    AppBootstrapPhase? phase,
    bool? isAuthenticated,
    bool? hasConnection,
    Object? userId = _userIdSentinel,
    Object? errorMessage = _errorSentinel,
    DateTime? lastRemoteSyncAt,
  }) {
    return AppBootstrapState(
      phase: phase ?? this.phase,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasConnection: hasConnection ?? this.hasConnection,
      userId: identical(userId, _userIdSentinel) ? this.userId : userId as int?,
      errorMessage:
          identical(errorMessage, _errorSentinel)
              ? this.errorMessage
              : errorMessage as String?,
      lastRemoteSyncAt: lastRemoteSyncAt ?? this.lastRemoteSyncAt,
    );
  }
}

const _errorSentinel = Object();
const _userIdSentinel = Object();

final appBootstrapProvider =
    NotifierProvider<AppBootstrapNotifier, AppBootstrapState>(
      AppBootstrapNotifier.new,
    );

final currentUserIdProvider = Provider<int?>((ref) {
  return ref.watch(appBootstrapProvider.select((state) => state.userId));
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(
    appBootstrapProvider.select((state) => state.isAuthenticated),
  );
});

class AppBootstrapNotifier extends Notifier<AppBootstrapState> {
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<Object>? _connectivitySubscription;
  bool _isBootstrapping = false;
  bool _didStart = false;

  @override
  AppBootstrapState build() {
    ref.onDispose(() {
      _connectivitySubscription?.cancel();
    });

    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );

    if (!_didStart) {
      _didStart = true;
      Future<void>.microtask(bootstrap);
    }

    return const AppBootstrapState.initial();
  }

  Future<void> bootstrap() async {
    if (_isBootstrapping) {
      return;
    }

    _isBootstrapping = true;
    state = state.copyWith(
      phase: AppBootstrapPhase.initializingServices,
      errorMessage: null,
    );

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final storage = ref.read(storageProvider);

      await storage.warmup();
      final session = await authRepository.restoreSession();

      state = state.copyWith(
        phase: AppBootstrapPhase.checkingConnectivity,
        isAuthenticated: session.isAuthenticated,
        userId: session.userId,
      );

      final hasConnection = await _hasConnection();
      state = state.copyWith(
        phase: AppBootstrapPhase.preloadingCachedData,
        hasConnection: hasConnection,
      );

      if (!session.isAuthenticated) {
        state = state.copyWith(
          phase:
              hasConnection
                  ? AppBootstrapPhase.ready
                  : AppBootstrapPhase.offlineReady,
          isAuthenticated: false,
          userId: null,
        );
        return;
      }

      if (!hasConnection) {
        state = state.copyWith(
          phase: AppBootstrapPhase.offlineReady,
          errorMessage: null,
        );
        return;
      }

      await _preloadRemoteData(session.userId);
      state = state.copyWith(
        phase: AppBootstrapPhase.ready,
        hasConnection: true,
        lastRemoteSyncAt: DateTime.now(),
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        phase: AppBootstrapPhase.failed,
        errorMessage: error.toString(),
      );
    } finally {
      _isBootstrapping = false;
    }
  }

  Future<void> refreshRemoteData({bool allowOffline = true}) async {
    if (_isBootstrapping || !state.isAuthenticated) {
      return;
    }

    final hasConnection = await _hasConnection();
    state = state.copyWith(hasConnection: hasConnection);
    if (!hasConnection) {
      if (allowOffline) {
        state = state.copyWith(phase: AppBootstrapPhase.offlineReady);
      }
      return;
    }

    _isBootstrapping = true;
    final previousPhase = state.phase;
    state = state.copyWith(
      phase: AppBootstrapPhase.preloadingRemoteData,
      errorMessage: null,
    );

    try {
      await _preloadRemoteData(state.userId);
      state = state.copyWith(
        phase: AppBootstrapPhase.ready,
        hasConnection: true,
        lastRemoteSyncAt: DateTime.now(),
      );
    } catch (error) {
      state = state.copyWith(
        phase:
            previousPhase == AppBootstrapPhase.offlineReady
                ? AppBootstrapPhase.offlineReady
                : AppBootstrapPhase.ready,
        errorMessage: error.toString(),
      );
    } finally {
      _isBootstrapping = false;
    }
  }

  Future<void> handleAuthenticatedSession() async {
    await bootstrap();
  }

  void handleLoggedOut() {
    state = state.copyWith(
      phase:
          state.hasConnection
              ? AppBootstrapPhase.ready
              : AppBootstrapPhase.offlineReady,
      isAuthenticated: false,
      userId: null,
      errorMessage: null,
    );
  }

  Future<void> _preloadRemoteData(int? userId) async {
    final postRepository = ref.read(postRepositoryProvider);
    final socialRepository = ref.read(socialRepositoryProvider);
    final authRepository = ref.read(authRepositoryProvider);

    state = state.copyWith(phase: AppBootstrapPhase.preloadingRemoteData);

    await Future.wait<Object?>([
      authRepository.prefetchProfile(),
      postRepository.prefetchFeed(pageSize: 20),
      postRepository.prefetchFollowingFeed(pageSize: 20),
      socialRepository.prefetchDiscovery(limit: 48),
      socialRepository.prefetchFriendsBundle(),
      socialRepository.prefetchConversations(),
      ref.read(notificationSummaryProvider.notifier).refresh(silent: true),
      if (userId != null)
        postRepository.getUserPosts(userId, forceRefresh: true),
    ]);
  }

  Future<bool> _hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return _isConnected(result);
  }

  void _handleConnectivityChanged(Object result) {
    final hasConnection = _isConnected(result);
    if (state.hasConnection == hasConnection) {
      return;
    }

    state = state.copyWith(hasConnection: hasConnection);
    if (!hasConnection) {
      if (state.isReady) {
        state = state.copyWith(phase: AppBootstrapPhase.offlineReady);
      }
      return;
    }

    if (state.isAuthenticated) {
      unawaited(refreshRemoteData());
      return;
    }

    if (state.phase == AppBootstrapPhase.offlineReady) {
      state = state.copyWith(phase: AppBootstrapPhase.ready);
    }
  }

  bool _isConnected(Object result) {
    if (result is List<ConnectivityResult>) {
      return result.any((item) => item != ConnectivityResult.none);
    }

    return result != ConnectivityResult.none;
  }
}

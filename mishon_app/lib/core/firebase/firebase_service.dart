import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/storage/secure_storage.dart';
import 'package:mishon_app/core/utils/device_metadata.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) {
    return;
  }
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore initialization issues in background. Foreground app flow will recover.
  }
}

class PushRouteIntent {
  final String location;

  const PushRouteIntent(this.location);
}

PushRouteIntent? mapPushDataToIntent(Map<String, Object?> data) {
  final conversationId = _tryParsePushInt(data['conversationId'] ?? data['chatId']);
  if (conversationId != null) {
    final peerId = _tryParsePushInt(
      data['peerId'] ?? data['actorUserId'] ?? data['relatedUserId'],
    );
    final username =
        data['actorUsername']?.toString() ??
        data['username']?.toString() ??
        data['title']?.toString();
    final params = <String, String>{
      if (peerId != null) 'peerId': '$peerId',
      if (username != null && username.isNotEmpty) 'username': username,
    };
    final query =
        params.isEmpty
            ? ''
            : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return PushRouteIntent('/chat/$conversationId$query');
  }

  final profileUserId = _tryParsePushInt(
    data['profileUserId'] ?? data['userId'] ?? data['relatedUserId'],
  );
  final type = data['type']?.toString().toLowerCase();
  if (type == 'follow_request') {
    return const PushRouteIntent('/follow-requests');
  }
  if (profileUserId != null &&
      (type == 'friend_request' || type == 'profile')) {
    return PushRouteIntent('/profile/$profileUserId');
  }

  final postId = _tryParsePushInt(data['postId']);
  final postUserId = _tryParsePushInt(data['postUserId']);
  if (postId != null && postUserId != null) {
    return PushRouteIntent('/comments/$postId?postUserId=$postUserId');
  }

  if (type != null &&
      (type.contains('moderation') || type.contains('security'))) {
    return const PushRouteIntent('/moderation');
  }

  if (profileUserId != null) {
    return PushRouteIntent('/profile/$profileUserId');
  }

  return const PushRouteIntent('/notifications');
}

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  final service = FirebaseService(
    storage: ref.watch(storageProvider),
    socialRepository: ref.watch(socialRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final pushRouteIntentProvider = StreamProvider<PushRouteIntent>((ref) {
  return ref.watch(firebaseServiceProvider).routeIntents;
});

class FirebaseService {
  FirebaseService({
    required this.storage,
    required this.socialRepository,
  });

  final SecureStorage storage;
  final SocialRepository socialRepository;
  final _logger = Logger();
  final StreamController<PushRouteIntent> _routeIntentController =
      StreamController<PushRouteIntent>.broadcast();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  bool _initialized = false;
  bool _available = false;

  Stream<PushRouteIntent> get routeIntents => _routeIntentController.stream;

  bool get isAvailable => _available;

  static bool get hasWebFirebaseOptions {
    if (!kIsWeb) {
      return true;
    }

    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

    return apiKey.isNotEmpty &&
        appId.isNotEmpty &&
        messagingSenderId.isNotEmpty &&
        projectId.isNotEmpty;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (kIsWeb && !hasWebFirebaseOptions) {
      _initialized = true;
      _available = false;
      _logger.i('Firebase web config is missing; push is disabled.');
      return;
    }

    try {
      if (kIsWeb) {
        final options = _tryLoadWebFirebaseOptions();
        if (options == null) {
          _available = false;
          _logger.i('Firebase web config is missing; push is disabled.');
          return;
        }
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
      _available = true;
    } catch (error, stackTrace) {
      _available = false;
      _logger.w(
        'Firebase initialization skipped',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _initialized = true;

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    final messaging = FirebaseMessaging.instance;
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      _logger.i('Foreground push received: ${message.messageId}');
      unawaited(socialRepository.getNotificationSummary(forceRefresh: true));
    });
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }

    await syncTokenIfPossible();
  }

  Future<AuthorizationStatus> requestPermission() async {
    if (!_available) {
      return AuthorizationStatus.notDetermined;
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await syncTokenIfPossible();
    return settings.authorizationStatus;
  }

  Future<void> syncTokenIfPossible() async {
    if (!_available) {
      return;
    }

    await storage.warmup();
    final jwt = storage.cachedToken;
    final userId = storage.cachedUserId;
    if (jwt == null || jwt.isEmpty || userId == null) {
      return;
    }

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await _registerToken(token);
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _routeIntentController.close();
  }

  Future<void> _registerToken(String token) async {
    try {
      final metadata = await resolveDeviceMetadata(storage);
      await socialRepository.registerPushToken(
        deviceId: metadata.deviceId,
        token: token,
        platform: metadata.platform,
        deviceName: metadata.deviceName,
      );
      _logger.i('Push token registered');
    } catch (error, stackTrace) {
      _logger.w(
        'Push token registration failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final intent = mapPushDataToIntent(message.data);
    if (intent == null || _routeIntentController.isClosed) {
      return;
    }
    _routeIntentController.add(intent);
  }

  FirebaseOptions? _tryLoadWebFirebaseOptions() {
    if (!hasWebFirebaseOptions) {
      return null;
    }

    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
    const databaseURL = String.fromEnvironment('FIREBASE_DATABASE_URL');

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
      databaseURL: databaseURL.isEmpty ? null : databaseURL,
    );
  }
}

int? _tryParsePushInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

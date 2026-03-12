import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/features/chats/providers/chat_realtime_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_messages_provider.g.dart';

const _errorSentinel = Object();
const _cursorSentinel = Object();

@immutable
class ChatMessagesState {
  final List<ChatMessageModel> messages;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingOlder;
  final bool hasMoreOlder;
  final bool hasLoadedOnce;
  final bool isPeerTyping;
  final String? errorMessage;
  final int? nextBeforeMessageId;

  const ChatMessagesState({
    required this.messages,
    required this.isInitialLoading,
    required this.isRefreshing,
    required this.isLoadingOlder,
    required this.hasMoreOlder,
    required this.hasLoadedOnce,
    required this.isPeerTyping,
    required this.errorMessage,
    required this.nextBeforeMessageId,
  });

  const ChatMessagesState.initial()
    : messages = const [],
      isInitialLoading = true,
      isRefreshing = false,
      isLoadingOlder = false,
      hasMoreOlder = false,
      hasLoadedOnce = false,
      isPeerTyping = false,
      errorMessage = null,
      nextBeforeMessageId = null;

  ChatMessagesState copyWith({
    List<ChatMessageModel>? messages,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingOlder,
    bool? hasMoreOlder,
    bool? hasLoadedOnce,
    bool? isPeerTyping,
    Object? errorMessage = _errorSentinel,
    Object? nextBeforeMessageId = _cursorSentinel,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      isPeerTyping: isPeerTyping ?? this.isPeerTyping,
      errorMessage:
          identical(errorMessage, _errorSentinel)
              ? this.errorMessage
              : errorMessage as String?,
      nextBeforeMessageId:
          identical(nextBeforeMessageId, _cursorSentinel)
              ? this.nextBeforeMessageId
              : nextBeforeMessageId as int?,
    );
  }
}

@riverpod
class ChatMessagesNotifier extends _$ChatMessagesNotifier {
  static const int _pageSize = 20;

  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;
  Timer? _typingExpiryTimer;
  bool _liveUpdatesEnabled = true;

  @override
  ChatMessagesState build(int conversationId) {
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
      _typingExpiryTimer?.cancel();
    });

    _subscribeToRealtime();
    Future<void>.microtask(() async {
      await ref.read(chatRealtimeServiceProvider).ensureConnected();
      await _loadInitialPage();
    });

    return const ChatMessagesState.initial();
  }

  Future<void> ensureLoaded() async {
    if (state.hasLoadedOnce || state.isInitialLoading) {
      return;
    }

    await _loadInitialPage();
  }

  Future<void> refresh({bool silent = false, bool force = false}) async {
    if (!force && state.isLoadingOlder) {
      return;
    }

    if (!state.hasLoadedOnce && !state.isInitialLoading) {
      await _loadInitialPage();
      return;
    }

    if (state.isRefreshing || state.isInitialLoading) {
      return;
    }

    if (!silent) {
      state = state.copyWith(isRefreshing: true, errorMessage: null);
    }

    try {
      final page = await ref
          .read(socialRepositoryProvider)
          .getMessages(conversationId, limit: _pageSize);
      final mergedMessages = _mergeLatestPage(page.items, state.messages);
      state = state.copyWith(
        messages: mergedMessages,
        isInitialLoading: false,
        isRefreshing: false,
        hasLoadedOnce: true,
        hasMoreOlder:
            state.messages.length > page.items.length
                ? state.hasMoreOlder
                : page.hasMore,
        nextBeforeMessageId:
            mergedMessages.isNotEmpty ? mergedMessages.last.id : null,
        errorMessage: null,
      );
    } on ApiException catch (e) {
      _handleRefreshError(e.apiError.message, silent: silent);
    } on OfflineException catch (e) {
      _handleRefreshError(e.message, silent: silent);
    } catch (_) {
      _handleRefreshError('Failed to load messages.', silent: silent);
    }
  }

  Future<void> loadOlder() async {
    if (state.isInitialLoading ||
        state.isLoadingOlder ||
        !state.hasMoreOlder ||
        state.messages.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingOlder: true, errorMessage: null);

    try {
      final page = await ref
          .read(socialRepositoryProvider)
          .getMessages(
            conversationId,
            limit: _pageSize,
            beforeMessageId: state.nextBeforeMessageId ?? state.messages.last.id,
          );
      final existingIds = state.messages.map((message) => message.id).toSet();
      final olderMessages = page.items
          .where((message) => !existingIds.contains(message.id))
          .toList(growable: false);
      final mergedMessages = [...state.messages, ...olderMessages];
      state = state.copyWith(
        messages: mergedMessages,
        isLoadingOlder: false,
        hasLoadedOnce: true,
        hasMoreOlder: page.hasMore,
        nextBeforeMessageId:
            mergedMessages.isNotEmpty ? mergedMessages.last.id : null,
        errorMessage: null,
      );
    } on ApiException catch (e) {
      _handleLoadOlderError(e.apiError.message);
    } on OfflineException catch (e) {
      _handleLoadOlderError(e.message);
    } catch (_) {
      _handleLoadOlderError('Failed to load older messages.');
    }
  }

  void setLiveUpdatesEnabled(bool enabled) {
    if (_liveUpdatesEnabled == enabled) {
      return;
    }

    _liveUpdatesEnabled = enabled;
    if (enabled) {
      unawaited(refresh(silent: true, force: true));
    }
  }

  void upsertMessage(ChatMessageModel message) {
    final mergedMessages = _mergeLatestPage([message], state.messages);
    state = state.copyWith(
      messages: mergedMessages,
      isInitialLoading: false,
      isRefreshing: false,
      hasLoadedOnce: true,
      isPeerTyping: message.isMine ? state.isPeerTyping : false,
      errorMessage: null,
      nextBeforeMessageId:
          mergedMessages.isNotEmpty ? mergedMessages.last.id : null,
    );
  }

  void removeMessage(int messageId) {
    final filteredMessages = state.messages
        .where((message) => message.id != messageId)
        .toList(growable: false);
    state = state.copyWith(
      messages: filteredMessages,
      nextBeforeMessageId:
          filteredMessages.isNotEmpty ? filteredMessages.last.id : null,
    );
  }

  void clearHistory() {
    state = state.copyWith(
      messages: const [],
      isInitialLoading: false,
      isRefreshing: false,
      isLoadingOlder: false,
      hasLoadedOnce: true,
      hasMoreOlder: false,
      isPeerTyping: false,
      nextBeforeMessageId: null,
      errorMessage: null,
    );
  }

  void markMessageDelivered(int messageId, DateTime deliveredAt) {
    final updatedMessages = state.messages
        .map(
          (message) => message.id == messageId
              ? message.copyWith(
                  isDeliveredToPeer: true,
                  deliveredToPeerAt: deliveredAt,
                )
              : message,
        )
        .toList(growable: false);
    state = state.copyWith(messages: updatedMessages);
  }

  void markConversationRead(DateTime readAt) {
    final updatedMessages = state.messages
        .map(
          (message) =>
              message.isMine && !message.isReadByPeer && !message.createdAt.isAfter(readAt)
              ? message.copyWith(
                  isDeliveredToPeer: true,
                  deliveredToPeerAt: readAt,
                  isReadByPeer: true,
                  readByPeerAt: readAt,
                )
              : message,
        )
        .toList(growable: false);
    state = state.copyWith(messages: updatedMessages);
  }

  Future<void> _loadInitialPage() async {
    if (state.hasLoadedOnce || !state.isInitialLoading) {
      return;
    }

    try {
      final page = await ref
          .read(socialRepositoryProvider)
          .getMessages(conversationId, limit: _pageSize);
      state = state.copyWith(
        messages: page.items,
        isInitialLoading: false,
        isRefreshing: false,
        isLoadingOlder: false,
        hasMoreOlder: page.hasMore,
        hasLoadedOnce: true,
        nextBeforeMessageId:
            page.items.isNotEmpty ? page.items.last.id : null,
        errorMessage: null,
      );
    } on ApiException catch (e) {
      _handleInitialLoadError(e.apiError.message);
    } on OfflineException catch (e) {
      _handleInitialLoadError(e.message);
    } catch (_) {
      _handleInitialLoadError('Failed to load messages.');
    }
  }

  void _subscribeToRealtime() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = ref
        .read(chatRealtimeServiceProvider)
        .events
        .listen(_handleRealtimeEvent);
  }

  void _handleRealtimeEvent(ChatRealtimeEvent event) {
    if (event.conversationId != conversationId) {
      return;
    }

    if (event is ChatTypingStartedRealtimeEvent) {
      _typingExpiryTimer?.cancel();
      _typingExpiryTimer = Timer(const Duration(seconds: 3), _clearPeerTyping);
      state = state.copyWith(isPeerTyping: true);
      return;
    }

    if (event is ChatTypingStoppedRealtimeEvent) {
      _clearPeerTyping();
      return;
    }

    if (event is ChatMessageSentRealtimeEvent) {
      upsertMessage(event.message);
      return;
    }

    if (event is ChatMessageDeliveredRealtimeEvent) {
      markMessageDelivered(
        event.payload.messageId,
        event.payload.deliveredAt,
      );
      return;
    }

    if (event is ChatMessageReadRealtimeEvent) {
      markConversationRead(event.payload.readAt);
    }
  }

  void _clearPeerTyping() {
    _typingExpiryTimer?.cancel();
    _typingExpiryTimer = null;
    if (state.isPeerTyping) {
      state = state.copyWith(isPeerTyping: false);
    }
  }

  List<ChatMessageModel> _mergeLatestPage(
    List<ChatMessageModel> latestPage,
    List<ChatMessageModel> cachedMessages,
  ) {
    final seenIds = <int>{};
    final mergedMessages = <ChatMessageModel>[];

    for (final message in [...latestPage, ...cachedMessages]) {
      if (seenIds.add(message.id)) {
        mergedMessages.add(message);
      }
    }

    mergedMessages.sort((left, right) => right.id.compareTo(left.id));
    return mergedMessages;
  }

  void _handleInitialLoadError(Object error) {
    state = state.copyWith(
      isInitialLoading: false,
      isRefreshing: false,
      isLoadingOlder: false,
      hasLoadedOnce: false,
      errorMessage: error.toString(),
      nextBeforeMessageId: null,
    );
  }

  void _handleRefreshError(Object error, {required bool silent}) {
    if (silent) {
      state = state.copyWith(isRefreshing: false);
      return;
    }

    state = state.copyWith(
      isInitialLoading: false,
      isRefreshing: false,
      errorMessage: error.toString(),
    );
  }

  void _handleLoadOlderError(Object error) {
    state = state.copyWith(
      isLoadingOlder: false,
      errorMessage:
          state.messages.isEmpty ? error.toString() : state.errorMessage,
    );
  }
}

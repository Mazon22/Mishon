import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/sync/live_sync_service.dart';

final chatRealtimeServiceProvider = Provider<ChatRealtimeService>((ref) {
  final service = ChatRealtimeService(
    socialRepository: ref.watch(socialRepositoryProvider),
    liveSyncService: ref.watch(liveSyncServiceProvider),
  );
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

sealed class ChatRealtimeEvent {
  final int conversationId;

  const ChatRealtimeEvent(this.conversationId);
}

class ChatTypingStartedRealtimeEvent extends ChatRealtimeEvent {
  final ChatTypingEventModel payload;

  ChatTypingStartedRealtimeEvent(this.payload) : super(payload.conversationId);
}

class ChatTypingStoppedRealtimeEvent extends ChatRealtimeEvent {
  final ChatTypingEventModel payload;

  ChatTypingStoppedRealtimeEvent(this.payload) : super(payload.conversationId);
}

class ChatMessageSentRealtimeEvent extends ChatRealtimeEvent {
  final ChatMessageModel message;

  ChatMessageSentRealtimeEvent(this.message) : super(message.conversationId);
}

class ChatMessageDeletedRealtimeEvent extends ChatRealtimeEvent {
  final int messageId;
  final bool deleteForAll;

  ChatMessageDeletedRealtimeEvent({
    required int conversationId,
    required this.messageId,
    required this.deleteForAll,
  }) : super(conversationId);
}

class ChatHistoryClearedRealtimeEvent extends ChatRealtimeEvent {
  ChatHistoryClearedRealtimeEvent(super.conversationId);
}

class ChatMessageReadRealtimeEvent extends ChatRealtimeEvent {
  final ChatMessageReadEventModel payload;

  ChatMessageReadRealtimeEvent(this.payload) : super(payload.conversationId);
}

class ChatMessageDeliveredRealtimeEvent extends ChatRealtimeEvent {
  final ChatMessageDeliveredEventModel payload;

  ChatMessageDeliveredRealtimeEvent(this.payload)
    : super(payload.conversationId);
}

class ChatRealtimeService {
  ChatRealtimeService({
    required SocialRepository socialRepository,
    required LiveSyncService liveSyncService,
  }) : _socialRepository = socialRepository,
       _liveSyncService = liveSyncService {
    _statusSubscription = _liveSyncService.statuses.listen(_handleStatus);
    _liveSyncSubscription = _liveSyncService.events.listen(_handleLiveSyncEvent);
  }

  final SocialRepository _socialRepository;
  final LiveSyncService _liveSyncService;
  final StreamController<ChatRealtimeEvent> _eventsController =
      StreamController<ChatRealtimeEvent>.broadcast();
  final StreamController<HubConnectionState> _connectionStatesController =
      StreamController<HubConnectionState>.broadcast();
  final Map<int, DateTime> _lastTypingStartSentAt = <int, DateTime>{};
  final Map<int, Timer> _typingStopTimers = <int, Timer>{};
  final Set<int> _activeTypingConversations = <int>{};

  StreamSubscription<LiveSyncEvent>? _liveSyncSubscription;
  StreamSubscription<LiveSyncStatus>? _statusSubscription;
  bool _disposed = false;

  Stream<ChatRealtimeEvent> get events => _eventsController.stream;
  Stream<HubConnectionState> get connectionStates =>
      _connectionStatesController.stream;

  Future<void> ensureConnected() async {
    if (_disposed) {
      return;
    }

    await _liveSyncService.ensureConnected();
  }

  Future<void> reportTypingActivity(
    int conversationId, {
    required bool isComposing,
  }) async {
    if (_disposed) {
      return;
    }

    if (!isComposing) {
      await stopTyping(conversationId);
      return;
    }

    await ensureConnected();

    final now = DateTime.now();
    final lastSentAt = _lastTypingStartSentAt[conversationId];
    if (!_activeTypingConversations.contains(conversationId) ||
        lastSentAt == null ||
        now.difference(lastSentAt) >= const Duration(seconds: 2)) {
      _activeTypingConversations.add(conversationId);
      _lastTypingStartSentAt[conversationId] = now;
      unawaited(_safeTypingStart(conversationId));
    }

    _typingStopTimers.remove(conversationId)?.cancel();
    _typingStopTimers[conversationId] = Timer(const Duration(seconds: 3), () {
      unawaited(stopTyping(conversationId));
    });
  }

  Future<void> stopTyping(int conversationId) async {
    _typingStopTimers.remove(conversationId)?.cancel();
    _lastTypingStartSentAt.remove(conversationId);
    if (!_activeTypingConversations.remove(conversationId)) {
      return;
    }

    try {
      await _socialRepository.sendTypingStop(conversationId);
    } catch (_) {
      // Best-effort realtime hint.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final timer in _typingStopTimers.values) {
      timer.cancel();
    }
    _typingStopTimers.clear();
    _activeTypingConversations.clear();
    _lastTypingStartSentAt.clear();
    await _liveSyncSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _eventsController.close();
    await _connectionStatesController.close();
  }

  Future<void> _safeTypingStart(int conversationId) async {
    try {
      await _socialRepository.sendTypingStart(conversationId);
    } catch (_) {
      // Best-effort realtime hint.
    }
  }

  void _handleStatus(LiveSyncStatus status) {
    if (_disposed) {
      return;
    }

    final mapped = switch (status) {
      LiveSyncStatus.idle => HubConnectionState.Disconnected,
      LiveSyncStatus.connecting => HubConnectionState.Connecting,
      LiveSyncStatus.connected => HubConnectionState.Connected,
      LiveSyncStatus.reconnecting => HubConnectionState.Reconnecting,
      LiveSyncStatus.error => HubConnectionState.Reconnecting,
    };
    _connectionStatesController.add(mapped);
  }

  void _handleLiveSyncEvent(LiveSyncEvent event) {
    if (_disposed) {
      return;
    }

    final data = event.data;
    switch (event.type) {
      case 'chat.typing.started':
        _eventsController.add(
          ChatTypingStartedRealtimeEvent(
            ChatTypingEventModel(
              conversationId: data['conversationId'] as int? ?? 0,
              userId: data['userId'] as int? ?? 0,
              sentAt: event.occurredAt,
            ),
          ),
        );
        return;
      case 'chat.typing.stopped':
        _eventsController.add(
          ChatTypingStoppedRealtimeEvent(
            ChatTypingEventModel(
              conversationId: data['conversationId'] as int? ?? 0,
              userId: data['userId'] as int? ?? 0,
              sentAt: event.occurredAt,
            ),
          ),
        );
        return;
      case 'chat.message.created':
      case 'chat.message.updated':
        final messageData = data['message'];
        if (messageData is Map<String, dynamic>) {
          _eventsController.add(
            ChatMessageSentRealtimeEvent(
              ChatMessageModel.fromJson(messageData),
            ),
          );
        }
        return;
      case 'chat.message.deleted':
        _eventsController.add(
          ChatMessageDeletedRealtimeEvent(
            conversationId: data['conversationId'] as int? ?? 0,
            messageId: data['messageId'] as int? ?? 0,
            deleteForAll: data['deleteForAll'] as bool? ?? false,
          ),
        );
        return;
      case 'chat.message.delivered':
        _eventsController.add(
          ChatMessageDeliveredRealtimeEvent(
            ChatMessageDeliveredEventModel.fromJson(data),
          ),
        );
        return;
      case 'chat.message.read':
        _eventsController.add(
          ChatMessageReadRealtimeEvent(
            ChatMessageReadEventModel.fromJson(data),
          ),
        );
        return;
      case 'chat.history.cleared':
        _eventsController.add(
          ChatHistoryClearedRealtimeEvent(
            data['conversationId'] as int? ?? 0,
          ),
        );
        return;
    }
  }
}

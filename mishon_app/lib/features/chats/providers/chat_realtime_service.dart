import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'package:mishon_app/core/constants/api_constants.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/storage/secure_storage.dart';

final chatRealtimeServiceProvider = Provider<ChatRealtimeService>((ref) {
  final service = ChatRealtimeService(
    storage: ref.watch(storageProvider),
    socialRepository: ref.watch(socialRepositoryProvider),
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

  ChatTypingStartedRealtimeEvent(this.payload)
    : super(payload.conversationId);
}

class ChatTypingStoppedRealtimeEvent extends ChatRealtimeEvent {
  final ChatTypingEventModel payload;

  ChatTypingStoppedRealtimeEvent(this.payload)
    : super(payload.conversationId);
}

class ChatMessageSentRealtimeEvent extends ChatRealtimeEvent {
  final ChatMessageModel message;

  ChatMessageSentRealtimeEvent(this.message) : super(message.conversationId);
}

class ChatMessageReadRealtimeEvent extends ChatRealtimeEvent {
  final ChatMessageReadEventModel payload;

  ChatMessageReadRealtimeEvent(this.payload)
    : super(payload.conversationId);
}

class ChatMessageDeliveredRealtimeEvent extends ChatRealtimeEvent {
  final ChatMessageDeliveredEventModel payload;

  ChatMessageDeliveredRealtimeEvent(this.payload)
    : super(payload.conversationId);
}

class ChatRealtimeService {
  ChatRealtimeService({
    required SecureStorage storage,
    required SocialRepository socialRepository,
  }) : _storage = storage,
       _socialRepository = socialRepository;

  final SecureStorage _storage;
  final SocialRepository _socialRepository;
  final StreamController<ChatRealtimeEvent> _eventsController =
      StreamController<ChatRealtimeEvent>.broadcast();
  final StreamController<HubConnectionState> _connectionStatesController =
      StreamController<HubConnectionState>.broadcast();
  final Map<int, DateTime> _lastTypingStartSentAt = <int, DateTime>{};
  final Map<int, Timer> _typingStopTimers = <int, Timer>{};
  final Set<int> _activeTypingConversations = <int>{};

  HubConnection? _connection;
  Future<void>? _startOperation;
  bool _disposed = false;

  Stream<ChatRealtimeEvent> get events => _eventsController.stream;
  Stream<HubConnectionState> get connectionStates =>
      _connectionStatesController.stream;

  Future<void> ensureConnected() async {
    if (_disposed) {
      return;
    }

    final state = _connection?.state;
    if (state == HubConnectionState.Connected ||
        state == HubConnectionState.Connecting ||
        state == HubConnectionState.Reconnecting) {
      return _startOperation ?? Future<void>.value();
    }

    _startOperation ??= _startConnection();
    try {
      await _startOperation;
    } finally {
      _startOperation = null;
    }
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
    final connection = _connection;
    _connection = null;
    if (connection != null && !kIsWeb) {
      try {
        await connection.stop();
      } catch (_) {
        // Best-effort shutdown.
      }
    }
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

  Future<void> _startConnection() async {
    final connection = _connection ??= _buildConnection();
    final state = connection.state;
    if (state == HubConnectionState.Connected ||
        state == HubConnectionState.Connecting) {
      return;
    }

    await connection.start();
    _connectionStatesController.add(connection.state ?? HubConnectionState.Connected);
  }

  HubConnection _buildConnection() {
    final connection = HubConnectionBuilder()
        .withUrl(
          _buildHubUrl(),
          options: HttpConnectionOptions(
            accessTokenFactory: () async => await _storage.readToken() ?? '',
            transport:
                kIsWeb
                    ? HttpTransportType.LongPolling
                    : HttpTransportType.WebSockets,
          ),
        )
        .withAutomaticReconnect()
        .build();

    connection.on('typing_started', _handleTypingStarted);
    connection.on('typing_stopped', _handleTypingStopped);
    connection.on('message_sent', _handleMessageSent);
    connection.on('message_read', _handleMessageRead);
    connection.on('message_delivered', _handleMessageDelivered);
    connection.onclose(({
      Object? error,
    }) {
      if (_disposed) {
        return;
      }
      _connectionStatesController.add(HubConnectionState.Disconnected);
    });
    connection.onreconnecting(({
      Object? error,
    }) {
      if (_disposed) {
        return;
      }
      _connectionStatesController.add(HubConnectionState.Reconnecting);
    });
    connection.onreconnected(({
      String? connectionId,
    }) {
      if (_disposed) {
        return;
      }
      _connectionStatesController.add(HubConnectionState.Connected);
    });

    return connection;
  }

  void _handleTypingStarted(List<Object?>? arguments) {
    final payload = _decodePayload(arguments);
    if (payload == null) {
      return;
    }

    _eventsController.add(
      ChatTypingStartedRealtimeEvent(ChatTypingEventModel.fromJson(payload)),
    );
  }

  void _handleTypingStopped(List<Object?>? arguments) {
    final payload = _decodePayload(arguments);
    if (payload == null) {
      return;
    }

    _eventsController.add(
      ChatTypingStoppedRealtimeEvent(ChatTypingEventModel.fromJson(payload)),
    );
  }

  void _handleMessageSent(List<Object?>? arguments) {
    final payload = _decodePayload(arguments);
    if (payload == null) {
      return;
    }

    _eventsController.add(
      ChatMessageSentRealtimeEvent(ChatMessageModel.fromJson(payload)),
    );
  }

  void _handleMessageRead(List<Object?>? arguments) {
    final payload = _decodePayload(arguments);
    if (payload == null) {
      return;
    }

    _eventsController.add(
      ChatMessageReadRealtimeEvent(ChatMessageReadEventModel.fromJson(payload)),
    );
  }

  void _handleMessageDelivered(List<Object?>? arguments) {
    final payload = _decodePayload(arguments);
    if (payload == null) {
      return;
    }

    _eventsController.add(
      ChatMessageDeliveredRealtimeEvent(
        ChatMessageDeliveredEventModel.fromJson(payload),
      ),
    );
  }

  Map<String, dynamic>? _decodePayload(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      return null;
    }

    final raw = arguments.first;
    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    }

    return null;
  }

  String _buildHubUrl() {
    final apiUri = Uri.parse(ApiConstants.baseUrl);
    final pathSegments = <String>[
      for (final segment in apiUri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (pathSegments.isNotEmpty && pathSegments.last == 'api') {
      pathSegments.removeLast();
    }

    return apiUri.replace(pathSegments: [...pathSegments, 'hubs', 'chat']).toString();
  }
}

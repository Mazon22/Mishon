import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'package:mishon_app/core/network/api_client.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/storage/secure_storage.dart';

enum LiveSyncStatus { idle, connecting, connected, reconnecting, error }

class LiveSyncEvent {
  final int id;
  final String type;
  final DateTime occurredAt;
  final Map<String, dynamic> data;

  const LiveSyncEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.data,
  });
}

final liveSyncServiceProvider = Provider<LiveSyncService>((ref) {
  final service = LiveSyncService(
    client: ref.watch(apiClientProvider),
    storage: ref.watch(storageProvider),
  );
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

class LiveSyncService {
  LiveSyncService({
    required ApiClient client,
    required SecureStorage storage,
  }) : _client = client,
       _storage = storage;

  final ApiClient _client;
  final SecureStorage _storage;
  final Logger _logger = Logger();
  final StreamController<LiveSyncEvent> _eventsController =
      StreamController<LiveSyncEvent>.broadcast();
  final StreamController<LiveSyncStatus> _statusController =
      StreamController<LiveSyncStatus>.broadcast();

  CancelToken? _cancelToken;
  Timer? _webFallbackTimer;
  Future<void>? _connectOperation;
  bool _disposed = false;
  int _lastEventId = 0;

  Stream<LiveSyncEvent> get events => _eventsController.stream;
  Stream<LiveSyncStatus> get statuses => _statusController.stream;
  int get lastEventId => _lastEventId;

  Future<void> ensureConnected() async {
    if (_disposed) {
      return;
    }

    final activeOperation = _connectOperation;
    if (activeOperation != null) {
      return activeOperation;
    }

    final operation = _connect();
    _connectOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_connectOperation, operation)) {
        _connectOperation = null;
      }
    }
  }

  Future<void> disconnect() async {
    _webFallbackTimer?.cancel();
    _webFallbackTimer = null;
    _cancelToken?.cancel('disconnect');
    _cancelToken = null;
    if (!_disposed) {
      _statusController.add(LiveSyncStatus.idle);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _eventsController.close();
    await _statusController.close();
  }

  Future<void> reconnect() async {
    await disconnect();
    await ensureConnected();
  }

  Future<void> _connect() async {
    final token = await _storage.readToken();
    if (_disposed || token == null || token.isEmpty) {
      _statusController.add(LiveSyncStatus.idle);
      return;
    }

    if (kIsWeb) {
      _startWebFallback();
      return;
    }

    var attempt = 0;
    while (!_disposed) {
      attempt += 1;
      _statusController.add(
        attempt == 1 && _lastEventId == 0
            ? LiveSyncStatus.connecting
            : LiveSyncStatus.reconnecting,
      );

      final cancelToken = CancelToken();
      _cancelToken = cancelToken;

      try {
        final response = await _client.dio.get<ResponseBody>(
          '/sync/stream',
          queryParameters: {'lastEventId': _lastEventId},
          options: Options(
            responseType: ResponseType.stream,
            headers: const {
              'Accept': 'text/event-stream',
              'Cache-Control': 'no-store',
            },
            receiveTimeout: const Duration(minutes: 30),
          ),
          cancelToken: cancelToken,
        );

        final responseBody = response.data;
        if (responseBody == null) {
          throw StateError('Sync stream is empty.');
        }

        _statusController.add(LiveSyncStatus.connected);
        await _consumeStream(responseBody);

        if (_disposed || cancelToken.isCancelled) {
          return;
        }
        throw StateError('Sync stream closed unexpectedly.');
      } catch (error, stackTrace) {
        if (_disposed || cancelToken.isCancelled) {
          return;
        }

        _logger.w('Live sync disconnected', error: error, stackTrace: stackTrace);
        _statusController.add(LiveSyncStatus.error);
        await Future<void>.delayed(
          Duration(seconds: attempt < 3 ? attempt : 4),
        );
      }
    }
  }

  void _startWebFallback() {
    _webFallbackTimer?.cancel();
    _statusController.add(LiveSyncStatus.connected);
    _webFallbackTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_disposed) {
        return;
      }
      _emitSyntheticResync();
    });
  }

  Future<void> _consumeStream(ResponseBody responseBody) async {
    var buffer = '';
    await for (final chunk in responseBody.stream) {
      if (_disposed) {
        return;
      }

      buffer += utf8.decode(chunk, allowMalformed: true);
      final processed = _consumeBufferedFrames(buffer);
      buffer = processed;
    }
  }

  String _consumeBufferedFrames(String buffer) {
    var remainder = buffer;
    while (true) {
      final boundary = remainder.indexOf('\n\n');
      if (boundary == -1) {
        break;
      }

      final rawFrame = remainder.substring(0, boundary);
      remainder = remainder.substring(boundary + 2);
      _handleFrame(rawFrame);
    }
    return remainder;
  }

  void _handleFrame(String frame) {
    final lines = frame.split(RegExp(r'\r?\n'));
    var nextId = 0;
    final dataLines = <String>[];

    for (final line in lines) {
      if (line.isEmpty || line.startsWith(':')) {
        continue;
      }

      if (line.startsWith('id:')) {
        nextId = int.tryParse(line.substring(3).trim()) ?? 0;
        continue;
      }

      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }

    if (dataLines.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(dataLines.join('\n'));
      if (decoded is! Map) {
        return;
      }

      final payload = _coerceMap(decoded);
      final payloadId =
          nextId > 0 ? nextId : (payload['id'] as num?)?.toInt() ?? 0;
      if (payloadId > 0 && payloadId <= _lastEventId) {
        return;
      }

      if (payloadId > 0) {
        _lastEventId = payloadId;
      }

      final type = payload['type'] as String? ?? 'sync.unknown';
      final occurredAtRaw = payload['occurredAt'] as String?;
      final occurredAt =
          occurredAtRaw != null
              ? DateTime.tryParse(occurredAtRaw) ?? DateTime.now()
              : DateTime.now();

      final data = _coerceMap(payload['data']);
      _eventsController.add(
        LiveSyncEvent(
          id: payloadId,
          type: type,
          occurredAt: occurredAt,
          data: data,
        ),
      );
    } catch (error, stackTrace) {
      _logger.w('Failed to parse live sync frame',
          error: error, stackTrace: stackTrace);
    }
  }

  Map<String, dynamic> _coerceMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamic item) => MapEntry(key.toString(), _coerceValue(item)),
      );
    }
    return <String, dynamic>{};
  }

  Object? _coerceValue(Object? value) {
    if (value is Map) {
      return _coerceMap(value);
    }
    if (value is List) {
      return value.map(_coerceValue).toList(growable: false);
    }
    return value;
  }

  void _emitSyntheticResync() {
    final nextId = _lastEventId + 1;
    _lastEventId = nextId;
    _eventsController.add(
      LiveSyncEvent(
        id: nextId,
        type: 'sync.resync',
        occurredAt: DateTime.now(),
        data: const <String, dynamic>{'reason': 'web_fallback'},
      ),
    );
  }
}

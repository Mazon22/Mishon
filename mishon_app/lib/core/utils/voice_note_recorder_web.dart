import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

import 'voice_note_recording_result.dart';

class VoiceNoteRecorder {
  MediaStream? _stream;
  MediaRecorder? _recorder;
  final List<Blob> _chunks = <Blob>[];
  DateTime? _startedAt;
  String _mimeType = 'audio/webm';
  bool _lifecycleGuardsAttached = false;

  bool get isRecording => _recorder != null;

  Duration get elapsed {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return Duration.zero;
    }

    return DateTime.now().difference(startedAt);
  }

  Future<bool> requestPermission() async {
    return true;
  }

  Future<void> start() async {
    if (isRecording) {
      return;
    }

    final stream = await window.navigator.mediaDevices
        .getUserMedia(MediaStreamConstraints(audio: true.toJS))
        .toDart;

    _stream = stream;
    _chunks.clear();
    _startedAt = DateTime.now();
    _mimeType = _resolveMimeType();

    final options = MediaRecorderOptions(mimeType: _mimeType);
    final recorder = MediaRecorder(stream, options);

    void dataHandler(Event event) {
      final blob = (event as BlobEvent).data;
      if (blob.size > 0) {
        _chunks.add(blob);
      }
    }

    void stopHandler(Event event) {
      unawaited(_finalizeRecording());
    }

    void errorHandler(Event event) {
      unawaited(_finalizeRecording(error: StateError('Voice recording failed')));
    }

    recorder.addEventListener('dataavailable', dataHandler.toJS);
    recorder.addEventListener('stop', stopHandler.toJS);
    recorder.addEventListener('error', errorHandler.toJS);
    _attachLifecycleGuards();
    recorder.start(250);
    _recorder = recorder;
  }

  Future<VoiceNoteRecordingResult?> stop() async {
    final recorder = _recorder;
    if (recorder == null) {
      return null;
    }

    final completer = _stopCompleter ??= Completer<VoiceNoteRecordingResult?>();
    try {
      recorder.stop();
    } catch (_) {
      await _cleanup();
      return null;
    }

    return completer.future;
  }

  Future<void> cancel() async {
    final recorder = _recorder;
    if (recorder == null) {
      _startedAt = null;
      _chunks.clear();
      return;
    }

    try {
      recorder.stop();
    } catch (_) {}
    await _cleanup();
  }

  void dispose() {
    unawaited(cancel());
  }

  Completer<VoiceNoteRecordingResult?>? _stopCompleter;
  EventListener? _pageHideHandler;
  EventListener? _visibilityChangeHandler;
  EventListener? _blurHandler;

  void _attachLifecycleGuards() {
    if (_lifecycleGuardsAttached) {
      return;
    }

    _pageHideHandler = ((Event _) {
      unawaited(cancel());
    }).toJS;
    _visibilityChangeHandler = ((Event _) {
      if (document.visibilityState == 'hidden') {
        unawaited(cancel());
      }
    }).toJS;
    _blurHandler = ((Event _) {
      if (isRecording) {
        unawaited(cancel());
      }
    }).toJS;

    window.addEventListener('pagehide', _pageHideHandler);
    document.addEventListener('visibilitychange', _visibilityChangeHandler);
    window.addEventListener('blur', _blurHandler);
    _lifecycleGuardsAttached = true;
  }

  void _detachLifecycleGuards() {
    if (!_lifecycleGuardsAttached) {
      return;
    }

    if (_pageHideHandler != null) {
      window.removeEventListener('pagehide', _pageHideHandler);
    }
    if (_visibilityChangeHandler != null) {
      document.removeEventListener('visibilitychange', _visibilityChangeHandler);
    }
    if (_blurHandler != null) {
      window.removeEventListener('blur', _blurHandler);
    }

    _pageHideHandler = null;
    _visibilityChangeHandler = null;
    _blurHandler = null;
    _lifecycleGuardsAttached = false;
  }

  Future<void> _finalizeRecording({Object? error}) async {
    final completer = _stopCompleter;
    if (completer == null || completer.isCompleted) {
      await _cleanup();
      return;
    }

    try {
      if (error != null) {
        throw error;
      }

      final startedAt = _startedAt;
      final chunks = List<Blob>.from(_chunks);
      if (chunks.isEmpty) {
        completer.complete(null);
        return;
      }

      final blob = Blob(
        chunks.toJS,
        BlobPropertyBag(type: _mimeType),
      );
      final arrayBuffer = await blob.arrayBuffer().toDart;
      final bytes = arrayBuffer.toDart.asUint8List();

      completer.complete(
        VoiceNoteRecordingResult(
          bytes: bytes,
          fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}${_extensionForMimeType(_mimeType)}',
          contentType: _mimeType,
          duration:
              startedAt == null
                  ? Duration.zero
                  : DateTime.now().difference(startedAt),
        ),
      );
    } catch (e, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(e, stackTrace);
      }
    } finally {
      await _cleanup();
    }
  }

  Future<void> _cleanup() async {
    _detachLifecycleGuards();
    _stream?.getTracks().toDart.forEach((track) => track.stop());
    _stream = null;
    _recorder = null;
    _startedAt = null;
    _chunks.clear();
    _stopCompleter = null;
  }

  String _resolveMimeType() {
    const candidates = <String>[
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/ogg',
      'audio/mp4',
    ];

    for (final candidate in candidates) {
      if (MediaRecorder.isTypeSupported(candidate)) {
        return candidate;
      }
    }

    return 'audio/webm';
  }

  String _extensionForMimeType(String mimeType) {
    return switch (mimeType) {
      'audio/ogg' || 'audio/ogg;codecs=opus' => '.ogg',
      'audio/mp4' => '.m4a',
      _ => '.webm',
    };
  }
}

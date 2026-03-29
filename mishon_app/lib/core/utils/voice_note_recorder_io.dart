import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'voice_note_recording_result.dart';
import 'voice_note_utils.dart';

class VoiceNoteRecorder {
  static const _sampleRate = 16000;
  static const _channels = 1;

  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _pcmBuffer = BytesBuilder(copy: false);
  StreamSubscription<List<int>>? _subscription;
  DateTime? _startedAt;

  bool get isRecording => _subscription != null;

  Duration get elapsed {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return Duration.zero;
    }

    return DateTime.now().difference(startedAt);
  }

  Future<bool> requestPermission() async {
    return _recorder.hasPermission();
  }

  Future<void> start() async {
    if (isRecording) {
      return;
    }

    _pcmBuffer.clear();
    _startedAt = DateTime.now();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: _channels,
      ),
    );
    _subscription = stream.listen(
      (chunk) {
        _pcmBuffer.add(_toBytes(chunk));
      },
      onError: (_) {},
    );
  }

  Future<VoiceNoteRecordingResult?> stop() async {
    if (!isRecording) {
      return null;
    }

    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();

    final startedAt = _startedAt;
    _startedAt = null;

    final pcmBytes = _pcmBuffer.takeBytes();
    _pcmBuffer.clear();
    if (pcmBytes.isEmpty) {
      return null;
    }

    final wavBytes = buildWavFromPcm16(
      pcmBytes,
      sampleRate: _sampleRate,
      channels: _channels,
    );

    return VoiceNoteRecordingResult(
      bytes: wavBytes,
      fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
      contentType: 'audio/wav',
      duration:
          startedAt == null
              ? Duration.zero
              : DateTime.now().difference(startedAt),
    );
  }

  Future<void> cancel() async {
    if (!isRecording) {
      _startedAt = null;
      _pcmBuffer.clear();
      return;
    }

    await _subscription?.cancel();
    _subscription = null;
    await _recorder.cancel();
    _startedAt = null;
    _pcmBuffer.clear();
  }

  void dispose() {
    unawaited(cancel());
    _recorder.dispose();
  }

  Uint8List _toBytes(List<int> chunk) {
    if (chunk is Uint8List) {
      return chunk;
    }

    return Uint8List.fromList(chunk);
  }
}

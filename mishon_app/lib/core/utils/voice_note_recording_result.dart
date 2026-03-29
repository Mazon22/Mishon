import 'dart:typed_data';

class VoiceNoteRecordingResult {
  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final Duration duration;

  const VoiceNoteRecordingResult({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.duration,
  });
}

import 'dart:math' as math;
import 'dart:typed_data';

bool isAudioFileName(String fileName) {
  final extension =
      fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  return const {'wav', 'mp3', 'm4a', 'aac', 'ogg', 'webm', 'opus'}
      .contains(extension);
}

String inferAttachmentContentType(String fileName, {bool isImage = false}) {
  if (isImage) {
    final extension =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return switch (extension) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  final extension =
      fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  return switch (extension) {
    'wav' => 'audio/wav',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'ogg' => 'audio/ogg',
    'webm' => 'audio/webm',
    'opus' => 'audio/opus',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'zip' => 'application/zip',
    'rar' => 'application/vnd.rar',
    _ => 'application/octet-stream',
  };
}

Uint8List buildWavFromPcm16(
  Uint8List pcmBytes, {
  required int sampleRate,
  required int channels,
}) {
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataSize = pcmBytes.lengthInBytes;
  final totalSize = 44 + dataSize;

  final bytes = Uint8List(totalSize);
  final byteData = ByteData.view(bytes.buffer);

  void writeAscii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes[offset + i] = value.codeUnitAt(i);
    }
  }

  writeAscii(0, 'RIFF');
  byteData.setUint32(4, totalSize - 8, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little);
  byteData.setUint16(22, channels, Endian.little);
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, byteRate, Endian.little);
  byteData.setUint16(32, blockAlign, Endian.little);
  byteData.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  byteData.setUint32(40, dataSize, Endian.little);
  bytes.setRange(44, totalSize, pcmBytes);

  return bytes;
}

Duration estimateWavDuration(Uint8List wavBytes) {
  if (wavBytes.lengthInBytes < 44) {
    return Duration.zero;
  }

  final byteData = ByteData.sublistView(wavBytes);
  final channels = math.max(1, byteData.getUint16(22, Endian.little));
  final sampleRate = math.max(1, byteData.getUint32(24, Endian.little));
  final bitsPerSample = math.max(1, byteData.getUint16(34, Endian.little));
  final dataSize = math.max(0, byteData.getUint32(40, Endian.little));
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  if (byteRate <= 0) {
    return Duration.zero;
  }

  final seconds = dataSize / byteRate;
  return Duration(milliseconds: (seconds * 1000).round());
}

Duration estimateAudioDurationFromSizeBytes(int sizeBytes) {
  if (sizeBytes <= 0) {
    return Duration.zero;
  }

  final dataSize = math.max(0, sizeBytes - 44);
  if (dataSize == 0) {
    return Duration.zero;
  }

  const byteRate = 16000 * 1 * 16 ~/ 8;
  final seconds = dataSize / byteRate;
  return Duration(milliseconds: (seconds * 1000).round());
}

String formatDurationLabel(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final minutes = safeDuration.inMinutes;
  final seconds = safeDuration.inSeconds.remainder(60);
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

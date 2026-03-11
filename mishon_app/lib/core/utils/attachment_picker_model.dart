import 'dart:typed_data';

enum AttachmentPickType { any, image }

class PickedAttachmentData {
  final String fileName;
  final Uint8List bytes;

  const PickedAttachmentData({required this.fileName, required this.bytes});
}

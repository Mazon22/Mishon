import 'package:file_picker/file_picker.dart';

import 'attachment_picker_model.dart';

Future<List<PickedAttachmentData>?> pickAttachments({
  bool allowMultiple = true,
  AttachmentPickType type = AttachmentPickType.any,
}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    withData: true,
    type: type == AttachmentPickType.image ? FileType.image : FileType.any,
  );

  if (result == null || result.files.isEmpty) {
    return null;
  }

  return result.files
      .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
      .map(
        (file) => PickedAttachmentData(fileName: file.name, bytes: file.bytes!),
      )
      .toList(growable: false);
}

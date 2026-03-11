import 'attachment_picker_model.dart';
import 'attachment_picker_io.dart'
    if (dart.library.html) 'attachment_picker_web.dart'
    as impl;

export 'attachment_picker_model.dart'
    show AttachmentPickType, PickedAttachmentData;

Future<List<PickedAttachmentData>?> pickAttachments({
  bool allowMultiple = true,
  AttachmentPickType type = AttachmentPickType.any,
}) {
  return impl.pickAttachments(allowMultiple: allowMultiple, type: type);
}

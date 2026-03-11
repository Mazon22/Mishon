import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'attachment_picker_model.dart';

Future<List<PickedAttachmentData>?> pickAttachments({
  bool allowMultiple = true,
  AttachmentPickType type = AttachmentPickType.any,
}) async {
  final input =
      HTMLInputElement()
        ..type = 'file'
        ..multiple = allowMultiple
        ..accept = type == AttachmentPickType.image ? 'image/*' : '*/*'
        ..style.display = 'none';

  final completer = Completer<List<PickedAttachmentData>?>();
  var changed = false;

  void completeWithNull() {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }

  document.body?.children.add(input);

  void changeHandler(Event _) async {
    if (changed) {
      return;
    }
    changed = true;

    final files = input.files;
    if (files == null || files.length == 0) {
      completeWithNull();
      input.remove();
      return;
    }

    try {
      final picked = <PickedAttachmentData>[];
      for (var index = 0; index < files.length; index++) {
        final file = files.item(index);
        if (file == null) {
          continue;
        }

        final bytes = await _readFile(file);
        picked.add(PickedAttachmentData(fileName: file.name, bytes: bytes));
      }

      if (!completer.isCompleted) {
        completer.complete(picked);
      }
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    } finally {
      input.remove();
    }
  }

  void focusHandler(Event _) {
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!changed) {
        completeWithNull();
        input.remove();
      }
    });
  }

  input.addEventListener('change', changeHandler.toJS);
  window.addEventListener('focus', focusHandler.toJS);
  input.click();

  final result = await completer.future;
  window.removeEventListener('focus', focusHandler.toJS);
  input.removeEventListener('change', changeHandler.toJS);
  return result;
}

Future<Uint8List> _readFile(File file) {
  final completer = Completer<Uint8List>();
  final reader = FileReader();

  void loadHandler(Event _) {
    final result = reader.result;
    if (result != null && result.isA<JSArrayBuffer>()) {
      completer.complete((result as JSArrayBuffer).toDart.asUint8List());
      return;
    }

    completer.completeError(StateError('Unable to read file: ${file.name}'));
  }

  void errorHandler(Event _) {
    completer.completeError(StateError('Unable to read file: ${file.name}'));
  }

  reader.addEventListener('loadend', loadHandler.toJS);
  reader.addEventListener('error', errorHandler.toJS);
  reader.readAsArrayBuffer(file);

  return completer.future.whenComplete(() {
    reader.removeEventListener('loadend', loadHandler.toJS);
    reader.removeEventListener('error', errorHandler.toJS);
  });
}

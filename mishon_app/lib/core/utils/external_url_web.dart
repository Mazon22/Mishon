import 'package:web/web.dart';

Future<bool> openExternalUrl(String url) async {
  final anchor =
      HTMLAnchorElement()
        ..href = url
        ..target = '_blank'
        ..rel = 'noopener noreferrer'
        ..download = '';

  document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}

import 'external_url_io.dart'
    if (dart.library.html) 'external_url_web.dart'
    as impl;

Future<bool> openExternalUrl(String url) {
  return impl.openExternalUrl(url);
}

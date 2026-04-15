import 'package:mishon_app/core/constants/api_constants.dart';

String get mediaOrigin => ApiConstants.baseUrl.replaceFirst('/api', '');

String resolveMediaUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) {
      return trimmed;
    }

    if (_shouldRewriteLegacyLocalMedia(parsed)) {
      final origin = Uri.parse(mediaOrigin);
      return origin
          .replace(
            path: parsed.path,
            query: parsed.hasQuery ? parsed.query : null,
            fragment: parsed.hasFragment ? parsed.fragment : null,
          )
          .toString();
    }

    return trimmed;
  }

  return trimmed.startsWith('/') ? '$mediaOrigin$trimmed' : '$mediaOrigin/$trimmed';
}

String? resolveOptionalMediaUrl(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return resolveMediaUrl(trimmed);
}

bool _shouldRewriteLegacyLocalMedia(Uri uri) {
  final host = uri.host.toLowerCase();
  final isLocalHost = host == 'localhost' || host == '127.0.0.1';
  if (!isLocalHost) {
    return false;
  }

  return uri.path.startsWith('/uploads/');
}

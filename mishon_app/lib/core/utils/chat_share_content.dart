import 'dart:convert';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/utils/media_url.dart' as media_url;

const _sharedPostPrefix = '__mishon_shared_post__:';

class SharedPostPayload {
  final int postId;
  final int userId;
  final String username;
  final String? userAvatarUrl;
  final double userAvatarScale;
  final double userAvatarOffsetX;
  final double userAvatarOffsetY;
  final String contentPreview;
  final String? imageUrl;
  final DateTime createdAt;

  const SharedPostPayload({
    required this.postId,
    required this.userId,
    required this.username,
    required this.userAvatarUrl,
    required this.userAvatarScale,
    required this.userAvatarOffsetX,
    required this.userAvatarOffsetY,
    required this.contentPreview,
    required this.imageUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': 'post',
      'postId': postId,
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'userAvatarScale': userAvatarScale,
      'userAvatarOffsetX': userAvatarOffsetX,
      'userAvatarOffsetY': userAvatarOffsetY,
      'contentPreview': contentPreview,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SharedPostPayload.fromJson(Map<String, dynamic> json) {
    return SharedPostPayload(
      postId: json['postId'] as int,
      userId: json['userId'] as int,
      username: json['username'] as String? ?? 'Mishon',
      userAvatarUrl: json['userAvatarUrl'] as String?,
      userAvatarScale: (json['userAvatarScale'] as num?)?.toDouble() ?? 1,
      userAvatarOffsetX: (json['userAvatarOffsetX'] as num?)?.toDouble() ?? 0,
      userAvatarOffsetY: (json['userAvatarOffsetY'] as num?)?.toDouble() ?? 0,
      contentPreview: json['contentPreview'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
    );
  }
}

String encodeSharedPostMessage(Post post) {
  final payload = SharedPostPayload(
    postId: post.id,
    userId: post.userId,
    username: post.username,
    userAvatarUrl: _resolveOptionalMediaUrl(post.userAvatarUrl),
    userAvatarScale: post.userAvatarScale,
    userAvatarOffsetX: post.userAvatarOffsetX,
    userAvatarOffsetY: post.userAvatarOffsetY,
    contentPreview: _truncatePostPreview(post.content),
    imageUrl: _extractPrimaryImageUrl(post.imageUrl),
    createdAt: post.createdAt.toUtc(),
  );

  return '$_sharedPostPrefix${jsonEncode(payload.toJson())}';
}

SharedPostPayload? tryParseSharedPostMessage(String? rawContent) {
  final trimmed = rawContent?.trim();
  if (trimmed == null || !trimmed.startsWith(_sharedPostPrefix)) {
    return null;
  }

  try {
    final decoded = jsonDecode(trimmed.substring(_sharedPostPrefix.length));
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    if (decoded['type'] != 'post') {
      return null;
    }

    return SharedPostPayload.fromJson(decoded);
  } catch (_) {
    return null;
  }
}

String sharedPostPreviewLabel(AppStrings strings, SharedPostPayload payload) {
  return strings.isRu
      ? 'Пост от ${payload.username}'
      : 'Post from ${payload.username}';
}

String sharedPostSubtitleLabel(AppStrings strings) {
  return strings.isRu ? 'Поделиться постом' : 'Shared post';
}

String _truncatePostPreview(String content) {
  final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= 220) {
    return normalized;
  }

  return '${normalized.substring(0, 217).trimRight()}...';
}

String? _extractPrimaryImageUrl(String? rawImageUrl) {
  if (rawImageUrl == null || rawImageUrl.trim().isEmpty) {
    return null;
  }

  final normalized = rawImageUrl.trim();
  final parts = normalized
      .split(RegExp(r'\s*(?:\n|\||,\s*(?=https?://|/)|;\s*(?=https?://|/))\s*'))
      .where((value) => value.trim().isNotEmpty)
      .toList(growable: false);

  final primary = parts.isEmpty ? normalized : parts.first;
  return media_url.resolveMediaUrl(primary);
}

String? _resolveOptionalMediaUrl(String? url) {
  return media_url.resolveOptionalMediaUrl(url);
}

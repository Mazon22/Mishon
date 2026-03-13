import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mishon_app/core/constants/api_constants.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/widgets/fullscreen_image_screen.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool isOwnPost;
  final VoidCallback? onLike;
  final VoidCallback? onFollow;
  final VoidCallback? onDelete;
  final VoidCallback? onComment;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onShare;
  final bool showActions;

  const PostCard({
    super.key,
    required this.post,
    this.isOwnPost = false,
    this.onLike,
    this.onFollow,
    this.onDelete,
    this.onComment,
    this.onOpenProfile,
    this.onShare,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final mediaUrls = _extractImageUrls(post.imageUrl);
    final handle = _buildHandle(post.username);
    final dateLabel = _formatRelativeDate(context, post.createdAt.toLocal());
    final resolvedAvatarUrl = _resolveOptionalMediaUrl(post.userAvatarUrl);
    final hasMenu =
        (isOwnPost && onDelete != null) || onFollow != null || onShare != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EBF7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12162033),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar(
                  username: post.username,
                  imageUrl: resolvedAvatarUrl,
                  size: 48,
                  scale: post.userAvatarScale,
                  offsetX: post.userAvatarOffsetX,
                  offsetY: post.userAvatarOffsetY,
                  onTap: onOpenProfile,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onOpenProfile,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: const Color(0xFF18243C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                '@$handle',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                '·',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                dateLabel,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasMenu)
                  _PostMenuButton(
                    isOwnPost: isOwnPost,
                    isFollowingAuthor: post.isFollowingAuthor,
                    onFollow: onFollow,
                    onDelete: onDelete,
                    onShare: onShare,
                  ),
              ],
            ),
            if (post.content.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                post.content.trim(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.55,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
            if (mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 14),
              _PostMediaGallery(postId: post.id, imageUrls: mediaUrls),
            ],
            if (showActions) ...[
              const SizedBox(height: 14),
              const Divider(color: Color(0xFFE8EEF8), height: 1, thickness: 1),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _PostActionButton(
                      icon:
                          post.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                      label: _formatCount(post.likesCount),
                      isActive: post.isLiked,
                      color:
                          post.isLiked
                              ? const Color(0xFFE33F6C)
                              : const Color(0xFF526075),
                      onTap: onLike,
                    ),
                  ),
                  Expanded(
                    child: _PostActionButton(
                      icon: Icons.mode_comment_outlined,
                      label: _formatCount(post.commentsCount),
                      color: const Color(0xFF526075),
                      onTap: onComment,
                    ),
                  ),
                  Expanded(
                    child: _PostActionButton(
                      icon: Icons.share_outlined,
                      label: strings.share,
                      color: const Color(0xFF526075),
                      onTap: onShare,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostMenuButton extends StatelessWidget {
  final bool isOwnPost;
  final bool isFollowingAuthor;
  final VoidCallback? onFollow;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const _PostMenuButton({
    required this.isOwnPost,
    required this.isFollowingAuthor,
    required this.onFollow,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final items = <PopupMenuEntry<String>>[
      if (!isOwnPost && onFollow != null)
        PopupMenuItem<String>(
          value: 'follow',
          child: Text(isFollowingAuthor ? strings.unfollow : strings.follow),
        ),
      if (onShare != null)
        PopupMenuItem<String>(value: 'share', child: Text(strings.share)),
      if (isOwnPost && onDelete != null)
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(strings.deletePost),
        ),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'follow':
            onFollow?.call();
          case 'share':
            onShare?.call();
          case 'delete':
            onDelete?.call();
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      itemBuilder: (_) => items,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: Color(0xFF526075),
        ),
      ),
    );
  }
}

class _PostMediaGallery extends StatelessWidget {
  final int postId;
  final List<String> imageUrls;

  const _PostMediaGallery({required this.postId, required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      return _PostMediaTile(
        imageUrl: imageUrls.first,
        heroTag: 'post-image-$postId-0',
        borderRadius: BorderRadius.circular(18),
        height: 250,
      );
    }

    if (imageUrls.length == 2) {
      return SizedBox(
        height: 220,
        child: Row(
          children: [
            Expanded(
              child: _PostMediaTile(
                imageUrl: imageUrls[0],
                heroTag: 'post-image-$postId-0',
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PostMediaTile(
                imageUrl: imageUrls[1],
                heroTag: 'post-image-$postId-1',
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final remainingCount = imageUrls.length - 3;

    return Column(
      children: [
        _PostMediaTile(
          imageUrl: imageUrls[0],
          heroTag: 'post-image-$postId-0',
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
          height: 180,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: Row(
            children: [
              Expanded(
                child: _PostMediaTile(
                  imageUrl: imageUrls[1],
                  heroTag: 'post-image-$postId-1',
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PostMediaTile(
                  imageUrl: imageUrls[2],
                  heroTag: 'post-image-$postId-2',
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(18),
                  ),
                  overlayLabel: remainingCount > 0 ? '+$remainingCount' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostMediaTile extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final BorderRadius borderRadius;
  final double? height;
  final String? overlayLabel;

  const _PostMediaTile({
    required this.imageUrl,
    required this.heroTag,
    required this.borderRadius,
    this.height,
    this.overlayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final child = Hero(
      tag: heroTag,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder:
                    (_, __) => Container(
                      color: const Color(0xFFF0F4FA),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                errorWidget:
                    (_, __, ___) => Container(
                      color: const Color(0xFFF0F4FA),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        size: 34,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
              ),
              if (overlayLabel != null)
                Container(
                  color: Colors.black.withValues(alpha: 0.34),
                  alignment: Alignment.center,
                  child: Text(
                    overlayLabel!,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullscreenImageScreen(imageUrl: imageUrl),
            ),
          );
        },
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}

class _PostActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;

  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_PostActionButton> createState() => _PostActionButtonState();
}

class _PostActionButtonState extends State<_PostActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseScale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.18,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _PostActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown:
          widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: _pulseScale,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: widget.isActive ? _pulseScale.value : 1,
                        child: child,
                      );
                    },
                    child: Icon(widget.icon, size: 20, color: widget.color),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: widget.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRelativeDate(BuildContext context, DateTime date) {
  final strings = AppStrings.of(context);
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inMinutes < 1) {
    return strings.nowShort;
  }
  if (difference.inHours < 1) {
    return strings.minutesShort(difference.inMinutes);
  }
  if (difference.inDays < 1) {
    return strings.hoursShort(difference.inHours);
  }
  if (difference.inDays < 7) {
    return strings.daysShort(difference.inDays);
  }
  return strings.formatMonthDay(date);
}

String _formatCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(count % 1000000 == 0 ? 0 : 1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}K';
  }
  return '$count';
}

String _buildHandle(String username) {
  final handle = username.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9_]+'),
    '',
  );
  return handle.isEmpty ? 'mishon' : handle;
}

List<String> _extractImageUrls(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }

  final normalized = raw.trim();
  final hasMultipleSeparators =
      normalized.contains('\n') ||
      normalized.contains('|') ||
      normalized.contains(',http') ||
      normalized.contains(',/') ||
      normalized.contains(';http') ||
      normalized.contains(';/');

  if (!hasMultipleSeparators) {
    return [_resolveMediaUrl(normalized)];
  }

  return normalized
      .split(RegExp(r'\s*(?:\n|\||,\s*(?=https?://|/)|;\s*(?=https?://|/))\s*'))
      .where((value) => value.trim().isNotEmpty)
      .map((value) => _resolveMediaUrl(value.trim()))
      .toList(growable: false);
}

String? _resolveOptionalMediaUrl(String? url) {
  if (url == null || url.trim().isEmpty) {
    return null;
  }
  return _resolveMediaUrl(url.trim());
}

String _resolveMediaUrl(String url) {
  return url.startsWith('http')
      ? url
      : '${ApiConstants.baseUrl.replaceFirst('/api', '')}$url';
}

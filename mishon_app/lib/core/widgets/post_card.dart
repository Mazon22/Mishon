import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/api_constants.dart';
import '../models/post_model.dart';
import 'fullscreen_image_screen.dart';
import 'profile_media.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool isOwnPost;
  final VoidCallback? onLike;
  final VoidCallback? onFollow;
  final VoidCallback? onDelete;
  final VoidCallback? onComment;
  final VoidCallback? onOpenProfile;
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
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd MMM, HH:mm').format(post.createdAt.toLocal());

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10203F).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar(
                  username: post.username,
                  imageUrl: post.userAvatarUrl,
                  size: 54,
                  scale: post.userAvatarScale,
                  offsetX: post.userAvatarOffsetX,
                  offsetY: post.userAvatarOffsetY,
                  onTap: onOpenProfile,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: onOpenProfile,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  post.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F5FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  dateLabel,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF50627D),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isOwnPost
                                ? 'Your update in the feed'
                                : post.isFollowingAuthor
                                    ? 'From someone you follow'
                                    : 'Discovering new voices',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF6A7790),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isOwnPost && onDelete != null)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete post'),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.more_horiz_rounded),
                    ),
                  )
                else if (!isOwnPost && onFollow != null)
                  FilledButton.tonal(
                    onPressed: onFollow,
                    style: FilledButton.styleFrom(
                      backgroundColor: post.isFollowingAuthor
                          ? const Color(0xFFEDEFF7)
                          : const Color(0xFFEAF1FF),
                      foregroundColor: post.isFollowingAuthor
                          ? const Color(0xFF3F4C63)
                          : const Color(0xFF1C52FF),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(post.isFollowingAuthor ? 'Following' : 'Follow'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFFF8FAFF),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Text(
                post.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.55,
                      color: const Color(0xFF17233B),
                    ),
              ),
            ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullscreenImageScreen(imageUrl: _resolvedImageUrl),
                    ),
                  );
                },
                child: Hero(
                  tag: 'post-image-${post.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 240,
                      child: CachedNetworkImage(
                        imageUrl: _resolvedImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFF0F2F8),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFF0F2F8),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, size: 44, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _ActionPill(
                    icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: '${post.likesCount}',
                    tint: post.isLiked ? const Color(0xFFFFE4EB) : const Color(0xFFF2F4F8),
                    foreground: post.isLiked ? const Color(0xFFE33F6C) : const Color(0xFF5F708A),
                    onTap: onLike,
                  ),
                  const SizedBox(width: 10),
                  _ActionPill(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Comments',
                    tint: const Color(0xFFEAF1FF),
                    foreground: const Color(0xFF235CFF),
                    onTap: onComment,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _resolvedImageUrl {
    if (post.imageUrl == null || post.imageUrl!.isEmpty) {
      return '';
    }

    return post.imageUrl!.startsWith('http')
        ? post.imageUrl!
        : '${ApiConstants.baseUrl.replaceFirst('/api', '')}${post.imageUrl!}';
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final Color foreground;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.tint,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

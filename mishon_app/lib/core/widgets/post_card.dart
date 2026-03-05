import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../constants/api_constants.dart';
import 'fullscreen_image_screen.dart';

/// Карточка поста для ленты и профиля
class PostCard extends StatelessWidget {
  final Post post;
  final bool isOwnPost;
  final VoidCallback? onLike;
  final VoidCallback? onFollow;
  final VoidCallback? onDelete;
  final VoidCallback? onComment;
  final bool showActions;

  const PostCard({
    super.key,
    required this.post,
    this.isOwnPost = false,
    this.onLike,
    this.onFollow,
    this.onDelete,
    this.onComment,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок с аватаром и именем
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Аватар
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: post.userAvatarUrl != null && post.userAvatarUrl!.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: post.userAvatarUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: Text(
                                  post.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  post.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              post.username[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Информация о пользователе
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                post.username,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Кнопка удаления для владельца
                            if (isOwnPost && onDelete != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 22),
                                color: Colors.red.shade400,
                                onPressed: onDelete,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(post.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Кнопка подписки (не для своих постов)
                  if (!isOwnPost && onFollow != null)
                    ElevatedButton(
                      onPressed: onFollow,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: const Size(0, 36),
                        backgroundColor: post.isFollowingAuthor
                            ? Colors.grey.shade300
                            : Theme.of(context).colorScheme.primary,
                        foregroundColor: post.isFollowingAuthor
                            ? Colors.black87
                            : Colors.white,
                      ),
                      child: Text(post.isFollowingAuthor ? 'Подписан' : 'Подписаться'),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Контент поста
              Text(
                post.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                    ),
              ),

              // Изображение (если есть) - фиксированный размер 180dp
              if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullscreenImageScreen(
                          imageUrl: post.imageUrl!.startsWith('http')
                              ? post.imageUrl!
                              : '${ApiConstants.baseUrl.replaceFirst('/api', '')}${post.imageUrl!}',
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 180,
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl!.startsWith('http')
                            ? post.imageUrl!
                            : '${ApiConstants.baseUrl.replaceFirst('/api', '')}${post.imageUrl!}',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Действия (лайки и комментарии)
              if (showActions) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      // Лайки
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onLike,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                                  size: 22,
                                  color: post.isLiked ? Colors.red : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${post.likesCount}',
                                  style: TextStyle(
                                    color: post.isLiked ? Colors.red : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Комментарии
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onComment,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 22,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Комментировать',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

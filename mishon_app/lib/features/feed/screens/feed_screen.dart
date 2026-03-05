import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/feed_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:mishon_app/core/network/exceptions.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedNotifierProvider);
    final userIdAsync = ref.watch(userIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mishon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => context.go('/create-post'),
          ),
        ],
      ),
      body: feedState.when(
        data: (posts) => posts.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
                child: ListView.builder(
                  itemCount: posts.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final currentUserId = userIdAsync.value;
                    return _PostCard(
                      post: post,
                      currentUserId: currentUserId,
                      onLike: () => ref
                          .read(feedNotifierProvider.notifier)
                          .toggleLike(post.id),
                      onFollow: () => ref
                          .read(feedNotifierProvider.notifier)
                          .toggleFollow(post.userId),
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(ref, error),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feed_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Лента пуста',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Подпишитесь на пользователей,\nчтобы видеть их посты',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, Object error) {
    String errorMessage;
    if (error is String) {
      errorMessage = error;
    } else if (error is OfflineException) {
      errorMessage = 'Нет подключения к интернету';
    } else {
      errorMessage = 'Ошибка загрузки ленты';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(feedNotifierProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final dynamic post;
  final int? currentUserId;
  final VoidCallback onLike;
  final VoidCallback onFollow;

  const _PostCard({
    required this.post,
    this.currentUserId,
    required this.onLike,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final isOwnPost = currentUserId != null && currentUserId == post.userId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade100,
              child: post.userAvatarUrl != null && post.userAvatarUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: post.userAvatarUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Text(
                          post.username[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Text(
                          post.username[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  : Text(
                      post.username[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
            title: Text(
              post.username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(dateFormat.format(post.createdAt.toLocal())),
            trailing: isOwnPost
                ? null
                : ElevatedButton(
                    onPressed: onFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Подписаться'),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              post.content,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  child: const Center(child: Icon(Icons.broken_image, size: 48)),
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : null,
                  ),
                  onPressed: onLike,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likesCount}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

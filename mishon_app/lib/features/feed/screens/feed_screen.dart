import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/widgets/post_card.dart';
import 'package:mishon_app/core/widgets/states.dart';
import '../providers/feed_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/network/exceptions.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedNotifierProvider);
    final userIdAsync = ref.watch(userIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mishon'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/profile'),
            tooltip: 'Профиль',
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => context.go('/create-post'),
            tooltip: 'Создать пост',
          ),
        ],
      ),
      body: feedState.when(
        data: (posts) => posts.isEmpty
            ? _buildEmptyState(ref)
            : RefreshIndicator(
                onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
                child: ListView.builder(
                  itemCount: posts.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final currentUserId = userIdAsync.value;
                    final isOwnPost = currentUserId != null && currentUserId == post.userId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: PostCard(
                          post: post,
                          isOwnPost: isOwnPost,
                          onLike: () => ref
                              .read(feedNotifierProvider.notifier)
                              .toggleLike(post.id),
                          onFollow: () => ref
                              .read(feedNotifierProvider.notifier)
                              .toggleFollow(post.userId),
                        ),
                      ),
                    );
                  },
                ),
              ),
        loading: () => const LoadingState(),
        error: (error, stack) => _buildErrorState(ref, error),
      ),
    );
  }

  Widget _buildEmptyState(WidgetRef ref) {
    return EmptyState(
      icon: Icons.feed_outlined,
      title: 'Лента пуста',
      subtitle: 'Подпишитесь на пользователей,\nчтобы видеть их посты',
      actionText: 'Обновить',
      onAction: () => ref.read(feedNotifierProvider.notifier).refresh(),
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

    return ErrorState(
      message: errorMessage,
      onRetry: () => ref.read(feedNotifierProvider.notifier).refresh(),
    );
  }
}

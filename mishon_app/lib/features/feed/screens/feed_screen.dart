import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/post_card.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/comments/screens/comments_screen.dart';
import 'package:mishon_app/features/feed/providers/feed_provider.dart';

import '../../auth/providers/auth_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _poller = Timer.periodic(const Duration(seconds: 12), (_) {
      ref.read(feedNotifierProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedNotifierProvider);
    final userIdAsync = ref.watch(userIdProvider);

    return AppShell(
      currentSection: AppSection.feed,
      title: 'Лента',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-post'),
        icon: const Icon(Icons.add),
        label: const Text('Пост'),
      ),
      child: feedState.when(
        data: (posts) => posts.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
                child: ListView.builder(
                  itemCount: posts.length,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final currentUserId = userIdAsync.value;
                    final isOwnPost = currentUserId != null && currentUserId == post.userId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PostCard(
                        post: post,
                        isOwnPost: isOwnPost,
                        onLike: () => ref.read(feedNotifierProvider.notifier).toggleLike(post.id),
                        onFollow: () => ref.read(feedNotifierProvider.notifier).toggleFollow(post.userId),
                        onComment: () => context.push(
                          '/comments',
                          extra: CommentsScreenArgs(
                            postId: post.id,
                            postUserId: post.userId,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
        loading: () => const LoadingState(),
        error: (error, stack) => ErrorState(
          message: _getErrorMessage(error),
          onRetry: () => ref.read(feedNotifierProvider.notifier).refresh(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.feed_outlined,
      title: 'Лента пока пустая',
      subtitle: 'Подпишитесь на людей или создайте первый пост.',
    );
  }

  String _getErrorMessage(Object error) {
    if (error is String) {
      return error;
    }
    if (error is OfflineException) {
      return 'Нет подключения к интернету';
    }
    return 'Ошибка загрузки ленты';
  }
}

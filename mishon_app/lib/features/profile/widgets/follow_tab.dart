import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/widgets/empty_posts_banner.dart';
import 'package:mishon_app/features/profile/providers/follow_provider.dart';

class FollowTab extends ConsumerWidget {
  final int userId;
  final bool isFollowersTab;

  const FollowTab({
    super.key,
    required this.userId,
    required this.isFollowersTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = isFollowersTab
        ? userFollowersListProvider(userId)
        : userFollowingListProvider(userId);
    
    final state = ref.watch(provider);

    return state.when(
      data: (list) => list.isEmpty
          ? EmptyFollowBanner(
              isFollowers: isFollowersTab,
            )
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = list[index];
                return _FollowListTile(
                  user: user,
                  onTap: () => context.go('/profile/${user.id}'),
                  onFollowToggle: () async {
                    try {
                      await ref
                          .read(followNotifierProvider.notifier)
                          .toggleFollow(user.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ошибка операции'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text('Ошибка: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(provider),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowListTile extends StatelessWidget {
  final Follow user;
  final VoidCallback onTap;
  final VoidCallback onFollowToggle;

  const _FollowListTile({
    required this.user,
    required this.onTap,
    required this.onFollowToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: user.avatarUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Text(
                    user.username[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : Text(
                user.username[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
      title: Text(
        user.username,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: ElevatedButton(
        onPressed: onFollowToggle,
        style: ElevatedButton.styleFrom(
          backgroundColor: user.isFollowing
              ? Colors.grey.shade300
              : Theme.of(context).colorScheme.primary,
          foregroundColor: user.isFollowing ? Colors.black87 : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(user.isFollowing ? 'Подписан' : 'Подписаться'),
      ),
      onTap: onTap,
    );
  }
}

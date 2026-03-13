import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/widgets/empty_posts_banner.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
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
    final strings = AppStrings.of(context);
    final provider =
        isFollowersTab
            ? userFollowersListProvider(userId)
            : userFollowingListProvider(userId);

    final state = ref.watch(provider);

    return state.when(
      data:
          (list) => list.isEmpty
              ? EmptyPostsBanner(
                title:
                    isFollowersTab
                        ? strings.noFollowersYet
                        : strings.noFollowingYet,
                subtitle:
                    isFollowersTab
                        ? strings.followersWillAppearHere
                        : strings.followingWillAppearHere,
                icon:
                    isFollowersTab
                        ? Icons.people_outline_rounded
                        : Icons.person_add_alt_1_outlined,
                showCta: false,
              )
              : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = list[index];
                  return _FollowListTile(
                    user: user,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/profile/${user.id}');
                    },
                    onFollowToggle: () async {
                      try {
                        await ref
                            .read(followNotifierProvider.notifier)
                            .toggleFollow(user.id);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(strings.operationError),
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
      error:
          (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 12),
                Text('${strings.errorTitle}: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(provider),
                  child: Text(strings.retry),
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
    final strings = AppStrings.of(context);

    return ListTile(
      leading: AppAvatar(
        username: user.username,
        imageUrl: user.avatarUrl,
        size: 40,
        scale: user.avatarScale,
        offsetX: user.avatarOffsetX,
        offsetY: user.avatarOffsetY,
      ),
      title: Text(
        user.username,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: ElevatedButton(
        onPressed: onFollowToggle,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              user.isFollowing
                  ? Colors.grey.shade300
                  : Theme.of(context).colorScheme.primary,
          foregroundColor: user.isFollowing ? Colors.black87 : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(user.isFollowing ? strings.followingLabel : strings.follow),
      ),
      onTap: onTap,
    );
  }
}

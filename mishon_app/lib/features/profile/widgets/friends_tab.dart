import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/widgets/empty_posts_banner.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/features/friends/providers/friends_screen_provider.dart';

class FriendsTab extends ConsumerWidget {
  const FriendsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final state = ref.watch(friendsScreenControllerProvider);

    if (state.isLoading && state.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text('${strings.errorTitle}: ${state.errorMessage}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(friendsScreenControllerProvider.notifier).refresh(),
              child: Text(strings.retry),
            ),
          ],
        ),
      );
    }

    final friends = state.friends;
    if (friends.isEmpty) {
      return EmptyPostsBanner(
        title: strings.noFriendsYet,
        subtitle: strings.friendsWillAppearHere,
        icon: Icons.people_outline_rounded,
        showCta: false,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: friends.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = friends[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: AppAvatar(
            username: user.username,
            imageUrl: user.avatarUrl,
            size: 40,
            scale: user.avatarScale,
            offsetX: user.avatarOffsetX,
            offsetY: user.avatarOffsetY,
          ),
          title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            user.isOnline
                ? (strings.isRu ? 'В сети сейчас' : 'Online now')
                : (strings.isRu ? 'Не в сети' : 'Offline'),
          ),
          onTap: () {
            Navigator.pop(context);
            context.go('/profile/${user.id}');
          },
        );
      },
    );
  }
}

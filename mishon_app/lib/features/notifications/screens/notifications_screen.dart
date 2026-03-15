import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<NotificationItemModel> _items = const [];
  bool _didMarkAll = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final repository = ref.read(socialRepositoryProvider);
      var items = await repository.getNotifications();

      if (!_didMarkAll) {
        await repository.markAllNotificationsRead();
        await ref.read(notificationSummaryProvider.notifier).refresh();
        _didMarkAll = true;
        items = await repository.getNotifications();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.apiError.message;
        _isLoading = false;
      });
    } on OfflineException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      final strings = AppStrings.of(context);
      setState(() {
        _errorMessage =
            strings.isRu
                ? 'Не удалось загрузить уведомления'
                : 'Could not load notifications';
        _isLoading = false;
      });
    }
  }

  Future<void> _openNotification(NotificationItemModel item) async {
    if (!item.isRead) {
      await ref.read(socialRepositoryProvider).markNotificationRead(item.id);
      await ref.read(notificationSummaryProvider.notifier).refresh();
    }

    if (!mounted) {
      return;
    }

    if (item.conversationId != null && item.actorUserId != null) {
      final strings = AppStrings.of(context);
      final username = item.actorUsername ?? (strings.isRu ? 'Диалог' : 'Chat');
      context.push(
        '/chat',
        extra: ChatScreenArgs(
          conversationId: item.conversationId!,
          peerId: item.actorUserId!,
          peerUsername: username,
          peerAvatarUrl: item.actorAvatarUrl,
          peerAvatarScale: item.actorAvatarScale,
          peerAvatarOffsetX: item.actorAvatarOffsetX,
          peerAvatarOffsetY: item.actorAvatarOffsetY,
        ),
      );
      return;
    }

    if (item.relatedUserId != null) {
      context.go('/profile/${item.relatedUserId}');
      return;
    }

    if (item.postId != null) {
      context.go('/feed');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.isRu ? 'Уведомления' : 'Notifications'),
        centerTitle: false,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7F6FF),
              Color(0xFFFFFBF5),
            ],
          ),
        ),
        child: _isLoading
            ? const LoadingState()
            : _errorMessage != null
                ? ErrorState(
                    message: _errorMessage!,
                    onRetry: () => _loadNotifications(),
                  )
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: strings.isRu ? 'Пока тихо' : 'Nothing new yet',
                        subtitle:
                            strings.isRu
                                ? 'Новые реакции, заявки и сообщения появятся здесь.'
                                : 'New reactions, requests, and messages will appear here.',
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadNotifications(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _NotificationCard(
                              item: item,
                              onTap: () => _openNotification(item),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItemModel item;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final createdAt = DateFormat(
      'dd MMM, HH:mm',
      strings.localeCode,
    ).format(item.createdAt.toLocal());

    return Material(
      color: item.isRead ? Colors.white.withValues(alpha: 0.92) : const Color(0xFFEFF4FF),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationAvatar(item: item),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.actorUsername ?? _titleForType(context, item.type),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2F67FF),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.isRu ? item.text : _bodyForType(strings, item),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF45556F),
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      createdAt,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleForType(BuildContext context, String type) {
    final strings = AppStrings.of(context);
    return switch (type) {
      'post_like' => strings.isRu ? 'Новый лайк' : 'New like',
      'post_comment' =>
        strings.isRu ? 'Новый комментарий' : 'New comment',
      'comment_reply' =>
        strings.isRu ? 'Ответ на комментарий' : 'Reply to comment',
      'friend_request' =>
        strings.isRu ? 'Заявка в друзья' : 'Friend request',
      'friend_accepted' =>
        strings.isRu ? 'Дружба подтверждена' : 'Friend request accepted',
      'message_reply' =>
        strings.isRu ? 'Ответ в сообщениях' : 'Reply in messages',
      'message' => strings.isRu ? 'Новое сообщение' : 'New message',
      _ => strings.isRu ? 'Уведомление' : 'Notification',
    };
  }

  String _bodyForType(AppStrings strings, NotificationItemModel item) {
    return switch (item.type) {
      'post_like' => 'liked your post',
      'post_comment' => 'commented on your post',
      'comment_reply' => 'replied to your comment',
      'friend_request' => 'sent you a friend request',
      'friend_accepted' => 'accepted your friend request',
      'message_reply' => 'replied in messages',
      'message' => 'sent you a message',
      _ => item.text,
    };
  }
}

class _NotificationAvatar extends StatelessWidget {
  final NotificationItemModel item;

  const _NotificationAvatar({required this.item});

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      'post_like' => Icons.favorite_rounded,
      'post_comment' => Icons.chat_bubble_rounded,
      'comment_reply' => Icons.reply_rounded,
      'friend_request' => Icons.person_add_alt_1_rounded,
      'friend_accepted' => Icons.favorite_rounded,
      'message_reply' => Icons.reply_all_rounded,
      'message' => Icons.forum_rounded,
      _ => Icons.notifications_rounded,
    };

    if (item.actorAvatarUrl != null && item.actorAvatarUrl!.isNotEmpty) {
      return AppAvatar(
        username: item.actorUsername ?? 'Alert',
        imageUrl: item.actorAvatarUrl,
        size: 52,
        circle: false,
        borderRadius: BorderRadius.circular(18),
        scale: item.actorAvatarScale,
        offsetX: item.actorAvatarOffsetX,
        offsetY: item.actorAvatarOffsetY,
      );
    }

    return _FallbackNotificationAvatar(icon: icon);
  }
}

class _FallbackNotificationAvatar extends StatelessWidget {
  final IconData icon;

  const _FallbackNotificationAvatar({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2F67FF),
            Color(0xFF4E9CFF),
          ],
        ),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

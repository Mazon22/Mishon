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
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<NotificationItemModel> _items = const [];
  int _nextPage = 1;
  bool _hasMore = false;
  bool _didMarkAll = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications(initial: true);
  }

  Future<void> _loadNotifications({required bool initial}) async {
    if (initial) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      if (_isLoadingMore || !_hasMore) {
        return;
      }
      setState(() => _isLoadingMore = true);
    }

    try {
      final repository = ref.read(socialRepositoryProvider);
      final pageToLoad = initial ? 1 : _nextPage;
      var response = await repository.getNotificationsPage(
        page: pageToLoad,
        forceRefresh: initial,
      );

      if (initial && !_didMarkAll && response.items.isNotEmpty) {
        await repository.markAllNotificationsRead();
        await ref.read(notificationSummaryProvider.notifier).refresh();
        _didMarkAll = true;
        response = await repository.getNotificationsPage(page: 1, forceRefresh: true);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _items =
            initial
                ? response.items
                : <NotificationItemModel>[..._items, ...response.items];
        _nextPage = response.page + 1;
        _hasMore = response.hasNext;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (error) {
      _setError(initial, error.apiError.message);
    } on OfflineException catch (error) {
      _setError(initial, error.message);
    } catch (_) {
      final strings = AppStrings.of(context);
      _setError(
        initial,
        strings.isRu ? 'Не удалось загрузить уведомления' : 'Could not load notifications',
      );
    }
  }

  void _setError(bool initial, String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  Future<void> _openNotification(NotificationItemModel item) async {
    if (!item.isRead) {
      await ref.read(socialRepositoryProvider).markNotificationRead(item.id);
      await ref.read(notificationSummaryProvider.notifier).refresh();
    }

    if (!mounted) {
      return;
    }

    final type = item.type.toLowerCase();
    if (item.conversationId != null) {
      final params = <String, String>{
        if (item.actorUserId != null) 'peerId': '${item.actorUserId}',
        if ((item.actorUsername ?? '').trim().isNotEmpty)
          'username': item.actorUsername!.trim(),
      };
      final query =
          params.isEmpty
              ? ''
              : '?${params.entries.map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}').join('&')}';
      context.push('/chat/${item.conversationId}$query');
      return;
    }

    if (item.postId != null) {
      final postUserId = item.relatedUserId ?? item.actorUserId ?? 0;
      context.push('/comments/${item.postId}?postUserId=$postUserId');
      return;
    }

    if (type.contains('follow_request')) {
      context.push('/follow-requests');
      return;
    }

    if (item.relatedUserId != null) {
      context.push('/profile/${item.relatedUserId}');
      return;
    }

    context.go('/notifications');
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
            colors: [Color(0xFFF7F6FF), Color(0xFFFFFBF5)],
          ),
        ),
        child:
            _isLoading
                ? const LoadingState()
                : _errorMessage != null
                ? ErrorState(
                  message: _errorMessage!,
                  onRetry: () => _loadNotifications(initial: true),
                )
                : _items.isEmpty
                ? EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: strings.isRu ? 'Пока тихо' : 'Nothing new yet',
                  subtitle:
                      strings.isRu
                          ? 'Новые реакции, запросы и сообщения появятся здесь.'
                          : 'New reactions, requests, and messages will appear here.',
                )
                : RefreshIndicator(
                  onRefresh: () => _loadNotifications(initial: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return FilledButton.tonal(
                          onPressed:
                              _isLoadingMore
                                  ? null
                                  : () => _loadNotifications(initial: false),
                          child:
                              _isLoadingMore
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                  : Text(strings.loadMore),
                        );
                      }

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
      color:
          item.isRead
              ? Colors.white.withValues(alpha: 0.92)
              : const Color(0xFFEFF4FF),
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
      'post_comment' => strings.isRu ? 'Новый комментарий' : 'New comment',
      'comment_reply' =>
        strings.isRu ? 'Ответ на комментарий' : 'Reply to comment',
      'friend_request' =>
        strings.isRu ? 'Заявка в друзья' : 'Friend request',
      'follow_request' =>
        strings.isRu ? 'Запрос на подписку' : 'Follow request',
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
      'follow_request' => 'requested access to your private profile',
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
      'follow_request' => Icons.lock_person_rounded,
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
          colors: [Color(0xFF2F67FF), Color(0xFF4E9CFF)],
        ),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

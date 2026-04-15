import type { NotificationItem } from '../../../shared/types/api';
import type { AppIconName } from '../../../shared/ui/AppIcon';

export type NotificationTab = 'all' | 'mentions';

export function isMentionNotification(item: NotificationItem) {
  return item.type === 'comment';
}

export function getNotificationIconName(item: NotificationItem): AppIconName {
  switch (item.type) {
    case 'message':
      return 'message';
    case 'like':
      return 'heart';
    case 'comment':
      return 'comment';
    case 'friend_request':
    case 'follow_request':
      return 'user-plus';
    case 'friend_accept':
    case 'follow':
      return 'friends';
    default:
      return 'notifications';
  }
}

export function getNotificationEyebrow(item: NotificationItem) {
  switch (item.type) {
    case 'message':
      return 'Сообщение';
    case 'like':
      return 'Лайк';
    case 'comment':
      return 'Комментарий';
    case 'friend_request':
      return 'Запрос в друзья';
    case 'friend_accept':
      return 'Дружба';
    case 'follow_request':
      return 'Запрос на подписку';
    case 'follow':
      return 'Подписка';
    default:
      return 'Уведомление';
  }
}

export function getNotificationRoute(item: NotificationItem) {
  if (item.conversationId) {
    return item.relatedUserId ? `/chats?chatWith=${item.relatedUserId}` : '/chats';
  }

  if (item.postId) {
    return item.commentId ? `/posts/${item.postId}#comment-${item.commentId}` : `/posts/${item.postId}`;
  }

  if (item.relatedUserId) {
    return `/profile/${item.relatedUserId}`;
  }

  return null;
}

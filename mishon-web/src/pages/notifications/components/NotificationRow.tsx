import { formatRelativeDate } from '../../../shared/lib/format';
import type { NotificationItem } from '../../../shared/types/api';
import { AppIcon } from '../../../shared/ui/AppIcon';
import { UserAvatar } from '../../../shared/ui/UserAvatar';
import { getNotificationEyebrow, getNotificationIconName } from '../lib/notificationMeta';

type NotificationRowProps = {
  item: NotificationItem;
  onOpen: (item: NotificationItem) => void;
};

export function NotificationRow({ item, onOpen }: NotificationRowProps) {
  const actorName = item.actor?.displayName || item.actor?.username || null;
  const hasActor = Boolean(item.actor);

  return (
    <button
      className={`notification-row${item.isRead ? '' : ' notification-row--unread'}`}
      type="button"
      onClick={() => onOpen(item)}
    >
      <div className="notification-row__leading">
        {hasActor ? (
          <div className="notification-row__avatar-wrap">
            <UserAvatar
              imageUrl={item.actor?.avatarUrl}
              name={actorName ?? 'Mishon'}
              offsetX={item.actor?.avatarOffsetX}
              offsetY={item.actor?.avatarOffsetY}
              scale={item.actor?.avatarScale}
              size="md"
            />
            <span className="notification-row__badge">
              <AppIcon className="button-icon" name={getNotificationIconName(item)} />
            </span>
          </div>
        ) : (
          <span className="notification-row__glyph">
            <AppIcon className="button-icon" name={getNotificationIconName(item)} />
          </span>
        )}
      </div>

      <div className="notification-row__body">
        <div className="notification-row__meta">
          <span className="notification-row__eyebrow">{getNotificationEyebrow(item)}</span>
          <time className="notification-row__time" dateTime={item.createdAt}>
            {formatRelativeDate(item.createdAt)}
          </time>
        </div>

        <div className="notification-row__text">
          {actorName ? <strong>{actorName}</strong> : null}
          <span>{item.text}</span>
        </div>
      </div>

      {!item.isRead ? <span className="notification-row__dot" aria-hidden="true" /> : null}
    </button>
  );
}

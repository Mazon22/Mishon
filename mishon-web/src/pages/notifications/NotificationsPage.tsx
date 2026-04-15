import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import type { NotificationItem } from '../../shared/types/api';
import { AppIcon } from '../../shared/ui/AppIcon';
import { NotificationRow } from './components/NotificationRow';
import { NotificationTabs } from './components/NotificationTabs';
import { getNotificationRoute, isMentionNotification, type NotificationTab } from './lib/notificationMeta';

export function NotificationsPage() {
  const navigate = useNavigate();
  const { subscribe } = useLiveSync();
  const [items, setItems] = useState<NotificationItem[]>([]);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tab, setTab] = useState<NotificationTab>('all');

  const loadNotifications = useCallback(async (silent = false) => {
    if (!silent) {
      setBusy(true);
    }

    setError(null);

    try {
      const response = await api.notifications.list(1, 50);
      setItems(response.items.filter((item) => item.type !== 'message'));
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить уведомления.');
    } finally {
      if (!silent) {
        setBusy(false);
      }
    }
  }, []);

  useEffect(() => {
    void loadNotifications();
  }, [loadNotifications]);

  useEffect(() => {
    return subscribe((event) => {
      if (event.type === 'notifications.changed' || event.type === 'notification.summary.changed' || event.type === 'sync.resync') {
        void loadNotifications(true);
      }
    });
  }, [loadNotifications, subscribe]);

  const filteredItems = useMemo(
    () => (tab === 'mentions' ? items.filter((item) => isMentionNotification(item)) : items),
    [items, tab],
  );

  async function handleOpen(item: NotificationItem) {
    if (!item.isRead) {
      try {
        await api.notifications.markRead(item.id);
        setItems((current) =>
          current.map((entry) => (entry.id === item.id ? { ...entry, isRead: true } : entry)),
        );
      } catch {
        // Non-blocking.
      }
    }

    const target = getNotificationRoute(item);
    if (target) {
      navigate(target);
    }
  }

  async function handleMarkAllRead() {
    await api.notifications.markAllRead();
    setItems((current) => current.map((item) => ({ ...item, isRead: true })));
  }

  return (
    <div className="timeline notifications-page">
      <header className="notifications-page__top">
        <div className="notifications-page__bar">
          <h1 className="notifications-page__title">Уведомления</h1>

          <div className="notifications-page__actions">
            {items.some((item) => !item.isRead) ? (
              <button className="text-button notifications-page__mark-read" type="button" onClick={() => void handleMarkAllRead()}>
                Прочитать все
              </button>
            ) : null}

            <button
              aria-label="Открыть настройки"
              className="icon-button icon-button--ghost notifications-page__settings"
              type="button"
              onClick={() => navigate('/settings')}
            >
              <AppIcon className="button-icon" name="settings" />
            </button>
          </div>
        </div>

        <NotificationTabs value={tab} onChange={setTab} />
      </header>

      {error ? <div className="error-banner timeline-banner">{error}</div> : null}
      {busy ? <div className="empty-card timeline-banner">Загружаем уведомления...</div> : null}

      {!busy ? (
        <div className="stack-list notifications-page__list">
          {filteredItems.map((item) => (
            <NotificationRow key={item.id} item={item} onOpen={handleOpen} />
          ))}

          {filteredItems.length === 0 ? (
            <div className="empty-card timeline-banner">
              {tab === 'mentions' ? 'Упоминаний пока нет.' : 'Новых уведомлений пока нет.'}
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

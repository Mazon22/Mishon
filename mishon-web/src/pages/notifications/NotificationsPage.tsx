import { useEffect, useState } from 'react';

import { api } from '../../shared/api/api';
import { formatRelativeDate } from '../../shared/lib/format';
import type { NotificationItem } from '../../shared/types/api';

export function NotificationsPage() {
  const [items, setItems] = useState<NotificationItem[]>([]);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setBusy(true);
      setError(null);
      try {
        const response = await api.notifications.list(1, 50);
        if (!cancelled) {
          setItems(response.items);
        }
      } catch (nextError) {
        if (!cancelled) {
          setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить уведомления.');
        }
      } finally {
        if (!cancelled) {
          setBusy(false);
        }
      }
    }

    void load();

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="page-stack">
      <section className="panel">
        <div className="panel__header">
          <div>
            <div className="section-title">Уведомления</div>
            <div className="section-subtitle">Лайки, комментарии, сообщения и новые запросы.</div>
          </div>
          <button
            className="ghost-button"
            type="button"
            onClick={() =>
              void api.notifications.markAllRead().then(() =>
                setItems((current) => current.map((item) => ({ ...item, isRead: true }))),
              )
            }
          >
            Отметить все
          </button>
        </div>

        {error ? <div className="error-banner">{error}</div> : null}

        <div className="stack-list">
          {busy ? <div className="empty-card">Загружаем уведомления...</div> : null}
          {items.map((item) => (
            <button
              key={item.id}
              className={`event-card event-card--wide${item.isRead ? '' : ' event-card--highlight'}`}
              type="button"
              onClick={() =>
                void api.notifications.markRead(item.id).then(() =>
                  setItems((current) =>
                    current.map((entry) => (entry.id === item.id ? { ...entry, isRead: true } : entry)),
                  ),
                )
              }
            >
              <div className="event-card__title">{item.actor?.displayName || item.actor?.username || 'Mishon'}</div>
              <div className="event-card__text">{item.text}</div>
              <div className="event-card__time">{formatRelativeDate(item.createdAt)}</div>
            </button>
          ))}
          {!busy && items.length === 0 ? <div className="empty-card">Новых уведомлений нет.</div> : null}
        </div>
      </section>
    </div>
  );
}

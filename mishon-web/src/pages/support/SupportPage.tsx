import { startTransition, useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import { formatAbsoluteDate, formatCount, formatRelativeDate } from '../../shared/lib/format';
import type { SupportMessage, SupportThread, SupportThreadDetail, SupportThreadStatus } from '../../shared/types/api';
import { AppIcon } from '../../shared/ui/AppIcon';
import { UserAvatar } from '../../shared/ui/UserAvatar';

const filters: Array<{ value: SupportThreadStatus | ''; label: string }> = [
  { value: '', label: 'Все' },
  { value: 'WaitingForAdmin', label: 'Ждут команду' },
  { value: 'WaitingForUser', label: 'Ждут вас' },
  { value: 'Closed', label: 'Закрытые' },
];

function supportStatusLabel(status: SupportThreadStatus) {
  switch (status) {
    case 'WaitingForAdmin':
      return 'Ждёт администратора';
    case 'WaitingForUser':
      return 'Ждёт вас';
    case 'Closed':
      return 'Закрыт';
  }
}

function supportStatusTone(status: SupportThreadStatus) {
  switch (status) {
    case 'WaitingForAdmin':
      return 'warning';
    case 'WaitingForUser':
      return 'accent';
    case 'Closed':
      return 'muted';
  }
}

function uniqueById<T extends { id: number }>(items: T[]) {
  const seen = new Set<number>();
  return items.filter((item) => {
    if (seen.has(item.id)) {
      return false;
    }
    seen.add(item.id);
    return true;
  });
}

function isSupportSyncEvent(type: string) {
  return type === 'support.thread.updated' || type === 'support.message.created' || type === 'sync.resync';
}

function messageAuthor(message: SupportMessage) {
  return message.authorDisplayName || message.authorUsername || (message.isAdminAuthor ? 'Команда Mishon' : 'Вы');
}

export function SupportPage() {
  const { subscribe } = useLiveSync();

  const [notice, setNotice] = useState<{ tone: 'success' | 'error' | 'info'; text: string } | null>(null);
  const [filter, setFilter] = useState<SupportThreadStatus | ''>('');
  const [threads, setThreads] = useState<SupportThread[]>([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [busy, setBusy] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedThreadId, setSelectedThreadId] = useState<number | null>(null);
  const [selectedThreadDetail, setSelectedThreadDetail] = useState<SupportThreadDetail | null>(null);
  const [selectedThreadBusy, setSelectedThreadBusy] = useState(false);
  const [selectedThreadError, setSelectedThreadError] = useState<string | null>(null);
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [createBusy, setCreateBusy] = useState(false);
  const [reply, setReply] = useState('');
  const [replyBusy, setReplyBusy] = useState(false);
  const threadsRef = useRef<SupportThread[]>([]);

  useEffect(() => {
    threadsRef.current = threads;
  }, [threads]);

  const selectedThread = useMemo(
    () => threads.find((item) => item.id === selectedThreadId) ?? selectedThreadDetail?.thread ?? null,
    [selectedThreadDetail, selectedThreadId, threads],
  );

  const threadSnapshot = useMemo(
    () => ({
      visibleCount: threads.length,
      waitingForYouCount: threads.filter((item) => item.status === 'WaitingForUser').length,
      unreadCount: threads.reduce((sum, item) => sum + item.userUnreadCount, 0),
    }),
    [threads],
  );

  const loadThreads = useCallback(async (nextPage: number, append = false) => {
    if (nextPage === 1) {
      setBusy(true);
    } else {
      setLoadingMore(true);
    }

    try {
      const response = await api.support.threads(nextPage, 20, filter);
      const nextItems = append ? uniqueById([...threadsRef.current, ...response.items]) : response.items;
      threadsRef.current = nextItems;
      setThreads(nextItems);
      setHasMore(response.hasMore);
      setError(null);
      setSelectedThreadId((current) => {
        if (current && nextItems.some((item) => item.id === current)) {
          return current;
        }
        return nextItems[0]?.id ?? null;
      });
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить обращения.');
    } finally {
      if (nextPage === 1) {
        setBusy(false);
      } else {
        setLoadingMore(false);
      }
    }
  }, [filter]);

  const loadSelectedThread = useCallback(async (threadId: number, silent = false) => {
    if (!silent) {
      setSelectedThreadBusy(true);
    }

    try {
      const detail = await api.support.thread(threadId);
      setSelectedThreadDetail(detail);
      setSelectedThreadError(null);
    } catch (nextError) {
      setSelectedThreadError(nextError instanceof Error ? nextError.message : 'Не удалось открыть обращение.');
    } finally {
      if (!silent) {
        setSelectedThreadBusy(false);
      }
    }
  }, []);

  useEffect(() => {
    void loadThreads(page, page > 1);
  }, [loadThreads, page]);

  useEffect(() => {
    setPage(1);
  }, [filter]);

  useEffect(() => {
    if (!selectedThreadId) {
      setSelectedThreadDetail(null);
      setSelectedThreadError(null);
      return;
    }
    void loadSelectedThread(selectedThreadId);
  }, [loadSelectedThread, selectedThreadId]);

  useEffect(() => {
    return subscribe((event) => {
      if (!isSupportSyncEvent(event.type)) {
        return;
      }
      void loadThreads(1);
      if (selectedThreadId) {
        void loadSelectedThread(selectedThreadId, true);
      }
    });
  }, [loadSelectedThread, loadThreads, selectedThreadId, subscribe]);

  useEffect(() => {
    if (!selectedThreadDetail || selectedThreadDetail.thread.userUnreadCount === 0) {
      return;
    }

    let cancelled = false;
    void api.support
      .markRead(selectedThreadDetail.thread.id)
      .then(() => {
        if (cancelled) {
          return;
        }
        setSelectedThreadDetail((current) =>
          current
            ? {
                ...current,
                thread: {
                  ...current.thread,
                  userUnreadCount: 0,
                },
              }
            : current,
        );
        void loadThreads(1);
      })
      .catch(() => {
        // Non-blocking.
      });

    return () => {
      cancelled = true;
    };
  }, [loadThreads, selectedThreadDetail]);

  async function handleCreateThread() {
    if (!subject.trim() || !message.trim()) {
      setNotice({ tone: 'error', text: 'Нужны тема и первое сообщение.' });
      return;
    }

    setCreateBusy(true);
    setNotice(null);
    try {
      const detail = await api.support.createThread({
        subject: subject.trim(),
        message: message.trim(),
      });
      setSelectedThreadId(detail.thread.id);
      setSelectedThreadDetail(detail);
      setSubject('');
      setMessage('');
      setNotice({
        tone: 'success',
        text: 'Обращение открыто. Если незакрытый тикет уже существовал, мы вернули его текущий диалог.',
      });
      await loadThreads(1);
    } catch (nextError) {
      setNotice({ tone: 'error', text: nextError instanceof Error ? nextError.message : 'Не удалось открыть обращение.' });
    } finally {
      setCreateBusy(false);
    }
  }

  async function handleReply() {
    if (!selectedThread || !reply.trim()) {
      return;
    }

    setReplyBusy(true);
    setNotice(null);
    try {
      await api.support.reply(selectedThread.id, { message: reply.trim() });
      setReply('');
      setNotice({ tone: 'success', text: selectedThread.status === 'Closed' ? 'Обращение снова открыто и сообщение отправлено.' : 'Сообщение отправлено.' });
      await Promise.all([loadThreads(1), loadSelectedThread(selectedThread.id, true)]);
    } catch (nextError) {
      setNotice({ tone: 'error', text: nextError instanceof Error ? nextError.message : 'Не удалось отправить сообщение.' });
    } finally {
      setReplyBusy(false);
    }
  }

  function renderThreadRow(thread: SupportThread) {
    const isSelected = thread.id === selectedThreadId;
    return (
      <button
        key={thread.id}
        className={`admin-list-row${isSelected ? ' admin-list-row--active' : ''}`}
        type="button"
        onClick={() => startTransition(() => setSelectedThreadId(thread.id))}
      >
        <div className="admin-list-row__body">
          <div className="admin-list-row__headline">
            <strong>{thread.subject}</strong>
            <span>{formatRelativeDate(thread.updatedAt)}</span>
          </div>

          <div className="admin-list-row__meta admin-list-row__meta--support">
            <span className={`status-pill status-pill--${supportStatusTone(thread.status)}`}>{supportStatusLabel(thread.status)}</span>
            <span className="admin-list-row__preview">{thread.lastMessagePreview || 'Без текста'}</span>
            {thread.userUnreadCount > 0 ? <span className="status-pill status-pill--accent">{thread.userUnreadCount} новых</span> : null}
          </div>
        </div>
      </button>
    );
  }

  function renderMessageItem(item: SupportMessage) {
    const author = messageAuthor(item);
    return (
      <article
        key={item.id}
        className={`support-message${item.isMine ? ' support-message--mine' : ''}${item.isAdminAuthor ? ' support-message--admin' : ''}`}
      >
        <div className="support-message__avatar">
          <UserAvatar
            imageUrl={item.authorAvatarUrl}
            name={author}
            offsetX={item.authorAvatarOffsetX}
            offsetY={item.authorAvatarOffsetY}
            scale={item.authorAvatarScale}
            size="sm"
          />
        </div>

        <div className="support-message__card">
          <div className="support-message__header">
            <strong>{author}</strong>
            <span>{item.isAdminAuthor ? 'Команда Mishon' : 'Вы'}</span>
            <time>{formatAbsoluteDate(item.createdAt)}</time>
          </div>
          <p>{item.content}</p>
          {item.readAt ? <small>Прочитано {formatAbsoluteDate(item.readAt)}</small> : null}
        </div>
      </article>
    );
  }

  return (
    <div className="timeline support-page">
      <section className="panel support-page__hero">
        <div className="support-page__hero-copy">
          <div className="support-page__eyebrow">Поддержка</div>
          <h1>Связаться с Mishon</h1>
          <p>Опишите проблему своими словами. Если открытый диалог уже есть, мы просто вернём вас в него вместо создания дубля.</p>
          <div className="admin-page__hero-highlights">
            <span className="admin-hero-chip">Одна очередь для всех обращений</span>
            <span className="admin-hero-chip">Сообщения сохраняются в истории</span>
            <span className="admin-hero-chip">Ответы без ручного обновления</span>
          </div>
          <div className="admin-hero-metrics">
            <div className="admin-hero-metric">
              <span>Всего диалогов</span>
              <strong>{busy ? '...' : formatCount(threadSnapshot.visibleCount)}</strong>
            </div>
            <div className="admin-hero-metric">
              <span>Ждут вас</span>
              <strong>{busy ? '...' : formatCount(threadSnapshot.waitingForYouCount)}</strong>
            </div>
            <div className="admin-hero-metric">
              <span>Непрочитанных</span>
              <strong>{busy ? '...' : formatCount(threadSnapshot.unreadCount)}</strong>
            </div>
          </div>
        </div>
        <div className="support-page__hero-note">
          <AppIcon className="support-page__hero-icon" name="message" />
          <span>Ответы приходят сюда же и синхронизируются без перезагрузки страницы.</span>
        </div>
      </section>

      {notice ? <div className={notice.tone === 'error' ? 'error-banner' : 'info-banner'}>{notice.text}</div> : null}

      <section className="admin-board">
        <div className="panel admin-board__sidebar support-sidebar">
          <div className="admin-panel-heading">
            <div>
              <div className="admin-panel-heading__eyebrow">Ваши обращения</div>
              <h2>Центр поддержки</h2>
            </div>
            <span className="admin-panel-heading__meta">{busy ? 'Обновляем...' : `${formatCount(threadSnapshot.visibleCount)} в списке`}</span>
          </div>

          <div className="support-create-card">
            <h2>Новое обращение</h2>
            <p>Краткая тема и первое сообщение помогут быстрее понять контекст и не потерять детали.</p>

            <label className="admin-field">
              <span>Тема</span>
              <input
                className="input"
                value={subject}
                placeholder="Например: не приходит письмо подтверждения"
                onChange={(event) => setSubject(event.target.value)}
              />
            </label>

            <label className="admin-field">
              <span>Сообщение</span>
              <textarea
                className="input input--area"
                rows={5}
                value={message}
                placeholder="Опишите, что случилось, что вы уже пробовали и на каком аккаунте это заметили."
                onChange={(event) => setMessage(event.target.value)}
              />
            </label>

            <button className="primary-button primary-button--wide" disabled={createBusy} type="button" onClick={() => void handleCreateThread()}>
              {createBusy ? 'Открываем...' : 'Отправить обращение'}
            </button>
          </div>

          <div className="admin-toolbar support-sidebar__toolbar">
            <div className="segmented admin-toolbar__filters">
              {filters.map((item) => (
                <button
                  key={item.value || 'all'}
                  className={filter === item.value ? 'pill-button pill-button--active' : 'pill-button'}
                  type="button"
                  onClick={() => setFilter(item.value)}
                >
                  {item.label}
                </button>
              ))}
            </div>
          </div>

          {error ? <div className="error-banner">{error}</div> : null}
          {busy ? <div className="empty-card">Загружаем ваши обращения...</div> : null}

          {!busy ? (
            <div className="admin-list">
              {threads.map(renderThreadRow)}
              {!threads.length ? <div className="empty-card">Обращений пока нет. Когда напишете в поддержку, диалог появится здесь.</div> : null}
              {hasMore ? (
                <button
                  className="ghost-button ghost-button--wide"
                  disabled={loadingMore}
                  type="button"
                  onClick={() => setPage((current) => current + 1)}
                >
                  {loadingMore ? 'Подгружаем...' : 'Показать ещё'}
                </button>
              ) : null}
            </div>
          ) : null}
        </div>

        <div className="panel admin-board__detail">
          <div className="admin-panel-heading admin-panel-heading--detail">
            <div>
              <div className="admin-panel-heading__eyebrow">Диалог</div>
              <h2>{selectedThread ? selectedThread.subject : 'Откройте обращение'}</h2>
            </div>
            <span className="admin-panel-heading__meta">{selectedThread ? 'История сообщений и ответы команды' : 'Переписка появится справа'}</span>
          </div>

          {selectedThreadBusy ? <div className="empty-card">Загружаем переписку...</div> : null}
          {selectedThreadError ? <div className="error-banner">{selectedThreadError}</div> : null}

          {!selectedThreadBusy && !selectedThreadError && selectedThreadDetail ? (
            <div className="support-thread-view">
              <header className="support-thread-view__header">
                <div className="support-thread-view__identity">
                  <div className="support-thread-view__copy">
                    <h2>{selectedThreadDetail.thread.subject}</h2>
                    <div className="support-thread-view__meta">
                      <span>{formatAbsoluteDate(selectedThreadDetail.thread.createdAt)}</span>
                      <span>Последнее обновление {formatRelativeDate(selectedThreadDetail.thread.updatedAt)}</span>
                    </div>
                    <div className="support-thread-view__badges">
                      <span className={`status-pill status-pill--${supportStatusTone(selectedThreadDetail.thread.status)}`}>
                        {supportStatusLabel(selectedThreadDetail.thread.status)}
                      </span>
                      {selectedThreadDetail.thread.closedAt ? (
                        <span className="status-pill status-pill--muted">Закрыт {formatAbsoluteDate(selectedThreadDetail.thread.closedAt)}</span>
                      ) : null}
                    </div>
                  </div>
                </div>
              </header>

              <div className="support-thread-view__summary">
                <div className="support-thread-view__summary-card">
                  <span>Сообщений</span>
                  <strong>{formatCount(selectedThreadDetail.messages.length)}</strong>
                </div>
                <div className="support-thread-view__summary-card">
                  <span>Статус</span>
                  <strong>{supportStatusLabel(selectedThreadDetail.thread.status)}</strong>
                </div>
                <div className="support-thread-view__summary-card">
                  <span>Непрочитанных</span>
                  <strong>{formatCount(selectedThreadDetail.thread.userUnreadCount)}</strong>
                </div>
              </div>

              <div className="support-thread-view__messages">
                {selectedThreadDetail.messages.length ? (
                  selectedThreadDetail.messages.map(renderMessageItem)
                ) : (
                  <div className="empty-card empty-card--compact">В этом обращении пока нет сообщений.</div>
                )}
              </div>

              <div className="support-thread-view__composer">
                <textarea
                  className="input input--area"
                  disabled={replyBusy}
                  rows={4}
                  value={reply}
                  placeholder={selectedThreadDetail.thread.status === 'Closed' ? 'Новое сообщение снова откроет диалог' : 'Напишите ответ команде поддержки'}
                  onChange={(event) => setReply(event.target.value)}
                />

                <div className="support-thread-view__composer-actions">
                  <span className="admin-inline-note">
                    {selectedThreadDetail.thread.status === 'Closed'
                      ? 'Любое новое сообщение переоткроет тикет'
                      : 'Новые ответы появятся здесь без ручного обновления'}
                  </span>
                  <button className="primary-button" disabled={!reply.trim() || replyBusy} type="button" onClick={() => void handleReply()}>
                    {replyBusy ? 'Отправляем...' : 'Отправить'}
                  </button>
                </div>
              </div>
            </div>
          ) : null}

          {!selectedThreadBusy && !selectedThreadError && !selectedThreadDetail ? (
            <section className="admin-empty-state">
              <div className="admin-empty-state__icon">HELP</div>
              <div className="admin-empty-state__copy">
                <h2>Откройте диалог справа</h2>
                <p>Создайте первое обращение или выберите существующее слева, чтобы увидеть всю переписку и продолжить разговор с командой.</p>
              </div>
            </section>
          ) : null}
        </div>
      </section>
    </div>
  );
}

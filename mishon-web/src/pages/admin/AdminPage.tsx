import { startTransition, useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { useAuth } from '../../app/providers/useAuth';
import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import { formatAbsoluteDate, formatCount, formatRelativeDate } from '../../shared/lib/format';
import { useDebouncedValue } from '../../shared/lib/useDebouncedValue';
import type {
  AdminUserDetail,
  AdminUserSummary,
  AdminUsersFilter,
  SupportMessage,
  SupportThread,
  SupportThreadDetail,
  SupportThreadStatus,
} from '../../shared/types/api';
import { AppIcon } from '../../shared/ui/AppIcon';
import { ContentTabs } from '../../shared/ui/ContentTabs';
import { UserAvatar } from '../../shared/ui/UserAvatar';

type AdminTab = 'users' | 'support';
type FreezePreset = '1d' | '7d' | '30d' | 'custom';

const userFilters: Array<{ value: AdminUsersFilter; label: string }> = [
  { value: 'all', label: 'Все' },
  { value: 'active', label: 'Активные' },
  { value: 'frozen', label: 'Замороженные' },
  { value: 'admins', label: 'Админы' },
  { value: 'moderators', label: 'Модераторы' },
];

const supportFilters: Array<{ value: SupportThreadStatus | ''; label: string }> = [
  { value: '', label: 'Все' },
  { value: 'WaitingForAdmin', label: 'Ждут ответа' },
  { value: 'WaitingForUser', label: 'Ждут пользователя' },
  { value: 'Closed', label: 'Закрытые' },
];

const adminTabs: Array<{ value: AdminTab; label: string }> = [
  { value: 'users', label: 'Пользователи' },
  { value: 'support', label: 'Поддержка' },
];

const freezePresets: Array<{ value: FreezePreset; label: string }> = [
  { value: '1d', label: '1 день' },
  { value: '7d', label: '7 дней' },
  { value: '30d', label: '30 дней' },
  { value: 'custom', label: 'Своя дата' },
];

function roleLabel(role: string) {
  switch (role) {
    case 'Admin':
      return 'Админ';
    case 'Moderator':
      return 'Модератор';
    default:
      return 'Пользователь';
  }
}

function supportStatusLabel(status: SupportThreadStatus) {
  switch (status) {
    case 'WaitingForAdmin':
      return 'Ждёт администратора';
    case 'WaitingForUser':
      return 'Ждёт пользователя';
    case 'Closed':
      return 'Закрыт';
  }
}

function supportStatusTone(status: SupportThreadStatus) {
  switch (status) {
    case 'WaitingForAdmin':
      return 'warning';
    case 'WaitingForUser':
      return 'info';
    case 'Closed':
      return 'muted';
  }
}

function accountStatusLabel(user: AdminUserSummary) {
  if (user.status === 'Frozen' && user.suspendedUntil) {
    return `Заморожен до ${formatAbsoluteDate(user.suspendedUntil)}`;
  }
  if (user.status === 'Banned' && user.bannedAt) {
    return `Заблокирован ${formatAbsoluteDate(user.bannedAt)}`;
  }
  if (user.status === 'Admin') {
    return 'Администратор';
  }
  if (user.status === 'Moderator') {
    return 'Модератор';
  }
  return 'Активен';
}

function accountStatusTone(status: string) {
  switch (status) {
    case 'Frozen':
      return 'warning';
    case 'Banned':
      return 'danger';
    case 'Admin':
    case 'Moderator':
      return 'accent';
    default:
      return 'success';
  }
}

function moderationActionLabel(actionType: string) {
  switch (actionType) {
    case 'Freeze':
      return 'Заморозка';
    case 'Unfreeze':
      return 'Разморозка';
    case 'HardDelete':
      return 'Удаление аккаунта';
    case 'Warn':
      return 'Предупреждение';
    case 'Suspend':
      return 'Ограничение доступа';
    case 'Ban':
      return 'Блокировка';
    case 'Unban':
      return 'Снятие блокировки';
    default:
      return actionType;
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

function toLocalDateTimeValue(date: Date) {
  const next = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return next.toISOString().slice(0, 16);
}

function resolveFreezeUntil(preset: FreezePreset, customValue: string) {
  if (preset === 'custom') {
    return customValue ? new Date(customValue).toISOString() : null;
  }

  const next = new Date();
  switch (preset) {
    case '1d':
      next.setDate(next.getDate() + 1);
      break;
    case '7d':
      next.setDate(next.getDate() + 7);
      break;
    case '30d':
      next.setDate(next.getDate() + 30);
      break;
    default:
      break;
  }
  return next.toISOString();
}

function isSupportSyncEvent(type: string) {
  return type === 'support.thread.updated' || type === 'support.message.created' || type === 'sync.resync';
}

function personName(message: SupportMessage) {
  return message.authorDisplayName || message.authorUsername || (message.isAdminAuthor ? 'Администратор' : 'Пользователь');
}

export function AdminPage() {
  const { profile } = useAuth();
  const { subscribe } = useLiveSync();
  const currentAdminId = profile?.id ?? 0;

  const [activeTab, setActiveTab] = useState<AdminTab>('users');
  const [notice, setNotice] = useState<{ tone: 'success' | 'error' | 'info'; text: string } | null>(null);

  const [userFilter, setUserFilter] = useState<AdminUsersFilter>('all');
  const [userQuery, setUserQuery] = useState('');
  const debouncedUserQuery = useDebouncedValue(userQuery.trim(), 280);
  const [users, setUsers] = useState<AdminUserSummary[]>([]);
  const [usersPage, setUsersPage] = useState(1);
  const [usersHasMore, setUsersHasMore] = useState(false);
  const [usersBusy, setUsersBusy] = useState(true);
  const [usersLoadingMore, setUsersLoadingMore] = useState(false);
  const [usersError, setUsersError] = useState<string | null>(null);
  const [selectedUserId, setSelectedUserId] = useState<number | null>(null);
  const [selectedUserDetail, setSelectedUserDetail] = useState<AdminUserDetail | null>(null);
  const [selectedUserBusy, setSelectedUserBusy] = useState(false);
  const [selectedUserError, setSelectedUserError] = useState<string | null>(null);
  const usersRef = useRef<AdminUserSummary[]>([]);

  const [freezeOpen, setFreezeOpen] = useState(false);
  const [freezePreset, setFreezePreset] = useState<FreezePreset>('7d');
  const [freezeCustomValue, setFreezeCustomValue] = useState(() => toLocalDateTimeValue(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)));
  const [freezeNote, setFreezeNote] = useState('');
  const [freezeBusy, setFreezeBusy] = useState(false);

  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleteNote, setDeleteNote] = useState('');
  const [deleteConfirmValue, setDeleteConfirmValue] = useState('');
  const [deleteBusy, setDeleteBusy] = useState(false);

  const [supportFilter, setSupportFilter] = useState<SupportThreadStatus | ''>('');
  const [supportQuery, setSupportQuery] = useState('');
  const debouncedSupportQuery = useDebouncedValue(supportQuery.trim(), 280);
  const [supportThreads, setSupportThreads] = useState<SupportThread[]>([]);
  const [supportPage, setSupportPage] = useState(1);
  const [supportHasMore, setSupportHasMore] = useState(false);
  const [supportBusy, setSupportBusy] = useState(true);
  const [supportLoadingMore, setSupportLoadingMore] = useState(false);
  const [supportError, setSupportError] = useState<string | null>(null);
  const [selectedSupportThreadId, setSelectedSupportThreadId] = useState<number | null>(null);
  const [selectedSupportDetail, setSelectedSupportDetail] = useState<SupportThreadDetail | null>(null);
  const [selectedSupportBusy, setSelectedSupportBusy] = useState(false);
  const [selectedSupportError, setSelectedSupportError] = useState<string | null>(null);
  const [supportReply, setSupportReply] = useState('');
  const [supportReplyBusy, setSupportReplyBusy] = useState(false);
  const supportThreadsRef = useRef<SupportThread[]>([]);

  useEffect(() => {
    usersRef.current = users;
  }, [users]);

  useEffect(() => {
    supportThreadsRef.current = supportThreads;
  }, [supportThreads]);

  const selectedUser = useMemo(
    () => users.find((item) => item.id === selectedUserId) ?? selectedUserDetail?.user ?? null,
    [selectedUserDetail, selectedUserId, users],
  );

  const selectedThread = useMemo(
    () => supportThreads.find((item) => item.id === selectedSupportThreadId) ?? selectedSupportDetail?.thread ?? null,
    [selectedSupportDetail, selectedSupportThreadId, supportThreads],
  );

  const deleteHandle = selectedUser ? `@${selectedUser.username}` : '';
  const canDelete = Boolean(selectedUser && deleteConfirmValue.trim() === deleteHandle && deleteNote.trim());
  const freezeUntil = resolveFreezeUntil(freezePreset, freezeCustomValue);
  const currentAdminLabel = profile?.displayName || profile?.username || 'Текущий администратор';

  const userSnapshot = useMemo(
    () => ({
      visibleCount: users.length,
      frozenCount: users.filter((item) => item.status === 'Frozen').length,
      supportLoad: users.reduce((sum, item) => sum + item.openSupportThreads, 0),
    }),
    [users],
  );

  const supportSnapshot = useMemo(
    () => ({
      visibleCount: supportThreads.length,
      waitingCount: supportThreads.filter((item) => item.status === 'WaitingForAdmin').length,
      unreadCount: supportThreads.reduce((sum, item) => sum + item.adminUnreadCount, 0),
    }),
    [supportThreads],
  );

  const heroMetrics = useMemo(
    () =>
      activeTab === 'users'
        ? [
            { label: 'В выборке', value: usersBusy ? '...' : formatCount(userSnapshot.visibleCount) },
            { label: 'Заморожено', value: usersBusy ? '...' : formatCount(userSnapshot.frozenCount) },
            { label: 'Открытых обращений', value: usersBusy ? '...' : formatCount(userSnapshot.supportLoad) },
          ]
        : [
            { label: 'Диалогов в очереди', value: supportBusy ? '...' : formatCount(supportSnapshot.visibleCount) },
            { label: 'Ждут ответа', value: supportBusy ? '...' : formatCount(supportSnapshot.waitingCount) },
            { label: 'Непрочитанных', value: supportBusy ? '...' : formatCount(supportSnapshot.unreadCount) },
          ],
    [activeTab, supportBusy, supportSnapshot, userSnapshot, usersBusy],
  );

  const loadUsers = useCallback(
    async (page: number, append = false) => {
      if (page === 1) {
        setUsersBusy(true);
      } else {
        setUsersLoadingMore(true);
      }

      try {
        const response = await api.admin.users(page, 25, userFilter, debouncedUserQuery);
        const nextItems = append ? uniqueById([...usersRef.current, ...response.items]) : response.items;
        usersRef.current = nextItems;
        setUsers(nextItems);
        setUsersHasMore(response.hasMore);
        setUsersError(null);
        setSelectedUserId((current) => {
          if (current && nextItems.some((item) => item.id === current)) {
            return current;
          }
          return nextItems[0]?.id ?? null;
        });
      } catch (error) {
        setUsersError(error instanceof Error ? error.message : 'Не удалось загрузить список пользователей.');
      } finally {
        if (page === 1) {
          setUsersBusy(false);
        } else {
          setUsersLoadingMore(false);
        }
      }
    },
    [debouncedUserQuery, userFilter],
  );

  const loadSelectedUserDetail = useCallback(async (userId: number, silent = false) => {
    if (!silent) {
      setSelectedUserBusy(true);
    }

    try {
      const detail = await api.admin.userDetail(userId);
      setSelectedUserDetail(detail);
      setSelectedUserError(null);
    } catch (error) {
      setSelectedUserError(error instanceof Error ? error.message : 'Не удалось загрузить данные пользователя.');
    } finally {
      if (!silent) {
        setSelectedUserBusy(false);
      }
    }
  }, []);

  const loadSupportThreads = useCallback(
    async (page: number, append = false) => {
      if (page === 1) {
        setSupportBusy(true);
      } else {
        setSupportLoadingMore(true);
      }

      try {
        const response = await api.admin.supportThreads(page, 20, supportFilter, debouncedSupportQuery);
        const nextItems = append ? uniqueById([...supportThreadsRef.current, ...response.items]) : response.items;
        supportThreadsRef.current = nextItems;
        setSupportThreads(nextItems);
        setSupportHasMore(response.hasMore);
        setSupportError(null);
        setSelectedSupportThreadId((current) => {
          if (current && nextItems.some((item) => item.id === current)) {
            return current;
          }
          return nextItems[0]?.id ?? null;
        });
      } catch (error) {
        setSupportError(error instanceof Error ? error.message : 'Не удалось загрузить обращения.');
      } finally {
        if (page === 1) {
          setSupportBusy(false);
        } else {
          setSupportLoadingMore(false);
        }
      }
    },
    [debouncedSupportQuery, supportFilter],
  );

  const loadSelectedSupportDetail = useCallback(async (threadId: number, silent = false) => {
    if (!silent) {
      setSelectedSupportBusy(true);
    }

    try {
      const detail = await api.admin.supportThread(threadId);
      setSelectedSupportDetail(detail);
      setSelectedSupportError(null);
    } catch (error) {
      setSelectedSupportError(error instanceof Error ? error.message : 'Не удалось загрузить переписку.');
    } finally {
      if (!silent) {
        setSelectedSupportBusy(false);
      }
    }
  }, []);

  useEffect(() => {
    if (activeTab !== 'users') {
      return;
    }
    void loadUsers(usersPage, usersPage > 1);
  }, [activeTab, loadUsers, usersPage]);

  useEffect(() => {
    if (activeTab !== 'support') {
      return;
    }
    void loadSupportThreads(supportPage, supportPage > 1);
  }, [activeTab, loadSupportThreads, supportPage]);

  useEffect(() => {
    setUsersPage(1);
  }, [debouncedUserQuery, userFilter]);

  useEffect(() => {
    setSupportPage(1);
  }, [debouncedSupportQuery, supportFilter]);

  useEffect(() => {
    if (!selectedUserId) {
      setSelectedUserDetail(null);
      setSelectedUserError(null);
      return;
    }
    void loadSelectedUserDetail(selectedUserId);
  }, [loadSelectedUserDetail, selectedUserId]);

  useEffect(() => {
    if (!selectedSupportThreadId) {
      setSelectedSupportDetail(null);
      setSelectedSupportError(null);
      return;
    }
    void loadSelectedSupportDetail(selectedSupportThreadId);
  }, [loadSelectedSupportDetail, selectedSupportThreadId]);

  useEffect(() => {
    return subscribe((event) => {
      if (event.type === 'admin.user.updated') {
        void loadUsers(1);
        if (selectedUserId) {
          void loadSelectedUserDetail(selectedUserId, true);
        }
        return;
      }

      if (isSupportSyncEvent(event.type)) {
        if (activeTab === 'support') {
          void loadSupportThreads(1);
          if (selectedSupportThreadId) {
            void loadSelectedSupportDetail(selectedSupportThreadId, true);
          }
        }
        if (selectedUserId) {
          void loadSelectedUserDetail(selectedUserId, true);
        }
      }
    });
  }, [
    activeTab,
    loadSelectedSupportDetail,
    loadSelectedUserDetail,
    loadSupportThreads,
    loadUsers,
    selectedSupportThreadId,
    selectedUserId,
    subscribe,
  ]);

  function resetFreezeDialog() {
    setFreezePreset('7d');
    setFreezeCustomValue(toLocalDateTimeValue(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)));
    setFreezeNote('');
    setFreezeOpen(false);
  }

  function resetDeleteDialog() {
    setDeleteNote('');
    setDeleteConfirmValue('');
    setDeleteOpen(false);
  }

  async function handleFreezeUser() {
    if (!selectedUser || !freezeUntil) {
      return;
    }

    setFreezeBusy(true);
    setNotice(null);
    try {
      await api.admin.freezeUser(selectedUser.id, {
        until: freezeUntil,
        note: freezeNote.trim(),
      });
      setNotice({ tone: 'success', text: `Аккаунт ${deleteHandle || '@user'} заморожен.` });
      resetFreezeDialog();
      await Promise.all([loadUsers(1), loadSelectedUserDetail(selectedUser.id, true)]);
    } catch (error) {
      setNotice({ tone: 'error', text: error instanceof Error ? error.message : 'Не удалось заморозить аккаунт.' });
    } finally {
      setFreezeBusy(false);
    }
  }

  async function handleUnfreezeUser() {
    if (!selectedUser) {
      return;
    }

    setNotice(null);
    try {
      await api.admin.unfreezeUser(selectedUser.id);
      setNotice({ tone: 'success', text: `Аккаунт ${deleteHandle || '@user'} снова активен.` });
      await Promise.all([loadUsers(1), loadSelectedUserDetail(selectedUser.id, true)]);
    } catch (error) {
      setNotice({ tone: 'error', text: error instanceof Error ? error.message : 'Не удалось снять заморозку.' });
    }
  }

  async function handleHardDeleteUser() {
    if (!selectedUser || !canDelete) {
      return;
    }

    const deletedId = selectedUser.id;
    setDeleteBusy(true);
    setNotice(null);
    try {
      await api.admin.hardDeleteUser(deletedId, { note: deleteNote.trim() });
      setNotice({ tone: 'success', text: `Аккаунт ${deleteHandle} удалён навсегда.` });
      resetDeleteDialog();
      setSelectedUserDetail(null);
      setSelectedUserId(null);
      await loadUsers(1);
    } catch (error) {
      setNotice({ tone: 'error', text: error instanceof Error ? error.message : 'Не удалось удалить аккаунт.' });
    } finally {
      setDeleteBusy(false);
    }
  }

  async function handleAdminReply() {
    if (!selectedThread || !supportReply.trim()) {
      return;
    }

    setSupportReplyBusy(true);
    setNotice(null);
    try {
      await api.admin.replySupportThread(selectedThread.id, { message: supportReply.trim() });
      setSupportReply('');
      setNotice({ tone: 'success', text: 'Ответ отправлен.' });
      await Promise.all([loadSupportThreads(1), loadSelectedSupportDetail(selectedThread.id, true)]);
    } catch (error) {
      setNotice({ tone: 'error', text: error instanceof Error ? error.message : 'Не удалось отправить ответ.' });
    } finally {
      setSupportReplyBusy(false);
    }
  }

  async function handleCloseThread() {
    if (!selectedThread) {
      return;
    }

    setNotice(null);
    try {
      await api.admin.closeSupportThread(selectedThread.id);
      setNotice({ tone: 'info', text: 'Обращение закрыто.' });
      await Promise.all([loadSupportThreads(1), loadSelectedSupportDetail(selectedThread.id, true)]);
    } catch (error) {
      setNotice({ tone: 'error', text: error instanceof Error ? error.message : 'Не удалось закрыть обращение.' });
    }
  }

  async function handleReopenThread() {
    if (!selectedThread) {
      return;
    }

    setNotice(null);
    try {
      await api.admin.reopenSupportThread(selectedThread.id);
      setNotice({ tone: 'success', text: 'Обращение снова открыто.' });
      await Promise.all([loadSupportThreads(1), loadSelectedSupportDetail(selectedThread.id, true)]);
    } catch (error) {
      setNotice({ tone: 'error', text: error instanceof Error ? error.message : 'Не удалось переоткрыть обращение.' });
    }
  }

  function renderUserRow(user: AdminUserSummary) {
    const isSelected = user.id === selectedUserId;
    return (
      <button
        key={user.id}
        className={`admin-list-row${isSelected ? ' admin-list-row--active' : ''}`}
        type="button"
        onClick={() => startTransition(() => setSelectedUserId(user.id))}
      >
        <UserAvatar
          imageUrl={user.avatarUrl}
          name={user.displayName || user.username}
          offsetX={user.avatarOffsetX}
          offsetY={user.avatarOffsetY}
          scale={user.avatarScale}
          size="lg"
        />

        <div className="admin-list-row__body">
          <div className="admin-list-row__headline">
            <strong>{user.displayName || user.username}</strong>
            <span>@{user.username}</span>
          </div>

          <div className="admin-list-row__subline">
            <span>{user.email}</span>
            <span>{roleLabel(user.role)}</span>
          </div>

          <div className="admin-list-row__meta">
            <span className={`status-pill status-pill--${accountStatusTone(user.status)}`}>{accountStatusLabel(user)}</span>
            <span>{formatCount(user.postsCount)} постов</span>
            <span>{user.activeSessionsCount} сессий</span>
            <span>{user.openSupportThreads} тикетов</span>
          </div>
        </div>
      </button>
    );
  }

  function renderSupportRow(thread: SupportThread) {
    const isSelected = thread.id === selectedSupportThreadId;
    const threadName = thread.user?.displayName || thread.user?.username || `#${thread.id}`;

    return (
      <button
        key={thread.id}
        className={`admin-list-row${isSelected ? ' admin-list-row--active' : ''}`}
        type="button"
        onClick={() => startTransition(() => setSelectedSupportThreadId(thread.id))}
      >
        <UserAvatar
          imageUrl={thread.user?.avatarUrl}
          name={threadName}
          offsetX={thread.user?.avatarOffsetX}
          offsetY={thread.user?.avatarOffsetY}
          scale={thread.user?.avatarScale}
          size="lg"
        />

        <div className="admin-list-row__body">
          <div className="admin-list-row__headline">
            <strong>{thread.subject}</strong>
            <span>{formatRelativeDate(thread.lastMessageAt)}</span>
          </div>

          <div className="admin-list-row__subline">
            <span>{thread.user?.username ? `@${thread.user.username}` : threadName}</span>
            <span>{thread.user?.email || roleLabel(thread.user?.role || 'User')}</span>
          </div>

          <div className="admin-list-row__meta admin-list-row__meta--support">
            <span className={`status-pill status-pill--${supportStatusTone(thread.status)}`}>{supportStatusLabel(thread.status)}</span>
            <span className="admin-list-row__preview">{thread.lastMessagePreview || 'Без текста'}</span>
            {thread.adminUnreadCount > 0 ? <span className="status-pill status-pill--accent">{thread.adminUnreadCount} новых</span> : null}
          </div>
        </div>
      </button>
    );
  }

  function renderMessage(message: SupportMessage) {
    const author = personName(message);
    const messageRole = message.isAdminAuthor ? 'Команда Mishon' : 'Пользователь';

    return (
      <article
        key={message.id}
        className={`support-message${message.isMine ? ' support-message--mine' : ''}${message.isAdminAuthor ? ' support-message--admin' : ''}`}
      >
        <div className="support-message__avatar">
          <UserAvatar
            imageUrl={message.authorAvatarUrl}
            name={author}
            offsetX={message.authorAvatarOffsetX}
            offsetY={message.authorAvatarOffsetY}
            scale={message.authorAvatarScale}
            size="sm"
          />
        </div>

        <div className="support-message__card">
          <div className="support-message__header">
            <strong>{author}</strong>
            <span>{message.authorUsername ? `@${message.authorUsername}` : messageRole}</span>
            <time>{formatAbsoluteDate(message.createdAt)}</time>
          </div>
          <p>{message.content}</p>
          {message.readAt ? <small>Прочитано {formatAbsoluteDate(message.readAt)}</small> : null}
        </div>
      </article>
    );
  }

  return (
    <>
      <div className="timeline admin-page">
        <section className="panel admin-page__hero">
          <div className="admin-page__hero-copy">
            <div className="admin-page__eyebrow">Управление платформой</div>
            <h1>Админ-панель Mishon</h1>
            <p>Пользователи, ограничения доступа и поддержка в одном рабочем пространстве. Карточки и очереди обновляются без перезагрузки страницы.</p>
            <div className="admin-page__hero-highlights">
              <span className="admin-hero-chip">Обновления в реальном времени</span>
              <span className="admin-hero-chip">История модерации под рукой</span>
              <span className="admin-hero-chip">Единый центр поддержки</span>
            </div>
            <div className="admin-hero-metrics">
              {heroMetrics.map((metric) => (
                <div key={metric.label} className="admin-hero-metric">
                  <span>{metric.label}</span>
                  <strong>{metric.value}</strong>
                </div>
              ))}
            </div>
          </div>

          <div className="admin-page__hero-side">
            <div className="admin-page__hero-card">
              <span className="admin-page__hero-card-label">Сейчас в панели</span>
              <strong>{currentAdminLabel}</strong>
              <span>{profile?.username ? `@${profile.username} • ${roleLabel(profile?.role || 'Admin')}` : roleLabel(profile?.role || 'Admin')}</span>
            </div>
            <ContentTabs ariaLabel="Разделы админки" className="admin-page__tabs" items={adminTabs} value={activeTab} onChange={setActiveTab} />
          </div>
        </section>

        {notice ? <div className={notice.tone === 'error' ? 'error-banner' : 'info-banner'}>{notice.text}</div> : null}
        {activeTab === 'users' ? (
          <section className="admin-board">
            <div className="panel admin-board__sidebar">
              <div className="admin-panel-heading">
                <div>
                  <div className="admin-panel-heading__eyebrow">Люди</div>
                  <h2>Реестр аккаунтов</h2>
                </div>
                <span className="admin-panel-heading__meta">{usersBusy ? 'Обновляем...' : `${formatCount(userSnapshot.visibleCount)} в выборке`}</span>
              </div>

              <div className="admin-toolbar">
                <div className="admin-toolbar__search">
                  <AppIcon className="admin-toolbar__icon" name="search" />
                  <input
                    className="input admin-toolbar__input"
                    value={userQuery}
                    placeholder="Поиск по имени, @username или email"
                    onChange={(event) => setUserQuery(event.target.value)}
                  />
                </div>

                <div className="segmented admin-toolbar__filters">
                  {userFilters.map((filter) => (
                    <button
                      key={filter.value}
                      className={userFilter === filter.value ? 'pill-button pill-button--active' : 'pill-button'}
                      type="button"
                      onClick={() => setUserFilter(filter.value)}
                    >
                      {filter.label}
                    </button>
                  ))}
                </div>
              </div>

              {usersError ? <div className="error-banner">{usersError}</div> : null}
              {usersBusy ? <div className="empty-card">Загружаем список пользователей...</div> : null}

              {!usersBusy ? (
                <div className="admin-list">
                  {users.map(renderUserRow)}
                  {!users.length ? <div className="empty-card">Никого не нашли по текущему фильтру.</div> : null}
                  {usersHasMore ? (
                    <button
                      className="ghost-button ghost-button--wide"
                      disabled={usersLoadingMore}
                      type="button"
                      onClick={() => setUsersPage((current) => current + 1)}
                    >
                      {usersLoadingMore ? 'Подгружаем...' : 'Показать ещё'}
                    </button>
                  ) : null}
                </div>
              ) : null}
            </div>

            <div className="panel admin-board__detail">
              <div className="admin-panel-heading admin-panel-heading--detail">
                <div>
                  <div className="admin-panel-heading__eyebrow">Карточка</div>
                  <h2>{selectedUser ? `@${selectedUser.username}` : 'Выберите аккаунт'}</h2>
                </div>
                <span className="admin-panel-heading__meta">{selectedUser ? 'Профиль, сессии и история действий' : 'Детали откроются справа'}</span>
              </div>

              {selectedUserBusy ? <div className="empty-card">Загружаем карточку пользователя...</div> : null}
              {selectedUserError ? <div className="error-banner">{selectedUserError}</div> : null}

              {!selectedUserBusy && !selectedUserError && selectedUserDetail ? (
                <div className="admin-detail">
                  <div className="admin-detail__hero">
                    <div className="admin-detail__identity">
                      <UserAvatar
                        imageUrl={selectedUserDetail.user.avatarUrl}
                        name={selectedUserDetail.user.displayName || selectedUserDetail.user.username}
                        offsetX={selectedUserDetail.user.avatarOffsetX}
                        offsetY={selectedUserDetail.user.avatarOffsetY}
                        scale={selectedUserDetail.user.avatarScale}
                        size="xl"
                      />

                      <div className="admin-detail__copy">
                        <h2>{selectedUserDetail.user.displayName || selectedUserDetail.user.username}</h2>
                        <div className="admin-detail__handles">
                          <span>@{selectedUserDetail.user.username}</span>
                          <span>{selectedUserDetail.user.email}</span>
                        </div>
                        <div className="admin-detail__badges">
                          <span className="status-pill status-pill--accent">{roleLabel(selectedUserDetail.user.role)}</span>
                          <span className={`status-pill status-pill--${accountStatusTone(selectedUserDetail.user.status)}`}>
                            {accountStatusLabel(selectedUserDetail.user)}
                          </span>
                          {selectedUserDetail.user.isEmailVerified ? (
                            <span className="status-pill status-pill--success">Email подтверждён</span>
                          ) : (
                            <span className="status-pill status-pill--muted">Email не подтверждён</span>
                          )}
                        </div>
                      </div>
                    </div>

                    <div className="admin-detail__actions">
                      {selectedUserDetail.user.id !== currentAdminId ? (
                        <>
                          {selectedUserDetail.user.status === 'Frozen' ? (
                            <button className="ghost-button" type="button" onClick={() => void handleUnfreezeUser()}>
                              Снять заморозку
                            </button>
                          ) : (
                            <button className="ghost-button" type="button" onClick={() => setFreezeOpen(true)}>
                              Заморозить аккаунт
                            </button>
                          )}

                          <button className="ghost-button admin-danger-button" type="button" onClick={() => setDeleteOpen(true)}>
                            Удалить аккаунт
                          </button>
                        </>
                      ) : (
                        <div className="admin-inline-note">Для текущего администратора действия над собственным аккаунтом отключены.</div>
                      )}
                    </div>
                  </div>

                  <div className="admin-metrics">
                    <div className="admin-metric-card">
                      <span>Посты</span>
                      <strong>{formatCount(selectedUserDetail.user.postsCount)}</strong>
                    </div>
                    <div className="admin-metric-card">
                      <span>Подписчики</span>
                      <strong>{formatCount(selectedUserDetail.user.followersCount)}</strong>
                    </div>
                    <div className="admin-metric-card">
                      <span>Подписок</span>
                      <strong>{formatCount(selectedUserDetail.user.followingCount)}</strong>
                    </div>
                    <div className="admin-metric-card">
                      <span>Активные сессии</span>
                      <strong>{selectedUserDetail.user.activeSessionsCount}</strong>
                    </div>
                  </div>

                  <div className="admin-info-grid">
                    <section className="admin-info-card">
                      <h3>Профиль</h3>
                      <dl>
                        <div>
                          <dt>Создан</dt>
                          <dd>{formatAbsoluteDate(selectedUserDetail.user.createdAt)}</dd>
                        </div>
                        <div>
                          <dt>Последняя активность</dt>
                          <dd>{formatRelativeDate(selectedUserDetail.user.lastSeenAt)}</dd>
                        </div>
                        <div>
                          <dt>О себе</dt>
                          <dd>{selectedUserDetail.user.aboutMe || 'Описание не заполнено.'}</dd>
                        </div>
                      </dl>
                    </section>

                    <section className="admin-info-card">
                      <h3>Последние модерации</h3>
                      {selectedUserDetail.recentModerationActions.length ? (
                        <div className="admin-activity-list">
                          {selectedUserDetail.recentModerationActions.map((action) => (
                            <div key={action.id} className="admin-activity-row">
                              <div>
                                <strong>{moderationActionLabel(action.actionType)}</strong>
                                <span>{action.note || (action.expiresAt ? `До ${formatAbsoluteDate(action.expiresAt)}` : 'Без заметки')}</span>
                              </div>
                              <div>
                                <time>{formatAbsoluteDate(action.createdAt)}</time>
                                <small>{action.actorUsername ? `@${action.actorUsername}` : 'Система'}</small>
                              </div>
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="empty-card empty-card--compact">Модерационных действий пока не было.</div>
                      )}
                    </section>

                    <section className="admin-info-card admin-info-card--wide">
                      <h3>Последние обращения</h3>
                      {selectedUserDetail.recentSupportThreads.length ? (
                        <div className="admin-activity-list">
                          {selectedUserDetail.recentSupportThreads.map((thread) => (
                            <button
                              key={thread.id}
                              className="admin-thread-compact"
                              type="button"
                              onClick={() => {
                                startTransition(() => setActiveTab('support'));
                                setSelectedSupportThreadId(thread.id);
                              }}
                            >
                              <div>
                                <strong>{thread.subject}</strong>
                                <span>{thread.lastMessagePreview || 'Без текста'}</span>
                              </div>
                              <div>
                                <span className={`status-pill status-pill--${supportStatusTone(thread.status)}`}>{supportStatusLabel(thread.status)}</span>
                                <time>{formatRelativeDate(thread.updatedAt)}</time>
                              </div>
                            </button>
                          ))}
                        </div>
                      ) : (
                        <div className="empty-card empty-card--compact">Открытых и недавних тикетов у пользователя нет.</div>
                      )}
                    </section>
                  </div>
                </div>
              ) : null}

              {!selectedUserBusy && !selectedUserError && !selectedUserDetail ? (
                <section className="admin-empty-state">
                  <div className="admin-empty-state__icon">ADM</div>
                  <div className="admin-empty-state__copy">
                    <h2>Выберите пользователя</h2>
                    <p>Слева откроется список аккаунтов. После выбора появятся активные сессии, история модерации и обращения в поддержку.</p>
                  </div>
                </section>
              ) : null}
            </div>
          </section>
        ) : (
          <section className="admin-board">
            <div className="panel admin-board__sidebar">
              <div className="admin-panel-heading">
                <div>
                  <div className="admin-panel-heading__eyebrow">Поддержка</div>
                  <h2>Очередь обращений</h2>
                </div>
                <span className="admin-panel-heading__meta">{supportBusy ? 'Обновляем...' : `${formatCount(supportSnapshot.visibleCount)} в очереди`}</span>
              </div>

              <div className="admin-toolbar">
                <div className="admin-toolbar__search">
                  <AppIcon className="admin-toolbar__icon" name="search" />
                  <input
                    className="input admin-toolbar__input"
                    value={supportQuery}
                    placeholder="Поиск по теме, @username или email"
                    onChange={(event) => setSupportQuery(event.target.value)}
                  />
                </div>

                <div className="segmented admin-toolbar__filters">
                  {supportFilters.map((filter) => (
                    <button
                      key={filter.value || 'all'}
                      className={supportFilter === filter.value ? 'pill-button pill-button--active' : 'pill-button'}
                      type="button"
                      onClick={() => setSupportFilter(filter.value)}
                    >
                      {filter.label}
                    </button>
                  ))}
                </div>
              </div>

              {supportError ? <div className="error-banner">{supportError}</div> : null}
              {supportBusy ? <div className="empty-card">Загружаем очередь поддержки...</div> : null}

              {!supportBusy ? (
                <div className="admin-list">
                  {supportThreads.map(renderSupportRow)}
                  {!supportThreads.length ? <div className="empty-card">Сейчас новых обращений нет. Как только кто-то напишет в поддержку, диалог появится здесь.</div> : null}
                  {supportHasMore ? (
                    <button
                      className="ghost-button ghost-button--wide"
                      disabled={supportLoadingMore}
                      type="button"
                      onClick={() => setSupportPage((current) => current + 1)}
                    >
                      {supportLoadingMore ? 'Подгружаем...' : 'Показать ещё'}
                    </button>
                  ) : null}
                </div>
              ) : null}
            </div>
            <div className="panel admin-board__detail">
              <div className="admin-panel-heading admin-panel-heading--detail">
                <div>
                  <div className="admin-panel-heading__eyebrow">Диалог</div>
                  <h2>{selectedThread ? selectedThread.subject : 'Выберите обращение'}</h2>
                </div>
                <span className="admin-panel-heading__meta">{selectedThread ? 'Переписка и действия команды' : 'История переписки откроется справа'}</span>
              </div>

              {selectedSupportBusy ? <div className="empty-card">Загружаем переписку...</div> : null}
              {selectedSupportError ? <div className="error-banner">{selectedSupportError}</div> : null}

              {!selectedSupportBusy && !selectedSupportError && selectedSupportDetail ? (
                <div className="support-thread-view">
                  <header className="support-thread-view__header">
                    <div className="support-thread-view__identity">
                      <UserAvatar
                        imageUrl={selectedSupportDetail.thread.user?.avatarUrl}
                        name={selectedSupportDetail.thread.user?.displayName || selectedSupportDetail.thread.user?.username || 'Поддержка'}
                        offsetX={selectedSupportDetail.thread.user?.avatarOffsetX}
                        offsetY={selectedSupportDetail.thread.user?.avatarOffsetY}
                        scale={selectedSupportDetail.thread.user?.avatarScale}
                        size="xl"
                      />

                      <div className="support-thread-view__copy">
                        <h2>{selectedSupportDetail.thread.subject}</h2>
                        <div className="support-thread-view__meta">
                          <span>
                            {selectedSupportDetail.thread.user?.username
                              ? `@${selectedSupportDetail.thread.user.username}`
                              : `Пользователь #${selectedSupportDetail.thread.userId}`}
                          </span>
                          {selectedSupportDetail.thread.user?.email ? <span>{selectedSupportDetail.thread.user.email}</span> : null}
                          <span>{formatAbsoluteDate(selectedSupportDetail.thread.createdAt)}</span>
                        </div>
                        <div className="support-thread-view__badges">
                          <span className={`status-pill status-pill--${supportStatusTone(selectedSupportDetail.thread.status)}`}>
                            {supportStatusLabel(selectedSupportDetail.thread.status)}
                          </span>
                          <span className="status-pill status-pill--muted">{roleLabel(selectedSupportDetail.thread.user?.role || 'User')}</span>
                        </div>
                      </div>
                    </div>

                    <div className="support-thread-view__actions">
                      {selectedSupportDetail.thread.status === 'Closed' ? (
                        <button className="ghost-button" type="button" onClick={() => void handleReopenThread()}>
                          Переоткрыть
                        </button>
                      ) : (
                        <button className="ghost-button" type="button" onClick={() => void handleCloseThread()}>
                          Закрыть
                        </button>
                      )}
                    </div>
                  </header>

                  <div className="support-thread-view__summary">
                    <div className="support-thread-view__summary-card">
                      <span>Сообщений</span>
                      <strong>{formatCount(selectedSupportDetail.messages.length)}</strong>
                    </div>
                    <div className="support-thread-view__summary-card">
                      <span>Непрочитано</span>
                      <strong>{formatCount(selectedSupportDetail.thread.adminUnreadCount)}</strong>
                    </div>
                    <div className="support-thread-view__summary-card">
                      <span>Роль пользователя</span>
                      <strong>{roleLabel(selectedSupportDetail.thread.user?.role || 'User')}</strong>
                    </div>
                  </div>

                  <div className="support-thread-view__messages">
                    {selectedSupportDetail.messages.length ? (
                      selectedSupportDetail.messages.map(renderMessage)
                    ) : (
                      <div className="empty-card empty-card--compact">В обращении пока нет сообщений.</div>
                    )}
                  </div>

                  <div className="support-thread-view__composer">
                    <textarea
                      className="input input--area"
                      disabled={selectedSupportDetail.thread.status === 'Closed' || supportReplyBusy}
                      rows={4}
                      value={supportReply}
                      placeholder={
                        selectedSupportDetail.thread.status === 'Closed'
                          ? 'Сначала переоткройте обращение'
                          : 'Напишите ответ пользователю'
                      }
                      onChange={(event) => setSupportReply(event.target.value)}
                    />

                    <div className="support-thread-view__composer-actions">
                      <span className="admin-inline-note">
                        {selectedSupportDetail.thread.adminUnreadCount > 0
                          ? `${selectedSupportDetail.thread.adminUnreadCount} непрочитанных сообщений накопилось до открытия диалога`
                          : 'Список и переписка синхронизируются в реальном времени'}
                      </span>
                      <button
                        className="primary-button"
                        disabled={!supportReply.trim() || selectedSupportDetail.thread.status === 'Closed' || supportReplyBusy}
                        type="button"
                        onClick={() => void handleAdminReply()}
                      >
                        {supportReplyBusy ? 'Отправляем...' : 'Ответить'}
                      </button>
                    </div>
                  </div>
                </div>
              ) : null}

              {!selectedSupportBusy && !selectedSupportError && !selectedSupportDetail ? (
                <section className="admin-empty-state">
                  <div className="admin-empty-state__icon">SUP</div>
                  <div className="admin-empty-state__copy">
                    <h2>Выберите обращение</h2>
                    <p>Справа откроется история сообщений, статус диалога и быстрые действия для ответа, закрытия и переоткрытия.</p>
                  </div>
                </section>
              ) : null}
            </div>
          </section>
        )}
      </div>

      {freezeOpen && selectedUser ? (
        <div className="admin-modal" role="presentation" onMouseDown={(event) => event.target === event.currentTarget && !freezeBusy && resetFreezeDialog()}>
          <div className="admin-modal__card">
            <div className="admin-modal__header">
              <div>
                <h2>Заморозить {deleteHandle}</h2>
                <p>Пользователь потеряет доступ к аккаунту до выбранной даты, а активные сессии будут сразу отозваны.</p>
              </div>
              <button className="icon-button icon-button--ghost" disabled={freezeBusy} type="button" onClick={resetFreezeDialog}>
                <AppIcon className="button-icon" name="close" />
              </button>
            </div>

            <div className="admin-modal__body">
              <div className="segmented admin-modal__segmented">
                {freezePresets.map((preset) => (
                  <button
                    key={preset.value}
                    className={freezePreset === preset.value ? 'pill-button pill-button--active' : 'pill-button'}
                    type="button"
                    onClick={() => setFreezePreset(preset.value)}
                  >
                    {preset.label}
                  </button>
                ))}
              </div>

              {freezePreset === 'custom' ? (
                <label className="admin-field">
                  <span>Дата и время окончания</span>
                  <input
                    className="input"
                    min={toLocalDateTimeValue(new Date())}
                    type="datetime-local"
                    value={freezeCustomValue}
                    onChange={(event) => setFreezeCustomValue(event.target.value)}
                  />
                </label>
              ) : null}

              <label className="admin-field">
                <span>Заметка для истории модерации</span>
                <textarea
                  className="input input--area"
                  rows={4}
                  value={freezeNote}
                  placeholder="Например: спам, абьюз, запрос на паузу по верификации"
                  onChange={(event) => setFreezeNote(event.target.value)}
                />
              </label>
            </div>

            <div className="admin-modal__actions">
              <button className="ghost-button" disabled={freezeBusy} type="button" onClick={resetFreezeDialog}>
                Отмена
              </button>
              <button className="primary-button" disabled={!freezeUntil || freezeBusy} type="button" onClick={() => void handleFreezeUser()}>
                {freezeBusy ? 'Замораживаем...' : 'Подтвердить заморозку'}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {deleteOpen && selectedUser ? (
        <div className="admin-modal" role="presentation" onMouseDown={(event) => event.target === event.currentTarget && !deleteBusy && resetDeleteDialog()}>
          <div className="admin-modal__card admin-modal__card--danger">
            <div className="admin-modal__header">
              <div>
                <h2>Удалить {deleteHandle} навсегда</h2>
                <p>Удалятся аккаунт, контент, история поддержки и связанные данные. Это действие необратимо.</p>
              </div>
              <button className="icon-button icon-button--ghost" disabled={deleteBusy} type="button" onClick={resetDeleteDialog}>
                <AppIcon className="button-icon" name="close" />
              </button>
            </div>

            <div className="admin-modal__body">
              <label className="admin-field">
                <span>Причина удаления</span>
                <textarea
                  className="input input--area"
                  rows={4}
                  value={deleteNote}
                  placeholder="Коротко зафиксируйте причину для аудита"
                  onChange={(event) => setDeleteNote(event.target.value)}
                />
              </label>

              <label className="admin-field">
                <span>Введите {deleteHandle} для подтверждения</span>
                <input
                  className="input"
                  value={deleteConfirmValue}
                  placeholder={deleteHandle}
                  onChange={(event) => setDeleteConfirmValue(event.target.value)}
                />
              </label>
            </div>

            <div className="admin-modal__actions">
              <button className="ghost-button" disabled={deleteBusy} type="button" onClick={resetDeleteDialog}>
                Отмена
              </button>
              <button className="primary-button admin-danger-button" disabled={!canDelete || deleteBusy} type="button" onClick={() => void handleHardDeleteUser()}>
                {deleteBusy ? 'Удаляем...' : 'Удалить аккаунт'}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}

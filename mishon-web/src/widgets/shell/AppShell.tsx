import { useEffect, useMemo, useState, type PropsWithChildren } from 'react';
import { NavLink, useLocation, useNavigate } from 'react-router-dom';

import { useAuth } from '../../app/providers/useAuth';
import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import { hasMinimumRole } from '../../shared/lib/roles';
import type { NotificationSummary, Post } from '../../shared/types/api';
import { AppIcon } from '../../shared/ui/AppIcon';
import { MishonMark } from '../../shared/ui/MishonMark';
import { UserAvatar } from '../../shared/ui/UserAvatar';
import { ComposePostModal } from '../post/ComposePostModal';
import { SidebarNav } from './SidebarNav';
import { ShellIcon } from './ShellIcon';
import type { SidebarNavItem } from './types';

type AppShellProps = PropsWithChildren<{
  title: string;
  subtitle?: string;
  hideTopbar?: boolean;
  shellVariant?: 'default' | 'messages' | 'wide';
}>;

const defaultSummary: NotificationSummary = {
  unreadNotifications: 0,
  unreadChats: 0,
  incomingFriendRequests: 0,
  pendingFollowRequests: 0,
};

export function AppShell({
  title,
  subtitle,
  hideTopbar = false,
  shellVariant = 'default',
  children,
}: AppShellProps) {
  const location = useLocation();
  const navigate = useNavigate();
  const { profile, logout, refreshProfile } = useAuth();
  const { subscribe } = useLiveSync();
  const [summary, setSummary] = useState<NotificationSummary>(defaultSummary);
  const [composeOpen, setComposeOpen] = useState(false);
  const [composeBusy, setComposeBusy] = useState(false);
  const [sidebarMode, setSidebarMode] = useState<'expanded' | 'compact'>(
    shellVariant === 'messages' ? 'compact' : 'expanded',
  );

  useEffect(() => {
    setSidebarMode(shellVariant === 'messages' ? 'compact' : 'expanded');
  }, [shellVariant]);

  useEffect(() => {
    let cancelled = false;

    async function loadSummary() {
      try {
        const nextSummary = await api.notifications.summary();
        if (!cancelled) {
          setSummary(nextSummary);
        }
      } catch {
        // Non-blocking.
      }
    }

    void loadSummary();

    const intervalId = window.setInterval(() => void loadSummary(), 30000);
    const unsubscribe = subscribe((event) => {
      const eventData = event.data as { userId?: number } | undefined;
      const eventUserId = Number(eventData?.userId ?? 0);

      if (
        event.type === 'notification.summary.changed' ||
        event.type === 'notifications.changed' ||
        event.type.startsWith('chat.') ||
        event.type.startsWith('friends.') ||
        event.type.startsWith('follow.') ||
        event.type === 'sync.resync'
      ) {
        void loadSummary();
      }

      if (event.type === 'sync.resync' || (event.type === 'profile.updated' && (!eventUserId || eventUserId === profile?.id))) {
        void refreshProfile().catch(() => {
          // Non-blocking.
        });
      }
    });

    return () => {
      cancelled = true;
      unsubscribe();
      window.clearInterval(intervalId);
    };
  }, [profile?.id, refreshProfile, subscribe]);

  const navItems = useMemo<SidebarNavItem[]>(
    () => [
      { to: '/feed', label: 'Лента', icon: 'feed' },
      {
        to: '/notifications',
        label: 'Уведомления',
        icon: 'notifications',
        badge: summary.unreadNotifications,
      },
      {
        to: '/friends',
        label: 'Люди',
        icon: 'friends',
        badge: summary.incomingFriendRequests + summary.pendingFollowRequests,
      },
      { to: '/chats', label: 'Чаты', icon: 'chats', badge: summary.unreadChats },
      { to: '/bookmarks', label: 'Закладки', icon: 'bookmark' },
      { to: '/profile', label: 'Профиль', icon: 'profile' },
      { to: '/settings', label: 'Настройки', icon: 'settings' },
    ],
    [summary],
  );

  const shellNavItems = useMemo<SidebarNavItem[]>(() => {
    if (!hasMinimumRole(profile?.role ?? null, 'Admin')) {
      return navItems;
    }
    return [...navItems, { to: '/admin', label: 'Админ', icon: 'shield' }];
  }, [navItems, profile?.role]);

  const mobileNavItems = useMemo(() => shellNavItems.slice(0, 5), [shellNavItems]);

  const displayName = profile?.displayName || profile?.username || 'Mishon';
  const username = profile?.username ? `@${profile.username}` : '@mishon';
  const isMessagesShell = shellVariant === 'messages';
  const isWideShell = shellVariant === 'wide';

  async function handleComposeSubmit(payload: { content: string; imageUrl?: string; imageFile?: File | null }) {
    setComposeBusy(true);

    try {
      const createdPost = await api.feed.create(payload.content, payload.imageUrl, payload.imageFile);
      window.dispatchEvent(new CustomEvent<Post>('mishon:post-created', { detail: createdPost }));
    } finally {
      setComposeBusy(false);
    }
  }

  return (
    <>
      <div
        className={`shell${isMessagesShell ? ' shell--messages' : ''}${isWideShell ? ' shell--wide' : ''}${sidebarMode === 'compact' ? ' shell--rail-compact' : ''}`}
      >
        <aside className="shell__sidebar">
          {isMessagesShell ? (
            <button
              aria-label={sidebarMode === 'compact' ? 'Развернуть навигацию' : 'Свернуть навигацию'}
              className={`shell__rail-toggle${sidebarMode === 'expanded' ? ' shell__rail-toggle--expanded' : ''}`}
              type="button"
              onClick={() => setSidebarMode((current) => (current === 'compact' ? 'expanded' : 'compact'))}
            >
              <AppIcon className="shell-icon shell-icon--sm shell__rail-toggle-icon" name="chevron-right" />
            </button>
          ) : null}

          <div className="brand-card">
            <button className="brand-card__badge" type="button" onClick={() => navigate('/feed')}>
              <MishonMark className="brand-card__logo" monochrome />
            </button>
            <div className="brand-card__meta">
              <strong>Mishon</strong>
            </div>
          </div>

          <SidebarNav items={shellNavItems} onCompose={() => setComposeOpen(true)} />

          <div className="profile-card">
            <button className="profile-card__row" type="button" onClick={() => navigate('/profile')}>
              <UserAvatar
                className="profile-card__avatar"
                imageUrl={profile?.avatarUrl}
                name={displayName}
                offsetX={profile?.avatarOffsetX}
                offsetY={profile?.avatarOffsetY}
                scale={profile?.avatarScale}
                size="lg"
              />
              <span className="profile-card__meta">
                <span className="profile-card__name">{displayName}</span>
                <span className="profile-card__hint">{username}</span>
              </span>
              <span className="profile-card__menu">
                <AppIcon className="shell-icon shell-icon--sm" name="chevron-right" />
              </span>
            </button>
            <button
              aria-label="Выйти"
              className="ghost-button ghost-button--wide profile-card__logout"
              type="button"
              onClick={() => void logout()}
            >
              <AppIcon className="button-icon" name="logout" />
              <span>Выйти</span>
            </button>
          </div>
        </aside>

        <div className="shell__layout">
          <section className={`shell__center${hideTopbar ? ' shell__center--no-topbar' : ''}`}>
            {!hideTopbar ? (
              <header className="topbar">
                <div className="topbar__title">
                  <span className="page-title">{title}</span>
                  {subtitle && location.pathname !== '/feed' ? <span className="page-subtitle">{subtitle}</span> : null}
                </div>
                <div className="topbar__actions">
                  <button className="topbar__profile" type="button" onClick={() => navigate('/profile')}>
                    <UserAvatar
                      imageUrl={profile?.avatarUrl}
                      name={displayName}
                      offsetX={profile?.avatarOffsetX}
                      offsetY={profile?.avatarOffsetY}
                      scale={profile?.avatarScale}
                      size="mini"
                    />
                    <span className="topbar__profile-copy">
                      <strong>{displayName}</strong>
                      <span>{username}</span>
                    </span>
                  </button>
                </div>
              </header>
            ) : null}

            <main className="shell__content shell__content--enter" key={location.pathname}>
              {children}
            </main>
          </section>
        </div>

        <nav className="mobile-nav" aria-label="Нижняя навигация">
          {mobileNavItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => `mobile-nav__link${isActive ? ' mobile-nav__link--active' : ''}`}
            >
              <span className="nav-link__icon">
                <ShellIcon name={item.icon} />
              </span>
              <span className="nav-link__label">{item.label}</span>
              {item.badge ? <span className="nav-link__badge">{item.badge > 99 ? '99+' : item.badge}</span> : null}
            </NavLink>
          ))}
        </nav>
      </div>

      <ComposePostModal
        busy={composeBusy}
        open={composeOpen}
        onClose={() => {
          if (!composeBusy) {
            setComposeOpen(false);
          }
        }}
        onSubmit={handleComposeSubmit}
      />
    </>
  );
}

import { useEffect, useMemo, useState, type PropsWithChildren } from 'react';
import { NavLink, useLocation, useNavigate } from 'react-router-dom';

import { useAuth } from '../../app/providers/useAuth';
import { api } from '../../shared/api/api';
import { initials } from '../../shared/lib/format';
import type { NotificationSummary } from '../../shared/types/api';

type AppShellProps = PropsWithChildren<{
  title: string;
  subtitle?: string;
}>;

type NavIconName = 'feed' | 'chats' | 'friends' | 'profile' | 'settings' | 'notifications';

type NavItem = {
  to: string;
  label: string;
  icon: NavIconName;
  badge?: number;
};

const defaultSummary: NotificationSummary = {
  unreadNotifications: 0,
  unreadChats: 0,
  incomingFriendRequests: 0,
  pendingFollowRequests: 0,
};

function ShellIcon({ name }: { name: NavIconName }) {
  switch (name) {
    case 'feed':
      return (
        <svg aria-hidden="true" className="shell-icon" fill="none" viewBox="0 0 24 24">
          <rect height="15" rx="4" stroke="currentColor" strokeWidth="1.8" width="14" x="5" y="4.5" />
          <path d="M8.5 9h7" stroke="currentColor" strokeLinecap="round" strokeWidth="1.8" />
          <path d="M8.5 12.5h7" stroke="currentColor" strokeLinecap="round" strokeWidth="1.8" />
          <path d="M8.5 16h4.5" stroke="currentColor" strokeLinecap="round" strokeWidth="1.8" />
        </svg>
      );
    case 'chats':
      return (
        <svg aria-hidden="true" className="shell-icon" fill="none" viewBox="0 0 24 24">
          <path
            d="M6.25 7.25A3.25 3.25 0 0 1 9.5 4h5A3.25 3.25 0 0 1 17.75 7.25v6.5A3.25 3.25 0 0 1 14.5 17h-3.2L7 19.8V17A3.25 3.25 0 0 1 4.25 13.75v-6.5Z"
            stroke="currentColor"
            strokeLinejoin="round"
            strokeWidth="1.8"
          />
          <path d="M8.75 9.5h6.5" stroke="currentColor" strokeLinecap="round" strokeWidth="1.8" />
          <path d="M8.75 12.5h4.5" stroke="currentColor" strokeLinecap="round" strokeWidth="1.8" />
        </svg>
      );
    case 'friends':
      return (
        <svg aria-hidden="true" className="shell-icon" fill="none" viewBox="0 0 24 24">
          <path
            d="M12 19.25s-6.25-3.66-6.25-8.44A3.56 3.56 0 0 1 9.3 7.25c1.12 0 2.15.5 2.7 1.31a3.35 3.35 0 0 1 2.7-1.31 3.56 3.56 0 0 1 3.55 3.56C18.25 15.6 12 19.25 12 19.25Z"
            stroke="currentColor"
            strokeLinejoin="round"
            strokeWidth="1.8"
          />
        </svg>
      );
    case 'profile':
      return (
        <svg aria-hidden="true" className="shell-icon" fill="none" viewBox="0 0 24 24">
          <circle cx="12" cy="8.5" r="3.25" stroke="currentColor" strokeWidth="1.8" />
          <path
            d="M6.75 18.25a5.25 5.25 0 0 1 10.5 0"
            stroke="currentColor"
            strokeLinecap="round"
            strokeWidth="1.8"
          />
        </svg>
      );
    case 'settings':
      return (
        <svg aria-hidden="true" className="shell-icon" fill="none" viewBox="0 0 24 24">
          <path
            d="M9.5 6.5h8.25M6.25 6.5h1M14.5 12h3.25M6.25 12h5M10.5 17.5h7.25M6.25 17.5h1"
            stroke="currentColor"
            strokeLinecap="round"
            strokeWidth="1.8"
          />
          <circle cx="8.25" cy="6.5" fill="currentColor" r="2" />
          <circle cx="12.5" cy="12" fill="currentColor" r="2" />
          <circle cx="8.25" cy="17.5" fill="currentColor" r="2" />
        </svg>
      );
    case 'notifications':
      return (
        <svg aria-hidden="true" className="shell-icon" fill="none" viewBox="0 0 24 24">
          <path
            d="M8.25 17.25h7.5l-1.14-1.78a4 4 0 0 1-.61-2.16V10.5a4 4 0 1 0-8 0v2.81c0 .77-.22 1.52-.62 2.16l-1.13 1.78h4"
            stroke="currentColor"
            strokeLinejoin="round"
            strokeWidth="1.8"
          />
          <path d="M10.25 19a1.75 1.75 0 0 0 3.5 0" stroke="currentColor" strokeLinecap="round" strokeWidth="1.8" />
        </svg>
      );
  }
}

export function AppShell({ title, subtitle, children }: AppShellProps) {
  const location = useLocation();
  const navigate = useNavigate();
  const { profile, logout } = useAuth();
  const [summary, setSummary] = useState<NotificationSummary>(defaultSummary);

  useEffect(() => {
    let cancelled = false;

    async function loadSummary() {
      try {
        const nextSummary = await api.notifications.summary();
        if (!cancelled) {
          setSummary(nextSummary);
        }
      } catch {
        // Summary refresh is non-blocking for navigation.
      }
    }

    void loadSummary();
    const id = window.setInterval(() => void loadSummary(), 30000);

    return () => {
      cancelled = true;
      window.clearInterval(id);
    };
  }, []);

  const navItems = useMemo<NavItem[]>(
    () => [
      { to: '/feed', label: 'Лента', icon: 'feed' },
      { to: '/chats', label: 'Чаты', icon: 'chats', badge: summary.unreadChats },
      {
        to: '/friends',
        label: 'Друзья',
        icon: 'friends',
        badge: summary.incomingFriendRequests + summary.pendingFollowRequests,
      },
      { to: '/profile', label: 'Профиль', icon: 'profile' },
      { to: '/settings', label: 'Настройки', icon: 'settings' },
    ],
    [summary],
  );

  const displayName = profile?.displayName || profile?.username || 'Mishon';
  const username = profile?.username ? `@${profile.username}` : 'Ваш аккаунт';

  return (
    <div className="shell">
      <aside className="shell__sidebar">
        <div className="brand-card">
          <div className="brand-card__badge">M</div>
          <div className="brand-card__title">Mishon</div>
          <div className="brand-card__subtitle">Социальная сеть</div>
        </div>

        <nav className="shell__nav" aria-label="Основная навигация">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => `nav-link${isActive ? ' nav-link--active' : ''}`}
            >
              <span className="nav-link__icon">
                <ShellIcon name={item.icon} />
              </span>
              <span className="nav-link__label">{item.label}</span>
              {item.badge ? <span className="nav-link__badge">{item.badge > 99 ? '99+' : item.badge}</span> : null}
            </NavLink>
          ))}
        </nav>

        <div className="profile-card">
          <button className="avatar avatar--large profile-card__avatar" type="button" onClick={() => navigate('/profile')}>
            {profile?.avatarUrl ? (
              <img alt={profile.username} className="avatar__image" src={profile.avatarUrl} />
            ) : (
              initials(displayName)
            )}
          </button>
          <div className="profile-card__meta">
            <div className="profile-card__name">{displayName}</div>
            <div className="profile-card__hint">{username}</div>
          </div>
          <button className="ghost-button ghost-button--wide" type="button" onClick={() => void logout()}>
            Выйти
          </button>
        </div>
      </aside>

      <div className="shell__main">
        <header className="topbar">
          <div className="topbar__title">
            <span className="topbar__dot" />
            <div>
              <div className="page-title">{title}</div>
              {subtitle ? <div className="page-subtitle">{subtitle}</div> : null}
            </div>
          </div>

          <div className="topbar__actions">
            <button
              aria-label="Уведомления"
              className="icon-button"
              type="button"
              onClick={() => navigate('/notifications')}
            >
              <ShellIcon name="notifications" />
              {summary.unreadNotifications ? (
                <span className="icon-button__badge">
                  {summary.unreadNotifications > 99 ? '99+' : summary.unreadNotifications}
                </span>
              ) : null}
            </button>

            <button className="topbar__profile" type="button" onClick={() => navigate('/profile')}>
              <span className="avatar topbar__profile-avatar">
                {profile?.avatarUrl ? (
                  <img alt={profile.username} className="avatar__image" src={profile.avatarUrl} />
                ) : (
                  initials(displayName)
                )}
              </span>
              <span className="topbar__profile-meta">
                <span className="topbar__profile-name">{displayName}</span>
                <span className="topbar__profile-hint">{username}</span>
              </span>
            </button>
          </div>
        </header>

        <main className="shell__content shell__content--enter" key={location.pathname}>
          {children}
        </main>
      </div>

      <nav className="mobile-nav" aria-label="Нижняя навигация">
        {navItems.map((item) => (
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
  );
}

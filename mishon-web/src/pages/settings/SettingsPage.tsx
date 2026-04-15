import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { useAuth } from '../../app/providers/useAuth';
import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import { buildMediaTransformStyle } from '../../shared/lib/media';
import type { FriendCard, FriendRequestItem, PrivacySettings, SessionInfo } from '../../shared/types/api';
import { AppIcon } from '../../shared/ui/AppIcon';
import { UserAvatar } from '../../shared/ui/UserAvatar';
import { SettingsCard } from './components/SettingsCard';
import { SettingsRow } from './components/SettingsRow';

const privacyOptions = ['Public', 'FollowersOnly', 'Private'] as const;
const interactionOptions = ['Everyone', 'Followers', 'Friends', 'Nobody'] as const;

const privacyLabels: Record<(typeof privacyOptions)[number], string> = {
  Public: 'Открытый профиль',
  FollowersOnly: 'Только подписчики',
  Private: 'Приватный аккаунт',
};

const interactionLabels: Record<(typeof interactionOptions)[number], string> = {
  Everyone: 'Все',
  Followers: 'Подписчики',
  Friends: 'Друзья',
  Nobody: 'Никто',
};

type SettingsPanel = 'profile' | 'privacy' | 'follow' | 'blocked' | 'sessions' | null;

function maskEmail(email?: string | null) {
  if (!email) {
    return 'Не указана';
  }

  const [local, domain] = email.split('@');
  if (!local || !domain) {
    return email;
  }

  const head = local.slice(0, 2);
  return `${head}${'*'.repeat(Math.max(1, local.length - 2))}@${domain}`;
}

function describePrivacy(privacy: PrivacySettings) {
  return privacy.isPrivateAccount ? 'Закрыт' : privacyLabels[(privacy.profileVisibility as typeof privacyOptions[number]) ?? 'Public'];
}

function useObjectUrlPreview(file: File | null) {
  const previewUrl = useMemo(() => (file ? URL.createObjectURL(file) : null), [file]);

  useEffect(() => {
    return () => {
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }
    };
  }, [previewUrl]);

  return previewUrl;
}

export function SettingsPage() {
  const navigate = useNavigate();
  const { profile, updateProfileState, logout } = useAuth();
  const { subscribe } = useLiveSync();

  const [openPanel, setOpenPanel] = useState<SettingsPanel>(null);
  const [form, setForm] = useState({
    displayName: '',
    username: '',
    aboutMe: '',
  });
  const [privacy, setPrivacy] = useState<PrivacySettings>({
    isPrivateAccount: false,
    profileVisibility: 'Public',
    messagePrivacy: 'Friends',
    commentPrivacy: 'Everyone',
    presenceVisibility: 'Everyone',
  });
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [bannerFile, setBannerFile] = useState<File | null>(null);
  const [removeAvatar, setRemoveAvatar] = useState(false);
  const [removeBanner, setRemoveBanner] = useState(false);
  const [sessions, setSessions] = useState<SessionInfo[]>([]);
  const [blockedUsers, setBlockedUsers] = useState<FriendCard[]>([]);
  const [followRequests, setFollowRequests] = useState<FriendRequestItem[]>([]);
  const [busy, setBusy] = useState(false);
  const [privacyBusy, setPrivacyBusy] = useState(false);
  const [notice, setNotice] = useState<{ tone: 'success' | 'error' | 'info'; text: string } | null>(null);

  const avatarPreviewUrl = useObjectUrlPreview(avatarFile);
  const bannerPreviewUrl = useObjectUrlPreview(bannerFile);

  const loadSecurityData = useCallback(async () => {
    try {
      const [nextPrivacy, nextSessions, nextBlockedUsers, nextFollowRequests] = await Promise.all([
        api.profile.getPrivacy(),
        api.profile.getSessions(),
        api.friends.blockedUsers(),
        api.friends.incomingFollowRequests(),
      ]);
      setPrivacy(nextPrivacy);
      setSessions(nextSessions);
      setBlockedUsers(nextBlockedUsers);
      setFollowRequests(nextFollowRequests);
    } catch {
      // Non-blocking for the main settings shell.
    }
  }, []);

  useEffect(() => {
    if (!profile) {
      return;
    }

    setForm({
      displayName: profile.displayName ?? '',
      username: profile.username,
      aboutMe: profile.aboutMe ?? '',
    });
    setPrivacy({
      isPrivateAccount: profile.isPrivateAccount,
      profileVisibility: profile.profileVisibility,
      messagePrivacy: profile.messagePrivacy,
      commentPrivacy: profile.commentPrivacy,
      presenceVisibility: profile.presenceVisibility,
    });
    void loadSecurityData();
  }, [loadSecurityData, profile]);

  useEffect(() => {
    return subscribe((event) => {
      if (
        event.type === 'profile.updated' ||
        event.type.startsWith('friends.') ||
        event.type.startsWith('follow.') ||
        event.type === 'sync.resync'
      ) {
        void loadSecurityData();
      }
    });
  }, [loadSecurityData, subscribe]);

  const currentSession = useMemo(() => sessions.find((item) => item.isCurrent) ?? null, [sessions]);
  const displayName = form.displayName.trim() || form.username.trim() || profile?.displayName || profile?.username || 'Mishon';
  const avatarPreview = removeAvatar ? null : avatarPreviewUrl ?? profile?.avatarUrl ?? null;
  const bannerPreview = removeBanner ? null : bannerPreviewUrl ?? profile?.bannerUrl ?? null;
  const hasProfileChanges =
    form.displayName !== (profile?.displayName ?? '') ||
    form.username !== (profile?.username ?? '') ||
    form.aboutMe !== (profile?.aboutMe ?? '');
  const hasMediaChanges = Boolean(avatarFile || bannerFile || removeAvatar || removeBanner);

  async function handleSaveProfile() {
    const normalizedUsername = form.username.trim();
    if (!normalizedUsername) {
      setNotice({ tone: 'error', text: 'Username не может быть пустым.' });
      return;
    }

    if (!hasProfileChanges && !hasMediaChanges) {
      setNotice({ tone: 'info', text: 'Изменений пока нет.' });
      return;
    }

    setBusy(true);
    setNotice(null);
    try {
      let nextProfile = profile;

      if (hasProfileChanges) {
        nextProfile = await api.profile.update({
          displayName: form.displayName,
          username: normalizedUsername,
          aboutMe: form.aboutMe,
        });
        updateProfileState(nextProfile);
      }

      if (hasMediaChanges) {
        try {
          nextProfile = await api.profile.updateMedia({
            avatar: avatarFile,
            banner: bannerFile,
            removeAvatar,
            removeBanner,
            avatarScale: nextProfile?.avatarScale ?? profile?.avatarScale ?? 1,
            avatarOffsetX: nextProfile?.avatarOffsetX ?? profile?.avatarOffsetX ?? 0,
            avatarOffsetY: nextProfile?.avatarOffsetY ?? profile?.avatarOffsetY ?? 0,
            bannerScale: nextProfile?.bannerScale ?? profile?.bannerScale ?? 1,
            bannerOffsetX: nextProfile?.bannerOffsetX ?? profile?.bannerOffsetX ?? 0,
            bannerOffsetY: nextProfile?.bannerOffsetY ?? profile?.bannerOffsetY ?? 0,
          });
        } catch (error) {
          if (nextProfile) {
            updateProfileState(nextProfile);
          }
          setNotice({
            tone: 'error',
            text:
              error instanceof Error
                ? `Основные данные профиля сохранены, но медиа не обновились: ${error.message}`
                : 'Основные данные профиля сохранены, но аватар или баннер не обновились.',
          });
          return;
        }
      }

      if (!nextProfile) {
        setNotice({ tone: 'info', text: 'Изменений пока нет.' });
        return;
      }

      updateProfileState(nextProfile);
      setForm({
        displayName: nextProfile.displayName ?? '',
        username: nextProfile.username,
        aboutMe: nextProfile.aboutMe ?? '',
      });
      setAvatarFile(null);
      setBannerFile(null);
      setRemoveAvatar(false);
      setRemoveBanner(false);
      setNotice({ tone: 'success', text: 'Профиль обновлён и сразу синхронизирован в интерфейсе.' });
    } catch (error) {
      setNotice({
        tone: 'error',
        text: error instanceof Error ? error.message : 'Не удалось сохранить изменения профиля.',
      });
    } finally {
      setBusy(false);
    }
  }

  async function handleSavePrivacy() {
    setPrivacyBusy(true);
    setNotice(null);
    try {
      const nextPrivacy = await api.profile.updatePrivacy(privacy);
      setPrivacy(nextPrivacy);
      updateProfileState({
        ...(profile ?? {
          id: 0,
          username: '',
          email: '',
          avatarScale: 1,
          avatarOffsetX: 0,
          avatarOffsetY: 0,
          bannerScale: 1,
          bannerOffsetX: 0,
          bannerOffsetY: 0,
          createdAt: new Date().toISOString(),
          lastSeenAt: new Date().toISOString(),
          isOnline: true,
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
          isFollowing: false,
          isFriend: false,
          hasPendingFollowRequest: false,
          emailVerified: false,
          role: 'User',
        }),
        ...nextPrivacy,
      });
      setNotice({ tone: 'success', text: 'Параметры приватности сохранены.' });
    } catch (error) {
      setNotice({
        tone: 'error',
        text: error instanceof Error ? error.message : 'Не удалось сохранить настройки приватности.',
      });
    } finally {
      setPrivacyBusy(false);
    }
  }

  function togglePanel(panel: Exclude<SettingsPanel, null>) {
    setOpenPanel((current) => (current === panel ? null : panel));
  }

  function handleAvatarSelect(file: File | null) {
    setAvatarFile(file);
    if (file) {
      setRemoveAvatar(false);
    }
  }

  function handleBannerSelect(file: File | null) {
    setBannerFile(file);
    if (file) {
      setRemoveBanner(false);
    }
  }

  function toggleAvatarRemoval() {
    setRemoveAvatar((current) => {
      const next = !current;
      if (next) {
        setAvatarFile(null);
      }
      return next;
    });
  }

  function toggleBannerRemoval() {
    setRemoveBanner((current) => {
      const next = !current;
      if (next) {
        setBannerFile(null);
      }
      return next;
    });
  }

  return (
    <div className="settings-page">
      {notice ? <div className={notice.tone === 'error' ? 'error-banner' : 'info-banner'}>{notice.text}</div> : null}

      <section className="settings-overview">
        <div className="settings-overview__icon">
          <AppIcon className="settings-overview__symbol" name="shield" />
        </div>
        <div className="settings-overview__copy">
          <h2>Настройки и безопасность</h2>
          <p>Профиль, приватность, защита аккаунта, активные сеансы и локальные параметры интерфейса в одном месте.</p>
        </div>
      </section>

      <SettingsCard
        title="Интерфейс"
        description="Тёмная тема закреплена как базовая, чтобы интерфейс оставался цельным и визуально спокойным."
        icon={<AppIcon className="app-icon" name="moon" />}
      >
        <SettingsRow
          icon="moon"
          title="Тёмная тема"
          description="Светлая тема временно скрыта из интерфейса и не используется в активном UI."
          value="Активна"
        />
      </SettingsCard>

      <SettingsCard
        title="Профиль"
        description="Имя, username, описание и медиа профиля."
        icon={<AppIcon className="app-icon" name="profile" />}
      >
        <SettingsRow
          icon="profile"
          title="Редактирование профиля"
          description="Измените имя, описание, аватар и баннер."
          expandable
          expanded={openPanel === 'profile'}
          onClick={() => togglePanel('profile')}
          value={form.displayName || form.username || 'Заполнить'}
        >
          <div className="settings-inline">
            <section className="settings-profile-preview">
              <div className="settings-profile-preview__banner">
                {bannerPreview ? (
                  <img
                    alt="Предпросмотр баннера"
                    className="settings-profile-preview__banner-image"
                    src={bannerPreview}
                    style={buildMediaTransformStyle(profile?.bannerScale ?? 1, profile?.bannerOffsetX ?? 0, profile?.bannerOffsetY ?? 0)}
                  />
                ) : (
                  <div aria-hidden="true" className="settings-profile-preview__banner-fallback" />
                )}
              </div>

              <div className="settings-profile-preview__body">
                <div className="settings-profile-preview__avatar">
                  <UserAvatar
                    imageUrl={avatarPreview}
                    name={displayName}
                    offsetX={profile?.avatarOffsetX}
                    offsetY={profile?.avatarOffsetY}
                    scale={profile?.avatarScale}
                    size="xxl"
                  />
                </div>

                <div className="settings-profile-preview__meta">
                  <strong>{displayName}</strong>
                  <span>@{form.username.trim() || profile?.username || 'mishon'}</span>
                  <p>{form.aboutMe.trim() || 'Описание появится здесь сразу после сохранения.'}</p>
                </div>
              </div>
            </section>

            <div className="form-grid">
              <input
                className="input"
                value={form.displayName}
                placeholder="Отображаемое имя"
                onChange={(event) => setForm((current) => ({ ...current, displayName: event.target.value }))}
              />
              <input
                className="input"
                value={form.username}
                placeholder="Username"
                onChange={(event) => setForm((current) => ({ ...current, username: event.target.value }))}
              />
              <textarea
                className="input input--area form-grid__wide"
                rows={4}
                value={form.aboutMe}
                placeholder="О себе"
                onChange={(event) => setForm((current) => ({ ...current, aboutMe: event.target.value }))}
              />
            </div>

            <div className="settings-media-grid">
              <label className="settings-media-card">
                <span className="settings-media-card__label">Аватар</span>
                <div className="settings-media-card__preview settings-media-card__preview--avatar">
                  <UserAvatar imageUrl={avatarPreview} name={displayName} size="xl" />
                </div>
                <span className="settings-media-card__hint">
                  {avatarFile ? avatarFile.name : avatarPreview ? 'Текущее изображение готово к замене.' : 'PNG, JPG или WebP'}
                </span>
                <input accept="image/*" type="file" onChange={(event) => handleAvatarSelect(event.target.files?.[0] ?? null)} />
              </label>

              <label className="settings-media-card">
                <span className="settings-media-card__label">Баннер</span>
                <div className="settings-media-card__preview settings-media-card__preview--banner">
                  {bannerPreview ? (
                    <img
                      alt="Предпросмотр баннера"
                      className="settings-media-card__banner-image"
                      src={bannerPreview}
                      style={buildMediaTransformStyle(profile?.bannerScale ?? 1, profile?.bannerOffsetX ?? 0, profile?.bannerOffsetY ?? 0)}
                    />
                  ) : (
                    <div aria-hidden="true" className="settings-media-card__banner-fallback" />
                  )}
                </div>
                <span className="settings-media-card__hint">
                  {bannerFile ? bannerFile.name : bannerPreview ? 'Текущий баннер готов к обновлению.' : 'Широкое изображение для шапки профиля'}
                </span>
                <input accept="image/*" type="file" onChange={(event) => handleBannerSelect(event.target.files?.[0] ?? null)} />
              </label>
            </div>

            <div className="segmented settings-segmented">
              <button
                className={removeAvatar ? 'pill-button pill-button--active' : 'pill-button'}
                type="button"
                onClick={toggleAvatarRemoval}
              >
                {removeAvatar ? 'Аватар будет удалён' : 'Удалить аватар'}
              </button>
              <button
                className={removeBanner ? 'pill-button pill-button--active' : 'pill-button'}
                type="button"
                onClick={toggleBannerRemoval}
              >
                {removeBanner ? 'Баннер будет удалён' : 'Удалить баннер'}
              </button>
            </div>

            <button className="primary-button" disabled={busy} type="button" onClick={() => void handleSaveProfile()}>
              {busy ? 'Сохраняем...' : 'Сохранить профиль'}
            </button>
          </div>
        </SettingsRow>
      </SettingsCard>

      <SettingsCard
        title="Приватность"
        description="Кто видит профиль, пишет вам и получает доступ к закрытому аккаунту."
        icon={<AppIcon className="app-icon" name="lock" />}
      >
        <SettingsRow
          icon="shield"
          title="Приватность профиля"
          description="Управление видимостью профиля, сообщений, комментариев и онлайна."
          expandable
          expanded={openPanel === 'privacy'}
          onClick={() => togglePanel('privacy')}
          value={describePrivacy(privacy)}
        >
          <div className="settings-inline">
            <label className="checkbox-row settings-checkbox">
              <input
                checked={privacy.isPrivateAccount}
                type="checkbox"
                onChange={(event) => setPrivacy((current) => ({ ...current, isPrivateAccount: event.target.checked }))}
              />
              <span>Приватный аккаунт</span>
            </label>

            <div className="form-grid">
              <select
                className="input"
                value={privacy.profileVisibility}
                onChange={(event) => setPrivacy((current) => ({ ...current, profileVisibility: event.target.value }))}
              >
                {privacyOptions.map((option) => (
                  <option key={option} value={option}>
                    {privacyLabels[option]}
                  </option>
                ))}
              </select>

              <select
                className="input"
                value={privacy.messagePrivacy}
                onChange={(event) => setPrivacy((current) => ({ ...current, messagePrivacy: event.target.value }))}
              >
                {interactionOptions.map((option) => (
                  <option key={option} value={option}>
                    {interactionLabels[option]}
                  </option>
                ))}
              </select>

              <select
                className="input"
                value={privacy.commentPrivacy}
                onChange={(event) => setPrivacy((current) => ({ ...current, commentPrivacy: event.target.value }))}
              >
                {interactionOptions.map((option) => (
                  <option key={option} value={option}>
                    {interactionLabels[option]}
                  </option>
                ))}
              </select>

              <select
                className="input"
                value={privacy.presenceVisibility}
                onChange={(event) => setPrivacy((current) => ({ ...current, presenceVisibility: event.target.value }))}
              >
                {interactionOptions.map((option) => (
                  <option key={option} value={option}>
                    {interactionLabels[option]}
                  </option>
                ))}
              </select>
            </div>

            <button className="primary-button" disabled={privacyBusy} type="button" onClick={() => void handleSavePrivacy()}>
              {privacyBusy ? 'Сохраняем...' : 'Сохранить приватность'}
            </button>
          </div>
        </SettingsRow>

        <SettingsRow
          icon="user-plus"
          title="Запросы на подписку"
          description="Входящие запросы на доступ к закрытому профилю."
          expandable
          expanded={openPanel === 'follow'}
          onClick={() => togglePanel('follow')}
          value={String(followRequests.length)}
        >
          <div className="settings-inline">
            {followRequests.length === 0 ? <div className="empty-card empty-card--compact">Новых запросов нет.</div> : null}
            {followRequests.map((request) => (
              <div key={request.id} className="person-row person-row--soft">
                <div className="person-row__meta">
                  <strong>{request.user.displayName || request.user.username}</strong>
                  <span>@{request.user.username}</span>
                </div>
                <div className="person-row__actions">
                  <button
                    className="primary-button primary-button--sm"
                    type="button"
                    onClick={() => void api.friends.approveFollowRequest(request.id).then(loadSecurityData)}
                  >
                    Принять
                  </button>
                  <button
                    className="ghost-button ghost-button--sm"
                    type="button"
                    onClick={() => void api.friends.rejectFollowRequest(request.id).then(loadSecurityData)}
                  >
                    Отклонить
                  </button>
                </div>
              </div>
            ))}
          </div>
        </SettingsRow>
      </SettingsCard>

      <SettingsCard
        title="Поддержка"
        description="Обращения в поддержку и ответы команды Mishon в одном месте."
        icon={<AppIcon className="app-icon" name="message" />}
      >
        <SettingsRow
          icon="message"
          title="Открыть поддержку"
          description="Создайте новый тикет или продолжите уже существующий диалог без перехода в почту."
          onClick={() => navigate('/support')}
          value="Перейти"
        />
      </SettingsCard>

      <SettingsCard
        title="Безопасность"
        description="Почта для входа, блокировки и управление активными устройствами."
        icon={<AppIcon className="app-icon" name="shield" />}
      >
        <SettingsRow
          icon="mail"
          title="Почта для входа"
          description="Адрес, к которому привязан вход в аккаунт."
          value={maskEmail(profile?.email)}
        />

        <SettingsRow
          icon="ban"
          title="Заблокированные пользователи"
          description="Список пользователей, которым запрещено писать вам и видеть часть активности."
          expandable
          expanded={openPanel === 'blocked'}
          onClick={() => togglePanel('blocked')}
          value={String(blockedUsers.length)}
        >
          <div className="settings-inline">
            {blockedUsers.length === 0 ? <div className="empty-card empty-card--compact">Список блокировок пуст.</div> : null}
            {blockedUsers.map((user) => (
              <div key={user.id} className="person-row person-row--soft">
                <div className="person-row__meta">
                  <strong>{user.displayName || user.username}</strong>
                  <span>@{user.username}</span>
                </div>
                <div className="person-row__actions">
                  <button
                    className="ghost-button ghost-button--sm"
                    type="button"
                    onClick={() => void api.friends.unblock(user.id).then(loadSecurityData)}
                  >
                    Разблокировать
                  </button>
                </div>
              </div>
            ))}
          </div>
        </SettingsRow>

        <SettingsRow
          icon="devices"
          title="Активные сеансы"
          description="Устройства, на которых сейчас открыт ваш аккаунт."
          expandable
          expanded={openPanel === 'sessions'}
          onClick={() => togglePanel('sessions')}
          value={String(sessions.length)}
        >
          <div className="settings-inline">
            {currentSession ? (
              <div className="info-banner">
                Текущая сессия: {currentSession.deviceName || currentSession.platform || 'Это устройство'}
              </div>
            ) : null}

            {sessions.map((item) => (
              <div key={item.id} className="person-row person-row--soft">
                <div className="person-row__meta">
                  <strong>{item.deviceName || item.platform || 'Неизвестное устройство'}</strong>
                  <span>{item.userAgent || item.ipAddress || 'Без дополнительных метаданных'}</span>
                </div>
                <div className="person-row__actions">
                  <span className="pill-button pill-button--active">
                    {item.isCurrent ? 'Текущая' : item.isActive ? 'Активна' : 'Завершена'}
                  </span>
                  {!item.isCurrent ? (
                    <button
                      className="ghost-button ghost-button--sm"
                      type="button"
                      onClick={() => void api.profile.revokeSession(item.id).then(loadSecurityData)}
                    >
                      Завершить
                    </button>
                  ) : null}
                </div>
              </div>
            ))}

            <button
              className="ghost-button"
              type="button"
              onClick={() =>
                void api.profile.logoutAllSessions().then(async () => {
                  await logout();
                })
              }
            >
              Выйти со всех устройств
            </button>
          </div>
        </SettingsRow>
      </SettingsCard>
    </div>
  );
}

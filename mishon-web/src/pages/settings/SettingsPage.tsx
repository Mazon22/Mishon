import { useEffect, useState } from 'react';

import { useAuth } from '../../app/providers/useAuth';
import { useTheme } from '../../app/providers/useTheme';
import { api } from '../../shared/api/api';

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

export function SettingsPage() {
  const { profile, updateProfileState } = useAuth();
  const { theme, setTheme } = useTheme();
  const [form, setForm] = useState({
    displayName: '',
    username: '',
    aboutMe: '',
    avatarUrl: '',
    bannerUrl: '',
    isPrivateAccount: false,
    profileVisibility: 'Public',
    messagePrivacy: 'Friends',
    commentPrivacy: 'Everyone',
    presenceVisibility: 'Everyone',
  });
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ tone: 'success' | 'error'; text: string } | null>(null);

  useEffect(() => {
    if (!profile) {
      return;
    }

    setForm({
      displayName: profile.displayName ?? '',
      username: profile.username,
      aboutMe: profile.aboutMe ?? '',
      avatarUrl: profile.avatarUrl ?? '',
      bannerUrl: profile.bannerUrl ?? '',
      isPrivateAccount: profile.isPrivateAccount,
      profileVisibility: profile.profileVisibility,
      messagePrivacy: profile.messagePrivacy,
      commentPrivacy: profile.commentPrivacy,
      presenceVisibility: profile.presenceVisibility,
    });
  }, [profile]);

  async function handleSave() {
    setBusy(true);
    setNotice(null);
    try {
      const nextProfile = await api.profile.update(form);
      updateProfileState(nextProfile);
      setNotice({ tone: 'success', text: 'Настройки сохранены.' });
    } catch (error) {
      setNotice({
        tone: 'error',
        text: error instanceof Error ? error.message : 'Не удалось сохранить изменения.',
      });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="page-stack">
      <section className="hero-card hero-card--settings">
        <div className="hero-card__eyebrow">Mishon</div>
        <h2>Настройки аккаунта</h2>
        <p>Тема, внешний вид профиля и приватность, как в мобильной версии Mishon.</p>
      </section>

      <section className="panel">
        <div className="panel__header">
          <div>
            <div className="section-title">Тема</div>
            <div className="section-subtitle">По умолчанию веб повторяет светлую тему приложения.</div>
          </div>
        </div>
        <div className="segmented">
          <button
            className={theme === 'light' ? 'pill-button pill-button--active' : 'pill-button'}
            type="button"
            onClick={() => setTheme('light')}
          >
            Светлая
          </button>
          <button
            className={theme === 'dark' ? 'pill-button pill-button--active' : 'pill-button'}
            type="button"
            onClick={() => setTheme('dark')}
          >
            Темная
          </button>
        </div>
      </section>

      <section className="panel">
        <div className="panel__header">
          <div>
            <div className="section-title">Профиль и приватность</div>
            <div className="section-subtitle">Здесь меняются имя, описание, медиа и правила общения.</div>
          </div>
        </div>

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
          <input
            className="input"
            value={form.avatarUrl}
            placeholder="Ссылка на аватар"
            onChange={(event) => setForm((current) => ({ ...current, avatarUrl: event.target.value }))}
          />
          <input
            className="input"
            value={form.bannerUrl}
            placeholder="Ссылка на баннер"
            onChange={(event) => setForm((current) => ({ ...current, bannerUrl: event.target.value }))}
          />
          <textarea
            className="input input--area form-grid__wide"
            rows={4}
            value={form.aboutMe}
            placeholder="О себе"
            onChange={(event) => setForm((current) => ({ ...current, aboutMe: event.target.value }))}
          />
        </div>

        <label className="checkbox-row">
          <input
            checked={form.isPrivateAccount}
            type="checkbox"
            onChange={(event) => setForm((current) => ({ ...current, isPrivateAccount: event.target.checked }))}
          />
          <span>Приватный аккаунт</span>
        </label>

        <div className="form-grid">
          <select
            className="input"
            value={form.profileVisibility}
            onChange={(event) => setForm((current) => ({ ...current, profileVisibility: event.target.value }))}
          >
            {privacyOptions.map((option) => (
              <option key={option} value={option}>
                {privacyLabels[option]}
              </option>
            ))}
          </select>

          <select
            className="input"
            value={form.messagePrivacy}
            onChange={(event) => setForm((current) => ({ ...current, messagePrivacy: event.target.value }))}
          >
            {interactionOptions.map((option) => (
              <option key={option} value={option}>
                {interactionLabels[option]}
              </option>
            ))}
          </select>

          <select
            className="input"
            value={form.commentPrivacy}
            onChange={(event) => setForm((current) => ({ ...current, commentPrivacy: event.target.value }))}
          >
            {interactionOptions.map((option) => (
              <option key={option} value={option}>
                {interactionLabels[option]}
              </option>
            ))}
          </select>

          <select
            className="input"
            value={form.presenceVisibility}
            onChange={(event) => setForm((current) => ({ ...current, presenceVisibility: event.target.value }))}
          >
            {interactionOptions.map((option) => (
              <option key={option} value={option}>
                {interactionLabels[option]}
              </option>
            ))}
          </select>
        </div>

        {notice ? (
          <div className={notice.tone === 'error' ? 'error-banner' : 'info-banner'}>{notice.text}</div>
        ) : null}

        <button className="primary-button" disabled={busy} type="button" onClick={() => void handleSave()}>
          {busy ? 'Сохраняем...' : 'Сохранить настройки'}
        </button>
      </section>
    </div>
  );
}

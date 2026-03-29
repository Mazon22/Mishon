import { useState } from 'react';
import { Navigate } from 'react-router-dom';

import { useAuth } from '../../app/providers/useAuth';

export function LoginPage() {
  const { isAuthenticated, login, register } = useAuth();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [form, setForm] = useState({ username: '', email: '', password: '' });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (isAuthenticated) {
    return <Navigate replace to="/feed" />;
  }

  async function handleSubmit() {
    setBusy(true);
    setError(null);
    try {
      if (mode === 'login') {
        await login(form.email, form.password);
      } else {
        await register(form.username, form.email, form.password);
      }
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось выполнить запрос.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth-layout">
      <section className="auth-hero">
        <div className="auth-hero__chip">Mishon Web</div>
        <h1>Социальная сеть Mishon в формате desktop-first</h1>
        <p>
          Большой экран, быстрая навигация, плавная лента, отдельная зона для чатов и настроек.
          Веб-версия повторяет характер мобильного приложения, но ощущается естественно на PC.
        </p>
      </section>

      <section className="auth-card">
        <div className="auth-card__tabs">
          <button className={mode === 'login' ? 'pill-button pill-button--active' : 'pill-button'} type="button" onClick={() => setMode('login')}>
            Вход
          </button>
          <button className={mode === 'register' ? 'pill-button pill-button--active' : 'pill-button'} type="button" onClick={() => setMode('register')}>
            Регистрация
          </button>
        </div>

        {mode === 'register' ? (
          <input
            className="input"
            value={form.username}
            placeholder="Username"
            onChange={(event) => setForm((current) => ({ ...current, username: event.target.value }))}
          />
        ) : null}

        <input
          className="input"
          value={form.email}
          placeholder="Email"
          onChange={(event) => setForm((current) => ({ ...current, email: event.target.value }))}
        />
        <input
          className="input"
          type="password"
          value={form.password}
          placeholder="Пароль"
          onChange={(event) => setForm((current) => ({ ...current, password: event.target.value }))}
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              event.preventDefault();
              void handleSubmit();
            }
          }}
        />

        {error ? <div className="error-banner">{error}</div> : null}

        <button className="primary-button primary-button--wide" disabled={busy} type="button" onClick={() => void handleSubmit()}>
          {busy ? 'Подключаемся...' : mode === 'login' ? 'Войти' : 'Создать аккаунт'}
        </button>
      </section>
    </div>
  );
}

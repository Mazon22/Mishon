import { useState, type MouseEvent } from 'react';

import { AppIcon } from '../../../shared/ui/AppIcon';
import type { LoginFormState } from '../lib/types';
import { AuthButton } from './AuthButton';
import { AuthInput } from './AuthInput';
import { ModalShell } from './ModalShell';

type LoginModalProps = {
  form: LoginFormState;
  busy: boolean;
  error: string | null;
  onClose: () => void;
  onChange: <K extends keyof LoginFormState>(field: K, value: LoginFormState[K]) => void;
  onSubmit: () => Promise<void>;
  onForgotPassword: () => void;
  onSwitchToRegister: () => void;
};

export function LoginModal({
  form,
  busy,
  error,
  onClose,
  onChange,
  onSubmit,
  onForgotPassword,
  onSwitchToRegister,
}: LoginModalProps) {
  const [showPassword, setShowPassword] = useState(false);

  async function handleSubmit() {
    await onSubmit();
  }

  function handlePasswordVisibilityToggle(event: MouseEvent<HTMLButtonElement>) {
    const field = event.currentTarget.closest('label');
    const input = field?.querySelector('input') as HTMLInputElement | null;
    const selectionStart = input?.selectionStart ?? null;
    const selectionEnd = input?.selectionEnd ?? null;

    setShowPassword((value) => !value);

    requestAnimationFrame(() => {
      const nextInput = field?.querySelector('input') as HTMLInputElement | null;
      if (!nextInput) {
        return;
      }

      nextInput.focus({ preventScroll: true });
      if (selectionStart !== null && selectionEnd !== null) {
        nextInput.setSelectionRange(selectionStart, selectionEnd);
      }
    });
  }

  return (
    <ModalShell
      title="Вход в Mishon"
      subtitle="Войдите в свой аккаунт на web и мобильных устройствах."
      onClose={onClose}
    >
      <div className="auth-modal__content">
        <div className="auth-modal__form">
          <AuthInput
            label="Email"
            leading={<AppIcon name="mail" className="app-icon" />}
            inputProps={{
              autoComplete: 'email',
              autoFocus: true,
              value: form.email,
              onChange: (event) => onChange('email', event.target.value),
              placeholder: 'Введите почту',
            }}
          />

          <AuthInput
            label="Пароль"
            action={
              <button className="auth-inline-link" type="button" onClick={onForgotPassword}>
                Forgot password?
              </button>
            }
            leading={<AppIcon name="lock" className="app-icon" />}
            trailing={
              <button
                className="auth-input__toggle"
                type="button"
                aria-label={showPassword ? 'Скрыть пароль' : 'Показать пароль'}
                aria-pressed={showPassword}
                onMouseDown={(event) => event.preventDefault()}
                onClick={(event) => handlePasswordVisibilityToggle(event)}
              >
                <AppIcon name={showPassword ? 'eye-off' : 'eye'} className="app-icon" />
              </button>
            }
            inputProps={{
              autoComplete: 'current-password',
              type: showPassword ? 'text' : 'password',
              value: form.password,
              onChange: (event) => onChange('password', event.target.value),
              onKeyDown: (event) => {
                if (event.key === 'Enter') {
                  event.preventDefault();
                  void handleSubmit();
                }
              },
              placeholder: 'Введите пароль',
            }}
          />

          {error ? <div className="auth-inline-note auth-inline-note--error">{error}</div> : null}
        </div>

        <div className="auth-modal__footer">
          <AuthButton variant="primary" disabled={busy} onClick={() => void handleSubmit()}>
            {busy ? 'Входим...' : 'Войти'}
          </AuthButton>

          <p className="auth-modal__switch">
            Нет аккаунта?{' '}
            <button type="button" onClick={onSwitchToRegister}>
              Создать
            </button>
          </p>
        </div>
      </div>
    </ModalShell>
  );
}

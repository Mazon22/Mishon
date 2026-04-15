import { useState, type MouseEvent } from 'react';

import { AppIcon } from '../../../shared/ui/AppIcon';
import type { RegisterFormState, RegisterStep } from '../lib/types';
import { AuthButton } from './AuthButton';
import { AuthInput } from './AuthInput';
import { DateOfBirthFields } from './DateOfBirthFields';
import { ModalShell } from './ModalShell';

type Option = {
  value: string;
  label: string;
};

type RegisterModalProps = {
  step: RegisterStep;
  form: RegisterFormState;
  busy: boolean;
  error: string | null;
  dayOptions: Option[];
  yearOptions: Option[];
  onClose: () => void;
  onChange: <K extends keyof RegisterFormState>(field: K, value: RegisterFormState[K]) => void;
  onNext: () => void;
  onBack: () => void;
  onSubmit: () => Promise<void>;
  onSwitchToLogin: () => void;
};

export function RegisterModal({
  step,
  form,
  busy,
  error,
  dayOptions,
  yearOptions,
  onClose,
  onChange,
  onNext,
  onBack,
  onSubmit,
  onSwitchToLogin,
}: RegisterModalProps) {
  const [showPassword, setShowPassword] = useState(false);

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
      title={step === 'profile' ? 'Создайте аккаунт' : 'Завершите регистрацию'}
      subtitle={
        step === 'profile'
          ? 'Укажите базовые данные, чтобы быстро начать.'
          : 'Придумайте username и пароль для входа.'
      }
      onClose={onClose}
    >
      <div className="auth-modal__content">
        {step === 'profile' ? (
          <>
            <div className="auth-modal__form">
              <AuthInput
                label="Имя"
                leading={<AppIcon name="profile" className="app-icon" />}
                inputProps={{
                  autoFocus: true,
                  value: form.name,
                  onChange: (event) => onChange('name', event.target.value),
                  placeholder: 'Введите имя',
                }}
              />

              <AuthInput
                label="Email"
                leading={<AppIcon name="mail" className="app-icon" />}
                inputProps={{
                  autoComplete: 'email',
                  value: form.email,
                  onChange: (event) => onChange('email', event.target.value),
                  placeholder: 'Введите почту',
                }}
              />

              <DateOfBirthFields
                month={form.birthMonth}
                day={form.birthDay}
                year={form.birthYear}
                dayOptions={dayOptions}
                yearOptions={yearOptions}
                onChange={onChange}
              />
            </div>

            {error ? <div className="auth-inline-note auth-inline-note--error">{error}</div> : null}

            <div className="auth-modal__footer">
              <AuthButton variant="primary" onClick={onNext}>
                Далее
              </AuthButton>
              <p className="auth-modal__switch">
                Уже есть аккаунт?{' '}
                <button type="button" onClick={onSwitchToLogin}>
                  Войти
                </button>
              </p>
            </div>
          </>
        ) : (
          <>
            <div className="auth-modal__form">
              <AuthInput
                label="Username"
                leading={<AppIcon name="spark" className="app-icon" />}
                hint="Будет виден в профиле и упоминаниях. Можно использовать только латиницу, цифры, точку и _."
                inputProps={{
                  autoFocus: true,
                  value: form.username,
                  onChange: (event) => onChange('username', event.target.value),
                  placeholder: 'Придумайте username',
                }}
              />

              <AuthInput
                label="Пароль"
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
                hint="Используйте минимум 8 символов. Лучше добавить цифры и разные регистры."
                inputProps={{
                  autoComplete: 'new-password',
                  type: showPassword ? 'text' : 'password',
                  value: form.password,
                  onChange: (event) => onChange('password', event.target.value),
                  onKeyDown: (event) => {
                    if (event.key === 'Enter') {
                      event.preventDefault();
                      void onSubmit();
                    }
                  },
                  placeholder: 'Введите пароль',
                }}
              />
            </div>

            {error ? <div className="auth-inline-note auth-inline-note--error">{error}</div> : null}

            <div className="auth-modal__footer auth-modal__footer--split">
              <AuthButton variant="ghost" onClick={onBack}>
                Назад
              </AuthButton>
              <AuthButton variant="primary" disabled={busy} onClick={() => void onSubmit()}>
                {busy ? 'Создаем аккаунт...' : 'Создать аккаунт'}
              </AuthButton>
            </div>
            <p className="auth-modal__switch">
              Уже есть аккаунт?{' '}
              <button type="button" onClick={onSwitchToLogin}>
                Войти
              </button>
            </p>
          </>
        )}
      </div>
    </ModalShell>
  );
}

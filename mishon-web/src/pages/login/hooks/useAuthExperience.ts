import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { useAuth } from '../../../app/providers/useAuth';
import { api } from '../../../shared/api/api';
import { buildDayOptions, buildYearOptions, suggestUsername, validateRegisterCredentials, validateRegisterProfile } from '../lib/auth-utils';
import type { AuthModalKind, LoginFormState, RegisterFormState, RegisterStep } from '../lib/types';

const INITIAL_LOGIN_FORM: LoginFormState = {
  email: '',
  password: '',
};

const INITIAL_REGISTER_FORM: RegisterFormState = {
  name: '',
  email: '',
  birthMonth: '',
  birthDay: '',
  birthYear: '',
  username: '',
  password: '',
};

export function useAuthExperience() {
  const { isAuthenticated, login, register, updateProfileState } = useAuth();
  const navigate = useNavigate();
  const [modal, setModal] = useState<AuthModalKind>(null);
  const [registerStep, setRegisterStep] = useState<RegisterStep>('profile');
  const [loginForm, setLoginForm] = useState<LoginFormState>(INITIAL_LOGIN_FORM);
  const [registerForm, setRegisterForm] = useState<RegisterFormState>(INITIAL_REGISTER_FORM);
  const [socialNotice, setSocialNotice] = useState<string | null>(null);
  const [loginError, setLoginError] = useState<string | null>(null);
  const [registerError, setRegisterError] = useState<string | null>(null);
  const [loginBusy, setLoginBusy] = useState(false);
  const [registerBusy, setRegisterBusy] = useState(false);

  const dayOptions = useMemo(() => buildDayOptions(), []);
  const yearOptions = useMemo(() => buildYearOptions(), []);

  function openLogin() {
    setModal('login');
    setLoginError(null);
    setSocialNotice(null);
  }

  function openRegister() {
    setModal('register');
    setRegisterStep('profile');
    setRegisterError(null);
    setSocialNotice(null);
  }

  function closeModal() {
    setModal(null);
    setLoginError(null);
    setRegisterError(null);
  }

  function openForgotPassword() {
    closeModal();
    navigate('/forgot-password');
  }

  function onSocialClick(provider: 'google' | 'apple') {
    const label = provider === 'google' ? 'Google' : 'Apple';
    setSocialNotice(`Вход через ${label} появится следующим обновлением. Пока используйте email и пароль.`);
  }

  function updateLoginField<K extends keyof LoginFormState>(field: K, value: LoginFormState[K]) {
    setLoginForm((current) => ({ ...current, [field]: value }));
    setLoginError(null);
  }

  function updateRegisterField<K extends keyof RegisterFormState>(field: K, value: RegisterFormState[K]) {
    setRegisterForm((current) => ({ ...current, [field]: value }));
    setRegisterError(null);
  }

  function goToRegisterCredentials() {
    const validation = validateRegisterProfile(registerForm);
    if (!validation.valid) {
      setRegisterError(validation.message ?? 'Проверьте введенные данные.');
      return;
    }

    setRegisterForm((current) => ({
      ...current,
      username: current.username || suggestUsername(current.name, current.email),
    }));
    setRegisterStep('credentials');
    setRegisterError(null);
  }

  function goToRegisterProfile() {
    setRegisterStep('profile');
    setRegisterError(null);
  }

  async function submitLogin() {
    setLoginBusy(true);
    setLoginError(null);
    try {
      await login(loginForm.email.trim(), loginForm.password);
    } catch (error) {
      setLoginError(error instanceof Error ? error.message : 'Не удалось выполнить вход. Попробуйте еще раз.');
    } finally {
      setLoginBusy(false);
    }
  }

  async function submitRegister() {
    const validation = validateRegisterCredentials(registerForm);
    if (!validation.valid) {
      setRegisterError(validation.message ?? 'Проверьте username и пароль.');
      return;
    }

    setRegisterBusy(true);
    setRegisterError(null);

    try {
      const username = registerForm.username.trim().toLowerCase();
      const email = registerForm.email.trim().toLowerCase();
      await register(username, email, registerForm.password);
      try {
        const updatedProfile = await api.profile.update({
          displayName: registerForm.name.trim(),
          username,
        });
        updateProfileState(updatedProfile);
      } catch {
        // Registration should still succeed even if profile enrichment lags behind.
      }
      navigate(`/verify-email/pending?email=${encodeURIComponent(email)}`);
    } catch (error) {
      setRegisterError(error instanceof Error ? error.message : 'Не удалось создать аккаунт. Попробуйте еще раз.');
    } finally {
      setRegisterBusy(false);
    }
  }

  return {
    isAuthenticated,
    modal,
    registerStep,
    loginForm,
    registerForm,
    socialNotice,
    loginError,
    registerError,
    loginBusy,
    registerBusy,
    dayOptions,
    yearOptions,
    openLogin,
    openRegister,
    openForgotPassword,
    closeModal,
    onSocialClick,
    updateLoginField,
    updateRegisterField,
    goToRegisterCredentials,
    goToRegisterProfile,
    submitLogin,
    submitRegister,
  };
}

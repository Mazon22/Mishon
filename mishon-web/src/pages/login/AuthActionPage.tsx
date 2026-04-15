import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link, useLocation, useSearchParams } from 'react-router-dom';

import { api } from '../../shared/api/api';
import { AuthButton } from './components/AuthButton';
import { AuthHero } from './components/AuthHero';
import { AuthInput } from './components/AuthInput';
import { AuthLayout } from './components/AuthLayout';

type AuthActionMode = 'forgot-password' | 'reset-password' | 'verify-email' | 'verify-email-pending';

type ActionCopy = {
  label: string;
  title: string;
  subtitle: string;
  submitLabel: string;
};

function resolveMode(pathname: string): AuthActionMode {
  if (pathname.endsWith('/reset-password')) {
    return 'reset-password';
  }
  if (pathname.endsWith('/verify-email/pending')) {
    return 'verify-email-pending';
  }
  if (pathname.endsWith('/verify-email')) {
    return 'verify-email';
  }
  return 'forgot-password';
}

function copyForMode(mode: AuthActionMode): ActionCopy {
  switch (mode) {
    case 'reset-password':
      return {
        label: 'Security',
        title: 'Choose a new password',
        subtitle: 'Finish the reset flow from the email you received and secure your account again.',
        submitLabel: 'Update password',
      };
    case 'verify-email':
      return {
        label: 'Verification',
        title: 'Confirm your email',
        subtitle: 'Verify this address so Mishon can unlock account recovery and security notifications.',
        submitLabel: 'Verify email',
      };
    case 'verify-email-pending':
      return {
        label: 'Verification',
        title: 'Check your inbox',
        subtitle: 'A verification email is waiting for you. You can resend it here if needed.',
        submitLabel: 'Resend verification',
      };
    default:
      return {
        label: 'Recovery',
        title: 'Reset access',
        subtitle: 'Enter your email and we will send a secure link for choosing a new password.',
        submitLabel: 'Send reset link',
      };
  }
}

export function AuthActionPage() {
  const location = useLocation();
  const [searchParams] = useSearchParams();
  const mode = useMemo(() => resolveMode(location.pathname), [location.pathname]);
  const copy = useMemo(() => copyForMode(mode), [mode]);

  const queryEmail = (searchParams.get('email') ?? '').trim();
  const token = (searchParams.get('token') ?? '').trim();

  const [email, setEmail] = useState(queryEmail);
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [autoVerifyRequested, setAutoVerifyRequested] = useState(false);

  useEffect(() => {
    setEmail(queryEmail);
    setNewPassword('');
    setConfirmPassword('');
    setBusy(false);
    setError(null);
    setNotice(null);
    setAutoVerifyRequested(false);
  }, [mode, queryEmail, token]);

  async function submitForgotPassword() {
    const normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail) {
      setError('Enter the email address for your Mishon account.');
      return;
    }

    setBusy(true);
    setError(null);
    setNotice(null);

    try {
      await api.auth.forgotPassword(normalizedEmail);
      setNotice('If the account exists, a password reset link has been sent to that email.');
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : 'Failed to send the reset email.');
    } finally {
      setBusy(false);
    }
  }

  async function submitResetPassword() {
    if (!token) {
      setError('The reset link is incomplete. Open the latest email and try again.');
      return;
    }
    if (newPassword.length < 8) {
      setError('Use a password with at least 8 characters.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setError('The passwords do not match.');
      return;
    }

    setBusy(true);
    setError(null);
    setNotice(null);

    try {
      await api.auth.resetPassword(token, newPassword);
      setNotice('Password updated. You can sign in with the new password now.');
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : 'Failed to reset the password.');
    } finally {
      setBusy(false);
    }
  }

  async function submitResendVerification() {
    const normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail) {
      setError('Enter the email address that should receive the verification link.');
      return;
    }

    setBusy(true);
    setError(null);
    setNotice(null);

    try {
      await api.auth.resendVerification(normalizedEmail);
      setNotice('Verification email sent. Open the latest message and follow the link.');
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : 'Failed to resend verification.');
    } finally {
      setBusy(false);
    }
  }

  async function submitVerifyEmail() {
    if (!token) {
      setError('This verification link is missing its token. Request a new email to continue.');
      return;
    }

    setBusy(true);
    setError(null);
    setNotice(null);

    try {
      await api.auth.verifyEmail(token);
      setNotice('Email verified. Your account is ready to use.');
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : 'Failed to verify the email.');
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    if (mode !== 'verify-email' || !token || autoVerifyRequested) {
      return;
    }

    setAutoVerifyRequested(true);
    setBusy(true);
    setError(null);
    setNotice(null);
    void api.auth
      .verifyEmail(token)
      .then(() => {
        setNotice('Email verified. Your account is ready to use.');
        setError(null);
      })
      .catch((submitError) => {
        setError(submitError instanceof Error ? submitError.message : 'Failed to verify the email.');
      })
      .finally(() => {
        setBusy(false);
      });
  }, [autoVerifyRequested, mode, token]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    switch (mode) {
      case 'reset-password':
        await submitResetPassword();
        break;
      case 'verify-email':
        await submitVerifyEmail();
        break;
      case 'verify-email-pending':
        await submitResendVerification();
        break;
      default:
        await submitForgotPassword();
        break;
    }
  }

  const showEmailField = mode === 'forgot-password' || mode === 'verify-email-pending' || (mode === 'verify-email' && !token);
  const showResetFields = mode === 'reset-password';

  return (
    <AuthLayout
      hero={<AuthHero />}
      actions={
        <section className="auth-actions">
          <article className="auth-modal auth-modal--embedded">
            <header className="auth-modal__header">
              <p className="auth-actions__label">{copy.label}</p>
              <h2>{copy.title}</h2>
              <p>{copy.subtitle}</p>
            </header>

            <div className="auth-modal__content">
              <form className="auth-modal__form" onSubmit={(event) => void handleSubmit(event)}>
                {showEmailField ? (
                  <AuthInput
                    label="Email"
                    inputProps={{
                      autoComplete: 'email',
                      autoFocus: true,
                      value: email,
                      onChange: (event) => setEmail(event.target.value),
                      placeholder: 'name@example.com',
                    }}
                  />
                ) : null}

                {showResetFields ? (
                  <>
                    <AuthInput
                      label="New password"
                      inputProps={{
                        autoComplete: 'new-password',
                        autoFocus: true,
                        type: 'password',
                        value: newPassword,
                        onChange: (event) => setNewPassword(event.target.value),
                        placeholder: 'Choose a stronger password',
                      }}
                    />

                    <AuthInput
                      label="Confirm password"
                      inputProps={{
                        autoComplete: 'new-password',
                        type: 'password',
                        value: confirmPassword,
                        onChange: (event) => setConfirmPassword(event.target.value),
                        placeholder: 'Repeat the password',
                      }}
                    />
                  </>
                ) : null}

                {error ? <div className="auth-inline-note auth-inline-note--error">{error}</div> : null}
                {notice ? <div className="auth-inline-note">{notice}</div> : null}

                <div className="auth-modal__footer">
                  <AuthButton type="submit" variant="primary" disabled={busy}>
                    {busy ? 'Please wait...' : copy.submitLabel}
                  </AuthButton>
                </div>
              </form>

              <div className="auth-modal__footer">
                <Link className="auth-inline-link" to="/login">
                  Back to login
                </Link>
                {mode !== 'forgot-password' ? (
                  <Link className="auth-inline-link" to="/forgot-password">
                    Need a password reset instead?
                  </Link>
                ) : null}
                {mode !== 'verify-email-pending' ? (
                  <Link className="auth-inline-link" to={`/verify-email/pending${email.trim() ? `?email=${encodeURIComponent(email.trim())}` : ''}`}>
                    Need a fresh verification email?
                  </Link>
                ) : null}
              </div>
            </div>
          </article>
        </section>
      }
    />
  );
}

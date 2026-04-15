import { Navigate } from 'react-router-dom';

import { useAuthExperience } from '../hooks/useAuthExperience';
import { AuthActions } from './AuthActions';
import { AuthHero } from './AuthHero';
import { AuthLayout } from './AuthLayout';
import { LoginModal } from './LoginModal';
import { RegisterModal } from './RegisterModal';

export function AuthPage() {
  const auth = useAuthExperience();

  if (auth.isAuthenticated) {
    return <Navigate replace to="/feed" />;
  }

  return (
    <>
      <AuthLayout
        hero={<AuthHero />}
        actions={
          <AuthActions
            socialNotice={auth.socialNotice}
            onProviderClick={auth.onSocialClick}
            onCreateAccount={auth.openRegister}
            onLogin={auth.openLogin}
          />
        }
      />

      {auth.modal === 'register' ? (
        <RegisterModal
          step={auth.registerStep}
          form={auth.registerForm}
          busy={auth.registerBusy}
          error={auth.registerError}
          dayOptions={auth.dayOptions}
          yearOptions={auth.yearOptions}
          onClose={auth.closeModal}
          onChange={auth.updateRegisterField}
          onNext={auth.goToRegisterCredentials}
          onBack={auth.goToRegisterProfile}
          onSubmit={auth.submitRegister}
          onSwitchToLogin={auth.openLogin}
        />
      ) : null}

      {auth.modal === 'login' ? (
        <LoginModal
          form={auth.loginForm}
          busy={auth.loginBusy}
          error={auth.loginError}
          onClose={auth.closeModal}
          onChange={auth.updateLoginField}
          onSubmit={auth.submitLogin}
          onForgotPassword={auth.openForgotPassword}
          onSwitchToRegister={auth.openRegister}
        />
      ) : null}
    </>
  );
}

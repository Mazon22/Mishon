import { AuthButton } from './AuthButton';
import { AuthDivider } from './AuthDivider';
import { AuthLegalText } from './AuthLegalText';
import { SocialLoginButtons } from './SocialLoginButtons';

type AuthActionsProps = {
  socialNotice: string | null;
  onProviderClick: (provider: 'google' | 'apple') => void;
  onCreateAccount: () => void;
  onLogin: () => void;
};

export function AuthActions({
  socialNotice,
  onProviderClick,
  onCreateAccount,
  onLogin,
}: AuthActionsProps) {
  return (
    <section className="auth-actions">
      <p className="auth-actions__label">Аккаунт Mishon</p>
      <h1 className="auth-actions__title">
        <span>Оставайтесь</span>
        <span>в ритме</span>
        <span>Mishon.</span>
      </h1>
      <p className="auth-actions__subtitle">
        Люди, новости и сообщения рядом на каждом вашем устройстве.
      </p>

      <div className="auth-actions__buttons">
        <SocialLoginButtons onProviderClick={onProviderClick} />
        {socialNotice ? <div className="auth-inline-note">{socialNotice}</div> : null}
        <AuthDivider label="или" />
        <AuthButton variant="primary" onClick={onCreateAccount}>
          Создать аккаунт
        </AuthButton>
        <AuthLegalText />
      </div>

      <div className="auth-actions__secondary">
        <p>Уже есть аккаунт?</p>
        <AuthButton variant="secondary" onClick={onLogin}>
          Войти
        </AuthButton>
      </div>
    </section>
  );
}

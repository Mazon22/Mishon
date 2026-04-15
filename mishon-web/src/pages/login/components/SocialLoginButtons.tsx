import { AuthButton } from './AuthButton';

type SocialLoginButtonsProps = {
  onProviderClick: (provider: 'google' | 'apple') => void;
};

function GoogleIcon() {
  return (
    <svg aria-hidden="true" className="auth-social-icon" viewBox="0 0 24 24">
      <path fill="#4285F4" d="M21.8 12.22c0-.78-.07-1.53-.2-2.24H12v4.24h5.5a4.7 4.7 0 0 1-2.04 3.09v2.56h3.3c1.93-1.78 3.04-4.4 3.04-7.65Z" />
      <path fill="#34A853" d="M12 22c2.75 0 5.05-.9 6.74-2.44l-3.3-2.56c-.91.61-2.08.97-3.44.97-2.65 0-4.9-1.79-5.7-4.2H2.9v2.64A10 10 0 0 0 12 22Z" />
      <path fill="#FBBC05" d="M6.3 13.77A5.98 5.98 0 0 1 6 12c0-.61.1-1.2.3-1.77V7.6H2.9A10 10 0 0 0 2 12c0 1.61.38 3.12 1.06 4.4l3.24-2.63Z" />
      <path fill="#EA4335" d="M12 5.98c1.49 0 2.82.5 3.87 1.47l2.9-2.9C17.04 2.95 14.74 2 12 2A10 10 0 0 0 2.9 7.6l3.4 2.64c.8-2.42 3.05-4.26 5.7-4.26Z" />
    </svg>
  );
}

function AppleIcon() {
  return (
    <svg aria-hidden="true" className="auth-social-icon" viewBox="0 0 24 24">
      <path
        fill="currentColor"
        d="M16.56 12.61c.03 2.88 2.53 3.84 2.56 3.85-.02.07-.4 1.37-1.3 2.72-.79 1.17-1.6 2.34-2.9 2.36-1.26.02-1.66-.75-3.1-.75-1.45 0-1.89.73-3.08.77-1.25.05-2.2-1.26-2.99-2.42C4.1 16.66 2.8 12.1 4.73 8.76c.96-1.67 2.67-2.73 4.52-2.76 1.2-.03 2.33.81 3.09.81.76 0 2.19-.99 3.69-.85.63.03 2.4.25 3.54 1.92-.09.05-2.12 1.24-2.11 3.73Zm-2.64-7.77c.66-.8 1.12-1.92 1-3.03-.95.04-2.09.63-2.77 1.43-.61.71-1.14 1.84-.99 2.93 1.06.08 2.1-.54 2.76-1.33Z"
      />
    </svg>
  );
}

export function SocialLoginButtons({ onProviderClick }: SocialLoginButtonsProps) {
  return (
    <div className="auth-social-stack">
      <AuthButton variant="social" icon={<GoogleIcon />} onClick={() => onProviderClick('google')}>
        Продолжить через Google
      </AuthButton>
      <AuthButton variant="social" icon={<AppleIcon />} onClick={() => onProviderClick('apple')}>
        Продолжить через Apple
      </AuthButton>
    </div>
  );
}

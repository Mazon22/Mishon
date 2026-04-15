import type { ButtonHTMLAttributes, ReactNode } from 'react';

type AuthButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'secondary' | 'ghost' | 'social';
  fullWidth?: boolean;
  icon?: ReactNode;
};

export function AuthButton({
  variant = 'primary',
  fullWidth = true,
  icon,
  className,
  children,
  ...props
}: AuthButtonProps) {
  return (
    <button
      className={[
        'auth-button',
        `auth-button--${variant}`,
        fullWidth ? 'auth-button--full' : '',
        icon ? 'auth-button--icon' : '',
        className ?? '',
      ]
        .filter(Boolean)
        .join(' ')}
      type="button"
      {...props}
    >
      {icon ? <span className="auth-button__icon">{icon}</span> : null}
      <span>{children}</span>
    </button>
  );
}

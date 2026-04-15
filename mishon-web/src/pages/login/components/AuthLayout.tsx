import type { ReactNode } from 'react';

type AuthLayoutProps = {
  hero: ReactNode;
  actions: ReactNode;
};

export function AuthLayout({ hero, actions }: AuthLayoutProps) {
  return (
    <div className="auth-screen">
      <div className="auth-screen__orb auth-screen__orb--left" aria-hidden="true" />
      <div className="auth-screen__orb auth-screen__orb--right" aria-hidden="true" />

      <main className="auth-shell">
        <div className="auth-shell__grid">
          {hero}
          {actions}
        </div>
      </main>
    </div>
  );
}

import type { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';

import { AppShell } from '../../widgets/shell/AppShell';
import { useAuth } from '../providers/useAuth';

type ProtectedRouteProps = {
  title: string;
  subtitle?: string;
  children: ReactNode;
};

export function ProtectedRoute({ title, subtitle, children }: ProtectedRouteProps) {
  const { isAuthenticated, isReady } = useAuth();

  if (!isReady) {
    return <div className="splash-screen">Подготавливаем Mishon Web...</div>;
  }

  if (!isAuthenticated) {
    return <Navigate replace to="/login" />;
  }

  return (
    <AppShell subtitle={subtitle} title={title}>
      {children}
    </AppShell>
  );
}

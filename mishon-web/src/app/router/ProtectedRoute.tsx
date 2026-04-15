import type { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';

import { AppShell } from '../../widgets/shell/AppShell';
import { hasMinimumRole } from '../../shared/lib/roles';
import { useAuth } from '../providers/useAuth';

type ProtectedRouteProps = {
  title: string;
  subtitle?: string;
  hideTopbar?: boolean;
  shellVariant?: 'default' | 'messages' | 'wide';
  minimumRole?: string;
  children: ReactNode;
};

export function ProtectedRoute({
  title,
  subtitle,
  hideTopbar,
  shellVariant = 'default',
  minimumRole,
  children,
}: ProtectedRouteProps) {
  const { isAuthenticated, isReady, profile, session } = useAuth();

  if (!isReady) {
    return null;
  }

  if (!isAuthenticated) {
    return <Navigate replace to="/login" />;
  }

  const currentRole = profile?.role ?? session?.role ?? null;
  if (minimumRole && !hasMinimumRole(currentRole, minimumRole)) {
    return (
      <AppShell hideTopbar={hideTopbar ?? true} shellVariant={shellVariant} subtitle={subtitle} title={title}>
        <section className="panel admin-empty-state">
          <div className="admin-empty-state__icon">403</div>
          <div className="admin-empty-state__copy">
            <h2>Доступ запрещён</h2>
            <p>У вашей роли пока нет доступа к этому разделу.</p>
          </div>
        </section>
      </AppShell>
    );
  }

  return (
    <AppShell hideTopbar={hideTopbar ?? true} shellVariant={shellVariant} subtitle={subtitle} title={title}>
      {children}
    </AppShell>
  );
}

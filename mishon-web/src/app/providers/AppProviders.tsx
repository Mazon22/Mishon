import type { PropsWithChildren } from 'react';

import { AuthProvider } from './AuthContext';
import { LiveSyncProvider } from './LiveSyncContext';
import { ThemeProvider } from './ThemeContext';

export function AppProviders({ children }: PropsWithChildren) {
  return (
    <ThemeProvider>
      <AuthProvider>
        <LiveSyncProvider>{children}</LiveSyncProvider>
      </AuthProvider>
    </ThemeProvider>
  );
}

import type { PropsWithChildren } from 'react';

import { AuthProvider } from './AuthContext';
import { ThemeProvider } from './ThemeContext';

export function AppProviders({ children }: PropsWithChildren) {
  return (
    <ThemeProvider>
      <AuthProvider>{children}</AuthProvider>
    </ThemeProvider>
  );
}

import { useEffect, useMemo, type PropsWithChildren } from 'react';

import { ThemeContext, type ThemeContextValue } from './theme-context';

const STORAGE_KEY = 'mishon-web-theme';

export function ThemeProvider({ children }: PropsWithChildren) {
  useEffect(() => {
    document.documentElement.dataset.theme = 'dark';
    window.localStorage.setItem(STORAGE_KEY, 'dark');
  }, []);

  const value = useMemo<ThemeContextValue>(
    () => ({
      theme: 'dark',
      setTheme: () => undefined,
      toggleTheme: () => undefined,
    }),
    [],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

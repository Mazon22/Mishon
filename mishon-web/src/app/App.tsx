import { useEffect } from 'react';
import { BrowserRouter } from 'react-router-dom';

import { AppSplash } from './components/AppSplash';
import { useAppBootSplash } from './hooks/useAppBootSplash';
import { AppProviders } from './providers/AppProviders';
import { useAuth } from './providers/useAuth';
import { AppRouter } from './router/AppRouter';
import { preloadAppRoutes } from './router/preloadRoutes';

function AppBootstrap() {
  const { isReady } = useAuth();
  const { isVisible, isExiting } = useAppBootSplash(isReady);

  useEffect(() => {
    if (isReady) {
      preloadAppRoutes();
    }
  }, [isReady]);

  return (
    <>
      <AppRouter />
      {isVisible ? <AppSplash exiting={isExiting} /> : null}
    </>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AppProviders>
        <AppBootstrap />
      </AppProviders>
    </BrowserRouter>
  );
}

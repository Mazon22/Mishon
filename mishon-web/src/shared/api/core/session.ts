import type { AuthResponse } from '../../types/api';

export type SessionProvider = {
  getAccessToken: () => string | null;
  getRefreshToken: () => string | null;
  onTokens: (tokens: AuthResponse) => void;
  onLogout: () => void;
};

let sessionProvider: SessionProvider | null = null;

export function configureApi(provider: SessionProvider) {
  sessionProvider = provider;
}

export function getSessionProvider() {
  return sessionProvider;
}

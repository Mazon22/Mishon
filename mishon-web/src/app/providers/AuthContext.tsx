import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type PropsWithChildren,
} from 'react';

import { AuthContext, type AuthContextValue, type SessionState } from './auth-context';
import { api, configureApi } from '../../shared/api/api';
import type { AuthResponse, Profile } from '../../shared/types/api';

const STORAGE_KEY = 'mishon-web-session';

function mapSession(response: AuthResponse): SessionState {
  return {
    token: response.token,
    refreshToken: response.refreshToken,
    sessionId: response.sessionId,
    accessTokenExpiresAt: response.accessTokenExpiresAt,
    refreshTokenExpiry: response.refreshTokenExpiry,
    role: response.role,
    emailVerified: response.emailVerified,
    userId: response.userId,
    username: response.username,
    email: response.email,
  };
}

function readStoredSession() {
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw) as SessionState;
  } catch {
    window.localStorage.removeItem(STORAGE_KEY);
    return null;
  }
}

export function AuthProvider({ children }: PropsWithChildren) {
  const [session, setSession] = useState<SessionState | null>(() => readStoredSession());
  const [profile, setProfile] = useState<Profile | null>(null);
  const [isReady, setIsReady] = useState(false);
  const sessionRef = useRef(session);

  useEffect(() => {
    sessionRef.current = session;
    if (session) {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
    } else {
      window.localStorage.removeItem(STORAGE_KEY);
    }
  }, [session]);

  useEffect(() => {
    configureApi({
      getAccessToken: () => sessionRef.current?.token ?? null,
      getRefreshToken: () => sessionRef.current?.refreshToken ?? null,
      onTokens: (tokens) => {
        setSession(mapSession(tokens));
      },
      onLogout: () => {
        setSession(null);
        setProfile(null);
      },
    });
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function bootstrap() {
      if (!sessionRef.current) {
        setIsReady(true);
        return;
      }

      try {
        const nextProfile = await api.auth.me();
        if (!cancelled) {
          setProfile(nextProfile);
        }
      } catch {
        if (!cancelled) {
          setSession(null);
          setProfile(null);
        }
      } finally {
        if (!cancelled) {
          setIsReady(true);
        }
      }
    }

    void bootstrap();

    return () => {
      cancelled = true;
    };
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const response = await api.auth.login(email, password);
    const nextSession = mapSession(response);
    setSession(nextSession);
    const nextProfile = await api.auth.me();
    setProfile(nextProfile);
  }, []);

  const register = useCallback(async (username: string, email: string, password: string) => {
    const response = await api.auth.register(username, email, password);
    const nextSession = mapSession(response);
    setSession(nextSession);
    const nextProfile = await api.auth.me();
    setProfile(nextProfile);
  }, []);

  const logout = useCallback(async () => {
    try {
      await api.auth.logout();
    } finally {
      setSession(null);
      setProfile(null);
    }
  }, []);

  const refreshProfile = useCallback(async () => {
    if (!sessionRef.current) {
      return null;
    }

    const nextProfile = await api.auth.me();
    setProfile(nextProfile);
    return nextProfile;
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      profile,
      isReady,
      isAuthenticated: Boolean(session),
      login,
      register,
      logout,
      refreshProfile,
      updateProfileState: setProfile,
    }),
    [isReady, login, logout, profile, refreshProfile, register, session],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

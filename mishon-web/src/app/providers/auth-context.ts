import { createContext } from 'react';

import type { Profile } from '../../shared/types/api';

export type SessionState = {
  token: string;
  refreshToken: string;
  sessionId: string;
  accessTokenExpiresAt: string;
  refreshTokenExpiry: string;
  role: string;
  emailVerified: boolean;
  userId: number;
  username: string;
  email: string;
};

export type AuthContextValue = {
  session: SessionState | null;
  profile: Profile | null;
  isReady: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (username: string, email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshProfile: () => Promise<Profile | null>;
  updateProfileState: (profile: Profile) => void;
};

export const AuthContext = createContext<AuthContextValue | null>(null);

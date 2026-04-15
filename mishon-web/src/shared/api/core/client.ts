import axios, { type AxiosError, type AxiosInstance, type InternalAxiosRequestConfig } from 'axios';

import type { ApiError, AuthResponse } from '../../types/api';
import { normalizeError } from './errors';
import { getSessionProvider } from './session';

const baseURL = import.meta.env.VITE_API_URL ?? '/api/v1';
const chatsBaseURL = baseURL.replace(/\/api\/v1\/?$/i, '/api').replace(/\/+$/, '') || '/api';

export interface ApiRequestConfig extends InternalAxiosRequestConfig {
  skipAuth?: boolean;
  _retry?: boolean;
}

function createHttpClient(instanceBaseURL: string) {
  return axios.create({
    baseURL: instanceBaseURL,
    timeout: 20000,
    headers: {
      'Content-Type': 'application/json',
    },
  });
}

function clearMultipartContentType(headers: InternalAxiosRequestConfig['headers']) {
  if (!headers) {
    return;
  }

  const normalizedHeaders = headers as InternalAxiosRequestConfig['headers'] & {
    delete?: (name: string) => void;
  };

  if (typeof normalizedHeaders.delete === 'function') {
    normalizedHeaders.delete('Content-Type');
    normalizedHeaders.delete('content-type');
    return;
  }

  delete (normalizedHeaders as Record<string, unknown>)['Content-Type'];
  delete (normalizedHeaders as Record<string, unknown>)['content-type'];
}

export const client = createHttpClient(baseURL);
export const compatClient = createHttpClient(chatsBaseURL);
export const chatsClient = compatClient;

let refreshPromise: Promise<AuthResponse> | null = null;

async function refreshTokens(refreshToken: string) {
  const response = await client.post<AuthResponse>(
    '/auth/refresh',
    { refreshToken },
    { skipAuth: true } as ApiRequestConfig,
  );
  return response.data;
}

function attachInterceptors(instance: AxiosInstance) {
  instance.interceptors.request.use((config) => {
    const nextConfig = config as ApiRequestConfig;
    if (typeof FormData !== 'undefined' && nextConfig.data instanceof FormData) {
      // Let the browser set the multipart boundary; keeping JSON defaults here breaks uploads.
      clearMultipartContentType(nextConfig.headers);
    }

    if (!nextConfig.skipAuth) {
      const token = getSessionProvider()?.getAccessToken();
      if (token) {
        nextConfig.headers.Authorization = `Bearer ${token}`;
      }
    }

    return nextConfig;
  });

  instance.interceptors.response.use(
    (response) => response,
    async (error: AxiosError<ApiError>) => {
      const originalRequest = error.config as ApiRequestConfig | undefined;
      if (!originalRequest) {
        throw normalizeError(error);
      }

      const sessionProvider = getSessionProvider();

      if (
        error.response?.status === 401 &&
        !originalRequest.skipAuth &&
        !originalRequest._retry &&
        sessionProvider?.getRefreshToken()
      ) {
        originalRequest._retry = true;
        try {
          refreshPromise ??= refreshTokens(sessionProvider.getRefreshToken()!);
          const refreshed = await refreshPromise;
          sessionProvider.onTokens(refreshed);
          originalRequest.headers.Authorization = `Bearer ${refreshed.token}`;
          return instance(originalRequest);
        } catch {
          sessionProvider.onLogout();
        } finally {
          refreshPromise = null;
        }
      }

      throw normalizeError(error);
    },
  );
}

attachInterceptors(client);
attachInterceptors(compatClient);

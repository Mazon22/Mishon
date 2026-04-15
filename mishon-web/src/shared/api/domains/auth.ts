import type { AuthResponse, Profile } from '../../types/api';
import { client, compatClient, type ApiRequestConfig } from '../core/client';
import { asRecord, normalizeMobileProfile, normalizeProfile } from '../core/normalizers';

export const authApi = {
  async login(email: string, password: string) {
    const response = await client.post<AuthResponse>(
      '/auth/login',
      { email, password },
      { skipAuth: true } as ApiRequestConfig,
    );
    return response.data;
  },
  async register(username: string, email: string, password: string) {
    const response = await client.post<AuthResponse>(
      '/auth/register',
      { username, email, password },
      { skipAuth: true } as ApiRequestConfig,
    );
    return response.data;
  },
  async me() {
    const response = await client.get<Profile>('/auth/me');
    return normalizeProfile(response.data);
  },
  async forgotPassword(email: string) {
    await client.post(
      '/auth/forgot-password',
      { email },
      { skipAuth: true } as ApiRequestConfig,
    );
  },
  async resetPassword(token: string, newPassword: string) {
    await client.post(
      '/auth/reset-password',
      { token, newPassword },
      { skipAuth: true } as ApiRequestConfig,
    );
  },
  async resendVerification(email: string) {
    await client.post(
      '/auth/resend-verification',
      { email },
      { skipAuth: true } as ApiRequestConfig,
    );
  },
  async verifyEmail(token: string) {
    await client.post(
      '/auth/verify-email',
      { token },
      { skipAuth: true } as ApiRequestConfig,
    );
  },
  async mobileProfile() {
    const response = await compatClient.get<Profile>('/auth/profile');
    return normalizeMobileProfile(asRecord(response.data));
  },
  async logout() {
    await client.post('/auth/logout');
  },
};

import type {
  PagedResponse,
  Post,
  PrivacySettings,
  Profile,
  ProfileMediaUpdateInput,
  ProfilePostsQuery,
  ProfileUpdateInput,
  SessionInfo,
} from '../../types/api';
import { client, compatClient } from '../core/client';
import { asRecord, normalizeMobileProfile, normalizePost, normalizeProfile } from '../core/normalizers';

export const profileApi = {
  async get() {
    const response = await client.get<Profile>('/profile');
    return normalizeProfile(response.data);
  },
  async getUser(userId: number) {
    const response = await compatClient.get(`/auth/profile/${userId}`);
    return normalizeMobileProfile(asRecord(response.data));
  },
  async update(payload: ProfileUpdateInput) {
    const response = await client.put<Profile>('/profile', payload);
    return normalizeProfile(response.data);
  },
  async updateMedia(payload: ProfileMediaUpdateInput) {
    const formData = new FormData();
    if (payload.avatar) {
      formData.append('avatar', payload.avatar);
    }
    if (payload.banner) {
      formData.append('banner', payload.banner);
    }
    if (payload.avatarScale !== undefined) {
      formData.append('avatarScale', String(payload.avatarScale));
    }
    if (payload.avatarOffsetX !== undefined) {
      formData.append('avatarOffsetX', String(payload.avatarOffsetX));
    }
    if (payload.avatarOffsetY !== undefined) {
      formData.append('avatarOffsetY', String(payload.avatarOffsetY));
    }
    if (payload.bannerScale !== undefined) {
      formData.append('bannerScale', String(payload.bannerScale));
    }
    if (payload.bannerOffsetX !== undefined) {
      formData.append('bannerOffsetX', String(payload.bannerOffsetX));
    }
    if (payload.bannerOffsetY !== undefined) {
      formData.append('bannerOffsetY', String(payload.bannerOffsetY));
    }
    if (payload.removeAvatar) {
      formData.append('removeAvatar', 'true');
    }
    if (payload.removeBanner) {
      formData.append('removeBanner', 'true');
    }

    const response = await client.put<Profile>('/profile/media', formData, {
      timeout: 90000,
    });
    return normalizeProfile(response.data);
  },
  async getPrivacy() {
    const response = await compatClient.get<PrivacySettings>('/users/me/privacy');
    return response.data;
  },
  async updatePrivacy(payload: PrivacySettings) {
    const response = await compatClient.put<PrivacySettings>('/users/me/privacy', payload);
    return response.data;
  },
  async getSessions() {
    const response = await client.get<SessionInfo[]>('/auth/sessions');
    return response.data;
  },
  async revokeSession(sessionId: string) {
    await client.delete(`/auth/sessions/${sessionId}`);
  },
  async logoutAllSessions() {
    await client.post('/auth/logout-all');
  },
  async posts(query: ProfilePostsQuery = {}) {
    const { page = 1, pageSize = 12, tab = 'posts', userId } = query;
    const response = await client.get<PagedResponse<Post>>('/profile/posts', {
      params: { page, pageSize, tab, userId },
    });
    return {
      ...response.data,
      items: response.data.items.map((item) => normalizePost(item)),
    };
  },
  async userPosts(query: ProfilePostsQuery) {
    const { userId, ...rest } = query;
    if (!userId) {
      throw new Error('Missing userId for profile posts request.');
    }

    return profileApi.posts({
      ...rest,
      userId,
    });
  },
};

import axios, { AxiosError, type InternalAxiosRequestConfig } from 'axios';

import type {
  ApiError,
  AuthResponse,
  Comment,
  Conversation,
  FollowToggleResponse,
  FriendCard,
  FriendRequestsPayload,
  Message,
  NotificationItem,
  NotificationSummary,
  PagedResponse,
  Post,
  Profile,
} from '../types/api';

const baseURL = import.meta.env.VITE_API_URL ?? '/api/v1';

type SessionProvider = {
  getAccessToken: () => string | null;
  getRefreshToken: () => string | null;
  onTokens: (tokens: AuthResponse) => void;
  onLogout: () => void;
};

let sessionProvider: SessionProvider | null = null;
let refreshPromise: Promise<AuthResponse> | null = null;

interface ApiRequestConfig extends InternalAxiosRequestConfig {
  skipAuth?: boolean;
  _retry?: boolean;
}

export class HttpError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.status = status;
  }
}

export function configureApi(provider: SessionProvider) {
  sessionProvider = provider;
}

const client = axios.create({
  baseURL,
  timeout: 20000,
  headers: {
    'Content-Type': 'application/json',
  },
});

client.interceptors.request.use((config) => {
  const nextConfig = config as ApiRequestConfig;
  if (!nextConfig.skipAuth) {
    const token = sessionProvider?.getAccessToken();
    if (token) {
      nextConfig.headers.Authorization = `Bearer ${token}`;
    }
  }

  return nextConfig;
});

client.interceptors.response.use(
  (response) => response,
  async (error: AxiosError<ApiError>) => {
    const originalRequest = error.config as ApiRequestConfig | undefined;
    if (!originalRequest) {
      throw normalizeError(error);
    }

    if (error.response?.status === 401 && !originalRequest.skipAuth && !originalRequest._retry && sessionProvider?.getRefreshToken()) {
      originalRequest._retry = true;
      try {
        refreshPromise ??= refreshTokens(sessionProvider.getRefreshToken()!);
        const refreshed = await refreshPromise;
        sessionProvider.onTokens(refreshed);
        originalRequest.headers.Authorization = `Bearer ${refreshed.token}`;
        return client(originalRequest);
      } catch {
        sessionProvider?.onLogout();
      } finally {
        refreshPromise = null;
      }
    }

    throw normalizeError(error);
  },
);

function normalizeError(error: AxiosError<ApiError>) {
  const message = error.response?.data?.message ?? error.message ?? 'Request failed';
  return new HttpError(message, error.response?.status ?? 500);
}

async function refreshTokens(refreshToken: string) {
  const response = await client.post<AuthResponse>(
    '/auth/refresh',
    { refreshToken },
    { skipAuth: true } as ApiRequestConfig,
  );
  return response.data;
}

function extractItems<T>(payload: { items: T[] }) {
  return payload.items;
}

export const api = {
  auth: {
    async login(email: string, password: string) {
      const response = await client.post<AuthResponse>('/auth/login', { email, password }, { skipAuth: true } as ApiRequestConfig);
      return response.data;
    },
    async register(username: string, email: string, password: string) {
      const response = await client.post<AuthResponse>('/auth/register', { username, email, password }, { skipAuth: true } as ApiRequestConfig);
      return response.data;
    },
    async me() {
      const response = await client.get<Profile>('/auth/me');
      return response.data;
    },
    async logout() {
      await client.post('/auth/logout');
    },
  },
  profile: {
    async get() {
      const response = await client.get<Profile>('/profile');
      return response.data;
    },
    async update(payload: Partial<Profile>) {
      const response = await client.put<Profile>('/profile', payload);
      return response.data;
    },
    async posts(page = 1, pageSize = 12) {
      const response = await client.get<PagedResponse<Post>>('/profile/posts', { params: { page, pageSize } });
      return response.data;
    },
  },
  feed: {
    async list(mode: 'for-you' | 'following', page = 1, pageSize = 12) {
      const response = await client.get<PagedResponse<Post>>('/feed', {
        params: { page, pageSize, mode: mode === 'following' ? 'following' : undefined },
      });
      return response.data;
    },
    async create(content: string, imageUrl?: string) {
      const response = await client.post<Post>('/posts', { content, imageUrl });
      return response.data;
    },
    async update(postId: number, content: string, imageUrl?: string) {
      const response = await client.patch<Post>(`/posts/${postId}`, { content, imageUrl });
      return response.data;
    },
    async remove(postId: number) {
      await client.delete(`/posts/${postId}`);
    },
    async toggleLike(postId: number) {
      const response = await client.post<Post>(`/posts/${postId}/like`);
      return response.data;
    },
    async comments(postId: number) {
      const response = await client.get<{ items: Comment[] }>(`/posts/${postId}/comments`);
      return extractItems(response.data);
    },
    async createComment(postId: number, content: string) {
      const response = await client.post<{ items: Comment[] }>(`/posts/${postId}/comments`, { content });
      return extractItems(response.data);
    },
  },
  chats: {
    async list() {
      const response = await client.get<{ items: Conversation[] }>('/chats');
      return extractItems(response.data);
    },
    async openDirect(userId: number) {
      const response = await client.post<Conversation>(`/chats/direct/${userId}`);
      return response.data;
    },
    async messages(chatId: number, before?: number) {
      const response = await client.get<{ items: Message[] }>(`/chats/${chatId}/messages`, {
        params: { limit: 40, before },
      });
      return extractItems(response.data);
    },
    async send(chatId: number, content: string) {
      const response = await client.post<Message>(`/chats/${chatId}/messages`, { content });
      return response.data;
    },
  },
  friends: {
    async list() {
      const response = await client.get<{ items: FriendCard[] }>('/friends');
      return extractItems(response.data);
    },
    async requests() {
      const response = await client.get<FriendRequestsPayload>('/friends/requests');
      return response.data;
    },
    async sendRequest(userId: number) {
      await client.post('/friends/requests', { userId });
    },
    async acceptRequest(requestId: number) {
      await client.post(`/friends/requests/${requestId}/accept`);
    },
    async deleteRequest(requestId: number) {
      await client.delete(`/friends/requests/${requestId}`);
    },
    async remove(userId: number) {
      await client.delete(`/friends/${userId}`);
    },
    async discover(query: string, page = 1, pageSize = 16) {
      const response = await client.get<PagedResponse<FriendCard>>('/discover', { params: { query, page, pageSize } });
      return response.data;
    },
    async toggleFollow(userId: number) {
      const response = await client.post<FollowToggleResponse>(`/follows/${userId}/toggle`);
      return response.data;
    },
  },
  notifications: {
    async list(page = 1, pageSize = 20) {
      const response = await client.get<PagedResponse<NotificationItem>>('/notifications', { params: { page, pageSize } });
      return response.data;
    },
    async summary() {
      const response = await client.get<NotificationSummary>('/notifications/summary');
      return response.data;
    },
    async markRead(notificationId: number) {
      await client.post(`/notifications/${notificationId}/read`);
    },
    async markAllRead() {
      await client.post('/notifications/read-all');
    },
  },
};

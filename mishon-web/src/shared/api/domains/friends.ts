import { resolveMediaUrl } from '../../lib/media';
import type { FollowListEntry, FollowToggleResponse, FriendCard, FriendRequestsPayload, PagedResponse } from '../../types/api';
import { client, compatClient } from '../core/client';
import { asRecord, extractItems, normalizeFriendCard, normalizeFriendRequestPayload } from '../core/normalizers';

function normalizeMobileFriend(payload: Record<string, unknown>): FriendCard {
  return normalizeFriendCard({
    id: Number(payload.id ?? 0),
    username: typeof payload.username === 'string' ? payload.username : 'mishon',
    displayName: typeof payload.username === 'string' ? payload.username : 'mishon',
    aboutMe: typeof payload.aboutMe === 'string' ? payload.aboutMe : null,
    avatarUrl: typeof payload.avatarUrl === 'string' ? payload.avatarUrl : null,
    avatarScale: Number(payload.avatarScale ?? 1),
    avatarOffsetX: Number(payload.avatarOffsetX ?? 0),
    avatarOffsetY: Number(payload.avatarOffsetY ?? 0),
    lastSeenAt: typeof payload.lastSeenAt === 'string' ? payload.lastSeenAt : new Date(0).toISOString(),
    isOnline: Boolean(payload.isOnline),
    followersCount: Number(payload.followersCount ?? 0),
    postsCount: Number(payload.postsCount ?? 0),
    isFollowing: Boolean(payload.isFollowing),
    isFriend: Boolean(payload.isFriend),
    incomingFriendRequestId: typeof payload.incomingFriendRequestId === 'number' ? payload.incomingFriendRequestId : null,
    outgoingFriendRequestId: typeof payload.outgoingFriendRequestId === 'number' ? payload.outgoingFriendRequestId : null,
    hasPendingFollowRequest: Boolean(payload.hasPendingFollowRequest),
    isPrivateAccount: Boolean(payload.isPrivateAccount),
    profileVisibility: typeof payload.profileVisibility === 'string' ? payload.profileVisibility : 'Public',
  });
}

function normalizeFollowListEntry(payload: Record<string, unknown>): FollowListEntry {
  const username = typeof payload.username === 'string' ? payload.username : 'mishon';

  return {
    id: Number(payload.id ?? 0),
    username,
    displayName: typeof payload.displayName === 'string' ? payload.displayName : null,
    isVerified: Boolean(payload.isVerified ?? payload.emailVerified),
    avatarUrl: resolveMediaUrl(typeof payload.avatarUrl === 'string' ? payload.avatarUrl : null),
    avatarScale: Number(payload.avatarScale ?? 1),
    avatarOffsetX: Number(payload.avatarOffsetX ?? 0),
    avatarOffsetY: Number(payload.avatarOffsetY ?? 0),
    isFollowing: Boolean(payload.isFollowing),
    isPrivateAccount: Boolean(payload.isPrivateAccount),
  };
}

export const friendsApi = {
  async list() {
    const response = await client.get<{ items: FriendCard[] }>('/friends');
    return extractItems(response.data).map((item) => normalizeFriendCard(item));
  },
  async requests() {
    const response = await client.get<FriendRequestsPayload>('/friends/requests');
    return normalizeFriendRequestPayload(response.data);
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
    return {
      ...response.data,
      items: response.data.items.map((item) => normalizeFriendCard(item)),
    };
  },
  async toggleFollow(userId: number) {
    const response = await client.post<FollowToggleResponse>(`/follows/${userId}/toggle`);
    return response.data;
  },
  async followers(userId: number) {
    const response = await compatClient.get<unknown[]>(`/follows/${userId}/followers`);
    return (response.data as unknown[]).map((item) => normalizeFollowListEntry(asRecord(item)));
  },
  async following(userId: number) {
    const response = await compatClient.get<unknown[]>(`/follows/${userId}/following`);
    return (response.data as unknown[]).map((item) => normalizeFollowListEntry(asRecord(item)));
  },
  async incomingFollowRequests() {
    const response = await compatClient.get<unknown[]>('/follows/requests');
    return (response.data as Record<string, unknown>[]).map((item) => ({
      id: Number(item.id ?? 0),
      userId: Number(item.userId ?? 0),
      user: {
        id: Number(item.userId ?? 0),
        username: typeof item.username === 'string' ? item.username : 'mishon',
        displayName: typeof item.username === 'string' ? item.username : 'mishon',
        avatarUrl: typeof item.avatarUrl === 'string' ? item.avatarUrl : null,
        avatarScale: Number(item.avatarScale ?? 1),
        avatarOffsetX: Number(item.avatarOffsetX ?? 0),
        avatarOffsetY: Number(item.avatarOffsetY ?? 0),
        lastSeenAt: typeof item.lastSeenAt === 'string' ? item.lastSeenAt : null,
        isOnline: Boolean(item.isOnline),
      },
      aboutMe: typeof item.aboutMe === 'string' ? item.aboutMe : null,
      isIncoming: true,
      createdAt: typeof item.createdAt === 'string' ? item.createdAt : new Date().toISOString(),
    }));
  },
  async approveFollowRequest(requestId: number) {
    await compatClient.post(`/follows/requests/${requestId}/approve`);
  },
  async rejectFollowRequest(requestId: number) {
    await compatClient.post(`/follows/requests/${requestId}/reject`);
  },
  async blockedUsers() {
    const response = await compatClient.get<unknown[]>('/chat/blocked-users');
    return (response.data as Record<string, unknown>[]).map((item) => normalizeMobileFriend(asRecord(item)));
  },
  async unblock(userId: number) {
    await compatClient.post('/chat/unblock-user', { userId });
  },
};

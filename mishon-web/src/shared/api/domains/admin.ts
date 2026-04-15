import type {
  AdminUserDetail,
  AdminUserSummary,
  AdminUsersFilter,
  FreezeUserInput,
  HardDeleteUserInput,
  PagedResponse,
  ReplySupportThreadInput,
  SupportThread,
  SupportThreadDetail,
} from '../../types/api';
import {
  asRecord,
  normalizeAdminUser,
  normalizeAdminUserDetail,
  normalizeSupportMessage,
  normalizeSupportThread,
  normalizeSupportThreadDetail,
} from '../core/normalizers';
import { client } from '../core/client';

export const adminApi = {
  async users(page = 1, pageSize = 25, filter: AdminUsersFilter = 'all', query = '') {
    const response = await client.get<PagedResponse<AdminUserSummary>>('/admin/users', {
      params: { page, pageSize, filter, query },
    });
    return {
      ...response.data,
      items: response.data.items.map((item) => normalizeAdminUser(asRecord(item))),
    };
  },
  async userDetail(userId: number) {
    const response = await client.get<AdminUserDetail>(`/admin/users/${userId}`);
    return normalizeAdminUserDetail(asRecord(response.data));
  },
  async freezeUser(userId: number, payload: FreezeUserInput) {
    await client.post(`/admin/users/${userId}/freeze`, payload);
  },
  async unfreezeUser(userId: number) {
    await client.post(`/admin/users/${userId}/unfreeze`, {});
  },
  async hardDeleteUser(userId: number, payload: HardDeleteUserInput) {
    await client.post(`/admin/users/${userId}/hard-delete`, payload);
  },
  async supportThreads(page = 1, pageSize = 20, status = '', query = '') {
    const response = await client.get<PagedResponse<SupportThread>>('/admin/support/threads', {
      params: { page, pageSize, status, query },
    });
    return {
      ...response.data,
      items: response.data.items.map((item) => normalizeSupportThread(asRecord(item))),
    };
  },
  async supportThread(threadId: number) {
    const response = await client.get<SupportThreadDetail>(`/admin/support/threads/${threadId}`);
    return normalizeSupportThreadDetail(asRecord(response.data));
  },
  async replySupportThread(threadId: number, payload: ReplySupportThreadInput) {
    const response = await client.post(`/admin/support/threads/${threadId}/reply`, payload);
    return normalizeSupportMessage(asRecord(response.data));
  },
  async closeSupportThread(threadId: number) {
    const response = await client.post(`/admin/support/threads/${threadId}/close`);
    return normalizeSupportThread(asRecord(response.data));
  },
  async reopenSupportThread(threadId: number) {
    const response = await client.post(`/admin/support/threads/${threadId}/reopen`);
    return normalizeSupportThread(asRecord(response.data));
  },
};

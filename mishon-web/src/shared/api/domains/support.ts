import type {
  CreateSupportThreadInput,
  PagedResponse,
  ReplySupportThreadInput,
  SupportThread,
  SupportThreadDetail,
  SupportThreadStatus,
} from '../../types/api';
import { asRecord, normalizeSupportMessage, normalizeSupportThread, normalizeSupportThreadDetail } from '../core/normalizers';
import { client } from '../core/client';

export const supportApi = {
  async threads(page = 1, pageSize = 20, status: SupportThreadStatus | '' = '') {
    const response = await client.get<PagedResponse<SupportThread>>('/support/threads', {
      params: { page, pageSize, status },
    });
    return {
      ...response.data,
      items: response.data.items.map((item) => normalizeSupportThread(asRecord(item))),
    };
  },
  async createThread(payload: CreateSupportThreadInput) {
    const response = await client.post<SupportThreadDetail>('/support/threads', payload);
    return normalizeSupportThreadDetail(asRecord(response.data));
  },
  async thread(threadId: number) {
    const response = await client.get<SupportThreadDetail>(`/support/threads/${threadId}`);
    return normalizeSupportThreadDetail(asRecord(response.data));
  },
  async reply(threadId: number, payload: ReplySupportThreadInput) {
    const response = await client.post(`/support/threads/${threadId}/messages`, payload);
    return normalizeSupportMessage(asRecord(response.data));
  },
  async markRead(threadId: number) {
    await client.post(`/support/threads/${threadId}/read`);
  },
};

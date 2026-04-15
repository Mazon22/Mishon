import type { NotificationItem, NotificationSummary, PagedResponse } from '../../types/api';
import { client } from '../core/client';
import { normalizeNotification } from '../core/normalizers';

export const notificationsApi = {
  async list(page = 1, pageSize = 20) {
    const response = await client.get<PagedResponse<NotificationItem>>('/notifications', { params: { page, pageSize } });
    return {
      ...response.data,
      items: response.data.items.map((item) => normalizeNotification(item)),
    };
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
};

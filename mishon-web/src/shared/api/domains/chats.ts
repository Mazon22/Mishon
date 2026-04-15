import type { Conversation, Message } from '../../types/api';
import { chatsClient } from '../core/client';
import { asRecord, extractItems, normalizeConversation, normalizeMessage } from '../core/normalizers';

export const chatsApi = {
  async list() {
    const response = await chatsClient.get<Conversation[]>('/conversations');
    return response.data.map((item) => normalizeConversation(asRecord(item)));
  },
  async openDirect(userId: number) {
    const response = await chatsClient.post<Conversation>(`/conversations/direct/${userId}`);
    return normalizeConversation(asRecord(response.data));
  },
  async messages(chatId: number, before?: number) {
    const response = await chatsClient.get<{ items: Message[] }>(`/conversations/${chatId}/messages`, {
      params: { limit: 40, beforeMessageId: before },
    });
    return extractItems(response.data).map((item) => normalizeMessage(asRecord(item)));
  },
  async send(
    chatId: number,
    payload: {
      content?: string;
      replyToMessageId?: number;
      attachments?: File[];
    },
  ) {
    const attachments = payload.attachments ?? [];
    if (attachments.length > 0) {
      const formData = new FormData();
      if (payload.content?.trim()) {
        formData.append('content', payload.content.trim());
      }
      if (payload.replyToMessageId) {
        formData.append('replyToMessageId', String(payload.replyToMessageId));
      }
      for (const attachment of attachments) {
        formData.append('files', attachment);
      }

      const response = await chatsClient.post<Message>(`/conversations/${chatId}/messages`, formData, {
        timeout: 90000,
      });
      return normalizeMessage(asRecord(response.data));
    }

    const response = await chatsClient.post<Message>(`/conversations/${chatId}/messages`, {
      content: payload.content?.trim() ?? '',
    });
    return normalizeMessage(asRecord(response.data));
  },
  async update(chatId: number, messageId: number, content: string) {
    const response = await chatsClient.put<Message>(`/conversations/${chatId}/messages/${messageId}`, { content });
    return normalizeMessage(asRecord(response.data));
  },
  async remove(chatId: number, messageId: number) {
    await chatsClient.delete(`/conversations/${chatId}/messages/${messageId}`);
  },
  async removeForAll(chatId: number, messageId: number) {
    await chatsClient.post('/message/delete-for-all', { conversationId: chatId, messageId });
  },
  async forward(chatId: number, messageId: number) {
    const response = await chatsClient.post<Message>(`/conversations/${chatId}/messages/forward`, { messageId });
    return normalizeMessage(asRecord(response.data));
  },
  async pin(chatId: number, isPinned: boolean) {
    await chatsClient.post('/chat/pin', { conversationId: chatId, isPinned });
  },
  async archive(chatId: number, isArchived: boolean) {
    await chatsClient.post('/chat/archive', { conversationId: chatId, isArchived });
  },
  async favorite(chatId: number, isFavorite: boolean) {
    await chatsClient.post('/chat/favorite', { conversationId: chatId, isFavorite });
  },
  async mute(chatId: number, isMuted: boolean) {
    await chatsClient.post('/chat/mute', { conversationId: chatId, isMuted });
  },
  async deleteConversation(chatId: number, deleteForBoth: boolean) {
    await chatsClient.delete('/chat', { data: { conversationId: chatId, deleteForBoth } });
  },
  async clearHistory(chatId: number) {
    await chatsClient.post('/chat/clear-history', { conversationId: chatId });
  },
  async blockUser(userId: number) {
    await chatsClient.post('/chat/block-user', { userId });
  },
  async unblockUser(userId: number) {
    await chatsClient.post('/chat/unblock-user', { userId });
  },
  async typingStart(chatId: number) {
    await chatsClient.post('/chat/typing-start', { conversationId: chatId });
  },
  async typingStop(chatId: number) {
    await chatsClient.post('/chat/typing-stop', { conversationId: chatId });
  },
};

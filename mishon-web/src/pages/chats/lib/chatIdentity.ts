import { getConversationPreview } from '../../../shared/lib/chatContent';
import type { Conversation, Profile } from '../../../shared/types/api';
import type { ForwardDestination } from '../types';

const SAVED_MESSAGES_TITLE = 'Saved Messages';
const SAVED_MESSAGES_SUBTITLE = 'Личные заметки, файлы и пересылки';

type ChatAvatar = {
  avatarUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
};

export function isSavedMessagesChat(chat: Conversation, currentUserId: number | undefined) {
  return currentUserId !== undefined && chat.peerId === currentUserId;
}

export function getSavedMessagesTitle() {
  return SAVED_MESSAGES_TITLE;
}

export function getSavedMessagesSubtitle() {
  return SAVED_MESSAGES_SUBTITLE;
}

export function getChatAvatar(
  chat: Conversation,
  currentUserId: number | undefined,
  profile?: Profile | null,
): ChatAvatar {
  if (!isSavedMessagesChat(chat, currentUserId)) {
    return {
      avatarUrl: chat.avatarUrl,
      avatarScale: chat.avatarScale,
      avatarOffsetX: chat.avatarOffsetX,
      avatarOffsetY: chat.avatarOffsetY,
    };
  }

  return {
    avatarUrl: profile?.avatarUrl ?? chat.avatarUrl,
    avatarScale: profile?.avatarScale ?? chat.avatarScale,
    avatarOffsetX: profile?.avatarOffsetX ?? chat.avatarOffsetX,
    avatarOffsetY: profile?.avatarOffsetY ?? chat.avatarOffsetY,
  };
}

export function getChatTitle(chat: Conversation, currentUserId: number | undefined) {
  return isSavedMessagesChat(chat, currentUserId) ? SAVED_MESSAGES_TITLE : chat.username;
}

export function getChatListSubtitle(chat: Conversation, currentUserId: number | undefined) {
  if (isSavedMessagesChat(chat, currentUserId)) {
    return SAVED_MESSAGES_SUBTITLE;
  }

  if (!chat.lastMessage) {
    return 'Начните разговор';
  }

  return `${chat.lastMessageIsMine ? 'Вы: ' : ''}${getConversationPreview(chat.lastMessage)}`;
}

export function getActiveChatSubtitle(chat: Conversation, currentUserId: number | undefined) {
  if (isSavedMessagesChat(chat, currentUserId)) {
    return SAVED_MESSAGES_SUBTITLE;
  }

  if (chat.isOnline) {
    return 'В сети';
  }

  return 'Диалог';
}

export function buildForwardDestinations(
  chats: Conversation[],
  currentUserId: number | undefined,
  profile?: Profile | null,
): ForwardDestination[] {
  const items: ForwardDestination[] = [];
  const seen = new Set<number>();

  if (currentUserId) {
    const savedMessagesChat = chats.find((chat) => isSavedMessagesChat(chat, currentUserId));
    items.push({
      conversationId: savedMessagesChat?.id ?? null,
      peerId: currentUserId,
      title: SAVED_MESSAGES_TITLE,
      subtitle: SAVED_MESSAGES_SUBTITLE,
      avatarUrl: profile?.avatarUrl ?? savedMessagesChat?.avatarUrl,
      avatarScale: profile?.avatarScale ?? savedMessagesChat?.avatarScale ?? 1,
      avatarOffsetX: profile?.avatarOffsetX ?? savedMessagesChat?.avatarOffsetX ?? 0,
      avatarOffsetY: profile?.avatarOffsetY ?? savedMessagesChat?.avatarOffsetY ?? 0,
    });
    seen.add(currentUserId);
  }

  for (const chat of chats) {
    if (seen.has(chat.peerId)) {
      continue;
    }

    seen.add(chat.peerId);
    const avatar = getChatAvatar(chat, currentUserId, profile);
    items.push({
      conversationId: chat.id,
      peerId: chat.peerId,
      title: getChatTitle(chat, currentUserId),
      subtitle: isSavedMessagesChat(chat, currentUserId)
        ? SAVED_MESSAGES_SUBTITLE
        : chat.lastMessage
          ? getConversationPreview(chat.lastMessage)
          : 'Пустой диалог',
      ...avatar,
    });
  }

  return items;
}

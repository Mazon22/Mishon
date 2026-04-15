import { startTransition, useMemo, useState } from 'react';

import { getConversationPreview } from '../../../shared/lib/chatContent';
import { formatRelativeDate } from '../../../shared/lib/format';
import type { Conversation, Profile } from '../../../shared/types/api';
import { AppIcon } from '../../../shared/ui/AppIcon';
import { UserAvatar } from '../../../shared/ui/UserAvatar';
import { getChatAvatar, getChatTitle, isSavedMessagesChat } from '../lib/chatIdentity';

type ConversationListProps = {
  chats: Conversation[];
  selectedChatId: number | null;
  currentUserId: number | undefined;
  profile?: Profile | null;
  busy: boolean;
  onSelect: (chatId: number) => void;
};

function getConversationMeta(chat: Conversation, currentUserId: number | undefined) {
  if (isSavedMessagesChat(chat, currentUserId)) {
    return 'Личные заметки и быстрые пересылки';
  }

  if (chat.lastMessage) {
    return `${chat.lastMessageIsMine ? 'Вы: ' : ''}${getConversationPreview(chat.lastMessage)}`;
  }

  if (chat.isOnline) {
    return 'В сети';
  }

  return 'Начните разговор';
}

export function ConversationList({
  chats,
  selectedChatId,
  currentUserId,
  profile,
  busy,
  onSelect,
}: ConversationListProps) {
  const [query, setQuery] = useState('');
  const normalizedQuery = query.trim().toLowerCase();

  const visibleChats = useMemo(
    () =>
      chats.filter((chat) => {
        if (!normalizedQuery) {
          return true;
        }

        const title = getChatTitle(chat, currentUserId).toLowerCase();
        const meta = getConversationMeta(chat, currentUserId).toLowerCase();
        const username = chat.username.toLowerCase();

        return title.includes(normalizedQuery) || meta.includes(normalizedQuery) || username.includes(normalizedQuery);
      }),
    [chats, currentUserId, normalizedQuery],
  );

  return (
    <aside className="chat-list">
      <header className="chat-list__header">
        <div className="chat-list__headline">
          <h1>Сообщения</h1>
          <span>{chats.length ? `${chats.length} диалогов` : 'Новых диалогов пока нет'}</span>
        </div>

        <div className="chat-list__search">
          <AppIcon className="chat-list__search-icon" name="search" />
          <input
            className="chat-list__search-input"
            placeholder="Поиск в сообщениях"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
        </div>
      </header>

      <div className="chat-list__body">
        {busy ? <div className="chat-list__empty">Загружаем диалоги…</div> : null}
        {!busy && visibleChats.length === 0 ? (
          <div className="chat-list__empty">
            {normalizedQuery ? 'Ничего не найдено по вашему запросу.' : 'Пока нет активных диалогов.'}
          </div>
        ) : null}

        {visibleChats.map((chat) => {
          const title = getChatTitle(chat, currentUserId);
          const meta = getConversationMeta(chat, currentUserId);
          const avatar = getChatAvatar(chat, currentUserId, profile);
          const isActive = chat.id === selectedChatId;
          const isSaved = isSavedMessagesChat(chat, currentUserId);

          return (
            <button
              key={chat.id}
              className={`chat-row${isActive ? ' chat-row--active' : ''}`}
              type="button"
              onClick={() => startTransition(() => onSelect(chat.id))}
            >
              <UserAvatar
                imageUrl={avatar.avatarUrl}
                name={title}
                offsetX={avatar.avatarOffsetX}
                offsetY={avatar.avatarOffsetY}
                scale={avatar.avatarScale}
                size="md"
              />

              <div className="chat-row__body">
                <div className="chat-row__headline">
                  <div className="chat-row__identity">
                    <strong>{title}</strong>
                    {!isSaved ? <span>@{chat.username}</span> : null}
                  </div>
                  <time>{formatRelativeDate(chat.lastMessageAt || chat.lastSeenAt)}</time>
                </div>

                <div className="chat-row__meta">
                  <span className="chat-row__message">{meta}</span>
                  {chat.unreadCount ? (
                    <span className="chat-row__badge">{chat.unreadCount > 99 ? '99+' : chat.unreadCount}</span>
                  ) : null}
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </aside>
  );
}

import { startTransition, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

import { api } from '../../shared/api/api';
import {
  getConversationPreview,
  getMessageText,
  parseSharedPostMessage,
  type SharedPostPayload,
} from '../../shared/lib/chatContent';
import { formatRelativeDate, initials } from '../../shared/lib/format';
import type { Conversation, Message } from '../../shared/types/api';

function SharedPostCard({ payload }: { payload: SharedPostPayload }) {
  return (
    <div className="shared-post">
      <div className="shared-post__header">
        <div className="avatar avatar--mini">
          {payload.userAvatarUrl ? (
            <img alt={payload.username} className="avatar__image" src={payload.userAvatarUrl} />
          ) : (
            initials(payload.username)
          )}
        </div>
        <div>
          <div className="shared-post__label">Поделился постом</div>
          <div className="shared-post__author">@{payload.username}</div>
        </div>
      </div>

      {payload.contentPreview ? (
        <div className="shared-post__content">{payload.contentPreview}</div>
      ) : (
        <div className="message-bubble__placeholder">Пост из мобильного приложения Mishon</div>
      )}

      {payload.imageUrl ? (
        <div className="shared-post__image">
          <img alt={`Пост пользователя @${payload.username}`} src={payload.imageUrl} />
        </div>
      ) : null}
    </div>
  );
}

export function ChatsPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [chats, setChats] = useState<Conversation[]>([]);
  const [messages, setMessages] = useState<Message[]>([]);
  const [selectedChatId, setSelectedChatId] = useState<number | null>(null);
  const [draft, setDraft] = useState('');
  const [busy, setBusy] = useState(true);
  const [messagesBusy, setMessagesBusy] = useState(false);
  const [sendBusy, setSendBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const messageListRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function loadChats() {
      setBusy(true);
      setError(null);
      try {
        const directUserId = Number(searchParams.get('chatWith'));
        const nextChats = await api.chats.list();
        let nextSelectedChatId = nextChats[0]?.id ?? null;

        if (Number.isFinite(directUserId) && directUserId > 0) {
          const directChat = await api.chats.openDirect(directUserId);
          const exists = nextChats.some((item) => item.id === directChat.id);
          const mergedChats = exists ? nextChats : [directChat, ...nextChats];
          if (!cancelled) {
            setChats(mergedChats);
          }
          nextSelectedChatId = directChat.id;
          setSearchParams((current) => {
            const next = new URLSearchParams(current);
            next.delete('chatWith');
            return next;
          });
        } else if (!cancelled) {
          setChats(nextChats);
        }

        if (!cancelled) {
          startTransition(() => setSelectedChatId(nextSelectedChatId));
        }
      } catch (nextError) {
        if (!cancelled) {
          setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить чаты.');
          setChats([]);
        }
      } finally {
        if (!cancelled) {
          setBusy(false);
        }
      }
    }

    void loadChats();

    return () => {
      cancelled = true;
    };
  }, [searchParams, setSearchParams]);

  useEffect(() => {
    let cancelled = false;

    async function loadMessages() {
      if (!selectedChatId) {
        setMessages([]);
        return;
      }

      setMessagesBusy(true);
      try {
        const nextMessages = await api.chats.messages(selectedChatId);
        if (!cancelled) {
          setMessages(nextMessages);
        }
      } catch (nextError) {
        if (!cancelled) {
          setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить сообщения.');
          setMessages([]);
        }
      } finally {
        if (!cancelled) {
          setMessagesBusy(false);
        }
      }
    }

    void loadMessages();

    return () => {
      cancelled = true;
    };
  }, [selectedChatId]);

  useEffect(() => {
    const list = messageListRef.current;
    if (!list) {
      return;
    }

    list.scrollTo({ top: list.scrollHeight, behavior: 'smooth' });
  }, [messages]);

  const activeChat = useMemo(
    () => chats.find((item) => item.id === selectedChatId) ?? null,
    [chats, selectedChatId],
  );

  async function sendMessage() {
    if (!selectedChatId || !draft.trim()) {
      return;
    }

    setSendBusy(true);
    setError(null);
    try {
      const sent = await api.chats.send(selectedChatId, draft.trim());
      setMessages((current) => [...current, sent]);
      setDraft('');
      const nextChats = await api.chats.list();
      setChats(nextChats);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось отправить сообщение.');
    } finally {
      setSendBusy(false);
    }
  }

  return (
    <div className="chat-layout">
      <section className="chat-list">
        <div className="panel__header">
          <div>
            <div className="section-title">Диалоги</div>
            <div className="section-subtitle">Личные сообщения как в Android-версии Mishon.</div>
          </div>
        </div>

        {busy ? <div className="empty-card">Загружаем чаты...</div> : null}
        {!busy && chats.length === 0 ? <div className="empty-card">Пока нет активных диалогов.</div> : null}

        {chats.map((chat) => (
          <button
            key={chat.id}
            className={`chat-row${chat.id === selectedChatId ? ' chat-row--active' : ''}`}
            type="button"
            onClick={() => startTransition(() => setSelectedChatId(chat.id))}
          >
            <div className="avatar">
              {chat.peer.avatarUrl ? (
                <img alt={chat.peer.username} className="avatar__image" src={chat.peer.avatarUrl} />
              ) : (
                initials(chat.peer.displayName || chat.peer.username)
              )}
            </div>
            <div className="chat-row__body">
              <div className="chat-row__title">
                <span>{chat.peer.displayName || chat.peer.username}</span>
                <span>{formatRelativeDate(chat.lastMessageAt || chat.peer.lastSeenAt)}</span>
              </div>
              <div className="chat-row__message">
                {chat.lastMessage
                  ? `${chat.lastMessageIsMine ? 'Вы: ' : ''}${getConversationPreview(chat.lastMessage)}`
                  : 'Начните разговор'}
              </div>
            </div>
            {chat.unreadCount ? <span className="nav-link__badge">{chat.unreadCount}</span> : null}
          </button>
        ))}
      </section>

      <section className="chat-panel">
        {error ? <div className="error-banner">{error}</div> : null}

        {activeChat ? (
          <>
            <header className="chat-panel__header">
              <div className="chat-panel__peer">
                <div className="avatar">
                  {activeChat.peer.avatarUrl ? (
                    <img alt={activeChat.peer.username} className="avatar__image" src={activeChat.peer.avatarUrl} />
                  ) : (
                    initials(activeChat.peer.displayName || activeChat.peer.username)
                  )}
                </div>
                <div>
                  <div className="section-title">{activeChat.peer.displayName || activeChat.peer.username}</div>
                  <div className="chat-panel__status">
                    {activeChat.peer.isOnline ? 'В сети' : formatRelativeDate(activeChat.peer.lastSeenAt)}
                  </div>
                </div>
              </div>
            </header>

            <div ref={messageListRef} className="message-list">
              {messagesBusy ? <div className="empty-card">Загружаем сообщения...</div> : null}
              {!messagesBusy && messages.length === 0 ? (
                <div className="empty-card">Здесь пока тихо. Начните разговор первым.</div>
              ) : null}

              {messages.map((message) => {
                const sharedPost = parseSharedPostMessage(message.content);
                return (
                  <div key={message.id} className={`message-bubble${message.isMine ? ' message-bubble--mine' : ''}`}>
                    {!message.isMine ? (
                      <div className="message-bubble__sender">{message.sender.displayName || message.sender.username}</div>
                    ) : null}

                    {sharedPost ? (
                      <SharedPostCard payload={sharedPost} />
                    ) : (
                      <div className="message-bubble__text">{getMessageText(message.content)}</div>
                    )}

                    <div className="message-bubble__time">{formatRelativeDate(message.createdAt)}</div>
                  </div>
                );
              })}
            </div>

            <footer className="chat-panel__composer">
              <textarea
                className="input input--area"
                rows={3}
                value={draft}
                placeholder="Написать сообщение"
                onChange={(event) => setDraft(event.target.value)}
                onKeyDown={(event) => {
                  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
                    event.preventDefault();
                    void sendMessage();
                  }
                }}
              />
              <button className="primary-button" disabled={sendBusy} type="button" onClick={() => void sendMessage()}>
                {sendBusy ? 'Отправляем...' : 'Отправить'}
              </button>
            </footer>
          </>
        ) : (
          <div className="empty-card">Выберите диалог слева или откройте чат из раздела друзей.</div>
        )}
      </section>
    </div>
  );
}

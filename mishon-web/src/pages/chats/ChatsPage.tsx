import { startTransition, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

import { useAuth } from '../../app/providers/useAuth';
import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import { asRecord, normalizeMessage } from '../../shared/api/core/normalizers';
import type { Conversation, Message, Profile } from '../../shared/types/api';
import { ChatPanel } from './components/ChatPanel';
import { ConversationList } from './components/ConversationList';
import { ForwardSheet } from './components/ForwardSheet';
import { buildForwardDestinations, isSavedMessagesChat } from './lib/chatIdentity';
import type { ForwardDestination } from './types';

function sortMessages(items: Message[]) {
  return [...items].sort((left, right) => {
    const timeDiff = new Date(left.createdAt).getTime() - new Date(right.createdAt).getTime();
    if (timeDiff !== 0) {
      return timeDiff;
    }
    return left.id - right.id;
  });
}

function upsertMessage(collection: Message[], nextMessage: Message) {
  const index = collection.findIndex((item) => item.id === nextMessage.id);
  if (index === -1) {
    return sortMessages([...collection, nextMessage]);
  }
  const next = [...collection];
  next[index] = nextMessage;
  return sortMessages(next);
}

function markMessageDelivered(collection: Message[], messageId: number, deliveredAt: string) {
  return collection.map((item) =>
    item.id === messageId
      ? {
          ...item,
          isDeliveredToPeer: true,
          deliveredToPeerAt: item.deliveredToPeerAt ?? deliveredAt,
        }
      : item,
  );
}

function markMessagesRead(collection: Message[], readAt: string) {
  const readTimestamp = new Date(readAt).getTime();
  return collection.map((item) => {
    if (!item.isMine || item.isReadByPeer || new Date(item.createdAt).getTime() > readTimestamp) {
      return item;
    }

    return {
      ...item,
      isDeliveredToPeer: true,
      deliveredToPeerAt: item.deliveredToPeerAt ?? readAt,
      isReadByPeer: true,
      readByPeerAt: readAt,
    };
  });
}

function createOptimisticMessage(
  tempId: number,
  conversationId: number,
  currentUserId: number | undefined,
  username: string | undefined,
  content: string,
  replyTo?: Message | null,
) {
  return {
    id: tempId,
    conversationId,
    senderId: currentUserId ?? 0,
    senderUsername: username ?? 'me',
    content,
    createdAt: new Date().toISOString(),
    editedAt: null,
    isMine: true,
    isDeliveredToPeer: false,
    deliveredToPeerAt: null,
    isReadByPeer: false,
    readByPeerAt: null,
    replyToMessageId: replyTo?.id ?? null,
    replyToSenderUsername: replyTo?.senderUsername ?? null,
    replyToContent: replyTo?.content ?? null,
    forwardedFromMessageId: null,
    forwardedFromUserId: null,
    forwardedFromSenderUsername: null,
    forwardedFromUserAvatarUrl: null,
    forwardedFromUserAvatarScale: 1,
    forwardedFromUserAvatarOffsetX: 0,
    forwardedFromUserAvatarOffsetY: 0,
    attachments: [],
    isHidden: false,
    isRemoved: false,
  } satisfies Message;
}

export function ChatsPage() {
  const { profile } = useAuth();
  const { subscribe, status: syncStatus } = useLiveSync();
  const [searchParams, setSearchParams] = useSearchParams();
  const [chats, setChats] = useState<Conversation[]>([]);
  const [messages, setMessages] = useState<Message[]>([]);
  const [selectedChatId, setSelectedChatId] = useState<number | null>(null);
  const [draft, setDraft] = useState('');
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
  const [busy, setBusy] = useState(true);
  const [messagesBusy, setMessagesBusy] = useState(false);
  const [sendBusy, setSendBusy] = useState(false);
  const [forwardBusy, setForwardBusy] = useState(false);
  const [editingMessageId, setEditingMessageId] = useState<number | null>(null);
  const [replyingMessage, setReplyingMessage] = useState<Message | null>(null);
  const [forwardingMessage, setForwardingMessage] = useState<Message | null>(null);
  const [typingLabel, setTypingLabel] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [chatProfiles, setChatProfiles] = useState<Record<number, Profile>>({});
  const messageListRef = useRef<HTMLDivElement | null>(null);
  const tempMessageIdRef = useRef(-1);
  const typingActiveRef = useRef(false);

  const currentUserId = profile?.id;

  const refreshChats = useCallback(async (silent = false) => {
    if (!silent) {
      setBusy(true);
    }

    try {
      const nextChats = await api.chats.list();
      setChats(nextChats);
      setSelectedChatId((current) => {
        if (current && nextChats.some((item) => item.id === current)) {
          return current;
        }
        return nextChats[0]?.id ?? null;
      });
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить чаты.');
      setChats([]);
    } finally {
      if (!silent) {
        setBusy(false);
      }
    }
  }, []);

  const loadMessages = useCallback(async (chatId: number, silent = false) => {
    if (!silent) {
      setMessagesBusy(true);
    }

    try {
      const nextMessages = await api.chats.messages(chatId);
      setMessages(sortMessages(nextMessages));
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить сообщения.');
      setMessages([]);
    } finally {
      if (!silent) {
        setMessagesBusy(false);
      }
    }
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function bootstrap() {
      setBusy(true);
      setError(null);
      try {
        const directUserId = Number(searchParams.get('chatWith'));
        let nextChats = await api.chats.list();
        let nextSelectedChatId = nextChats[0]?.id ?? null;

        if (Number.isFinite(directUserId) && directUserId > 0) {
          const directChat = await api.chats.openDirect(directUserId);
          const exists = nextChats.some((item) => item.id === directChat.id);
          nextChats = exists ? nextChats : [directChat, ...nextChats];
          nextSelectedChatId = directChat.id;
          setSearchParams((current) => {
            const next = new URLSearchParams(current);
            next.delete('chatWith');
            return next;
          });
        }

        if (!cancelled) {
          setChats(nextChats);
          startTransition(() => setSelectedChatId(nextSelectedChatId));
        }
      } catch (nextError) {
        if (!cancelled) {
          setError(nextError instanceof Error ? nextError.message : 'Не удалось открыть чаты.');
          setChats([]);
        }
      } finally {
        if (!cancelled) {
          setBusy(false);
        }
      }
    }

    void bootstrap();

    return () => {
      cancelled = true;
    };
  }, [searchParams, setSearchParams]);

  useEffect(() => {
    if (!selectedChatId) {
      setMessages([]);
      return;
    }

    void loadMessages(selectedChatId);
  }, [loadMessages, selectedChatId]);

  useEffect(() => {
    if (syncStatus === 'connected') {
      return;
    }

    const chatsInterval = window.setInterval(() => void refreshChats(true), 15000);
    const messagesInterval =
      selectedChatId !== null ? window.setInterval(() => void loadMessages(selectedChatId, true), 8000) : null;

    return () => {
      window.clearInterval(chatsInterval);
      if (messagesInterval !== null) {
        window.clearInterval(messagesInterval);
      }
    };
  }, [loadMessages, refreshChats, selectedChatId, syncStatus]);

  useEffect(() => {
    const list = messageListRef.current;
    if (!list) {
      return;
    }

    list.scrollTo({ top: list.scrollHeight, behavior: 'smooth' });
  }, [messages]);

  useEffect(() => {
    return subscribe((event) => {
      const payload = asRecord(event.data);
      const conversationId = Number(payload.conversationId ?? 0) || null;

      if (event.type === 'sync.resync') {
        void refreshChats(true);
        if (selectedChatId) {
          void loadMessages(selectedChatId, true);
        }
        return;
      }

      if (event.type === 'chat.typing.started' && conversationId === selectedChatId) {
        const peerUserId = Number(payload.userId ?? 0);
        if (peerUserId && peerUserId !== currentUserId) {
          const username = typeof payload.username === 'string' ? payload.username : 'Собеседник';
          setTypingLabel(`${username} печатает...`);
        }
        return;
      }

      if (event.type === 'chat.typing.stopped' && conversationId === selectedChatId) {
        setTypingLabel(null);
        return;
      }

      if (event.type === 'chat.message.created') {
        void refreshChats(true);
        if (conversationId === selectedChatId && payload.message) {
          const nextMessage = normalizeMessage(asRecord(payload.message));
          setTypingLabel(null);
          setMessages((current) => upsertMessage(current, nextMessage));
        }
        return;
      }

      if (event.type === 'chat.message.delivered') {
        const messageId = Number(payload.messageId ?? 0);
        const deliveredAt = typeof payload.deliveredAt === 'string' ? payload.deliveredAt : new Date().toISOString();
        if (conversationId === selectedChatId && messageId > 0) {
          setMessages((current) => markMessageDelivered(current, messageId, deliveredAt));
        }
        void refreshChats(true);
        return;
      }

      if (event.type === 'chat.message.read') {
        const userId = Number(payload.userId ?? 0);
        const readAt = typeof payload.readAt === 'string' ? payload.readAt : new Date().toISOString();
        if (conversationId === selectedChatId && userId && userId !== currentUserId) {
          setMessages((current) => markMessagesRead(current, readAt));
        }
        void refreshChats(true);
        return;
      }

      if (event.type === 'chat.message.updated') {
        if (conversationId === selectedChatId && payload.message) {
          const nextMessage = normalizeMessage(asRecord(payload.message));
          setMessages((current) => upsertMessage(current, nextMessage));
        }
        void refreshChats(true);
        return;
      }

      if (event.type === 'chat.message.deleted') {
        if (conversationId === selectedChatId) {
          const messageId = Number(payload.messageId ?? 0);
          if (messageId > 0) {
            setMessages((current) => current.filter((item) => item.id !== messageId));
          } else if (selectedChatId !== null) {
            void loadMessages(selectedChatId, true);
          }
        }
        void refreshChats(true);
        return;
      }

      if (event.type === 'chat.history.cleared') {
        if (conversationId === selectedChatId) {
          setMessages([]);
        }
        void refreshChats(true);
        return;
      }

      if (event.type === 'chat.conversation.changed') {
        void refreshChats(true);
        if (conversationId === selectedChatId && selectedChatId !== null) {
          void loadMessages(selectedChatId, true);
        }
      }
    });
  }, [currentUserId, loadMessages, refreshChats, selectedChatId, subscribe]);

  const activeChat = useMemo(
    () => chats.find((item) => item.id === selectedChatId) ?? null,
    [chats, selectedChatId],
  );

  const forwardDestinations = useMemo<ForwardDestination[]>(
    () => buildForwardDestinations(chats, currentUserId, profile),
    [chats, currentUserId, profile],
  );

  useEffect(() => {
    if (!activeChat || !currentUserId) {
      return;
    }

    if (isSavedMessagesChat(activeChat, currentUserId) || chatProfiles[activeChat.peerId]) {
      return;
    }

    const peerId = activeChat.peerId;
    let cancelled = false;

    async function loadChatProfile() {
      try {
        const nextProfile = await api.profile.getUser(peerId);
        if (!cancelled) {
          setChatProfiles((current) => ({
            ...current,
            [peerId]: nextProfile,
          }));
        }
      } catch {
        // Non-blocking.
      }
    }

    void loadChatProfile();

    return () => {
      cancelled = true;
    };
  }, [activeChat, chatProfiles, currentUserId]);

  const activeChatProfile = useMemo(() => {
    if (!activeChat) {
      return null;
    }

    if (currentUserId && isSavedMessagesChat(activeChat, currentUserId)) {
      return profile ?? null;
    }

    return chatProfiles[activeChat.peerId] ?? null;
  }, [activeChat, chatProfiles, currentUserId, profile]);

  useEffect(() => {
    if (!selectedChatId || !activeChat?.canSendMessages || editingMessageId) {
      if (typingActiveRef.current && selectedChatId) {
        typingActiveRef.current = false;
        void api.chats.typingStop(selectedChatId);
      }
      return;
    }

    const hasDraft = draft.trim().length > 0;
    if (hasDraft && !typingActiveRef.current) {
      typingActiveRef.current = true;
      void api.chats.typingStart(selectedChatId);
    }

    if (!hasDraft && typingActiveRef.current) {
      typingActiveRef.current = false;
      void api.chats.typingStop(selectedChatId);
    }
  }, [activeChat?.canSendMessages, draft, editingMessageId, selectedChatId]);

  useEffect(() => {
    return () => {
      if (typingActiveRef.current && selectedChatId) {
        typingActiveRef.current = false;
        void api.chats.typingStop(selectedChatId);
      }
    };
  }, [selectedChatId]);

  async function sendMessage() {
    if (!selectedChatId || !activeChat?.canSendMessages) {
      return;
    }

    const trimmed = draft.trim();
    if (!trimmed && selectedFiles.length === 0) {
      return;
    }

    setSendBusy(true);
    setError(null);

    const optimisticId = editingMessageId || selectedFiles.length > 0 ? null : tempMessageIdRef.current--;
    if (!editingMessageId && optimisticId !== null) {
      const optimisticMessage = createOptimisticMessage(
        optimisticId,
        selectedChatId,
        currentUserId,
        profile?.username,
        trimmed,
        replyingMessage,
      );
      setMessages((current) => upsertMessage(current, optimisticMessage));
    }

    try {
      if (editingMessageId) {
        const updated = await api.chats.update(selectedChatId, editingMessageId, trimmed);
        setMessages((current) => upsertMessage(current, updated));
        setEditingMessageId(null);
      } else {
        const sent = await api.chats.send(selectedChatId, {
          content: trimmed,
          replyToMessageId: replyingMessage?.id ?? undefined,
          attachments: selectedFiles,
        });
        setMessages((current) => {
          const withoutOptimistic =
            optimisticId === null ? current : current.filter((item) => item.id !== optimisticId);
          return upsertMessage(withoutOptimistic, sent);
        });
      }

      if (typingActiveRef.current) {
        typingActiveRef.current = false;
        void api.chats.typingStop(selectedChatId);
      }

      setDraft('');
      setSelectedFiles([]);
      setReplyingMessage(null);
      await refreshChats(true);
    } catch (nextError) {
      if (optimisticId !== null) {
        setMessages((current) => current.filter((item) => item.id !== optimisticId));
      }
      setError(nextError instanceof Error ? nextError.message : 'Не удалось отправить сообщение.');
    } finally {
      setSendBusy(false);
    }
  }

  // Legacy handlers kept temporarily while the new chat panel uses custom dialogs.
  async function handleDeleteMessage(message: Message, deleteForAll: boolean) {
    if (!selectedChatId) {
      return;
    }

    const confirmed = window.confirm(
      deleteForAll ? 'Удалить сообщение у всех участников?' : 'Удалить сообщение только у себя?',
    );
    if (!confirmed) {
      return;
    }

    const previousMessages = messages;
    setMessages((current) => current.filter((item) => item.id !== message.id));

    try {
      if (deleteForAll) {
        await api.chats.removeForAll(selectedChatId, message.id);
      } else {
        await api.chats.remove(selectedChatId, message.id);
      }

      await refreshChats(true);
    } catch (nextError) {
      setMessages(previousMessages);
      setError(nextError instanceof Error ? nextError.message : 'Не удалось удалить сообщение.');
    }
  }

  function handleStartEdit(message: Message) {
    setReplyingMessage(null);
    setEditingMessageId(message.id);
    setDraft(message.content);
    setSelectedFiles([]);
  }

  function handleCancelEdit() {
    setEditingMessageId(null);
    setDraft('');
  }

  function handleStartReply(message: Message) {
    setEditingMessageId(null);
    setReplyingMessage(message);
  }

  function handleCancelReply() {
    setReplyingMessage(null);
  }

  async function forwardToDestination(destination: ForwardDestination) {
    if (!forwardingMessage) {
      return;
    }

    setForwardBusy(true);
    setError(null);
    try {
      let conversationId = destination.conversationId;

      if (!conversationId) {
        const directChat = await api.chats.openDirect(destination.peerId);
        conversationId = directChat.id;
        setChats((current) => {
          const exists = current.some((item) => item.id === directChat.id);
          return exists ? current : [directChat, ...current];
        });
      }

      await api.chats.forward(conversationId, forwardingMessage.id);
      setForwardingMessage(null);
      startTransition(() => setSelectedChatId(conversationId));
      await refreshChats(true);
      await loadMessages(conversationId, true);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось переслать сообщение.');
    } finally {
      setForwardBusy(false);
    }
  }

  async function toggleConversationFlag(action: () => Promise<void>, successRefresh = true) {
    setError(null);
    try {
      await action();
      if (successRefresh) {
        await refreshChats(true);
      }
      if (selectedChatId) {
        await loadMessages(selectedChatId, true);
      }
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось обновить настройки чата.');
    }
  }

  async function handleDeleteConversation(deleteForBoth: boolean) {
    if (!activeChat) {
      return;
    }

    const confirmed = window.confirm(
      deleteForBoth ? 'Удалить диалог для всех участников?' : 'Скрыть этот диалог только у себя?',
    );
    if (!confirmed) {
      return;
    }

    try {
      await api.chats.deleteConversation(activeChat.id, deleteForBoth);
      await refreshChats(true);
      setMessages([]);
      setDraft('');
      setSelectedFiles([]);
      setReplyingMessage(null);
      setEditingMessageId(null);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось удалить диалог.');
    }
  }

  async function handleClearHistory() {
    if (!activeChat) {
      return;
    }

    const confirmed = window.confirm('Очистить историю сообщений в этом диалоге?');
    if (!confirmed) {
      return;
    }

    try {
      await api.chats.clearHistory(activeChat.id);
      setMessages([]);
      await refreshChats(true);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось очистить историю.');
    }
  }

  async function handleToggleBlock() {
    if (!activeChat) {
      return;
    }

    try {
      if (activeChat.isBlockedByViewer) {
        await api.chats.unblockUser(activeChat.peerId);
      } else {
        await api.chats.blockUser(activeChat.peerId);
      }
      await refreshChats(true);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось обновить статус блокировки.');
    }
  }

  async function deleteMessageDirect(message: Message, deleteForAll: boolean) {
    if (!selectedChatId) {
      return;
    }

    const previousMessages = messages;
    setMessages((current) => current.filter((item) => item.id !== message.id));

    try {
      if (deleteForAll) {
        await api.chats.removeForAll(selectedChatId, message.id);
      } else {
        await api.chats.remove(selectedChatId, message.id);
      }

      await refreshChats(true);
    } catch (nextError) {
      setMessages(previousMessages);
      setError(nextError instanceof Error ? nextError.message : 'Не удалось удалить сообщение.');
    }
  }

  async function deleteConversationDirect(deleteForBoth: boolean) {
    if (!activeChat) {
      return;
    }

    try {
      await api.chats.deleteConversation(activeChat.id, deleteForBoth);
      await refreshChats(true);
      setMessages([]);
      setDraft('');
      setSelectedFiles([]);
      setReplyingMessage(null);
      setEditingMessageId(null);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось удалить диалог.');
    }
  }

  async function clearHistoryDirect() {
    if (!activeChat) {
      return;
    }

    try {
      await api.chats.clearHistory(activeChat.id);
      setMessages([]);
      await refreshChats(true);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось очистить историю.');
    }
  }

  void handleDeleteMessage;
  void handleDeleteConversation;
  void handleClearHistory;

  return (
    <div className="chat-layout chat-layout--desktop">
      <ConversationList
        busy={busy}
        chats={chats}
        currentUserId={currentUserId}
        profile={profile}
        selectedChatId={selectedChatId}
        onSelect={setSelectedChatId}
      />

      <ChatPanel
        activeChat={activeChat}
        activeChatProfile={activeChatProfile}
        currentUserId={currentUserId}
        draft={draft}
        editingMessageId={editingMessageId}
        error={error}
        messageListRef={messageListRef}
        messages={messages}
        messagesBusy={messagesBusy}
        profile={profile}
        replyingMessage={replyingMessage}
        selectedFiles={selectedFiles}
        sendBusy={sendBusy}
        typingLabel={typingLabel}
        onCancelEdit={handleCancelEdit}
        onCancelReply={handleCancelReply}
        onClearHistory={clearHistoryDirect}
        onDeleteConversation={deleteConversationDirect}
        onDeleteMessage={deleteMessageDirect}
        onDraftChange={setDraft}
        onFilesChange={setSelectedFiles}
        onForwardMessage={setForwardingMessage}
        onStartEdit={handleStartEdit}
        onStartReply={handleStartReply}
        onSubmit={sendMessage}
        onToggleArchive={() => toggleConversationFlag(() => api.chats.archive(activeChat!.id, !activeChat!.isArchived))}
        onToggleBlock={handleToggleBlock}
        onToggleFavorite={() => toggleConversationFlag(() => api.chats.favorite(activeChat!.id, !activeChat!.isFavorite))}
        onToggleMute={() => toggleConversationFlag(() => api.chats.mute(activeChat!.id, !activeChat!.isMuted))}
        onTogglePin={() => toggleConversationFlag(() => api.chats.pin(activeChat!.id, !activeChat!.isPinned))}
      />

      {forwardingMessage ? (
        <ForwardSheet
          busy={forwardBusy}
          destinations={forwardDestinations}
          onClose={() => setForwardingMessage(null)}
          onSelect={forwardToDestination}
        />
      ) : null}
    </div>
  );
}

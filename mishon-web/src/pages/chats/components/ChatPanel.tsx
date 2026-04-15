import { useEffect, useMemo, useRef, useState, type RefObject } from 'react';
import { useNavigate } from 'react-router-dom';

import { ConfirmDialog } from '../../../shared/ui/ConfirmDialog';
import { getMessageText, parseSharedPostMessage } from '../../../shared/lib/chatContent';
import { formatRelativeDate } from '../../../shared/lib/format';
import type { Conversation, Message, Profile } from '../../../shared/types/api';
import { AppIcon } from '../../../shared/ui/AppIcon';
import { UserAvatar } from '../../../shared/ui/UserAvatar';
import { getActiveChatSubtitle, getChatAvatar, getChatTitle, isSavedMessagesChat } from '../lib/chatIdentity';
import { ChatIntroCard } from './ChatIntroCard';
import { MessageAttachment } from './MessageAttachment';
import { SharedPostCard } from './SharedPostCard';

type ChatPanelProps = {
  activeChat: Conversation | null;
  activeChatProfile?: Profile | null;
  currentUserId: number | undefined;
  profile?: Profile | null;
  error: string | null;
  messages: Message[];
  messagesBusy: boolean;
  messageListRef: RefObject<HTMLDivElement | null>;
  draft: string;
  editingMessageId: number | null;
  replyingMessage: Message | null;
  sendBusy: boolean;
  typingLabel: string | null;
  selectedFiles: File[];
  onDraftChange: (value: string) => void;
  onSubmit: () => void | Promise<void>;
  onCancelEdit: () => void;
  onCancelReply: () => void;
  onStartEdit: (message: Message) => void;
  onStartReply: (message: Message) => void;
  onDeleteMessage: (message: Message, deleteForAll: boolean) => void | Promise<void>;
  onForwardMessage: (message: Message) => void;
  onFilesChange: (files: File[]) => void;
  onTogglePin: () => void | Promise<void>;
  onToggleArchive: () => void | Promise<void>;
  onToggleFavorite: () => void | Promise<void>;
  onToggleMute: () => void | Promise<void>;
  onDeleteConversation: (deleteForBoth: boolean) => void | Promise<void>;
  onClearHistory: () => void | Promise<void>;
  onToggleBlock: () => void | Promise<void>;
};

type ConfirmState =
  | {
      title: string;
      description: string;
      confirmLabel: string;
      busyLabel: string;
      onConfirm: () => Promise<void> | void;
    }
  | null;

function isSameDay(left: string, right: string) {
  const leftDate = new Date(left);
  const rightDate = new Date(right);

  return (
    leftDate.getFullYear() === rightDate.getFullYear() &&
    leftDate.getMonth() === rightDate.getMonth() &&
    leftDate.getDate() === rightDate.getDate()
  );
}

function formatDayLabel(value: string) {
  const target = new Date(value);
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);

  if (
    target.getFullYear() === today.getFullYear() &&
    target.getMonth() === today.getMonth() &&
    target.getDate() === today.getDate()
  ) {
    return 'Сегодня';
  }

  if (
    target.getFullYear() === yesterday.getFullYear() &&
    target.getMonth() === yesterday.getMonth() &&
    target.getDate() === yesterday.getDate()
  ) {
    return 'Вчера';
  }

  return new Intl.DateTimeFormat('ru-RU', {
    day: 'numeric',
    month: 'long',
  }).format(target);
}

function isGroupedWithPrevious(previous: Message | null, current: Message) {
  if (!previous) {
    return false;
  }

  if (previous.senderId !== current.senderId || previous.isMine !== current.isMine) {
    return false;
  }

  if (!isSameDay(previous.createdAt, current.createdAt)) {
    return false;
  }

  const diff = Math.abs(new Date(current.createdAt).getTime() - new Date(previous.createdAt).getTime());
  return diff <= 5 * 60 * 1000;
}

function getThreadStatus(
  activeChat: Conversation,
  subtitle: string,
  typingLabel: string | null,
  savedMessages: boolean,
) {
  if (typingLabel) {
    return typingLabel;
  }

  if (savedMessages) {
    return 'Личные заметки, файлы и быстрые пересылки';
  }

  if (activeChat.isOnline) {
    return 'В сети';
  }

  if (subtitle === 'Диалог' && activeChat.lastSeenAt) {
    return `Был(а) ${formatRelativeDate(activeChat.lastSeenAt)}`;
  }

  return subtitle;
}

function formatJoinedAt(value?: string | null) {
  if (!value) {
    return null;
  }

  return new Intl.DateTimeFormat('ru-RU', {
    month: 'long',
    year: 'numeric',
  }).format(new Date(value));
}

function getMessageReceiptMeta(message: Message) {
  if (message.isReadByPeer) {
    return {
      icon: 'check-double' as const,
      label: 'Прочитано',
      className: 'message-card__receipt message-card__receipt--read',
    };
  }

  if (message.isDeliveredToPeer) {
    return {
      icon: 'check-double' as const,
      label: 'Доставлено',
      className: 'message-card__receipt message-card__receipt--delivered',
    };
  }

  return {
    icon: 'check' as const,
    label: 'Отправлено',
    className: 'message-card__receipt message-card__receipt--sent',
  };
}

export function ChatPanel({
  activeChat,
  activeChatProfile,
  currentUserId,
  profile,
  error,
  messages,
  messagesBusy,
  messageListRef,
  draft,
  editingMessageId,
  replyingMessage,
  sendBusy,
  typingLabel,
  selectedFiles,
  onDraftChange,
  onSubmit,
  onCancelEdit,
  onCancelReply,
  onStartEdit,
  onStartReply,
  onDeleteMessage,
  onForwardMessage,
  onFilesChange,
  onTogglePin,
  onToggleArchive,
  onToggleFavorite,
  onToggleMute,
  onDeleteConversation,
  onClearHistory,
  onToggleBlock,
}: ChatPanelProps) {
  const navigate = useNavigate();
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const [chatMenuOpen, setChatMenuOpen] = useState(false);
  const [messageMenuId, setMessageMenuId] = useState<number | null>(null);
  const [confirmState, setConfirmState] = useState<ConfirmState>(null);
  const [confirmBusy, setConfirmBusy] = useState(false);

  useEffect(() => {
    function handlePointerDown(event: MouseEvent) {
      const target = event.target as HTMLElement | null;
      if (!target) {
        return;
      }

      if (chatMenuOpen && !target.closest('.chat-header__menu-wrap')) {
        setChatMenuOpen(false);
      }

      if (messageMenuId !== null && !target.closest('.message-card__menu-wrap')) {
        setMessageMenuId(null);
      }
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        setChatMenuOpen(false);
        setMessageMenuId(null);
      }
    }

    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [chatMenuOpen, messageMenuId]);

  useEffect(() => {
    const element = textareaRef.current;
    if (!element) {
      return;
    }

    element.style.height = '0px';
    const nextHeight = Math.min(Math.max(element.scrollHeight, 46), 140);
    element.style.height = `${nextHeight}px`;
    element.style.overflowY = element.scrollHeight > 140 ? 'auto' : 'hidden';
  }, [draft]);

  const threadItems = useMemo(
    () =>
      messages.map((message, index) => {
        const previous = index > 0 ? messages[index - 1] : null;
        const showDayDivider = !previous || !isSameDay(previous.createdAt, message.createdAt);

        return {
          message,
          showDayDivider,
          dayLabel: showDayDivider ? formatDayLabel(message.createdAt) : null,
          grouped: isGroupedWithPrevious(previous, message),
        };
      }),
    [messages],
  );

  if (!activeChat) {
    return (
      <section className="chat-panel">
        {error ? <div className="error-banner">{error}</div> : null}
        <div className="chat-panel__empty">
          <div className="chat-panel__empty-icon">
            <AppIcon className="button-icon" name="message" />
          </div>
          <div className="chat-panel__empty-copy">
            <h2>Выберите диалог</h2>
            <p>Откройте переписку слева или начните новый диалог из раздела людей.</p>
          </div>
        </div>
      </section>
    );
  }

  const title = getChatTitle(activeChat, currentUserId);
  const subtitle = getActiveChatSubtitle(activeChat, currentUserId);
  const avatar = getChatAvatar(activeChat, currentUserId, profile);
  const savedMessages = isSavedMessagesChat(activeChat, currentUserId);
  const threadStatus = getThreadStatus(activeChat, subtitle, typingLabel, savedMessages);
  const displayName =
    !savedMessages && activeChatProfile?.displayName?.trim() ? activeChatProfile.displayName.trim() : title;
  const displayUsername = savedMessages
    ? profile?.username ?? activeChat.username
    : activeChatProfile?.username ?? activeChat.username;
  const joinedAt = formatJoinedAt(activeChatProfile?.createdAt);
  const introMeta = joinedAt ? `Дата регистрации: ${joinedAt}` : threadStatus;

  const openProfile = () => {
    if (savedMessages) {
      navigate('/profile');
      return;
    }

    navigate(`/profile/${activeChat.peerId}`);
  };

  function requestConfirmation(nextState: Exclude<ConfirmState, null>) {
    setChatMenuOpen(false);
    setMessageMenuId(null);
    setConfirmState(nextState);
  }

  async function runConfirmation() {
    if (!confirmState) {
      return;
    }

    setConfirmBusy(true);
    try {
      await confirmState.onConfirm();
      setConfirmState(null);
    } finally {
      setConfirmBusy(false);
    }
  }

  return (
    <section className="chat-panel">
      {error ? <div className="error-banner">{error}</div> : null}

      <header className="chat-header">
        <div className="chat-header__identity">
          <UserAvatar
            imageUrl={avatar.avatarUrl}
            name={displayName}
            offsetX={avatar.avatarOffsetX}
            offsetY={avatar.avatarOffsetY}
            scale={avatar.avatarScale}
            size="lg"
          />

          <div className="chat-header__copy">
            <div className="chat-header__title-row">
              <strong>{displayName}</strong>
              {!savedMessages ? <span>@{displayUsername}</span> : null}
            </div>
            <div className="chat-header__status">{threadStatus}</div>
          </div>
        </div>

        <div className="chat-header__actions">
          <button className="ghost-button ghost-button--sm chat-header__profile" type="button" onClick={openProfile}>
            Профиль
          </button>

          <div className="chat-header__menu-wrap">
            <button
              aria-expanded={chatMenuOpen}
              aria-haspopup="menu"
              className="icon-button icon-button--ghost"
              type="button"
              onClick={() => setChatMenuOpen((current) => !current)}
            >
              <AppIcon className="button-icon" name="more" />
            </button>

            {chatMenuOpen ? (
              <div className="chat-menu" role="menu">
                <button className="chat-menu__item" type="button" onClick={() => void onTogglePin()}>
                  {activeChat.isPinned ? 'Открепить' : 'Закрепить'}
                </button>
                <button className="chat-menu__item" type="button" onClick={() => void onToggleArchive()}>
                  {activeChat.isArchived ? 'Вернуть из архива' : 'В архив'}
                </button>
                <button className="chat-menu__item" type="button" onClick={() => void onToggleFavorite()}>
                  {activeChat.isFavorite ? 'Убрать из избранного' : 'В избранное'}
                </button>
                <button className="chat-menu__item" type="button" onClick={() => void onToggleMute()}>
                  {activeChat.isMuted ? 'Включить звук' : 'Выключить звук'}
                </button>
                <button
                  className="chat-menu__item"
                  type="button"
                  onClick={() =>
                    requestConfirmation({
                      title: 'Очистить историю?',
                      description:
                        'Все сообщения в этом диалоге будут скрыты из текущей истории. Это действие нельзя отменить.',
                      confirmLabel: 'Очистить',
                      busyLabel: 'Очищаем...',
                      onConfirm: onClearHistory,
                    })
                  }
                >
                  Очистить историю
                </button>
                {!savedMessages ? (
                  <button className="chat-menu__item" type="button" onClick={() => void onToggleBlock()}>
                    {activeChat.isBlockedByViewer ? 'Разблокировать' : 'Заблокировать'}
                  </button>
                ) : null}
                <button
                  className="chat-menu__item"
                  type="button"
                  onClick={() =>
                    requestConfirmation({
                      title: 'Скрыть чат?',
                      description: 'Диалог исчезнет только у вас и вернется снова после нового сообщения.',
                      confirmLabel: 'Скрыть чат',
                      busyLabel: 'Скрываем...',
                      onConfirm: () => onDeleteConversation(false),
                    })
                  }
                >
                  Скрыть чат
                </button>
                {!savedMessages ? (
                  <button
                    className="chat-menu__item chat-menu__item--danger"
                    type="button"
                    onClick={() =>
                      requestConfirmation({
                        title: 'Удалить чат у всех?',
                        description: 'Диалог будет удален для всех участников. Это действие нельзя отменить.',
                        confirmLabel: 'Удалить у всех',
                        busyLabel: 'Удаляем...',
                        onConfirm: () => onDeleteConversation(true),
                      })
                    }
                  >
                    Удалить у всех
                  </button>
                ) : null}
              </div>
            ) : null}
          </div>
        </div>
      </header>

      <div ref={messageListRef} className="message-list">
        {!messagesBusy && !savedMessages ? (
          <ChatIntroCard
            avatarOffsetX={avatar.avatarOffsetX}
            avatarOffsetY={avatar.avatarOffsetY}
            avatarScale={avatar.avatarScale}
            avatarUrl={avatar.avatarUrl}
            meta={introMeta}
            name={displayName}
            username={displayUsername}
            onOpenProfile={openProfile}
          />
        ) : null}

        {messagesBusy ? <div className="chat-panel__inline-state">Загружаем сообщения...</div> : null}

        {!messagesBusy && messages.length === 0 ? (
          <div className="chat-panel__thread-empty">
            <div className="chat-panel__thread-empty-copy">
              <strong>{savedMessages ? 'Пока пусто' : 'Начните разговор'}</strong>
              <span>
                {savedMessages
                  ? 'Сохраняйте сюда заметки, файлы и быстрые пересылки.'
                  : 'Отправьте первое сообщение, чтобы начать диалог.'}
              </span>
            </div>
          </div>
        ) : null}

        {threadItems.map(({ message, dayLabel, grouped, showDayDivider }) => {
          const sharedPost = parseSharedPostMessage(message.content);
          const messageText = message.isRemoved ? 'Сообщение удалено' : getMessageText(message.content);
          const receiptMeta = message.isMine && !savedMessages ? getMessageReceiptMeta(message) : null;
          const menuOpen = messageMenuId === message.id;

          return (
            <div key={message.id} className="message-entry">
              {showDayDivider ? <div className="message-day-divider">{dayLabel}</div> : null}

              <article
                className={`message-card${message.isMine ? ' message-card--mine' : ''}${grouped ? ' message-card--grouped' : ''}`}
              >
                {!message.isRemoved ? (
                  <div className="message-card__actions">
                    {message.isMine ? (
                      <div className="message-card__menu-wrap">
                        <button
                          aria-expanded={menuOpen}
                          aria-haspopup="menu"
                          className="message-card__icon-button"
                          type="button"
                          onClick={() => setMessageMenuId((current) => (current === message.id ? null : message.id))}
                        >
                          <AppIcon className="button-icon" name="more" />
                        </button>

                        {menuOpen ? (
                          <div className="chat-menu chat-menu--message chat-menu--message-mine" role="menu">
                            <button
                              className="chat-menu__item"
                              type="button"
                              onClick={() => {
                                setMessageMenuId(null);
                                onStartReply(message);
                              }}
                            >
                              Ответить
                            </button>
                            <button
                              className="chat-menu__item"
                              type="button"
                              onClick={() => {
                                setMessageMenuId(null);
                                onForwardMessage(message);
                              }}
                            >
                              Переслать
                            </button>
                            <button
                              className="chat-menu__item"
                              type="button"
                              onClick={() => {
                                setMessageMenuId(null);
                                onStartEdit(message);
                              }}
                            >
                              Редактировать сообщение
                            </button>
                            <button
                              className="chat-menu__item"
                              type="button"
                              onClick={() =>
                                requestConfirmation({
                                  title: 'Удалить сообщение?',
                                  description: 'Сообщение исчезнет только у вас в истории переписки.',
                                  confirmLabel: 'Удалить для меня',
                                  busyLabel: 'Удаляем...',
                                  onConfirm: () => onDeleteMessage(message, false),
                                })
                              }
                            >
                              Удалить для меня
                            </button>
                            {!savedMessages ? (
                              <button
                                className="chat-menu__item chat-menu__item--danger"
                                type="button"
                                onClick={() =>
                                  requestConfirmation({
                                    title: 'Удалить сообщение у всех?',
                                    description: 'Сообщение будет удалено у всех участников диалога.',
                                    confirmLabel: 'Удалить у всех',
                                    busyLabel: 'Удаляем...',
                                    onConfirm: () => onDeleteMessage(message, true),
                                  })
                                }
                              >
                                Удалить у всех
                              </button>
                            ) : null}
                          </div>
                        ) : null}
                      </div>
                    ) : (
                      <>
                        <button
                          aria-label="Ответить"
                          className="message-card__icon-button"
                          type="button"
                          onClick={() => onStartReply(message)}
                        >
                          <AppIcon className="button-icon" name="reply" />
                        </button>
                        <button
                          aria-label="Переслать"
                          className="message-card__icon-button"
                          type="button"
                          onClick={() => onForwardMessage(message)}
                        >
                          <AppIcon className="button-icon" name="share" />
                        </button>
                      </>
                    )}
                  </div>
                ) : null}

                {message.forwardedFromSenderUsername ? (
                  <div className="message-card__forwarded">Переслано от @{message.forwardedFromSenderUsername}</div>
                ) : null}

                {message.replyToContent ? (
                  <div className="message-card__reply">
                    <strong>@{message.replyToSenderUsername}</strong>
                    <span>{message.replyToContent}</span>
                  </div>
                ) : null}

                {sharedPost && !message.isRemoved ? <SharedPostCard payload={sharedPost} /> : null}
                {!sharedPost && messageText ? <div className="message-card__text">{messageText}</div> : null}

                {message.attachments.length ? (
                  <div className="message-card__attachments">
                    {message.attachments.map((attachment) => (
                      <MessageAttachment key={attachment.id} attachment={attachment} />
                    ))}
                  </div>
                ) : null}

                <div className="message-card__footer">
                  <div className="message-card__meta">
                    <div className="message-card__time">
                      {formatRelativeDate(message.createdAt)}
                      {message.editedAt ? ' · изменено' : ''}
                    </div>
                    {receiptMeta ? (
                      <div aria-label={receiptMeta.label} className={receiptMeta.className} title={receiptMeta.label}>
                        <AppIcon className="button-icon" name={receiptMeta.icon} />
                      </div>
                    ) : null}
                  </div>
                </div>
              </article>
            </div>
          );
        })}
      </div>

      <footer className="chat-composer">
        {editingMessageId ? (
          <div className="chat-composer__state">
            <span>Редактирование сообщения</span>
            <button className="text-button" type="button" onClick={onCancelEdit}>
              Отмена
            </button>
          </div>
        ) : null}

        {replyingMessage ? (
          <div className="chat-composer__state">
            <span>
              Ответ @{replyingMessage.senderUsername}:{' '}
              {getMessageText(replyingMessage.content).slice(0, 88) || 'вложение'}
            </span>
            <button className="text-button" type="button" onClick={onCancelReply}>
              Отмена
            </button>
          </div>
        ) : null}

        {selectedFiles.length ? (
          <div className="chat-composer__attachments">
            {selectedFiles.map((file) => (
              <span key={`${file.name}-${file.size}-${file.lastModified}`} className="chat-composer__file-pill">
                {file.name}
              </span>
            ))}
          </div>
        ) : null}

        <div className="chat-composer__shell">
          <div className="chat-composer__tools">
            <label className="chat-composer__tool" title="Добавить файл">
              <AppIcon className="button-icon" name="attach" />
              <input hidden multiple type="file" onChange={(event) => onFilesChange(Array.from(event.target.files ?? []))} />
            </label>
          </div>

          <textarea
            ref={textareaRef}
            className="chat-composer__input"
            rows={1}
            value={draft}
            placeholder={
              editingMessageId
                ? 'Изменить сообщение'
                : activeChat.canSendMessages
                  ? 'Напишите сообщение'
                  : 'Отправка сообщений недоступна'
            }
            onChange={(event) => onDraftChange(event.target.value)}
            onKeyDown={(event) => {
              if (!event.shiftKey && !event.ctrlKey && !event.metaKey && event.key === 'Enter') {
                event.preventDefault();
                void onSubmit();
              }
            }}
          />

          <button
            className="chat-composer__send"
            disabled={sendBusy || (!draft.trim() && selectedFiles.length === 0) || !activeChat.canSendMessages}
            type="button"
            onClick={() => void onSubmit()}
          >
            <AppIcon className="button-icon" name="send" />
            <span>{sendBusy ? 'Отправляем...' : editingMessageId ? 'Сохранить' : 'Отправить'}</span>
          </button>
        </div>
      </footer>

      <ConfirmDialog
        busy={confirmBusy}
        cancelLabel="Отмена"
        confirmLabel={confirmBusy && confirmState ? confirmState.busyLabel : confirmState?.confirmLabel}
        description={confirmState?.description ?? ''}
        open={Boolean(confirmState)}
        title={confirmState?.title ?? ''}
        onCancel={() => {
          if (!confirmBusy) {
            setConfirmState(null);
          }
        }}
        onConfirm={() => void runConfirmation()}
      />
    </section>
  );
}

import { useEffect, useMemo, useState } from 'react';

import { useAuth } from '../../app/providers/useAuth';
import { api } from '../../shared/api/api';
import { formatRelativeDate } from '../../shared/lib/format';
import type { Comment, CommentSort, Conversation, Post } from '../../shared/types/api';
import { AppIcon } from '../../shared/ui/AppIcon';
import { ContentTabs } from '../../shared/ui/ContentTabs';
import { UserAvatar } from '../../shared/ui/UserAvatar';
import { VerifiedBadge } from '../../shared/ui/VerifiedBadge';
import { ForwardSheet } from '../../pages/chats/components/ForwardSheet';
import { buildForwardDestinations } from '../../pages/chats/lib/chatIdentity';
import type { ForwardDestination } from '../../pages/chats/types';

type CommentThreadProps = {
  mode?: 'inline' | 'detail';
  post: Post;
  comments: Comment[];
  repliesByParent: Record<number, Comment[]>;
  expandedReplyIds: Record<number, boolean>;
  loadingReplies: Record<number, boolean>;
  draft: string;
  busy: boolean;
  loading: boolean;
  error?: string | null;
  editingCommentId: number | null;
  replyTarget: Comment | null;
  currentUserId: number;
  sort: CommentSort;
  hasMore: boolean;
  onSortChange: (value: CommentSort) => void;
  onDraftChange: (value: string) => void;
  onSubmit: () => void | Promise<void>;
  onEdit: (comment: Comment) => void;
  onReply: (comment: Comment) => void;
  onDelete: (commentId: number) => void | Promise<void>;
  onCancelEdit: () => void;
  onCancelReply: () => void;
  onToggleReplies: (comment: Comment) => void | Promise<void>;
  onToggleLike: (comment: Comment) => void | Promise<void>;
  onLoadMore: () => void | Promise<void>;
  onOpenDetail?: () => void;
};

type CommentCardProps = {
  postId: number;
  comment: Comment;
  currentUserId: number;
  menuOpen: boolean;
  isReply?: boolean;
  onToggleMenu: (commentId: number | null) => void;
  onEdit: (comment: Comment) => void;
  onReply: (comment: Comment) => void;
  onForward: (comment: Comment) => void;
  onDelete: (commentId: number) => void | Promise<void>;
  onToggleLike: (comment: Comment) => void | Promise<void>;
};

function pluralizeReplies(count: number) {
  const mod10 = count % 10;
  const mod100 = count % 100;

  if (mod10 === 1 && mod100 !== 11) {
    return 'ответ';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'ответа';
  }
  return 'ответов';
}

function buildForwardedCommentText(comment: Comment, post: Post) {
  const displayName = comment.author.displayName || comment.author.username;
  const postPreview = post.content.trim();
  const clippedPreview = postPreview.length > 140 ? `${postPreview.slice(0, 140).trimEnd()}...` : postPreview || 'Публикация без текста';

  return [
    `Комментарий от ${displayName} (@${comment.author.username})`,
    comment.replyToUsername ? `В ответ @${comment.replyToUsername}` : null,
    '',
    comment.content,
    '',
    `К посту: ${clippedPreview}`,
    `${window.location.origin}/posts/${post.id}#comment-${comment.id}`,
  ]
    .filter(Boolean)
    .join('\n');
}

async function copyCommentLink(postId: number, commentId: number) {
  const href = `${window.location.origin}/posts/${postId}#comment-${commentId}`;

  try {
    await navigator.clipboard.writeText(href);
  } catch {
    window.prompt('Ссылка на комментарий', href);
  }
}

function CommentCard({
  postId,
  comment,
  currentUserId,
  menuOpen,
  isReply = false,
  onToggleMenu,
  onEdit,
  onReply,
  onForward,
  onDelete,
  onToggleLike,
}: CommentCardProps) {
  const displayName = comment.author.displayName || comment.author.username;
  const canManage = comment.userId === currentUserId;
  const isVerified = Boolean(comment.author.isVerified);

  return (
    <article className={`comment-card${isReply ? ' comment-card--reply' : ''}`} id={`comment-${comment.id}`}>
      <div className="comment-card__header">
        <UserAvatar
          imageUrl={comment.author.avatarUrl}
          name={displayName}
          offsetX={comment.author.avatarOffsetX}
          offsetY={comment.author.avatarOffsetY}
          scale={comment.author.avatarScale}
          size="sm"
        />

        <div className="comment-card__meta">
          <div className="comment-card__title">
            <span className="comment-card__author">{displayName}</span>
            <span className="comment-card__identity">
              <span className="comment-card__meta-text">@{comment.author.username}</span>
              <VerifiedBadge verified={isVerified} />
            </span>
            <span className="comment-card__meta-text">·</span>
            <time className="comment-card__meta-text" dateTime={comment.createdAt}>
              {formatRelativeDate(comment.createdAt)}
            </time>
            {comment.editedAt ? <span className="comment-card__meta-text">изменено</span> : null}
          </div>

          {comment.replyToUsername ? <div className="comment-card__replying-to">Ответ @{comment.replyToUsername}</div> : null}

          <div className="comment-card__text">{comment.content}</div>
        </div>

        <div className="comment-card__menu-wrap">
          <button
            aria-expanded={menuOpen}
            aria-label="Действия комментария"
            className="icon-button icon-button--ghost comment-card__menu"
            type="button"
            onClick={() => onToggleMenu(menuOpen ? null : comment.id)}
          >
            <AppIcon className="shell-icon shell-icon--sm" name="more" />
          </button>

          {menuOpen ? (
            <div className="comment-menu" role="menu">
              <button
                className="comment-menu__item"
                role="menuitem"
                type="button"
                onClick={() => {
                  onToggleMenu(null);
                  onForward(comment);
                }}
              >
                <AppIcon className="app-icon" name="share" />
                <span>Переслать</span>
              </button>

              {canManage ? (
                <>
                  <button
                    className="comment-menu__item"
                    role="menuitem"
                    type="button"
                    onClick={() => {
                      onToggleMenu(null);
                      onEdit(comment);
                    }}
                  >
                    <AppIcon className="app-icon" name="edit" />
                    <span>Редактировать</span>
                  </button>
                  <button
                    className="comment-menu__item comment-menu__item--danger"
                    role="menuitem"
                    type="button"
                    onClick={() => {
                      onToggleMenu(null);
                      void onDelete(comment.id);
                    }}
                  >
                    <AppIcon className="app-icon" name="trash" />
                    <span>Удалить</span>
                  </button>
                </>
              ) : null}
            </div>
          ) : null}
        </div>
      </div>

      <div className="comment-card__actions">
        <button
          className={`comment-action${comment.isLiked ? ' comment-action--liked' : ''}`}
          type="button"
          onClick={() => void onToggleLike(comment)}
        >
          <AppIcon className="app-icon" filled={comment.isLiked} name="heart" />
          <span>{comment.likesCount}</span>
        </button>

        <button className="comment-action" type="button" onClick={() => onReply(comment)}>
          <AppIcon className="app-icon" name="reply" />
          <span>Ответить</span>
        </button>

        <button className="comment-action" type="button" onClick={() => void copyCommentLink(postId, comment.id)}>
          <AppIcon className="app-icon" name="share" />
          <span>Ссылка</span>
        </button>
      </div>
    </article>
  );
}

export function CommentThread({
  mode = 'inline',
  post,
  comments,
  repliesByParent,
  expandedReplyIds,
  loadingReplies,
  draft,
  busy,
  loading,
  error,
  editingCommentId,
  replyTarget,
  currentUserId,
  sort,
  hasMore,
  onSortChange,
  onDraftChange,
  onSubmit,
  onEdit,
  onReply,
  onDelete,
  onCancelEdit,
  onCancelReply,
  onToggleReplies,
  onToggleLike,
  onLoadMore,
  onOpenDetail,
}: CommentThreadProps) {
  const { profile } = useAuth();
  const [openMenuId, setOpenMenuId] = useState<number | null>(null);
  const [forwardingComment, setForwardingComment] = useState<Comment | null>(null);
  const [forwardBusy, setForwardBusy] = useState(false);
  const [availableChats, setAvailableChats] = useState<Conversation[]>([]);

  const forwardDestinations = useMemo<ForwardDestination[]>(
    () => buildForwardDestinations(availableChats, profile?.id, profile),
    [availableChats, profile],
  );

  useEffect(() => {
    if (openMenuId === null) {
      return undefined;
    }

    function handlePointerDown(event: MouseEvent) {
      const target = event.target as HTMLElement | null;
      if (target?.closest('.comment-card__menu-wrap')) {
        return;
      }
      setOpenMenuId(null);
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        setOpenMenuId(null);
      }
    }

    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [openMenuId]);

  useEffect(() => {
    if (!forwardingComment) {
      return undefined;
    }

    let cancelled = false;

    async function loadChats() {
      try {
        const nextChats = await api.chats.list();
        if (!cancelled) {
          setAvailableChats(nextChats);
        }
      } catch {
        if (!cancelled) {
          setAvailableChats([]);
        }
      }
    }

    void loadChats();

    return () => {
      cancelled = true;
    };
  }, [forwardingComment]);

  async function handleForward(destination: ForwardDestination) {
    if (!forwardingComment) {
      return;
    }

    setForwardBusy(true);
    try {
      let conversationId = destination.conversationId;
      if (!conversationId) {
        const directChat = await api.chats.openDirect(destination.peerId);
        conversationId = directChat.id;
      }

      await api.chats.send(conversationId, {
        content: buildForwardedCommentText(forwardingComment, post),
      });

      setForwardingComment(null);
    } finally {
      setForwardBusy(false);
    }
  }

  const composerLabel = editingCommentId
    ? 'Редактирование комментария'
    : replyTarget
      ? `Ответ пользователю @${replyTarget.author.username}`
      : null;

  const composerPlaceholder = editingCommentId
    ? 'Обновить комментарий'
    : replyTarget
      ? `Ответить @${replyTarget.author.username}`
      : 'Написать комментарий';

  return (
    <div className={`comments-panel${mode === 'detail' ? ' comments-panel--detail' : ''}`}>
      {mode === 'detail' ? (
        <div className="comments-panel__toolbar">
          <div className="comments-panel__toolbar-copy">
            <strong>Обсуждение</strong>
            <span>Ответы, реакции и вся ветка поста в одном месте.</span>
          </div>

          <ContentTabs
            ariaLabel="Сортировка комментариев"
            className="comments-panel__sort"
            items={[
              { value: 'top', label: 'Топ' },
              { value: 'latest', label: 'Новые' },
            ]}
            value={sort}
            onChange={(value) => onSortChange(value as CommentSort)}
          />
        </div>
      ) : null}

      {composerLabel ? (
        <div className="composer-state">
          <span>{composerLabel}</span>
          <button className="text-button" type="button" onClick={editingCommentId ? onCancelEdit : onCancelReply}>
            Отмена
          </button>
        </div>
      ) : null}

      <div className="comments-panel__composer">
        <div className="comments-panel__input-row">
          <textarea
            className="input input--area comments-panel__textarea"
            rows={1}
            value={draft}
            placeholder={composerPlaceholder}
            onChange={(event) => onDraftChange(event.target.value)}
            onKeyDown={(event) => {
              if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
                event.preventDefault();
                void onSubmit();
              }
            }}
          />

          <button className="primary-button primary-button--sm comments-panel__submit" disabled={busy || !draft.trim()} type="button" onClick={() => void onSubmit()}>
            {busy ? 'Отправляем...' : editingCommentId ? 'Сохранить' : replyTarget ? 'Ответить' : 'Комментировать'}
          </button>
        </div>
      </div>

      {error ? <div className="error-banner error-banner--compact">{error}</div> : null}

      <div className="stack-list comments-panel__stack">
        {!loading && comments.length === 0 ? (
          <div className="empty-card empty-card--compact">Пока нет комментариев. Начните обсуждение первым.</div>
        ) : null}

        {comments.map((comment) => {
          const isExpanded = Boolean(expandedReplyIds[comment.id]);
          const visibleReplies = isExpanded ? repliesByParent[comment.id] ?? comment.previewReplies ?? [] : comment.previewReplies ?? [];
          const hasReplies = comment.repliesCount > 0;

          return (
            <div key={comment.id} className="comment-thread__group">
              <CommentCard
                comment={comment}
                currentUserId={currentUserId}
                menuOpen={openMenuId === comment.id}
                postId={post.id}
                onDelete={onDelete}
                onEdit={onEdit}
                onForward={setForwardingComment}
                onReply={onReply}
                onToggleLike={onToggleLike}
                onToggleMenu={setOpenMenuId}
              />

              {visibleReplies.length ? (
                <div className="comment-thread__replies">
                  {visibleReplies.map((reply) => (
                    <CommentCard
                      key={reply.id}
                      comment={reply}
                      currentUserId={currentUserId}
                      isReply
                      menuOpen={openMenuId === reply.id}
                      postId={post.id}
                      onDelete={onDelete}
                      onEdit={onEdit}
                      onForward={setForwardingComment}
                      onReply={onReply}
                      onToggleLike={onToggleLike}
                      onToggleMenu={setOpenMenuId}
                    />
                  ))}
                </div>
              ) : null}

              {hasReplies ? (
                <div className="comment-thread__footer">
                  <button className="text-button" type="button" onClick={() => void onToggleReplies(comment)}>
                    {isExpanded ? 'Свернуть ответы' : `Показать ${comment.repliesCount} ${pluralizeReplies(comment.repliesCount)}`}
                  </button>
                  {loadingReplies[comment.id] ? <span className="comment-thread__hint">Загружаем ответы...</span> : null}
                </div>
              ) : null}
            </div>
          );
        })}
      </div>

      <div className="comments-panel__footer">
        {hasMore ? (
          <button className="ghost-button ghost-button--sm" disabled={loading} type="button" onClick={() => void onLoadMore()}>
            {loading ? 'Загружаем...' : 'Показать ещё комментарии'}
          </button>
        ) : null}

        {mode === 'inline' && onOpenDetail ? (
          <button className="text-button" type="button" onClick={onOpenDetail}>
            Открыть весь тред
          </button>
        ) : null}
      </div>

      {forwardingComment ? (
        <ForwardSheet
          busy={forwardBusy}
          destinations={forwardDestinations}
          onClose={() => setForwardingComment(null)}
          onSelect={handleForward}
        />
      ) : null}
    </div>
  );
}

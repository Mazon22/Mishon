import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';

import { api } from '../../shared/api/api';
import { formatAbsoluteDate, formatCount, formatRelativeDate } from '../../shared/lib/format';
import type { Comment, Post } from '../../shared/types/api';
import { AppIcon } from '../../shared/ui/AppIcon';
import { UserAvatar } from '../../shared/ui/UserAvatar';
import { VerifiedBadge } from '../../shared/ui/VerifiedBadge';
import { PostActions } from './PostActions';

type PostMediaViewerProps = {
  post: Post;
  imageUrl: string;
  alt: string;
  onClose: () => void;
  onLike: () => void | Promise<void>;
  onBookmark: () => void | Promise<void>;
  onShare: () => void | Promise<void>;
  onOpenThread: () => void;
};

const EXIT_DURATION_MS = 220;

export function PostMediaViewer({ post, imageUrl, alt, onClose, onLike, onBookmark, onShare, onOpenThread }: PostMediaViewerProps) {
  const [closing, setClosing] = useState(false);
  const [commentsPreview, setCommentsPreview] = useState<Comment[]>([]);
  const [commentsBusy, setCommentsBusy] = useState(false);
  const closeButtonRef = useRef<HTMLButtonElement | null>(null);

  const displayName = post.author.displayName || post.author.username;
  const isVerified = Boolean(post.author.isVerified);
  const createdAtLabel = useMemo(() => formatAbsoluteDate(post.createdAt), [post.createdAt]);

  const beginClose = useCallback(() => {
    setClosing((current) => (current ? current : true));
  }, []);

  useEffect(() => {
    closeButtonRef.current?.focus({ preventScroll: true });
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function loadPreview() {
      setCommentsBusy(true);
      try {
        const response = await api.feed.comments(post.id, {
          sort: 'latest',
          page: 1,
          pageSize: 2,
        });
        if (!cancelled) {
          setCommentsPreview(response.items);
        }
      } catch {
        if (!cancelled) {
          setCommentsPreview([]);
        }
      } finally {
        if (!cancelled) {
          setCommentsBusy(false);
        }
      }
    }

    void loadPreview();

    return () => {
      cancelled = true;
    };
  }, [post.id]);

  useEffect(() => {
    const scrollY = window.scrollY;
    const previousOverflow = document.body.style.overflow;
    const previousPosition = document.body.style.position;
    const previousTop = document.body.style.top;
    const previousWidth = document.body.style.width;

    document.body.style.overflow = 'hidden';
    document.body.style.position = 'fixed';
    document.body.style.top = `-${scrollY}px`;
    document.body.style.width = '100%';

    return () => {
      document.body.style.overflow = previousOverflow;
      document.body.style.position = previousPosition;
      document.body.style.top = previousTop;
      document.body.style.width = previousWidth;
      window.scrollTo(0, scrollY);
    };
  }, []);

  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        event.preventDefault();
        beginClose();
      }
    }

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [beginClose]);

  useEffect(() => {
    if (!closing) {
      return undefined;
    }

    const timer = window.setTimeout(() => {
      onClose();
    }, EXIT_DURATION_MS);

    return () => window.clearTimeout(timer);
  }, [closing, onClose]);

  if (typeof document === 'undefined') {
    return null;
  }

  return createPortal(
    <div
      aria-modal="true"
      className={`media-viewer${closing ? ' media-viewer--closing' : ''}`}
      role="dialog"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) {
          beginClose();
        }
      }}
    >
      <button
        ref={closeButtonRef}
        aria-label="Закрыть просмотр изображения"
        className="media-viewer__close"
        type="button"
        onClick={beginClose}
      >
        <AppIcon className="app-icon" name="close" />
      </button>

      <div className="media-viewer__content" onMouseDown={(event) => event.stopPropagation()}>
        <div className="media-viewer__image-pane">
          <img alt={alt} className="media-viewer__image" src={imageUrl} />
        </div>

        <aside className="media-viewer__aside">
          <div className="media-viewer__author">
            <UserAvatar
              imageUrl={post.author.avatarUrl}
              name={displayName}
              offsetX={post.author.avatarOffsetX}
              offsetY={post.author.avatarOffsetY}
              scale={post.author.avatarScale}
              size="sm"
            />

            <div className="media-viewer__author-copy">
              <div className="media-viewer__author-line">
                <strong>{displayName}</strong>
                <span>@{post.author.username}</span>
                <VerifiedBadge verified={isVerified} />
              </div>

              <time dateTime={post.createdAt}>{createdAtLabel}</time>
            </div>
          </div>

          {post.content ? <p className="media-viewer__text">{post.content}</p> : null}

          <PostActions
            commentsCount={post.commentsCount}
            commentsActive={false}
            isBookmarked={post.isBookmarked}
            isLiked={post.isLiked}
            likesCount={post.likesCount}
            onBookmark={onBookmark}
            onCommentClick={onOpenThread}
            onLike={onLike}
            onShare={onShare}
          />

          <div className="media-viewer__thread">
            <div className="media-viewer__thread-header">
              <strong>Обсуждение</strong>
              <button className="text-button" type="button" onClick={onOpenThread}>
                Открыть обсуждение
              </button>
            </div>

            {commentsBusy ? <div className="media-viewer__thread-state">Загружаем комментарии...</div> : null}

            {!commentsBusy && commentsPreview.length === 0 ? (
              <div className="media-viewer__thread-state">Пока нет комментариев. Обсуждение начнётся здесь.</div>
            ) : null}

            {!commentsBusy && commentsPreview.length ? (
              <div className="media-viewer__comments">
                {commentsPreview.map((comment) => (
                  <button key={comment.id} className="media-viewer__comment" type="button" onClick={onOpenThread}>
                    <div className="media-viewer__comment-header">
                      <strong>{comment.author.displayName || comment.author.username}</strong>
                      <span>@{comment.author.username}</span>
                      <span>·</span>
                      <time dateTime={comment.createdAt}>{formatRelativeDate(comment.createdAt)}</time>
                    </div>
                    <p>{comment.content}</p>
                  </button>
                ))}
              </div>
            ) : null}
          </div>

          <div className="media-viewer__stats">
            <div className="media-viewer__stat">
              <AppIcon className="app-icon" name="comment" />
              <span>{formatCount(post.commentsCount)}</span>
            </div>
            <div className="media-viewer__stat">
              <AppIcon className="app-icon" name="heart" />
              <span>{formatCount(post.likesCount)}</span>
            </div>
          </div>
        </aside>
      </div>
    </div>,
    document.body,
  );
}

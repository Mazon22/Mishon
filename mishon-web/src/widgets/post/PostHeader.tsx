import { useEffect, useRef, useState } from 'react';

import { formatRelativeDate } from '../../shared/lib/format';
import type { Post } from '../../shared/types/api';
import { AppIcon } from '../../shared/ui/AppIcon';
import { ConfirmDialog } from '../../shared/ui/ConfirmDialog';
import { VerifiedBadge } from '../../shared/ui/VerifiedBadge';

type PostHeaderProps = {
  post: Post;
  canDelete?: boolean;
  onOpenThread?: () => void;
  onEdit?: () => void;
  onDelete?: (postId: number) => Promise<void>;
};

export function PostHeader({ post, canDelete, onOpenThread, onEdit, onDelete }: PostHeaderProps) {
  const displayName = post.author.displayName || post.author.username;
  const isVerified = Boolean(post.author.isVerified);
  const [menuOpen, setMenuOpen] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const menuRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!menuOpen) {
      return undefined;
    }

    function handlePointerDown(event: MouseEvent) {
      if (!menuRef.current?.contains(event.target as Node)) {
        setMenuOpen(false);
      }
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        setMenuOpen(false);
      }
    }

    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [menuOpen]);

  async function handleDelete() {
    if (!onDelete || deleteBusy) {
      return;
    }

    setDeleteBusy(true);

    try {
      await onDelete(post.id);
      setConfirmOpen(false);
    } finally {
      setDeleteBusy(false);
    }
  }

  return (
    <header className="post-card__header">
      <div className="author-row__content">
        <div className="author-row__title-line">
          <strong className="author-row__title">{displayName}</strong>
          <span className="author-row__identity">
            <span className="author-row__meta">@{post.author.username}</span>
            <VerifiedBadge verified={isVerified} />
          </span>
          <span className="author-row__meta">·</span>
          {onOpenThread ? (
            <button className="author-row__time" type="button" onClick={onOpenThread}>
              {formatRelativeDate(post.createdAt)}
            </button>
          ) : (
            <time className="author-row__meta" dateTime={post.createdAt}>
              {formatRelativeDate(post.createdAt)}
            </time>
          )}
        </div>
      </div>

      {canDelete && onDelete ? (
        <div ref={menuRef} className="post-card__menu-wrap">
          <button
            aria-expanded={menuOpen}
            aria-haspopup="menu"
            aria-label="Действия публикации"
            className="icon-button icon-button--ghost post-card__menu"
            onClick={() => setMenuOpen((current) => !current)}
            type="button"
          >
            <AppIcon className="shell-icon shell-icon--sm" name="more" />
          </button>

          {menuOpen ? (
            <div className="post-menu" role="menu">
              <button
                className="post-menu__item"
                role="menuitem"
                type="button"
                onClick={() => {
                  setMenuOpen(false);
                  onEdit?.();
                }}
              >
                <AppIcon className="app-icon" name="edit" />
                <span>Редактировать</span>
              </button>
              <button
                className="post-menu__item post-menu__item--danger"
                role="menuitem"
                type="button"
                onClick={() => {
                  setMenuOpen(false);
                  setConfirmOpen(true);
                }}
              >
                <AppIcon className="app-icon" name="trash" />
                <span>Удалить пост</span>
              </button>
            </div>
          ) : null}
        </div>
      ) : null}

      <ConfirmDialog
        busy={deleteBusy}
        cancelLabel="Отмена"
        confirmLabel="Удалить"
        description="Это действие нельзя отменить. Публикация исчезнет из вашего профиля, ленты и обсуждения."
        open={confirmOpen}
        title="Удалить пост?"
        onCancel={() => {
          if (!deleteBusy) {
            setConfirmOpen(false);
          }
        }}
        onConfirm={() => void handleDelete()}
      />
    </header>
  );
}

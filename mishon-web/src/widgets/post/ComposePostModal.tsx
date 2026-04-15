import { useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';

import { AppIcon } from '../../shared/ui/AppIcon';
import { PostComposer } from './PostComposer';

type ComposePostModalProps = {
  open: boolean;
  busy?: boolean;
  onClose: () => void;
  onSubmit: (payload: { content: string; imageUrl?: string; imageFile?: File | null }) => Promise<void>;
};

export function ComposePostModal({ open, busy, onClose, onSubmit }: ComposePostModalProps) {
  const scrollRef = useRef(0);

  useEffect(() => {
    if (!open) {
      return undefined;
    }

    scrollRef.current = window.scrollY;

    const previousOverflow = document.body.style.overflow;
    const previousPosition = document.body.style.position;
    const previousTop = document.body.style.top;
    const previousWidth = document.body.style.width;

    document.body.style.overflow = 'hidden';
    document.body.style.position = 'fixed';
    document.body.style.top = `-${scrollRef.current}px`;
    document.body.style.width = '100%';

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape' && !busy) {
        event.preventDefault();
        onClose();
      }
    }

    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      document.body.style.overflow = previousOverflow;
      document.body.style.position = previousPosition;
      document.body.style.top = previousTop;
      document.body.style.width = previousWidth;
      window.scrollTo(0, scrollRef.current);
    };
  }, [busy, onClose, open]);

  if (!open || typeof document === 'undefined') {
    return null;
  }

  return createPortal(
    <div
      aria-modal="true"
      className="compose-modal"
      role="dialog"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !busy) {
          onClose();
        }
      }}
    >
      <div className="compose-modal__card" onMouseDown={(event) => event.stopPropagation()}>
        <header className="compose-modal__header">
          <button
            aria-label="Закрыть окно создания поста"
            className="icon-button icon-button--ghost compose-modal__close"
            type="button"
            onClick={onClose}
          >
            <AppIcon className="button-icon" name="close" />
          </button>

          <h2 className="compose-modal__title">Новая публикация</h2>

          <span className="compose-modal__balance" aria-hidden="true" />
        </header>

        <PostComposer autoFocus busy={busy} onSubmit={onSubmit} onSubmitted={onClose} variant="modal" />
      </div>
    </div>,
    document.body,
  );
}

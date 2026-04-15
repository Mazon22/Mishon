import { useEffect, useId, useRef, type MouseEvent, type MutableRefObject } from 'react';

import { AppIcon } from '../../../shared/ui/AppIcon';
import { AuthBrandMark } from './AuthBrandMark';
import { LegalContent } from './LegalContent';
import type { LegalDocument } from '../lib/legal-content';

type LegalModalProps = {
  legalDocument: LegalDocument;
  onClose: () => void;
  returnFocusRef?: MutableRefObject<HTMLElement | null>;
};

function getFocusableElements(container: HTMLElement | null) {
  if (!container) {
    return [] as HTMLElement[];
  }

  return Array.from(
    container.querySelectorAll<HTMLElement>(
      'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
    ),
  ).filter((element) => !element.hasAttribute('hidden') && element.tabIndex !== -1);
}

export function LegalModal({ legalDocument, onClose, returnFocusRef }: LegalModalProps) {
  const dialogRef = useRef<HTMLDivElement | null>(null);
  const closeButtonRef = useRef<HTMLButtonElement | null>(null);
  const titleId = useId();
  const descriptionId = useId();

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    const previousActiveElement = document.activeElement as HTMLElement | null;
    const focusReturnTarget = returnFocusRef?.current ?? null;
    document.body.style.overflow = 'hidden';

    const frame = requestAnimationFrame(() => {
      closeButtonRef.current?.focus({ preventScroll: true });
    });

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        event.preventDefault();
        onClose();
        return;
      }

      if (event.key !== 'Tab') {
        return;
      }

      const focusable = getFocusableElements(dialogRef.current);
      if (focusable.length === 0) {
        event.preventDefault();
        return;
      }

      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      const active = document.activeElement as HTMLElement | null;

      if (event.shiftKey) {
        if (!active || active === first || !dialogRef.current?.contains(active)) {
          event.preventDefault();
          last.focus();
        }
        return;
      }

      if (!active || active === last || !dialogRef.current?.contains(active)) {
        event.preventDefault();
        first.focus();
      }
    }

    window.addEventListener('keydown', handleKeyDown);

    return () => {
      cancelAnimationFrame(frame);
      document.body.style.overflow = previousOverflow;
      window.removeEventListener('keydown', handleKeyDown);

      const target = focusReturnTarget ?? previousActiveElement;
      target?.focus?.({ preventScroll: true });
    };
  }, [onClose, returnFocusRef]);

  function stopPropagation(event: MouseEvent<HTMLDivElement>) {
    event.stopPropagation();
  }

  return (
    <div className="auth-modal-backdrop auth-modal-backdrop--legal" role="presentation" onClick={onClose}>
      <div
        ref={dialogRef}
        className="auth-modal auth-modal--legal"
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={descriptionId}
        onClick={stopPropagation}
      >
        <div className="auth-modal__topbar">
          <button
            ref={closeButtonRef}
            className="auth-icon-button"
            type="button"
            aria-label="Закрыть юридический документ"
            onClick={onClose}
          >
            <AppIcon name="close" className="app-icon" />
          </button>
          <AuthBrandMark size="sm" />
          <span className="auth-modal__spacer" aria-hidden="true" />
        </div>

        <header className="auth-modal__header auth-modal__header--legal">
          <h2 id={titleId}>{legalDocument.title}</h2>
          <p id={descriptionId}>Временный локальный документ для интерфейса Mishon.</p>
        </header>

        <div className="auth-modal__content auth-modal__content--legal">
          <LegalContent document={legalDocument} />
        </div>
      </div>
    </div>
  );
}

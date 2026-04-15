import { useEffect, type MouseEvent, type ReactNode } from 'react';

import { AppIcon } from '../../../shared/ui/AppIcon';
import { AuthBrandMark } from './AuthBrandMark';

type ModalShellProps = {
  title: string;
  subtitle?: string;
  onClose: () => void;
  children: ReactNode;
};

export function ModalShell({ title, subtitle, onClose, children }: ModalShellProps) {
  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        onClose();
      }
    }

    window.addEventListener('keydown', onKeyDown);

    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener('keydown', onKeyDown);
    };
  }, [onClose]);

  function stop(event: MouseEvent<HTMLDivElement>) {
    event.stopPropagation();
  }

  return (
    <div className="auth-modal-backdrop" role="presentation" onClick={onClose}>
      <div
        aria-modal="true"
        className="auth-modal"
        role="dialog"
        aria-labelledby="auth-modal-title"
        onClick={stop}
      >
        <div className="auth-modal__topbar">
          <button className="auth-icon-button" type="button" aria-label="Закрыть окно" onClick={onClose}>
            <AppIcon name="close" className="app-icon" />
          </button>
          <AuthBrandMark size="sm" />
          <span className="auth-modal__spacer" aria-hidden="true" />
        </div>

        <header className="auth-modal__header">
          <h2 id="auth-modal-title">{title}</h2>
          {subtitle ? <p>{subtitle}</p> : null}
        </header>

        {children}
      </div>
    </div>
  );
}

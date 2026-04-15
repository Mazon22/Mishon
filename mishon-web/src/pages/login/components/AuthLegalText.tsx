import { useRef, useState, type MouseEvent } from 'react';

import { LEGAL_DOCUMENTS, type LegalDocumentId } from '../lib/legal-content';
import { LegalModal } from './LegalModal';

export function AuthLegalText() {
  const [activeDocumentId, setActiveDocumentId] = useState<LegalDocumentId | null>(null);
  const returnFocusRef = useRef<HTMLElement | null>(null);

  function handleOpen(documentId: LegalDocumentId) {
    return function onOpen(event: MouseEvent<HTMLAnchorElement>) {
      event.preventDefault();
      returnFocusRef.current = event.currentTarget;
      setActiveDocumentId(documentId);
    };
  }

  function handleClose() {
    setActiveDocumentId(null);
  }

  return (
    <>
      <p className="auth-legal">
        Создавая аккаунт, вы принимаете{' '}
        <a className="auth-legal__link" href="/legal/terms" onClick={handleOpen('terms')}>
          условия
        </a>
        ,{' '}
        <a className="auth-legal__link" href="/legal/privacy" onClick={handleOpen('privacy')}>
          политику приватности
        </a>{' '}
        и{' '}
        <a className="auth-legal__link" href="/legal/cookies" onClick={handleOpen('cookies')}>
          cookie
        </a>
        .
      </p>

      {activeDocumentId ? (
        <LegalModal
          legalDocument={LEGAL_DOCUMENTS[activeDocumentId]}
          onClose={handleClose}
          returnFocusRef={returnFocusRef}
        />
      ) : null}
    </>
  );
}

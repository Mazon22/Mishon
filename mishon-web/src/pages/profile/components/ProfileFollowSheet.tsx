import { useEffect, useId, useMemo } from 'react';
import { createPortal } from 'react-dom';

import type { FollowListEntry } from '../../../shared/types/api';
import { AppIcon } from '../../../shared/ui/AppIcon';
import { PeopleRow } from '../../friends/components/PeopleRow';

export type ProfileFollowSheetMode = 'followers' | 'following';

type ProfileFollowSheetProps = {
  open: boolean;
  mode: ProfileFollowSheetMode;
  profileName: string;
  busy: boolean;
  error?: string | null;
  items: FollowListEntry[];
  onClose: () => void;
  onSelect: (userId: number) => void;
};

const sheetCopy: Record<
  ProfileFollowSheetMode,
  {
    title: string;
    subtitle: string;
    empty: string;
    loading: string;
  }
> = {
  followers: {
    title: 'Подписчики',
    subtitle: 'Люди, которые следят за этим профилем.',
    empty: 'Здесь пока пусто. Когда появятся подписчики, они будут показаны в этом списке.',
    loading: 'Загружаем подписчиков...',
  },
  following: {
    title: 'Подписки',
    subtitle: 'Люди, на которых подписан этот профиль.',
    empty: 'Здесь пока нет подписок.',
    loading: 'Загружаем подписки...',
  },
};

export function ProfileFollowSheet({
  open,
  mode,
  profileName,
  busy,
  error,
  items,
  onClose,
  onSelect,
}: ProfileFollowSheetProps) {
  const titleId = useId();
  const descriptionId = useId();
  const copy = sheetCopy[mode];

  const subtitle = useMemo(() => `${profileName} · ${copy.subtitle}`, [copy.subtitle, profileName]);

  useEffect(() => {
    if (!open) {
      return undefined;
    }

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        onClose();
      }
    }

    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [onClose, open]);

  if (!open || typeof document === 'undefined') {
    return null;
  }

  return createPortal(
    <div
      className="profile-follow-sheet"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) {
          onClose();
        }
      }}
    >
      <section
        aria-describedby={descriptionId}
        aria-labelledby={titleId}
        aria-modal="true"
        className="profile-follow-sheet__card"
        role="dialog"
      >
        <header className="profile-follow-sheet__header">
          <div className="profile-follow-sheet__copy">
            <h2 id={titleId}>{copy.title}</h2>
            <p id={descriptionId}>{subtitle}</p>
          </div>

          <button
            aria-label="Закрыть"
            className="icon-button icon-button--ghost profile-follow-sheet__close"
            type="button"
            onClick={onClose}
          >
            <AppIcon className="profile-follow-sheet__close-icon" name="close" />
          </button>
        </header>

        <div className="profile-follow-sheet__body">
          {error ? (
            <div className="error-banner profile-follow-sheet__state">{error}</div>
          ) : busy ? (
            <div className="empty-card profile-follow-sheet__state">{copy.loading}</div>
          ) : items.length === 0 ? (
            <div className="empty-card profile-follow-sheet__state">{copy.empty}</div>
          ) : (
            <div className="people-stack">
              {items.map((item) => (
                <PeopleRow
                  key={item.id}
                  meta={item.isPrivateAccount ? 'Приватный профиль' : 'Открытый профиль'}
                  onOpen={() => onSelect(item.id)}
                  person={item}
                  trailing={item.isFollowing ? 'Вы подписаны' : undefined}
                />
              ))}
            </div>
          )}
        </div>
      </section>
    </div>,
    document.body,
  );
}

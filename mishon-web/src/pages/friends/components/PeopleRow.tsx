import type { MouseEvent } from 'react';

import { VerifiedBadge } from '../../../shared/ui/VerifiedBadge';
import { UserAvatar } from '../../../shared/ui/UserAvatar';

type PersonIdentity = {
  username: string;
  displayName?: string | null;
  isVerified?: boolean;
  avatarUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
};

type PeopleAction = {
  label: string;
  tone?: 'primary' | 'secondary' | 'danger';
  disabled?: boolean;
  onClick: () => void | Promise<void>;
};

type PeopleRowProps = {
  person: PersonIdentity;
  eyebrow?: string;
  meta?: string;
  trailing?: string;
  actions?: PeopleAction[];
  onOpen?: () => void;
};

export function PeopleRow({ person, eyebrow, meta, trailing, actions = [], onOpen }: PeopleRowProps) {
  const displayName = person.displayName || person.username;

  function stopRowClick(event: MouseEvent<HTMLButtonElement>) {
    event.stopPropagation();
  }

  return (
    <article
      className={`people-row${onOpen ? ' people-row--interactive' : ''}`}
      role={onOpen ? 'button' : undefined}
      tabIndex={onOpen ? 0 : undefined}
      onClick={onOpen}
      onKeyDown={
        onOpen
          ? (event) => {
              if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                onOpen();
              }
            }
          : undefined
      }
    >
      <UserAvatar
        imageUrl={person.avatarUrl}
        name={displayName}
        offsetX={person.avatarOffsetX}
        offsetY={person.avatarOffsetY}
        scale={person.avatarScale}
        size="lg"
      />

      <div className="people-row__body">
        {eyebrow ? <div className="people-row__eyebrow">{eyebrow}</div> : null}

        <div className="people-row__headline">
          <strong>{displayName}</strong>
          <span className="people-row__handle">@{person.username}</span>
          <VerifiedBadge verified={person.isVerified} />
          {trailing ? <span className="people-row__trailing">{trailing}</span> : null}
        </div>

        {meta ? <div className="people-row__meta">{meta}</div> : null}
      </div>

      {actions.length > 0 ? (
        <div className="people-row__actions">
          {actions.map((action) => (
            <button
              key={action.label}
              className={`people-row__action people-row__action--${action.tone ?? 'secondary'}`}
              disabled={action.disabled}
              type="button"
              onClick={(event) => {
                stopRowClick(event);
                void action.onClick();
              }}
            >
              {action.label}
            </button>
          ))}
        </div>
      ) : null}
    </article>
  );
}

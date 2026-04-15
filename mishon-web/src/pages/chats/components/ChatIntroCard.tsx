import { UserAvatar } from '../../../shared/ui/UserAvatar';

type ChatIntroCardProps = {
  avatarUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
  name: string;
  username?: string | null;
  meta: string;
  buttonLabel?: string;
  onOpenProfile: () => void;
};

export function ChatIntroCard({
  avatarUrl,
  avatarScale,
  avatarOffsetX,
  avatarOffsetY,
  name,
  username,
  meta,
  buttonLabel = 'Посмотреть профиль',
  onOpenProfile,
}: ChatIntroCardProps) {
  return (
    <section className="chat-intro">
      <UserAvatar
        imageUrl={avatarUrl}
        name={name}
        offsetX={avatarOffsetX}
        offsetY={avatarOffsetY}
        scale={avatarScale}
        size="xl"
      />

      <div className="chat-intro__copy">
        <strong>{name}</strong>
        {username ? <span>@{username}</span> : null}
        <small>{meta}</small>
      </div>

      <button className="ghost-button ghost-button--sm chat-intro__action" type="button" onClick={onOpenProfile}>
        {buttonLabel}
      </button>
    </section>
  );
}

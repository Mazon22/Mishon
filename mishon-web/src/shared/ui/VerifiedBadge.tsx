import { AppIcon } from './AppIcon';

type VerifiedBadgeProps = {
  verified?: boolean;
  size?: 'sm' | 'md';
  className?: string;
};

const sizeClassMap: Record<NonNullable<VerifiedBadgeProps['size']>, string> = {
  sm: 'verified-badge--sm',
  md: 'verified-badge--md',
};

export function VerifiedBadge({ verified, size = 'sm', className = '' }: VerifiedBadgeProps) {
  if (!verified) {
    return null;
  }

  return (
    <span
      aria-label="Подтверждённый аккаунт"
      className={['verified-badge', sizeClassMap[size], className].filter(Boolean).join(' ')}
      title="Подтверждённый аккаунт"
    >
      <AppIcon className="verified-badge__icon" name="verified" />
    </span>
  );
}

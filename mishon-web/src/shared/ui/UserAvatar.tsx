import { useState } from 'react';

import { initials } from '../lib/format';
import { buildMediaTransformStyle } from '../lib/media';

type UserAvatarProps = {
  name: string;
  imageUrl?: string | null;
  scale?: number;
  offsetX?: number;
  offsetY?: number;
  size?: 'mini' | 'sm' | 'md' | 'lg' | 'xl' | 'xxl';
  className?: string;
};

const sizeClassMap: Record<NonNullable<UserAvatarProps['size']>, string> = {
  mini: 'avatar--mini',
  sm: 'avatar--sm',
  md: 'avatar--md',
  lg: 'avatar--lg',
  xl: 'avatar--xl',
  xxl: 'avatar--xxl',
};

export function UserAvatar({
  name,
  imageUrl,
  scale = 1,
  offsetX = 0,
  offsetY = 0,
  size = 'md',
  className = '',
}: UserAvatarProps) {
  const normalizedImageUrl = imageUrl?.trim() || null;
  const [failedImageUrl, setFailedImageUrl] = useState<string | null>(null);

  const classes = ['avatar', sizeClassMap[size], className].filter(Boolean).join(' ');
  const showImage = Boolean(normalizedImageUrl) && failedImageUrl !== normalizedImageUrl;

  return (
    <div className={classes}>
      {showImage ? (
        <img
          alt={name}
          className="avatar__image"
          src={normalizedImageUrl ?? undefined}
          style={buildMediaTransformStyle(scale, offsetX, offsetY)}
          onError={() => setFailedImageUrl(normalizedImageUrl)}
        />
      ) : (
        initials(name)
      )}
    </div>
  );
}

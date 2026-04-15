import { useRef, useState } from 'react';

import type { Post } from '../../shared/types/api';
import { PostMediaViewer } from './PostMediaViewer';

type PostMediaProps = {
  post: Post;
  onLike: () => void | Promise<void>;
  onBookmark: () => void | Promise<void>;
  onShare: () => void | Promise<void>;
  onOpenThread: () => void;
};

type MediaVariant = 'landscape' | 'square' | 'portrait';

function resolveVariant(width: number, height: number): MediaVariant {
  if (!width || !height) {
    return 'landscape';
  }

  const ratio = width / height;

  if (ratio < 0.85) {
    return 'portrait';
  }

  if (ratio < 1.15) {
    return 'square';
  }

  return 'landscape';
}

export function PostMedia({ post, onLike, onBookmark, onShare, onOpenThread }: PostMediaProps) {
  const [variant, setVariant] = useState<MediaVariant>('landscape');
  const [measuredUrl, setMeasuredUrl] = useState<string | null>(null);
  const [viewerOpen, setViewerOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement | null>(null);

  const imageUrl = post.imageUrl;

  if (!imageUrl) {
    return null;
  }

  const resolvedVariant = measuredUrl === imageUrl ? variant : 'landscape';
  const alt = post.content.slice(0, 80) || 'Изображение публикации';

  return (
    <>
      <button
        ref={triggerRef}
        aria-label="Открыть изображение публикации"
        className={`post-card__media post-card__media--${resolvedVariant} post-card__media-trigger`}
        type="button"
        onClick={() => setViewerOpen(true)}
      >
        <img
          alt={alt}
          className={`post-card__media-image post-card__media-image--${resolvedVariant}`}
          src={imageUrl}
          onLoad={(event) => {
            const { naturalWidth, naturalHeight } = event.currentTarget;
            setMeasuredUrl(imageUrl);
            setVariant(resolveVariant(naturalWidth, naturalHeight));
          }}
        />
      </button>

      {viewerOpen ? (
        <PostMediaViewer
          alt={alt}
          imageUrl={imageUrl}
          post={post}
          onBookmark={onBookmark}
          onClose={() => {
            setViewerOpen(false);
            window.requestAnimationFrame(() => {
              triggerRef.current?.focus({ preventScroll: true });
            });
          }}
          onLike={onLike}
          onOpenThread={onOpenThread}
          onShare={onShare}
        />
      ) : null}
    </>
  );
}

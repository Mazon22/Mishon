import { useEffect, useState } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';

import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import type { Post } from '../../shared/types/api';
import { PostCard } from '../../widgets/post/PostCard';
import { PostSkeleton } from '../../widgets/post/PostSkeleton';

type PostDetailPageProps = {
  currentUserId: number;
};

export function PostDetailPage({ currentUserId }: PostDetailPageProps) {
  const navigate = useNavigate();
  const location = useLocation();
  const { subscribe } = useLiveSync();
  const { postId: postIdParam } = useParams<{ postId: string }>();
  const postId = Number(postIdParam ?? 0);
  const [post, setPost] = useState<Post | null>(null);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!postId) {
      setPost(null);
      setBusy(false);
      setError('Публикация не найдена.');
      return;
    }

    let cancelled = false;

    async function loadPost() {
      setBusy(true);
      setError(null);
      try {
        const nextPost = await api.feed.getPost(postId);
        if (!cancelled) {
          setPost(nextPost);
        }
      } catch (nextError) {
        if (!cancelled) {
          setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить публикацию.');
          setPost(null);
        }
      } finally {
        if (!cancelled) {
          setBusy(false);
        }
      }
    }

    void loadPost();

    return () => {
      cancelled = true;
    };
  }, [postId]);

  useEffect(() => {
    if (!postId) {
      return undefined;
    }

    return subscribe((event) => {
      const payload = event.data as { postId?: number } | undefined;
      const eventPostId = Number(payload?.postId ?? 0);

      if (
        event.type === 'sync.resync' ||
        event.type.startsWith('comment.') ||
        ((event.type.startsWith('post.') || event.type === 'post.author-follow.changed') && (!eventPostId || eventPostId === postId))
      ) {
        void api.feed
          .getPost(postId)
          .then((nextPost) => {
            setPost(nextPost);
            setError(null);
          })
          .catch((nextError) => {
            setError(nextError instanceof Error ? nextError.message : 'Не удалось обновить публикацию.');
          });
      }
    });
  }, [postId, subscribe]);

  useEffect(() => {
    if (!location.hash) {
      return undefined;
    }

    const targetId = location.hash.slice(1);
    const timers = [200, 650].map((delay) =>
      window.setTimeout(() => {
        document.getElementById(targetId)?.scrollIntoView({ block: 'center', behavior: 'smooth' });
      }, delay),
    );

    return () => timers.forEach((timer) => window.clearTimeout(timer));
  }, [location.hash, post]);

  async function handleLike(targetPost: Post) {
    const optimistic = {
      ...targetPost,
      isLiked: !targetPost.isLiked,
      likesCount: targetPost.likesCount + (targetPost.isLiked ? -1 : 1),
    };
    setPost(optimistic);

    try {
      const updated = await api.feed.toggleLike(targetPost.id);
      setPost(updated);
    } catch (nextError) {
      setPost(targetPost);
      setError(nextError instanceof Error ? nextError.message : 'Не удалось изменить реакцию.');
    }
  }

  async function handleBookmark(targetPost: Post) {
    const optimistic = {
      ...targetPost,
      isBookmarked: !targetPost.isBookmarked,
    };
    setPost(optimistic);

    try {
      const updated = await api.feed.toggleBookmark(targetPost.id);
      setPost(updated);
    } catch (nextError) {
      setPost(targetPost);
      setError(nextError instanceof Error ? nextError.message : 'Не удалось обновить закладку.');
    }
  }

  return (
    <div className="timeline">
      {error ? <div className="error-banner timeline-banner">{error}</div> : null}

      {busy ? (
        <div className="stack-list">
          <PostSkeleton />
        </div>
      ) : post ? (
        <div className="stack-list">
          <PostCard
            canDelete={post.userId === currentUserId}
            currentUserId={currentUserId}
            post={post}
            view="detail"
            onBookmark={handleBookmark}
            onDelete={async (targetPostId) => {
              await api.feed.remove(targetPostId);
              navigate('/feed');
            }}
            onLike={handleLike}
            onUpdate={async (targetPostId, payload) => {
              const updated = await api.feed.update(targetPostId, payload.content, payload.imageUrl);
              setPost(updated);
              return updated;
            }}
          />
        </div>
      ) : (
        <div className="empty-card timeline-banner">Публикация не найдена или уже была удалена.</div>
      )}
    </div>
  );
}

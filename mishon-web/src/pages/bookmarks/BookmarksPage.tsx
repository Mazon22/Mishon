import { useCallback, useEffect, useRef, useState } from 'react';

import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import type { Post } from '../../shared/types/api';
import { PostCard } from '../../widgets/post/PostCard';
import { PostSkeleton } from '../../widgets/post/PostSkeleton';

type BookmarksPageProps = {
  currentUserId: number;
};

const PAGE_SIZE = 12;

export function BookmarksPage({ currentUserId }: BookmarksPageProps) {
  const { subscribe } = useLiveSync();
  const [posts, setPosts] = useState<Post[]>([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [busy, setBusy] = useState(false);
  const [initialized, setInitialized] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const stateRef = useRef({ page: 1, hasMore: false, busy: false });

  useEffect(() => {
    stateRef.current = { page, hasMore, busy };
  }, [busy, hasMore, page]);

  const loadBookmarks = useCallback(async (targetPage = 1, append = false, silent = false) => {
    if (stateRef.current.busy) {
      return;
    }

    if (!silent) {
      setBusy(true);
    }
    setError(null);

    try {
      const response = await api.feed.listBookmarks(targetPage, PAGE_SIZE);
      setPosts((current) => {
        if (!append) {
          return response.items;
        }

        const seen = new Set(current.map((item) => item.id));
        return [...current, ...response.items.filter((item) => !seen.has(item.id))];
      });
      setPage(targetPage);
      setHasMore(Boolean(response.hasMore));
      setInitialized(true);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить закладки.');
    } finally {
      if (!silent) {
        setBusy(false);
      }
    }
  }, []);

  useEffect(() => {
    void loadBookmarks(1);
  }, [loadBookmarks]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node || !initialized || !hasMore) {
      return undefined;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        if (!entries.some((entry) => entry.isIntersecting)) {
          return;
        }

        if (!stateRef.current.busy && stateRef.current.hasMore) {
          void loadBookmarks(stateRef.current.page + 1, true);
        }
      },
      { rootMargin: '320px 0px' },
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, [hasMore, initialized, loadBookmarks]);

  useEffect(() => {
    return subscribe((event) => {
      if (
        event.type === 'sync.resync' ||
        event.type.startsWith('post.') ||
        event.type.startsWith('comment.')
      ) {
        void loadBookmarks(1, false, true);
      }
    });
  }, [loadBookmarks, subscribe]);

  async function handleLike(targetPost: Post) {
    const optimistic = {
      ...targetPost,
      isLiked: !targetPost.isLiked,
      likesCount: targetPost.likesCount + (targetPost.isLiked ? -1 : 1),
    };
    setPosts((current) => current.map((item) => (item.id === targetPost.id ? optimistic : item)));

    try {
      const updated = await api.feed.toggleLike(targetPost.id);
      setPosts((current) => current.map((item) => (item.id === updated.id ? updated : item)));
    } catch (nextError) {
      setPosts((current) => current.map((item) => (item.id === targetPost.id ? targetPost : item)));
      setError(nextError instanceof Error ? nextError.message : 'Не удалось изменить реакцию.');
    }
  }

  async function handleBookmark(targetPost: Post) {
    const optimistic = {
      ...targetPost,
      isBookmarked: !targetPost.isBookmarked,
    };
    setPosts((current) => current.map((item) => (item.id === targetPost.id ? optimistic : item)));

    try {
      const updated = await api.feed.toggleBookmark(targetPost.id);
      setPosts((current) =>
        updated.isBookmarked
          ? current.map((item) => (item.id === updated.id ? updated : item))
          : current.filter((item) => item.id !== updated.id),
      );
    } catch (nextError) {
      setPosts((current) => current.map((item) => (item.id === targetPost.id ? targetPost : item)));
      setError(nextError instanceof Error ? nextError.message : 'Не удалось обновить закладку.');
    }
  }

  return (
    <div className="timeline">
      <section className="timeline-section timeline-section--search">
        <h2 className="section-title">Сохранённые публикации</h2>
        <p className="section-subtitle">Здесь лежат посты, к которым хочется быстро вернуться позже.</p>
      </section>

      {error ? <div className="error-banner timeline-banner">{error}</div> : null}

      {!initialized && busy ? (
        <div className="stack-list">
          <PostSkeleton />
          <PostSkeleton />
        </div>
      ) : (
        <div className="stack-list">
          {posts.map((post) => (
            <PostCard
              key={post.id}
              canDelete={post.userId === currentUserId}
              currentUserId={currentUserId}
              post={post}
              onBookmark={handleBookmark}
              onDelete={async (postId) => {
                await api.feed.remove(postId);
                setPosts((current) => current.filter((item) => item.id !== postId));
              }}
              onLike={handleLike}
              onUpdate={async (postId, payload) => {
                const updated = await api.feed.update(postId, payload.content, payload.imageUrl);
                setPosts((current) => current.map((item) => (item.id === updated.id ? updated : item)));
                return updated;
              }}
            />
          ))}

          {initialized && !posts.length ? (
            <div className="empty-card timeline-banner">Пока у вас нет закладок. Сохраняйте интересные посты, чтобы они появились здесь.</div>
          ) : null}

          {initialized && busy ? (
            <>
              <PostSkeleton />
              <PostSkeleton />
            </>
          ) : null}

          <div ref={sentinelRef} className="timeline-sentinel" aria-hidden="true" />
        </div>
      )}
    </div>
  );
}

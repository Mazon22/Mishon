import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import type { Post } from '../../shared/types/api';
import { FeedHeader } from '../../widgets/feed/FeedHeader';
import { FeedTabs } from '../../widgets/feed/FeedTabs';
import { PostCard } from '../../widgets/post/PostCard';
import { PostComposer } from '../../widgets/post/PostComposer';
import { PostSkeleton } from '../../widgets/post/PostSkeleton';

type FeedMode = 'for-you' | 'following';
type PostCreatedEvent = CustomEvent<Post>;

type FeedBucket = {
  items: Post[];
  page: number;
  hasMore: boolean;
  busy: boolean;
  initialized: boolean;
  error: string | null;
};

const PAGE_SIZE = 12;

function createBucket(): FeedBucket {
  return {
    items: [],
    page: 1,
    hasMore: false,
    busy: false,
    initialized: false,
    error: null,
  };
}

function cloneBuckets(source: Record<FeedMode, FeedBucket>): Record<FeedMode, FeedBucket> {
  return {
    'for-you': { ...source['for-you'], items: [...source['for-you'].items] },
    following: { ...source.following, items: [...source.following.items] },
  };
}

export function FeedPage({ currentUserId }: { currentUserId: number }) {
  const { subscribe } = useLiveSync();
  const [mode, setMode] = useState<FeedMode>('for-you');
  const [feeds, setFeeds] = useState<Record<FeedMode, FeedBucket>>({
    'for-you': createBucket(),
    following: createBucket(),
  });
  const [composerBusy, setComposerBusy] = useState(false);
  const [bannerError, setBannerError] = useState<string | null>(null);
  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const feedsRef = useRef(feeds);

  useEffect(() => {
    feedsRef.current = feeds;
  }, [feeds]);

  const activeFeed = feeds[mode];
  const isInitialLoading = !activeFeed.initialized && activeFeed.busy;
  const isLoadingMore = activeFeed.initialized && activeFeed.busy;
  const visibleError = bannerError || activeFeed.error;

  const updatePostsAcrossFeeds = useCallback((updater: (items: Post[]) => Post[]) => {
    setFeeds((current) => ({
      'for-you': { ...current['for-you'], items: updater(current['for-you'].items) },
      following: { ...current.following, items: updater(current.following.items) },
    }));
  }, []);

  const replacePostAcrossFeeds = useCallback(
    (updated: Post) => {
      updatePostsAcrossFeeds((items) => items.map((item) => (item.id === updated.id ? updated : item)));
    },
    [updatePostsAcrossFeeds],
  );

  const removePostAcrossFeeds = useCallback(
    (postId: number) => {
      updatePostsAcrossFeeds((items) => items.filter((item) => item.id !== postId));
    },
    [updatePostsAcrossFeeds],
  );

  const prependPostAcrossFeeds = useCallback((created: Post) => {
    setFeeds((current) => ({
      'for-you': {
        ...current['for-you'],
        initialized: true,
        items: [created, ...current['for-you'].items.filter((item) => item.id !== created.id)],
      },
      following: {
        ...current.following,
        items: current.following.initialized
          ? [created, ...current.following.items.filter((item) => item.id !== created.id)]
          : current.following.items,
      },
    }));
  }, []);

  const loadFeedPage = useCallback(async (targetMode: FeedMode, targetPage = 1, append = false, silent = false) => {
    const currentBucket = feedsRef.current[targetMode];
    if (currentBucket.busy) {
      return;
    }

    setFeeds((current) => ({
      ...current,
      [targetMode]: {
        ...current[targetMode],
        busy: !silent,
        error: silent ? current[targetMode].error : null,
      },
    }));

    try {
      const response = await api.feed.list(targetMode, targetPage, PAGE_SIZE);
      setFeeds((current) => {
        const existing = append ? current[targetMode].items : [];
        const seen = new Set(existing.map((item) => item.id));
        const nextItems = append
          ? [...existing, ...response.items.filter((item) => !seen.has(item.id))]
          : response.items;

        return {
          ...current,
          [targetMode]: {
            ...current[targetMode],
            items: nextItems,
            page: targetPage,
            hasMore: Boolean(response.hasMore),
            busy: false,
            initialized: true,
            error: null,
          },
        };
      });
    } catch (nextError) {
      setFeeds((current) => ({
        ...current,
        [targetMode]: {
          ...current[targetMode],
          busy: false,
          initialized: current[targetMode].initialized || append,
          error: nextError instanceof Error ? nextError.message : 'Не удалось загрузить ленту.',
        },
      }));
    }
  }, []);

  useEffect(() => {
    if (!feeds[mode].initialized) {
      void loadFeedPage(mode, 1);
    }
  }, [feeds, loadFeedPage, mode]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node || !activeFeed.initialized || !activeFeed.hasMore) {
      return undefined;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        if (!entries.some((entry) => entry.isIntersecting)) {
          return;
        }

        const currentBucket = feedsRef.current[mode];
        if (!currentBucket.busy && currentBucket.hasMore) {
          void loadFeedPage(mode, currentBucket.page + 1, true);
        }
      },
      { rootMargin: '320px 0px' },
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, [activeFeed.hasMore, activeFeed.initialized, loadFeedPage, mode]);

  useEffect(() => {
    return subscribe((event) => {
      if (
        event.type.startsWith('post.') ||
        event.type.startsWith('comment.') ||
        event.type === 'profile.updated' ||
        event.type === 'post.author-follow.changed' ||
        event.type === 'sync.resync'
      ) {
        void loadFeedPage(mode, 1, false, true);
      }
    });
  }, [loadFeedPage, mode, subscribe]);

  useEffect(() => {
    function handlePostCreated(event: Event) {
      const createdPost = (event as PostCreatedEvent).detail;
      if (!createdPost) {
        return;
      }

      prependPostAcrossFeeds(createdPost);
    }

    window.addEventListener('mishon:post-created', handlePostCreated as EventListener);

    return () => {
      window.removeEventListener('mishon:post-created', handlePostCreated as EventListener);
    };
  }, [prependPostAcrossFeeds]);

  async function handleCreatePost(payload: { content: string; imageUrl?: string; imageFile?: File | null }) {
    setComposerBusy(true);
    setBannerError(null);
    try {
      const post = await api.feed.create(payload.content, payload.imageUrl, payload.imageFile);
      prependPostAcrossFeeds(post);
      void loadFeedPage(mode, 1, false, true);
    } catch (nextError) {
      setBannerError(nextError instanceof Error ? nextError.message : 'Не удалось опубликовать пост.');
    } finally {
      setComposerBusy(false);
    }
  }

  async function handleLike(targetPost: Post) {
    const previousFeeds = cloneBuckets(feedsRef.current);
    const optimisticPost = {
      ...targetPost,
      isLiked: !targetPost.isLiked,
      likesCount: targetPost.likesCount + (targetPost.isLiked ? -1 : 1),
    };

    updatePostsAcrossFeeds((items) => items.map((item) => (item.id === targetPost.id ? optimisticPost : item)));
    setBannerError(null);

    try {
      const updated = await api.feed.toggleLike(targetPost.id);
      replacePostAcrossFeeds(updated);
    } catch (nextError) {
      setFeeds(previousFeeds);
      setBannerError(nextError instanceof Error ? nextError.message : 'Не удалось изменить реакцию.');
    }
  }

  async function handleBookmark(targetPost: Post) {
    const previousFeeds = cloneBuckets(feedsRef.current);
    const optimisticPost = {
      ...targetPost,
      isBookmarked: !targetPost.isBookmarked,
    };

    updatePostsAcrossFeeds((items) => items.map((item) => (item.id === targetPost.id ? optimisticPost : item)));
    setBannerError(null);

    try {
      const updated = await api.feed.toggleBookmark(targetPost.id);
      replacePostAcrossFeeds(updated);
    } catch (nextError) {
      setFeeds(previousFeeds);
      setBannerError(nextError instanceof Error ? nextError.message : 'Не удалось обновить закладку.');
    }
  }

  const emptyState = useMemo(() => {
    if (mode === 'following') {
      return 'Пока здесь пусто. Подпишитесь на людей, чтобы собрать персональную ленту публикаций.';
    }
    return 'Лента пока пустая. Опубликуйте первый пост и начните разговор.';
  }, [mode]);

  return (
    <div className="timeline">
      <FeedHeader>
        <FeedTabs value={mode} onChange={setMode} />
      </FeedHeader>

      <PostComposer busy={composerBusy} onSubmit={handleCreatePost} />

      {visibleError ? <div className="error-banner timeline-banner">{visibleError}</div> : null}

      {isInitialLoading ? (
        <div className="stack-list">
          <PostSkeleton />
          <PostSkeleton />
          <PostSkeleton />
        </div>
      ) : (
        <div className="stack-list">
          {activeFeed.items.map((post) => (
            <PostCard
              key={post.id}
              canDelete={post.userId === currentUserId}
              currentUserId={currentUserId}
              post={post}
              onBookmark={handleBookmark}
              onUpdate={async (postId, payload) => {
                const updated = await api.feed.update(postId, payload.content, payload.imageUrl);
                replacePostAcrossFeeds(updated);
                return updated;
              }}
              onDelete={async (postId) => {
                await api.feed.remove(postId);
                removePostAcrossFeeds(postId);
              }}
              onLike={handleLike}
            />
          ))}

          {!activeFeed.items.length ? <div className="empty-card timeline-banner">{emptyState}</div> : null}

          {isLoadingMore ? (
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

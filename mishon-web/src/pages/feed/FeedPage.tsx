import { startTransition, useEffect, useState } from 'react';

import { api } from '../../shared/api/api';
import type { Post } from '../../shared/types/api';
import { PostCard } from '../../widgets/post/PostCard';
import { PostComposer } from '../../widgets/post/PostComposer';

export function FeedPage({ currentUserId }: { currentUserId: number }) {
  const [mode, setMode] = useState<'for-you' | 'following'>('for-you');
  const [posts, setPosts] = useState<Post[]>([]);
  const [busy, setBusy] = useState(false);
  const [composerBusy, setComposerBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function loadFeed() {
      setBusy(true);
      setError(null);
      try {
        const response = await api.feed.list(mode);
        if (!cancelled) {
          setPosts(response.items);
        }
      } catch (nextError) {
        if (!cancelled) {
          setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить ленту.');
        }
      } finally {
        if (!cancelled) {
          setBusy(false);
        }
      }
    }

    void loadFeed();

    return () => {
      cancelled = true;
    };
  }, [mode]);

  async function handleCreatePost(payload: { content: string; imageUrl?: string }) {
    setComposerBusy(true);
    try {
      const post = await api.feed.create(payload.content, payload.imageUrl);
      setPosts((current) => [post, ...current]);
    } finally {
      setComposerBusy(false);
    }
  }

  return (
    <div className="page-grid">
      <section className="hero-card hero-card--feed">
        <div className="hero-card__eyebrow">Mishon</div>
        <h2>Лента как в приложении</h2>
        <p>
          Чистые карточки постов, быстрые реакции и комфортный просмотр на большом экране без лишних колонок.
        </p>
        <div className="segmented">
          <button
            className={mode === 'for-you' ? 'pill-button pill-button--active' : 'pill-button'}
            type="button"
            onClick={() => startTransition(() => setMode('for-you'))}
          >
            Для вас
          </button>
          <button
            className={mode === 'following' ? 'pill-button pill-button--active' : 'pill-button'}
            type="button"
            onClick={() => startTransition(() => setMode('following'))}
          >
            Подписки
          </button>
        </div>
      </section>

      <PostComposer busy={composerBusy} onSubmit={handleCreatePost} />

      {error ? <div className="error-banner">{error}</div> : null}
      {busy ? <div className="panel">Загружаем ленту...</div> : null}

      <div className="stack-list">
        {posts.map((post) => (
          <PostCard
            key={post.id}
            canDelete={post.userId === currentUserId}
            post={post}
            onDelete={async (postId) => {
              await api.feed.remove(postId);
              setPosts((current) => current.filter((item) => item.id !== postId));
            }}
            onLike={async (targetPost) => {
              const updated = await api.feed.toggleLike(targetPost.id);
              setPosts((current) => current.map((item) => (item.id === updated.id ? updated : item)));
            }}
          />
        ))}

        {!busy && posts.length === 0 ? (
          <div className="empty-card">Лента пока пустая. Опубликуйте первый пост или подпишитесь на друзей.</div>
        ) : null}
      </div>
    </div>
  );
}

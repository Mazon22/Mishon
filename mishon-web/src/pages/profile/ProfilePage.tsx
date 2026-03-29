import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { api } from '../../shared/api/api';
import { formatRelativeDate, initials } from '../../shared/lib/format';
import type { Post, Profile } from '../../shared/types/api';
import { PostCard } from '../../widgets/post/PostCard';

export function ProfilePage({ currentUserId }: { currentUserId: number }) {
  const navigate = useNavigate();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [posts, setPosts] = useState<Post[]>([]);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function loadProfile() {
      setBusy(true);
      setError(null);
      try {
        const [nextProfile, nextPosts] = await Promise.all([api.profile.get(), api.profile.posts(1, 24)]);
        if (!cancelled) {
          setProfile(nextProfile);
          setPosts(nextPosts.items);
        }
      } catch (nextError) {
        if (!cancelled) {
          setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить профиль.');
        }
      } finally {
        if (!cancelled) {
          setBusy(false);
        }
      }
    }

    void loadProfile();

    return () => {
      cancelled = true;
    };
  }, []);

  const bannerStyle = useMemo(() => {
    if (!profile?.bannerUrl) {
      return undefined;
    }

    return {
      backgroundImage: `linear-gradient(135deg, rgba(73, 128, 255, 0.28), rgba(122, 94, 255, 0.32)), url(${profile.bannerUrl})`,
    };
  }, [profile?.bannerUrl]);

  if (busy && !profile) {
    return <div className="panel">Загружаем профиль...</div>;
  }

  return (
    <div className="page-stack">
      {error ? <div className="error-banner">{error}</div> : null}

      <section className="profile-hero">
        <div className="profile-hero__banner" style={bannerStyle} />
        <div className="profile-hero__body">
          <div className="profile-hero__avatar-ring">
            <div className="avatar avatar--xl">
              {profile?.avatarUrl ? (
                <img alt={profile.username} className="avatar__image" src={profile.avatarUrl} />
              ) : (
                initials(profile?.displayName || profile?.username || 'Mi')
              )}
            </div>
          </div>

          <div className="profile-hero__meta">
            <div className="hero-card__eyebrow hero-card__eyebrow--muted">Ваш профиль</div>
            <h2>{profile?.displayName || profile?.username}</h2>
            <p>@{profile?.username}</p>
            <div className="profile-hero__about">
              {profile?.aboutMe || 'Расскажите друзьям о себе в настройках профиля.'}
            </div>
            <div className="stats-row">
              <div className="stat-chip">{profile?.followersCount ?? 0} подписчиков</div>
              <div className="stat-chip">{profile?.followingCount ?? 0} подписок</div>
              <div className="stat-chip">{profile?.postsCount ?? 0} постов</div>
              <div className="stat-chip">Онлайн: {profile?.isOnline ? 'сейчас' : formatRelativeDate(profile?.lastSeenAt)}</div>
            </div>
            <div className="profile-hero__actions">
              <button className="primary-button" type="button" onClick={() => navigate('/settings')}>
                Редактировать профиль
              </button>
            </div>
          </div>
        </div>
      </section>

      <section className="panel">
        <div className="panel__header">
          <div>
            <div className="section-title">Мои посты</div>
            <div className="section-subtitle">Личная лента, медиа и активность.</div>
          </div>
        </div>

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

          {!busy && posts.length === 0 ? <div className="empty-card">У вас еще нет постов. Самое время начать ленту.</div> : null}
        </div>
      </section>
    </div>
  );
}

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';

import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import { formatCount, formatRelativeDate } from '../../shared/lib/format';
import { buildMediaTransformStyle } from '../../shared/lib/media';
import type { FollowListEntry, Post, Profile, ProfileTimelineTab } from '../../shared/types/api';
import { AppIcon } from '../../shared/ui/AppIcon';
import { ContentTabs } from '../../shared/ui/ContentTabs';
import { UserAvatar } from '../../shared/ui/UserAvatar';
import { VerifiedBadge } from '../../shared/ui/VerifiedBadge';
import { PostCard } from '../../widgets/post/PostCard';
import { ProfileFollowSheet, type ProfileFollowSheetMode } from './components/ProfileFollowSheet';

const profileTabs: Array<{ id: ProfileTimelineTab; label: string }> = [
  { id: 'posts', label: 'Посты' },
  { id: 'media', label: 'Медиа' },
  { id: 'likes', label: 'Лайки' },
];

const tabCopy: Record<
  ProfileTimelineTab,
  {
    emptyOwn: string;
    emptyGuest: string;
    loading: string;
  }
> = {
  posts: {
    emptyOwn: 'Здесь пока нет публикаций. Первый пост сразу оживит профиль.',
    emptyGuest: 'У этого пользователя пока нет публикаций.',
    loading: 'Загружаем публикации...',
  },
  media: {
    emptyOwn: 'Медиа пока нет. Добавьте изображение в следующий пост.',
    emptyGuest: 'У этого пользователя пока нет медиа-публикаций.',
    loading: 'Загружаем медиа...',
  },
  likes: {
    emptyOwn: 'Лайкнутых публикаций пока нет.',
    emptyGuest: 'Понравившихся публикаций пока нет.',
    loading: 'Загружаем лайкнутые публикации...',
  },
};

const presenceWindowMs = 5 * 60 * 1000;

function formatLoadError(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

function pluralize(value: number, [one, few, many]: [string, string, string]) {
  const normalizedValue = Math.abs(value) % 100;
  const lastDigit = normalizedValue % 10;

  if (normalizedValue > 10 && normalizedValue < 20) {
    return many;
  }

  if (lastDigit === 1) {
    return one;
  }

  if (lastDigit >= 2 && lastDigit <= 4) {
    return few;
  }

  return many;
}

export function ProfilePage({ currentUserId }: { currentUserId: number }) {
  const navigate = useNavigate();
  const { status, subscribe } = useLiveSync();
  const params = useParams();
  const routeUserId = Number(params.userId ?? 0) || null;
  const targetUserId = routeUserId ?? currentUserId;
  const isOwnProfile = targetUserId === currentUserId;

  const profileStreamRef = useRef<HTMLElement | null>(null);

  const [activeTab, setActiveTab] = useState<ProfileTimelineTab>('posts');
  const [profile, setProfile] = useState<Profile | null>(null);
  const [posts, setPosts] = useState<Post[]>([]);
  const [profileBusy, setProfileBusy] = useState(true);
  const [tabBusy, setTabBusy] = useState(true);
  const [profileError, setProfileError] = useState<string | null>(null);
  const [tabError, setTabError] = useState<string | null>(null);
  const [followSheetMode, setFollowSheetMode] = useState<ProfileFollowSheetMode | null>(null);
  const [followSheetItems, setFollowSheetItems] = useState<FollowListEntry[]>([]);
  const [followSheetBusy, setFollowSheetBusy] = useState(false);
  const [followSheetError, setFollowSheetError] = useState<string | null>(null);
  const [presenceTick, setPresenceTick] = useState(() => Date.now());

  const loadProfile = useCallback(async () => {
    setProfileBusy(true);
    setProfileError(null);

    try {
      const nextProfile = isOwnProfile ? await api.profile.get() : await api.profile.getUser(targetUserId);
      setProfile(nextProfile);
      return nextProfile;
    } catch (error) {
      setProfile(null);
      setProfileError(formatLoadError(error, 'Не удалось загрузить профиль.'));
      return null;
    } finally {
      setProfileBusy(false);
    }
  }, [isOwnProfile, targetUserId]);

  const loadTab = useCallback(
    async (tab: ProfileTimelineTab, nextProfile: Profile) => {
      if (nextProfile.canViewPosts === false) {
        setPosts([]);
        setTabError(null);
        setTabBusy(false);
        return;
      }

      setTabBusy(true);
      setTabError(null);

      try {
        const response = await api.profile.posts({
          page: 1,
          pageSize: 24,
          tab,
          userId: targetUserId,
        });
        setPosts(response.items);
      } catch (error) {
        setPosts([]);
        setTabError(formatLoadError(error, 'Не удалось загрузить публикации профиля.'));
      } finally {
        setTabBusy(false);
      }
    },
    [targetUserId],
  );

  const loadFollowList = useCallback(
    async (mode: ProfileFollowSheetMode) => {
      setFollowSheetBusy(true);
      setFollowSheetError(null);

      try {
        const items = mode === 'followers' ? await api.friends.followers(targetUserId) : await api.friends.following(targetUserId);
        setFollowSheetItems(items);
      } catch (error) {
        setFollowSheetItems([]);
        setFollowSheetError(formatLoadError(error, 'Не удалось загрузить список.'));
      } finally {
        setFollowSheetBusy(false);
      }
    },
    [targetUserId],
  );

  useEffect(() => {
    setActiveTab('posts');
    setPosts([]);
    setProfile(null);
    setProfileError(null);
    setTabError(null);
    setProfileBusy(true);
    setTabBusy(true);
    setFollowSheetMode(null);
    setFollowSheetItems([]);
    setFollowSheetError(null);
    setFollowSheetBusy(false);
  }, [targetUserId]);

  useEffect(() => {
    void loadProfile();
  }, [loadProfile]);

  useEffect(() => {
    if (!profile) {
      return;
    }

    void loadTab(activeTab, profile);
  }, [activeTab, loadTab, profile]);

  useEffect(() => {
    if (!followSheetMode) {
      return;
    }

    void loadFollowList(followSheetMode);
  }, [followSheetMode, loadFollowList]);

  useEffect(() => {
    const timerId = window.setInterval(() => {
      setPresenceTick(Date.now());
    }, 30000);

    return () => {
      window.clearInterval(timerId);
    };
  }, []);

  useEffect(() => {
    return subscribe((event) => {
      const eventUserId = Number((event.data as { userId?: number } | undefined)?.userId ?? 0);
      const affectsTargetProfile = !eventUserId || eventUserId === targetUserId;
      const isPresenceEvent = event.type === 'presence.updated' && eventUserId === targetUserId;
      const shouldRefreshProfile =
        event.type === 'sync.resync' ||
        event.type.startsWith('post.') ||
        event.type.startsWith('comment.') ||
        event.type.startsWith('follow.') ||
        event.type.startsWith('friends.') ||
        isPresenceEvent ||
        (event.type === 'profile.updated' && affectsTargetProfile);

      if (shouldRefreshProfile) {
        void loadProfile();
      }

      if (
        followSheetMode &&
        (event.type.startsWith('follow.') ||
          event.type.startsWith('friends.') ||
          (event.type === 'profile.updated' && affectsTargetProfile))
      ) {
        void loadFollowList(followSheetMode);
      }
    });
  }, [followSheetMode, loadFollowList, loadProfile, subscribe, targetUserId]);

  const liveSyncActive = status === 'connecting' || status === 'connected' || status === 'reconnecting';
  const lastSeenAtMs = useMemo(() => {
    if (!profile?.lastSeenAt) {
      return null;
    }

    const parsed = Date.parse(profile.lastSeenAt);
    return Number.isFinite(parsed) ? parsed : null;
  }, [profile?.lastSeenAt]);

  const effectiveIsOnline = useMemo(() => {
    if (!profile) {
      return false;
    }

    if (isOwnProfile && liveSyncActive) {
      return true;
    }

    if (lastSeenAtMs === null) {
      return profile.isOnline;
    }

    return presenceTick - lastSeenAtMs <= presenceWindowMs;
  }, [isOwnProfile, lastSeenAtMs, liveSyncActive, presenceTick, profile]);

  const onlineText = useMemo(() => {
    if (!profile) {
      return 'Обновляем данные...';
    }

    return effectiveIsOnline ? 'В сети сейчас' : `Был(а) ${formatRelativeDate(profile.lastSeenAt)}`;
  }, [effectiveIsOnline, profile]);

  const joinedText = useMemo(() => {
    if (!profile) {
      return '';
    }

    return new Intl.DateTimeFormat('ru-RU', {
      month: 'long',
      year: 'numeric',
    }).format(new Date(profile.createdAt));
  }, [profile]);

  const tabInfo = tabCopy[activeTab];
  const displayName = profile?.displayName?.trim() || profile?.username || 'Mishon';
  const profileHandle = profile?.username ? `@${profile.username}` : '@mishon';
  const emptyTabText = isOwnProfile ? tabInfo.emptyOwn : tabInfo.emptyGuest;
  const isVerifiedProfile = Boolean(profile?.isVerified || profile?.emailVerified);
  const aboutText = profile?.aboutMe?.trim() || 'Добавьте пару слов о себе, чтобы профиль выглядел собранным и живым.';
  const postsHeadline = profile
    ? `${formatCount(profile.postsCount)} ${pluralize(profile.postsCount, ['пост', 'поста', 'постов'])}`
    : profileBusy
      ? 'Загружаем профиль...'
      : 'Профиль';
  const headerTitle = profile ? displayName : isOwnProfile ? 'Профиль' : 'Пользователь';
  const headerSubtitle = profileError ? 'Профиль временно недоступен' : postsHeadline;

  const applyUpdatedPost = useCallback(
    (updated: Post) => {
      setPosts((current) => {
        if (activeTab === 'media' && !updated.imageUrl) {
          return current.filter((item) => item.id !== updated.id);
        }

        if (activeTab === 'likes' && targetUserId === currentUserId && !updated.isLiked) {
          return current.filter((item) => item.id !== updated.id);
        }

        return current.map((item) => (item.id === updated.id ? updated : item));
      });
    },
    [activeTab, currentUserId, targetUserId],
  );

  async function handleToggleFollow() {
    if (!profile || isOwnProfile) {
      return;
    }

    const response = await api.friends.toggleFollow(profile.id);
    setProfile((current) =>
      current
        ? {
            ...current,
            isFollowing: response.isFollowing,
            followersCount: response.followersCount,
            hasPendingFollowRequest: response.isRequested,
          }
        : current,
    );

    if (followSheetMode === 'followers') {
      await loadFollowList('followers');
    }
  }

  async function handleAddFriend() {
    if (!profile || isOwnProfile) {
      return;
    }

    await api.friends.sendRequest(profile.id);
    await loadProfile();
  }

  function handleBackNavigation() {
    if (window.history.length > 1) {
      navigate(-1);
      return;
    }

    navigate('/feed');
  }

  function handleOpenPosts() {
    setActiveTab('posts');
    window.requestAnimationFrame(() => {
      profileStreamRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }

  function handleSelectProfileFromSheet(userId: number) {
    setFollowSheetMode(null);
    navigate(userId === currentUserId ? '/profile' : `/profile/${userId}`);
  }

  return (
    <div className="timeline timeline--profile">
      <header className="profile-page-header">
        <button
          aria-label="Назад"
          className="icon-button icon-button--ghost profile-page-header__back"
          type="button"
          onClick={handleBackNavigation}
        >
          <AppIcon className="profile-page-header__back-icon" name="chevron-right" />
        </button>

        <div className="profile-page-header__copy">
          <div className="profile-page-header__title-row">
            <strong>{headerTitle}</strong>
            <VerifiedBadge className="profile-page-header__verified" size="sm" verified={isVerifiedProfile} />
          </div>
          <span>{headerSubtitle}</span>
        </div>
      </header>

      {profileError ? <div className="error-banner timeline-banner">{profileError}</div> : null}

      {profile ? (
        <>
          <section className="profile-hero">
            <div className="profile-hero__banner">
              {profile.bannerUrl ? (
                <img
                  alt="Баннер профиля"
                  className="profile-hero__banner-image"
                  src={profile.bannerUrl}
                  style={buildMediaTransformStyle(profile.bannerScale, profile.bannerOffsetX, profile.bannerOffsetY)}
                />
              ) : (
                <div aria-hidden="true" className="profile-hero__banner-fallback" />
              )}
              <div className="profile-hero__banner-overlay" />
            </div>

            <div className="profile-hero__body">
              <div className="profile-hero__top">
                <div className="profile-hero__avatar-shell">
                  <UserAvatar
                    className="profile-hero__avatar"
                    imageUrl={profile.avatarUrl}
                    name={displayName}
                    offsetX={profile.avatarOffsetX}
                    offsetY={profile.avatarOffsetY}
                    scale={profile.avatarScale}
                    size="xxl"
                  />
                </div>
              </div>

              <div className="profile-hero__content">
                <div className="profile-hero__headline-row">
                  <div className="profile-hero__identity">
                    <div className="profile-hero__heading">
                      <div className="profile-hero__title-row">
                        <h2>{displayName}</h2>
                        <VerifiedBadge size="md" verified={isVerifiedProfile} />
                      </div>
                      <p className="profile-hero__handle">{profileHandle}</p>

                      {isOwnProfile && !isVerifiedProfile ? (
                        <button
                          className="profile-hero__verification-cta"
                          type="button"
                          onClick={() => navigate(`/verify-email/pending?email=${encodeURIComponent(profile.email)}`)}
                        >
                          Подтвердить email
                        </button>
                      ) : null}
                    </div>
                  </div>

                  <div className="profile-hero__actions">
                    {isOwnProfile ? (
                      <button
                        className="ghost-button profile-hero__action-button profile-hero__action-button--strong"
                        type="button"
                        onClick={() => navigate('/settings')}
                      >
                        Редактировать профиль
                      </button>
                    ) : (
                      <>
                        <button
                          className={[
                            profile.isFollowing || profile.hasPendingFollowRequest ? 'ghost-button' : 'primary-button',
                            'profile-hero__action-button',
                            !profile.isFollowing && !profile.hasPendingFollowRequest ? 'profile-hero__action-button--primary' : '',
                          ]
                            .filter(Boolean)
                            .join(' ')}
                          disabled={profile.hasPendingFollowRequest && !profile.isFollowing}
                          type="button"
                          onClick={() => void handleToggleFollow()}
                        >
                          {profile.isFollowing
                            ? 'Отписаться'
                            : profile.hasPendingFollowRequest
                              ? 'Запрос отправлен'
                              : 'Подписаться'}
                        </button>
                        <button
                          className="ghost-button profile-hero__action-button"
                          disabled={profile.isFriend}
                          type="button"
                          onClick={() => void handleAddFriend()}
                        >
                          {profile.isFriend ? 'У вас в друзьях' : 'В друзья'}
                        </button>
                        <button
                          className="ghost-button profile-hero__action-button"
                          disabled={profile.canSendMessages === false}
                          title={profile.canSendMessages === false ? 'Пользователь ограничил входящие сообщения' : undefined}
                          type="button"
                          onClick={() => navigate(`/chats?chatWith=${targetUserId}`)}
                        >
                          Написать
                        </button>
                      </>
                    )}
                  </div>
                </div>

                <p className={`profile-hero__about${profile.aboutMe?.trim() ? '' : ' profile-hero__about--empty'}`}>{aboutText}</p>

                <div className="profile-hero__meta">
                  <span className="profile-hero__meta-item">
                    <AppIcon className="profile-hero__meta-icon" name={effectiveIsOnline ? 'check' : 'clock'} />
                    {onlineText}
                  </span>
                  <span className="profile-hero__meta-item">
                    <AppIcon className="profile-hero__meta-icon" name={profile.isPrivateAccount ? 'lock' : 'globe'} />
                    {profile.isPrivateAccount ? 'Приватный профиль' : 'Открытый профиль'}
                  </span>
                  <span className="profile-hero__meta-item">
                    <AppIcon className="profile-hero__meta-icon" name="calendar" />
                    {joinedText ? `С нами с ${joinedText}` : 'Профиль Mishon'}
                  </span>
                </div>

                <div className="profile-hero__stats">
                  <button
                    className="profile-hero__stat profile-hero__stat--interactive"
                    type="button"
                    onClick={() => setFollowSheetMode('followers')}
                  >
                    <strong>{formatCount(profile.followersCount)}</strong>
                    <span>Подписчики</span>
                  </button>
                  <button
                    className="profile-hero__stat profile-hero__stat--interactive"
                    type="button"
                    onClick={() => setFollowSheetMode('following')}
                  >
                    <strong>{formatCount(profile.followingCount)}</strong>
                    <span>Подписки</span>
                  </button>
                  <button
                    className="profile-hero__stat profile-hero__stat--interactive"
                    type="button"
                    onClick={handleOpenPosts}
                  >
                    <strong>{formatCount(profile.postsCount)}</strong>
                    <span>Посты</span>
                  </button>
                </div>
              </div>
            </div>
          </section>

          <div className="profile-tabs-wrap">
            <ContentTabs
              ariaLabel="Вкладки профиля"
              className="profile-tabs"
              items={profileTabs.map((tab) => ({ value: tab.id, label: tab.label }))}
              value={activeTab}
              onChange={setActiveTab}
            />
          </div>

          <section ref={profileStreamRef} className="profile-stream">
            {profile.canViewPosts === false ? (
              <div className="empty-card timeline-banner profile-stream__state">Этот профиль ограничил просмотр публикаций.</div>
            ) : tabError ? (
              <div className="error-banner timeline-banner profile-stream__state">{tabError}</div>
            ) : tabBusy ? (
              <div className="empty-card timeline-banner profile-stream__state">{tabInfo.loading}</div>
            ) : posts.length === 0 ? (
              <div className="empty-card timeline-banner profile-stream__state">{emptyTabText}</div>
            ) : (
              <div className="stack-list">
                {posts.map((post) => (
                  <PostCard
                    key={post.id}
                    canDelete={post.userId === currentUserId}
                    currentUserId={currentUserId}
                    post={post}
                    onBookmark={async (targetPost) => {
                      const updated = await api.feed.toggleBookmark(targetPost.id);
                      applyUpdatedPost(updated);
                    }}
                    onDelete={async (postId) => {
                      await api.feed.remove(postId);
                      setPosts((current) => current.filter((item) => item.id !== postId));

                      if (post.userId === targetUserId) {
                        setProfile((current) =>
                          current
                            ? {
                                ...current,
                                postsCount: Math.max(0, current.postsCount - 1),
                              }
                            : current,
                        );
                      }
                    }}
                    onLike={async (targetPost) => {
                      const updated = await api.feed.toggleLike(targetPost.id);
                      applyUpdatedPost(updated);
                    }}
                    onUpdate={async (postId, payload) => {
                      const updated = await api.feed.update(postId, payload.content, payload.imageUrl);
                      applyUpdatedPost(updated);
                      return updated;
                    }}
                  />
                ))}
              </div>
            )}
          </section>

          <ProfileFollowSheet
            busy={followSheetBusy}
            error={followSheetError}
            items={followSheetItems}
            mode={followSheetMode ?? 'followers'}
            open={followSheetMode !== null}
            profileName={displayName}
            onClose={() => setFollowSheetMode(null)}
            onSelect={handleSelectProfileFromSheet}
          />
        </>
      ) : profileBusy ? (
        <section className="profile-stream">
          <div className="empty-card timeline-banner profile-stream__state">Загружаем профиль...</div>
        </section>
      ) : null}
    </div>
  );
}

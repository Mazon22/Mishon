import { startTransition, useCallback, useDeferredValue, useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';

import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import { formatRelativeDate } from '../../shared/lib/format';
import type { FriendCard, FriendRequestItem, FriendRequestsPayload } from '../../shared/types/api';
import { AppIcon } from '../../shared/ui/AppIcon';
import { PeopleRow } from './components/PeopleRow';
import { PeopleTabs, type PeopleTab } from './components/PeopleTabs';

async function fetchFriendsData(query: string) {
  const [nextFriends, nextRequests, nextDiscover] = await Promise.all([
    api.friends.list(),
    api.friends.requests(),
    api.friends.discover(query, 1, 18),
  ]);

  return {
    friends: nextFriends,
    requests: nextRequests,
    discover: nextDiscover.items,
  };
}

function matchesQuery(query: string, ...parts: Array<string | null | undefined>) {
  if (!query) {
    return true;
  }

  const haystack = parts.filter(Boolean).join(' ').toLowerCase();
  return haystack.includes(query);
}

function getFriendMeta(friend: FriendCard) {
  return friend.aboutMe || `${friend.followersCount} подписчиков · ${friend.postsCount} постов`;
}

export function FriendsPage() {
  const navigate = useNavigate();
  const { subscribe } = useLiveSync();
  const [searchParams, setSearchParams] = useSearchParams();
  const initialQuery = searchParams.get('query') ?? '';
  const initialTab = (searchParams.get('tab') as PeopleTab | null) ?? 'for-you';
  const [friends, setFriends] = useState<FriendCard[]>([]);
  const [requests, setRequests] = useState<FriendRequestsPayload>({ incoming: [], outgoing: [] });
  const [discover, setDiscover] = useState<FriendCard[]>([]);
  const [query, setQuery] = useState(initialQuery);
  const [tab, setTab] = useState<PeopleTab>(initialTab);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const deferredQuery = useDeferredValue(query);
  const normalizedQuery = deferredQuery.trim().toLowerCase();

  useEffect(() => {
    setQuery(initialQuery);
  }, [initialQuery]);

  useEffect(() => {
    setTab(initialTab);
  }, [initialTab]);

  const refreshLists = useCallback(
    async (silent = false) => {
      if (!silent) {
        setBusy(true);
      }

      try {
        const payload = await fetchFriendsData(deferredQuery);
        setFriends(payload.friends);
        setRequests(payload.requests);
        setDiscover(payload.discover);
        if (!silent) {
          setError(null);
        }
      } catch (nextError) {
        if (!silent) {
          setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить раздел людей.');
        }
      } finally {
        if (!silent) {
          setBusy(false);
        }
      }
    },
    [deferredQuery],
  );

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setBusy(true);
      setError(null);

      try {
        const payload = await fetchFriendsData(deferredQuery);
        if (!cancelled) {
          setFriends(payload.friends);
          setRequests(payload.requests);
          setDiscover(payload.discover);
        }
      } catch (nextError) {
        if (!cancelled) {
          setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить раздел людей.');
        }
      } finally {
        if (!cancelled) {
          setBusy(false);
        }
      }
    }

    setSearchParams(
      (current) => {
        const next = new URLSearchParams(current);

        if (deferredQuery.trim()) {
          next.set('query', deferredQuery.trim());
        } else {
          next.delete('query');
        }

        if (tab !== 'for-you') {
          next.set('tab', tab);
        } else {
          next.delete('tab');
        }

        return next;
      },
      { replace: true },
    );

    void load();

    return () => {
      cancelled = true;
    };
  }, [deferredQuery, setSearchParams, tab]);

  useEffect(() => {
    return subscribe((event) => {
      if (
        event.type === 'friends.changed' ||
        event.type === 'follow.changed' ||
        event.type === 'profile.updated' ||
        event.type === 'sync.resync'
      ) {
        void refreshLists(true);
      }
    });
  }, [refreshLists, subscribe]);

  const visibleIncomingRequests = useMemo(
    () =>
      requests.incoming.filter((item) =>
        matchesQuery(normalizedQuery, item.user.displayName, item.user.username, item.aboutMe),
      ),
    [normalizedQuery, requests.incoming],
  );

  const visibleOutgoingRequests = useMemo(
    () =>
      requests.outgoing.filter((item) =>
        matchesQuery(normalizedQuery, item.user.displayName, item.user.username, item.aboutMe),
      ),
    [normalizedQuery, requests.outgoing],
  );

  const visibleFriends = useMemo(
    () =>
      friends.filter((friend) =>
        matchesQuery(normalizedQuery, friend.displayName, friend.username, friend.aboutMe),
      ),
    [friends, normalizedQuery],
  );

  const visibleDiscover = useMemo(
    () =>
      discover.filter((friend) =>
        matchesQuery(normalizedQuery, friend.displayName, friend.username, friend.aboutMe),
      ),
    [discover, normalizedQuery],
  );

  function openProfile(userId: number) {
    startTransition(() => navigate(`/profile/${userId}`));
  }

  function renderEmpty(text: string) {
    return <div className="people-empty">{text}</div>;
  }

  function renderRequestRows(items: FriendRequestItem[], kind: 'incoming' | 'outgoing') {
    return (
      <div className="people-stack">
        {items.map((item) => (
          <PeopleRow
            key={`${kind}-${item.id}`}
            actions={
              kind === 'incoming'
                ? [
                    {
                      label: 'Принять',
                      tone: 'primary',
                      onClick: () => api.friends.acceptRequest(item.id).then(() => refreshLists(true)),
                    },
                    {
                      label: 'Отклонить',
                      tone: 'secondary',
                      onClick: () => api.friends.deleteRequest(item.id).then(() => refreshLists(true)),
                    },
                  ]
                : [
                    {
                      label: 'Отменить',
                      tone: 'secondary',
                      onClick: () => api.friends.deleteRequest(item.id).then(() => refreshLists(true)),
                    },
                  ]
            }
            eyebrow={kind === 'incoming' ? 'Входящий запрос' : 'Исходящий запрос'}
            meta={item.aboutMe || (kind === 'incoming' ? 'Ожидает вашего решения' : 'Ждёт ответа')}
            onOpen={() => openProfile(item.user.id)}
            person={item.user}
            trailing={formatRelativeDate(item.createdAt)}
          />
        ))}
      </div>
    );
  }

  function renderFriendRows(items: FriendCard[]) {
    return (
      <div className="people-stack">
        {items.map((friend) => (
          <PeopleRow
            key={friend.id}
            actions={[
              {
                label: 'Написать',
                tone: 'secondary',
                onClick: () => startTransition(() => navigate(`/chats?chatWith=${friend.id}`)),
              },
              {
                label: 'Удалить',
                tone: 'secondary',
                onClick: () => api.friends.remove(friend.id).then(() => refreshLists(true)),
              },
            ]}
            meta={getFriendMeta(friend)}
            onOpen={() => openProfile(friend.id)}
            person={friend}
            trailing={friend.isOnline ? 'Онлайн' : formatRelativeDate(friend.lastSeenAt)}
          />
        ))}
      </div>
    );
  }

  function renderDiscoverRows(items: FriendCard[]) {
    return (
      <div className="people-stack">
        {items.map((person) => (
          <PeopleRow
            key={person.id}
            actions={[
              {
                label: person.isFollowing
                  ? 'Читаете'
                  : person.hasPendingFollowRequest
                    ? 'Запрос отправлен'
                    : 'Читать',
                tone: person.isFollowing ? 'secondary' : 'primary',
                onClick: () => api.friends.toggleFollow(person.id).then(() => refreshLists(true)),
              },
              {
                label: person.outgoingFriendRequestId ? 'В ожидании' : 'В друзья',
                tone: 'secondary',
                disabled: Boolean(person.outgoingFriendRequestId),
                onClick: () => api.friends.sendRequest(person.id).then(() => refreshLists(true)),
              },
            ]}
            meta={getFriendMeta(person)}
            onOpen={() => openProfile(person.id)}
            person={person}
            trailing={person.isPrivateAccount ? 'Приватный' : 'Открытый'}
          />
        ))}
      </div>
    );
  }

  function renderForYouTab() {
    const hasAnything =
      visibleIncomingRequests.length > 0 || visibleDiscover.length > 0 || visibleFriends.length > 0;

    if (!hasAnything) {
      return renderEmpty(normalizedQuery ? 'Никого не найдено по вашему запросу.' : 'Пока здесь тихо. Попробуйте поиск.');
    }

    return (
      <div className="people-content">
        {visibleIncomingRequests.length > 0 ? (
          <section className="people-section">
            <header className="people-section__header">
              <div>
                <h2>Запросы для вас</h2>
                <p>Люди, которые ждут вашего решения.</p>
              </div>
            </header>
            {renderRequestRows(visibleIncomingRequests, 'incoming')}
          </section>
        ) : null}

        {visibleDiscover.length > 0 ? (
          <section className="people-section">
            <header className="people-section__header">
              <div>
                <h2>{normalizedQuery ? 'Результаты поиска' : 'Подобрано для вас'}</h2>
                <p>
                  {normalizedQuery
                    ? 'Подходящие профили по вашему запросу.'
                    : 'Интересные люди, которых можно быстро читать или добавить.'}
                </p>
              </div>
            </header>
            {renderDiscoverRows(normalizedQuery ? visibleDiscover : visibleDiscover.slice(0, 10))}
          </section>
        ) : null}

        {!normalizedQuery && visibleFriends.length > 0 ? (
          <section className="people-section">
            <header className="people-section__header">
              <div>
                <h2>Ваш круг</h2>
                <p>Люди, с которыми вы уже на связи.</p>
              </div>
            </header>
            {renderFriendRows(visibleFriends.slice(0, 4))}
          </section>
        ) : null}
      </div>
    );
  }

  function renderTabContent() {
    if (busy) {
      return renderEmpty('Загружаем людей…');
    }

    switch (tab) {
      case 'requests':
        if (!visibleIncomingRequests.length && !visibleOutgoingRequests.length) {
          return renderEmpty('Здесь появятся входящие и исходящие запросы.');
        }

        return (
          <div className="people-content">
            {visibleIncomingRequests.length > 0 ? (
              <section className="people-section">
                <header className="people-section__header">
                  <div>
                    <h2>Входящие</h2>
                    <p>Люди, которые хотят добавить вас.</p>
                  </div>
                </header>
                {renderRequestRows(visibleIncomingRequests, 'incoming')}
              </section>
            ) : null}

            {visibleOutgoingRequests.length > 0 ? (
              <section className="people-section">
                <header className="people-section__header">
                  <div>
                    <h2>Исходящие</h2>
                    <p>Запросы, которые ещё ждут ответа.</p>
                  </div>
                </header>
                {renderRequestRows(visibleOutgoingRequests, 'outgoing')}
              </section>
            ) : null}
          </div>
        );
      case 'friends':
        return visibleFriends.length > 0 ? (
          <div className="people-content">
            <section className="people-section">
              <header className="people-section__header">
                <div>
                  <h2>Ваши люди</h2>
                  <p>Друзья и быстрый вход в диалог.</p>
                </div>
              </header>
              {renderFriendRows(visibleFriends)}
            </section>
          </div>
        ) : (
          renderEmpty('Пока нет друзей. Найдите людей в рекомендациях.')
        );
      case 'discover':
        return visibleDiscover.length > 0 ? (
          <div className="people-content">
            <section className="people-section">
              <header className="people-section__header">
                <div>
                  <h2>Можно добавить</h2>
                  <p>Подборка профилей для расширения круга общения.</p>
                </div>
              </header>
              {renderDiscoverRows(visibleDiscover)}
            </section>
          </div>
        ) : (
          renderEmpty('По вашему запросу никого не найдено.')
        );
      default:
        return renderForYouTab();
    }
  }

  return (
    <div className="timeline people-page">
      <header className="people-page__top">
        <div className="people-page__search">
          <AppIcon className="people-page__search-icon" name="search" />
          <input
            className="people-page__search-input"
            value={query}
            placeholder="Поиск по имени или @username"
            onChange={(event) => setQuery(event.target.value)}
          />
        </div>

        <PeopleTabs value={tab} onChange={setTab} />
      </header>

      {error ? <div className="error-banner timeline-banner">{error}</div> : null}

      {renderTabContent()}
    </div>
  );
}

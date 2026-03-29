import { startTransition, useDeferredValue, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { api } from '../../shared/api/api';
import { formatRelativeDate, initials } from '../../shared/lib/format';
import type { FriendCard, FriendRequestsPayload } from '../../shared/types/api';

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

export function FriendsPage() {
  const navigate = useNavigate();
  const [friends, setFriends] = useState<FriendCard[]>([]);
  const [requests, setRequests] = useState<FriendRequestsPayload>({ incoming: [], outgoing: [] });
  const [discover, setDiscover] = useState<FriendCard[]>([]);
  const [query, setQuery] = useState('');
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const deferredQuery = useDeferredValue(query);

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
          setError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить друзей и запросы.');
        }
      } finally {
        if (!cancelled) {
          setBusy(false);
        }
      }
    }

    void load();

    return () => {
      cancelled = true;
    };
  }, [deferredQuery]);

  async function refreshLists() {
    const payload = await fetchFriendsData(deferredQuery);
    setFriends(payload.friends);
    setRequests(payload.requests);
    setDiscover(payload.discover);
  }

  return (
    <div className="page-stack">
      <section className="hero-card hero-card--friends">
        <div className="hero-card__eyebrow">Mishon</div>
        <h2>Друзья и знакомства</h2>
        <p>Запросы, текущие друзья и поиск новых людей в одном месте, как в мобильном Mishon.</p>
        <div className="hero-card__metrics">
          <div className="hero-card__metric">
            <strong>{requests.incoming.length}</strong>
            <span>входящих запросов</span>
          </div>
          <div className="hero-card__metric">
            <strong>{friends.length}</strong>
            <span>друзей</span>
          </div>
          <div className="hero-card__metric">
            <strong>{discover.length}</strong>
            <span>людей в поиске</span>
          </div>
        </div>
      </section>

      <section className="panel">
        <div className="panel__header">
          <div>
            <div className="section-title">Поиск людей</div>
            <div className="section-subtitle">Найдите человека по username или имени.</div>
          </div>
        </div>
        <input
          className="input"
          value={query}
          placeholder="Поиск по username или имени"
          onChange={(event) => setQuery(event.target.value)}
        />
      </section>

      {error ? <div className="error-banner">{error}</div> : null}
      {busy ? <div className="panel">Загружаем друзей и запросы...</div> : null}

      <section className="panel">
        <div className="panel__header">
          <div>
            <div className="section-title">Запросы в друзья</div>
            <div className="section-subtitle">Входящие запросы, которые ждут вашего ответа.</div>
          </div>
        </div>
        <div className="stack-list">
          {requests.incoming.map((item) => (
            <div key={item.id} className="person-card">
              <div className="avatar">
                {item.user.avatarUrl ? (
                  <img alt={item.user.username} className="avatar__image" src={item.user.avatarUrl} />
                ) : (
                  initials(item.user.displayName || item.user.username)
                )}
              </div>
              <div className="person-card__meta">
                <div className="person-card__title">{item.user.displayName || item.user.username}</div>
                <div className="person-card__caption">Запрос отправлен {formatRelativeDate(item.createdAt)}</div>
              </div>
              <div className="person-card__actions">
                <button
                  className="primary-button"
                  type="button"
                  onClick={() => void api.friends.acceptRequest(item.id).then(() => refreshLists())}
                >
                  Принять
                </button>
                <button
                  className="ghost-button"
                  type="button"
                  onClick={() => void api.friends.deleteRequest(item.id).then(() => refreshLists())}
                >
                  Отклонить
                </button>
              </div>
            </div>
          ))}
          {!busy && requests.incoming.length === 0 ? <div className="empty-card">Новых запросов пока нет.</div> : null}
        </div>
      </section>

      <section className="panel">
        <div className="panel__header">
          <div>
            <div className="section-title">Ваши друзья</div>
            <div className="section-subtitle">Быстрый переход к диалогу и управлению контактами.</div>
          </div>
        </div>
        <div className="stack-list">
          {friends.map((friend) => (
            <div key={friend.id} className="person-card">
              <div className="avatar">
                {friend.avatarUrl ? (
                  <img alt={friend.username} className="avatar__image" src={friend.avatarUrl} />
                ) : (
                  initials(friend.displayName || friend.username)
                )}
              </div>
              <div className="person-card__meta">
                <div className="person-card__title">{friend.displayName || friend.username}</div>
                <div className="person-card__caption">
                  {friend.aboutMe || `${friend.followersCount} подписчиков • ${friend.postsCount} постов`}
                </div>
              </div>
              <div className="person-card__actions">
                <button
                  className="ghost-button"
                  type="button"
                  onClick={() => startTransition(() => navigate(`/chats?chatWith=${friend.id}`))}
                >
                  Написать
                </button>
                <button
                  className="ghost-button"
                  type="button"
                  onClick={() => void api.friends.remove(friend.id).then(() => refreshLists())}
                >
                  Удалить
                </button>
              </div>
            </div>
          ))}
          {!busy && friends.length === 0 ? (
            <div className="empty-card">Пока нет друзей. Найдите людей ниже и отправьте запрос.</div>
          ) : null}
        </div>
      </section>

      <section className="panel">
        <div className="panel__header">
          <div>
            <div className="section-title">Возможно, вы знакомы</div>
            <div className="section-subtitle">Подписывайтесь и отправляйте запросы прямо из поиска.</div>
          </div>
        </div>
        <div className="discover-grid">
          {discover.map((person) => (
            <div key={person.id} className="discover-card">
              <div className="avatar avatar--large">
                {person.avatarUrl ? (
                  <img alt={person.username} className="avatar__image" src={person.avatarUrl} />
                ) : (
                  initials(person.displayName || person.username)
                )}
              </div>
              <div className="discover-card__name">{person.displayName || person.username}</div>
              <div className="discover-card__caption">@{person.username}</div>
              <div className="discover-card__caption">
                {person.followersCount} подписчиков • {person.postsCount} постов
              </div>
              <div className="discover-card__actions">
                <button
                  className="ghost-button"
                  type="button"
                  onClick={() => void api.friends.toggleFollow(person.id).then(() => refreshLists())}
                >
                  {person.isFollowing
                    ? 'Отписаться'
                    : person.hasPendingFollowRequest
                      ? 'Запрос отправлен'
                      : 'Подписаться'}
                </button>
                <button
                  className="primary-button"
                  disabled={Boolean(person.outgoingFriendRequestId)}
                  type="button"
                  onClick={() => void api.friends.sendRequest(person.id).then(() => refreshLists())}
                >
                  {person.outgoingFriendRequestId ? 'Запрос отправлен' : 'В друзья'}
                </button>
              </div>
            </div>
          ))}
          {!busy && discover.length === 0 ? (
            <div className="empty-card">По вашему запросу никого не найдено. Попробуйте другое имя или username.</div>
          ) : null}
        </div>
      </section>
    </div>
  );
}

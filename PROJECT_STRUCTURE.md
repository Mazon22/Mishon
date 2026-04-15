# Project Structure

Этот файл описывает актуальную структуру репозитория Mishon после перехода на единый Go backend и добавления live-sync слоя.

## Корень репозитория

- `mishon-go-api/` — основной backend
- `mishon-web/` — desktop-first сайт
- `mishon_app/` — Flutter mobile и Flutter Web
- `README.md` — запуск, архитектура и быстрая проверка
- `PROJECT_STRUCTURE.md` — эта карта проекта
- `ROADMAP.md` — дальнейшие этапы развития

## `mishon-go-api/`

Серверная часть, которая обслуживает сайт, mobile API, SSE sync и раздачу статических файлов.

- `cmd/mishon-go-api/main.go` — точка входа
- `internal/config/config.go` — конфиг окружения, JWT, DB, CORS и пути
- `internal/app/core.go` — базовый router, auth, профиль и web API
- `internal/app/feed.go` — посты, лента, лайки, комментарии
- `internal/app/chats.go` — список диалогов и базовые chat query
- `internal/app/friends_notifications.go` — друзья, follows, notifications, discover
- `internal/app/mobile_routes.go` — mobile-compatible роуты `/api`
- `internal/app/mobile_types.go` — DTO mobile-compatible API
- `internal/app/mobile_compat.go` — mobile handlers и адаптеры
- `internal/app/sync.go` — SSE broker, replay, dedup и live event stream
- `internal/app/static.go` — раздача сайта и `/uploads`
- `internal/app/media.go` — нормализация и раздача media URL

## `mishon-web/`

Сайт на React + TypeScript, ориентированный на desktop UX.

- `package.json` — зависимости и команды
- `vite.config.ts` — сборка и dev-настройки
- `src/main.tsx` — bootstrap frontend

### `mishon-web/src/app/`

Каркас приложения.

- `App.tsx` — корневой слой
- `providers/AppProviders.tsx` — сборка всех provider-слоев
- `providers/AuthContext.tsx` — auth state
- `providers/ThemeContext.tsx` — тема
- `providers/LiveSyncContext.tsx` — web live-sync stream
- `providers/live-sync-context.ts` — типы live-sync
- `providers/useAuth.ts` — auth hook
- `providers/useTheme.ts` — theme hook
- `providers/useLiveSync.ts` — live-sync hook
- `router/AppRouter.tsx` — маршруты и lazy pages
- `router/ProtectedRoute.tsx` — защита приватных страниц
- `styles/` — Sass design system и layout-слой

### `mishon-web/src/pages/`

Страницы верхнего уровня.

- `pages/login/LoginPage.tsx` — вход и регистрация
- `pages/feed/FeedPage.tsx` — основная лента
- `pages/chats/ChatsPage.tsx` — чаты и сообщения
- `pages/friends/FriendsPage.tsx` — люди, друзья, заявки, discover
- `pages/notifications/NotificationsPage.tsx` — уведомления
- `pages/profile/ProfilePage.tsx` — собственный и чужие профили
- `pages/settings/SettingsPage.tsx` — тема, профиль, privacy, sessions, blocked users

### `mishon-web/src/widgets/`

Переиспользуемые UI-блоки.

- `widgets/shell/` — shell, sidebar, right rail, search, trends, recommendations
- `widgets/feed/` — header и tabs ленты
- `widgets/post/` — composer, post card, media, actions, comments

### `mishon-web/src/shared/`

Общие типы, API и утилиты.

- `shared/api/core/` — http client, session, error handling, normalizers
- `shared/api/domains/` — доменные API для auth/feed/profile/chats/friends/notifications
- `shared/lib/` — форматирование, media helpers, chat content helpers
- `shared/types/api.ts` — контракты frontend API

## `mishon_app/`

Flutter-клиент для телефона и web mobile.

- `lib/main.dart` — точка входа
- `pubspec.yaml` — зависимости
- `android/` — Android host project
- `web/` — Flutter Web оболочка

### `mishon_app/lib/core/`

Общая инфраструктура приложения.

- `constants/` — базовые URL и константы API
- `network/` — Dio client, API service, exceptions
- `repositories/` — auth, posts, social и cache-слои
- `providers/` — bootstrap, auth session events, connection state
- `sync/live_sync_service.dart` — Flutter live-sync слой поверх SSE
- `sync/app_live_sync_bootstrap.dart` — глобальная реакция приложения на sync events
- `router/` — маршруты приложения
- `theme/` — темы и токены
- `widgets/` — общие UI-виджеты
- `utils/` — media, external URL, device metadata и вспомогательные функции

### `mishon_app/lib/features/`

Функциональные модули.

- `auth/` — auth flow, onboarding, verification UI
- `feed/` — лента и посты
- `post/` — создание постов
- `comments/` — комментарии и discussion thread
- `chats/` — диалоги, сообщения и realtime adapters
- `friends/` — друзья и заявки
- `people/` — поиск и discover
- `notifications/` — уведомления и summary
- `profile/` — профиль, privacy, sessions

## Как всё связано

1. `mishon-go-api` хранит единую бизнес-логику и публикует sync events.
2. `mishon-web` работает через `/api/v1` и live stream `/api/v1/sync/stream`.
3. `mishon_app` работает через `/api` и live stream `/api/sync/stream`.
4. Оба клиента используют одну базу данных, один backend и согласованные модели данных.
5. При reconnect клиенты выполняют повторную синхронизацию и актуализируют counters, ленты, чаты и профиль.

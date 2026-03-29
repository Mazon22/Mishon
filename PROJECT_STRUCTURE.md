# Project Structure

Этот файл описывает актуальную структуру репозитория Mishon после перехода на единый backend на Go.

## Корень репозитория

- `mishon-go-api/` - основной backend
- `mishon-web/` - веб-клиент для ПК
- `mishon_app/` - мобильное приложение и Flutter Web
- `.gitignore` - правила игнорирования файлов
- `README.md` - общее описание проекта и команды запуска
- `PROJECT_STRUCTURE.md` - этот файл
- `ROADMAP.md` - дорожная карта проекта

## `mishon-go-api/`

Серверная часть, которая обслуживает и сайт, и мобильное приложение.

- `.env.example` - пример переменных окружения
- `go.mod`, `go.sum` - модуль и lock-файл зависимостей
- `README.md` - краткое описание backend
- `cmd/mishon-go-api/main.go` - точка входа сервера
- `internal/config/config.go` - конфигурация сервера, JWT, БД и путей
- `internal/app/core.go` - базовая логика API, auth и основной router
- `internal/app/feed.go` - лента, посты, лайки и комментарии
- `internal/app/chats.go` - чаты и сообщения
- `internal/app/friends_notifications.go` - друзья, подписки, discover и уведомления
- `internal/app/mobile_compat.go` - совместимый API для Flutter-клиента
- `internal/app/static.go` - раздача собранного сайта и файлов из uploads

## `mishon-web/`

Основной сайт Mishon на React + TypeScript.

- `package.json` - зависимости и команды
- `vite.config.ts` - конфигурация Vite и proxy до Go backend
- `index.html` - HTML entrypoint
- `public/` - публичные статические файлы
- `src/main.tsx` - bootstrap приложения

### `mishon-web/src/app/`

Ядро frontend-приложения.

- `App.tsx` - верхний уровень приложения
- `providers/AppProviders.tsx` - сборка всех провайдеров
- `providers/AuthContext.tsx` - auth provider
- `providers/ThemeContext.tsx` - theme provider
- `providers/auth-context.ts` - контекст и типы авторизации
- `providers/theme-context.ts` - контекст и типы темы
- `providers/useAuth.ts` - хук для auth context
- `providers/useTheme.ts` - хук для theme context
- `router/AppRouter.tsx` - маршрутизация страниц
- `router/ProtectedRoute.tsx` - защита приватных разделов
- `styles/index.scss` - главный Sass entrypoint
- `styles/_tokens.scss` - переменные и токены интерфейса
- `styles/_base.scss` - базовые стили
- `styles/_chrome.scss` - layout, shell и topbar
- `styles/_components.scss` - стили повторно используемых UI-блоков
- `styles/_responsive.scss` - адаптивные правила

### `mishon-web/src/pages/`

Страницы верхнего уровня.

- `pages/login/LoginPage.tsx` - вход и регистрация
- `pages/feed/FeedPage.tsx` - главная лента
- `pages/chats/ChatsPage.tsx` - чаты
- `pages/friends/FriendsPage.tsx` - друзья, заявки и поиск людей
- `pages/notifications/NotificationsPage.tsx` - уведомления
- `pages/profile/ProfilePage.tsx` - профиль
- `pages/settings/SettingsPage.tsx` - настройки

### `mishon-web/src/widgets/`

Повторно используемые визуальные блоки.

- `widgets/shell/AppShell.tsx` - каркас приложения и навигация
- `widgets/post/PostCard.tsx` - карточка поста
- `widgets/post/PostComposer.tsx` - создание поста

### `mishon-web/src/shared/`

Общие модули.

- `shared/api/api.ts` - axios-клиент и вызовы backend API
- `shared/lib/chatContent.ts` - форматирование chat content
- `shared/lib/format.ts` - форматирование дат и текста
- `shared/types/api.ts` - типы API

## `mishon_app/`

Flutter-клиент Mishon.

- `pubspec.yaml` - зависимости и конфигурация Flutter
- `android/` - Android host project
- `web/` - оболочка Flutter Web
- `lib/main.dart` - точка входа приложения
- `test/` - тесты

### `mishon_app/lib/core/`

Общая инфраструктура приложения.

- `constants/` - URL API и базовые константы
- `network/` - клиент API и сетевой слой
- `repositories/` - repositories приложения
- `router/` - маршрутизация
- `theme/` - тема и дизайн-токены
- `widgets/` - общие виджеты
- `utils/` - вспомогательные инструменты, вложения и voice notes

### `mishon_app/lib/features/`

Функциональные модули.

- `auth/` - вход, регистрация и onboarding
- `feed/` - лента
- `post/` - создание постов
- `comments/` - комментарии
- `chats/` - чаты и сообщения
- `friends/` - друзья
- `people/` - поиск и discover
- `notifications/` - уведомления
- `profile/` - профиль, приватность и связанные экраны

## Как всё связано

1. `mishon-web` собирается в production build.
2. `mishon-go-api` раздаёт этот build как сайт.
3. `mishon_app` работает с тем же backend через mobile-compatible API.
4. И сайт, и мобильное приложение используют одну серверную логику и одну модель данных.

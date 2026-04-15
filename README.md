# Mishon

Mishon — социальная платформа, в которой сайт и мобильное приложение работают на одном Go backend, используют общую модель данных и синхронизируются без ручной перезагрузки.

## Что внутри

- `mishon-go-api/` — единый backend на Go
- `mishon-web/` — сайт на React + TypeScript
- `mishon_app/` — мобильное приложение на Flutter и его web-версия

## Архитектура

Проект построен вокруг одного backend:

- web API обслуживается по `/api/v1`
- mobile-compatible API обслуживается по `/api`
- live-sync поток событий работает по `/api/v1/sync/stream` и `/api/sync/stream`
- собранный сайт раздается самим Go сервером
- загруженные медиа раздаются из `/uploads`

За счет этого сайт и телефон получают одинаковые данные, одинаковые сущности и близкое по поведению обновление интерфейса.

## Что уже реализовано

- единая авторизация и работа с JWT
- лента постов, лайки, комментарии и публикация с медиа
- профили, аватарки, баннеры, приватность и сессии
- друзья, подписки, заявки и discover
- уведомления и счетчики
- чаты, reply, forward, edit, delete, delete-for-all, saved messages
- live sync между web и mobile через SSE и fallback-механики

## Быстрый запуск

### 1. Собрать сайт

```powershell
cd C:\Users\Michael\Desktop\Mishon\mishon-web
npm install
npm run build
```

### 2. Запустить backend

Если вы в `cmd.exe`:

```cmd
cd C:\Users\Michael\Desktop\Mishon\mishon-go-api
set "DATABASE_URL=postgres://postgres:ВАШ_ПАРОЛЬ@localhost:5432/mishon?sslmode=disable"
set "JWT_KEY=ваш-длинный-секрет-минимум-32-символа"
go run .\cmd\mishon-go-api\
```

Если вы в PowerShell:

```powershell
cd C:\Users\Michael\Desktop\Mishon\mishon-go-api
$env:DATABASE_URL = "postgres://postgres:ВАШ_ПАРОЛЬ@localhost:5432/mishon?sslmode=disable"
$env:JWT_KEY = "ваш-длинный-секрет-минимум-32-символа"
go run .\cmd\mishon-go-api\
```

После этого сайт будет доступен по адресу:

- [http://localhost:8081](http://localhost:8081)

### 3. Запустить web-версию мобильного приложения

```powershell
cd C:\Users\Michael\Desktop\Mishon\mishon_app
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8081/api
```

Flutter Web будет доступен по адресу:

- [http://localhost:3000](http://localhost:3000)

### 4. Запустить Android-приложение

```powershell
cd C:\Users\Michael\Desktop\Mishon\mishon_app
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api
```

## Проверка проекта

### Backend

```powershell
cd C:\Users\Michael\Desktop\Mishon\mishon-go-api
go build ./...
```

### Web

```powershell
cd C:\Users\Michael\Desktop\Mishon\mishon-web
npm run lint
npm run build
```

### Flutter

```powershell
cd C:\Users\Michael\Desktop\Mishon\mishon_app
flutter analyze
flutter build web
```

## Как работает синхронизация

- Go backend публикует события в SSE stream
- сайт подписывается на `/api/v1/sync/stream`
- мобильное приложение подписывается на `/api/sync/stream`
- при потере соединения клиенты переподключаются
- при reconnection выполняется повторная синхронизация состояния
- там, где realtime не нужен или временно недоступен, используется мягкий fallback через refetch и polling

Это позволяет без ручного refresh видеть:

- новые сообщения
- новые посты
- лайки и комментарии
- уведомления и unread counters
- изменения профиля
- изменения друзей и подписок

## Важно

- основной backend проекта — `mishon-go-api`
- отдельный backend для сайта больше не нужен
- web и mobile используют одну серверную модель
- стили сайта работают через Sass
- live-sync слой добавлен и в web, и в Flutter-клиент

## Документация

- подробная карта проекта: [PROJECT_STRUCTURE.md](/Users/Michael/Desktop/Mishon/PROJECT_STRUCTURE.md)
- план развития: [ROADMAP.md](/Users/Michael/Desktop/Mishon/ROADMAP.md)

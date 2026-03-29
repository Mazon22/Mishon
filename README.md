# Mishon

Mishon - это социальная платформа, в которой сайт и мобильное приложение работают на одном backend.

В проекте нет раздвоенной серверной логики: один backend на Go обслуживает веб-версию, Flutter Web и мобильное приложение. Это делает разработку чище, поддержку проще, а поведение продукта - предсказуемым на всех платформах.

## Из чего состоит проект

- `mishon-go-api` - единый backend на Go
- `mishon-web` - веб-клиент для больших экранов на React + TypeScript
- `mishon_app` - мобильное приложение на Flutter и его web-версия

## Что уже есть

- единая серверная архитектура для web и mobile
- аутентификация на JWT
- лента постов, лайки и комментарии
- чаты и уведомления
- друзья, подписки и поиск людей
- светлая и тёмная темы
- раздача собранного сайта и медиа напрямую через backend

## Архитектурная идея

Сайт и мобильное приложение используют одну и ту же базу данных и один backend.

`mishon-go-api` отвечает сразу за несколько задач:

- отдает web API по пути `/api/v1`
- отдает mobile-compatible API по пути `/api`
- раздает собранный сайт из `mishon-web/dist`
- отдает загруженные файлы из `/uploads`

За счет этого проект остаётся цельным: фронтенды разделены по технологиям, но опираются на одну серверную основу.

## Технологии

- Go
- PostgreSQL
- React
- TypeScript
- Vite
- Sass
- Flutter
- Riverpod
- GoRouter

## Структура репозитория

- `mishon-go-api/` - серверная часть
- `mishon-web/` - основной сайт
- `mishon_app/` - мобильный клиент
- `PROJECT_STRUCTURE.md` - подробная карта проекта
- `ROADMAP.md` - дальнейшие планы развития

## Быстрый запуск

### 1. Сборка сайта

```powershell
cd .\mishon-web\
npm install
npm run build
```

### 2. Запуск backend

```powershell
cd .\mishon-go-api\
$env:DATABASE_URL = "postgres://postgres:CHANGE_ME@localhost:5432/mishon?sslmode=disable"
$env:JWT_KEY = "replace-with-a-long-random-secret-at-least-32-characters"
go run .\cmd\mishon-go-api\
```

После запуска сайт будет доступен по адресу:

- [http://localhost:8081](http://localhost:8081)

### 3. Запуск web-версии мобильного приложения

```powershell
cd .\mishon_app\
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8081/api
```

Flutter Web будет доступен по адресу:

- [http://localhost:3000](http://localhost:3000)

### 4. Запуск Android-приложения

```powershell
cd .\mishon_app\
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api
```

## Проверка проекта

### Веб-клиент

```powershell
cd .\mishon-web\
npm run lint
npm run build
```

### Backend

```powershell
cd .\mishon-go-api\
go build ./...
```

### Flutter

```powershell
cd .\mishon_app\
flutter analyze
flutter test
```

## Важно

- Основной backend проекта - `mishon-go-api`.
- Сайту больше не нужен отдельный сервер.
- Веб-клиент переведен на более аккуратную структуру `app / pages / widgets / shared`.
- Стили сайта работают через `Sass`.
- Веб и мобильное приложение используют одну серверную модель и один источник данных.

## Дополнительно

Подробная структура каталогов и файлов описана в [PROJECT_STRUCTURE.md](/Users/Michael/Desktop/Mishon/PROJECT_STRUCTURE.md).

Планы по следующим этапам вынесены в [ROADMAP.md](/Users/Michael/Desktop/Mishon/ROADMAP.md).

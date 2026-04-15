# Windows Batch Scripts

Все Windows `.bat`-файлы для локального запуска лежат в этой папке, а не в корне проекта.

## Что запускает каждый файл

- `run-backend-go.bat`
  Запускает Go backend из `mishon-go-api`.

- `run-web-site.bat`
  Запускает web site в dev-режиме из `mishon-web` через реальную команду `npm run dev`.

- `run-flutter-web.bat`
  Запускает Flutter Web из `mishon_app` через `flutter run -d chrome`.

- `run-all.bat`
  Открывает backend, web site и Flutter Web в отдельных окнах.

## Быстрый запуск

Запустить всё сразу:

```bat
run-all.bat
```

Или по отдельности:

```bat
run-backend-go.bat
run-web-site.bat
run-flutter-web.bat
```

## Зависимости

Для запуска должны быть установлены и доступны в `PATH`:

- Go
- Node.js и npm
- Flutter
- Google Chrome
- PostgreSQL

## Порты

- Go backend: `8081`
- Web site (Vite dev server): `5173`
- Flutter Web: `3000`

## Переменные окружения по умолчанию

### Backend

`run-backend-go.bat` выставляет:

- `PORT=8081`
- `DATABASE_URL=postgres://postgres:CHANGE_ME@localhost:5432/mishon?sslmode=disable`
- `JWT_KEY=replace-with-a-long-random-secret-at-least-32-characters`
- `JWT_ISSUER=Mishon`
- `JWT_AUDIENCE=MishonUsers`
- `JWT_EXPIRE_MINUTES=120`
- `JWT_REFRESH_DAYS=30`
- `CORS_ORIGINS=http://localhost:*,http://127.0.0.1:*,https://localhost:*,https://127.0.0.1:*`

Если ваш пароль PostgreSQL отличается, замените `CHANGE_ME` в батнике или заранее задайте `DATABASE_URL` в текущем окне.

### Web site

`run-web-site.bat` по умолчанию использует:

- `VITE_API_URL=http://localhost:8081/api/v1`

### Flutter Web

`run-flutter-web.bat` по умолчанию использует:

- `API_BASE_URL=http://localhost:8081/api`
- `FLUTTER_WEB_PORT=3000`
- `FLUTTER_WEB_DEVICE=chrome`

## Если что-то не стартует

- Проверьте, что зависимости установлены и доступны из `PATH`.
- Для web site выполните `npm install` внутри `mishon-web`.
- Для Flutter выполните `flutter pub get` внутри `mishon_app`.
- Для backend проверьте, что PostgreSQL запущен и `DATABASE_URL` содержит правильный пароль.
- Если окно закрылось бы с ошибкой, батники специально ставят `pause`, чтобы вы увидели сообщение.

## Какие реальные команды используются внутри

- Backend:
  `go run .\cmd\mishon-go-api\`

- Web site:
  `npm run dev`

- Flutter Web:
  `flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8081/api`

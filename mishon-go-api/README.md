# Mishon Go API

Single Go backend for the Mishon website and Flutter app.

## Public v1 responsibilities

- canonical API for the website at `/api/v1`
- compatibility API for the current Flutter client at `/api`
- PostgreSQL-backed auth, feed, profiles, chats, notifications, reports, and moderation
- PostgreSQL-backed media storage through `MediaAssets`
- public media delivery through `/media/{mediaKey}`
- SSE live sync through `/api/v1/sync/stream` and `/api/sync/stream`
- automatic SQL migrations on startup

## Local run

```powershell
cd .\mishon-go-api\
Copy-Item .env.example .env
$env:DATABASE_URL = "postgres://mishon:CHANGE_ME@localhost:5432/mishon?sslmode=disable"
$env:JWT_KEY = "replace-with-a-long-random-secret-at-least-32-characters"
go run .\cmd\mishon-go-api\
```

Default local URL:

- [http://localhost:8081](http://localhost:8081)

## Docker

The repo root now contains `docker-compose.yml` plus:

- [Dockerfile](/Users/Michael/Desktop/Mishon/mishon-go-api/Dockerfile)
- [Dockerfile](/Users/Michael/Desktop/Mishon/mishon-web/Dockerfile)
- [default.conf](/Users/Michael/Desktop/Mishon/deploy/nginx/default.conf)

Typical flow:

```powershell
cd ..
Copy-Item .env.example .env
Copy-Item .\mishon-go-api\.env.example .\mishon-go-api\.env
docker compose up --build
```

## Verification

```powershell
go build ./...
```

## Media storage

New uploads are stored inside PostgreSQL `MediaAssets` as binary payloads and served back through `/media/{mediaKey}`.

`UPLOADS_DIR` remains only as a legacy compatibility directory for old `/uploads/...` links that may still exist in the database or on disk.

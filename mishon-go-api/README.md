# Mishon Go API

Single backend for the Mishon website and mobile app.

## Responsibilities

- serves web API for the React site at `/api/v1`
- serves mobile-compatible API for Flutter at `/api`
- serves the built website from `mishon-web/dist`
- serves uploaded files from `/uploads`

## Run

```powershell
cd .\mishon-go-api\
$env:DATABASE_URL = "postgres://postgres:CHANGE_ME@localhost:5432/mishon?sslmode=disable"
$env:JWT_KEY = "replace-with-a-long-random-secret-at-least-32-characters"
go run .\cmd\mishon-go-api\
```

Default local URL:

- [http://localhost:8081](http://localhost:8081)

## Verify

```powershell
go build ./...
```

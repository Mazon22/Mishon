# Docker Deploy

## What runs

- `postgres`: primary PostgreSQL database
- `mailpit`: local SMTP inbox for verification and reset emails
- `api`: Go backend with automatic SQL migrations
- `web`: built React frontend served by nginx
- `proxy`: public nginx entrypoint for web, API, SSE, and media

## First start

```powershell
cd C:\Users\Michael\Desktop\Mishon
Copy-Item .env.example .env
docker compose up --build -d
```

The public app will be available at:

- `http://localhost`

Local email inbox:

- `http://localhost:8025`

## Important env vars

- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `JWT_KEY`
- `PUBLIC_BASE_URL`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_FROM`

By default local Docker runs through Mailpit, so verification and reset emails appear in the browser inbox at `http://localhost:8025`.

## What this startup now includes

- automatic backend migrations, including admin/support tables and indexes
- API healthcheck on `/health`
- nginx proxy waiting for a healthy API before accepting traffic
- web admin panel at `http://localhost/admin` for the `@mishon` account after migrations run

## About uploads

New media is stored in PostgreSQL and served through `/media/{mediaKey}`.

`UPLOADS_DIR` is now optional and should stay empty for a clean public deployment.

Set `UPLOADS_DIR` only if you still need to serve old legacy files that are referenced as `/uploads/...`.

## Update

```powershell
cd C:\Users\Michael\Desktop\Mishon
docker compose up --build -d
Invoke-WebRequest http://localhost/health
```

## Logs

```powershell
docker compose logs -f api
docker compose logs -f proxy
```

## Stop

```powershell
docker compose down
```

## Backup and restore

Use the scripts:

- [backup-postgres.ps1](/Users/Michael/Desktop/Mishon/scripts-windows/backup-postgres.ps1)
- [restore-postgres.ps1](/Users/Michael/Desktop/Mishon/scripts-windows/restore-postgres.ps1)

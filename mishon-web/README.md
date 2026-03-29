# Mishon Web

Desktop-first website for Mishon built with React, TypeScript, Vite and Sass.

## Structure

- `src/app` — app shell, providers, router and Sass entry
- `src/pages` — route-level pages
- `src/widgets` — reusable UI blocks
- `src/shared` — API client, helpers and types

## Local workflow

Install dependencies:

```powershell
cd .\mishon-web\
npm install
```

Dev server:

```powershell
npm run dev
```

Production build served by Go:

```powershell
npm run build
```

## Notes

- In normal local usage the main site is served by `mishon-go-api`, not by a separate Node backend.
- In dev mode Vite proxies `/api` and `/uploads` to the Go server.

# Mishon

Mishon is a small social network project with one backend, one database, and Flutter clients for Android and web.

The repository contains:

- `Mishon.API` - ASP.NET Core API
- `Mishon.Application` - service contracts and DTOs
- `Mishon.Domain` - domain entities
- `Mishon.Infrastructure` - EF Core, data access, services, migrations
- `mishon_app` - Flutter client for Android and web

## What works

- registration and login
- profile editing
- feed and user posts
- likes and comments
- follow system
- friends and friend requests
- private chats
- shared data source for mobile client and backend

## Stack

- ASP.NET Core 8
- Entity Framework Core
- PostgreSQL
- JWT auth
- Flutter
- Riverpod
- Dio

## Project layout

```text
Mishon/
|-- Mishon.API/
|-- Mishon.Application/
|-- Mishon.Domain/
|-- Mishon.Infrastructure/
`-- mishon_app/
```

## Requirements

- .NET 8 SDK
- Flutter SDK
- Android SDK / Android Studio
- PostgreSQL

## Backend setup

1. Create a PostgreSQL database.
2. Set the connection string and JWT key.
3. Apply migrations.
4. Start the API.

Example for PowerShell:

```powershell
$env:ConnectionStrings__DefaultConnection="Host=localhost;Port=5432;Database=mishon;Username=postgres;Password=YOUR_PASSWORD"
$env:Jwt__Key="YOUR_SECRET_KEY_AT_LEAST_32_CHARS"

dotnet ef database update --project .\Mishon.Infrastructure\ --startup-project .\Mishon.API\
dotnet run --project .\Mishon.API\
```

## Flutter app setup

```powershell
cd .\mishon_app\
flutter pub get
flutter run
```

Run in Chrome:

```powershell
cd .\mishon_app\
flutter run -d chrome
```

Debug APK build:

```powershell
cd .\mishon_app\
flutter build apk --debug
```

Release APK build:

```powershell
cd .\mishon_app\
flutter build apk --release
```

## API address

The Flutter app uses `mishon_app/lib/core/constants/api_constants.dart`.

- Android emulator: `http://10.0.2.2:5097/api`
- web: `http://localhost:5097/api`
- physical phone: replace with your PC local IP

If you run the app on a real device, backend and phone must be in the same network.

## Database

The application is built around one shared database. Feed, profiles, comments, friend requests, chats, and messages come from the same backend and are used by the Android client directly through the API.

## Main API areas

- `/api/auth`
- `/api/posts`
- `/api/comments`
- `/api/follows`
- `/api/friends`
- `/api/users`
- `/api/conversations`

## Notes

- Do not commit real secrets to `appsettings.Development.json`.
- Keep `Jwt__Key` long enough for production use.
- Before the first launch on a phone, make sure the backend is reachable from the device.

## Current state

The root duplicate Flutter template was removed. The working client now lives in `mishon_app` and can be launched on Android or in the browser.

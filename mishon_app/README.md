# Mishon Flutter App

Flutter client for Mishon. It can run as:

- Android mobile app
- Flutter Web mobile-style client

## Backend

The app now uses the Go backend as the primary server.

Typical local URLs:

- web and desktop debug: `http://localhost:8081/api`
- Android emulator: `http://10.0.2.2:8081/api`
- physical device: `http://YOUR_LAN_IP:8081/api`

Preferred override:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:8081/api
```

## Run

Install dependencies:

```powershell
cd .\mishon_app\
flutter pub get
```

Android emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api
```

Flutter Web:

```powershell
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8081/api
```

## Verify

```powershell
flutter analyze
flutter test
```

# Mishon - Flutter Social Network App

Flutter приложение для социальной сети Mishon.

## Структура проекта

```
lib/
├── core/                      # Общий код
│   ├── constants/             # Константы (API URL)
│   ├── firebase/              # Firebase сервис
│   ├── models/                # Модели данных
│   ├── network/               # API клиент (Dio)
│   ├── repositories/          # Репозитории (Riverpod)
│   ├── router/                # Навигация (GoRouter)
│   └── storage/               # Secure storage (JWT)
├── features/                  # Фичи
│   ├── auth/                  # Авторизация
│   ├── feed/                  # Лента постов
│   ├── post/                  # Создание поста
│   └── profile/               # Профиль
└── main.dart
```

## Требования

- Flutter SDK 3.7+
- Android Studio / VS Code
- Backend Mishon (запущен)

## Настройка и запуск

### 1. Установка зависимостей

```bash
cd mishon_app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Настройка API URL

Откройте `lib/core/constants/api_constants.dart`:

```dart
// Для Android emulator (локальный backend)
static const String baseUrl = 'http://10.0.2.2:5000/api';

// Для iOS simulator
// static const String baseUrl = 'http://localhost:5000/api';

// Для реального устройства (замените IP на ваш)
// static const String baseUrl = 'http://192.168.1.100:5000/api';
```

### 3. Запуск backend

Убедитесь, что backend Mishon запущен:

```bash
cd ../Mishon.API
dotnet run
```

### 4. Запуск приложения

```bash
# Запуск на эмуляторе/устройстве
flutter run

# Сборка debug APK
flutter build apk --debug

# Сборка release APK
flutter build apk --release
```

## Функционал

| Экран | Путь | Описание |
|-------|------|----------|
| Вход | `/login` | Вход в аккаунт |
| Регистрация | `/register` | Создание аккаунта |
| Лента | `/feed` | Лента постов |
| Профиль | `/profile` | Профиль пользователя |
| Создать пост | `/create-post` | Создание нового поста |

## API Endpoints

Приложение использует backend Mishon:

```
POST   /api/auth/register     - Регистрация
POST   /api/auth/login        - Вход
GET    /api/auth/profile      - Профиль
PUT    /api/auth/profile      - Обновить профиль
POST   /api/posts             - Создать пост
GET    /api/posts             - Лента
POST   /api/posts/{id}/like   - Лайк
POST   /api/follows/{id}      - Подписка
GET    /api/follows/followings - Подписки
```

## Архитектура

- **Clean Architecture** (упрощенная)
- **MVVM** паттерн
- **Riverpod** для state management
- **GoRouter** для навигации
- **Dio** для HTTP запросов
- **flutter_secure_storage** для JWT токена

## Хранение JWT

```dart
// При логине/регистрации
await storage.writeToken(token);
await storage.writeUserId(userId);

// При запросах (автоматически через interceptor)
headers['Authorization'] = 'Bearer {token}';

// При 401 ошибке
await storage.clear();
```

## Firebase Push-уведомления

Для включения push-уведомлений:

1. Создайте проект в [Firebase Console](https://console.firebase.google.com)
2. Добавьте Android приложение
3. Скачайте `google-services.json` в `android/app/`
4. Добавьте зависимости в `android/build.gradle.kts` и `android/app/build.gradle.kts`

## Структура экранов

```
┌─────────────┐
│   Login     │
└──────┬──────┘
       │
┌──────▼──────┐     ┌─────────────┐
│   Feed      │────▶│  Profile    │
└──────┬──────┘     └─────────────┘
       │
┌──────▼──────┐
│ Create Post │
└─────────────┘
```

## State Management (Riverpod)

```dart
// Provider
@riverpod
class FeedNotifier extends _$FeedNotifier {
  @override
  AsyncValue<List<Post>> build() => const AsyncValue.loading();
  
  Future<void> toggleLike(int postId) async { ... }
}

// Использование в виджете
final feed = ref.watch(feedNotifierProvider);
ref.read(feedNotifierProvider.notifier).toggleLike(postId);
```

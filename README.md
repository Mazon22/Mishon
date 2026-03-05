# Mishon — Социальная сеть

Современное приложение социальной сети с поддержкой аутентификации, публикаций, ленты новостей и системы подписок.

## 🛠 Стек технологий

**Backend:**
- ASP.NET Core 8
- Entity Framework Core
- PostgreSQL
- JWT Authentication

**Frontend (Mobile):**
- Flutter
- Riverpod (state management)
- GoRouter (навигация)
- Firebase (push-уведомления)

## 📋 Требования

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Flutter 3.x](https://flutter.dev/docs/get-started/install)
- [PostgreSQL 14+](https://www.postgresql.org/download/)

## 🚀 Быстрый старт

### 1. База данных

Создайте базу данных PostgreSQL:

```sql
CREATE DATABASE mishon;
```

### 2. Backend

```bash
cd Mishon.API

# Настройте строку подключения в appsettings.Development.json:
# "ConnectionStrings": {
#   "DefaultConnection": "Host=localhost;Port=5432;Database=mishon;Username=postgres;Password=YOUR_PASSWORD"
# }

# Примените миграции
dotnet ef database update

# Запустите сервер
dotnet run
```

Backend будет доступен по адресу: `http://localhost:5000`

### 3. Flutter (Mobile)

```bash
cd mishon_app

# Установите зависимости
flutter pub get

# Запустите приложение
flutter run
```

## 🔐 Настройка секретов

### Вариант 1: appsettings.Development.json

Создайте файл `Mishon.API/appsettings.Development.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=mishon;Username=postgres;Password=YOUR_PASSWORD"
  },
  "Jwt": {
    "Key": "YOUR_SUPER_SECRET_KEY_MIN_32_CHARS",
    "Issuer": "Mishon",
    "Audience": "MishonUsers",
    "ExpireMinutes": 15,
    "RefreshTokenExpireDays": 7
  }
}
```

### Вариант 2: Переменные окружения

```bash
# Linux/macOS
export ConnectionStrings__DefaultConnection="Host=localhost;Database=mishon;Username=postgres;Password=YOUR_PASSWORD"
export Jwt__Key="YOUR_SUPER_SECRET_KEY"

# Windows (PowerShell)
$env:ConnectionStrings__DefaultConnection="Host=localhost;Database=mishon;Username=postgres;Password=YOUR_PASSWORD"
$env:Jwt__Key="YOUR_SUPER_SECRET_KEY"
```

## 📁 Структура проекта

```
Mishon/
├── Mishon.API/           # ASP.NET Core Web API
├── Mishon.Application/   # Бизнес-логика, интерфейсы, DTO
├── Mishon.Domain/        # Сущности базы данных
├── Mishon.Infrastructure/# Реализация репозиториев и сервисов
└── mishon_app/           # Flutter приложение
```

## 🔌 API Endpoints

| Метод | Endpoint | Описание |
|-------|----------|----------|
| POST | `/api/auth/register` | Регистрация |
| POST | `/api/auth/login` | Вход |
| POST | `/api/auth/refresh` | Обновление токена |
| GET | `/api/posts` | Лента постов |
| POST | `/api/posts` | Создать пост |
| GET | `/api/follows` | Подписки/подписчики |
| POST | `/api/follows/{id}` | Подписаться |

## ⚠️ Важно

- Никогда не коммитьте `appsettings.Development.json` с реальными паролями
- Используйте `.env` файлы для локальной разработки
- Все секреты должны быть добавлены в `.gitignore`

## 📄 Лицензия

MIT

class ApiConstants {
  // Development: localhost for Windows/Desktop
  static const String _devUrl = 'http://localhost:5097/api';

  // Production: замените на ваш реальный URL
  static const String _prodUrl = 'https://api.mishon.com/api';

  // Определяем текущий URL на основе флага production
  static String get baseUrl {
    // const bool.fromEnvironment('dart.vm.product') true для production сборки
    return const bool.fromEnvironment('dart.vm.product')
        ? _prodUrl
        : _devUrl;
  }

  static const String tokenKey = 'jwt_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String tokenExpiryKey = 'token_expiry';

  // Timeout настройки
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 10);
}

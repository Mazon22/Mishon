import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _localhostUrl = 'http://localhost:8081/api';
  static const String _androidEmulatorUrl = 'http://10.0.2.2:8081/api';
  static const String _defaultProdUrl = 'https://api.mishon.com/api';
  static const bool enableEmailVerificationFlow = false;

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    if (const bool.fromEnvironment('dart.vm.product')) {
      return _defaultProdUrl;
    }

    if (kIsWeb) {
      return _localhostUrl;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidEmulatorUrl,
      _ => _localhostUrl,
    };
  }

  static const String tokenKey = 'jwt_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String tokenExpiryKey = 'token_expiry';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 10);
}

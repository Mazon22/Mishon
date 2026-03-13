import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class SecureStorage {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  final _logger = Logger();

  Future<void> writeToken(String token) async {
    try {
      await _storage.write(key: 'jwt_token', value: token);
    } catch (e, st) {
      _logger.e('Failed to write token', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: 'jwt_token');
    } catch (e, st) {
      _logger.e('Failed to read token', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: 'jwt_token');
    } catch (e, st) {
      _logger.e('Failed to delete token', error: e, stackTrace: st);
    }
  }

  Future<void> writeRefreshToken(String token) async {
    try {
      await _storage.write(key: 'refresh_token', value: token);
    } catch (e, st) {
      _logger.e('Failed to write refresh token', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: 'refresh_token');
    } catch (e, st) {
      _logger.e('Failed to read refresh token', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: 'refresh_token');
    } catch (e, st) {
      _logger.e('Failed to delete refresh token', error: e, stackTrace: st);
    }
  }

  Future<void> writeUserId(int userId) async {
    try {
      await _storage.write(key: 'user_id', value: userId.toString());
    } catch (e, st) {
      _logger.e('Failed to write user ID', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<int?> readUserId() async {
    try {
      final value = await _storage.read(key: 'user_id');
      return value != null ? int.parse(value) : null;
    } catch (e, st) {
      _logger.e('Failed to read user ID', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> writeAccessTokenExpiry(DateTime expiry) async {
    try {
      await _storage.write(
        key: 'access_token_expiry',
        value: expiry.toIso8601String(),
      );
    } catch (e, st) {
      _logger.e('Failed to write access token expiry', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<DateTime?> readAccessTokenExpiry() async {
    try {
      final value = await _storage.read(key: 'access_token_expiry');
      return value != null ? DateTime.parse(value) : null;
    } catch (e, st) {
      _logger.e('Failed to read access token expiry', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> writeRefreshTokenExpiry(DateTime expiry) async {
    try {
      await _storage.write(
        key: 'refresh_token_expiry',
        value: expiry.toIso8601String(),
      );
    } catch (e, st) {
      _logger.e('Failed to write refresh token expiry', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<DateTime?> readRefreshTokenExpiry() async {
    try {
      final value = await _storage.read(key: 'refresh_token_expiry');
      return value != null ? DateTime.parse(value) : null;
    } catch (e, st) {
      _logger.e('Failed to read refresh token expiry', error: e, stackTrace: st);
      return null;
    }
  }

  Future<bool> isAccessTokenExpired() async {
    try {
      final expiry = await readAccessTokenExpiry();
      if (expiry == null) return true;
      // Добавляем буфер 1 минута
      return DateTime.now().add(const Duration(minutes: 1)).isAfter(expiry);
    } catch (e, st) {
      _logger.e('Failed to check access token expiry', error: e, stackTrace: st);
      return true;
    }
  }

  Future<bool> isRefreshTokenExpired() async {
    try {
      final expiry = await readRefreshTokenExpiry();
      if (expiry == null) return true;
      return DateTime.now().isAfter(expiry);
    } catch (e, st) {
      _logger.e('Failed to check refresh token expiry', error: e, stackTrace: st);
      return true;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (e, st) {
      _logger.e('Failed to clear storage', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> writeAppLanguage(String languageCode) async {
    try {
      await _storage.write(key: 'app_language', value: languageCode);
    } catch (e, st) {
      _logger.e('Failed to write app language', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<String?> readAppLanguage() async {
    try {
      return await _storage.read(key: 'app_language');
    } catch (e, st) {
      _logger.e('Failed to read app language', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> writeBooleanSetting(String key, bool value) async {
    try {
      await _storage.write(key: key, value: value ? 'true' : 'false');
    } catch (e, st) {
      _logger.e('Failed to write boolean setting', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool?> readBooleanSetting(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) {
        return null;
      }
      return value.toLowerCase() == 'true';
    } catch (e, st) {
      _logger.e('Failed to read boolean setting', error: e, stackTrace: st);
      return null;
    }
  }
}

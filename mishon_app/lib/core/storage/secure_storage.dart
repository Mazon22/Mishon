import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class SecureStorage {
  static const _jwtTokenKey = 'jwt_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _accessTokenExpiryKey = 'access_token_expiry';
  static const _refreshTokenExpiryKey = 'refresh_token_expiry';
  static const _appLanguageKey = 'app_language';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  final _logger = Logger();
  final Map<String, String?> _memoryCache = <String, String?>{};
  var _isCacheHydrated = false;

  bool get isCacheHydrated => _isCacheHydrated;

  String? get cachedToken => _memoryCache[_jwtTokenKey];
  String? get cachedRefreshToken => _memoryCache[_refreshTokenKey];
  int? get cachedUserId => _parseInt(_memoryCache[_userIdKey]);
  DateTime? get cachedAccessTokenExpiry =>
      _parseDate(_memoryCache[_accessTokenExpiryKey]);
  DateTime? get cachedRefreshTokenExpiry =>
      _parseDate(_memoryCache[_refreshTokenExpiryKey]);

  Future<void> warmup() async {
    if (_isCacheHydrated) {
      return;
    }

    try {
      final values = await _storage.readAll();
      _memoryCache
        ..clear()
        ..addAll(values);
      _isCacheHydrated = true;
    } catch (e, st) {
      _logger.e(
        'Failed to warm secure storage cache',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> writeToken(String token) async {
    await _writeValue(_jwtTokenKey, token, label: 'token');
  }

  Future<String?> readToken() async {
    return _readValue(_jwtTokenKey, label: 'token');
  }

  Future<void> deleteToken() async {
    await _deleteValue(_jwtTokenKey, label: 'token');
  }

  Future<void> writeRefreshToken(String token) async {
    await _writeValue(_refreshTokenKey, token, label: 'refresh token');
  }

  Future<String?> readRefreshToken() async {
    return _readValue(_refreshTokenKey, label: 'refresh token');
  }

  Future<void> deleteRefreshToken() async {
    await _deleteValue(_refreshTokenKey, label: 'refresh token');
  }

  Future<void> writeUserId(int userId) async {
    await _writeValue(_userIdKey, userId.toString(), label: 'user ID');
  }

  Future<int?> readUserId() async {
    final value = await _readValue(_userIdKey, label: 'user ID');
    return _parseInt(value);
  }

  Future<void> writeAccessTokenExpiry(DateTime expiry) async {
    await _writeValue(
      _accessTokenExpiryKey,
      expiry.toIso8601String(),
      label: 'access token expiry',
    );
  }

  Future<DateTime?> readAccessTokenExpiry() async {
    final value = await _readValue(
      _accessTokenExpiryKey,
      label: 'access token expiry',
    );
    return _parseDate(value);
  }

  Future<void> writeRefreshTokenExpiry(DateTime expiry) async {
    await _writeValue(
      _refreshTokenExpiryKey,
      expiry.toIso8601String(),
      label: 'refresh token expiry',
    );
  }

  Future<DateTime?> readRefreshTokenExpiry() async {
    final value = await _readValue(
      _refreshTokenExpiryKey,
      label: 'refresh token expiry',
    );
    return _parseDate(value);
  }

  Future<bool> isAccessTokenExpired() async {
    final expiry = await readAccessTokenExpiry();
    if (expiry == null) {
      return true;
    }

    return DateTime.now().add(const Duration(minutes: 1)).isAfter(expiry);
  }

  bool isAccessTokenExpiredSync({
    Duration buffer = const Duration(minutes: 1),
  }) {
    final expiry = cachedAccessTokenExpiry;
    if (expiry == null) {
      return true;
    }

    return DateTime.now().add(buffer).isAfter(expiry);
  }

  Future<bool> isRefreshTokenExpired() async {
    final expiry = await readRefreshTokenExpiry();
    if (expiry == null) {
      return true;
    }

    return DateTime.now().isAfter(expiry);
  }

  bool isRefreshTokenExpiredSync() {
    final expiry = cachedRefreshTokenExpiry;
    if (expiry == null) {
      return true;
    }

    return DateTime.now().isAfter(expiry);
  }

  Future<void> clear() async {
    try {
      await _storage.deleteAll();
      _memoryCache.clear();
      _isCacheHydrated = true;
    } catch (e, st) {
      _logger.e('Failed to clear storage', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> writeAppLanguage(String languageCode) async {
    await _writeValue(_appLanguageKey, languageCode, label: 'app language');
  }

  Future<String?> readAppLanguage() async {
    return _readValue(_appLanguageKey, label: 'app language');
  }

  Future<void> writeBooleanSetting(String key, bool value) async {
    await _writeValue(key, value ? 'true' : 'false', label: 'boolean setting');
  }

  Future<bool?> readBooleanSetting(String key) async {
    final value = await _readValue(key, label: 'boolean setting');
    if (value == null) {
      return null;
    }

    return value.toLowerCase() == 'true';
  }

  Future<void> _writeValue(
    String key,
    String value, {
    required String label,
  }) async {
    try {
      await _storage.write(key: key, value: value);
      _memoryCache[key] = value;
    } catch (e, st) {
      _logger.e('Failed to write $label', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<String?> _readValue(String key, {required String label}) async {
    if (_isCacheHydrated) {
      return _memoryCache[key];
    }

    try {
      final value = await _storage.read(key: key);
      _memoryCache[key] = value;
      return value;
    } catch (e, st) {
      _logger.e('Failed to read $label', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> _deleteValue(String key, {required String label}) async {
    try {
      await _storage.delete(key: key);
      _memoryCache.remove(key);
    } catch (e, st) {
      _logger.e('Failed to delete $label', error: e, stackTrace: st);
    }
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  static int? _parseInt(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return int.tryParse(value);
  }
}

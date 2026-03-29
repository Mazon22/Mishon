import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class SecureStorage {
  static const _jwtTokenKey = 'jwt_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _sessionIdKey = 'session_id';
  static const _usernameKey = 'username';
  static const _userEmailKey = 'user_email';
  static const _emailVerifiedKey = 'email_verified';
  static const _roleKey = 'user_role';
  static const _accessTokenExpiryKey = 'access_token_expiry';
  static const _refreshTokenExpiryKey = 'refresh_token_expiry';
  static const _appLanguageKey = 'app_language';
  static const _onboardingCompletedPrefix = 'onboarding_completed_';
  static const deviceIdKey = 'device_id';

  static const _authKeys = <String>{
    _jwtTokenKey,
    _refreshTokenKey,
    _userIdKey,
    _sessionIdKey,
    _usernameKey,
    _userEmailKey,
    _emailVerifiedKey,
    _roleKey,
    _accessTokenExpiryKey,
    _refreshTokenExpiryKey,
  };

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
  String? get cachedSessionId => _memoryCache[_sessionIdKey];
  String? get cachedUsername => _memoryCache[_usernameKey];
  String? get cachedUserEmail => _memoryCache[_userEmailKey];
  bool get cachedEmailVerified => _parseBool(_memoryCache[_emailVerifiedKey]);
  String? get cachedRole => _memoryCache[_roleKey];
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

  Future<void> writeSessionId(String sessionId) async {
    await _writeValue(_sessionIdKey, sessionId, label: 'session ID');
  }

  Future<String?> readSessionId() async {
    return _readValue(_sessionIdKey, label: 'session ID');
  }

  Future<void> writeUsername(String username) async {
    await _writeValue(_usernameKey, username, label: 'username');
  }

  Future<String?> readUsername() async {
    return _readValue(_usernameKey, label: 'username');
  }

  Future<void> writeUserEmail(String email) async {
    await _writeValue(_userEmailKey, email, label: 'user email');
  }

  Future<String?> readUserEmail() async {
    return _readValue(_userEmailKey, label: 'user email');
  }

  Future<void> writeEmailVerified(bool value) async {
    await _writeValue(
      _emailVerifiedKey,
      value ? 'true' : 'false',
      label: 'email verification status',
    );
  }

  Future<bool> readEmailVerified() async {
    final value = await _readValue(
      _emailVerifiedKey,
      label: 'email verification status',
    );
    return _parseBool(value);
  }

  Future<void> writeRole(String role) async {
    await _writeValue(_roleKey, role, label: 'role');
  }

  Future<String?> readRole() async {
    return _readValue(_roleKey, label: 'role');
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

  Future<void> clearAuthState() async {
    try {
      for (final key in _authKeys) {
        await _storage.delete(key: key);
        _memoryCache.remove(key);
      }
      _isCacheHydrated = true;
    } catch (e, st) {
      _logger.e('Failed to clear auth state', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> writeAppLanguage(String languageCode) async {
    await _writeValue(_appLanguageKey, languageCode, label: 'app language');
  }

  Future<String?> readAppLanguage() async {
    return _readValue(_appLanguageKey, label: 'app language');
  }

  Future<void> writeOnboardingCompleted(int userId, bool value) async {
    await _writeValue(
      '$_onboardingCompletedPrefix$userId',
      value ? 'true' : 'false',
      label: 'onboarding completion',
    );
  }

  Future<bool> readOnboardingCompleted(int userId) async {
    final value = await _readValue(
      '$_onboardingCompletedPrefix$userId',
      label: 'onboarding completion',
    );
    return _parseBool(value);
  }

  bool readOnboardingCompletedSync(int userId) {
    return _parseBool(_memoryCache['$_onboardingCompletedPrefix$userId']);
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

  Future<void> writeStringSetting(String key, String value) async {
    await _writeValue(key, value, label: 'string setting');
  }

  Future<String?> readStringSetting(String key) async {
    return _readValue(key, label: 'string setting');
  }

  Future<void> writeIntSetting(String key, int value) async {
    await _writeValue(key, value.toString(), label: 'int setting');
  }

  Future<int?> readIntSetting(String key) async {
    final value = await _readValue(key, label: 'int setting');
    return _parseInt(value);
  }

  Future<void> deleteSetting(String key) async {
    await _deleteValue(key, label: 'setting');
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

  static bool _parseBool(String? value) {
    return value?.toLowerCase() == 'true';
  }
}

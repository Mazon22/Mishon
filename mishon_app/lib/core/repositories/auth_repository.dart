import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mishon_app/core/auth/auth_session_support.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/network/api_client.dart';
import 'package:mishon_app/core/network/api_service.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/providers/auth_session_events.dart';
import 'package:mishon_app/core/repositories/memory_cache.dart';
import 'package:mishon_app/core/storage/secure_storage.dart';
import 'package:mishon_app/core/utils/device_metadata.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

class AuthSessionSnapshot {
  final bool isAuthenticated;
  final int? userId;
  final bool hasConnection;
  final bool emailVerified;
  final String? role;

  const AuthSessionSnapshot({
    required this.isAuthenticated,
    required this.userId,
    this.hasConnection = true,
    this.emailVerified = false,
    this.role,
  });
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    apiService: ref.watch(apiServiceProvider),
    storage: ref.watch(storageProvider),
  );
}

@riverpod
SecureStorage storage(Ref ref) => SecureStorage();

@riverpod
ApiService apiService(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return ApiServiceImpl(client.dio);
}

@riverpod
ApiClient apiClient(Ref ref) => ApiClient(
  storage: ref.watch(storageProvider),
  authSessionEvents: ref.watch(authSessionEventsProvider),
);

class AuthRepository {
  static const _profileCacheTtl = Duration(minutes: 5);
  static MemoryCacheEntry<UserProfile>? _profileCache;
  static final Map<int, MemoryCacheEntry<UserProfile>> _userProfileCache =
      <int, MemoryCacheEntry<UserProfile>>{};

  final ApiService _apiService;
  final SecureStorage _storage;
  final _logger = Logger();

  AuthRepository({
    required ApiService apiService,
    required SecureStorage storage,
  }) : _apiService = apiService,
       _storage = storage;

  Future<AuthResponse> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final deviceMetadata = await resolveDeviceMetadata(_storage);
      final response = await _apiService.register(
        username,
        email,
        password,
        deviceName: deviceMetadata.deviceName,
        platform: deviceMetadata.platform,
      );
      await _saveAuthResponse(response);
      return response;
    } on ApiException catch (e) {
      _logger.e('Registration failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection during registration');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected registration error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    try {
      final deviceMetadata = await resolveDeviceMetadata(_storage);
      final response = await _apiService.login(
        email,
        password,
        deviceName: deviceMetadata.deviceName,
        platform: deviceMetadata.platform,
      );
      await _saveAuthResponse(response);
      return response;
    } on ApiException catch (e) {
      _logger.e('Login failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection during login');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected login error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> verifyEmail(String token) => _apiService.verifyEmail(token);

  Future<void> resendVerification(String email) =>
      _apiService.resendVerification(email);

  Future<void> forgotPassword(String email) => _apiService.forgotPassword(email);

  Future<void> resetPassword(String token, String newPassword) =>
      _apiService.resetPassword(token, newPassword);

  Future<bool> isOnboardingCompleted(int userId) =>
      _storage.readOnboardingCompleted(userId);

  bool isOnboardingCompletedSync(int userId) =>
      _storage.readOnboardingCompletedSync(userId);

  Future<void> setOnboardingCompleted(int userId, bool value) =>
      _storage.writeOnboardingCompleted(userId, value);

  Future<void> logout() async {
    try {
      final deviceId = await _storage.readStringSetting(SecureStorage.deviceIdKey);
      if (deviceId != null && deviceId.isNotEmpty) {
        try {
          await _apiService.removePushToken(deviceId);
        } catch (e, st) {
          _logger.w(
            'Push token removal failed during logout',
            error: e,
            stackTrace: st,
          );
        }
      }
      await _apiService.logout();
    } catch (e, st) {
      _logger.w('Logout API call failed', error: e, stackTrace: st);
    } finally {
      _resetCaches();
      await _storage.clearAuthState();
    }
  }

  Future<void> logoutAllSessions() async {
    try {
      await _apiService.logoutAllSessions();
    } finally {
      _resetCaches();
      await _storage.clearAuthState();
    }
  }

  Future<List<SessionModel>> getSessions() => _apiService.getSessions();

  Future<void> revokeSession(String sessionId) => _apiService.revokeSession(sessionId);

  Future<PrivacySettings> getPrivacySettings() =>
      _apiService.getPrivacySettings();

  Future<PrivacySettings> updatePrivacySettings(PrivacySettings settings) async {
    final updated = await _apiService.updatePrivacySettings(settings);
    final currentProfile = peekProfile();
    if (currentProfile != null) {
      _cacheProfile(
        currentProfile.copyWith(
          isPrivateAccount: updated.isPrivateAccount,
          profileVisibility: updated.profileVisibility,
          messagePrivacy: updated.messagePrivacy,
          commentPrivacy: updated.commentPrivacy,
          presenceVisibility: updated.presenceVisibility,
        ),
      );
    }
    return updated;
  }

  UserProfile? peekProfile() {
    final cache = _profileCache;
    if (cache == null || !cache.isFresh(_profileCacheTtl)) {
      return null;
    }

    return cache.value;
  }

  UserProfile? peekUserProfile(int userId) {
    final cache = _userProfileCache[userId];
    if (cache == null || !cache.isFresh(_profileCacheTtl)) {
      return null;
    }

    return cache.value;
  }

  Future<UserProfile> prefetchProfile() {
    return getProfile(forceRefresh: true);
  }

  Future<UserProfile> getProfile({bool forceRefresh = false}) async {
    final cachedProfile = !forceRefresh ? peekProfile() : null;
    if (cachedProfile != null) {
      return cachedProfile;
    }

    final profile = await _apiService.getProfile();
    _cacheProfile(profile);
    return profile;
  }

  Future<UserProfile> getUserProfile(
    int userId, {
    bool forceRefresh = false,
  }) async {
    final cachedProfile = !forceRefresh ? peekUserProfile(userId) : null;
    if (cachedProfile != null) {
      return cachedProfile;
    }

    final profile = await _apiService.getUserProfile(userId);
    _userProfileCache[userId] = MemoryCacheEntry<UserProfile>.now(profile);
    return profile;
  }

  Future<bool> checkUsernameAvailability(String username) async {
    return _apiService.checkUsernameAvailability(username);
  }

  Future<bool> checkRegistrationUsernameAvailability(String username) async {
    return _apiService.checkRegistrationUsernameAvailability(username);
  }

  Future<bool> checkRegistrationEmailAvailability(String email) async {
    return _apiService.checkRegistrationEmailAvailability(email);
  }

  Future<UserProfile> updateProfile({
    String? displayName,
    String? username,
    String? aboutMe,
  }) async {
    final profile = await _apiService.updateProfile(
      displayName: displayName,
      username: username,
      aboutMe: aboutMe,
    );
    _cacheProfile(profile);
    return profile;
  }

  Future<UserProfile> updateProfileMedia({
    Uint8List? avatarBytes,
    Uint8List? bannerBytes,
    required double avatarScale,
    required double avatarOffsetX,
    required double avatarOffsetY,
    required double bannerScale,
    required double bannerOffsetX,
    required double bannerOffsetY,
    bool removeAvatar = false,
    bool removeBanner = false,
  }) async {
    final profile = await _apiService.updateProfileMedia(
      avatarBytes: avatarBytes,
      bannerBytes: bannerBytes,
      avatarScale: avatarScale,
      avatarOffsetX: avatarOffsetX,
      avatarOffsetY: avatarOffsetY,
      bannerScale: bannerScale,
      bannerOffsetX: bannerOffsetX,
      bannerOffsetY: bannerOffsetY,
      removeAvatar: removeAvatar,
      removeBanner: removeBanner,
    );
    _cacheProfile(profile);
    return profile;
  }

  Future<int?> getUserId() async {
    if (_storage.isCacheHydrated) {
      return _storage.cachedUserId;
    }

    return _storage.readUserId();
  }

  Future<bool> isAuthenticated() async {
    final session = await restoreSession();
    return session.isAuthenticated;
  }

  Future<AuthSessionSnapshot> restoreSession() async {
    await _storage.warmup();

    final token = _storage.cachedToken;
    final refreshToken = _storage.cachedRefreshToken;
    final userId = _storage.cachedUserId;

    if ((token == null || token.isEmpty) &&
        (refreshToken == null || refreshToken.isEmpty)) {
      return const AuthSessionSnapshot(isAuthenticated: false, userId: null);
    }

    if (token != null && token.isNotEmpty && !_storage.isAccessTokenExpiredSync()) {
      return AuthSessionSnapshot(
        isAuthenticated: true,
        userId: userId,
        emailVerified: _storage.cachedEmailVerified,
        role: _storage.cachedRole,
      );
    }

    if (refreshToken == null ||
        refreshToken.isEmpty ||
        _storage.isRefreshTokenExpiredSync()) {
      _resetCaches();
      await _storage.clearAuthState();
      return const AuthSessionSnapshot(isAuthenticated: false, userId: null);
    }

    try {
      final response = await _apiService.refreshToken(refreshToken);
      await _saveAuthResponse(response);
      return AuthSessionSnapshot(
        isAuthenticated: true,
        userId: response.userId,
        emailVerified: response.emailVerified,
        role: response.role,
      );
    } on ApiException catch (e, st) {
      final statusCode = e.statusCode ?? e.apiError.statusCode;
      _resetCaches();
      await _clearAuthStateSafely();

      if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
        return const AuthSessionSnapshot(isAuthenticated: false, userId: null);
      }

      _logger.w(
        'Session restore via refresh failed',
        error: e,
        stackTrace: st,
      );
      return const AuthSessionSnapshot(isAuthenticated: false, userId: null);
    } catch (e, st) {
      _logger.w('Session restore via refresh failed', error: e, stackTrace: st);
      _resetCaches();
      await _clearAuthStateSafely();
      return const AuthSessionSnapshot(isAuthenticated: false, userId: null);
    }
  }

  Future<void> _saveAuthResponse(AuthResponse response) async {
    await persistAuthResponse(_storage, response);
  }

  void _cacheProfile(UserProfile profile) {
    _profileCache = MemoryCacheEntry<UserProfile>.now(profile);
    _userProfileCache[profile.id] = MemoryCacheEntry<UserProfile>.now(profile);
  }

  void _resetCaches() {
    _profileCache = null;
    _userProfileCache.clear();
  }

  Future<void> _clearAuthStateSafely() async {
    try {
      await _storage.clearAuthState();
    } catch (e, st) {
      _logger.w(
        'Failed to clear stored auth state after restore failure',
        error: e,
        stackTrace: st,
      );
    }
  }

  @visibleForTesting
  static void resetCachesForTest() {
    _profileCache = null;
    _userProfileCache.clear();
  }
}

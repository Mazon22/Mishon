import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/network/api_service.dart';
import 'package:mishon_app/core/storage/secure_storage.dart';
import 'package:mishon_app/core/network/api_client.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/memory_cache.dart';
import 'package:logger/logger.dart';

part 'auth_repository.g.dart';

class AuthSessionSnapshot {
  final bool isAuthenticated;
  final int? userId;
  final bool hasConnection;

  const AuthSessionSnapshot({
    required this.isAuthenticated,
    required this.userId,
    this.hasConnection = true,
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
ApiClient apiClient(Ref ref) => ApiClient(storage: ref.watch(storageProvider));

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
      final response = await _apiService.register(username, email, password);
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
      final response = await _apiService.login(email, password);
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

  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e, st) {
      _logger.w('Logout API call failed', error: e, stackTrace: st);
    } finally {
      _profileCache = null;
      _userProfileCache.clear();
      await _storage.clear();
    }
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

    try {
      final profile = await _apiService.getProfile();
      _cacheProfile(profile);
      return profile;
    } on ApiException catch (e) {
      _logger.e('Get profile failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting profile');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected get profile error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<UserProfile> getUserProfile(
    int userId, {
    bool forceRefresh = false,
  }) async {
    final cachedProfile = !forceRefresh ? peekUserProfile(userId) : null;
    if (cachedProfile != null) {
      return cachedProfile;
    }

    try {
      final profile = await _apiService.getUserProfile(userId);
      _userProfileCache[userId] = MemoryCacheEntry<UserProfile>.now(profile);
      return profile;
    } on ApiException catch (e) {
      _logger.e('Get user profile failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting user profile');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected get user profile error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool> checkUsernameAvailability(String username) async {
    try {
      return await _apiService.checkUsernameAvailability(username);
    } on ApiException catch (e) {
      _logger.e('Check username availability failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection checking username availability');
      rethrow;
    } catch (e, st) {
      _logger.e(
        'Unexpected username availability error',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<UserProfile> updateProfile({String? username, String? aboutMe}) async {
    try {
      final profile = await _apiService.updateProfile(
        username: username,
        aboutMe: aboutMe,
      );
      _cacheProfile(profile);
      return profile;
    } on ApiException catch (e) {
      _logger.e('Update profile failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection updating profile');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected update profile error', error: e, stackTrace: st);
      rethrow;
    }
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
    try {
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
    } on ApiException catch (e) {
      _logger.e('Update profile media failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection updating profile media');
      rethrow;
    } catch (e, st) {
      _logger.e(
        'Unexpected update profile media error',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<int?> getUserId() async {
    if (_storage.isCacheHydrated) {
      return _storage.cachedUserId;
    }

    return _storage.readUserId();
  }

  Future<bool> isAuthenticated() async {
    if (_storage.isCacheHydrated) {
      final token = _storage.cachedToken;
      final isExpired = _storage.isAccessTokenExpiredSync();
      return token != null && token.isNotEmpty && !isExpired;
    }

    final token = await _storage.readToken();
    final isExpired = await _storage.isAccessTokenExpired();
    return token != null && token.isNotEmpty && !isExpired;
  }

  Future<AuthSessionSnapshot> restoreSession() async {
    await _storage.warmup();

    final token = _storage.cachedToken;
    final userId = _storage.cachedUserId;
    final isAuthenticated =
        token != null &&
        token.isNotEmpty &&
        !_storage.isAccessTokenExpiredSync();

    return AuthSessionSnapshot(
      isAuthenticated: isAuthenticated,
      userId: isAuthenticated ? userId : null,
    );
  }

  Future<bool> _saveAuthResponse(AuthResponse response) async {
    try {
      await _storage.writeToken(response.token);
      await _storage.writeUserId(response.userId);

      if (response.refreshToken != null) {
        await _storage.writeRefreshToken(response.refreshToken!);
      }
      if (response.refreshTokenExpiry != null) {
        await _storage.writeRefreshTokenExpiry(response.refreshTokenExpiry!);
      }

      // Access token expires через 15 минут
      await _storage.writeAccessTokenExpiry(
        DateTime.now().add(const Duration(minutes: 15)),
      );

      return true;
    } catch (e, st) {
      _logger.e('Failed to save auth response', error: e, stackTrace: st);
      return false;
    }
  }

  void _cacheProfile(UserProfile profile) {
    _profileCache = MemoryCacheEntry<UserProfile>.now(profile);
    _userProfileCache[profile.id] = MemoryCacheEntry<UserProfile>.now(profile);
  }
}

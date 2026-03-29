import 'package:flutter_test/flutter_test.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';

import '../../support/test_doubles.dart';

void main() {
  setUp(() {
    AuthRepository.resetCachesForTest();
  });

  test('restoreSession refreshes expired access token and persists response', () async {
    final storage = FakeSecureStorage()
      ..token = 'expired-token'
      ..refreshToken = 'refresh-token'
      ..userId = 42
      ..emailVerified = false
      ..role = 'User'
      ..accessTokenExpiry = DateTime.now().subtract(const Duration(minutes: 5))
      ..refreshTokenExpiry = DateTime.now().add(const Duration(days: 1));
    final api = FakeApiService()
      ..refreshTokenResponse = AuthResponse(
        userId: 42,
        username: 'michael',
        email: 'michael@example.com',
        token: 'fresh-token',
        accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 30)),
        refreshToken: 'fresh-refresh',
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
        sessionId: 'session-42',
        emailVerified: true,
        role: 'Moderator',
      );
    final repository = AuthRepository(apiService: api, storage: storage);

    final session = await repository.restoreSession();

    expect(session.isAuthenticated, isTrue);
    expect(session.userId, 42);
    expect(session.emailVerified, isTrue);
    expect(session.role, 'Moderator');
    expect(api.refreshTokenCallCount, 1);
    expect(api.lastRefreshToken, 'refresh-token');
    expect(storage.cachedToken, 'fresh-token');
    expect(storage.cachedRefreshToken, 'fresh-refresh');
    expect(storage.cachedUserId, 42);
  });

  test('restoreSession clears auth state when refresh fails', () async {
    final storage = FakeSecureStorage()
      ..token = 'expired-token'
      ..refreshToken = 'refresh-token'
      ..userId = 7
      ..accessTokenExpiry = DateTime.now().subtract(const Duration(minutes: 5))
      ..refreshTokenExpiry = DateTime.now().add(const Duration(days: 1));
    final api = FakeApiService()..refreshTokenError = StateError('revoked');
    final repository = AuthRepository(apiService: api, storage: storage);

    final session = await repository.restoreSession();

    expect(session.isAuthenticated, isFalse);
    expect(session.userId, isNull);
    expect(storage.clearAuthStateCalls, 1);
    expect(storage.cachedToken, isNull);
    expect(storage.cachedRefreshToken, isNull);
  });

  test('updatePrivacySettings updates cached profile state', () async {
    final storage = FakeSecureStorage();
    final api = FakeApiService()
      ..profileResponse = UserProfile(
        id: 9,
        username: 'tester',
        email: 'tester@example.com',
        displayName: 'Tester',
        aboutMe: 'bio',
        avatarUrl: null,
        bannerUrl: null,
        avatarScale: 1,
        avatarOffsetX: 0,
        avatarOffsetY: 0,
        bannerScale: 1,
        bannerOffsetX: 0,
        bannerOffsetY: 0,
        createdAt: DateTime(2024, 1, 1),
        lastSeenAt: DateTime(2024, 1, 2),
        isOnline: false,
        followersCount: 10,
        followingCount: 5,
        postsCount: 3,
        isBlockedByViewer: false,
        hasBlockedViewer: false,
      )
      ..updatePrivacyResponse = const PrivacySettings(
        isPrivateAccount: true,
        profileVisibility: 'FollowersOnly',
        messagePrivacy: 'Followers',
        commentPrivacy: 'Friends',
        presenceVisibility: 'Nobody',
      );
    final repository = AuthRepository(apiService: api, storage: storage);

    await repository.getProfile();
    final updated = await repository.updatePrivacySettings(
      const PrivacySettings(
        isPrivateAccount: true,
        profileVisibility: 'FollowersOnly',
        messagePrivacy: 'Followers',
        commentPrivacy: 'Friends',
        presenceVisibility: 'Nobody',
      ),
    );

    expect(updated.isPrivateAccount, isTrue);
    expect(api.lastPrivacySettings?.profileVisibility, 'FollowersOnly');
    expect(repository.peekProfile()?.isPrivateAccount, isTrue);
    expect(repository.peekProfile()?.messagePrivacy, 'Followers');
    expect(repository.peekProfile()?.commentPrivacy, 'Friends');
    expect(repository.peekProfile()?.presenceVisibility, 'Nobody');
  });

  test('logoutAllSessions clears auth state after backend call', () async {
    final storage = FakeSecureStorage()
      ..token = 'token'
      ..refreshToken = 'refresh'
      ..userId = 5;
    final api = FakeApiService();
    final repository = AuthRepository(apiService: api, storage: storage);

    await repository.logoutAllSessions();

    expect(api.logoutAllSessionsCalled, isTrue);
    expect(storage.clearAuthStateCalls, 1);
    expect(storage.cachedToken, isNull);
    expect(storage.cachedRefreshToken, isNull);
  });

  test('getSessions returns backend sessions for active sessions flow', () async {
    final storage = FakeSecureStorage();
    final api = FakeApiService()
      ..sessionsResponse = <SessionModel>[
        SessionModel(
          id: 'session-1',
          createdAt: DateTime(2024, 1, 1),
          lastUsedAt: DateTime(2024, 1, 2),
          expiresAt: DateTime(2024, 2, 1),
          revokedAt: null,
          deviceName: 'Pixel',
          platform: 'android',
          userAgent: 'UA',
          ipAddress: '127.0.0.1',
          isCurrent: true,
          isActive: true,
          revocationReason: null,
        ),
      ];
    final repository = AuthRepository(apiService: api, storage: storage);

    final sessions = await repository.getSessions();

    expect(sessions, hasLength(1));
    expect(sessions.single.id, 'session-1');
    expect(sessions.single.isCurrent, isTrue);
  });
}

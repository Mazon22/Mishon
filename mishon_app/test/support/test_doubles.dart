import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/api_service.dart';
import 'package:mishon_app/core/storage/secure_storage.dart';

class FakeSecureStorage extends SecureStorage {
  String? token;
  String? refreshToken;
  int? userId;
  String? username;
  String? userEmail;
  bool emailVerified = false;
  String? role;
  String? sessionId;
  DateTime? accessTokenExpiry;
  DateTime? refreshTokenExpiry;
  int clearAuthStateCalls = 0;
  final Map<int, bool> onboardingCompletion = <int, bool>{};
  final Map<String, String> stringSettings = <String, String>{};

  @override
  bool get isCacheHydrated => true;

  @override
  String? get cachedToken => token;

  @override
  String? get cachedRefreshToken => refreshToken;

  @override
  int? get cachedUserId => userId;

  @override
  String? get cachedSessionId => sessionId;

  @override
  String? get cachedUsername => username;

  @override
  String? get cachedUserEmail => userEmail;

  @override
  bool get cachedEmailVerified => emailVerified;

  @override
  String? get cachedRole => role;

  @override
  DateTime? get cachedAccessTokenExpiry => accessTokenExpiry;

  @override
  DateTime? get cachedRefreshTokenExpiry => refreshTokenExpiry;

  @override
  Future<void> warmup() async {}

  @override
  Future<void> writeToken(String token) async => this.token = token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeRefreshToken(String token) async => refreshToken = token;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeUserId(int userId) async => this.userId = userId;

  @override
  Future<int?> readUserId() async => userId;

  @override
  Future<void> writeSessionId(String sessionId) async => this.sessionId = sessionId;

  @override
  Future<String?> readSessionId() async => sessionId;

  @override
  Future<void> writeUsername(String username) async => this.username = username;

  @override
  Future<String?> readUsername() async => username;

  @override
  Future<void> writeUserEmail(String email) async => userEmail = email;

  @override
  Future<String?> readUserEmail() async => userEmail;

  @override
  Future<void> writeEmailVerified(bool value) async => emailVerified = value;

  @override
  Future<bool> readEmailVerified() async => emailVerified;

  @override
  Future<void> writeRole(String role) async => this.role = role;

  @override
  Future<String?> readRole() async => role;

  @override
  Future<void> writeAccessTokenExpiry(DateTime expiry) async =>
      accessTokenExpiry = expiry;

  @override
  Future<DateTime?> readAccessTokenExpiry() async => accessTokenExpiry;

  @override
  Future<void> writeRefreshTokenExpiry(DateTime expiry) async =>
      refreshTokenExpiry = expiry;

  @override
  Future<DateTime?> readRefreshTokenExpiry() async => refreshTokenExpiry;

  @override
  bool isAccessTokenExpiredSync({
    Duration buffer = const Duration(minutes: 1),
  }) {
    final expiry = accessTokenExpiry;
    return expiry == null || DateTime.now().add(buffer).isAfter(expiry);
  }

  @override
  bool isRefreshTokenExpiredSync() {
    final expiry = refreshTokenExpiry;
    return expiry == null || DateTime.now().isAfter(expiry);
  }

  @override
  Future<void> clearAuthState() async {
    clearAuthStateCalls += 1;
    token = null;
    refreshToken = null;
    userId = null;
    username = null;
    userEmail = null;
    emailVerified = false;
    role = null;
    sessionId = null;
    accessTokenExpiry = null;
    refreshTokenExpiry = null;
  }

  @override
  Future<void> writeOnboardingCompleted(int userId, bool value) async {
    onboardingCompletion[userId] = value;
  }

  @override
  Future<bool> readOnboardingCompleted(int userId) async =>
      onboardingCompletion[userId] ?? false;

  @override
  bool readOnboardingCompletedSync(int userId) =>
      onboardingCompletion[userId] ?? false;

  @override
  Future<void> writeStringSetting(String key, String value) async {
    stringSettings[key] = value;
  }

  @override
  Future<String?> readStringSetting(String key) async => stringSettings[key];

  @override
  Future<void> deleteSetting(String key) async {
    stringSettings.remove(key);
  }
}

class FakeApiService implements ApiService {
  AuthResponse? refreshTokenResponse;
  Object? refreshTokenError;
  int refreshTokenCallCount = 0;
  String? lastRefreshToken;

  UserProfile? profileResponse;
  PrivacySettings? updatePrivacyResponse;
  PrivacySettings? lastPrivacySettings;

  List<SessionModel> sessionsResponse = const <SessionModel>[];
  bool logoutAllSessionsCalled = false;

  ReportDetailModel? reportResponse;
  Map<String, Object?>? lastReportRequest;

  @override
  Future<AuthResponse> refreshToken(String refreshToken) async {
    refreshTokenCallCount += 1;
    lastRefreshToken = refreshToken;
    if (refreshTokenError != null) {
      throw refreshTokenError!;
    }
    return refreshTokenResponse!;
  }

  @override
  Future<UserProfile> getProfile() async => profileResponse!;

  @override
  Future<PrivacySettings> updatePrivacySettings(PrivacySettings settings) async {
    lastPrivacySettings = settings;
    return updatePrivacyResponse ?? settings;
  }

  @override
  Future<List<SessionModel>> getSessions() async => sessionsResponse;

  @override
  Future<void> logoutAllSessions() async {
    logoutAllSessionsCalled = true;
  }

  @override
  Future<ReportDetailModel> createReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? customNote,
  }) async {
    lastReportRequest = <String, Object?>{
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'customNote': customNote,
    };
    return reportResponse!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Not stubbed: $invocation');
}

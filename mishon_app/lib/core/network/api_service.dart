import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../models/auth_model.dart';
import '../models/post_model.dart';
import '../models/social_models.dart';

abstract class ApiService {
  Future<AuthResponse> register(
    String username,
    String email,
    String password, {
    String? deviceName,
    String? platform,
  });

  Future<AuthResponse> login(
    String email,
    String password, {
    String? deviceName,
    String? platform,
  });

  Future<AuthResponse> refreshToken(String refreshToken);
  Future<void> verifyEmail(String token);
  Future<void> resendVerification(String email);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String token, String newPassword);

  Future<UserProfile> getProfile();
  Future<UserProfile> getUserProfile(int userId);
  Future<bool> checkUsernameAvailability(String username);
  Future<bool> checkRegistrationUsernameAvailability(String username);
  Future<bool> checkRegistrationEmailAvailability(String email);
  Future<UserProfile> updateProfile({
    String? displayName,
    String? username,
    String? aboutMe,
  });
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
  });
  Future<void> logout();
  Future<void> logoutAllSessions();
  Future<List<SessionModel>> getSessions();
  Future<void> revokeSession(String sessionId);
  Future<PrivacySettings> getPrivacySettings();
  Future<PrivacySettings> updatePrivacySettings(PrivacySettings settings);

  Future<PagedResponse<Post>> getFeed({int page = 1, int pageSize = 10});
  Future<PagedResponse<Post>> getFollowingFeed({
    int page = 1,
    int pageSize = 10,
  });
  Future<List<Post>> getUserPosts(
    int userId, {
    int page = 1,
    int pageSize = 20,
  });
  Future<Post> createPost(
    String content,
    String? imageUrl,
    Uint8List? imageBytes,
  );
  Future<Post?> getPost(int postId);
  Future<Post> toggleLike(int postId);
  Future<void> deletePost(int postId);

  Future<List<Comment>> getComments(int postId);
  Future<Comment> createComment(
    int postId,
    String content, {
    int? parentCommentId,
  });
  Future<Comment> updateComment(int postId, int commentId, String content);
  Future<void> deleteComment(int postId, int commentId);

  Future<ToggleFollowResponse> toggleFollow(int userId);
  Future<List<Follow>> getFollowing(int userId);
  Future<List<Follow>> getFollowers(int userId);
  Future<List<Follow>> getFollowings();
  Future<List<Follow>> getFollowersList();
  Future<bool> isFollowing(int userId);
  Future<int> getFollowersCount(int userId);
  Future<List<FriendRequestModel>> getIncomingFollowRequests();
  Future<void> approveFollowRequest(int requestId);
  Future<void> rejectFollowRequest(int requestId);

  Future<PagedResponse<DiscoverUser>> getUsers({
    String? query,
    int page = 1,
    int pageSize = 24,
    int? limit,
  });

  Future<List<FriendUser>> getFriends();
  Future<List<BlockedUserModel>> getBlockedUsers();
  Future<List<FriendRequestModel>> getIncomingFriendRequests();
  Future<List<FriendRequestModel>> getOutgoingFriendRequests();
  Future<void> sendFriendRequest(int userId);
  Future<void> acceptFriendRequest(int requestId);
  Future<void> deleteFriendRequest(int requestId);
  Future<void> removeFriend(int userId);

  Future<List<ConversationModel>> getConversations();
  Future<DirectConversationModel> getOrCreateConversation(int userId);
  Future<ChatMessagePageModel> getMessages(
    int conversationId, {
    int limit = 20,
    int? beforeMessageId,
  });
  Future<ChatMessageModel> sendMessage(
    int conversationId,
    String? content, {
    int? replyToMessageId,
    List<ChatUploadAttachment> attachments = const [],
    void Function(int sent, int total)? onSendProgress,
  });
  Future<ChatMessageModel> forwardMessage(int conversationId, int messageId);
  Future<ChatMessageModel> updateMessage(
    int conversationId,
    int messageId,
    String content,
  );
  Future<void> deleteMessage(int conversationId, int messageId);
  Future<void> deleteMessageForAll(int conversationId, int messageId);
  Future<void> pinConversation(int conversationId, bool isPinned);
  Future<void> archiveConversation(int conversationId, bool isArchived);
  Future<void> favoriteConversation(int conversationId, bool isFavorite);
  Future<void> muteConversation(int conversationId, bool isMuted);
  Future<void> deleteConversation(
    int conversationId, {
    required bool deleteForBoth,
  });
  Future<void> clearConversationHistory(int conversationId);
  Future<void> blockUserFromChat(int userId);
  Future<void> unblockUserFromChat(int userId);
  Future<void> sendTypingStart(int conversationId);
  Future<void> sendTypingStop(int conversationId);

  Future<PagedResponse<NotificationItemModel>> getNotifications({
    int page = 1,
    int pageSize = 30,
  });
  Future<NotificationSummaryModel> getNotificationSummary();
  Future<void> markNotificationRead(int notificationId);
  Future<void> markAllNotificationsRead();
  Future<void> registerPushToken({
    required String deviceId,
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  });
  Future<void> removePushToken(String deviceId);

  Future<ReportDetailModel> createReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? customNote,
  });
  Future<PagedResponse<ReportItemModel>> getReports({
    int page = 1,
    int pageSize = 30,
  });
  Future<ReportDetailModel> getReport(int id);
  Future<void> assignReport(int reportId, int moderatorUserId);
  Future<void> resolveReport(
    int reportId, {
    required String resolution,
    String? resolutionNote,
    DateTime? suspensionUntil,
  });
  Future<ModerationActionModel> warnUser(
    int userId,
    String note, {
    int? reportId,
  });
  Future<ModerationActionModel> suspendUser(
    int userId,
    DateTime until,
    String note, {
    int? reportId,
  });
  Future<ModerationActionModel> banUser(
    int userId,
    String note, {
    int? reportId,
  });
  Future<ModerationActionModel> unbanUser(
    int userId, {
    String? note,
    int? reportId,
  });
  Future<void> assignModerator(int userId);
  Future<void> removeModerator(int userId);
}

class ApiServiceImpl implements ApiService {
  final Dio _dio;

  ApiServiceImpl(this._dio);

  @override
  Future<AuthResponse> register(
    String username,
    String email,
    String password, {
    String? deviceName,
    String? platform,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
        if (deviceName != null) 'deviceName': deviceName,
        if (platform != null) 'platform': platform,
      },
      options: Options(extra: const {'skipAuth': true}),
    );
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AuthResponse> login(
    String email,
    String password, {
    String? deviceName,
    String? platform,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        if (deviceName != null) 'deviceName': deviceName,
        if (platform != null) 'platform': platform,
      },
      options: Options(extra: const {'skipAuth': true}),
    );
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AuthResponse> refreshToken(String refreshToken) async {
    final response = await _dio.post(
      '/auth/refresh-token',
      data: {'refreshToken': refreshToken},
      options: Options(
        extra: const {'skipAuth': true, 'isRefreshRequest': true},
      ),
    );
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> verifyEmail(String token) async {
    await _dio.post(
      '/auth/verify-email',
      data: {'token': token},
      options: Options(extra: const {'skipAuth': true}),
    );
  }

  @override
  Future<void> resendVerification(String email) async {
    await _dio.post(
      '/auth/resend-verification',
      data: {'email': email},
      options: Options(extra: const {'skipAuth': true}),
    );
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _dio.post(
      '/auth/forgot-password',
      data: {'email': email},
      options: Options(extra: const {'skipAuth': true}),
    );
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    await _dio.post(
      '/auth/reset-password',
      data: {'token': token, 'newPassword': newPassword},
      options: Options(extra: const {'skipAuth': true}),
    );
  }

  @override
  Future<UserProfile> getProfile() async {
    final response = await _dio.get('/auth/profile');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> getUserProfile(int userId) async {
    final response = await _dio.get('/auth/profile/$userId');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<bool> checkUsernameAvailability(String username) async {
    final response = await _dio.get(
      '/users/check-username',
      queryParameters: {'username': username},
    );
    return (response.data as Map<String, dynamic>)['available'] as bool? ??
        false;
  }

  @override
  Future<bool> checkRegistrationUsernameAvailability(String username) async {
    final response = await _dio.get(
      '/auth/check-username',
      queryParameters: {'username': username},
      options: Options(extra: const {'skipAuth': true}),
    );
    return (response.data as Map<String, dynamic>)['available'] as bool? ??
        false;
  }

  @override
  Future<bool> checkRegistrationEmailAvailability(String email) async {
    final response = await _dio.get(
      '/auth/check-email',
      queryParameters: {'email': email},
      options: Options(extra: const {'skipAuth': true}),
    );
    return (response.data as Map<String, dynamic>)['available'] as bool? ??
        false;
  }

  @override
  Future<UserProfile> updateProfile({
    String? displayName,
    String? username,
    String? aboutMe,
  }) async {
    final response = await _dio.put(
      '/auth/profile',
      data: {
        if (displayName != null) 'displayName': displayName,
        if (username != null) 'username': username,
        if (aboutMe != null) 'aboutMe': aboutMe,
      },
    );
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  @override
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
    final formData = FormData.fromMap({
      'avatarScale': _formatFormDouble(avatarScale, fallback: 1),
      'avatarOffsetX': _formatFormDouble(avatarOffsetX),
      'avatarOffsetY': _formatFormDouble(avatarOffsetY),
      'bannerScale': _formatFormDouble(bannerScale, fallback: 1),
      'bannerOffsetX': _formatFormDouble(bannerOffsetX),
      'bannerOffsetY': _formatFormDouble(bannerOffsetY),
      'removeAvatar': removeAvatar,
      'removeBanner': removeBanner,
    });

    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      final metadata = _buildImageUploadMetadata(
        avatarBytes,
        prefix: 'avatar',
      );
      formData.files.add(
        MapEntry(
          'avatar',
          MultipartFile.fromBytes(
            avatarBytes,
            filename: metadata.fileName,
            contentType: metadata.contentType,
          ),
        ),
      );
    }

    if (bannerBytes != null && bannerBytes.isNotEmpty) {
      final metadata = _buildImageUploadMetadata(
        bannerBytes,
        prefix: 'banner',
      );
      formData.files.add(
        MapEntry(
          'banner',
          MultipartFile.fromBytes(
            bannerBytes,
            filename: metadata.fileName,
            contentType: metadata.contentType,
          ),
        ),
      );
    }

    final response = await _dio.put(
      '/auth/profile/media',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60)),
    );
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> logout() async {
    await _dio.post('/auth/logout');
  }

  @override
  Future<void> logoutAllSessions() async {
    await _dio.post('/auth/logout-all');
  }

  @override
  Future<List<SessionModel>> getSessions() async {
    final response = await _dio.get('/auth/sessions');
    return (response.data as List<dynamic>)
        .map((item) => SessionModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    await _dio.delete('/auth/sessions/$sessionId');
  }

  @override
  Future<PrivacySettings> getPrivacySettings() async {
    final response = await _dio.get('/users/me/privacy');
    return PrivacySettings.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PrivacySettings> updatePrivacySettings(PrivacySettings settings) async {
    final response = await _dio.put('/users/me/privacy', data: settings.toJson());
    return PrivacySettings.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PagedResponse<Post>> getFeed({int page = 1, int pageSize = 10}) async {
    final response = await _dio.get(
      '/feed',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PagedResponse<Post>.fromJson(
      response.data as Map<String, dynamic>,
      (json) => (json as List<dynamic>)
          .map((item) => Post.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<PagedResponse<Post>> getFollowingFeed({
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _dio.get(
      '/feed/following',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PagedResponse<Post>.fromJson(
      response.data as Map<String, dynamic>,
      (json) => (json as List<dynamic>)
          .map((item) => Post.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<List<Post>> getUserPosts(
    int userId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '/posts/user/$userId',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return (response.data as List<dynamic>)
        .map((item) => Post.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Post> createPost(
    String content,
    String? imageUrl,
    Uint8List? imageBytes,
  ) async {
    final formData = FormData.fromMap({'content': content});

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final metadata = _buildImageUploadMetadata(
        imageBytes,
        prefix: 'post',
      );
      formData.files.add(
        MapEntry(
          'image',
          MultipartFile.fromBytes(
            imageBytes,
            filename: metadata.fileName,
            contentType: metadata.contentType,
          ),
        ),
      );
    }

    final response = await _dio.post(
      '/posts',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60)),
    );
    return Post.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Post?> getPost(int postId) async {
    final response = await _dio.get('/posts/$postId');
    return Post.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Post> toggleLike(int postId) async {
    final response = await _dio.post('/posts/$postId/like');
    return Post.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deletePost(int postId) async {
    await _dio.delete('/posts/$postId');
  }

  @override
  Future<List<Comment>> getComments(int postId) async {
    final response = await _dio.get('/posts/$postId/comments');
    return (response.data as List<dynamic>)
        .map((item) => Comment.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Comment> createComment(
    int postId,
    String content, {
    int? parentCommentId,
  }) async {
    final response = await _dio.post(
      '/posts/$postId/comments',
      data: {
        'content': content,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      },
    );
    return Comment.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Comment> updateComment(
    int postId,
    int commentId,
    String content,
  ) async {
    final response = await _dio.put(
      '/posts/$postId/comments/$commentId',
      data: {'content': content},
    );
    return Comment.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteComment(int postId, int commentId) async {
    await _dio.delete('/posts/$postId/comments/$commentId');
  }

  @override
  Future<ToggleFollowResponse> toggleFollow(int userId) async {
    final response = await _dio.post('/follows/$userId');
    return ToggleFollowResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<Follow>> getFollowing(int userId) async {
    final response = await _dio.get('/follows/$userId/following');
    return (response.data as List<dynamic>)
        .map((item) => Follow.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<Follow>> getFollowers(int userId) async {
    final response = await _dio.get('/follows/$userId/followers');
    return (response.data as List<dynamic>)
        .map((item) => Follow.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<Follow>> getFollowings() async {
    final response = await _dio.get('/follows/followings');
    return (response.data as List<dynamic>)
        .map((item) => Follow.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<Follow>> getFollowersList() async {
    final response = await _dio.get('/follows/followers');
    return (response.data as List<dynamic>)
        .map((item) => Follow.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<bool> isFollowing(int userId) async {
    final response = await _dio.get('/follows/check/$userId');
    return response.data as bool;
  }

  @override
  Future<int> getFollowersCount(int userId) async {
    final response = await _dio.get('/follows/$userId/followers/count');
    return response.data as int;
  }

  @override
  Future<List<FriendRequestModel>> getIncomingFollowRequests() async {
    final response = await _dio.get('/follows/requests');
    return (response.data as List<dynamic>)
        .map((item) => FriendRequestModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> approveFollowRequest(int requestId) async {
    await _dio.post('/follows/requests/$requestId/approve');
  }

  @override
  Future<void> rejectFollowRequest(int requestId) async {
    await _dio.post('/follows/requests/$requestId/reject');
  }

  @override
  Future<PagedResponse<DiscoverUser>> getUsers({
    String? query,
    int page = 1,
    int pageSize = 24,
    int? limit,
  }) async {
    final normalizedQuery = query?.trim();
    final hasQuery = normalizedQuery != null && normalizedQuery.isNotEmpty;
    final effectivePageSize = limit ?? pageSize;
    final response = await _dio.get(
      hasQuery ? '/users/search' : '/users',
      queryParameters: {
        if (hasQuery) 'q': normalizedQuery,
        'page': page,
        'pageSize': effectivePageSize,
      },
    );
    return PagedResponse<DiscoverUser>.fromJson(
      response.data as Map<String, dynamic>,
      (json) => (json as List<dynamic>)
          .map((item) => DiscoverUser.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<List<FriendUser>> getFriends() async {
    final response = await _dio.get('/friends');
    return (response.data as List<dynamic>)
        .map((item) => FriendUser.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<BlockedUserModel>> getBlockedUsers() async {
    final response = await _dio.get('/chat/blocked-users');
    return (response.data as List<dynamic>)
        .map((item) => BlockedUserModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<FriendRequestModel>> getIncomingFriendRequests() async {
    final response = await _dio.get('/friends/requests/incoming');
    return (response.data as List<dynamic>)
        .map((item) => FriendRequestModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<FriendRequestModel>> getOutgoingFriendRequests() async {
    final response = await _dio.get('/friends/requests/outgoing');
    return (response.data as List<dynamic>)
        .map((item) => FriendRequestModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> sendFriendRequest(int userId) async {
    await _dio.post('/friends/requests/$userId');
  }

  @override
  Future<void> acceptFriendRequest(int requestId) async {
    await _dio.post('/friends/requests/$requestId/accept');
  }

  @override
  Future<void> deleteFriendRequest(int requestId) async {
    await _dio.delete('/friends/requests/$requestId');
  }

  @override
  Future<void> removeFriend(int userId) async {
    await _dio.delete('/friends/$userId');
  }

  @override
  Future<List<ConversationModel>> getConversations() async {
    final response = await _dio.get('/conversations');
    return (response.data as List<dynamic>)
        .map((item) => ConversationModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<DirectConversationModel> getOrCreateConversation(int userId) async {
    final response = await _dio.post('/conversations/direct/$userId');
    return DirectConversationModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<ChatMessagePageModel> getMessages(
    int conversationId, {
    int limit = 20,
    int? beforeMessageId,
  }) async {
    final response = await _dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {
        'limit': limit,
        if (beforeMessageId != null) 'beforeMessageId': beforeMessageId,
      },
    );
    return ChatMessagePageModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ChatMessageModel> sendMessage(
    int conversationId,
    String? content, {
    int? replyToMessageId,
    List<ChatUploadAttachment> attachments = const [],
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      if (content != null && content.trim().isNotEmpty) 'content': content.trim(),
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (attachments.isNotEmpty)
        'attachmentKinds': attachments
            .map((attachment) => attachment.isImage ? 'image' : 'file')
            .toList(growable: false),
    });

    for (final attachment in attachments) {
      formData.files.add(
        MapEntry(
          'files',
          MultipartFile.fromBytes(
            attachment.bytes,
            filename: attachment.fileName,
            contentType: _mediaTypeFromContentType(attachment.contentType),
          ),
        ),
      );
    }

    final response = await _dio.post(
      '/conversations/$conversationId/messages',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(sendTimeout: const Duration(seconds: 90)),
    );
    return ChatMessageModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ChatMessageModel> forwardMessage(
    int conversationId,
    int messageId,
  ) async {
    final response = await _dio.post(
      '/conversations/$conversationId/messages/forward',
      data: {'messageId': messageId},
    );
    return ChatMessageModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ChatMessageModel> updateMessage(
    int conversationId,
    int messageId,
    String content,
  ) async {
    final response = await _dio.put(
      '/conversations/$conversationId/messages/$messageId',
      data: {'content': content},
    );
    return ChatMessageModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteMessage(int conversationId, int messageId) async {
    await _dio.delete('/conversations/$conversationId/messages/$messageId');
  }

  @override
  Future<void> deleteMessageForAll(int conversationId, int messageId) async {
    await _dio.post(
      '/message/delete-for-all',
      data: {'conversationId': conversationId, 'messageId': messageId},
    );
  }

  @override
  Future<void> pinConversation(int conversationId, bool isPinned) async {
    await _dio.post(
      '/chat/pin',
      data: {'conversationId': conversationId, 'isPinned': isPinned},
    );
  }

  @override
  Future<void> archiveConversation(int conversationId, bool isArchived) async {
    await _dio.post(
      '/chat/archive',
      data: {'conversationId': conversationId, 'isArchived': isArchived},
    );
  }

  @override
  Future<void> favoriteConversation(int conversationId, bool isFavorite) async {
    await _dio.post(
      '/chat/favorite',
      data: {'conversationId': conversationId, 'isFavorite': isFavorite},
    );
  }

  @override
  Future<void> muteConversation(int conversationId, bool isMuted) async {
    await _dio.post(
      '/chat/mute',
      data: {'conversationId': conversationId, 'isMuted': isMuted},
    );
  }

  @override
  Future<void> deleteConversation(
    int conversationId, {
    required bool deleteForBoth,
  }) async {
    await _dio.delete(
      '/chat',
      data: {'conversationId': conversationId, 'deleteForBoth': deleteForBoth},
    );
  }

  @override
  Future<void> clearConversationHistory(int conversationId) async {
    await _dio.post(
      '/chat/clear-history',
      data: {'conversationId': conversationId},
    );
  }

  @override
  Future<void> blockUserFromChat(int userId) async {
    await _dio.post('/chat/block-user', data: {'userId': userId});
  }

  @override
  Future<void> unblockUserFromChat(int userId) async {
    await _dio.post('/chat/unblock-user', data: {'userId': userId});
  }

  @override
  Future<void> sendTypingStart(int conversationId) async {
    await _dio.post('/chat/typing-start', data: {'conversationId': conversationId});
  }

  @override
  Future<void> sendTypingStop(int conversationId) async {
    await _dio.post('/chat/typing-stop', data: {'conversationId': conversationId});
  }

  @override
  Future<PagedResponse<NotificationItemModel>> getNotifications({
    int page = 1,
    int pageSize = 30,
  }) async {
    final response = await _dio.get(
      '/notifications',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PagedResponse<NotificationItemModel>.fromJson(
      response.data as Map<String, dynamic>,
      (json) => (json as List<dynamic>)
          .map(
            (item) =>
                NotificationItemModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<NotificationSummaryModel> getNotificationSummary() async {
    final response = await _dio.get('/notifications/summary');
    return NotificationSummaryModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<void> markNotificationRead(int notificationId) async {
    await _dio.post('/notifications/$notificationId/read');
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _dio.post('/notifications/read-all');
  }

  @override
  Future<void> registerPushToken({
    required String deviceId,
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    await _dio.post(
      '/notifications/push-token',
      data: {
        'deviceId': deviceId,
        'token': token,
        'platform': platform,
        if (deviceName != null) 'deviceName': deviceName,
        if (appVersion != null) 'appVersion': appVersion,
      },
    );
  }

  @override
  Future<void> removePushToken(String deviceId) async {
    await _dio.delete(
      '/notifications/push-token',
      data: {'deviceId': deviceId},
    );
  }

  @override
  Future<ReportDetailModel> createReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? customNote,
  }) async {
    final response = await _dio.post(
      '/reports',
      data: {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (customNote != null && customNote.trim().isNotEmpty)
          'customNote': customNote.trim(),
      },
    );
    return ReportDetailModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PagedResponse<ReportItemModel>> getReports({
    int page = 1,
    int pageSize = 30,
  }) async {
    final response = await _dio.get(
      '/moderation/reports',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PagedResponse<ReportItemModel>.fromJson(
      response.data as Map<String, dynamic>,
      (json) => (json as List<dynamic>)
          .map((item) => ReportItemModel.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<ReportDetailModel> getReport(int id) async {
    final response = await _dio.get('/moderation/reports/$id');
    return ReportDetailModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> assignReport(int reportId, int moderatorUserId) async {
    await _dio.post(
      '/moderation/reports/$reportId/assign',
      data: {'moderatorUserId': moderatorUserId},
    );
  }

  @override
  Future<void> resolveReport(
    int reportId, {
    required String resolution,
    String? resolutionNote,
    DateTime? suspensionUntil,
  }) async {
    await _dio.post(
      '/moderation/reports/$reportId/resolve',
      data: {
        'resolution': resolution,
        if (resolutionNote != null && resolutionNote.trim().isNotEmpty)
          'resolutionNote': resolutionNote.trim(),
        if (suspensionUntil != null)
          'suspensionUntil': suspensionUntil.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<ModerationActionModel> warnUser(
    int userId,
    String note, {
    int? reportId,
  }) async {
    final response = await _dio.post(
      '/moderation/actions/warn',
      data: {
        'userId': userId,
        'note': note,
        if (reportId != null) 'reportId': reportId,
      },
    );
    return ModerationActionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ModerationActionModel> suspendUser(
    int userId,
    DateTime until,
    String note, {
    int? reportId,
  }) async {
    final response = await _dio.post(
      '/moderation/actions/suspend',
      data: {
        'userId': userId,
        'until': until.toUtc().toIso8601String(),
        'note': note,
        if (reportId != null) 'reportId': reportId,
      },
    );
    return ModerationActionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ModerationActionModel> banUser(
    int userId,
    String note, {
    int? reportId,
  }) async {
    final response = await _dio.post(
      '/moderation/actions/ban',
      data: {
        'userId': userId,
        'note': note,
        if (reportId != null) 'reportId': reportId,
      },
    );
    return ModerationActionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ModerationActionModel> unbanUser(
    int userId, {
    String? note,
    int? reportId,
  }) async {
    final response = await _dio.post(
      '/moderation/actions/unban',
      data: {
        'userId': userId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (reportId != null) 'reportId': reportId,
      },
    );
    return ModerationActionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> assignModerator(int userId) async {
    await _dio.post('/admin/roles/moderators/$userId');
  }

  @override
  Future<void> removeModerator(int userId) async {
    await _dio.delete('/admin/roles/moderators/$userId');
  }

  String _formatFormDouble(double value, {double fallback = 0}) {
    final normalized = value.isFinite ? value : fallback;
    return normalized.toStringAsFixed(4);
  }

  _ImageUploadMetadata _buildImageUploadMetadata(
    Uint8List bytes, {
    required String prefix,
  }) {
    final format = _detectImageFormat(bytes);
    final extension = switch (format) {
      _ImageUploadFormat.jpeg => 'jpg',
      _ImageUploadFormat.png => 'png',
      _ImageUploadFormat.gif => 'gif',
      _ImageUploadFormat.webp => 'webp',
      _ImageUploadFormat.unknown => 'jpg',
    };
    final contentType = switch (format) {
      _ImageUploadFormat.jpeg => MediaType('image', 'jpeg'),
      _ImageUploadFormat.png => MediaType('image', 'png'),
      _ImageUploadFormat.gif => MediaType('image', 'gif'),
      _ImageUploadFormat.webp => MediaType('image', 'webp'),
      _ImageUploadFormat.unknown => MediaType('image', 'jpeg'),
    };

    return _ImageUploadMetadata(
      fileName: '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension',
      contentType: contentType,
    );
  }

  _ImageUploadFormat _detectImageFormat(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return _ImageUploadFormat.jpeg;
    }

    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return _ImageUploadFormat.png;
    }

    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x39 || bytes[4] == 0x37) &&
        bytes[5] == 0x61) {
      return _ImageUploadFormat.gif;
    }

    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return _ImageUploadFormat.webp;
    }

    return _ImageUploadFormat.unknown;
  }

  MediaType? _mediaTypeFromContentType(String contentType) {
    final normalized = contentType.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final baseType = normalized.split(';').first.trim();
    final parts = baseType.split('/');
    if (parts.length != 2) {
      return null;
    }

    return MediaType(parts[0], parts[1]);
  }
}

enum _ImageUploadFormat { jpeg, png, gif, webp, unknown }

class _ImageUploadMetadata {
  final String fileName;
  final MediaType contentType;

  const _ImageUploadMetadata({
    required this.fileName,
    required this.contentType,
  });
}

class PagedResponse<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasPrevious;
  final bool hasNext;

  const PagedResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.hasPrevious,
    required this.hasNext,
  });

  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    List<T> Function(Object? json) itemsFactory,
  ) {
    return PagedResponse<T>(
      items: itemsFactory(json['items']),
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      hasPrevious: json['hasPrevious'] as bool? ?? false,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }
}

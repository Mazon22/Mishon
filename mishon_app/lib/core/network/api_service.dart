import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/auth_model.dart';
import '../models/post_model.dart';
import '../models/social_models.dart';

abstract class ApiService {
  Future<AuthResponse> register(String username, String email, String password);
  Future<AuthResponse> login(String email, String password);
  Future<AuthResponse> refreshToken(String refreshToken);
  Future<UserProfile> getProfile();
  Future<UserProfile> getUserProfile(int userId);
  Future<bool> checkUsernameAvailability(String username);
  Future<UserProfile> updateProfile({String? username, String? aboutMe});
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

  Future<List<DiscoverUser>> getUsers({String? query, int limit = 24});
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

  Future<List<NotificationItemModel>> getNotifications();
  Future<NotificationSummaryModel> getNotificationSummary();
  Future<void> markNotificationRead(int notificationId);
  Future<void> markAllNotificationsRead();
}

class ApiServiceImpl implements ApiService {
  final Dio _dio;

  ApiServiceImpl(this._dio);

  @override
  Future<AuthResponse> register(
    String username,
    String email,
    String password,
  ) async {
    final response = await _dio.post(
      '/auth/register',
      data: {'username': username, 'email': email, 'password': password},
    );
    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<AuthResponse> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<AuthResponse> refreshToken(String refreshToken) async {
    final response = await _dio.post(
      '/auth/refresh-token',
      data: {'refreshToken': refreshToken},
    );
    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<UserProfile> getProfile() async {
    final response = await _dio.get('/auth/profile');
    return UserProfile.fromJson(response.data);
  }

  @override
  Future<UserProfile> getUserProfile(int userId) async {
    final response = await _dio.get('/auth/profile/$userId');
    return UserProfile.fromJson(response.data);
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
  Future<UserProfile> updateProfile({String? username, String? aboutMe}) async {
    final response = await _dio.put(
      '/auth/profile',
      data: {if (username != null) 'username': username, 'aboutMe': aboutMe},
    );
    return UserProfile.fromJson(response.data);
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
      formData.files.add(
        MapEntry(
          'avatar',
          MultipartFile.fromBytes(
            avatarBytes,
            filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        ),
      );
    }

    if (bannerBytes != null && bannerBytes.isNotEmpty) {
      formData.files.add(
        MapEntry(
          'banner',
          MultipartFile.fromBytes(
            bannerBytes,
            filename: 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        ),
      );
    }

    final response = await _dio.put(
      '/auth/profile/media',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60)),
    );
    return UserProfile.fromJson(response.data);
  }

  String _formatFormDouble(double value, {double fallback = 0}) {
    final safeValue = value.isFinite ? value : fallback;
    final rounded = (safeValue * 10000).round() / 10000;
    return rounded.toString();
  }

  @override
  Future<void> logout() async {
    await _dio.post('/auth/logout');
  }

  @override
  Future<PagedResponse<Post>> getFeed({int page = 1, int pageSize = 10}) async {
    final response = await _dio.get(
      '/feed',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PagedResponse<Post>.fromJson(
      response.data,
      (json) => (json as List).map((e) => Post.fromJson(e)).toList(),
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
      response.data,
      (json) => (json as List).map((e) => Post.fromJson(e)).toList(),
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
    return (response.data as List).map((e) => Post.fromJson(e)).toList();
  }

  @override
  Future<Post> createPost(
    String content,
    String? imageUrl,
    Uint8List? imageBytes,
  ) async {
    final formData = FormData.fromMap({'content': content});

    if (imageBytes != null && imageBytes.isNotEmpty) {
      formData.files.add(
        MapEntry(
          'image',
          MultipartFile.fromBytes(
            imageBytes,
            filename: 'post_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        ),
      );
    }

    final response = await _dio.post(
      '/posts',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60)),
    );
    return Post.fromJson(response.data);
  }

  @override
  Future<Post?> getPost(int postId) async {
    final response = await _dio.get('/posts/$postId');
    return Post.fromJson(response.data);
  }

  @override
  Future<Post> toggleLike(int postId) async {
    final response = await _dio.post('/posts/$postId/like');
    return Post.fromJson(response.data);
  }

  @override
  Future<void> deletePost(int postId) async {
    await _dio.delete('/posts/$postId');
  }

  @override
  Future<List<Comment>> getComments(int postId) async {
    final response = await _dio.get('/posts/$postId/comments');
    return (response.data as List).map((e) => Comment.fromJson(e)).toList();
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
    return Comment.fromJson(response.data);
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
    return Comment.fromJson(response.data);
  }

  @override
  Future<void> deleteComment(int postId, int commentId) async {
    await _dio.delete('/posts/$postId/comments/$commentId');
  }

  @override
  Future<ToggleFollowResponse> toggleFollow(int userId) async {
    final response = await _dio.post('/follows/$userId');
    return ToggleFollowResponse.fromJson(response.data);
  }

  @override
  Future<List<Follow>> getFollowing(int userId) async {
    final response = await _dio.get('/follows/$userId/following');
    return (response.data as List).map((e) => Follow.fromJson(e)).toList();
  }

  @override
  Future<List<Follow>> getFollowers(int userId) async {
    final response = await _dio.get('/follows/$userId/followers');
    return (response.data as List).map((e) => Follow.fromJson(e)).toList();
  }

  @override
  Future<List<Follow>> getFollowings() async {
    final response = await _dio.get('/follows/followings');
    return (response.data as List).map((e) => Follow.fromJson(e)).toList();
  }

  @override
  Future<List<Follow>> getFollowersList() async {
    final response = await _dio.get('/follows/followers');
    return (response.data as List).map((e) => Follow.fromJson(e)).toList();
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
  Future<List<DiscoverUser>> getUsers({String? query, int limit = 24}) async {
    final normalizedQuery = query?.trim();
    final hasQuery = normalizedQuery != null && normalizedQuery.isNotEmpty;
    final response = await _dio.get(
      hasQuery ? '/users/search' : '/users',
      queryParameters: {
        if (hasQuery)
          'q': normalizedQuery
        else if (normalizedQuery != null)
          'query': normalizedQuery,
        'limit': limit,
      },
    );
    return (response.data as List)
        .map((e) => DiscoverUser.fromJson(e))
        .toList();
  }

  @override
  Future<List<FriendUser>> getFriends() async {
    final response = await _dio.get('/friends');
    return (response.data as List).map((e) => FriendUser.fromJson(e)).toList();
  }

  @override
  Future<List<BlockedUserModel>> getBlockedUsers() async {
    final response = await _dio.get('/chat/blocked-users');
    return (response.data as List)
        .map((e) => BlockedUserModel.fromJson(e))
        .toList();
  }

  @override
  Future<List<FriendRequestModel>> getIncomingFriendRequests() async {
    final response = await _dio.get('/friends/requests/incoming');
    return (response.data as List)
        .map((e) => FriendRequestModel.fromJson(e))
        .toList();
  }

  @override
  Future<List<FriendRequestModel>> getOutgoingFriendRequests() async {
    final response = await _dio.get('/friends/requests/outgoing');
    return (response.data as List)
        .map((e) => FriendRequestModel.fromJson(e))
        .toList();
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
    return (response.data as List)
        .map((e) => ConversationModel.fromJson(e))
        .toList();
  }

  @override
  Future<DirectConversationModel> getOrCreateConversation(int userId) async {
    final response = await _dio.post('/conversations/direct/$userId');
    return DirectConversationModel.fromJson(response.data);
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
    return ChatMessagePageModel.fromJson(response.data);
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
      if (content != null) 'content': content,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    });

    for (final attachment in attachments) {
      formData.fields.add(
        MapEntry('attachmentKinds', attachment.isImage ? 'image' : 'file'),
      );
      formData.files.add(
        MapEntry(
          'files',
          MultipartFile.fromBytes(
            attachment.bytes,
            filename: attachment.fileName,
          ),
        ),
      );
    }

    final response = await _dio.post(
      '/conversations/$conversationId/messages',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60)),
      onSendProgress: onSendProgress,
    );
    return ChatMessageModel.fromJson(response.data);
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
    return ChatMessageModel.fromJson(response.data);
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
    return ChatMessageModel.fromJson(response.data);
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
    await _dio.post(
      '/chat/typing-start',
      data: {'conversationId': conversationId},
    );
  }

  @override
  Future<void> sendTypingStop(int conversationId) async {
    await _dio.post(
      '/chat/typing-stop',
      data: {'conversationId': conversationId},
    );
  }

  @override
  Future<List<NotificationItemModel>> getNotifications() async {
    final response = await _dio.get('/notifications');
    return (response.data as List)
        .map((e) => NotificationItemModel.fromJson(e))
        .toList();
  }

  @override
  Future<NotificationSummaryModel> getNotificationSummary() async {
    final response = await _dio.get('/notifications/summary');
    return NotificationSummaryModel.fromJson(response.data);
  }

  @override
  Future<void> markNotificationRead(int notificationId) async {
    await _dio.post('/notifications/$notificationId/read');
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _dio.post('/notifications/read-all');
  }
}

class PagedResponse<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasPrevious;
  final bool hasNext;

  PagedResponse({
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
    List<T> Function(dynamic) itemsParser,
  ) {
    return PagedResponse(
      items: itemsParser(json['items'] ?? []),
      page: json['page'] ?? 1,
      pageSize: json['pageSize'] ?? 10,
      totalCount: json['totalCount'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      hasPrevious: json['hasPrevious'] ?? false,
      hasNext: json['hasNext'] ?? false,
    );
  }
}

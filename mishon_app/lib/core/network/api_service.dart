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
  Future<UserProfile> updateProfile({String? username, String? avatarUrl});
  Future<void> logout();

  Future<PagedResponse<Post>> getFeed({int page = 1, int pageSize = 10});
  Future<List<Post>> getUserPosts(int userId, {int page = 1, int pageSize = 20});
  Future<Post> createPost(String content, String? imageUrl, Uint8List? imageBytes);
  Future<Post?> getPost(int postId);
  Future<Post> toggleLike(int postId);
  Future<void> deletePost(int postId);

  Future<List<Comment>> getComments(int postId);
  Future<Comment> createComment(int postId, String content);

  Future<ToggleFollowResponse> toggleFollow(int userId);
  Future<List<Follow>> getFollowing(int userId);
  Future<List<Follow>> getFollowers(int userId);
  Future<List<Follow>> getFollowings();
  Future<List<Follow>> getFollowersList();
  Future<bool> isFollowing(int userId);
  Future<int> getFollowersCount(int userId);

  Future<List<DiscoverUser>> getUsers({String? query, int limit = 24});
  Future<List<FriendUser>> getFriends();
  Future<List<FriendRequestModel>> getIncomingFriendRequests();
  Future<List<FriendRequestModel>> getOutgoingFriendRequests();
  Future<void> sendFriendRequest(int userId);
  Future<void> acceptFriendRequest(int requestId);
  Future<void> deleteFriendRequest(int requestId);
  Future<void> removeFriend(int userId);

  Future<List<ConversationModel>> getConversations();
  Future<DirectConversationModel> getOrCreateConversation(int userId);
  Future<List<ChatMessageModel>> getMessages(int conversationId);
  Future<ChatMessageModel> sendMessage(int conversationId, String content);
}

class ApiServiceImpl implements ApiService {
  final Dio _dio;

  ApiServiceImpl(this._dio);

  @override
  Future<AuthResponse> register(String username, String email, String password) async {
    final response = await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<AuthResponse> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<AuthResponse> refreshToken(String refreshToken) async {
    final response = await _dio.post('/auth/refresh-token', data: {
      'refreshToken': refreshToken,
    });
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
  Future<UserProfile> updateProfile({String? username, String? avatarUrl}) async {
    final response = await _dio.put('/auth/profile', data: {
      if (username != null) 'username': username,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return UserProfile.fromJson(response.data);
  }

  @override
  Future<void> logout() async {
    await _dio.post('/auth/logout');
  }

  @override
  Future<PagedResponse<Post>> getFeed({int page = 1, int pageSize = 10}) async {
    final response = await _dio.get('/posts', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    return PagedResponse<Post>.fromJson(
      response.data,
      (json) => (json as List).map((e) => Post.fromJson(e)).toList(),
    );
  }

  @override
  Future<List<Post>> getUserPosts(int userId, {int page = 1, int pageSize = 20}) async {
    final response = await _dio.get('/posts/user/$userId', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    return (response.data as List).map((e) => Post.fromJson(e)).toList();
  }

  @override
  Future<Post> createPost(String content, String? imageUrl, Uint8List? imageBytes) async {
    final formData = FormData.fromMap({'content': content});

    if (imageBytes != null && imageBytes.isNotEmpty) {
      formData.files.add(MapEntry(
        'image',
        MultipartFile.fromBytes(
          imageBytes,
          filename: 'post_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      ));
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
  Future<Comment> createComment(int postId, String content) async {
    final response = await _dio.post('/posts/$postId/comments', data: {
      'content': content,
    });
    return Comment.fromJson(response.data);
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
    final response = await _dio.get('/users', queryParameters: {
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      'limit': limit,
    });
    return (response.data as List).map((e) => DiscoverUser.fromJson(e)).toList();
  }

  @override
  Future<List<FriendUser>> getFriends() async {
    final response = await _dio.get('/friends');
    return (response.data as List).map((e) => FriendUser.fromJson(e)).toList();
  }

  @override
  Future<List<FriendRequestModel>> getIncomingFriendRequests() async {
    final response = await _dio.get('/friends/requests/incoming');
    return (response.data as List).map((e) => FriendRequestModel.fromJson(e)).toList();
  }

  @override
  Future<List<FriendRequestModel>> getOutgoingFriendRequests() async {
    final response = await _dio.get('/friends/requests/outgoing');
    return (response.data as List).map((e) => FriendRequestModel.fromJson(e)).toList();
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
    return (response.data as List).map((e) => ConversationModel.fromJson(e)).toList();
  }

  @override
  Future<DirectConversationModel> getOrCreateConversation(int userId) async {
    final response = await _dio.post('/conversations/direct/$userId');
    return DirectConversationModel.fromJson(response.data);
  }

  @override
  Future<List<ChatMessageModel>> getMessages(int conversationId) async {
    final response = await _dio.get('/conversations/$conversationId/messages');
    return (response.data as List).map((e) => ChatMessageModel.fromJson(e)).toList();
  }

  @override
  Future<ChatMessageModel> sendMessage(int conversationId, String content) async {
    final response = await _dio.post('/conversations/$conversationId/messages', data: {
      'content': content,
    });
    return ChatMessageModel.fromJson(response.data);
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

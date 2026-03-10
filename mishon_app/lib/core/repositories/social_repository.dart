import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/social_models.dart';
import '../network/api_service.dart';
import '../network/exceptions.dart';
import 'auth_repository.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(apiService: ref.watch(apiServiceProvider));
});

class SocialRepository {
  final ApiService _apiService;
  final _logger = Logger();

  SocialRepository({required ApiService apiService}) : _apiService = apiService;

  Future<List<DiscoverUser>> getUsers({String? query, int limit = 24}) async {
    try {
      return await _apiService.getUsers(query: query, limit: limit);
    } on ApiException catch (e) {
      _logger.e('Get users failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting users');
      rethrow;
    }
  }

  Future<List<FriendUser>> getFriends() async {
    try {
      return await _apiService.getFriends();
    } on ApiException catch (e) {
      _logger.e('Get friends failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting friends');
      rethrow;
    }
  }

  Future<List<FriendRequestModel>> getIncomingFriendRequests() async {
    try {
      return await _apiService.getIncomingFriendRequests();
    } on ApiException catch (e) {
      _logger.e('Get incoming friend requests failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting incoming friend requests');
      rethrow;
    }
  }

  Future<List<FriendRequestModel>> getOutgoingFriendRequests() async {
    try {
      return await _apiService.getOutgoingFriendRequests();
    } on ApiException catch (e) {
      _logger.e('Get outgoing friend requests failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting outgoing friend requests');
      rethrow;
    }
  }

  Future<void> sendFriendRequest(int userId) async {
    try {
      await _apiService.sendFriendRequest(userId);
    } on ApiException catch (e) {
      _logger.e('Send friend request failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection sending friend request');
      rethrow;
    }
  }

  Future<void> acceptFriendRequest(int requestId) async {
    try {
      await _apiService.acceptFriendRequest(requestId);
    } on ApiException catch (e) {
      _logger.e('Accept friend request failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection accepting friend request');
      rethrow;
    }
  }

  Future<void> deleteFriendRequest(int requestId) async {
    try {
      await _apiService.deleteFriendRequest(requestId);
    } on ApiException catch (e) {
      _logger.e('Delete friend request failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection deleting friend request');
      rethrow;
    }
  }

  Future<void> removeFriend(int userId) async {
    try {
      await _apiService.removeFriend(userId);
    } on ApiException catch (e) {
      _logger.e('Remove friend failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection removing friend');
      rethrow;
    }
  }

  Future<List<ConversationModel>> getConversations() async {
    try {
      return await _apiService.getConversations();
    } on ApiException catch (e) {
      _logger.e('Get conversations failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting conversations');
      rethrow;
    }
  }

  Future<DirectConversationModel> getOrCreateConversation(int userId) async {
    try {
      return await _apiService.getOrCreateConversation(userId);
    } on ApiException catch (e) {
      _logger.e('Get or create conversation failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection opening conversation');
      rethrow;
    }
  }

  Future<List<ChatMessageModel>> getMessages(int conversationId) async {
    try {
      return await _apiService.getMessages(conversationId);
    } on ApiException catch (e) {
      _logger.e('Get messages failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting messages');
      rethrow;
    }
  }

  Future<ChatMessageModel> sendMessage(int conversationId, String content) async {
    try {
      return await _apiService.sendMessage(conversationId, content);
    } on ApiException catch (e) {
      _logger.e('Send message failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection sending message');
      rethrow;
    }
  }
}

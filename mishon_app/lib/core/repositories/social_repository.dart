import 'package:dio/dio.dart';
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

  Future<ChatMessageModel> sendMessage(int conversationId, String content, {int? replyToMessageId}) async {
    try {
      return await _apiService.sendMessage(
        conversationId,
        content,
        replyToMessageId: replyToMessageId,
      );
    } on ApiException catch (e) {
      _logger.e('Send message failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection sending message');
      rethrow;
    }
  }

  Future<ChatMessageModel> updateMessage(int conversationId, int messageId, String content) async {
    try {
      return await _apiService.updateMessage(conversationId, messageId, content);
    } on ApiException catch (e) {
      _logger.e('Update message failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection updating message');
      rethrow;
    }
  }

  Future<void> deleteMessage(int conversationId, int messageId) async {
    try {
      await _apiService.deleteMessage(conversationId, messageId);
    } on ApiException catch (e) {
      _logger.e('Delete message failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection deleting message');
      rethrow;
    }
  }

  Future<List<NotificationItemModel>> getNotifications() async {
    try {
      return await _apiService.getNotifications();
    } on ApiException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w('Notifications endpoint is unavailable on the current backend build');
        return const [];
      }
      _logger.e('Get notifications failed: ${e.apiError.message}');
      rethrow;
    } on DioException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w('Notifications endpoint is unavailable on the current backend build');
        return const [];
      }
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting notifications');
      rethrow;
    }
  }

  Future<NotificationSummaryModel> getNotificationSummary() async {
    try {
      return await _apiService.getNotificationSummary();
    } on ApiException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w('Notification summary endpoint is unavailable on the current backend build');
        return _emptyNotificationSummary;
      }
      _logger.e('Get notification summary failed: ${e.apiError.message}');
      rethrow;
    } on DioException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w('Notification summary endpoint is unavailable on the current backend build');
        return _emptyNotificationSummary;
      }
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting notification summary');
      rethrow;
    }
  }

  Future<void> markNotificationRead(int notificationId) async {
    try {
      await _apiService.markNotificationRead(notificationId);
    } on ApiException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w('Skipping mark notification read because endpoint is unavailable');
        return;
      }
      _logger.e('Mark notification read failed: ${e.apiError.message}');
      rethrow;
    } on DioException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w('Skipping mark notification read because endpoint is unavailable');
        return;
      }
      rethrow;
    } on OfflineException {
      _logger.w('No connection marking notification read');
      rethrow;
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _apiService.markAllNotificationsRead();
    } on ApiException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w('Skipping mark all notifications read because endpoint is unavailable');
        return;
      }
      _logger.e('Mark all notifications read failed: ${e.apiError.message}');
      rethrow;
    } on DioException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w('Skipping mark all notifications read because endpoint is unavailable');
        return;
      }
      rethrow;
    } on OfflineException {
      _logger.w('No connection marking all notifications read');
      rethrow;
    }
  }

  static const _emptyNotificationSummary = NotificationSummaryModel(
    unreadNotifications: 0,
    unreadChats: 0,
    incomingFriendRequests: 0,
  );

  bool _isNotificationsEndpointMissing(Object error) {
    if (error is ApiException) {
      return error.statusCode == 404 || error.apiError.statusCode == 404;
    }

    if (error is DioException) {
      return error.response?.statusCode == 404;
    }

    return false;
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/social_models.dart';
import '../network/api_service.dart';
import '../network/exceptions.dart';
import 'memory_cache.dart';
import 'auth_repository.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(apiService: ref.watch(apiServiceProvider));
});

class SocialRepository {
  static const _cacheTtl = Duration(minutes: 2);
  static final Map<String, MemoryCacheEntry<List<DiscoverUser>>>
  _discoverUsersCache = <String, MemoryCacheEntry<List<DiscoverUser>>>{};
  static MemoryCacheEntry<List<FriendUser>>? _friendsCache;
  static MemoryCacheEntry<List<FriendRequestModel>>? _incomingRequestsCache;
  static MemoryCacheEntry<List<FriendRequestModel>>? _outgoingRequestsCache;
  static MemoryCacheEntry<List<ConversationModel>>? _conversationsCache;
  static MemoryCacheEntry<List<NotificationItemModel>>? _notificationsCache;
  static MemoryCacheEntry<NotificationSummaryModel>? _notificationSummaryCache;

  final ApiService _apiService;
  final _logger = Logger();

  SocialRepository({required ApiService apiService}) : _apiService = apiService;

  List<DiscoverUser>? peekUsers({String? query, int limit = 24}) {
    final cache = _discoverUsersCache[_discoverKey(query, limit)];
    if (cache == null || !cache.isFresh(_cacheTtl)) {
      return null;
    }

    return cache.value;
  }

  List<FriendUser>? peekFriends() {
    final cache = _friendsCache;
    if (cache == null || !cache.isFresh(_cacheTtl)) {
      return null;
    }

    return cache.value;
  }

  List<FriendRequestModel>? peekIncomingFriendRequests() {
    final cache = _incomingRequestsCache;
    if (cache == null || !cache.isFresh(_cacheTtl)) {
      return null;
    }

    return cache.value;
  }

  List<FriendRequestModel>? peekOutgoingFriendRequests() {
    final cache = _outgoingRequestsCache;
    if (cache == null || !cache.isFresh(_cacheTtl)) {
      return null;
    }

    return cache.value;
  }

  List<ConversationModel>? peekConversations() {
    final cache = _conversationsCache;
    if (cache == null || !cache.isFresh(_cacheTtl)) {
      return null;
    }

    return cache.value;
  }

  List<NotificationItemModel>? peekNotifications() {
    final cache = _notificationsCache;
    if (cache == null || !cache.isFresh(_cacheTtl)) {
      return null;
    }

    return cache.value;
  }

  NotificationSummaryModel? peekNotificationSummary() {
    final cache = _notificationSummaryCache;
    if (cache == null || !cache.isFresh(_cacheTtl)) {
      return null;
    }

    return cache.value;
  }

  Future<List<DiscoverUser>> prefetchDiscovery({int limit = 48}) {
    return getUsers(limit: limit, forceRefresh: true);
  }

  Future<void> prefetchFriendsBundle() async {
    await Future.wait<Object?>([
      getFriends(forceRefresh: true),
      getIncomingFriendRequests(forceRefresh: true),
      getOutgoingFriendRequests(forceRefresh: true),
    ]);
  }

  Future<List<ConversationModel>> prefetchConversations() {
    return getConversations(forceRefresh: true);
  }

  Future<List<NotificationItemModel>> prefetchNotifications() {
    return getNotifications(forceRefresh: true);
  }

  Future<List<DiscoverUser>> getUsers({
    String? query,
    int limit = 24,
    bool forceRefresh = false,
  }) async {
    final cachedUsers =
        !forceRefresh ? peekUsers(query: query, limit: limit) : null;
    if (cachedUsers != null) {
      return cachedUsers;
    }

    try {
      final users = await _apiService.getUsers(query: query, limit: limit);
      _discoverUsersCache[_discoverKey(
        query,
        limit,
      )] = MemoryCacheEntry<List<DiscoverUser>>.now(
        List<DiscoverUser>.unmodifiable(users),
      );
      return users;
    } on ApiException catch (e) {
      _logger.e('Get users failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting users');
      rethrow;
    }
  }

  Future<List<FriendUser>> getFriends({bool forceRefresh = false}) async {
    final cachedFriends = !forceRefresh ? peekFriends() : null;
    if (cachedFriends != null) {
      return cachedFriends;
    }

    try {
      final friends = await _apiService.getFriends();
      _friendsCache = MemoryCacheEntry<List<FriendUser>>.now(
        List<FriendUser>.unmodifiable(friends),
      );
      return friends;
    } on ApiException catch (e) {
      _logger.e('Get friends failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting friends');
      rethrow;
    }
  }

  Future<List<FriendRequestModel>> getIncomingFriendRequests({
    bool forceRefresh = false,
  }) async {
    final cachedRequests = !forceRefresh ? peekIncomingFriendRequests() : null;
    if (cachedRequests != null) {
      return cachedRequests;
    }

    try {
      final requests = await _apiService.getIncomingFriendRequests();
      _incomingRequestsCache = MemoryCacheEntry<List<FriendRequestModel>>.now(
        List<FriendRequestModel>.unmodifiable(requests),
      );
      return requests;
    } on ApiException catch (e) {
      _logger.e('Get incoming friend requests failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting incoming friend requests');
      rethrow;
    }
  }

  Future<List<FriendRequestModel>> getOutgoingFriendRequests({
    bool forceRefresh = false,
  }) async {
    final cachedRequests = !forceRefresh ? peekOutgoingFriendRequests() : null;
    if (cachedRequests != null) {
      return cachedRequests;
    }

    try {
      final requests = await _apiService.getOutgoingFriendRequests();
      _outgoingRequestsCache = MemoryCacheEntry<List<FriendRequestModel>>.now(
        List<FriendRequestModel>.unmodifiable(requests),
      );
      return requests;
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
      _invalidatePeopleCaches();
      _outgoingRequestsCache = null;
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
      _invalidatePeopleCaches();
      _friendsCache = null;
      _incomingRequestsCache = null;
      _outgoingRequestsCache = null;
      _notificationSummaryCache = null;
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
      _invalidatePeopleCaches();
      _incomingRequestsCache = null;
      _outgoingRequestsCache = null;
      _notificationSummaryCache = null;
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
      _invalidatePeopleCaches();
      _friendsCache = null;
    } on ApiException catch (e) {
      _logger.e('Remove friend failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection removing friend');
      rethrow;
    }
  }

  Future<List<ConversationModel>> getConversations({
    bool forceRefresh = false,
  }) async {
    final cachedConversations = !forceRefresh ? peekConversations() : null;
    if (cachedConversations != null) {
      return cachedConversations;
    }

    try {
      final conversations = await _apiService.getConversations();
      _conversationsCache = MemoryCacheEntry<List<ConversationModel>>.now(
        List<ConversationModel>.unmodifiable(conversations),
      );
      return conversations;
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
      final conversation = await _apiService.getOrCreateConversation(userId);
      _conversationsCache = null;
      return conversation;
    } on ApiException catch (e) {
      _logger.e('Get or create conversation failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection opening conversation');
      rethrow;
    }
  }

  Future<ChatMessagePageModel> getMessages(
    int conversationId, {
    int limit = 20,
    int? beforeMessageId,
  }) async {
    try {
      return await _apiService.getMessages(
        conversationId,
        limit: limit,
        beforeMessageId: beforeMessageId,
      );
    } on ApiException catch (e) {
      _logger.e('Get messages failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting messages');
      rethrow;
    }
  }

  Future<ChatMessageModel> sendMessage(
    int conversationId,
    String? content, {
    int? replyToMessageId,
    List<ChatUploadAttachment> attachments = const [],
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      return await _apiService.sendMessage(
        conversationId,
        content,
        replyToMessageId: replyToMessageId,
        attachments: attachments,
        onSendProgress: onSendProgress,
      );
    } on ApiException catch (e) {
      _logger.e('Send message failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection sending message');
      rethrow;
    }
  }

  Future<ChatMessageModel> updateMessage(
    int conversationId,
    int messageId,
    String content,
  ) async {
    try {
      return await _apiService.updateMessage(
        conversationId,
        messageId,
        content,
      );
    } on ApiException catch (e) {
      _logger.e('Update message failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection updating message');
      rethrow;
    }
  }

  Future<ChatMessageModel> forwardMessage(
    int conversationId,
    int messageId,
  ) async {
    try {
      return await _apiService.forwardMessage(conversationId, messageId);
    } on ApiException catch (e) {
      _logger.e('Forward message failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection forwarding message');
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

  Future<void> deleteMessageForAll(int conversationId, int messageId) async {
    try {
      await _apiService.deleteMessageForAll(conversationId, messageId);
    } on ApiException catch (e) {
      _logger.e('Delete message for all failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection deleting message for all');
      rethrow;
    }
  }

  Future<void> pinConversation(int conversationId, bool isPinned) async {
    try {
      await _apiService.pinConversation(conversationId, isPinned);
      _conversationsCache = null;
    } on ApiException catch (e) {
      _logger.e('Pin conversation failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection pinning conversation');
      rethrow;
    }
  }

  Future<void> archiveConversation(int conversationId, bool isArchived) async {
    try {
      await _apiService.archiveConversation(conversationId, isArchived);
      _conversationsCache = null;
    } on ApiException catch (e) {
      _logger.e('Archive conversation failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection archiving conversation');
      rethrow;
    }
  }

  Future<void> favoriteConversation(int conversationId, bool isFavorite) async {
    try {
      await _apiService.favoriteConversation(conversationId, isFavorite);
      _conversationsCache = null;
    } on ApiException catch (e) {
      _logger.e('Favorite conversation failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection favoriting conversation');
      rethrow;
    }
  }

  Future<void> muteConversation(int conversationId, bool isMuted) async {
    try {
      await _apiService.muteConversation(conversationId, isMuted);
      _conversationsCache = null;
    } on ApiException catch (e) {
      _logger.e('Mute conversation failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection muting conversation');
      rethrow;
    }
  }

  Future<void> deleteConversation(
    int conversationId, {
    required bool deleteForBoth,
  }) async {
    try {
      await _apiService.deleteConversation(
        conversationId,
        deleteForBoth: deleteForBoth,
      );
      _conversationsCache = null;
    } on ApiException catch (e) {
      _logger.e('Delete conversation failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection deleting conversation');
      rethrow;
    }
  }

  Future<void> clearConversationHistory(int conversationId) async {
    try {
      await _apiService.clearConversationHistory(conversationId);
      _conversationsCache = null;
    } on ApiException catch (e) {
      _logger.e('Clear conversation history failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection clearing conversation history');
      rethrow;
    }
  }

  Future<void> blockUserFromChat(int userId) async {
    try {
      await _apiService.blockUserFromChat(userId);
    } on ApiException catch (e) {
      _logger.e('Block user from chat failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection blocking user from chat');
      rethrow;
    }
  }

  Future<void> unblockUserFromChat(int userId) async {
    try {
      await _apiService.unblockUserFromChat(userId);
    } on ApiException catch (e) {
      _logger.e('Unblock user from chat failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection unblocking user from chat');
      rethrow;
    }
  }

  Future<void> sendTypingStart(int conversationId) async {
    try {
      await _apiService.sendTypingStart(conversationId);
    } on ApiException catch (e) {
      _logger.e('Typing start failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection sending typing start');
      rethrow;
    }
  }

  Future<void> sendTypingStop(int conversationId) async {
    try {
      await _apiService.sendTypingStop(conversationId);
    } on ApiException catch (e) {
      _logger.e('Typing stop failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection sending typing stop');
      rethrow;
    }
  }

  Future<List<NotificationItemModel>> getNotifications({
    bool forceRefresh = false,
  }) async {
    final cachedNotifications = !forceRefresh ? peekNotifications() : null;
    if (cachedNotifications != null) {
      return cachedNotifications;
    }

    try {
      final notifications = await _apiService.getNotifications();
      _notificationsCache = MemoryCacheEntry<List<NotificationItemModel>>.now(
        List<NotificationItemModel>.unmodifiable(notifications),
      );
      return notifications;
    } on ApiException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w(
          'Notifications endpoint is unavailable on the current backend build',
        );
        return const [];
      }
      _logger.e('Get notifications failed: ${e.apiError.message}');
      rethrow;
    } on DioException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w(
          'Notifications endpoint is unavailable on the current backend build',
        );
        return const [];
      }
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting notifications');
      rethrow;
    }
  }

  Future<NotificationSummaryModel> getNotificationSummary({
    bool forceRefresh = false,
  }) async {
    final cachedSummary = !forceRefresh ? peekNotificationSummary() : null;
    if (cachedSummary != null) {
      return cachedSummary;
    }

    try {
      final summary = await _apiService.getNotificationSummary();
      _notificationSummaryCache =
          MemoryCacheEntry<NotificationSummaryModel>.now(summary);
      return summary;
    } on ApiException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w(
          'Notification summary endpoint is unavailable on the current backend build',
        );
        return _emptyNotificationSummary;
      }
      _logger.e('Get notification summary failed: ${e.apiError.message}');
      rethrow;
    } on DioException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w(
          'Notification summary endpoint is unavailable on the current backend build',
        );
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
      _notificationsCache = null;
      _notificationSummaryCache = null;
    } on ApiException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w(
          'Skipping mark notification read because endpoint is unavailable',
        );
        return;
      }
      _logger.e('Mark notification read failed: ${e.apiError.message}');
      rethrow;
    } on DioException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w(
          'Skipping mark notification read because endpoint is unavailable',
        );
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
      _notificationsCache = null;
      _notificationSummaryCache = null;
    } on ApiException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w(
          'Skipping mark all notifications read because endpoint is unavailable',
        );
        return;
      }
      _logger.e('Mark all notifications read failed: ${e.apiError.message}');
      rethrow;
    } on DioException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w(
          'Skipping mark all notifications read because endpoint is unavailable',
        );
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

  static String _discoverKey(String? query, int limit) {
    return '${query ?? ''}|$limit';
  }

  void _invalidatePeopleCaches() {
    _discoverUsersCache.clear();
  }
}

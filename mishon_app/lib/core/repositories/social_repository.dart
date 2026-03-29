import 'package:flutter/foundation.dart';
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
  static final Map<String, MemoryCacheEntry<PagedResponse<DiscoverUser>>>
  _discoverUserPagesCache =
      <String, MemoryCacheEntry<PagedResponse<DiscoverUser>>>{};
  static MemoryCacheEntry<List<FriendUser>>? _friendsCache;
  static MemoryCacheEntry<List<BlockedUserModel>>? _blockedUsersCache;
  static MemoryCacheEntry<List<FriendRequestModel>>? _incomingRequestsCache;
  static MemoryCacheEntry<List<FriendRequestModel>>? _outgoingRequestsCache;
  static MemoryCacheEntry<List<FriendRequestModel>>? _incomingFollowRequestsCache;
  static MemoryCacheEntry<List<ConversationModel>>? _conversationsCache;
  static MemoryCacheEntry<List<NotificationItemModel>>? _notificationsCache;
  static final Map<String, MemoryCacheEntry<PagedResponse<NotificationItemModel>>>
  _notificationPagesCache =
      <String, MemoryCacheEntry<PagedResponse<NotificationItemModel>>>{};
  static MemoryCacheEntry<NotificationSummaryModel>? _notificationSummaryCache;
  static final Map<String, MemoryCacheEntry<PagedResponse<ReportItemModel>>>
  _reportPagesCache = <String, MemoryCacheEntry<PagedResponse<ReportItemModel>>>{};

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

  List<BlockedUserModel>? peekBlockedUsers() {
    final cache = _blockedUsersCache;
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

  PagedResponse<DiscoverUser>? peekUsersPage({
    String? query,
    int page = 1,
    int pageSize = 24,
  }) {
    final cache = _discoverUserPagesCache[_discoverPageKey(query, page, pageSize)];
    if (cache == null || !cache.isFresh(_cacheTtl)) {
      return null;
    }

    return cache.value;
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
      final response = await getUsersPage(
        query: query,
        pageSize: limit,
        forceRefresh: forceRefresh,
        limit: limit,
      );
      final users = response.items;
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

  Future<PagedResponse<DiscoverUser>> getUsersPage({
    String? query,
    int page = 1,
    int pageSize = 24,
    int? limit,
    bool forceRefresh = false,
  }) async {
    final effectivePageSize = limit ?? pageSize;
    final cachedPage =
        !forceRefresh
            ? peekUsersPage(
              query: query,
              page: page,
              pageSize: effectivePageSize,
            )
            : null;
    if (cachedPage != null) {
      return cachedPage;
    }

    try {
      final response = await _apiService.getUsers(
        query: query,
        page: page,
        pageSize: effectivePageSize,
        limit: limit,
      );
      _discoverUserPagesCache[_discoverPageKey(
        query,
        page,
        effectivePageSize,
      )] = MemoryCacheEntry<PagedResponse<DiscoverUser>>.now(response);
      return response;
    } on ApiException catch (e) {
      _logger.e('Get users page failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting users page');
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

  Future<List<BlockedUserModel>> getBlockedUsers({
    bool forceRefresh = false,
  }) async {
    final cachedBlockedUsers = !forceRefresh ? peekBlockedUsers() : null;
    if (cachedBlockedUsers != null) {
      return cachedBlockedUsers;
    }

    try {
      final blockedUsers = await _apiService.getBlockedUsers();
      _blockedUsersCache = MemoryCacheEntry<List<BlockedUserModel>>.now(
        List<BlockedUserModel>.unmodifiable(blockedUsers),
      );
      return blockedUsers;
    } on ApiException catch (e) {
      _logger.e('Get blocked users failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting blocked users');
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
      _conversationsCache = null;
      _blockedUsersCache = null;
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
      _conversationsCache = null;
      _blockedUsersCache = null;
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

  PagedResponse<NotificationItemModel>? peekNotificationsPage({
    int page = 1,
    int pageSize = 30,
  }) {
    final cache = _notificationPagesCache[_notificationPageKey(page, pageSize)];
    if (cache == null || !cache.isFresh(_cacheTtl)) {
      return null;
    }

    return cache.value;
  }

  Future<List<NotificationItemModel>> getNotifications({
    bool forceRefresh = false,
    int page = 1,
    int pageSize = 30,
  }) async {
    final cachedNotifications =
        !forceRefresh && page == 1 && pageSize == 30 ? peekNotifications() : null;
    if (cachedNotifications != null) {
      return cachedNotifications;
    }

    final response = await getNotificationsPage(
      page: page,
      pageSize: pageSize,
      forceRefresh: forceRefresh,
    );
    if (page == 1) {
      _notificationsCache = MemoryCacheEntry<List<NotificationItemModel>>.now(
        List<NotificationItemModel>.unmodifiable(response.items),
      );
    }
    return response.items;
  }

  Future<PagedResponse<NotificationItemModel>> getNotificationsPage({
    int page = 1,
    int pageSize = 30,
    bool forceRefresh = false,
  }) async {
    final cachedPage =
        !forceRefresh ? peekNotificationsPage(page: page, pageSize: pageSize) : null;
    if (cachedPage != null) {
      return cachedPage;
    }

    try {
      final response = await _apiService.getNotifications(
        page: page,
        pageSize: pageSize,
      );
      _notificationPagesCache[_notificationPageKey(page, pageSize)] =
          MemoryCacheEntry<PagedResponse<NotificationItemModel>>.now(response);
      return response;
    } on ApiException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w(
          'Notifications endpoint is unavailable on the current backend build',
        );
        return const PagedResponse(
          items: <NotificationItemModel>[],
          page: 1,
          pageSize: 30,
          totalCount: 0,
          totalPages: 0,
          hasPrevious: false,
          hasNext: false,
        );
      }
      _logger.e('Get notifications failed: ${e.apiError.message}');
      rethrow;
    } on DioException catch (e) {
      if (_isNotificationsEndpointMissing(e)) {
        _logger.w(
          'Notifications endpoint is unavailable on the current backend build',
        );
        return const PagedResponse(
          items: <NotificationItemModel>[],
          page: 1,
          pageSize: 30,
          totalCount: 0,
          totalPages: 0,
          hasPrevious: false,
          hasNext: false,
        );
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
      _notificationPagesCache.clear();
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
      _notificationPagesCache.clear();
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

  Future<List<FriendRequestModel>> getIncomingFollowRequests({
    bool forceRefresh = false,
  }) async {
    final cachedRequests =
        !forceRefresh &&
                _incomingFollowRequestsCache != null &&
                _incomingFollowRequestsCache!.isFresh(_cacheTtl)
            ? _incomingFollowRequestsCache!.value
            : null;
    if (cachedRequests != null) {
      return cachedRequests;
    }

    try {
      final requests = await _apiService.getIncomingFollowRequests();
      _incomingFollowRequestsCache =
          MemoryCacheEntry<List<FriendRequestModel>>.now(
        List<FriendRequestModel>.unmodifiable(requests),
      );
      return requests;
    } on ApiException catch (e) {
      _logger.e('Get incoming follow requests failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting incoming follow requests');
      rethrow;
    }
  }

  Future<void> approveFollowRequest(int requestId) async {
    await _apiService.approveFollowRequest(requestId);
    _incomingFollowRequestsCache = null;
    _notificationSummaryCache = null;
    _notificationPagesCache.clear();
    _invalidatePeopleCaches();
  }

  Future<void> rejectFollowRequest(int requestId) async {
    await _apiService.rejectFollowRequest(requestId);
    _incomingFollowRequestsCache = null;
    _notificationSummaryCache = null;
    _notificationPagesCache.clear();
    _invalidatePeopleCaches();
  }

  Future<void> registerPushToken({
    required String deviceId,
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) {
    return _apiService.registerPushToken(
      deviceId: deviceId,
      token: token,
      platform: platform,
      deviceName: deviceName,
      appVersion: appVersion,
    );
  }

  Future<void> removePushToken(String deviceId) {
    return _apiService.removePushToken(deviceId);
  }

  PagedResponse<ReportItemModel>? peekReportsPage({
    int page = 1,
    int pageSize = 30,
  }) {
    final cache = _reportPagesCache[_reportPageKey(page, pageSize)];
    if (cache == null || !cache.isFresh(_cacheTtl)) {
      return null;
    }

    return cache.value;
  }

  Future<PagedResponse<ReportItemModel>> getReportsPage({
    int page = 1,
    int pageSize = 30,
    bool forceRefresh = false,
  }) async {
    final cachedPage =
        !forceRefresh ? peekReportsPage(page: page, pageSize: pageSize) : null;
    if (cachedPage != null) {
      return cachedPage;
    }

    final response = await _apiService.getReports(page: page, pageSize: pageSize);
    _reportPagesCache[_reportPageKey(page, pageSize)] =
        MemoryCacheEntry<PagedResponse<ReportItemModel>>.now(response);
    return response;
  }

  Future<ReportDetailModel> createReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? customNote,
  }) {
    return _apiService.createReport(
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      customNote: customNote,
    );
  }

  Future<ReportDetailModel> getReport(int id) => _apiService.getReport(id);

  Future<void> assignReport(int reportId, int moderatorUserId) async {
    await _apiService.assignReport(reportId, moderatorUserId);
    _reportPagesCache.clear();
  }

  Future<void> resolveReport(
    int reportId, {
    required String resolution,
    String? resolutionNote,
    DateTime? suspensionUntil,
  }) async {
    await _apiService.resolveReport(
      reportId,
      resolution: resolution,
      resolutionNote: resolutionNote,
      suspensionUntil: suspensionUntil,
    );
    _reportPagesCache.clear();
  }

  Future<ModerationActionModel> warnUser(
    int userId,
    String note, {
    int? reportId,
  }) {
    return _apiService.warnUser(userId, note, reportId: reportId);
  }

  Future<ModerationActionModel> suspendUser(
    int userId,
    DateTime until,
    String note, {
    int? reportId,
  }) {
    return _apiService.suspendUser(userId, until, note, reportId: reportId);
  }

  Future<ModerationActionModel> banUser(
    int userId,
    String note, {
    int? reportId,
  }) {
    return _apiService.banUser(userId, note, reportId: reportId);
  }

  Future<ModerationActionModel> unbanUser(
    int userId, {
    String? note,
    int? reportId,
  }) {
    return _apiService.unbanUser(userId, note: note, reportId: reportId);
  }

  Future<void> assignModerator(int userId) async {
    await _apiService.assignModerator(userId);
    _reportPagesCache.clear();
  }

  Future<void> removeModerator(int userId) async {
    await _apiService.removeModerator(userId);
    _reportPagesCache.clear();
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

  static String _discoverPageKey(String? query, int page, int pageSize) {
    return '${query ?? ''}|$page|$pageSize';
  }

  static String _notificationPageKey(int page, int pageSize) {
    return '$page|$pageSize';
  }

  static String _reportPageKey(int page, int pageSize) {
    return '$page|$pageSize';
  }

  void _invalidatePeopleCaches() {
    _discoverUsersCache.clear();
    _discoverUserPagesCache.clear();
  }

  @visibleForTesting
  static void resetCachesForTest() {
    _discoverUsersCache.clear();
    _discoverUserPagesCache.clear();
    _friendsCache = null;
    _blockedUsersCache = null;
    _incomingRequestsCache = null;
    _outgoingRequestsCache = null;
    _incomingFollowRequestsCache = null;
    _conversationsCache = null;
    _notificationsCache = null;
    _notificationPagesCache.clear();
    _notificationSummaryCache = null;
    _reportPagesCache.clear();
  }
}

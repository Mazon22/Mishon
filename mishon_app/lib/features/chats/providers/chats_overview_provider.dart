import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';

const _chatsErrorSentinel = Object();

@immutable
class ChatsOverviewState {
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final String searchQuery;
  final bool favoritesOnly;
  final bool showArchived;
  final List<ConversationModel> conversations;
  final Set<int> busyConversationIds;

  const ChatsOverviewState({
    required this.isLoading,
    required this.isRefreshing,
    required this.errorMessage,
    required this.searchQuery,
    required this.favoritesOnly,
    required this.showArchived,
    required this.conversations,
    required this.busyConversationIds,
  });

  const ChatsOverviewState.initial()
    : isLoading = true,
      isRefreshing = false,
      errorMessage = null,
      searchQuery = '',
      favoritesOnly = false,
      showArchived = false,
      conversations = const <ConversationModel>[],
      busyConversationIds = const <int>{};

  ChatsOverviewState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    Object? errorMessage = _chatsErrorSentinel,
    String? searchQuery,
    bool? favoritesOnly,
    bool? showArchived,
    List<ConversationModel>? conversations,
    Set<int>? busyConversationIds,
  }) {
    return ChatsOverviewState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage:
          identical(errorMessage, _chatsErrorSentinel)
              ? this.errorMessage
              : errorMessage as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      showArchived: showArchived ?? this.showArchived,
      conversations: conversations ?? this.conversations,
      busyConversationIds: busyConversationIds ?? this.busyConversationIds,
    );
  }
}

final chatsOverviewControllerProvider =
    NotifierProvider<ChatsOverviewController, ChatsOverviewState>(
      ChatsOverviewController.new,
    );

class ChatsOverviewController extends Notifier<ChatsOverviewState> {
  var _didInitialize = false;

  @override
  ChatsOverviewState build() {
    final cachedConversations =
        ref.read(socialRepositoryProvider).peekConversations();
    final initialState =
        cachedConversations == null
            ? const ChatsOverviewState.initial()
            : const ChatsOverviewState.initial().copyWith(
              isLoading: false,
              conversations: cachedConversations,
            );

    if (!_didInitialize) {
      _didInitialize = true;
      Future<void>.microtask(
        () => load(forceRefresh: cachedConversations == null, silent: true),
      );
    }

    return initialState;
  }

  Future<void> load({bool forceRefresh = true, bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(
        isLoading: state.conversations.isEmpty,
        isRefreshing: state.conversations.isNotEmpty,
        errorMessage: null,
      );
    }

    try {
      final conversations = await ref
          .read(socialRepositoryProvider)
          .getConversations(forceRefresh: forceRefresh);
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: null,
        conversations: conversations,
      );
    } catch (error) {
      if (silent && state.conversations.isNotEmpty) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await load(forceRefresh: true);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  void toggleFavoritesOnly() {
    state = state.copyWith(favoritesOnly: !state.favoritesOnly);
  }

  void toggleShowArchived() {
    state = state.copyWith(showArchived: !state.showArchived);
  }

  Future<void> pinConversation(ConversationModel conversation) async {
    await _runConversationAction(
      conversation.id,
      () => ref
          .read(socialRepositoryProvider)
          .pinConversation(conversation.id, !conversation.isPinned),
    );
  }

  Future<void> archiveConversation(ConversationModel conversation) async {
    await _runConversationAction(
      conversation.id,
      () => ref
          .read(socialRepositoryProvider)
          .archiveConversation(conversation.id, !conversation.isArchived),
    );
  }

  Future<void> favoriteConversation(ConversationModel conversation) async {
    await _runConversationAction(
      conversation.id,
      () => ref
          .read(socialRepositoryProvider)
          .favoriteConversation(conversation.id, !conversation.isFavorite),
    );
  }

  Future<void> muteConversation(ConversationModel conversation) async {
    await _runConversationAction(
      conversation.id,
      () => ref
          .read(socialRepositoryProvider)
          .muteConversation(conversation.id, !conversation.isMuted),
    );
  }

  Future<void> deleteConversation(
    int conversationId, {
    required bool deleteForBoth,
  }) async {
    await _runConversationAction(
      conversationId,
      () => ref
          .read(socialRepositoryProvider)
          .deleteConversation(conversationId, deleteForBoth: deleteForBoth),
    );
  }

  Future<void> blockUser(ConversationModel conversation) async {
    await _runConversationAction(
      conversation.id,
      () => ref
          .read(socialRepositoryProvider)
          .blockUserFromChat(conversation.peerId),
    );
  }

  Future<void> _runConversationAction(
    int conversationId,
    Future<void> Function() action,
  ) async {
    final nextBusyIds = Set<int>.from(state.busyConversationIds)
      ..add(conversationId);
    state = state.copyWith(busyConversationIds: nextBusyIds);

    try {
      await action();
      final conversations = await ref
          .read(socialRepositoryProvider)
          .getConversations(forceRefresh: true);
      state = state.copyWith(conversations: conversations);
    } finally {
      final busyIds = Set<int>.from(state.busyConversationIds)
        ..remove(conversationId);
      state = state.copyWith(busyConversationIds: busyIds);
    }
  }
}

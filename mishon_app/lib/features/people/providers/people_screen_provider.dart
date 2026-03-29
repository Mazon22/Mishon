import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';

const _peopleErrorSentinel = Object();

@immutable
class PeopleScreenState {
  final bool isBootstrapping;
  final bool isRefreshing;
  final String? errorMessage;
  final List<DiscoverUser> directoryUsers;
  final bool isLoadingMoreDirectory;
  final bool hasMoreDirectory;
  final int nextDirectoryPage;
  final String searchQuery;
  final bool isSearchLoading;
  final bool isLoadingMoreSearch;
  final bool hasMoreSearch;
  final int nextSearchPage;
  final String? searchErrorMessage;
  final List<DiscoverUser> searchResults;
  final Set<int> busyUserIds;

  const PeopleScreenState({
    required this.isBootstrapping,
    required this.isRefreshing,
    required this.errorMessage,
    required this.directoryUsers,
    required this.isLoadingMoreDirectory,
    required this.hasMoreDirectory,
    required this.nextDirectoryPage,
    required this.searchQuery,
    required this.isSearchLoading,
    required this.isLoadingMoreSearch,
    required this.hasMoreSearch,
    required this.nextSearchPage,
    required this.searchErrorMessage,
    required this.searchResults,
    required this.busyUserIds,
  });

  const PeopleScreenState.initial()
    : isBootstrapping = true,
      isRefreshing = false,
      errorMessage = null,
      directoryUsers = const <DiscoverUser>[],
      isLoadingMoreDirectory = false,
      hasMoreDirectory = false,
      nextDirectoryPage = 1,
      searchQuery = '',
      isSearchLoading = false,
      isLoadingMoreSearch = false,
      hasMoreSearch = false,
      nextSearchPage = 1,
      searchErrorMessage = null,
      searchResults = const <DiscoverUser>[],
      busyUserIds = const <int>{};

  bool get isSearching => searchQuery.isNotEmpty;

  PeopleScreenState copyWith({
    bool? isBootstrapping,
    bool? isRefreshing,
    Object? errorMessage = _peopleErrorSentinel,
    List<DiscoverUser>? directoryUsers,
    bool? isLoadingMoreDirectory,
    bool? hasMoreDirectory,
    int? nextDirectoryPage,
    String? searchQuery,
    bool? isSearchLoading,
    bool? isLoadingMoreSearch,
    bool? hasMoreSearch,
    int? nextSearchPage,
    Object? searchErrorMessage = _peopleErrorSentinel,
    List<DiscoverUser>? searchResults,
    Set<int>? busyUserIds,
  }) {
    return PeopleScreenState(
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage:
          identical(errorMessage, _peopleErrorSentinel)
              ? this.errorMessage
              : errorMessage as String?,
      directoryUsers: directoryUsers ?? this.directoryUsers,
      isLoadingMoreDirectory:
          isLoadingMoreDirectory ?? this.isLoadingMoreDirectory,
      hasMoreDirectory: hasMoreDirectory ?? this.hasMoreDirectory,
      nextDirectoryPage: nextDirectoryPage ?? this.nextDirectoryPage,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchLoading: isSearchLoading ?? this.isSearchLoading,
      isLoadingMoreSearch: isLoadingMoreSearch ?? this.isLoadingMoreSearch,
      hasMoreSearch: hasMoreSearch ?? this.hasMoreSearch,
      nextSearchPage: nextSearchPage ?? this.nextSearchPage,
      searchErrorMessage:
          identical(searchErrorMessage, _peopleErrorSentinel)
              ? this.searchErrorMessage
              : searchErrorMessage as String?,
      searchResults: searchResults ?? this.searchResults,
      busyUserIds: busyUserIds ?? this.busyUserIds,
    );
  }
}

final peopleScreenControllerProvider =
    NotifierProvider<PeopleScreenController, PeopleScreenState>(
      PeopleScreenController.new,
    );

class PeopleScreenController extends Notifier<PeopleScreenState> {
  static const _directoryPageSize = 24;
  static const _searchPageSize = 24;

  var _didInitialize = false;
  var _searchRequestVersion = 0;

  @override
  PeopleScreenState build() {
    final cachedUsers = ref
        .read(socialRepositoryProvider)
        .peekUsers(limit: _directoryPageSize);
    final initialState =
        cachedUsers == null
            ? const PeopleScreenState.initial()
            : const PeopleScreenState.initial().copyWith(
              isBootstrapping: false,
              directoryUsers: cachedUsers,
              nextDirectoryPage: 2,
            );

    if (!_didInitialize) {
      _didInitialize = true;
      Future<void>.microtask(
        () => loadDiscovery(forceRefresh: cachedUsers == null),
      );
    }

    return initialState;
  }

  Future<void> loadDiscovery({
    bool forceRefresh = true,
    bool silent = false,
  }) async {
    if (!silent) {
      state = state.copyWith(
        isBootstrapping: state.directoryUsers.isEmpty,
        isRefreshing: state.directoryUsers.isNotEmpty,
        errorMessage: null,
      );
    }

    try {
      final response = await ref.read(socialRepositoryProvider).getUsersPage(
            page: 1,
            pageSize: _directoryPageSize,
            forceRefresh: forceRefresh,
          );
      state = state.copyWith(
        isBootstrapping: false,
        isRefreshing: false,
        errorMessage: null,
        directoryUsers: _normalizeUsers(response.items),
        hasMoreDirectory: response.hasNext,
        nextDirectoryPage: response.page + 1,
      );
    } catch (error) {
      if (silent && state.directoryUsers.isNotEmpty) {
        return;
      }

      state = state.copyWith(
        isBootstrapping: false,
        isRefreshing: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> loadMoreDiscovery() async {
    if (state.isLoadingMoreDirectory || !state.hasMoreDirectory) {
      return;
    }

    state = state.copyWith(isLoadingMoreDirectory: true);
    try {
      final response = await ref.read(socialRepositoryProvider).getUsersPage(
            page: state.nextDirectoryPage,
            pageSize: _directoryPageSize,
          );
      state = state.copyWith(
        isLoadingMoreDirectory: false,
        directoryUsers: <DiscoverUser>[
          ...state.directoryUsers,
          ..._normalizeUsers(response.items),
        ],
        hasMoreDirectory: response.hasNext,
        nextDirectoryPage: response.page + 1,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMoreDirectory: false);
    }
  }

  Future<void> refresh() async {
    await loadDiscovery(forceRefresh: true);
    if (state.isSearching) {
      await setSearchQuery(state.searchQuery, forceRefresh: true);
    }
  }

  Future<void> setSearchQuery(String query, {bool forceRefresh = false}) async {
    final normalizedQuery = query.trim();
    final requestVersion = ++_searchRequestVersion;

    if (normalizedQuery.isEmpty) {
      state = state.copyWith(
        searchQuery: '',
        isSearchLoading: false,
        isLoadingMoreSearch: false,
        hasMoreSearch: false,
        nextSearchPage: 1,
        searchErrorMessage: null,
        searchResults: const <DiscoverUser>[],
      );
      return;
    }

    state = state.copyWith(
      searchQuery: normalizedQuery,
      isSearchLoading: true,
      isLoadingMoreSearch: false,
      searchErrorMessage: null,
    );

    try {
      final response = await ref.read(socialRepositoryProvider).getUsersPage(
            query: normalizedQuery,
            page: 1,
            pageSize: _searchPageSize,
            forceRefresh: forceRefresh,
          );
      if (requestVersion != _searchRequestVersion) {
        return;
      }

      state = state.copyWith(
        isSearchLoading: false,
        hasMoreSearch: response.hasNext,
        nextSearchPage: response.page + 1,
        searchErrorMessage: null,
        searchResults: _normalizeUsers(response.items),
      );
    } catch (error) {
      if (requestVersion != _searchRequestVersion) {
        return;
      }

      state = state.copyWith(
        isSearchLoading: false,
        searchErrorMessage: error.toString(),
        searchResults: const <DiscoverUser>[],
      );
    }
  }

  Future<void> loadMoreSearch() async {
    if (!state.isSearching || state.isLoadingMoreSearch || !state.hasMoreSearch) {
      return;
    }

    state = state.copyWith(isLoadingMoreSearch: true);
    try {
      final response = await ref.read(socialRepositoryProvider).getUsersPage(
            query: state.searchQuery,
            page: state.nextSearchPage,
            pageSize: _searchPageSize,
          );
      state = state.copyWith(
        isLoadingMoreSearch: false,
        hasMoreSearch: response.hasNext,
        nextSearchPage: response.page + 1,
        searchResults: <DiscoverUser>[
          ...state.searchResults,
          ..._normalizeUsers(response.items),
        ],
      );
    } catch (_) {
      state = state.copyWith(isLoadingMoreSearch: false);
    }
  }

  Future<void> toggleFollow(DiscoverUser user) async {
    await _runBusyAction(user.id, () async {
      final response = await ref.read(postRepositoryProvider).toggleFollow(user.id);
      _replaceUser(
        user.copyWith(
          isFollowing: response.isFollowing,
          followersCount: response.followersCount,
          hasPendingFollowRequest: response.isRequested,
          outgoingFriendRequestId:
              response.isRequested ? (user.outgoingFriendRequestId ?? -user.id) : null,
          clearOutgoingFriendRequestId: !response.isRequested,
        ),
      );
    });
  }

  Future<void> sendFriendRequest(DiscoverUser user) async {
    await _runBusyAction(user.id, () async {
      await ref.read(socialRepositoryProvider).sendFriendRequest(user.id);
      _replaceUser(user.copyWith(outgoingFriendRequestId: -user.id));
    });
  }

  Future<DirectConversationModel> openConversation(DiscoverUser user) async {
    return _runBusyAction(
      user.id,
      () => ref.read(socialRepositoryProvider).getOrCreateConversation(user.id),
    );
  }

  Future<T> _runBusyAction<T>(int userId, Future<T> Function() action) async {
    final busyIds = Set<int>.from(state.busyUserIds)..add(userId);
    state = state.copyWith(busyUserIds: busyIds);

    try {
      return await action();
    } finally {
      final nextBusyIds = Set<int>.from(state.busyUserIds)..remove(userId);
      state = state.copyWith(busyUserIds: nextBusyIds);
    }
  }

  void _replaceUser(DiscoverUser updatedUser) {
    final nextDirectory = state.directoryUsers
        .map((user) => user.id == updatedUser.id ? updatedUser : user)
        .toList(growable: false);
    final nextSearchResults = state.searchResults
        .map((user) => user.id == updatedUser.id ? updatedUser : user)
        .toList(growable: false);

    state = state.copyWith(
      directoryUsers: nextDirectory,
      searchResults: nextSearchResults,
    );
  }

  List<DiscoverUser> _normalizeUsers(List<DiscoverUser> users) {
    return users.map(_normalizeUser).toList(growable: false);
  }

  DiscoverUser _normalizeUser(DiscoverUser user) {
    if (user.hasPendingFollowRequest && user.outgoingFriendRequestId == null) {
      return user.copyWith(outgoingFriendRequestId: -user.id);
    }
    return user;
  }
}

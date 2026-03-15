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
  final String searchQuery;
  final bool isSearchLoading;
  final String? searchErrorMessage;
  final List<DiscoverUser> searchResults;
  final Set<int> busyUserIds;

  const PeopleScreenState({
    required this.isBootstrapping,
    required this.isRefreshing,
    required this.errorMessage,
    required this.directoryUsers,
    required this.searchQuery,
    required this.isSearchLoading,
    required this.searchErrorMessage,
    required this.searchResults,
    required this.busyUserIds,
  });

  const PeopleScreenState.initial()
    : isBootstrapping = true,
      isRefreshing = false,
      errorMessage = null,
      directoryUsers = const <DiscoverUser>[],
      searchQuery = '',
      isSearchLoading = false,
      searchErrorMessage = null,
      searchResults = const <DiscoverUser>[],
      busyUserIds = const <int>{};

  bool get isSearching => searchQuery.isNotEmpty;

  PeopleScreenState copyWith({
    bool? isBootstrapping,
    bool? isRefreshing,
    Object? errorMessage = _peopleErrorSentinel,
    List<DiscoverUser>? directoryUsers,
    String? searchQuery,
    bool? isSearchLoading,
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
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchLoading: isSearchLoading ?? this.isSearchLoading,
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
  static const _directoryLimit = 48;
  static const _searchLimit = 24;

  var _didInitialize = false;
  var _searchRequestVersion = 0;

  @override
  PeopleScreenState build() {
    final cachedUsers = ref
        .read(socialRepositoryProvider)
        .peekUsers(limit: _directoryLimit);
    final initialState =
        cachedUsers == null
            ? const PeopleScreenState.initial()
            : const PeopleScreenState.initial().copyWith(
              isBootstrapping: false,
              directoryUsers: cachedUsers,
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
      final users = await ref
          .read(socialRepositoryProvider)
          .getUsers(limit: _directoryLimit, forceRefresh: forceRefresh);
      state = state.copyWith(
        isBootstrapping: false,
        isRefreshing: false,
        errorMessage: null,
        directoryUsers: users,
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
        searchErrorMessage: null,
        searchResults: const <DiscoverUser>[],
      );
      return;
    }

    state = state.copyWith(
      searchQuery: normalizedQuery,
      isSearchLoading: true,
      searchErrorMessage: null,
    );

    try {
      final results = await ref
          .read(socialRepositoryProvider)
          .getUsers(
            query: normalizedQuery,
            limit: _searchLimit,
            forceRefresh: forceRefresh,
          );
      if (requestVersion != _searchRequestVersion) {
        return;
      }

      state = state.copyWith(
        isSearchLoading: false,
        searchErrorMessage: null,
        searchResults: results,
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

  Future<void> toggleFollow(DiscoverUser user) async {
    await _runBusyAction(user.id, () async {
      await ref.read(postRepositoryProvider).toggleFollow(user.id);
      _replaceUser(
        user.copyWith(
          isFollowing: !user.isFollowing,
          followersCount:
              user.isFollowing
                  ? user.followersCount - 1
                  : user.followersCount + 1,
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
}

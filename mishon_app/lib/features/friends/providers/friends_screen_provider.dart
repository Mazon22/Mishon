import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';

const _friendsErrorSentinel = Object();

@immutable
class FriendsScreenState {
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final List<FriendUser> friends;
  final List<FriendRequestModel> incoming;
  final List<FriendRequestModel> outgoing;
  final Set<int> busyIds;

  const FriendsScreenState({
    required this.isLoading,
    required this.isRefreshing,
    required this.errorMessage,
    required this.friends,
    required this.incoming,
    required this.outgoing,
    required this.busyIds,
  });

  const FriendsScreenState.initial()
    : isLoading = true,
      isRefreshing = false,
      errorMessage = null,
      friends = const <FriendUser>[],
      incoming = const <FriendRequestModel>[],
      outgoing = const <FriendRequestModel>[],
      busyIds = const <int>{};

  FriendsScreenState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    Object? errorMessage = _friendsErrorSentinel,
    List<FriendUser>? friends,
    List<FriendRequestModel>? incoming,
    List<FriendRequestModel>? outgoing,
    Set<int>? busyIds,
  }) {
    return FriendsScreenState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage:
          identical(errorMessage, _friendsErrorSentinel)
              ? this.errorMessage
              : errorMessage as String?,
      friends: friends ?? this.friends,
      incoming: incoming ?? this.incoming,
      outgoing: outgoing ?? this.outgoing,
      busyIds: busyIds ?? this.busyIds,
    );
  }
}

final friendsScreenControllerProvider =
    NotifierProvider<FriendsScreenController, FriendsScreenState>(
      FriendsScreenController.new,
    );

class FriendsScreenController extends Notifier<FriendsScreenState> {
  var _didInitialize = false;

  @override
  FriendsScreenState build() {
    final repository = ref.read(socialRepositoryProvider);
    final cachedFriends = repository.peekFriends();
    final cachedIncoming = repository.peekIncomingFriendRequests();
    final cachedOutgoing = repository.peekOutgoingFriendRequests();
    final hasCachedSnapshot =
        cachedFriends != null &&
        cachedIncoming != null &&
        cachedOutgoing != null;

    final initialState =
        hasCachedSnapshot
            ? const FriendsScreenState.initial().copyWith(
              isLoading: false,
              friends: cachedFriends,
              incoming: cachedIncoming,
              outgoing: cachedOutgoing,
            )
            : const FriendsScreenState.initial();

    if (!_didInitialize) {
      _didInitialize = true;
      Future<void>.microtask(
        () => load(forceRefresh: !hasCachedSnapshot, silent: hasCachedSnapshot),
      );
    }

    return initialState;
  }

  Future<void> load({bool forceRefresh = true, bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(
        isLoading:
            state.friends.isEmpty &&
            state.incoming.isEmpty &&
            state.outgoing.isEmpty,
        isRefreshing:
            state.friends.isNotEmpty ||
            state.incoming.isNotEmpty ||
            state.outgoing.isNotEmpty,
        errorMessage: null,
      );
    }

    try {
      final repository = ref.read(socialRepositoryProvider);
      final results = await Future.wait<Object?>([
        repository.getFriends(forceRefresh: forceRefresh),
        repository.getIncomingFriendRequests(forceRefresh: forceRefresh),
        repository.getOutgoingFriendRequests(forceRefresh: forceRefresh),
      ]);
      final friends = results[0] as List<FriendUser>;
      final incoming = results[1] as List<FriendRequestModel>;
      final outgoing = results[2] as List<FriendRequestModel>;

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: null,
        friends: friends,
        incoming: incoming,
        outgoing: outgoing,
      );
    } catch (error) {
      if (silent &&
          (state.friends.isNotEmpty ||
              state.incoming.isNotEmpty ||
              state.outgoing.isNotEmpty)) {
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

  Future<void> acceptRequest(FriendRequestModel request) async {
    await _runBusyAction(request.userId, () async {
      await ref.read(socialRepositoryProvider).acceptFriendRequest(request.id);
      final newFriend = FriendUser(
        id: request.userId,
        username: request.username,
        aboutMe: request.aboutMe,
        avatarUrl: request.avatarUrl,
        avatarScale: request.avatarScale,
        avatarOffsetX: request.avatarOffsetX,
        avatarOffsetY: request.avatarOffsetY,
        lastSeenAt: request.lastSeenAt,
        isOnline: request.isOnline,
      );
      state = state.copyWith(
        incoming: state.incoming
            .where((item) => item.id != request.id)
            .toList(growable: false),
        friends: <FriendUser>[
          newFriend,
          ...state.friends.where((item) => item.id != request.userId),
        ],
      );
    });
  }

  Future<void> deleteRequest(FriendRequestModel request) async {
    await _runBusyAction(request.userId, () async {
      await ref.read(socialRepositoryProvider).deleteFriendRequest(request.id);
      state = state.copyWith(
        incoming:
            request.isIncoming
                ? state.incoming
                    .where((item) => item.id != request.id)
                    .toList(growable: false)
                : state.incoming,
        outgoing:
            request.isIncoming
                ? state.outgoing
                : state.outgoing
                    .where((item) => item.id != request.id)
                    .toList(growable: false),
      );
    });
  }

  Future<void> removeFriend(FriendUser user) async {
    await _runBusyAction(user.id, () async {
      await ref.read(socialRepositoryProvider).removeFriend(user.id);
      state = state.copyWith(
        friends: state.friends
            .where((friend) => friend.id != user.id)
            .toList(growable: false),
      );
    });
  }

  Future<DirectConversationModel> openConversation(int userId) async {
    return _runBusyAction(
      userId,
      () => ref.read(socialRepositoryProvider).getOrCreateConversation(userId),
    );
  }

  Future<T> _runBusyAction<T>(int id, Future<T> Function() action) async {
    final nextBusyIds = Set<int>.from(state.busyIds)..add(id);
    state = state.copyWith(busyIds: nextBusyIds);

    try {
      return await action();
    } finally {
      final busyIds = Set<int>.from(state.busyIds)..remove(id);
      state = state.copyWith(busyIds: busyIds);
    }
  }
}

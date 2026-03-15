import 'dart:async';

import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_provider.g.dart';

enum FeedTabType { forYou, following }

extension FeedTabTypeX on FeedTabType {
  FeedTabType get other =>
      this == FeedTabType.forYou ? FeedTabType.following : FeedTabType.forYou;
}

@riverpod
class FeedNotifier extends _$FeedNotifier {
  static const _pageSize = 20;

  late FeedTabType _feedType;
  var _currentPage = 0;
  var _hasNextPage = true;
  var _isLoadingMore = false;

  @override
  AsyncValue<List<Post>> build(FeedTabType feedType) {
    ref.keepAlive();
    _feedType = feedType;
    final repository = ref.read(postRepositoryProvider);
    final cachedPage =
        feedType == FeedTabType.forYou
            ? repository.peekFeed(pageSize: _pageSize)
            : repository.peekFollowingFeed(pageSize: _pageSize);

    if (cachedPage != null) {
      _currentPage = cachedPage.page;
      _hasNextPage = cachedPage.hasNext;
      return AsyncValue.data(cachedPage.items);
    }

    Future<void>.microtask(() => _loadFeed(forceRefresh: true));
    return const AsyncValue.loading();
  }

  Future<void> ensureLoaded() async {
    if (state.hasValue || state.isLoading) {
      return;
    }

    await _loadFeed(forceRefresh: true);
  }

  Future<void> _loadFeed({required bool forceRefresh}) async {
    state =
        state.hasValue
            ? const AsyncLoading<List<Post>>().copyWithPrevious(state)
            : const AsyncValue.loading();

    try {
      final repository = ref.read(postRepositoryProvider);
      final pagedResponse =
          _feedType == FeedTabType.forYou
              ? await repository.getFeed(
                page: 1,
                pageSize: _pageSize,
                forceRefresh: forceRefresh,
              )
              : await repository.getFollowingFeed(
                page: 1,
                pageSize: _pageSize,
                forceRefresh: forceRefresh,
              );
      _currentPage = pagedResponse.page;
      _hasNextPage = pagedResponse.hasNext;
      state = AsyncValue.data(pagedResponse.items);
    } on ApiException catch (e, st) {
      state = _withPreviousOnError(e.apiError.message, st);
    } on OfflineException catch (e, st) {
      state = _withPreviousOnError(e.message, st);
    } catch (_, st) {
      state = _withPreviousOnError('feed_load_failed', st);
    }
  }

  Future<void> refresh() async {
    await _loadFeed(forceRefresh: true);
  }

  void maybePrefetchNextPage(int visibleIndex, int totalCount) {
    if (_isLoadingMore || !_hasNextPage) {
      return;
    }

    if (totalCount == 0 || visibleIndex < totalCount - 4) {
      return;
    }

    unawaited(loadMore());
  }

  Future<void> loadMore() async {
    final currentPosts = state.valueOrNull;
    if (_isLoadingMore ||
        !_hasNextPage ||
        currentPosts == null ||
        currentPosts.isEmpty) {
      return;
    }

    _isLoadingMore = true;
    try {
      final nextPage = _currentPage + 1;
      final repository = ref.read(postRepositoryProvider);
      final pagedResponse =
          _feedType == FeedTabType.forYou
              ? await repository.getFeed(
                page: nextPage,
                pageSize: _pageSize,
                forceRefresh: true,
              )
              : await repository.getFollowingFeed(
                page: nextPage,
                pageSize: _pageSize,
                forceRefresh: true,
              );

      _currentPage = pagedResponse.page;
      _hasNextPage = pagedResponse.hasNext;
      state = AsyncValue.data(<Post>[...currentPosts, ...pagedResponse.items]);
    } catch (_) {
      // Keep already-rendered posts intact on background prefetch errors.
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> toggleLike(int postId) async {
    final posts = state.value;
    if (posts == null) {
      return;
    }

    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex == -1) {
      return;
    }

    final oldPost = posts[postIndex];
    final newLikeState = !oldPost.isLiked;
    final newLikesCount = oldPost.likesCount + (newLikeState ? 1 : -1);

    final updatedPosts = List<Post>.from(posts);
    updatedPosts[postIndex] = oldPost.copyWith(
      likesCount: newLikesCount,
      isLiked: newLikeState,
    );

    state = AsyncValue.data(updatedPosts);

    try {
      final repository = ref.read(postRepositoryProvider);
      final serverPost = await repository.toggleLike(postId);
      final latestPosts = state.value;
      if (latestPosts != null) {
        final normalizedPosts =
            latestPosts
                .map((post) => post.id == postId ? serverPost : post)
                .toList();
        state = AsyncValue.data(normalizedPosts);
      }
      ref.invalidate(feedNotifierProvider(_feedType.other));
    } catch (_) {
      state = AsyncValue.data(posts);
      rethrow;
    }
  }

  Future<void> toggleFollow(int userId) async {
    final posts = state.value;
    if (posts == null) {
      return;
    }

    final updatedPosts =
        posts
            .map(
              (post) =>
                  post.userId == userId
                      ? post.copyWith(
                        isFollowingAuthor: !post.isFollowingAuthor,
                      )
                      : post,
            )
            .toList();

    state = AsyncValue.data(updatedPosts);

    try {
      final repository = ref.read(postRepositoryProvider);
      final response = await repository.toggleFollow(userId);

      if (_feedType == FeedTabType.following && !response.isFollowing) {
        await _loadFeed(forceRefresh: true);
      } else {
        final latestPosts = state.value;
        if (latestPosts != null) {
          state = AsyncValue.data(
            latestPosts
                .map(
                  (post) =>
                      post.userId == userId
                          ? post.copyWith(
                            isFollowingAuthor: response.isFollowing,
                          )
                          : post,
                )
                .toList(),
          );
        }
      }

      ref.invalidate(feedNotifierProvider(_feedType.other));
    } catch (_) {
      state = AsyncValue.data(posts);
      rethrow;
    }
  }

  AsyncValue<List<Post>> _withPreviousOnError(
    Object error,
    StackTrace stackTrace,
  ) {
    return state.hasValue
        ? AsyncError<List<Post>>(error, stackTrace).copyWithPrevious(state)
        : AsyncValue.error(error, stackTrace);
  }
}

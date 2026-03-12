import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_provider.g.dart';

@riverpod
class FeedNotifier extends _$FeedNotifier {
  @override
  AsyncValue<List<Post>> build() {
    Future<void>.microtask(_loadFeed);
    return const AsyncValue.loading();
  }

  Future<void> _loadFeed() async {
    state =
        state.hasValue
            ? const AsyncLoading<List<Post>>().copyWithPrevious(state)
            : const AsyncValue.loading();

    try {
      final repository = ref.read(postRepositoryProvider);
      final pagedResponse = await repository.getFeed(page: 1, pageSize: 20);
      state = AsyncValue.data(pagedResponse.items);
    } on ApiException catch (e, st) {
      state = _withPreviousOnError(e.apiError.message, st);
    } on OfflineException catch (e, st) {
      state = _withPreviousOnError(e.message, st);
    } catch (_, st) {
      state = _withPreviousOnError('Failed to load feed.', st);
    }
  }

  Future<void> refresh() async {
    await _loadFeed();
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
      await repository.toggleLike(postId);
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
      await repository.toggleFollow(userId);
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

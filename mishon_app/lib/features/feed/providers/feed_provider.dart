import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';

part 'feed_provider.g.dart';

@riverpod
class FeedNotifier extends _$FeedNotifier {
  @override
  AsyncValue<List<Post>> build() {
    _loadFeed();
    return const AsyncValue.loading();
  }

  Future<void> _loadFeed() async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(postRepositoryProvider);
      final pagedResponse = await repository.getFeed(page: 1, pageSize: 20);
      state = AsyncValue.data(pagedResponse.items);
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e.apiError.message, st);
    } on OfflineException catch (e, st) {
      state = AsyncValue.error(e.message, st);
    } catch (e, st) {
      state = AsyncValue.error('Ошибка загрузки ленты', st);
    }
  }

  Future<void> refresh() async {
    await _loadFeed();
  }

  Future<void> toggleLike(int postId) async {
    final posts = state.value;
    if (posts == null) return;

    // Находим пост и обновляем оптимистично
    final postIndex = posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final oldPost = posts[postIndex];
    final newLikeState = !oldPost.isLiked;
    final newLikesCount = oldPost.likesCount + (newLikeState ? 1 : -1);

    final updatedPosts = List<Post>.from(posts);
    updatedPosts[postIndex] = Post(
      id: oldPost.id,
      userId: oldPost.userId,
      username: oldPost.username,
      userAvatarUrl: oldPost.userAvatarUrl,
      content: oldPost.content,
      imageUrl: oldPost.imageUrl,
      createdAt: oldPost.createdAt,
      likesCount: newLikesCount,
      isLiked: newLikeState,
      isFollowingAuthor: oldPost.isFollowingAuthor,
    );

    state = AsyncValue.data(updatedPosts);

    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.toggleLike(postId);
    } catch (e) {
      // Rollback при ошибке
      state = AsyncValue.data(posts);
      rethrow;
    }
  }

  Future<void> toggleFollow(int userId) async {
    final posts = state.value;
    if (posts == null) return;

    // Находим все посты этого автора и обновляем оптимистично
    final updatedPosts = posts.map((post) {
      if (post.userId == userId) {
        return post.copyWith(
          isFollowingAuthor: !post.isFollowingAuthor,
        );
      }
      return post;
    }).toList();

    state = AsyncValue.data(updatedPosts);

    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.toggleFollow(userId);
      
      // После успешного запроса можно обновить ленту для актуальных данных
      // Но не делаем этого для лучшего UX
    } catch (e) {
      // Rollback при ошибке
      state = AsyncValue.data(posts);
      rethrow;
    }
  }
}

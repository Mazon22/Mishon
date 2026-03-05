import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:logger/logger.dart';

part 'user_posts_provider.g.dart';

@riverpod
class UserPosts extends _$UserPosts {
  @override
  Future<List<Post>> build() async {
    final userId = await ref.watch(authRepositoryProvider).getUserId();
    if (userId == null) return [];

    final repository = ref.read(postRepositoryProvider);
    return await repository.getUserPosts(userId);
  }

  Future<void> deletePost(int postId) async {
    final logger = Logger();
    logger.i('Deleting post $postId');

    final currentPosts = state.value ?? [];
    state = AsyncValue.data(currentPosts.where((p) => p.id != postId).toList());

    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.deletePost(postId);
      logger.i('Post $postId deleted successfully');
    } on ApiException catch (e, st) {
      logger.e('Delete post failed: ${e.apiError.message}');
      state = AsyncValue.error(Object, st);
      rethrow;
    } on OfflineException catch (e, st) {
      logger.w('No connection deleting post');
      state = AsyncValue.error(Object, st);
      rethrow;
    } catch (e, st) {
      logger.e('Unexpected delete post error', error: e, stackTrace: st);
      state = AsyncValue.error(Object, st);
      rethrow;
    }
  }
}

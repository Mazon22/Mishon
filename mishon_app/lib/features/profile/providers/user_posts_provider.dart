import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';

part 'user_posts_provider.g.dart';

@riverpod
Future<List<Post>> userPosts(UserPostsRef ref) async {
  final userId = await ref.watch(authRepositoryProvider).getUserId();
  if (userId == null) return [];

  final repository = ref.read(postRepositoryProvider);
  return await repository.getUserPosts(userId);
}

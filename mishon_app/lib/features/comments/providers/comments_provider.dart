import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';

part 'comments_provider.g.dart';

@riverpod
class Comments extends _$Comments {
  @override
  Future<List<Comment>> build(int postId) async {
    final repository = ref.read(postRepositoryProvider);
    return await repository.getComments(postId);
  }

  Future<void> addComment(Comment comment) async {
    final currentComments = state.value ?? [];
    state = AsyncValue.data([...currentComments, comment]);
  }

  Future<void> refresh() async {
    final repository = ref.read(postRepositoryProvider);
    final comments = await repository.getComments(postId);
    state = AsyncValue.data(comments);
  }
}

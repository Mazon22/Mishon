import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:logger/logger.dart';

part 'create_post_provider.g.dart';

@riverpod
class CreatePostNotifier extends _$CreatePostNotifier {
  final _logger = Logger();

  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> createPost(String content, Uint8List? imageBytes) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.createPost(content, null, imageBytes);
      state = const AsyncValue.data(null);
      return true;
    } on ApiException catch (e, st) {
      _logger.e('Create post failed: ${e.apiError.message}');
      state = AsyncValue.error(e.apiError.message, st);
      return false;
    } on OfflineException catch (e, st) {
      _logger.w('No connection creating post');
      state = AsyncValue.error(e.message, st);
      return false;
    } catch (e, st) {
      _logger.e('Unexpected create post error', error: e, stackTrace: st);
      state = AsyncValue.error('Ошибка создания поста', st);
      return false;
    }
  }
}

@riverpod
class SelectedImage extends _$SelectedImage {
  final _picker = ImagePicker();
  final _logger = Logger();

  @override
  File? build() => null;

  Future<void> pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        state = File(image.path);
      }
    } catch (e, st) {
      _logger.e('Failed to pick image', error: e, stackTrace: st);
      state = null;
    }
  }

  void clear() {
    state = null;
  }
}

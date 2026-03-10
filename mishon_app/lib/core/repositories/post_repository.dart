import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/api_service.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';

part 'post_repository.g.dart';

@riverpod
PostRepository postRepository(Ref ref) {
  return PostRepository(apiService: ref.watch(apiServiceProvider));
}

class PostRepository {
  final ApiService _apiService;
  final _logger = Logger();

  PostRepository({required ApiService apiService}) : _apiService = apiService;

  Future<PagedResponse<Post>> getFeed({int page = 1, int pageSize = 20}) async {
    try {
      final response = await _apiService.getFeed(page: page, pageSize: pageSize);
      return PagedResponse(
        items: response.items,
        page: response.page,
        pageSize: response.pageSize,
        totalCount: response.totalCount,
        totalPages: response.totalPages,
        hasPrevious: response.hasPrevious,
        hasNext: response.hasNext,
      );
    } on ApiException catch (e) {
      _logger.e('Get feed failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting feed');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected get feed error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Post>> getUserPosts(int userId, {int page = 1, int pageSize = 20}) async {
    try {
      return await _apiService.getUserPosts(userId, page: page, pageSize: pageSize);
    } on ApiException catch (e) {
      _logger.e('Get user posts failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting user posts');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected get user posts error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Post> createPost(String content, String? imageUrl, Uint8List? imageBytes) async {
    try {
      return await _apiService.createPost(content, imageUrl, imageBytes);
    } on ApiException catch (e) {
      _logger.e('Create post failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection creating post');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected create post error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Post> toggleLike(int postId) async {
    try {
      return await _apiService.toggleLike(postId);
    } on ApiException catch (e) {
      _logger.e('Toggle like failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection toggling like');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected toggle like error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deletePost(int postId) async {
    try {
      await _apiService.deletePost(postId);
    } on ApiException catch (e) {
      _logger.e('Delete post failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection deleting post');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected delete post error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<ToggleFollowResponse> toggleFollow(int userId) async {
    try {
      return await _apiService.toggleFollow(userId);
    } on ApiException catch (e) {
      _logger.e('Toggle follow failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection toggling follow');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected toggle follow error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Follow>> getFollowing(int userId) async {
    try {
      return await _apiService.getFollowing(userId);
    } on ApiException catch (e) {
      _logger.e('Get following failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting following');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected get following error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Follow>> getFollowers(int userId) async {
    try {
      return await _apiService.getFollowers(userId);
    } on ApiException catch (e) {
      _logger.e('Get followers failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting followers');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected get followers error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Follow>> getFollowings() async {
    try {
      return await _apiService.getFollowings();
    } on ApiException catch (e) {
      _logger.e('Get followings failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting followings');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected get followings error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Comment>> getComments(int postId) async {
    try {
      return await _apiService.getComments(postId);
    } on ApiException catch (e) {
      _logger.e('Get comments failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting comments');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected get comments error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Comment> createComment(int postId, String content, {int? parentCommentId}) async {
    try {
      return await _apiService.createComment(postId, content, parentCommentId: parentCommentId);
    } on ApiException catch (e) {
      _logger.e('Create comment failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection creating comment');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected create comment error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Comment> updateComment(int postId, int commentId, String content) async {
    try {
      return await _apiService.updateComment(postId, commentId, content);
    } on ApiException catch (e) {
      _logger.e('Update comment failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection updating comment');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected update comment error', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteComment(int postId, int commentId) async {
    try {
      await _apiService.deleteComment(postId, commentId);
    } on ApiException catch (e) {
      _logger.e('Delete comment failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection deleting comment');
      rethrow;
    } catch (e, st) {
      _logger.e('Unexpected delete comment error', error: e, stackTrace: st);
      rethrow;
    }
  }
}

class PagedResponse<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasPrevious;
  final bool hasNext;

  PagedResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.hasPrevious,
    required this.hasNext,
  });
}

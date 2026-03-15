import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/api_service.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/memory_cache.dart';

part 'post_repository.g.dart';

@riverpod
PostRepository postRepository(Ref ref) {
  return PostRepository(apiService: ref.watch(apiServiceProvider));
}

class PostRepository {
  static const _feedCacheTtl = Duration(minutes: 2);
  static MemoryCacheEntry<PagedResponse<Post>>? _feedCache;
  static MemoryCacheEntry<PagedResponse<Post>>? _followingFeedCache;
  static final Map<String, MemoryCacheEntry<List<Post>>> _userPostsCache =
      <String, MemoryCacheEntry<List<Post>>>{};

  final ApiService _apiService;
  final _logger = Logger();

  PostRepository({required ApiService apiService}) : _apiService = apiService;

  PagedResponse<Post>? peekFeed({int page = 1, int pageSize = 20}) {
    if (page != 1) {
      return null;
    }

    final cache = _feedCache;
    if (cache == null || !cache.isFresh(_feedCacheTtl)) {
      return null;
    }

    return cache.value;
  }

  PagedResponse<Post>? peekFollowingFeed({int page = 1, int pageSize = 20}) {
    if (page != 1) {
      return null;
    }

    final cache = _followingFeedCache;
    if (cache == null || !cache.isFresh(_feedCacheTtl)) {
      return null;
    }

    return cache.value;
  }

  List<Post>? peekUserPosts(int userId, {int page = 1, int pageSize = 20}) {
    final cache = _userPostsCache[_userPostsKey(userId, page, pageSize)];
    if (cache == null || !cache.isFresh(_feedCacheTtl)) {
      return null;
    }

    return cache.value;
  }

  Future<PagedResponse<Post>> prefetchFeed({int pageSize = 20}) {
    return getFeed(pageSize: pageSize, forceRefresh: true);
  }

  Future<PagedResponse<Post>> prefetchFollowingFeed({int pageSize = 20}) {
    return getFollowingFeed(pageSize: pageSize, forceRefresh: true);
  }

  Future<PagedResponse<Post>> getFeed({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final cachedFeed =
        !forceRefresh ? peekFeed(page: page, pageSize: pageSize) : null;
    if (cachedFeed != null) {
      return cachedFeed;
    }

    try {
      final response = await _apiService.getFeed(
        page: page,
        pageSize: pageSize,
      );
      final pagedResponse = PagedResponse(
        items: response.items,
        page: response.page,
        pageSize: response.pageSize,
        totalCount: response.totalCount,
        totalPages: response.totalPages,
        hasPrevious: response.hasPrevious,
        hasNext: response.hasNext,
      );
      if (page == 1) {
        _feedCache = MemoryCacheEntry<PagedResponse<Post>>.now(pagedResponse);
      }
      return pagedResponse;
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

  Future<PagedResponse<Post>> getFollowingFeed({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final cachedFeed =
        !forceRefresh
            ? peekFollowingFeed(page: page, pageSize: pageSize)
            : null;
    if (cachedFeed != null) {
      return cachedFeed;
    }

    try {
      final response = await _apiService.getFollowingFeed(
        page: page,
        pageSize: pageSize,
      );
      final pagedResponse = PagedResponse(
        items: response.items,
        page: response.page,
        pageSize: response.pageSize,
        totalCount: response.totalCount,
        totalPages: response.totalPages,
        hasPrevious: response.hasPrevious,
        hasNext: response.hasNext,
      );
      if (page == 1) {
        _followingFeedCache = MemoryCacheEntry<PagedResponse<Post>>.now(
          pagedResponse,
        );
      }
      return pagedResponse;
    } on ApiException catch (e) {
      _logger.e('Get following feed failed: ${e.apiError.message}');
      rethrow;
    } on OfflineException {
      _logger.w('No connection getting following feed');
      rethrow;
    } catch (e, st) {
      _logger.e(
        'Unexpected get following feed error',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<List<Post>> getUserPosts(
    int userId, {
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _userPostsKey(userId, page, pageSize);
    final cachedPosts =
        !forceRefresh
            ? peekUserPosts(userId, page: page, pageSize: pageSize)
            : null;
    if (cachedPosts != null) {
      return cachedPosts;
    }

    try {
      final posts = await _apiService.getUserPosts(
        userId,
        page: page,
        pageSize: pageSize,
      );
      _userPostsCache[cacheKey] = MemoryCacheEntry<List<Post>>.now(
        List<Post>.unmodifiable(posts),
      );
      return posts;
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

  Future<Post> createPost(
    String content,
    String? imageUrl,
    Uint8List? imageBytes,
  ) async {
    try {
      final post = await _apiService.createPost(content, imageUrl, imageBytes);
      _invalidateFeedCaches();
      _userPostsCache.clear();
      return post;
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
      final post = await _apiService.toggleLike(postId);
      _updateCachedPost(post);
      return post;
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
      _invalidateFeedCaches();
      _userPostsCache.clear();
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
      final response = await _apiService.toggleFollow(userId);
      _invalidateFeedCaches();
      return response;
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

  Future<Comment> createComment(
    int postId,
    String content, {
    int? parentCommentId,
  }) async {
    try {
      return await _apiService.createComment(
        postId,
        content,
        parentCommentId: parentCommentId,
      );
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

  Future<Comment> updateComment(
    int postId,
    int commentId,
    String content,
  ) async {
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
      _invalidateFeedCaches();
      _userPostsCache.clear();
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

  static String _userPostsKey(int userId, int page, int pageSize) {
    return '$userId|$page|$pageSize';
  }

  void _invalidateFeedCaches() {
    _feedCache = null;
    _followingFeedCache = null;
  }

  void _updateCachedPost(Post updatedPost) {
    if (_feedCache != null) {
      _feedCache = MemoryCacheEntry<PagedResponse<Post>>.now(
        _replacePostInPagedResponse(_feedCache!.value, updatedPost),
      );
    }

    if (_followingFeedCache != null) {
      _followingFeedCache = MemoryCacheEntry<PagedResponse<Post>>.now(
        _replacePostInPagedResponse(_followingFeedCache!.value, updatedPost),
      );
    }

    for (final entry in _userPostsCache.entries.toList(growable: false)) {
      final nextPosts = entry.value.value
          .map((post) => post.id == updatedPost.id ? updatedPost : post)
          .toList(growable: false);
      _userPostsCache[entry.key] = MemoryCacheEntry<List<Post>>.now(
        List<Post>.unmodifiable(nextPosts),
      );
    }
  }

  PagedResponse<Post> _replacePostInPagedResponse(
    PagedResponse<Post> response,
    Post updatedPost,
  ) {
    return PagedResponse(
      items: response.items
          .map((post) => post.id == updatedPost.id ? updatedPost : post)
          .toList(growable: false),
      page: response.page,
      pageSize: response.pageSize,
      totalCount: response.totalCount,
      totalPages: response.totalPages,
      hasPrevious: response.hasPrevious,
      hasNext: response.hasNext,
    );
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

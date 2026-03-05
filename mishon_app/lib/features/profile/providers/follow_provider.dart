import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:logger/logger.dart';
import 'package:mishon_app/features/profile/providers/profile_provider.dart';

part 'follow_provider.g.dart';

@riverpod
class FollowNotifier extends _$FollowNotifier {
  final _logger = Logger();

  @override
  AsyncValue<Map<int, bool>> build() {
    return const AsyncValue.data({});
  }

  /// Toggle follow status for a user
  /// Returns the new isFollowing status
  Future<bool> toggleFollow(int targetUserId) async {
    final currentState = state.value ?? {};
    final currentIsFollowing = currentState[targetUserId] ?? false;
    
    // Оптимистичное обновление
    state = AsyncValue.data({...currentState, targetUserId: !currentIsFollowing});

    try {
      final repository = ref.read(postRepositoryProvider);
      final response = await repository.toggleFollow(targetUserId);
      
      // Обновляем состояние на основе ответа сервера
      final newIsFollowing = response.isFollowing;
      state = AsyncValue.data({...currentState, targetUserId: newIsFollowing});
      
      // Обновляем профиль пользователя (followersCount)
      try {
        ref.read(userProfileNotifierProvider(targetUserId).notifier)
            .updateFollowingStatus(newIsFollowing);
      } catch (_) {
        // Игнорируем ошибки обновления профиля
      }
      
      return newIsFollowing;
    } catch (e, st) {
      _logger.e('Toggle follow failed', error: e, stackTrace: st);
      // Откат при ошибке
      state = AsyncValue.data({...currentState, targetUserId: currentIsFollowing});
      rethrow;
    }
  }

  bool isFollowing(int userId) {
    return state.value?[userId] ?? false;
  }

  void setFollowing(int userId, bool isFollowing) {
    final currentState = state.value ?? {};
    state = AsyncValue.data({...currentState, userId: isFollowing});
  }
}

@riverpod
class UserFollowingList extends _$UserFollowingList {
  @override
  AsyncValue<List<Follow>> build(int userId) {
    _loadFollowing();
    return const AsyncValue.loading();
  }

  Future<void> _loadFollowing() async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(postRepositoryProvider);
      final following = await repository.getFollowing(userId);
      state = AsyncValue.data(following);
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e.apiError.message, st);
    } on OfflineException catch (e, st) {
      state = AsyncValue.error(e.message, st);
    } catch (e, st) {
      state = AsyncValue.error('Ошибка загрузки подписок', st);
    }
  }

  Future<void> refresh() async {
    await _loadFollowing();
  }
}

@riverpod
class UserFollowersList extends _$UserFollowersList {
  @override
  AsyncValue<List<Follow>> build(int userId) {
    _loadFollowers();
    return const AsyncValue.loading();
  }

  Future<void> _loadFollowers() async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(postRepositoryProvider);
      final followers = await repository.getFollowers(userId);
      state = AsyncValue.data(followers);
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e.apiError.message, st);
    } on OfflineException catch (e, st) {
      state = AsyncValue.error(e.message, st);
    } catch (e, st) {
      state = AsyncValue.error('Ошибка загрузки подписчиков', st);
    }
  }

  Future<void> refresh() async {
    await _loadFollowers();
  }
}

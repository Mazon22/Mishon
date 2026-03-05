import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';

part 'profile_provider.g.dart';

@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  @override
  AsyncValue<UserProfile?> build() {
    _loadProfile();
    return const AsyncValue.loading();
  }

  Future<void> _loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final profile = await repository.getProfile();
      state = AsyncValue.data(profile);
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e.apiError.message, st);
    } on OfflineException catch (e, st) {
      state = AsyncValue.error(e.message, st);
    } catch (e, st) {
      state = AsyncValue.error('Ошибка загрузки профиля', st);
    }
  }

  Future<void> refresh() async {
    await _loadProfile();
  }

  Future<bool> updateProfile({String? username, String? avatarUrl}) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final profile = await repository.updateProfile(
        username: username,
        avatarUrl: avatarUrl,
      );
      state = AsyncValue.data(profile);
      return true;
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e.apiError.message, st);
      return false;
    } on OfflineException catch (e, st) {
      state = AsyncValue.error(e.message, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error('Ошибка обновления профиля', st);
      return false;
    }
  }
}

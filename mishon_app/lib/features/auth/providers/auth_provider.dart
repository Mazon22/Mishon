import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<AuthResponse?> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final response = await repository.login(email, password);
      state = AsyncValue.data(response);
      return true;
    } on ApiException catch (e) {
      state = AsyncValue.error(e.apiError.message, StackTrace.current);
      return false;
    } on OfflineException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      return false;
    } catch (e, st) {
      state = AsyncValue.error('Ошибка входа', st);
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final response = await repository.register(username, email, password);
      state = AsyncValue.data(response);
      return true;
    } on ApiException catch (e) {
      state = AsyncValue.error(e.apiError.message, StackTrace.current);
      return false;
    } on OfflineException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      return false;
    } catch (e, st) {
      state = AsyncValue.error('Ошибка регистрации', st);
      return false;
    }
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> clearError() async {
    state = const AsyncValue.data(null);
  }
}

@riverpod
Future<bool> isAuthenticated(Ref ref) async {
  final repository = ref.watch(authRepositoryProvider);
  return await repository.isAuthenticated();
}

@riverpod
Future<int?> userId(Ref ref) async {
  final repository = ref.watch(authRepositoryProvider);
  return await repository.getUserId();
}

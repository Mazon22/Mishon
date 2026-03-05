import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/features/auth/screens/login_screen.dart';
import 'package:mishon_app/features/auth/screens/register_screen.dart';
import 'package:mishon_app/features/feed/screens/feed_screen.dart';
import 'package:mishon_app/features/profile/screens/profile_screen.dart';
import 'package:mishon_app/features/post/screens/create_post_screen.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final isAuthenticated = await authRepository.isAuthenticated();
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // Если не авторизован и пытается войти не на login/register
      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      // Если авторизован и пытается войти на login/register
      if (isAuthenticated && isLoggingIn) {
        return '/feed';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/feed',
        name: 'feed',
        builder: (context, state) => const FeedScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/create-post',
        name: 'createPost',
        builder: (context, state) => const CreatePostScreen(),
      ),
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Страница не найдена: ${state.uri.path}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/feed'),
                child: const Text('На главную'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});

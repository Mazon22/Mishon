import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/features/auth/screens/login_screen.dart';
import 'package:mishon_app/features/auth/screens/register_screen.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';
import 'package:mishon_app/features/chats/screens/chats_screen.dart';
import 'package:mishon_app/features/comments/screens/comments_screen.dart';
import 'package:mishon_app/features/feed/screens/feed_screen.dart';
import 'package:mishon_app/features/friends/screens/friends_screen.dart';
import 'package:mishon_app/features/notifications/screens/notifications_screen.dart';
import 'package:mishon_app/features/people/screens/people_screen.dart';
import 'package:mishon_app/features/post/screens/create_post_screen.dart';
import 'package:mishon_app/features/profile/screens/profile_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/feed',
    redirect: (context, state) async {
      final isAuthenticated = await authRepository.isAuthenticated();
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthRoute) {
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
        path: '/people',
        name: 'people',
        builder: (context, state) => const PeopleScreen(),
      ),
      GoRoute(
        path: '/friends',
        name: 'friends',
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: '/chats',
        name: 'chats',
        builder: (context, state) => const ChatsScreen(),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) {
          final args = state.extra as ChatScreenArgs;
          return ChatScreen(args: args);
        },
      ),
      GoRoute(
        path: '/profile/:id',
        name: 'profile',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProfileScreen(userId: int.parse(id));
        },
      ),
      GoRoute(
        path: '/create-post',
        name: 'createPost',
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/comments',
        name: 'comments',
        builder: (context, state) {
          final args = state.extra as CommentsScreenArgs;
          return CommentsScreen(args: args);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
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

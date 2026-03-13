import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/navigation/main_navigation_shell.dart';
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

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _feedNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'feedBranch');
final _peopleNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'peopleBranch',
);
final _friendsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'friendsBranch',
);
final _chatsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'chatsBranch');
final _profileNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'profileBranch',
);

final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/feed',
    redirect: (context, state) async {
      final isAuthenticated = await authRepository.isAuthenticated();
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/feed';
      }

      if (state.matchedLocation == '/') {
        return '/feed';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/feed'),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder:
            (context, state) => _buildTelegramRoutePage(
              state: state,
              child: const LoginScreen(),
            ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder:
            (context, state) => _buildTelegramRoutePage(
              state: state,
              child: const RegisterScreen(),
            ),
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        navigatorContainerBuilder: mainShellContainerBuilder,
        branches: [
          StatefulShellBranch(
            navigatorKey: _feedNavigatorKey,
            routes: [
              GoRoute(
                path: '/feed',
                name: 'feed',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const FeedScreen(embeddedInNavigationShell: true),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _peopleNavigatorKey,
            routes: [
              GoRoute(
                path: '/people',
                name: 'people',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const PeopleScreen(
                        embeddedInNavigationShell: true,
                      ),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _friendsNavigatorKey,
            routes: [
              GoRoute(
                path: '/friends',
                name: 'friends',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const FriendsScreen(
                        embeddedInNavigationShell: true,
                      ),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _chatsNavigatorKey,
            routes: [
              GoRoute(
                path: '/chats',
                name: 'chats',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const ChatsScreen(embeddedInNavigationShell: true),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                name: 'myProfile',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const CurrentUserProfileBranchScreen(
                        embeddedInNavigationShell: true,
                      ),
                    ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final args = state.extra as ChatScreenArgs;
          return _buildTelegramRoutePage(
            state: state,
            child: ChatScreen(args: args),
          );
        },
      ),
      GoRoute(
        path: '/profile/:id',
        name: 'profile',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _buildTelegramRoutePage(
            state: state,
            child: ProfileScreen(userId: int.parse(id)),
          );
        },
      ),
      GoRoute(
        path: '/create-post',
        name: 'createPost',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder:
            (context, state) => _buildTelegramRoutePage(
              state: state,
              child: const CreatePostScreen(),
            ),
      ),
      GoRoute(
        path: '/comments',
        name: 'comments',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final args = state.extra as CommentsScreenArgs;
          return _buildTelegramRoutePage(
            state: state,
            child: CommentsScreen(args: args),
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder:
            (context, state) => _buildTelegramRoutePage(
              state: state,
              child: const NotificationsScreen(),
            ),
      ),
    ],
    errorPageBuilder: (context, state) {
      final strings = AppStrings.of(context);
      return MaterialPage(
        key: state.pageKey,
        child: Scaffold(
          appBar: AppBar(title: Text(strings.errorTitle)),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(strings.pageNotFound(state.uri.path)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/feed'),
                  child: Text(strings.goHome),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
});

CustomTransitionPage<void> _buildTelegramRoutePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.08, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(position: slideAnimation, child: child),
      );
    },
  );
}

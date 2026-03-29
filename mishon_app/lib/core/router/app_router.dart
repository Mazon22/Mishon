import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/navigation/main_navigation_shell.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/features/auth/screens/forgot_password_screen.dart';
import 'package:mishon_app/features/auth/screens/login_screen.dart';
import 'package:mishon_app/features/auth/screens/onboarding_screen.dart';
import 'package:mishon_app/features/auth/screens/register_screen.dart';
import 'package:mishon_app/features/auth/screens/reset_password_screen.dart';
import 'package:mishon_app/features/auth/screens/verify_email_pending_screen.dart';
import 'package:mishon_app/features/auth/screens/verify_email_result_screen.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';
import 'package:mishon_app/features/chats/screens/chats_overview_screen.dart';
import 'package:mishon_app/features/comments/screens/comments_screen_args.dart';
import 'package:mishon_app/features/comments/screens/telegram_comments_screen.dart';
import 'package:mishon_app/features/feed/screens/feed_screen.dart';
import 'package:mishon_app/features/friends/screens/friends_overview_screen.dart';
import 'package:mishon_app/features/notifications/screens/notifications_screen.dart';
import 'package:mishon_app/features/people/screens/people_overview_screen.dart';
import 'package:mishon_app/features/post/screens/create_post_screen.dart';
import 'package:mishon_app/features/profile/screens/profile_settings_screen.dart';
import 'package:mishon_app/features/profile/screens/follow_requests_screen.dart';
import 'package:mishon_app/features/profile/screens/privacy_settings_screen.dart';
import 'package:mishon_app/features/profile/screens/profile_screen.dart';
import 'package:mishon_app/features/profile/screens/sessions_management_screen.dart';

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
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isPublicRoute = _isPublicRoute(location);
      final isAuthEntryRoute = location == '/login' || location == '/register';

      if (!isAuthenticated && !isPublicRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthEntryRoute) {
        return '/feed';
      }

      if (location == '/') {
        return isAuthenticated ? '/feed' : '/login';
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
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        pageBuilder:
            (context, state) => _buildTelegramRoutePage(
              state: state,
              child: const ForgotPasswordScreen(),
            ),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'resetPassword',
        pageBuilder: (context, state) {
          final token =
              state.uri.queryParameters['token'] ??
              state.uri.queryParameters['code'];
          return _buildTelegramRoutePage(
            state: state,
            child: ResetPasswordScreen(token: token),
          );
        },
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verifyEmail',
        pageBuilder: (context, state) {
          final token =
              state.uri.queryParameters['token'] ??
              state.uri.queryParameters['code'];
          return _buildTelegramRoutePage(
            state: state,
            child: VerifyEmailResultScreen(token: token),
          );
        },
      ),
      GoRoute(
        path: '/verify-email/pending',
        name: 'verifyEmailPending',
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return _buildTelegramRoutePage(
            state: state,
            child: VerifyEmailPendingScreen(email: email),
          );
        },
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder:
            (context, state) => _buildTelegramRoutePage(
              state: state,
              child: const OnboardingScreen(),
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
                      child: const PeopleOverviewScreen(
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
                      child: const FriendsOverviewScreen(
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
                      child: const ChatsOverviewScreen(
                        embeddedInNavigationShell: true,
                      ),
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
        path: '/chat/:conversationId',
        name: 'chatById',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return _buildTelegramRoutePage(
            state: state,
            child: ChatScreen(args: _chatArgsFromState(state)),
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
            child: TelegramCommentsScreen(args: args),
          );
        },
      ),
      GoRoute(
        path: '/comments/:postId',
        name: 'commentsByPost',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return _buildTelegramRoutePage(
            state: state,
            child: TelegramCommentsScreen(args: _commentsArgsFromState(state)),
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
      GoRoute(
        path: '/sessions',
        name: 'sessions',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder:
            (context, state) => _buildTelegramRoutePage(
              state: state,
              child: const SessionsManagementScreen(),
            ),
      ),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder:
            (context, state) => _buildTelegramRoutePage(
              state: state,
              child: const PrivacySettingsScreen(),
            ),
      ),
      GoRoute(
        path: '/follow-requests',
        name: 'followRequests',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder:
            (context, state) => _buildTelegramRoutePage(
              state: state,
              child: const FollowRequestsScreen(),
            ),
      ),
      GoRoute(
        path: '/moderation',
        name: 'moderation',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder:
            (context, state) => _buildTelegramRoutePage(
              state: state,
              child: const ModerationDashboardScreen(),
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

bool _isPublicRoute(String matchedLocation) {
  return matchedLocation == '/login' ||
      matchedLocation == '/register' ||
      matchedLocation == '/forgot-password' ||
      matchedLocation == '/reset-password' ||
      matchedLocation == '/verify-email' ||
      matchedLocation == '/verify-email/pending';
}

ChatScreenArgs _chatArgsFromState(GoRouterState state) {
  final conversationId = int.parse(state.pathParameters['conversationId']!);
  final peerId = int.tryParse(state.uri.queryParameters['peerId'] ?? '') ?? 0;
  final peerUsername = state.uri.queryParameters['username'] ?? 'Chat';
  final peerAvatarUrl = state.uri.queryParameters['avatarUrl'];
  final isOnline = _tryParseBool(state.uri.queryParameters['isOnline']);
  final lastSeenAt = _tryParseDateTime(state.uri.queryParameters['lastSeenAt']);

  return ChatScreenArgs(
    conversationId: conversationId,
    peerId: peerId,
    peerUsername: peerUsername,
    peerAvatarUrl: peerAvatarUrl,
    initialIsOnline: isOnline,
    initialLastSeenAt: lastSeenAt,
  );
}

CommentsScreenArgs _commentsArgsFromState(GoRouterState state) {
  final postId = int.parse(state.pathParameters['postId']!);
  final postUserId =
      int.tryParse(state.uri.queryParameters['postUserId'] ?? '') ?? 0;
  return CommentsScreenArgs(postId: postId, postUserId: postUserId);
}

bool? _tryParseBool(String? value) {
  if (value == null) {
    return null;
  }
  if (value == 'true') {
    return true;
  }
  if (value == 'false') {
    return false;
  }
  return null;
}

DateTime? _tryParseDateTime(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

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

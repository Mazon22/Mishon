import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/firebase/firebase_service.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/auth/widgets/auth_shell.dart';
import 'package:mishon_app/features/profile/screens/profile_setup_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;
  UserProfile? _profile;
  List<DiscoverUser> _suggestions = const [];
  AuthorizationStatus? _notificationStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      final userId = await repository.getUserId();
      if (userId != null && await repository.isOnboardingCompleted(userId)) {
        if (mounted) {
          context.go('/feed');
        }
        return;
      }
      final socialRepository = ref.read(socialRepositoryProvider);
      final profile = await repository.getProfile(forceRefresh: true);
      final suggestions = await socialRepository.getUsers(
        limit: 6,
        forceRefresh: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _suggestions =
            suggestions.where((user) => user.id != profile.id).toList(growable: false);
        _isLoading = false;
      });
    } on OfflineException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) {
      return;
    }

    final result = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(initialProfile: profile),
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _profile = result;
    });
  }

  Future<void> _requestNotifications() async {
    setState(() => _isBusy = true);
    final status = await ref.read(firebaseServiceProvider).requestPermission();
    if (!mounted) {
      return;
    }
    setState(() {
      _notificationStatus = status;
      _isBusy = false;
    });
  }

  Future<void> _followSuggestion(DiscoverUser user) async {
    try {
      final response = await ref.read(postRepositoryProvider).toggleFollow(user.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _suggestions =
            _suggestions
                .map(
                  (item) =>
                      item.id == user.id
                          ? item.copyWith(
                            isFollowing: response.isFollowing,
                            hasPendingFollowRequest: response.isRequested,
                            followersCount: response.followersCount,
                          )
                          : item,
                )
                .toList(growable: false);
      });
    } on ApiException catch (error) {
      showAppToast(context, message: error.apiError.message, isError: true);
    } on OfflineException catch (error) {
      showAppToast(context, message: error.message, isError: true);
    } catch (_) {
      showAppToast(
        context,
        message: AppStrings.of(context).operationError,
        isError: true,
      );
    }
  }

  Future<void> _complete() async {
    final userId = await ref.read(authRepositoryProvider).getUserId();
    if (userId != null) {
      await ref.read(authRepositoryProvider).setOnboardingCompleted(userId, true);
    }
    if (!mounted) {
      return;
    }
    context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.onboardingTitle)),
        body: const LoadingState(),
      );
    }

    if (_errorMessage != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.onboardingTitle)),
        body: ErrorState(message: _errorMessage ?? strings.operationError, onRetry: _load),
      );
    }

    final profile = _profile!;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.onboardingTitle),
        actions: [
          TextButton(
            onPressed: () {
              unawaited(_complete());
            },
            child: Text(strings.skipForNow),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              strings.onboardingSubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF5C6B80)),
            ),
            const SizedBox(height: 20),
            _OnboardingCard(
              title: strings.onboardingProfileStepTitle,
              subtitle: strings.onboardingProfileStepSubtitle,
              child: Column(
                children: [
                  Row(
                    children: [
                      AppAvatar(
                        username: profile.username,
                        imageUrl: profile.avatarUrl,
                        size: 64,
                        scale: profile.avatarScale,
                        offsetX: profile.avatarOffsetX,
                        offsetY: profile.avatarOffsetY,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.username,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (profile.aboutMe ?? '').trim().isEmpty
                                  ? strings.onboardingProfileMissingHint
                                  : profile.aboutMe!.trim(),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF5C6B80),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: _editProfile,
                    child: Text(strings.editProfile),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _OnboardingCard(
              title: strings.onboardingSuggestionsStepTitle,
              subtitle: strings.onboardingSuggestionsStepSubtitle,
              child:
                  _suggestions.isEmpty
                      ? Text(strings.noSuggestionsAvailable)
                      : Column(
                        children:
                            _suggestions
                                .take(4)
                                .map(
                                  (user) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        AppAvatar(
                                          username: user.username,
                                          imageUrl: user.avatarUrl,
                                          size: 46,
                                          scale: user.avatarScale,
                                          offsetX: user.avatarOffsetX,
                                          offsetY: user.avatarOffsetY,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(user.username),
                                              Text(
                                                (user.aboutMe ?? '').trim().isEmpty
                                                    ? strings.suggestedPeopleHint
                                                    : user.aboutMe!.trim(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: const Color(0xFF5C6B80),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        FilledButton.tonal(
                                          onPressed: () => _followSuggestion(user),
                                          child: Text(
                                            user.isFollowing || user.hasPendingFollowRequest
                                                ? strings.followingLabel
                                                : strings.follow,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                      ),
            ),
            const SizedBox(height: 16),
            _OnboardingCard(
              title: strings.onboardingNotificationsStepTitle,
              subtitle: strings.onboardingNotificationsStepSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_notificationStatusLabel(strings)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _isBusy ? null : _requestNotifications,
                    child: Text(strings.notificationsOptInAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _OnboardingCard(
              title: strings.onboardingVerificationStepTitle,
              subtitle: strings.onboardingVerificationStepSubtitle,
              child: profile.emailVerified
                  ? Text(strings.emailAlreadyVerified)
                  : FilledButton.tonal(
                      onPressed: () => context.push(
                        '/verify-email/pending?email=${Uri.encodeComponent(profile.email)}',
                      ),
                      child: Text(strings.resendVerificationEmail),
                    ),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              text: strings.completeOnboarding,
              onPressed: () {
                unawaited(_complete());
              },
            ),
          ],
        ),
      ),
    );
  }

  String _notificationStatusLabel(AppStrings strings) {
    return switch (_notificationStatus) {
      AuthorizationStatus.authorized => strings.notificationsEnabled,
      AuthorizationStatus.provisional => strings.notificationsEnabled,
      AuthorizationStatus.denied => strings.notificationsPermissionDenied,
      _ => strings.notificationsOptInHint,
    };
  }
}

class _OnboardingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _OnboardingCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE4F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5C6B80)),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/core/widgets/minimal_components.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/core/theme/app_theme.dart';
import 'package:mishon_app/core/theme/app_tokens.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';
import 'package:mishon_app/features/people/providers/people_screen_provider.dart';

class PeopleOverviewScreen extends ConsumerStatefulWidget {
  final bool embeddedInNavigationShell;
  const PeopleOverviewScreen({
    super.key,
    this.embeddedInNavigationShell = false,
  });

  @override
  ConsumerState<PeopleOverviewScreen> createState() =>
      _PeopleOverviewScreenState();
}

class _PeopleOverviewScreenState extends ConsumerState<PeopleOverviewScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 280), () {
        unawaited(
          ref
              .read(peopleScreenControllerProvider.notifier)
              .setSearchQuery(_searchController.text),
        );
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = AppStrings.of(context);
    final state = ref.watch(peopleScreenControllerProvider);
    final users =
        state.isSearching ? state.searchResults : state.directoryUsers;

    return AppShell(
      currentSection: AppSection.people,
      title: strings.people,
      showSectionNavigation: !widget.embeddedInNavigationShell,
      actions: [
        IconButton(
          onPressed:
              state.isBootstrapping
                  ? null
                  : () =>
                      ref
                          .read(peopleScreenControllerProvider.notifier)
                          .refresh(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh:
            () => ref.read(peopleScreenControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHero(context, state)),
            if (state.isBootstrapping)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingState(),
              )
            else if (state.errorMessage != null && !state.isSearching)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: _messageFromError(
                    context,
                    state.errorMessage!,
                    'Could not load discovery sections.',
                  ),
                  onRetry:
                      () =>
                          ref
                              .read(peopleScreenControllerProvider.notifier)
                              .refresh(),
                ),
              )
            else if (state.isSearching && state.isSearchLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingState(),
              )
            else if (state.isSearching && state.searchErrorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: _messageFromError(
                    context,
                    state.searchErrorMessage!,
                    'Could not run the search.',
                  ),
                  onRetry:
                      () => ref
                          .read(peopleScreenControllerProvider.notifier)
                          .setSearchQuery(
                            _searchController.text,
                            forceRefresh: true,
                          ),
                ),
              )
            else if (users.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.person_search_rounded,
                  title:
                      state.isSearching
                          ? (strings.isRu
                              ? 'Ничего не найдено'
                              : 'No users found')
                          : (strings.isRu
                              ? 'Пока пусто'
                              : 'No suggestions yet'),
                  subtitle:
                      state.isSearching
                          ? (strings.isRu
                              ? 'Попробуйте другой username или имя профиля.'
                              : 'Try another username or profile name.')
                          : (strings.isRu
                              ? 'Новые подборки появятся чуть позже.'
                              : 'Fresh suggestions will appear shortly.'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount:
                      users.length +
                      ((state.isSearching
                              ? state.hasMoreSearch
                              : state.hasMoreDirectory)
                          ? 1
                          : 0),
                  itemBuilder: (context, index) {
                    if (index >= users.length) {
                      final isLoadingMore =
                          state.isSearching
                              ? state.isLoadingMoreSearch
                              : state.isLoadingMoreDirectory;
                      return FilledButton.tonal(
                        onPressed:
                            isLoadingMore
                                ? null
                                : () =>
                                    state.isSearching
                                        ? ref
                                            .read(
                                              peopleScreenControllerProvider
                                                  .notifier,
                                            )
                                            .loadMoreSearch()
                                        : ref
                                            .read(
                                              peopleScreenControllerProvider
                                                  .notifier,
                                            )
                                            .loadMoreDiscovery(),
                        child:
                            isLoadingMore
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(strings.loadMore),
                      );
                    }
                    final user = users[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == users.length - 1 ? 0 : 14,
                      ),
                      child: _buildUserCard(
                        context,
                        user,
                        state.busyUserIds.contains(user.id),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, PeopleScreenState state) {
    final strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(20),
        radius: AppRadii.xl,
        color: Colors.white.withValues(alpha: 0.94),
        boxShadow: AppShadows.soft(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: strings.isRu ? 'Поиск людей' : 'Discover people',
              subtitle:
                  strings.isRu
                      ? 'Находите людей по username и имени профиля.'
                      : 'Find people by username or profile name.',
              icon: Icons.search_rounded,
              accentColor: AppColors.people,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSearchField(
              controller: _searchController,
              hintText:
                  strings.isRu
                      ? 'Username или имя профиля'
                      : 'Username or profile name',
              onClear: _searchController.clear,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _PeopleMoodChip(
                  label:
                      '${state.directoryUsers.where((user) => user.isOnline).length} ${strings.online}',
                  accent: AppColors.people,
                ),
                _PeopleMoodChip(
                  label: strings.isRu ? 'Активные' : 'Active',
                  accent: AppColors.primary,
                ),
                _PeopleMoodChip(
                  label: strings.isRu ? 'Подборка' : 'Discovery',
                  accent: AppColors.profile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, DiscoverUser user, bool isBusy) {
    final strings = AppStrings.of(context);
    final isFollowing = user.isFollowing || user.isFriend;
    final hasPendingRequest =
        user.hasPendingFollowRequest || user.outgoingFriendRequestId != null;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      radius: AppRadii.xl,
      color: Colors.white.withValues(alpha: 0.96),
      boxShadow: AppShadows.soft(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                username: user.username,
                imageUrl: user.avatarUrl,
                size: 56,
                scale: user.avatarScale,
                offsetX: user.avatarOffsetX,
                offsetY: user.avatarOffsetY,
                onTap: () => context.push('/profile/${user.id}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (user.isPrivateAccount || !user.canViewProfile) ...[
                      const SizedBox(height: 8),
                      _PeopleMoodChip(
                        label:
                            hasPendingRequest
                                ? strings.followRequestPendingSubtitle
                                : strings.privateProfileLockedSubtitle,
                        accent: AppColors.primary,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isBusy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.tonal(
                  onPressed: () => _handleAction(user),
                  child: Text(
                    isFollowing
                        ? strings.followingLabel
                        : (user.outgoingFriendRequestId != null
                            ? (strings.isRu ? 'Заявка отправлена' : 'Requested')
                            : strings.follow),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            (user.aboutMe ?? '').trim().isEmpty
                ? (strings.isRu
                    ? 'Профиль открыт для новых знакомств.'
                    : 'Open to new connections.')
                : user.aboutMe!.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/profile/${user.id}'),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: Text(strings.profile),
                ),
              ),
              if (user.isFriend) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : () => _openChat(user),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(strings.message),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(DiscoverUser user) async {
    final operationError = AppStrings.of(context).operationError;
    final controller = ref.read(peopleScreenControllerProvider.notifier);
    try {
      await controller.toggleFollow(user);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(operationError, isError: true);
    }
  }

  Future<void> _openChat(DiscoverUser user) async {
    if (!user.canSendMessages) {
      _showSnackBar(
        AppStrings.of(context).youCannotSendMessagesToThisUser,
        isError: true,
      );
      return;
    }

    try {
      final conversation = await ref
          .read(peopleScreenControllerProvider.notifier)
          .openConversation(user);
      if (!mounted) {
        return;
      }

      context.push(
        '/chat',
        extra: ChatScreenArgs(
          conversationId: conversation.id,
          peerId: conversation.peerId,
          peerUsername: conversation.username,
          peerAvatarUrl: conversation.avatarUrl ?? user.avatarUrl,
          peerAvatarScale:
              conversation.avatarScale == 0
                  ? user.avatarScale
                  : conversation.avatarScale,
          peerAvatarOffsetX: conversation.avatarOffsetX,
          peerAvatarOffsetY: conversation.avatarOffsetY,
          initialIsOnline: conversation.isOnline || user.isOnline,
          initialLastSeenAt: conversation.lastSeenAt,
        ),
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    showAppToast(context, message: message, isError: isError);
  }

  String _messageFromError(
    BuildContext context,
    String raw,
    String fallbackEn,
  ) {
    if (raw.startsWith('ApiException:')) {
      final parts = raw.split(' - ');
      if (parts.length > 1) return parts[1].split(' (Status:').first.trim();
    }
    if (raw.startsWith('OfflineException:')) {
      return raw.replaceFirst('OfflineException: ', '');
    }
    return raw.isEmpty ? fallbackEn : raw;
  }
}

class _PeopleMoodChip extends StatelessWidget {
  final String label;
  final Color accent;
  final bool compact;

  const _PeopleMoodChip({
    required this.label,
    required this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

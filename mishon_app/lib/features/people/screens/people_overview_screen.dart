import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
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
                  itemCount: users.length,
                  itemBuilder: (context, index) {
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
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFF101C38), Color(0xFF1B4B7C), Color(0xFF21A67A)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.isRu ? 'Поиск людей' : 'Discover people',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    strings.isRu
                        ? 'Username или имя профиля'
                        : 'Username or profile name',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${state.directoryUsers.where((user) => user.isOnline).length} ${strings.online}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, DiscoverUser user, bool isBusy) {
    final strings = AppStrings.of(context);
    final isFollowing = user.isFollowing || user.isFriend;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5C6B80),
                      ),
                    ),
                  ],
                ),
              ),
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
          const SizedBox(height: 14),
          Text(
            (user.aboutMe ?? '').trim().isEmpty
                ? (strings.isRu
                    ? 'Профиль открыт для новых знакомств.'
                    : 'Open to new connections.')
                : user.aboutMe!.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
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
      if (user.isFollowing ||
          user.isFriend ||
          user.outgoingFriendRequestId != null) {
        await controller.toggleFollow(user);
      } else {
        await controller.sendFriendRequest(user);
      }
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(operationError, isError: true);
    }
  }

  Future<void> _openChat(DiscoverUser user) async {
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

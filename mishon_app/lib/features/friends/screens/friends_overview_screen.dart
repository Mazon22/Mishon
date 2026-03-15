import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';
import 'package:mishon_app/features/friends/providers/friends_screen_provider.dart';

class FriendsOverviewScreen extends ConsumerStatefulWidget {
  final bool embeddedInNavigationShell;
  const FriendsOverviewScreen({
    super.key,
    this.embeddedInNavigationShell = false,
  });

  @override
  ConsumerState<FriendsOverviewScreen> createState() =>
      _FriendsOverviewScreenState();
}

class _FriendsOverviewScreenState extends ConsumerState<FriendsOverviewScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = AppStrings.of(context);
    final state = ref.watch(friendsScreenControllerProvider);

    return AppShell(
      currentSection: AppSection.friends,
      title: strings.friends,
      showSectionNavigation: !widget.embeddedInNavigationShell,
      actions: [
        IconButton(
          onPressed:
              state.isLoading
                  ? null
                  : () =>
                      ref
                          .read(friendsScreenControllerProvider.notifier)
                          .refresh(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            _SummaryCard(
              friends: state.friends.length,
              incoming: state.incoming.length,
              outgoing: state.outgoing.length,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Material(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      tabs: [
                        Tab(text: strings.isRu ? 'Друзья' : 'Friends'),
                        Tab(text: strings.isRu ? 'Входящие' : 'Incoming'),
                        Tab(text: strings.isRu ? 'Исходящие' : 'Outgoing'),
                      ],
                    ),
                    Expanded(
                      child:
                          state.isLoading
                              ? const LoadingState()
                              : state.errorMessage != null
                              ? ErrorState(
                                message: _errorMessage(state.errorMessage!),
                                onRetry:
                                    () =>
                                        ref
                                            .read(
                                              friendsScreenControllerProvider
                                                  .notifier,
                                            )
                                            .refresh(),
                              )
                              : TabBarView(
                                controller: _tabController,
                                children: [
                                  _friendsList(context, state.friends, state),
                                  _requestsList(
                                    context,
                                    state.incoming,
                                    state,
                                    incoming: true,
                                  ),
                                  _requestsList(
                                    context,
                                    state.outgoing,
                                    state,
                                    incoming: false,
                                  ),
                                ],
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _friendsList(
    BuildContext context,
    List<FriendUser> friends,
    FriendsScreenState state,
  ) {
    final strings = AppStrings.of(context);
    if (friends.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: strings.isRu ? 'Нет друзей' : 'No friends yet',
        subtitle:
            strings.isRu
                ? 'Найдите людей и начните собирать свое окружение.'
                : 'Find people and start building your circle.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final user = friends[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: AppAvatar(
            username: user.username,
            imageUrl: user.avatarUrl,
            size: 48,
            scale: user.avatarScale,
            offsetX: user.avatarOffsetX,
            offsetY: user.avatarOffsetY,
            onTap: () => context.push('/profile/${user.id}'),
          ),
          title: Text(user.username),
          subtitle: Text(
            user.isOnline
                ? (strings.isRu ? 'В сети сейчас' : 'Online now')
                : (strings.isRu ? 'Не в сети' : 'Offline'),
          ),
          trailing:
              state.busyIds.contains(user.id)
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : PopupMenuButton<String>(
                    onSelected: (value) => _handleFriendMenu(user, value),
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 'chat',
                            child: Text(strings.message),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(strings.isRu ? 'Удалить' : 'Remove'),
                          ),
                        ],
                  ),
        );
      },
    );
  }

  Widget _requestsList(
    BuildContext context,
    List<FriendRequestModel> requests,
    FriendsScreenState state, {
    required bool incoming,
  }) {
    final strings = AppStrings.of(context);
    if (requests.isEmpty) {
      return EmptyState(
        icon: Icons.mail_outline_rounded,
        title:
            incoming
                ? (strings.isRu
                    ? 'Нет входящих заявок'
                    : 'No incoming requests')
                : (strings.isRu
                    ? 'Нет исходящих заявок'
                    : 'No outgoing requests'),
        subtitle:
            incoming
                ? (strings.isRu
                    ? 'Когда кто-то отправит заявку, она появится здесь.'
                    : 'Incoming requests will appear here.')
                : (strings.isRu
                    ? 'Отправляйте новые запросы с вкладки People.'
                    : 'New outgoing requests will appear here.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: AppAvatar(
            username: request.username,
            imageUrl: request.avatarUrl,
            size: 48,
            scale: request.avatarScale,
            offsetX: request.avatarOffsetX,
            offsetY: request.avatarOffsetY,
            onTap: () => context.push('/profile/${request.userId}'),
          ),
          title: Text(request.username),
          subtitle: Text(
            incoming
                ? (strings.isRu
                    ? 'Хочет добавить вас в друзья.'
                    : 'Wants to add you as a friend.')
                : (strings.isRu
                    ? 'Ожидает ответ на запрос.'
                    : 'Waiting for a response.'),
          ),
          trailing:
              state.busyIds.contains(request.userId)
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Wrap(
                    spacing: 8,
                    children: [
                      if (incoming)
                        IconButton(
                          onPressed: () => _acceptRequest(request),
                          icon: const Icon(Icons.check_rounded),
                        ),
                      IconButton(
                        onPressed: () => _deleteRequest(request),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
        );
      },
    );
  }

  Future<void> _handleFriendMenu(FriendUser user, String action) async {
    if (action == 'chat') {
      await _openConversation(
        user.id,
        username: user.username,
        avatarUrl: user.avatarUrl,
        avatarScale: user.avatarScale,
        avatarOffsetX: user.avatarOffsetX,
        avatarOffsetY: user.avatarOffsetY,
        isOnline: user.isOnline,
        lastSeenAt: user.lastSeenAt,
      );
      return;
    }

    await _removeFriend(user);
  }

  Future<void> _acceptRequest(FriendRequestModel request) async {
    try {
      await ref
          .read(friendsScreenControllerProvider.notifier)
          .acceptRequest(request);
    } on ApiException catch (e) {
      _showError(e.apiError.message);
    } on OfflineException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _deleteRequest(FriendRequestModel request) async {
    try {
      await ref
          .read(friendsScreenControllerProvider.notifier)
          .deleteRequest(request);
    } on ApiException catch (e) {
      _showError(e.apiError.message);
    } on OfflineException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _removeFriend(FriendUser user) async {
    try {
      await ref
          .read(friendsScreenControllerProvider.notifier)
          .removeFriend(user);
    } on ApiException catch (e) {
      _showError(e.apiError.message);
    } on OfflineException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _openConversation(
    int userId, {
    required String username,
    required String? avatarUrl,
    required double avatarScale,
    required double avatarOffsetX,
    required double avatarOffsetY,
    required bool isOnline,
    required DateTime lastSeenAt,
  }) async {
    try {
      final conversation = await ref
          .read(friendsScreenControllerProvider.notifier)
          .openConversation(userId);
      if (!mounted) {
        return;
      }
      context.push(
        '/chat',
        extra: ChatScreenArgs(
          conversationId: conversation.id,
          peerId: conversation.peerId,
          peerUsername: conversation.username,
          peerAvatarUrl: conversation.avatarUrl ?? avatarUrl,
          peerAvatarScale:
              conversation.avatarScale == 0
                  ? avatarScale
                  : conversation.avatarScale,
          peerAvatarOffsetX: conversation.avatarOffsetX,
          peerAvatarOffsetY: conversation.avatarOffsetY,
          initialIsOnline: conversation.isOnline || isOnline,
          initialLastSeenAt: conversation.lastSeenAt,
        ),
      );
    } on ApiException catch (e) {
      _showError(e.apiError.message);
    } on OfflineException catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB42318),
      ),
    );
  }

  String _errorMessage(String raw) {
    if (raw.startsWith('ApiException:')) {
      final parts = raw.split(' - ');
      if (parts.length > 1) {
        return parts[1].split(' (Status:').first.trim();
      }
    }
    if (raw.startsWith('OfflineException:')) {
      return raw.replaceFirst('OfflineException: ', '');
    }
    return raw;
  }
}

class _SummaryCard extends StatelessWidget {
  final int friends;
  final int incoming;
  final int outgoing;
  const _SummaryCard({
    required this.friends,
    required this.incoming,
    required this.outgoing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF12355B), Color(0xFF196E8A), Color(0xFF3DAE8B)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              value: '$friends',
              label: AppStrings.of(context).isRu ? 'друзей' : 'friends',
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              value: '$incoming',
              label: AppStrings.of(context).isRu ? 'входящих' : 'incoming',
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              value: '$outgoing',
              label: AppStrings.of(context).isRu ? 'исходящих' : 'outgoing',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String value;
  final String label;
  const _SummaryMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

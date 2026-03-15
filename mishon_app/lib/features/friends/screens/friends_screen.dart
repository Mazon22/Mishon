import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  final bool embeddedInNavigationShell;

  const FriendsScreen({super.key, this.embeddedInNavigationShell = false});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _poller;

  bool _isLoading = true;
  String? _errorMessage;
  List<FriendUser> _friends = const <FriendUser>[];
  List<FriendRequestModel> _incoming = const <FriendRequestModel>[];
  List<FriendRequestModel> _outgoing = const <FriendRequestModel>[];
  final Set<int> _busyIds = <int>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final repository = ref.read(socialRepositoryProvider);
    final cachedFriends = repository.peekFriends();
    final cachedIncoming = repository.peekIncomingFriendRequests();
    final cachedOutgoing = repository.peekOutgoingFriendRequests();
    final hasCachedSnapshot =
        cachedFriends != null &&
        cachedIncoming != null &&
        cachedOutgoing != null;

    if (hasCachedSnapshot) {
      _friends = cachedFriends;
      _incoming = cachedIncoming;
      _outgoing = cachedOutgoing;
      _isLoading = false;
    }

    unawaited(_loadData(silent: hasCachedSnapshot));
    _poller = Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(_loadData(silent: true)),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final repository = ref.read(socialRepositoryProvider);
      final friends = await repository.getFriends(forceRefresh: true);
      final incoming = await repository.getIncomingFriendRequests(
        forceRefresh: true,
      );
      final outgoing = await repository.getOutgoingFriendRequests(
        forceRefresh: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _friends = friends;
        _incoming = incoming;
        _outgoing = outgoing;
        _isLoading = false;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      if (silent &&
          (_friends.isNotEmpty ||
              _incoming.isNotEmpty ||
              _outgoing.isNotEmpty)) {
        return;
      }

      setState(() {
        _errorMessage = e.apiError.message;
        _isLoading = false;
      });
    } on OfflineException catch (e) {
      if (!mounted) {
        return;
      }

      if (silent &&
          (_friends.isNotEmpty ||
              _incoming.isNotEmpty ||
              _outgoing.isNotEmpty)) {
        return;
      }

      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      if (silent &&
          (_friends.isNotEmpty ||
              _incoming.isNotEmpty ||
              _outgoing.isNotEmpty)) {
        return;
      }

      final strings = AppStrings.of(context);
      setState(() {
        _errorMessage =
            strings.isRu
                ? 'Не удалось загрузить друзей и заявки.'
                : 'Could not load friends and requests.';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptRequest(FriendRequestModel request) async {
    final strings = AppStrings.of(context);
    await _runAction(
      request.userId,
      () async {
        await ref
            .read(socialRepositoryProvider)
            .acceptFriendRequest(request.id);
        _applyAcceptedRequest(request);
      },
      strings.isRu
          ? '${request.username} добавлен в друзья.'
          : '${request.username} was added to friends.',
    );
  }

  Future<void> _deleteRequest(FriendRequestModel request) async {
    final strings = AppStrings.of(context);
    await _runAction(
      request.userId,
      () async {
        await ref
            .read(socialRepositoryProvider)
            .deleteFriendRequest(request.id);
        setState(() {
          if (request.isIncoming) {
            _incoming = _incoming
                .where((item) => item.id != request.id)
                .toList(growable: false);
          } else {
            _outgoing = _outgoing
                .where((item) => item.id != request.id)
                .toList(growable: false);
          }
        });
      },
      request.isIncoming
          ? (strings.isRu ? 'Заявка отклонена.' : 'Request declined.')
          : (strings.isRu
              ? 'Исходящая заявка отменена.'
              : 'Outgoing request canceled.'),
    );
  }

  Future<void> _removeFriend(FriendUser user) async {
    final strings = AppStrings.of(context);
    await _runAction(
      user.id,
      () async {
        await ref.read(socialRepositoryProvider).removeFriend(user.id);
        setState(() {
          _friends = _friends
              .where((friend) => friend.id != user.id)
              .toList(growable: false);
        });
      },
      strings.isRu
          ? '${user.username} удален из друзей.'
          : '${user.username} was removed from friends.',
    );
  }

  Future<void> _openChatWithFriend(FriendUser user) async {
    await _openChat(
      user.id,
      username: user.username,
      avatarUrl: user.avatarUrl,
      avatarScale: user.avatarScale,
      avatarOffsetX: user.avatarOffsetX,
      avatarOffsetY: user.avatarOffsetY,
      isOnline: user.isOnline,
      lastSeenAt: user.lastSeenAt,
    );
  }

  Future<void> _openChat(
    int userId, {
    required String username,
    required String? avatarUrl,
    required double avatarScale,
    required double avatarOffsetX,
    required double avatarOffsetY,
    required bool isOnline,
    required DateTime lastSeenAt,
  }) async {
    setState(() => _busyIds.add(userId));
    try {
      final conversation = await ref
          .read(socialRepositoryProvider)
          .getOrCreateConversation(userId);
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
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(AppStrings.of(context).couldNotOpenChat, isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(userId));
      }
    }
  }

  Future<void> _runAction(
    int id,
    Future<void> Function() action,
    String successMessage,
  ) async {
    final strings = AppStrings.of(context);
    setState(() => _busyIds.add(id));

    try {
      await action();
      _showSnackBar(successMessage);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(strings.operationError, isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(id));
      }
    }
  }

  void _applyAcceptedRequest(FriendRequestModel request) {
    final newFriend = FriendUser(
      id: request.userId,
      username: request.username,
      aboutMe: request.aboutMe,
      avatarUrl: request.avatarUrl,
      avatarScale: request.avatarScale,
      avatarOffsetX: request.avatarOffsetX,
      avatarOffsetY: request.avatarOffsetY,
      lastSeenAt: request.lastSeenAt,
      isOnline: request.isOnline,
    );

    setState(() {
      _incoming = _incoming
          .where((item) => item.id != request.id)
          .toList(growable: false);
      _friends = <FriendUser>[
        newFriend,
        ..._friends.where((item) => item.id != request.userId),
      ];
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFB42318) : const Color(0xFF117A47),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return AppShell(
      currentSection: AppSection.friends,
      title: strings.friends,
      showSectionNavigation: !widget.embeddedInNavigationShell,
      actions: <Widget>[
        IconButton(
          onPressed: _isLoading ? null : _loadData,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: <Widget>[
            _FriendsSummaryPanel(
              friendsCount: _friends.length,
              incomingCount: _incoming.length,
              outgoingCount: _outgoing.length,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Material(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FB),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          dividerColor: Colors.transparent,
                          labelColor: const Color(0xFF15243B),
                          unselectedLabelColor: const Color(0xFF6B7788),
                          tabs: <Tab>[
                            Tab(text: strings.isRu ? 'Друзья' : 'Friends'),
                            Tab(text: strings.isRu ? 'Входящие' : 'Incoming'),
                            Tab(text: strings.isRu ? 'Исходящие' : 'Outgoing'),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          _isLoading
                              ? const LoadingState()
                              : _errorMessage != null
                              ? ErrorState(
                                message: _errorMessage!,
                                onRetry: _loadData,
                              )
                              : TabBarView(
                                controller: _tabController,
                                children: <Widget>[
                                  _buildFriendsTab(context),
                                  _buildIncomingTab(context),
                                  _buildOutgoingTab(context),
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

  Widget _buildFriendsTab(BuildContext context) {
    final strings = AppStrings.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child:
          _friends.isEmpty
              ? _FriendsEmptyState(
                title: strings.isRu ? 'Нет друзей' : 'No friends yet',
                subtitle:
                    strings.isRu
                        ? 'Найдите людей и начните собирать свое окружение.'
                        : 'Find people and start building your circle.',
                onFindPeople: () => context.go('/people'),
              )
              : ListView.builder(
                key: const ValueKey<String>('friends-list'),
                padding: const EdgeInsets.all(16),
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  final user = _friends[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _friends.length - 1 ? 0 : 14,
                    ),
                    child: _FriendConnectionCard(
                      user: user,
                      isBusy: _busyIds.contains(user.id),
                      onOpenProfile: () => context.push('/profile/${user.id}'),
                      onMessage: () => _openChatWithFriend(user),
                      onRemove: () => _removeFriend(user),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildIncomingTab(BuildContext context) {
    final strings = AppStrings.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child:
          _incoming.isEmpty
              ? _FriendsEmptyState(
                title:
                    strings.isRu
                        ? 'Нет входящих заявок'
                        : 'No incoming requests',
                subtitle:
                    strings.isRu
                        ? 'Когда кто-то отправит заявку, она появится здесь.'
                        : 'When someone sends a request, it will appear here.',
                onFindPeople: () => context.go('/people'),
              )
              : ListView.builder(
                key: const ValueKey<String>('incoming-list'),
                padding: const EdgeInsets.all(16),
                itemCount: _incoming.length,
                itemBuilder: (context, index) {
                  final request = _incoming[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _incoming.length - 1 ? 0 : 14,
                    ),
                    child: _RequestCard(
                      request: request,
                      isBusy: _busyIds.contains(request.userId),
                      primaryLabel: strings.isRu ? 'Принять' : 'Accept',
                      secondaryLabel: strings.isRu ? 'Отклонить' : 'Decline',
                      onPrimary: () => _acceptRequest(request),
                      onSecondary: () => _deleteRequest(request),
                      onOpenProfile:
                          () => context.push('/profile/${request.userId}'),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildOutgoingTab(BuildContext context) {
    final strings = AppStrings.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child:
          _outgoing.isEmpty
              ? _FriendsEmptyState(
                title:
                    strings.isRu
                        ? 'Нет исходящих заявок'
                        : 'No outgoing requests',
                subtitle:
                    strings.isRu
                        ? 'Отправляйте новые запросы с вкладки People.'
                        : 'Send new requests from the People tab.',
                onFindPeople: () => context.go('/people'),
              )
              : ListView.builder(
                key: const ValueKey<String>('outgoing-list'),
                padding: const EdgeInsets.all(16),
                itemCount: _outgoing.length,
                itemBuilder: (context, index) {
                  final request = _outgoing[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _outgoing.length - 1 ? 0 : 14,
                    ),
                    child: _RequestCard(
                      request: request,
                      isBusy: _busyIds.contains(request.userId),
                      primaryLabel: strings.cancel,
                      onPrimary: () => _deleteRequest(request),
                      onOpenProfile:
                          () => context.push('/profile/${request.userId}'),
                    ),
                  );
                },
              ),
    );
  }
}

class _FriendsSummaryPanel extends StatelessWidget {
  final int friendsCount;
  final int incomingCount;
  final int outgoingCount;

  const _FriendsSummaryPanel({
    required this.friendsCount,
    required this.incomingCount,
    required this.outgoingCount,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF12355B),
            Color(0xFF196E8A),
            Color(0xFF3DAE8B),
          ],
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryMetric(
              value: '$friendsCount',
              label: strings.isRu ? 'друзей' : 'friends',
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              value: '$incomingCount',
              label: strings.isRu ? 'входящих' : 'incoming',
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              value: '$outgoingCount',
              label: strings.isRu ? 'исходящих' : 'outgoing',
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
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

class _FriendsEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onFindPeople;

  const _FriendsEmptyState({
    required this.title,
    required this.subtitle,
    required this.onFindPeople,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return EmptyState(
      icon: Icons.people_outline_rounded,
      title: title,
      subtitle: subtitle,
      actionText: strings.isRu ? 'Find people' : 'Find people',
      onAction: onFindPeople,
    );
  }
}

class _FriendConnectionCard extends StatelessWidget {
  final FriendUser user;
  final bool isBusy;
  final VoidCallback onOpenProfile;
  final VoidCallback onMessage;
  final VoidCallback onRemove;

  const _FriendConnectionCard({
    required this.user,
    required this.isBusy,
    required this.onOpenProfile,
    required this.onMessage,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final bio =
        (user.aboutMe ?? '').trim().isNotEmpty
            ? user.aboutMe!.trim()
            : (strings.isRu
                ? 'Ваш друг в Mishon. Можно сразу перейти в чат.'
                : 'Your friend on Mishon. Open chat instantly.');

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity >= 320) {
          onMessage();
        } else if (velocity <= -320) {
          onRemove();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF1B2838).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                AppAvatar(
                  username: user.username,
                  imageUrl: user.avatarUrl,
                  size: 54,
                  scale: user.avatarScale,
                  offsetX: user.avatarOffsetX,
                  offsetY: user.avatarOffsetY,
                  onTap: onOpenProfile,
                ),
                if (user.isOnline)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2FD16C),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: InkWell(
                onTap: onOpenProfile,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.username,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF536273),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.isOnline
                            ? (strings.isRu ? 'В сети сейчас' : 'Online now')
                            : (strings.isRu ? 'Не в сети' : 'Offline'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              user.isOnline
                                  ? const Color(0xFF138A4E)
                                  : const Color(0xFF7A8797),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
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
              Column(
                children: <Widget>[
                  ElevatedButton(
                    onPressed: onMessage,
                    child: Text(strings.message),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onRemove,
                    child: Text(strings.isRu ? 'Удалить' : 'Remove'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final FriendRequestModel request;
  final bool isBusy;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;
  final VoidCallback onOpenProfile;

  const _RequestCard({
    required this.request,
    required this.isBusy,
    required this.primaryLabel,
    this.secondaryLabel,
    required this.onPrimary,
    this.onSecondary,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final bio =
        (request.aboutMe ?? '').trim().isNotEmpty
            ? request.aboutMe!.trim()
            : (request.isIncoming
                ? (strings.isRu
                    ? 'Хочет добавить вас в друзья.'
                    : 'Wants to add you as a friend.')
                : (strings.isRu
                    ? 'Ожидает ответа на вашу заявку.'
                    : 'Waiting for a response to your request.'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF1B2838).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              AppAvatar(
                username: request.username,
                imageUrl: request.avatarUrl,
                size: 54,
                scale: request.avatarScale,
                offsetX: request.avatarOffsetX,
                offsetY: request.avatarOffsetY,
                onTap: onOpenProfile,
              ),
              if (request.isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2FD16C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: InkWell(
              onTap: onOpenProfile,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      request.username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF536273),
                      ),
                    ),
                  ],
                ),
              ),
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
            Column(
              children: <Widget>[
                ElevatedButton(onPressed: onPrimary, child: Text(primaryLabel)),
                if (onSecondary != null && secondaryLabel != null) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

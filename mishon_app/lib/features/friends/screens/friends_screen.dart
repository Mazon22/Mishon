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
  List<FriendUser> _friends = const [];
  List<FriendRequestModel> _incoming = const [];
  List<FriendRequestModel> _outgoing = const [];
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _poller = Timer.periodic(const Duration(seconds: 12), (_) => _loadData(silent: true));
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
      final friends = await repository.getFriends();
      final incoming = await repository.getIncomingFriendRequests();
      final outgoing = await repository.getOutgoingFriendRequests();

      if (!mounted) return;
      setState(() {
        _friends = friends;
        _incoming = incoming;
        _outgoing = outgoing;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.apiError.message;
        _isLoading = false;
      });
    } on OfflineException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      final strings = AppStrings.of(context);
      setState(() {
        _errorMessage =
            strings.isRu
                ? 'Не удалось загрузить друзей'
                : 'Could not load friends';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptRequest(FriendRequestModel request) async {
    final strings = AppStrings.of(context);
    await _runAction(
      request.userId,
      () => ref.read(socialRepositoryProvider).acceptFriendRequest(request.id),
      strings.isRu
          ? '${request.username} добавлен в друзья'
          : '${request.username} added to friends',
    );
  }

  Future<void> _deleteRequest(FriendRequestModel request) async {
    final strings = AppStrings.of(context);
    await _runAction(
      request.userId,
      () => ref.read(socialRepositoryProvider).deleteFriendRequest(request.id),
      strings.isRu ? 'Заявка удалена' : 'Request removed',
    );
  }

  Future<void> _removeFriend(FriendUser user) async {
    final strings = AppStrings.of(context);
    await _runAction(
      user.id,
      () => ref.read(socialRepositoryProvider).removeFriend(user.id),
      strings.isRu
          ? '${user.username} удален из друзей'
          : '${user.username} removed from friends',
    );
  }

  Future<void> _openChat(FriendUser user) async {
    setState(() => _busyIds.add(user.id));
    try {
      final conversation = await ref.read(socialRepositoryProvider).getOrCreateConversation(user.id);
      if (!mounted) return;
      context.push(
        '/chat',
        extra: ChatScreenArgs(
          conversationId: conversation.id,
          peerId: conversation.peerId,
          peerUsername: conversation.username,
          peerAvatarUrl: conversation.avatarUrl,
          peerAvatarScale: conversation.avatarScale,
          peerAvatarOffsetX: conversation.avatarOffsetX,
          peerAvatarOffsetY: conversation.avatarOffsetY,
          initialIsOnline: conversation.isOnline,
          initialLastSeenAt: conversation.lastSeenAt,
        ),
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      final strings = AppStrings.of(context);
      _showSnackBar(
        strings.isRu ? 'Не удалось открыть диалог' : 'Could not open chat',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(user.id));
      }
    }
  }

  Future<void> _runAction(int id, Future<void> Function() action, String successMessage) async {
    final strings = AppStrings.of(context);
    setState(() => _busyIds.add(id));
    try {
      await action();
      await _loadData(silent: true);
      _showSnackBar(successMessage);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Операция не выполнена'
            : 'Could not complete the action',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(id));
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted || !isError) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
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
      actions: [
        IconButton(
          onPressed: _isLoading ? null : () => _loadData(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  _MetricTile(
                    label: strings.isRu ? 'Друзья' : 'Friends',
                    value: _friends.length,
                  ),
                  _MetricTile(
                    label: strings.isRu ? 'Входящие' : 'Incoming',
                    value: _incoming.length,
                  ),
                  _MetricTile(
                    label: strings.isRu ? 'Исходящие' : 'Outgoing',
                    value: _outgoing.length,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                    const Divider(height: 1),
                    Expanded(
                      child: _isLoading
                          ? const LoadingState()
                          : _errorMessage != null
                              ? ErrorState(
                                  message: _errorMessage!,
                                  onRetry: () => _loadData(),
                                )
                              : TabBarView(
                                  controller: _tabController,
                                  children: [
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
    if (_friends.isEmpty) {
      return EmptyState(
        icon: Icons.favorite_border,
        title: strings.isRu ? 'Друзей пока нет' : 'No friends yet',
        subtitle:
            strings.isRu
                ? 'Отправьте заявки на вкладке "Люди".'
                : 'Send requests from the People tab.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final user = _friends[index];
        return _FriendTile(
          username: user.username,
          avatarUrl: user.avatarUrl,
          avatarScale: user.avatarScale,
          avatarOffsetX: user.avatarOffsetX,
          avatarOffsetY: user.avatarOffsetY,
          isBusy: _busyIds.contains(user.id),
          onTap: () => context.go('/profile/${user.id}'),
          onPrimaryAction: () => _openChat(user),
          onPrimaryLabel: strings.message,
          onSecondaryAction: () => _removeFriend(user),
          onSecondaryLabel: strings.delete,
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }

  Widget _buildIncomingTab(BuildContext context) {
    final strings = AppStrings.of(context);
    if (_incoming.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: strings.isRu ? 'Нет входящих заявок' : 'No incoming requests',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _incoming.length,
      itemBuilder: (context, index) {
        final request = _incoming[index];
        return _FriendTile(
          username: request.username,
          avatarUrl: request.avatarUrl,
          avatarScale: request.avatarScale,
          avatarOffsetX: request.avatarOffsetX,
          avatarOffsetY: request.avatarOffsetY,
          caption:
              strings.isRu
                  ? 'Хочет добавить вас в друзья'
                  : 'Wants to add you as a friend',
          isBusy: _busyIds.contains(request.userId),
          onTap: () => context.go('/profile/${request.userId}'),
          onPrimaryAction: () => _acceptRequest(request),
          onPrimaryLabel: strings.isRu ? 'Принять' : 'Accept',
          onSecondaryAction: () => _deleteRequest(request),
          onSecondaryLabel: strings.isRu ? 'Отклонить' : 'Decline',
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }

  Widget _buildOutgoingTab(BuildContext context) {
    final strings = AppStrings.of(context);
    if (_outgoing.isEmpty) {
      return EmptyState(
        icon: Icons.outbox_outlined,
        title: strings.isRu ? 'Нет исходящих заявок' : 'No outgoing requests',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _outgoing.length,
      itemBuilder: (context, index) {
        final request = _outgoing[index];
        return _FriendTile(
          username: request.username,
          avatarUrl: request.avatarUrl,
          avatarScale: request.avatarScale,
          avatarOffsetX: request.avatarOffsetX,
          avatarOffsetY: request.avatarOffsetY,
          caption:
              strings.isRu ? 'Ожидает подтверждения' : 'Waiting for approval',
          isBusy: _busyIds.contains(request.userId),
          onTap: () => context.go('/profile/${request.userId}'),
          onPrimaryAction: () => _deleteRequest(request),
          onPrimaryLabel: strings.cancel,
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final int value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final String? caption;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onPrimaryAction;
  final String onPrimaryLabel;
  final VoidCallback? onSecondaryAction;
  final String? onSecondaryLabel;

  const _FriendTile({
    required this.username,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.isBusy,
    required this.onTap,
    required this.onPrimaryAction,
    required this.onPrimaryLabel,
    this.caption,
    this.onSecondaryAction,
    this.onSecondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AppAvatar(
              username: username,
              imageUrl: avatarUrl,
              size: 48,
              scale: avatarScale,
              offsetX: avatarOffsetX,
              offsetY: avatarOffsetY,
              onTap: onTap,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (caption != null) ...[
                        const SizedBox(height: 4),
                        Text(caption!, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (isBusy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: onPrimaryAction,
                    child: Text(onPrimaryLabel),
                  ),
                  if (onSecondaryAction != null && onSecondaryLabel != null)
                    OutlinedButton(
                      onPressed: onSecondaryAction,
                      child: Text(onSecondaryLabel!),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

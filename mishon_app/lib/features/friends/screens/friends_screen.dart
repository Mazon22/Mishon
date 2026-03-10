import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

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
      setState(() {
        _errorMessage = 'Не удалось загрузить друзей';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptRequest(FriendRequestModel request) async {
    await _runAction(
      request.userId,
      () => ref.read(socialRepositoryProvider).acceptFriendRequest(request.id),
      '${request.username} добавлен в друзья',
    );
  }

  Future<void> _deleteRequest(FriendRequestModel request) async {
    await _runAction(
      request.userId,
      () => ref.read(socialRepositoryProvider).deleteFriendRequest(request.id),
      'Заявка удалена',
    );
  }

  Future<void> _removeFriend(FriendUser user) async {
    await _runAction(
      user.id,
      () => ref.read(socialRepositoryProvider).removeFriend(user.id),
      '${user.username} удален из друзей',
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
        ),
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось открыть диалог', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(user.id));
      }
    }
  }

  Future<void> _runAction(int id, Future<void> Function() action, String successMessage) async {
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
      _showSnackBar('Операция не выполнена', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(id));
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentSection: AppSection.friends,
      title: 'Друзья',
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
                  _MetricTile(label: 'Друзья', value: _friends.length),
                  _MetricTile(label: 'Входящие', value: _incoming.length),
                  _MetricTile(label: 'Исходящие', value: _outgoing.length),
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
                      tabs: const [
                        Tab(text: 'Друзья'),
                        Tab(text: 'Входящие'),
                        Tab(text: 'Исходящие'),
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
    if (_friends.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border,
        title: 'Друзей пока нет',
        subtitle: 'Отправьте заявки на вкладке "Люди".',
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
          isBusy: _busyIds.contains(user.id),
          onTap: () => context.go('/profile/${user.id}'),
          onPrimaryAction: () => _openChat(user),
          onPrimaryLabel: 'Сообщение',
          onSecondaryAction: () => _removeFriend(user),
          onSecondaryLabel: 'Удалить',
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }

  Widget _buildIncomingTab(BuildContext context) {
    if (_incoming.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Нет входящих заявок',
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
          caption: 'Хочет добавить вас в друзья',
          isBusy: _busyIds.contains(request.userId),
          onTap: () => context.go('/profile/${request.userId}'),
          onPrimaryAction: () => _acceptRequest(request),
          onPrimaryLabel: 'Принять',
          onSecondaryAction: () => _deleteRequest(request),
          onSecondaryLabel: 'Отклонить',
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }

  Widget _buildOutgoingTab(BuildContext context) {
    if (_outgoing.isEmpty) {
      return const EmptyState(
        icon: Icons.outbox_outlined,
        title: 'Нет исходящих заявок',
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
          caption: 'Ожидает подтверждения',
          isBusy: _busyIds.contains(request.userId),
          onTap: () => context.go('/profile/${request.userId}'),
          onPrimaryAction: () => _deleteRequest(request),
          onPrimaryLabel: 'Отменить',
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
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      username.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
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

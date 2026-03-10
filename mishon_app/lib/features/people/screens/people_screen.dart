import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _poller;
  bool _isLoading = true;
  String? _errorMessage;
  List<DiscoverUser> _users = const [];
  final Set<int> _busyUserIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadUsers();
    _poller = Timer.periodic(const Duration(seconds: 15), (_) => _loadUsers(silent: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _poller?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _loadUsers());
  }

  Future<void> _loadUsers({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final users = await ref.read(socialRepositoryProvider).getUsers(
            query: _searchController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
        _errorMessage = null;
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
        _errorMessage = 'Не удалось загрузить список пользователей';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow(DiscoverUser user) async {
    await _runUserAction(
      user.id,
      () => ref.read(postRepositoryProvider).toggleFollow(user.id),
      successMessage: user.isFollowing ? 'Подписка отменена' : 'Подписка обновлена',
    );
  }

  Future<void> _sendFriendRequest(DiscoverUser user) async {
    await _runUserAction(
      user.id,
      () => ref.read(socialRepositoryProvider).sendFriendRequest(user.id),
      successMessage: 'Заявка отправлена',
    );
  }

  Future<void> _acceptFriendRequest(DiscoverUser user) async {
    final requestId = user.incomingFriendRequestId;
    if (requestId == null) return;
    await _runUserAction(
      user.id,
      () => ref.read(socialRepositoryProvider).acceptFriendRequest(requestId),
      successMessage: '${user.username} теперь у вас в друзьях',
    );
  }

  Future<void> _deleteFriendRequest(DiscoverUser user) async {
    final requestId = user.incomingFriendRequestId ?? user.outgoingFriendRequestId;
    if (requestId == null) return;
    await _runUserAction(
      user.id,
      () => ref.read(socialRepositoryProvider).deleteFriendRequest(requestId),
      successMessage: 'Заявка удалена',
    );
  }

  Future<void> _openChat(DiscoverUser user) async {
    setState(() => _busyUserIds.add(user.id));
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
        setState(() => _busyUserIds.remove(user.id));
      }
    }
  }

  Future<void> _runUserAction(
    int userId,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _busyUserIds.add(userId));
    try {
      await action();
      await _loadUsers(silent: true);
      _showSnackBar(successMessage);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Операция не выполнена', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyUserIds.remove(userId));
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
      currentSection: AppSection.people,
      title: 'Люди',
      actions: [
        IconButton(
          onPressed: _isLoading ? null : () => _loadUsers(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () => _loadUsers(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroCard(searchController: _searchController),
                    const SizedBox(height: 16),
                    Text(
                      'Люди рядом с вашей лентой',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ищите друзей, принимайте заявки и переходите в личные сообщения.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingState(),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: _errorMessage!,
                  onRetry: () => _loadUsers(),
                ),
              )
            else if (_users.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'Никого не найдено',
                  subtitle: 'Попробуйте изменить запрос или обновить список.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return _UserCard(
                      user: user,
                      isBusy: _busyUserIds.contains(user.id),
                      onOpenProfile: () => context.go('/profile/${user.id}'),
                      onToggleFollow: () => _toggleFollow(user),
                      onSendFriendRequest: () => _sendFriendRequest(user),
                      onAcceptRequest: () => _acceptFriendRequest(user),
                      onDeleteRequest: () => _deleteFriendRequest(user),
                      onOpenChat: user.isFriend ? () => _openChat(user) : null,
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final TextEditingController searchController;

  const _HeroCard({required this.searchController});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF151B2E),
            Color(0xFF2A3558),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Найдите новых людей',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Добавляйте в друзья, подписывайтесь и открывайте личные чаты без отдельного сайта.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Поиск по username',
              prefixIcon: const Icon(Icons.search),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final DiscoverUser user;
  final bool isBusy;
  final VoidCallback onOpenProfile;
  final VoidCallback onToggleFollow;
  final VoidCallback onSendFriendRequest;
  final VoidCallback onAcceptRequest;
  final VoidCallback onDeleteRequest;
  final VoidCallback? onOpenChat;

  const _UserCard({
    required this.user,
    required this.isBusy,
    required this.onOpenProfile,
    required this.onToggleFollow,
    required this.onSendFriendRequest,
    required this.onAcceptRequest,
    required this.onDeleteRequest,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final hasIncomingRequest = user.incomingFriendRequestId != null;
    final hasOutgoingRequest = user.outgoingFriendRequestId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                  onTap: onOpenProfile,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (user.isFriend) const _StatusChip(label: 'Друг'),
                          if (user.isFollowing) const _StatusChip(label: 'Подписка'),
                          if (hasIncomingRequest)
                            const _StatusChip(label: 'Входящая заявка'),
                          if (hasOutgoingRequest)
                            const _StatusChip(label: 'Заявка отправлена'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isBusy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (user.isFriend && onOpenChat != null)
                  ElevatedButton.icon(
                    onPressed: isBusy ? null : onOpenChat,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Сообщение'),
                  )
                else if (hasIncomingRequest)
                  ElevatedButton.icon(
                    onPressed: isBusy ? null : onAcceptRequest,
                    icon: const Icon(Icons.done),
                    label: const Text('Принять'),
                  )
                else if (!hasOutgoingRequest)
                  ElevatedButton.icon(
                    onPressed: isBusy ? null : onSendFriendRequest,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('В друзья'),
                  ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onToggleFollow,
                  icon: Icon(user.isFollowing ? Icons.remove_circle_outline : Icons.add_circle_outline),
                  label: Text(user.isFollowing ? 'Отписаться' : 'Подписаться'),
                ),
                if (hasIncomingRequest || hasOutgoingRequest)
                  TextButton(
                    onPressed: isBusy ? null : onDeleteRequest,
                    child: Text(hasIncomingRequest ? 'Отклонить' : 'Отменить'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

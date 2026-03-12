import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  Timer? _poller;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  bool _favoritesOnly = false;
  bool _showArchived = false;
  List<ConversationModel> _conversations = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadConversations();
    _poller = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadConversations(silent: true),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text.trim();
    if (nextQuery == _searchQuery) {
      return;
    }

    setState(() {
      _searchQuery = nextQuery;
    });
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final conversations =
          await ref.read(socialRepositoryProvider).getConversations();
      if (!mounted) {
        return;
      }

      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
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

      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Не удалось загрузить диалоги';
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF1F8F52),
      ),
    );
  }

  Future<void> _togglePin(ConversationModel conversation) async {
    try {
      await ref
          .read(socialRepositoryProvider)
          .pinConversation(conversation.id, !conversation.isPinned);
      await _loadConversations(silent: true);
      _showSnackBar(
        conversation.isPinned
            ? 'Чат откреплен'
            : 'Чат закреплен',
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось изменить закрепление чата', isError: true);
    }
  }

  Future<void> _toggleArchive(ConversationModel conversation) async {
    try {
      await ref
          .read(socialRepositoryProvider)
          .archiveConversation(conversation.id, !conversation.isArchived);
      await _loadConversations(silent: true);
      _showSnackBar(
        conversation.isArchived ? 'Чат возвращен из архива' : 'Чат отправлен в архив',
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось изменить архив чата', isError: true);
    }
  }

  Future<void> _toggleFavorite(ConversationModel conversation) async {
    try {
      await ref
          .read(socialRepositoryProvider)
          .favoriteConversation(conversation.id, !conversation.isFavorite);
      await _loadConversations(silent: true);
      _showSnackBar(
        conversation.isFavorite
            ? 'Чат убран из избранного'
            : 'Чат добавлен в избранное',
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось обновить избранное', isError: true);
    }
  }

  Future<void> _toggleMute(ConversationModel conversation) async {
    try {
      await ref
          .read(socialRepositoryProvider)
          .muteConversation(conversation.id, !conversation.isMuted);
      await _loadConversations(silent: true);
      _showSnackBar(
        conversation.isMuted
            ? 'Уведомления включены'
            : 'Уведомления отключены',
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось обновить уведомления', isError: true);
    }
  }

  Future<void> _deleteConversation(ConversationModel conversation) async {
    final decision = await showDialog<_DeleteConversationMode>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Удалить чат?'),
            content: Text('Диалог с ${conversation.username} можно удалить только у вас или у обоих пользователей.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pop(_DeleteConversationMode.onlyForMe),
                child: const Text('Только у меня'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pop(_DeleteConversationMode.forBoth),
                child: const Text('У обоих'),
              ),
            ],
          ),
    );

    if (decision == null) {
      return;
    }

    try {
      await ref.read(socialRepositoryProvider).deleteConversation(
        conversation.id,
        deleteForBoth: decision == _DeleteConversationMode.forBoth,
      );
      await _loadConversations(silent: true);
      _showSnackBar('Чат удален');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось удалить чат', isError: true);
    }
  }

  Future<void> _blockUser(ConversationModel conversation) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Заблокировать пользователя?'),
                content: Text(
                  'Вы уверены, что хотите заблокировать ${conversation.username}?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Заблокировать'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await ref.read(socialRepositoryProvider).blockUserFromChat(
        conversation.peerId,
      );
      await _loadConversations(silent: true);
      _showSnackBar('Пользователь заблокирован');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось заблокировать пользователя', isError: true);
    }
  }

  Future<void> _showChatActions(ConversationModel conversation) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    conversation.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                  ),
                  title: Text(
                    conversation.isPinned ? 'Открепить чат' : 'Закрепить чат',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _togglePin(conversation);
                  },
                ),
                ListTile(
                  leading: Icon(
                    conversation.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  title: Text(
                    conversation.isArchived
                        ? 'Вернуть из архива'
                        : 'Архивировать',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _toggleArchive(conversation);
                  },
                ),
                ListTile(
                  leading: Icon(
                    conversation.isFavorite
                        ? Icons.star_outline_rounded
                        : Icons.star_rounded,
                  ),
                  title: Text(
                    conversation.isFavorite
                        ? 'Убрать из избранного'
                        : 'Добавить в избранное',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _toggleFavorite(conversation);
                  },
                ),
                ListTile(
                  leading: Icon(
                    conversation.isMuted
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                  title: Text(
                    conversation.isMuted
                        ? 'Включить уведомления'
                        : 'Отключить уведомления',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _toggleMute(conversation);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_outlined),
                  title: const Text('Заблокировать пользователя'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _blockUser(conversation);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Удалить чат'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteConversation(conversation);
                  },
                ),
              ],
            ),
          ),
    );
  }

  List<ConversationModel> _filteredConversations() {
    final query = _searchQuery.trim().toLowerCase();
    final filtered =
        _conversations.where((conversation) {
          if (_favoritesOnly && !conversation.isFavorite) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final username = conversation.username.toLowerCase();
          final preview = (conversation.lastMessage ?? '').toLowerCase();
          return username.contains(query) || preview.contains(query);
        }).toList(growable: false);

    return filtered;
  }

  List<ConversationModel> _mainConversations() {
    return _filteredConversations()
        .where((conversation) {
          return !conversation.isArchived;
        })
        .toList(growable: false);
  }

  List<ConversationModel> _archivedConversations() {
    return _filteredConversations()
        .where((conversation) => conversation.isArchived)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final mainConversations = _mainConversations();
    final archivedConversations = _archivedConversations();
    final showEmptyState =
        mainConversations.isEmpty &&
        (!_showArchived || archivedConversations.isEmpty);

    return AppShell(
      currentSection: AppSection.chats,
      title: 'Чаты',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            _ChatsSearchBar(
              controller: _searchController,
              onClear:
                  _searchQuery.isEmpty
                      ? null
                      : () {
                        _searchController.clear();
                      },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilterChip(
                  selected: _favoritesOnly,
                  label: const Text('Избранные'),
                  avatar: const Icon(Icons.star_rounded, size: 18),
                  onSelected: (value) {
                    setState(() {
                      _favoritesOnly = value;
                    });
                  },
                ),
                const SizedBox(width: 10),
                if (archivedConversations.isNotEmpty)
                  ActionChip(
                    avatar: Icon(
                      _showArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _showArchived
                          ? 'Скрыть архив'
                          : 'Архив (${archivedConversations.length})',
                    ),
                    onPressed: () {
                      setState(() {
                        _showArchived = !_showArchived;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10203C).withValues(alpha: 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child:
                    _isLoading
                        ? const LoadingState()
                        : _errorMessage != null
                        ? ErrorState(
                          message: _errorMessage!,
                          onRetry: () => _loadConversations(),
                        )
                        : showEmptyState
                        ? RefreshIndicator(
                          onRefresh: () => _loadConversations(),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.all(24),
                            children: [
                              EmptyState(
                                icon:
                                    _searchQuery.isEmpty
                                        ? Icons.forum_outlined
                                        : Icons.search_off_rounded,
                                title:
                                    _searchQuery.isEmpty
                                        ? 'Пока нет диалогов'
                                        : 'Ничего не найдено',
                                subtitle:
                                    _searchQuery.isEmpty
                                        ? 'Откройте диалог из профиля, друзей или списка людей.'
                                        : 'Попробуйте другое имя или очистите поиск.',
                              ),
                            ],
                          ),
                        )
                        : RefreshIndicator(
                          onRefresh: () => _loadConversations(),
                          child: Scrollbar(
                            child: ListView(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                20,
                              ),
                              children: [
                                if (mainConversations.isNotEmpty) ...[
                                  const _SectionLabel(
                                    title: 'Диалоги',
                                    subtitle: 'Right swipe pins, left swipe archives',
                                  ),
                                  const SizedBox(height: 6),
                                  ...mainConversations.map(
                                    (conversation) => _ConversationListItem(
                                      conversation: conversation,
                                      onTap:
                                          () => context.push(
                                            '/chat',
                                            extra: ChatScreenArgs(
                                              conversationId: conversation.id,
                                              peerId: conversation.peerId,
                                              peerUsername:
                                                  conversation.username,
                                              peerAvatarUrl:
                                                  conversation.avatarUrl,
                                              peerAvatarScale:
                                                  conversation.avatarScale,
                                              peerAvatarOffsetX:
                                                  conversation.avatarOffsetX,
                                              peerAvatarOffsetY:
                                                  conversation.avatarOffsetY,
                                            ),
                                          ),
                                      onLongPress:
                                          () => _showChatActions(conversation),
                                      onPinToggle:
                                          () => _togglePin(conversation),
                                      onArchiveToggle:
                                          () => _toggleArchive(conversation),
                                    ),
                                  ),
                                ],
                                if (_showArchived &&
                                    archivedConversations.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  _SectionLabel(
                                    title: 'Архив',
                                    subtitle:
                                        '${archivedConversations.length} чатов',
                                  ),
                                  const SizedBox(height: 6),
                                  ...archivedConversations.map(
                                    (conversation) => _ConversationListItem(
                                      conversation: conversation,
                                      onTap:
                                          () => context.push(
                                            '/chat',
                                            extra: ChatScreenArgs(
                                              conversationId: conversation.id,
                                              peerId: conversation.peerId,
                                              peerUsername:
                                                  conversation.username,
                                              peerAvatarUrl:
                                                  conversation.avatarUrl,
                                              peerAvatarScale:
                                                  conversation.avatarScale,
                                              peerAvatarOffsetX:
                                                  conversation.avatarOffsetX,
                                              peerAvatarOffsetY:
                                                  conversation.avatarOffsetY,
                                            ),
                                          ),
                                      onLongPress:
                                          () => _showChatActions(conversation),
                                      onPinToggle:
                                          () => _togglePin(conversation),
                                      onArchiveToggle:
                                          () => _toggleArchive(conversation),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatsSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onClear;

  const _ChatsSearchBar({required this.controller, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF132443).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.search_rounded, color: Color(0xFF39538D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Поиск по чатам',
                border: InputBorder.none,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF7A869A),
                ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              color: const Color(0xFF5C6980),
            ),
        ],
      ),
    );
  }
}

enum _DeleteConversationMode { onlyForMe, forBoth }

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF21314E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A879A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationListItem extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPinToggle;
  final VoidCallback onArchiveToggle;

  const _ConversationListItem({
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
    required this.onPinToggle,
    required this.onArchiveToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(
        'conversation-${conversation.id}-${conversation.pinOrder}-${conversation.isArchived}',
      ),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onPinToggle();
        } else {
          onArchiveToggle();
        }
        return false;
      },
      background: _SwipeActionBackground(
        alignment: Alignment.centerLeft,
        color: const Color(0xFF2F67FF),
        icon:
            conversation.isPinned
                ? Icons.push_pin_rounded
                : Icons.push_pin_outlined,
        label:
            conversation.isPinned
                ? 'Открепить'
                : 'Закрепить',
      ),
      secondaryBackground: _SwipeActionBackground(
        alignment: Alignment.centerRight,
        color: const Color(0xFF17315A),
        icon:
            conversation.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
        label:
            conversation.isArchived
                ? 'Вернуть'
                : 'Архив',
      ),
      child: _ConversationTile(
        conversation: conversation,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.only(left: isLeft ? 20 : 0, right: isLeft ? 0 : 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            isLeft
                ? [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]
                : [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, color: Colors.white),
                ],
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final preview =
        conversation.lastMessage?.trim().isNotEmpty == true
            ? conversation.lastMessage!
            : 'Начните диалог';
    final hasUnread = conversation.unreadCount > 0;
    final statusIcons = [
      if (conversation.isPinned) Icons.push_pin_rounded,
      if (conversation.isFavorite) Icons.star_rounded,
      if (conversation.isMuted) Icons.notifications_off_rounded,
    ];
    final displayPreview =
        conversation.hasBlockedViewer
            ? 'Вы не можете писать этому пользователю'
            : conversation.isBlockedByViewer
            ? 'Вы заблокировали этого пользователя'
            : preview;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        margin: const EdgeInsets.only(bottom: 8),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF5F8FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          boxShadow:
              _isHovered
                  ? [
                    BoxShadow(
                      color: const Color(0xFF17325E).withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                  : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 78,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AppAvatar(
                          username: conversation.username,
                          imageUrl: conversation.avatarUrl,
                          size: 52,
                          scale: conversation.avatarScale,
                          offsetX: conversation.avatarOffsetX,
                          offsetY: conversation.avatarOffsetY,
                        ),
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color:
                                  conversation.isOnline
                                      ? const Color(0xFF2FD16C)
                                      : const Color(0xFFD8DFEA),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conversation.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF18243C),
                                    fontWeight:
                                        hasUnread
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (statusIcons.isNotEmpty)
                                ...statusIcons.map(
                                  (icon) => Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Icon(
                                      icon,
                                      size: 14,
                                      color: const Color(0xFF65748C),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayPreview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color:
                                  conversation.hasBlockedViewer ||
                                          conversation.isBlockedByViewer
                                      ? const Color(0xFF8A5A5A)
                                      : hasUnread
                                      ? const Color(0xFF3C4D69)
                                      : const Color(0xFF7A879A),
                              fontWeight:
                                  hasUnread ? FontWeight.w600 : FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatConversationTime(
                            conversation.lastMessageAt,
                            conversation.lastSeenAt,
                          ),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                hasUnread
                                    ? const Color(0xFF2F67FF)
                                    : const Color(0xFF7A879A),
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (hasUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            constraints: const BoxConstraints(minWidth: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F67FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              conversation.unreadCount > 99
                                  ? '99+'
                                  : '${conversation.unreadCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatConversationTime(
    DateTime? lastMessageAt,
    DateTime fallbackDate,
  ) {
    final local = (lastMessageAt ?? fallbackDate).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(local.year, local.month, local.day);
    final difference = today.difference(thatDay).inDays;

    if (difference <= 0) {
      return DateFormat('HH:mm').format(local);
    }

    if (difference == 1) {
      return 'Вчера';
    }

    if (difference < 7) {
      switch (local.weekday) {
        case DateTime.monday:
          return 'Пн';
        case DateTime.tuesday:
          return 'Вт';
        case DateTime.wednesday:
          return 'Ср';
        case DateTime.thursday:
          return 'Чт';
        case DateTime.friday:
          return 'Пт';
        case DateTime.saturday:
          return 'Сб';
        default:
          return 'Вс';
      }
    }

    return DateFormat('dd.MM').format(local);
  }
}

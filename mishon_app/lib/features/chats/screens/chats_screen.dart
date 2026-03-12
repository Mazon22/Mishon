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

  List<ConversationModel> _filteredConversations() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _conversations;
    }

    return _conversations
        .where((conversation) {
          final username = conversation.username.toLowerCase();
          final preview = (conversation.lastMessage ?? '').toLowerCase();
          return username.contains(query) || preview.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredConversations = _filteredConversations();

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
                        : filteredConversations.isEmpty
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
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                20,
                              ),
                              itemCount: filteredConversations.length,
                              itemBuilder: (context, index) {
                                final conversation =
                                    filteredConversations[index];
                                return _ConversationTile(
                                  conversation: conversation,
                                  onTap:
                                      () => context.push(
                                        '/chat',
                                        extra: ChatScreenArgs(
                                          conversationId: conversation.id,
                                          peerId: conversation.peerId,
                                          peerUsername: conversation.username,
                                          peerAvatarUrl: conversation.avatarUrl,
                                          peerAvatarScale:
                                              conversation.avatarScale,
                                          peerAvatarOffsetX:
                                              conversation.avatarOffsetX,
                                          peerAvatarOffsetY:
                                              conversation.avatarOffsetY,
                                        ),
                                      ),
                                );
                              },
                              separatorBuilder:
                                  (_, __) => Divider(
                                    height: 1,
                                    indent: 76,
                                    endIndent: 12,
                                    color: const Color(
                                      0xFFCFD9EA,
                                    ).withValues(alpha: 0.72),
                                  ),
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

class _ConversationTile extends StatefulWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
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
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 76,
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
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color:
                                  hasUnread
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

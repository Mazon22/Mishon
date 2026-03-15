import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/settings/app_settings_provider.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/chats/providers/chat_conversation_preview_provider.dart';
import 'package:mishon_app/features/chats/providers/chat_messages_provider.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';

final RegExp _photoCollectionPreviewPattern = RegExp(
  r'^(?:Фотографии|Photos):\s*(\d+)$',
  caseSensitive: false,
);
final RegExp _fileCollectionPreviewPattern = RegExp(
  r'^(?:Файлы|Files):\s*(\d+)$',
  caseSensitive: false,
);

String _conversationFallbackPreview(AppStrings strings) =>
    strings.isRu ? 'Начните диалог' : 'Start the conversation';

String _savedMessagesTitle() => 'Saved Messages';

String _savedMessagesSubtitle(AppStrings strings) =>
    strings.isRu
        ? 'Личные заметки, файлы и пересылки'
        : 'Private notes, files, and forwards';

String _localizeConversationPreview(String? rawPreview, AppStrings strings) {
  final trimmed = rawPreview?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return _conversationFallbackPreview(strings);
  }

  final normalized = trimmed.toLowerCase();
  if (normalized == 'фото' || normalized == 'photo') {
    return strings.isRu ? 'Фото' : 'Photo';
  }

  if (normalized == 'файл' || normalized == 'file') {
    return strings.isRu ? 'Файл' : 'File';
  }

  final photoCollectionMatch = _photoCollectionPreviewPattern.firstMatch(
    trimmed,
  );
  if (photoCollectionMatch != null) {
    final count = int.tryParse(photoCollectionMatch.group(1) ?? '');
    if (count != null) {
      return strings.isRu ? 'Фотографии: $count' : 'Photos: $count';
    }
  }

  final fileCollectionMatch = _fileCollectionPreviewPattern.firstMatch(trimmed);
  if (fileCollectionMatch != null) {
    final count = int.tryParse(fileCollectionMatch.group(1) ?? '');
    if (count != null) {
      return strings.isRu ? 'Файлы: $count' : 'Files: $count';
    }
  }

  return trimmed;
}

String _formatConversationTimeLabel(AppStrings strings, DateTime dateTime) {
  final local = dateTime.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(local.year, local.month, local.day);
  final difference = today.difference(thatDay).inDays;

  if (difference <= 0) {
    return DateFormat('HH:mm').format(local);
  }

  if (difference == 1) {
    return strings.isRu ? 'Вчера' : 'Yesterday';
  }

  if (difference < 7) {
    switch (local.weekday) {
      case DateTime.monday:
        return strings.isRu ? 'Пн' : 'Mon';
      case DateTime.tuesday:
        return strings.isRu ? 'Вт' : 'Tue';
      case DateTime.wednesday:
        return strings.isRu ? 'Ср' : 'Wed';
      case DateTime.thursday:
        return strings.isRu ? 'Чт' : 'Thu';
      case DateTime.friday:
        return strings.isRu ? 'Пт' : 'Fri';
      case DateTime.saturday:
        return strings.isRu ? 'Сб' : 'Sat';
      default:
        return strings.isRu ? 'Вс' : 'Sun';
    }
  }

  return DateFormat('dd.MM').format(local);
}

class ChatsScreen extends ConsumerStatefulWidget {
  final bool embeddedInNavigationShell;

  const ChatsScreen({super.key, this.embeddedInNavigationShell = false});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  Timer? _poller;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  bool _showArchived = false;
  List<ConversationModel> _conversations = const [];

  @override
  void initState() {
    super.initState();
    final repository = ref.read(socialRepositoryProvider);
    final cachedConversations = repository.peekConversations();
    if (cachedConversations != null) {
      final previewOverrides = ref.read(
        chatConversationPreviewOverridesProvider,
      );
      _conversations = cachedConversations
          .map(
            (conversation) => _applyConversationPreviewOverride(
              conversation,
              previewOverrides[conversation.id],
            ),
          )
          .toList(growable: false);
      _isLoading = false;
    }
    _searchController.addListener(_handleSearchChanged);
    unawaited(_loadConversations(silent: cachedConversations != null));
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
    final isRu = ref.read(appSettingsProvider).language == AppLanguage.ru;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final conversations = await ref
          .read(socialRepositoryProvider)
          .getConversations(forceRefresh: true);
      final previewOverrides = ref.read(
        chatConversationPreviewOverridesProvider,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _conversations = conversations
            .map(
              (conversation) => _applyConversationPreviewOverride(
                conversation,
                previewOverrides[conversation.id],
              ),
            )
            .toList(growable: false);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      if (silent && _conversations.isNotEmpty) {
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

      if (silent && _conversations.isNotEmpty) {
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

      if (silent && _conversations.isNotEmpty) {
        return;
      }

      setState(() {
        _errorMessage =
            isRu
                ? 'Не удалось загрузить диалоги'
                : 'Could not load the conversations';
        _isLoading = false;
      });
    }
  }

  ConversationModel _applyConversationPreviewOverride(
    ConversationModel conversation,
    ConversationPreviewOverride? override,
  ) {
    if (override == null) {
      return conversation;
    }

    final serverLastMessageAt = conversation.lastMessageAt;
    final overrideLastMessageAt = override.lastMessageAt;
    if (serverLastMessageAt != null &&
        overrideLastMessageAt != null &&
        overrideLastMessageAt.isBefore(serverLastMessageAt)) {
      return conversation;
    }

    return conversation.copyWith(
      lastMessage: override.lastMessage,
      lastMessageAt: override.lastMessageAt,
      lastMessageIsMine: override.lastMessageIsMine,
      lastMessageIsDeliveredToPeer: override.lastMessageIsDeliveredToPeer,
      lastMessageIsReadByPeer: override.lastMessageIsReadByPeer,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted || !isError) {
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
    final strings = AppStrings.of(context);
    try {
      await ref
          .read(socialRepositoryProvider)
          .pinConversation(conversation.id, !conversation.isPinned);
      await _loadConversations(silent: true);
      _showSnackBar(
        conversation.isPinned
            ? (strings.isRu ? 'Чат откреплен' : 'Chat unpinned')
            : (strings.isRu ? 'Чат закреплен' : 'Chat pinned'),
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось изменить закрепление чата'
            : 'Could not update the pin status',
        isError: true,
      );
    }
  }

  Future<void> _toggleArchive(ConversationModel conversation) async {
    final strings = AppStrings.of(context);
    try {
      await ref
          .read(socialRepositoryProvider)
          .archiveConversation(conversation.id, !conversation.isArchived);
      await _loadConversations(silent: true);
      _showSnackBar(
        conversation.isArchived
            ? (strings.isRu ? 'Чат возвращен из архива' : 'Chat restored')
            : (strings.isRu ? 'Чат отправлен в архив' : 'Chat archived'),
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось изменить архив чата'
            : 'Could not update the archive state',
        isError: true,
      );
    }
  }

  Future<void> _toggleMute(ConversationModel conversation) async {
    final strings = AppStrings.of(context);
    try {
      await ref
          .read(socialRepositoryProvider)
          .muteConversation(conversation.id, !conversation.isMuted);
      await _loadConversations(silent: true);
      _showSnackBar(
        conversation.isMuted
            ? (strings.isRu ? 'Уведомления включены' : 'Notifications enabled')
            : (strings.isRu ? 'Уведомления отключены' : 'Notifications muted'),
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось обновить уведомления'
            : 'Could not update notifications',
        isError: true,
      );
    }
  }

  Future<void> _deleteConversation(ConversationModel conversation) async {
    final strings = AppStrings.of(context);
    final decision = await showDialog<_DeleteConversationMode>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(strings.isRu ? 'Удалить чат?' : 'Delete chat?'),
            content: Text(
              strings.isRu
                  ? 'Диалог с ${conversation.username} можно удалить только у вас или у обоих пользователей.'
                  : 'You can delete the conversation with ${conversation.username} only for yourself or for both users.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(strings.cancel),
              ),
              TextButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pop(_DeleteConversationMode.onlyForMe),
                child: Text(strings.deleteForMe),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pop(_DeleteConversationMode.forBoth),
                child: Text(strings.deleteForEveryone),
              ),
            ],
          ),
    );

    if (decision == null) {
      return;
    }

    try {
      await ref
          .read(socialRepositoryProvider)
          .deleteConversation(
            conversation.id,
            deleteForBoth: decision == _DeleteConversationMode.forBoth,
          );
      await _loadConversations(silent: true);
      _showSnackBar(strings.isRu ? 'Чат удален' : 'Chat deleted');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu ? 'Не удалось удалить чат' : 'Could not delete the chat',
        isError: true,
      );
    }
  }

  Future<void> _blockUser(ConversationModel conversation) async {
    final strings = AppStrings.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  strings.isRu ? 'Заблокировать пользователя?' : 'Block user?',
                ),
                content: Text(
                  strings.isRu
                      ? 'Вы уверены, что хотите заблокировать ${conversation.username}?'
                      : 'Are you sure you want to block ${conversation.username}?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(strings.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(strings.isRu ? 'Заблокировать' : 'Block user'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(socialRepositoryProvider)
          .blockUserFromChat(conversation.peerId);
      await _loadConversations(silent: true);
      _showSnackBar(
        strings.isRu ? 'Пользователь заблокирован' : 'User blocked',
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось заблокировать пользователя'
            : 'Could not block the user',
        isError: true,
      );
    }
  }

  Future<void> _showChatActions(ConversationModel conversation) async {
    final strings = AppStrings.of(context);
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
                    conversation.isPinned
                        ? (strings.isRu ? 'Открепить чат' : 'Unpin chat')
                        : (strings.isRu ? 'Закрепить чат' : 'Pin chat'),
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
                        ? (strings.isRu
                            ? 'Вернуть из архива'
                            : 'Restore from archive')
                        : (strings.isRu ? 'Архивировать' : 'Archive'),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _toggleArchive(conversation);
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
                        ? (strings.isRu
                            ? 'Включить уведомления'
                            : 'Enable notifications')
                        : (strings.isRu
                            ? 'Отключить уведомления'
                            : 'Mute notifications'),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _toggleMute(conversation);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_outlined),
                  title: Text(
                    strings.isRu ? 'Заблокировать пользователя' : 'Block user',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _blockUser(conversation);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(strings.isRu ? 'Удалить чат' : 'Delete chat'),
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

  void _pushChat({
    required int conversationId,
    required int peerId,
    required String peerUsername,
    required String? peerAvatarUrl,
    required double peerAvatarScale,
    required double peerAvatarOffsetX,
    required double peerAvatarOffsetY,
    required bool? initialIsOnline,
    required DateTime? initialLastSeenAt,
  }) {
    unawaited(
      ref
          .read(chatMessagesNotifierProvider(conversationId).notifier)
          .ensureLoaded(),
    );
    context.push(
      '/chat',
      extra: ChatScreenArgs(
        conversationId: conversationId,
        peerId: peerId,
        peerUsername: peerUsername,
        peerAvatarUrl: peerAvatarUrl,
        peerAvatarScale: peerAvatarScale,
        peerAvatarOffsetX: peerAvatarOffsetX,
        peerAvatarOffsetY: peerAvatarOffsetY,
        initialIsOnline: initialIsOnline,
        initialLastSeenAt: initialLastSeenAt,
      ),
    );
  }

  void _openConversation(
    ConversationModel conversation, {
    String? titleOverride,
  }) {
    _pushChat(
      conversationId: conversation.id,
      peerId: conversation.peerId,
      peerUsername: titleOverride ?? conversation.username,
      peerAvatarUrl: conversation.avatarUrl,
      peerAvatarScale: conversation.avatarScale,
      peerAvatarOffsetX: conversation.avatarOffsetX,
      peerAvatarOffsetY: conversation.avatarOffsetY,
      initialIsOnline: conversation.isOnline,
      initialLastSeenAt: conversation.lastSeenAt,
    );
  }

  Future<void> _openSavedMessages(ConversationModel? conversation) async {
    final strings = AppStrings.of(context);
    if (conversation != null) {
      _openConversation(conversation, titleOverride: _savedMessagesTitle());
      return;
    }

    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      return;
    }

    try {
      final authRepository = ref.read(authRepositoryProvider);
      UserProfile? currentProfile = authRepository.peekProfile();
      if (currentProfile == null) {
        try {
          currentProfile = await authRepository.getProfile();
        } catch (_) {
          currentProfile = null;
        }
      }

      final createdConversation = await ref
          .read(socialRepositoryProvider)
          .getOrCreateConversation(currentUserId);
      if (!mounted) {
        return;
      }

      await _loadConversations(silent: true);
      if (!mounted) {
        return;
      }

      _pushChat(
        conversationId: createdConversation.id,
        peerId: createdConversation.peerId,
        peerUsername: _savedMessagesTitle(),
        peerAvatarUrl:
            currentProfile?.avatarUrl ?? createdConversation.avatarUrl,
        peerAvatarScale:
            currentProfile?.avatarScale ?? createdConversation.avatarScale,
        peerAvatarOffsetX:
            currentProfile?.avatarOffsetX ?? createdConversation.avatarOffsetX,
        peerAvatarOffsetY:
            currentProfile?.avatarOffsetY ?? createdConversation.avatarOffsetY,
        initialIsOnline:
            currentProfile?.isOnline ?? createdConversation.isOnline,
        initialLastSeenAt:
            currentProfile?.lastSeenAt ?? createdConversation.lastSeenAt,
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось открыть Saved Messages'
            : 'Could not open Saved Messages',
        isError: true,
      );
    }
  }

  ConversationModel? _savedMessagesConversation(int? currentUserId) {
    if (currentUserId == null) {
      return null;
    }

    for (final conversation in _conversations) {
      if (conversation.peerId == currentUserId) {
        return conversation;
      }
    }

    return null;
  }

  List<ConversationModel> _filteredConversations(int? currentUserId) {
    final strings = AppStrings.of(context);
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _conversations
        .where((conversation) {
          if (currentUserId != null && conversation.peerId == currentUserId) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final username = conversation.username.toLowerCase();
          final preview =
              _localizeConversationPreview(
                conversation.lastMessage,
                strings,
              ).toLowerCase();
          return username.contains(query) || preview.contains(query);
        })
        .toList(growable: false);

    return filtered;
  }

  List<ConversationModel> _mainConversations(int? currentUserId) {
    return _filteredConversations(currentUserId)
        .where((conversation) {
          return !conversation.isArchived;
        })
        .toList(growable: false);
  }

  List<ConversationModel> _archivedConversations(int? currentUserId) {
    return _filteredConversations(
      currentUserId,
    ).where((conversation) => conversation.isArchived).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
    final currentProfile = ref.watch(authRepositoryProvider).peekProfile();
    final savedMessagesConversation = _savedMessagesConversation(currentUserId);
    final mainConversations = _mainConversations(currentUserId);
    final archivedConversations = _archivedConversations(currentUserId);
    final showEmptyState =
        mainConversations.isEmpty &&
        (!_showArchived || archivedConversations.isEmpty);

    return AppShell(
      currentSection: AppSection.chats,
      title: strings.chats,
      showSectionNavigation: !widget.embeddedInNavigationShell,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            _ChatsSearchBar(
              controller: _searchController,
              hintText: strings.isRu ? 'Поиск по чатам' : 'Search chats',
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
                Expanded(
                  child: _SavedMessagesShortcutCard(
                    username: currentProfile?.username ?? strings.profile,
                    avatarUrl: currentProfile?.avatarUrl,
                    avatarScale: currentProfile?.avatarScale ?? 1,
                    avatarOffsetX: currentProfile?.avatarOffsetX ?? 0,
                    avatarOffsetY: currentProfile?.avatarOffsetY ?? 0,
                    title: _savedMessagesTitle(),
                    subtitle:
                        savedMessagesConversation == null
                            ? _savedMessagesSubtitle(strings)
                            : _localizeConversationPreview(
                              savedMessagesConversation.lastMessage,
                              strings,
                            ),
                    timeLabel:
                        savedMessagesConversation?.lastMessageAt != null
                            ? _formatConversationTimeLabel(
                              strings,
                              savedMessagesConversation!.lastMessageAt!,
                            )
                            : null,
                    onTap:
                        currentUserId == null
                            ? null
                            : () =>
                                _openSavedMessages(savedMessagesConversation),
                  ),
                ),
                if (archivedConversations.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  _ChatsActionPill(
                    icon:
                        _showArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                    label:
                        _showArchived
                            ? (strings.isRu ? 'Скрыть архив' : 'Hide archive')
                            : '${strings.isRu ? 'Архив' : 'Archive'} (${archivedConversations.length})',
                    isActive: _showArchived,
                    onTap: () {
                      setState(() {
                        _showArchived = !_showArchived;
                      });
                    },
                  ),
                ],
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
                                        ? (strings.isRu
                                            ? 'Пока нет диалогов'
                                            : 'No conversations yet')
                                        : (strings.isRu
                                            ? 'Ничего не найдено'
                                            : 'Nothing found'),
                                subtitle:
                                    _searchQuery.isEmpty
                                        ? (strings.isRu
                                            ? 'Откройте диалог из профиля, друзей или списка людей.'
                                            : 'Open a conversation from a profile, friends, or people list.')
                                        : (strings.isRu
                                            ? 'Попробуйте другое имя или очистите поиск.'
                                            : 'Try another name or clear the search.'),
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
                                  _SectionLabel(
                                    title:
                                        strings.isRu
                                            ? 'Диалоги'
                                            : 'Conversations',
                                    subtitle: strings.chatSwipeHint,
                                  ),
                                  const SizedBox(height: 6),
                                  ...mainConversations.map(
                                    (conversation) => _ConversationListItem(
                                      conversation: conversation,
                                      onTap:
                                          () => _openConversation(conversation),
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
                                    title: strings.isRu ? 'Архив' : 'Archive',
                                    subtitle:
                                        strings.isRu
                                            ? '${archivedConversations.length} чатов'
                                            : '${archivedConversations.length} chats',
                                  ),
                                  const SizedBox(height: 6),
                                  ...archivedConversations.map(
                                    (conversation) => _ConversationListItem(
                                      conversation: conversation,
                                      onTap:
                                          () => _openConversation(conversation),
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
  final String hintText;
  final VoidCallback? onClear;

  const _ChatsSearchBar({
    required this.controller,
    required this.hintText,
    required this.onClear,
  });

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
                hintText: hintText,
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

class _SavedMessagesShortcutCard extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final String title;
  final String subtitle;
  final String? timeLabel;
  final VoidCallback? onTap;

  const _SavedMessagesShortcutCard({
    required this.username,
    required this.avatarUrl,
    required this.avatarScale,
    required this.avatarOffsetX,
    required this.avatarOffsetY,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onTap == null ? 0.58 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            height: 82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFF7FBFF),
                  Color(0xFFEAF2FF),
                  Color(0xFFE7FFF5),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF12294D).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppAvatar(
                        username: username,
                        imageUrl: avatarUrl,
                        size: 52,
                        scale: avatarScale,
                        offsetX: avatarOffsetX,
                        offsetY: avatarOffsetY,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F67FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.bookmark_rounded,
                            size: 11,
                            color: Colors.white,
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
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF18243C),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6F7E92),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (timeLabel != null)
                        Text(
                          timeLabel!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF2F67FF),
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Color(0xFF6B7B90),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatsActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ChatsActionPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:
                isActive
                    ? const Color(0xFF213F82)
                    : Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  isActive
                      ? const Color(0xFF213F82)
                      : Colors.white.withValues(alpha: 0.9),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF13294F).withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : const Color(0xFF314B82),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isActive ? Colors.white : const Color(0xFF233A69),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
    final strings = AppStrings.of(context);
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
                ? (strings.isRu ? 'Открепить' : 'Unpin')
                : (strings.isRu ? 'Закрепить' : 'Pin'),
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
                ? (strings.isRu ? 'Вернуть' : 'Restore')
                : (strings.isRu ? 'Архив' : 'Archive'),
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

class _LastMessageStatusIcon extends StatelessWidget {
  final ConversationModel conversation;

  const _LastMessageStatusIcon({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final icon =
        conversation.lastMessageIsReadByPeer
            ? Icons.done_all
            : conversation.lastMessageIsDeliveredToPeer
            ? Icons.done_all
            : Icons.done;
    final color =
        conversation.lastMessageIsReadByPeer
            ? const Color(0xFF59B86C)
            : const Color(0xFF8A97AA);

    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Icon(icon, size: 16, color: color),
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
    final strings = AppStrings.of(context);
    final preview =
        conversation.lastMessage?.trim().isNotEmpty == true
            ? conversation.lastMessage!
            : (strings.isRu ? 'Начните диалог' : 'Start the conversation');
    final localizedPreview = _localizeConversationPreview(preview, strings);
    final hasUnread = conversation.unreadCount > 0;
    final statusIcons = [
      if (conversation.isPinned) Icons.push_pin_rounded,
      if (conversation.isMuted) Icons.notifications_off_rounded,
    ];
    final displayPreview =
        conversation.hasBlockedViewer
            ? (strings.isRu
                ? 'Вы не можете писать этому пользователю'
                : 'You cannot message this user')
            : conversation.isBlockedByViewer
            ? (strings.isRu
                ? 'Вы заблокировали этого пользователя'
                : 'You blocked this user')
            : localizedPreview;
    final showLastMessageStatus =
        conversation.lastMessageIsMine &&
        !conversation.hasBlockedViewer &&
        !conversation.isBlockedByViewer;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        margin: const EdgeInsets.only(bottom: 8),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color:
              _isHovered
                  ? const Color(0xFFF6F9FF)
                  : Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                _isHovered ? const Color(0xFFD4E1F7) : const Color(0xFFE1E8F5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF17325E,
              ).withValues(alpha: _isHovered ? 0.08 : 0.035),
              blurRadius: _isHovered ? 18 : 12,
              offset: const Offset(0, 8),
            ),
          ],
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
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
                                        hasUnread
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showLastMessageStatus) ...[
                              _LastMessageStatusIcon(
                                conversation: conversation,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              _formatConversationTime(
                                context,
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
                                    hasUnread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                              ),
                            ),
                          ],
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

  String _formatConversationTime(
    BuildContext context,
    DateTime? lastMessageAt,
    DateTime fallbackDate,
  ) {
    final strings = AppStrings.of(context);
    final local = (lastMessageAt ?? fallbackDate).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(local.year, local.month, local.day);
    final difference = today.difference(thatDay).inDays;

    if (difference <= 0) {
      return DateFormat('HH:mm').format(local);
    }

    if (difference == 1) {
      return strings.isRu ? 'Вчера' : 'Yesterday';
    }

    if (difference < 7) {
      switch (local.weekday) {
        case DateTime.monday:
          return strings.isRu ? 'Пн' : 'Mon';
        case DateTime.tuesday:
          return strings.isRu ? 'Вт' : 'Tue';
        case DateTime.wednesday:
          return strings.isRu ? 'Ср' : 'Wed';
        case DateTime.thursday:
          return strings.isRu ? 'Чт' : 'Thu';
        case DateTime.friday:
          return strings.isRu ? 'Пт' : 'Fri';
        case DateTime.saturday:
          return strings.isRu ? 'Сб' : 'Sat';
        default:
          return strings.isRu ? 'Вс' : 'Sun';
      }
    }

    return DateFormat('dd.MM').format(local);
  }
}

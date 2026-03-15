import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/settings/app_settings_provider.dart';
import 'package:mishon_app/core/utils/attachment_picker.dart';
import 'package:mishon_app/core/utils/external_url.dart';
import 'package:mishon_app/core/widgets/fullscreen_image_screen.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/chats/providers/chat_conversation_preview_provider.dart';
import 'package:mishon_app/features/chats/providers/chat_messages_provider.dart';
import 'package:mishon_app/features/chats/providers/chat_realtime_service.dart';
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';

class ChatScreenArgs {
  final int conversationId;
  final int peerId;
  final String peerUsername;
  final String? peerAvatarUrl;
  final double peerAvatarScale;
  final double peerAvatarOffsetX;
  final double peerAvatarOffsetY;
  final bool? initialIsOnline;
  final DateTime? initialLastSeenAt;

  const ChatScreenArgs({
    required this.conversationId,
    required this.peerId,
    required this.peerUsername,
    required this.peerAvatarUrl,
    this.peerAvatarScale = 1,
    this.peerAvatarOffsetX = 0,
    this.peerAvatarOffsetY = 0,
    this.initialIsOnline,
    this.initialLastSeenAt,
  });
}

String _messageContextPreview(
  AppStrings strings, {
  required String content,
  required int attachmentCount,
  required bool hasImageAttachment,
}) {
  final trimmed = content.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }

  if (attachmentCount == 0) {
    return strings.message;
  }

  if (hasImageAttachment) {
    return attachmentCount > 1
        ? (strings.isRu ? 'Фотографии' : 'Photos')
        : (strings.isRu ? 'Фото' : 'Photo');
  }

  return attachmentCount > 1
      ? (strings.isRu ? 'Файлы' : 'Files')
      : (strings.isRu ? 'Файл' : 'File');
}

String _messagePreviewLabel(AppStrings strings, ChatMessageModel message) {
  return _messageContextPreview(
    strings,
    content: message.content,
    attachmentCount: message.attachments.length,
    hasImageAttachment: message.attachments.any(
      (attachment) => attachment.isImage,
    ),
  );
}

String _localMessagePreviewLabel(
  AppStrings strings,
  _LocalOutgoingMessage message,
) {
  return _messageContextPreview(
    strings,
    content: message.content,
    attachmentCount: message.attachments.length,
    hasImageAttachment: message.attachments.any(
      (attachment) => attachment.isImage,
    ),
  );
}

final RegExp _photoCollectionPreviewPattern = RegExp(
  r'^(?:Фотографии|Photos):\s*(\d+)$',
  caseSensitive: false,
);
final RegExp _fileCollectionPreviewPattern = RegExp(
  r'^(?:Файлы|Files):\s*(\d+)$',
  caseSensitive: false,
);
final RegExp _attachmentsCollectionPreviewPattern = RegExp(
  r'^(?:Вложения|Attachments):\s*(\d+)$',
  caseSensitive: false,
);

String _localizeChatGeneratedPreview(
  String? rawPreview,
  AppStrings strings, {
  String? fallback,
}) {
  final trimmed = rawPreview?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return fallback ?? strings.message;
  }

  final normalized = trimmed.toLowerCase();
  if (normalized == 'фото' || normalized == 'photo') {
    return strings.isRu ? 'Фото' : 'Photo';
  }

  if (normalized == 'файл' || normalized == 'file') {
    return strings.isRu ? 'Файл' : 'File';
  }

  if (normalized == 'вложение' || normalized == 'attachment') {
    return strings.attachment;
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

  final attachmentsCollectionMatch = _attachmentsCollectionPreviewPattern
      .firstMatch(trimmed);
  if (attachmentsCollectionMatch != null) {
    final count = int.tryParse(attachmentsCollectionMatch.group(1) ?? '');
    if (count != null) {
      return strings.isRu ? 'Вложения: $count' : 'Attachments: $count';
    }
  }

  return trimmed;
}

class ChatScreen extends ConsumerStatefulWidget {
  final ChatScreenArgs args;

  const ChatScreen({super.key, required this.args});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  static const int _maxAttachmentBytes = 15 * 1024 * 1024;
  static const double _backSwipeEdgeWidth = 32;
  static const double _backSwipeDistanceThreshold = 88;
  static const double _backSwipeVelocityThreshold = 900;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatRealtimeService _chatRealtimeService;
  bool _isSending = false;
  ChatMessageModel? _replyingTo;
  ChatMessageModel? _editingMessage;
  UserProfile? _peerProfile;
  List<_PendingAttachment> _pendingAttachments = const [];
  List<_LocalOutgoingMessage> _localOutgoingMessages = const [];
  double? _backSwipeStartX;
  double _backSwipeTravel = 0;
  bool _didTriggerBackSwipe = false;

  @override
  void initState() {
    super.initState();
    _chatRealtimeService = ref.read(chatRealtimeServiceProvider);
    _messageController.addListener(_handleComposerChanged);
    _scrollController.addListener(_handleScrollChanged);
    ref
        .read(chatMessagesNotifierProvider(widget.args.conversationId).notifier)
        .ensureLoaded();
    unawaited(_chatRealtimeService.ensureConnected());
    unawaited(_loadPeerProfile());
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleComposerChanged);
    _scrollController.removeListener(_handleScrollChanged);
    unawaited(_chatRealtimeService.stopTyping(widget.args.conversationId));
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _handleComposerChanged() {
    final isTyping = _messageController.text.trim().isNotEmpty;
    if (_editingMessage != null) {
      unawaited(_chatRealtimeService.stopTyping(widget.args.conversationId));
      return;
    }

    unawaited(
      _chatRealtimeService.reportTypingActivity(
        widget.args.conversationId,
        isComposing: isTyping,
      ),
    );
  }

  bool _isNearLatest({double threshold = 96}) {
    if (!_scrollController.hasClients) {
      return true;
    }

    final position = _scrollController.position;
    return position.pixels <= threshold;
  }

  bool _isNearHistoryTop({double threshold = 200}) {
    if (!_scrollController.hasClients) {
      return false;
    }

    final position = _scrollController.position;
    return position.pixels >= position.maxScrollExtent - threshold;
  }

  void _handleScrollChanged() {
    final notifier = ref.read(
      chatMessagesNotifierProvider(widget.args.conversationId).notifier,
    );
    notifier.setLiveUpdatesEnabled(_isNearLatest());
    if (_isNearHistoryTop()) {
      unawaited(notifier.loadOlder());
    }
  }

  void _handleBackSwipeStart(DragStartDetails details) {
    if (details.globalPosition.dx > _backSwipeEdgeWidth) {
      _resetBackSwipe();
      return;
    }

    _backSwipeStartX = details.globalPosition.dx;
    _backSwipeTravel = 0;
    _didTriggerBackSwipe = false;
  }

  void _handleBackSwipeUpdate(DragUpdateDetails details) {
    if (_backSwipeStartX == null || _didTriggerBackSwipe) {
      return;
    }

    final delta = details.primaryDelta ?? 0;
    if (delta <= 0) {
      if (_backSwipeTravel + delta <= 0) {
        _resetBackSwipe();
      }
      return;
    }

    _backSwipeTravel += delta;
    if (_backSwipeTravel >= _backSwipeDistanceThreshold) {
      _didTriggerBackSwipe = true;
      _navigateBackToChats();
    }
  }

  void _handleBackSwipeEnd(DragEndDetails details) {
    if (_backSwipeStartX == null || _didTriggerBackSwipe) {
      _resetBackSwipe();
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    if (velocity >= _backSwipeVelocityThreshold &&
        _backSwipeTravel >= _backSwipeDistanceThreshold / 3) {
      _didTriggerBackSwipe = true;
      _navigateBackToChats();
      return;
    }

    _resetBackSwipe();
  }

  void _resetBackSwipe() {
    _backSwipeStartX = null;
    _backSwipeTravel = 0;
    _didTriggerBackSwipe = false;
  }

  void _navigateBackToChats() {
    if (!mounted) {
      return;
    }

    _resetBackSwipe();
    HapticFeedback.lightImpact();
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    context.goNamed('chats');
  }

  Future<void> _loadPeerProfile({bool silent = false}) async {
    final isRu = ref.read(appSettingsProvider).language == AppLanguage.ru;
    try {
      final authRepository = ref.read(authRepositoryProvider);
      final currentUserId = ref.read(currentUserIdProvider);
      final profile =
          currentUserId != null && widget.args.peerId == currentUserId
              ? await authRepository.getProfile()
              : await authRepository.getUserProfile(widget.args.peerId);
      if (!mounted) {
        return;
      }

      setState(() {
        _peerProfile = profile;
      });
    } on ApiException catch (_) {
      if (!silent && mounted) {
        _showSnackBar(
          isRu
              ? 'Не удалось загрузить статус собеседника'
              : 'Could not load the contact status',
          isError: true,
        );
      }
    } on OfflineException catch (_) {
      if (!silent && mounted) {
        _showSnackBar(
          isRu
              ? 'Нет соединения для загрузки статуса'
              : 'No connection to load the status',
          isError: true,
        );
      }
    } catch (_) {
      if (!silent && mounted) {
        _showSnackBar(
          isRu
              ? 'Не удалось обновить статус собеседника'
              : 'Could not refresh the contact status',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickAttachments(AttachmentPickType type) async {
    final strings = AppStrings.of(context);
    if (_editingMessage != null) {
      _showSnackBar(
        strings.isRu
            ? 'Во время редактирования вложения менять нельзя'
            : 'Attachments cannot be changed while editing',
        isError: true,
      );
      return;
    }

    try {
      final result = await pickAttachments(type: type);
      if (result == null || result.isEmpty || !mounted) {
        return;
      }

      final selected = result
          .map(
            (file) => _PendingAttachment(
              fileName: file.fileName,
              bytes: file.bytes,
              isImage: type == AttachmentPickType.image,
            ),
          )
          .toList(growable: false);

      final totalBytes =
          _pendingAttachments.fold<int>(
            0,
            (sum, item) => sum + item.sizeBytes,
          ) +
          selected.fold<int>(0, (sum, item) => sum + item.sizeBytes);
      if (totalBytes > _maxAttachmentBytes) {
        _showSnackBar(
          strings.isRu
              ? 'Общий размер вложений не должен превышать 15 МБ'
              : 'Attachments must stay under 15 MB in total',
          isError: true,
        );
        return;
      }

      setState(() {
        _pendingAttachments = [..._pendingAttachments, ...selected];
      });
    } catch (error) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось выбрать файлы: $error'
            : 'Could not pick files: $error',
        isError: true,
      );
    }
  }

  Future<void> _submit() async {
    final strings = AppStrings.of(context);
    final content = _messageController.text.trim();
    final hasAttachments = _pendingAttachments.isNotEmpty;
    final peerBlockedViewer = _peerProfile?.hasBlockedViewer ?? false;
    final viewerBlockedPeer = _peerProfile?.isBlockedByViewer ?? false;
    final notificationSummaryNotifier = ref.read(
      notificationSummaryProvider.notifier,
    );
    if (_isSending) {
      return;
    }
    if (peerBlockedViewer || viewerBlockedPeer) {
      _showSnackBar(
        peerBlockedViewer
            ? strings.youCannotSendMessagesToThisUser
            : strings.unblockUserFirst,
        isError: true,
      );
      return;
    }
    if (_editingMessage != null && content.isEmpty) {
      return;
    }
    if (_editingMessage == null && content.isEmpty && !hasAttachments) {
      return;
    }
    final wasNearLatest = _isNearLatest();
    final messagesNotifier = ref.read(
      chatMessagesNotifierProvider(widget.args.conversationId).notifier,
    );
    final realtimeService = ref.read(chatRealtimeServiceProvider);
    if (_editingMessage != null) {
      setState(() => _isSending = true);
      try {
        final updatedMessage = await ref
            .read(socialRepositoryProvider)
            .updateMessage(
              widget.args.conversationId,
              _editingMessage!.id,
              content,
            );
        messagesNotifier.upsertMessage(updatedMessage);
        _showSnackBar(strings.messageUpdated);
        _resetComposer();
        await realtimeService.stopTyping(widget.args.conversationId);
      } on ApiException catch (e) {
        _showSnackBar(e.apiError.message, isError: true);
      } on OfflineException catch (e) {
        _showSnackBar(e.message, isError: true);
      } catch (_) {
        _showSnackBar(strings.failedToSaveMessage, isError: true);
      } finally {
        if (mounted) {
          setState(() => _isSending = false);
        }
      }
      return;
    }
    final localMessage = _createLocalOutgoingMessage(
      content,
      List<_PendingAttachment>.of(_pendingAttachments),
      _replyingTo,
    );
    setState(() {
      _localOutgoingMessages = [..._localOutgoingMessages, localMessage];
      _isSending = true;
    });
    _resetComposer();
    await realtimeService.stopTyping(widget.args.conversationId);
    if (wasNearLatest) {
      _scrollToLatest();
    }
    await _sendLocalOutgoingMessage(
      localMessage,
      scrollToLatest: wasNearLatest,
    );
    unawaited(notificationSummaryNotifier.refresh(silent: true));
  }

  Future<void> _deleteMessageForMe(ChatMessageModel message) async {
    final strings = AppStrings.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  strings.isRu ? 'Удалить сообщение?' : 'Delete message?',
                ),
                content: Text(
                  strings.isRu
                      ? 'После удаления вернуть его уже не получится.'
                      : 'This action cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(strings.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(strings.delete),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    final socialRepository = ref.read(socialRepositoryProvider);
    final messagesNotifier = ref.read(
      chatMessagesNotifierProvider(widget.args.conversationId).notifier,
    );
    try {
      await socialRepository.deleteMessage(
        widget.args.conversationId,
        message.id,
      );
      if (_editingMessage?.id == message.id || _replyingTo?.id == message.id) {
        _resetComposer();
      }
      messagesNotifier.removeMessage(message.id);
      _showSnackBar(strings.isRu ? 'Сообщение удалено' : 'Message deleted');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось удалить сообщение'
            : 'Could not delete the message',
        isError: true,
      );
    }
  }

  Future<void> _deleteMessageForEveryone(ChatMessageModel message) async {
    final strings = AppStrings.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  strings.isRu ? 'Удалить у всех?' : 'Delete for everyone?',
                ),
                content: Text(
                  strings.isRu
                      ? 'Сообщение исчезнет у вас и у собеседника.'
                      : 'The message will disappear for both users.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(strings.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(strings.delete),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    final socialRepository = ref.read(socialRepositoryProvider);
    final messagesNotifier = ref.read(
      chatMessagesNotifierProvider(widget.args.conversationId).notifier,
    );
    try {
      await socialRepository.deleteMessageForAll(
        widget.args.conversationId,
        message.id,
      );
      if (_editingMessage?.id == message.id || _replyingTo?.id == message.id) {
        _resetComposer();
      }
      messagesNotifier.removeMessage(message.id);
      _showSnackBar(
        strings.isRu
            ? 'Сообщение удалено у всех'
            : 'Message deleted for everyone',
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось удалить сообщение у всех'
            : 'Could not delete the message for everyone',
        isError: true,
      );
    }
  }

  Future<void> _clearHistory() async {
    final strings = AppStrings.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  strings.isRu ? 'Очистить историю?' : 'Clear history?',
                ),
                content: Text(
                  strings.isRu
                      ? 'Все сообщения исчезнут только у вас, сам чат останется.'
                      : 'Messages will be cleared only for you, the chat will remain.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(strings.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(strings.isRu ? 'Очистить' : 'Clear'),
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
          .clearConversationHistory(widget.args.conversationId);
      _resetComposer();
      ref
          .read(
            chatMessagesNotifierProvider(widget.args.conversationId).notifier,
          )
          .clearHistory();
      _showSnackBar(strings.isRu ? 'История очищена' : 'History cleared');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось очистить историю'
            : 'Could not clear the history',
        isError: true,
      );
    }
  }

  Future<void> _toggleBlockUser({required bool unblock}) async {
    final strings = AppStrings.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  unblock
                      ? (strings.isRu
                          ? 'Разблокировать пользователя?'
                          : 'Unblock user?')
                      : (strings.isRu
                          ? 'Заблокировать пользователя?'
                          : 'Block user?'),
                ),
                content: Text(
                  unblock
                      ? (strings.isRu
                          ? 'После разблокировки вы снова сможете писать друг другу.'
                          : 'After unblocking, you will be able to message each other again.')
                      : (strings.isRu
                          ? 'После блокировки никто из вас не сможет писать сообщения.'
                          : 'After blocking, neither of you will be able to send messages.'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(strings.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      unblock
                          ? (strings.isRu ? 'Разблокировать' : 'Unblock')
                          : (strings.isRu ? 'Заблокировать' : 'Block'),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    final repository = ref.read(socialRepositoryProvider);
    final messagesNotifier = ref.read(
      chatMessagesNotifierProvider(widget.args.conversationId).notifier,
    );
    try {
      if (unblock) {
        await repository.unblockUserFromChat(widget.args.peerId);
      } else {
        await repository.blockUserFromChat(widget.args.peerId);
      }
      _resetComposer();
      await _loadPeerProfile(silent: true);
      await messagesNotifier.refresh(silent: true, force: true);
      _showSnackBar(
        unblock
            ? (strings.isRu ? 'Пользователь разблокирован' : 'User unblocked')
            : (strings.isRu ? 'Пользователь заблокирован' : 'User blocked'),
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        unblock
            ? (strings.isRu
                ? 'Не удалось разблокировать пользователя'
                : 'Could not unblock the user')
            : (strings.isRu
                ? 'Не удалось заблокировать пользователя'
                : 'Could not block the user'),
        isError: true,
      );
    }
  }

  Future<void> _showMessageActionsSheet(ChatMessageModel message) async {
    final strings = AppStrings.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    _messagePreviewLabel(strings, message),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    message.senderUsername,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: Text(strings.isRu ? 'Ответить' : 'Reply'),
                  onTap: () => Navigator.of(context).pop('reply'),
                ),
                ListTile(
                  leading: const Icon(Icons.forward_rounded),
                  title: Text(strings.isRu ? 'Переслать' : 'Forward'),
                  onTap: () => Navigator.of(context).pop('forward'),
                ),
                if (message.isMine)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: Text(strings.isRu ? 'Редактировать' : 'Edit'),
                    onTap: () => Navigator.of(context).pop('edit'),
                  ),
                if (message.isMine)
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_rounded),
                    title: Text(strings.deleteForEveryone),
                    onTap: () => Navigator.of(context).pop('delete_all'),
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(strings.deleteForMe),
                  onTap: () => Navigator.of(context).pop('delete_me'),
                ),
              ],
            ),
          ),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case 'reply':
        _startReply(message);
        break;
      case 'forward':
        unawaited(_forwardMessage(message));
        break;
      case 'edit':
        _startEdit(message);
        break;
      case 'delete_all':
        unawaited(_deleteMessageForEveryone(message));
        break;
      case 'delete_me':
        unawaited(_deleteMessageForMe(message));
        break;
    }
  }

  Future<void> _showLocalMessageActionsSheet(
    _LocalOutgoingMessage message,
  ) async {
    final strings = AppStrings.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    _localMessagePreviewLabel(strings, message),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    message.isFailed
                        ? (strings.isRu ? 'Не отправлено' : 'Not sent')
                        : strings.sendingMessage,
                  ),
                ),
                if (message.isFailed)
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: Text(strings.retry),
                    onTap: () => Navigator.of(context).pop('retry'),
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(strings.delete),
                  onTap: () => Navigator.of(context).pop('delete'),
                ),
              ],
            ),
          ),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case 'retry':
        unawaited(_retryLocalOutgoingMessage(message));
        break;
      case 'delete':
        _discardLocalOutgoingMessage(message);
        break;
    }
  }

  Future<void> _forwardMessage(ChatMessageModel message) async {
    final strings = AppStrings.of(context);
    try {
      final destination = await _pickForwardDestination();
      if (!mounted || destination == null) {
        return;
      }

      var targetConversationId = destination.conversationId;
      if (targetConversationId == null) {
        final createdConversation = await ref
            .read(socialRepositoryProvider)
            .getOrCreateConversation(destination.peerId);
        targetConversationId = createdConversation.id;
      }

      final forwardedMessage = await ref
          .read(socialRepositoryProvider)
          .forwardMessage(targetConversationId, message.id);
      if (!mounted) {
        return;
      }

      ref
          .read(chatConversationPreviewOverridesProvider.notifier)
          .upsertFromMessage(forwardedMessage);
      if (targetConversationId == widget.args.conversationId) {
        ref
            .read(
              chatMessagesNotifierProvider(widget.args.conversationId).notifier,
            )
            .upsertMessage(forwardedMessage);
        _scrollToLatest();
      }

      _showSnackBar(
        strings.isRu
            ? 'Сообщение переслано в ${destination.title}'
            : 'Message forwarded to ${destination.title}',
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось переслать сообщение'
            : 'Could not forward the message',
        isError: true,
      );
    }
  }

  Future<_ForwardDestination?> _pickForwardDestination() async {
    final strings = AppStrings.of(context);
    final currentUserId = ref.read(currentUserIdProvider);
    final socialRepository = ref.read(socialRepositoryProvider);
    final authRepository = ref.read(authRepositoryProvider);
    final conversations = await socialRepository.getConversations(
      forceRefresh: true,
    );

    UserProfile? currentProfile;
    if (currentUserId != null) {
      currentProfile = authRepository.peekProfile();
      if (currentProfile == null) {
        try {
          currentProfile = await authRepository.getProfile();
        } catch (_) {
          currentProfile = null;
        }
      }
    }

    final destinations = <_ForwardDestination>[];
    if (currentUserId != null) {
      ConversationModel? savedMessagesConversation;
      for (final conversation in conversations) {
        if (conversation.peerId == currentUserId) {
          savedMessagesConversation = conversation;
          break;
        }
      }

      destinations.add(
        _ForwardDestination(
          conversationId: savedMessagesConversation?.id,
          peerId: currentUserId,
          title: 'Saved Messages',
          subtitle:
              strings.isRu
                  ? 'Личные заметки, файлы и пересылки'
                  : 'Private notes, files, and forwards',
          avatarUrl:
              currentProfile?.avatarUrl ?? savedMessagesConversation?.avatarUrl,
          avatarScale:
              currentProfile?.avatarScale ??
              savedMessagesConversation?.avatarScale ??
              1,
          avatarOffsetX:
              currentProfile?.avatarOffsetX ??
              savedMessagesConversation?.avatarOffsetX ??
              0,
          avatarOffsetY:
              currentProfile?.avatarOffsetY ??
              savedMessagesConversation?.avatarOffsetY ??
              0,
          isSavedMessages: true,
        ),
      );
    }

    for (final conversation in conversations) {
      if (currentUserId != null && conversation.peerId == currentUserId) {
        continue;
      }

      destinations.add(
        _ForwardDestination(
          conversationId: conversation.id,
          peerId: conversation.peerId,
          title: conversation.username,
          subtitle:
              (conversation.lastMessage?.trim().isNotEmpty ?? false)
                  ? _localizeChatGeneratedPreview(
                    conversation.lastMessage,
                    strings,
                    fallback: strings.isRu ? 'Чат' : 'Chat',
                  )
                  : (strings.isRu ? 'Чат' : 'Chat'),
          avatarUrl: conversation.avatarUrl,
          avatarScale: conversation.avatarScale,
          avatarOffsetX: conversation.avatarOffsetX,
          avatarOffsetY: conversation.avatarOffsetY,
        ),
      );
    }

    if (!mounted) {
      return null;
    }

    return showModalBottomSheet<_ForwardDestination>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => _ForwardDestinationSheet(destinations: destinations),
    );
  }

  void _startReply(ChatMessageModel message) {
    setState(() {
      _replyingTo = message;
      _editingMessage = null;
    });
  }

  void _startEdit(ChatMessageModel message) {
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
      _pendingAttachments = const [];
      _messageController.text = message.content;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
    });
  }

  void _removePendingAttachment(_PendingAttachment attachment) {
    setState(() {
      _pendingAttachments = _pendingAttachments
          .where((item) => item != attachment)
          .toList(growable: false);
    });
  }

  _LocalOutgoingMessage _createLocalOutgoingMessage(
    String content,
    List<_PendingAttachment> attachments,
    ChatMessageModel? replyTo,
  ) {
    return _LocalOutgoingMessage(
      localId: DateTime.now().microsecondsSinceEpoch,
      content: content,
      createdAt: DateTime.now(),
      replyToMessageId: replyTo?.id,
      replyToSenderUsername: replyTo?.senderUsername,
      replyToContent: _buildReplyPreview(replyTo),
      attachments: attachments,
      status:
          attachments.isNotEmpty
              ? _LocalOutgoingMessageStatus.uploading
              : _LocalOutgoingMessageStatus.sending,
      uploadProgress: attachments.isNotEmpty ? 0 : null,
    );
  }

  String? _buildReplyPreview(ChatMessageModel? replyTo) {
    final strings = AppStrings.of(context);
    if (replyTo == null) {
      return null;
    }
    if (replyTo.content.isNotEmpty) {
      return replyTo.content;
    }
    if (replyTo.attachments.isNotEmpty) {
      return strings.attachment;
    }
    return null;
  }

  Future<void> _sendLocalOutgoingMessage(
    _LocalOutgoingMessage localMessage, {
    required bool scrollToLatest,
  }) async {
    final strings = AppStrings.of(context);
    try {
      final sentMessage = await ref
          .read(socialRepositoryProvider)
          .sendMessage(
            widget.args.conversationId,
            localMessage.content.isEmpty ? null : localMessage.content,
            replyToMessageId: localMessage.replyToMessageId,
            attachments: localMessage.attachments
                .map(
                  (attachment) => ChatUploadAttachment(
                    fileName: attachment.fileName,
                    bytes: attachment.bytes,
                    isImage: attachment.isImage,
                  ),
                )
                .toList(growable: false),
            onSendProgress: (sent, total) {
              if (!mounted || total <= 0) {
                return;
              }
              final progress = (sent / total).clamp(0, 1).toDouble();
              _updateLocalOutgoingMessage(
                localMessage.localId,
                status: _LocalOutgoingMessageStatus.uploading,
                uploadProgress: progress,
              );
            },
          );
      if (!mounted) {
        return;
      }
      _removeLocalOutgoingMessage(localMessage.localId);
      ref
          .read(chatConversationPreviewOverridesProvider.notifier)
          .upsertFromMessage(sentMessage);
      ref
          .read(
            chatMessagesNotifierProvider(widget.args.conversationId).notifier,
          )
          .upsertMessage(sentMessage);
      if (scrollToLatest) {
        _scrollToLatest();
      }
    } on ApiException catch (e) {
      _updateLocalOutgoingMessage(
        localMessage.localId,
        status: _LocalOutgoingMessageStatus.failed,
        uploadProgress: null,
        errorMessage: e.apiError.message,
      );
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _updateLocalOutgoingMessage(
        localMessage.localId,
        status: _LocalOutgoingMessageStatus.failed,
        uploadProgress: null,
        errorMessage: e.message,
      );
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _updateLocalOutgoingMessage(
        localMessage.localId,
        status: _LocalOutgoingMessageStatus.failed,
        uploadProgress: null,
        errorMessage: strings.failedToSendMessage,
      );
      _showSnackBar(strings.failedToSendMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _updateLocalOutgoingMessage(
    int localId, {
    _LocalOutgoingMessageStatus? status,
    double? uploadProgress,
    String? errorMessage,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _localOutgoingMessages = _localOutgoingMessages
          .map(
            (message) =>
                message.localId == localId
                    ? message.copyWith(
                      status: status,
                      uploadProgress: uploadProgress,
                      errorMessage: errorMessage,
                    )
                    : message,
          )
          .toList(growable: false);
    });
  }

  void _removeLocalOutgoingMessage(int localId) {
    if (!mounted) {
      return;
    }
    setState(() {
      _localOutgoingMessages = _localOutgoingMessages
          .where((message) => message.localId != localId)
          .toList(growable: false);
    });
  }

  Future<void> _retryLocalOutgoingMessage(_LocalOutgoingMessage message) async {
    if (_isSending) {
      return;
    }
    final wasNearLatest = _isNearLatest();
    _updateLocalOutgoingMessage(
      message.localId,
      status:
          message.attachments.isNotEmpty
              ? _LocalOutgoingMessageStatus.uploading
              : _LocalOutgoingMessageStatus.sending,
      uploadProgress: message.attachments.isNotEmpty ? 0 : null,
      errorMessage: null,
    );
    setState(() => _isSending = true);
    await _sendLocalOutgoingMessage(message, scrollToLatest: wasNearLatest);
  }

  void _discardLocalOutgoingMessage(_LocalOutgoingMessage message) {
    _removeLocalOutgoingMessage(message.localId);
  }

  List<_TimelineMessageItem> _buildTimelineItems(
    List<ChatMessageModel> messages,
  ) {
    final items = <_TimelineMessageItem>[
      ...messages.map(_TimelineMessageItem.remote),
      ..._localOutgoingMessages.map(_TimelineMessageItem.local),
    ];
    items.sort((left, right) {
      final dateCompare = right.createdAt.compareTo(left.createdAt);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return right.sortKey.compareTo(left.sortKey);
    });
    return items;
  }

  void _resetComposer() {
    setState(() {
      _replyingTo = null;
      _editingMessage = null;
      _pendingAttachments = const [];
      _messageController.clear();
    });
  }

  void _scrollToLatest({
    bool forceSettle = false,
    bool immediate = false,
    VoidCallback? onSettled,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      final targetOffset = _scrollController.position.minScrollExtent;
      final currentOffset = _scrollController.position.pixels;
      if ((targetOffset - currentOffset).abs() < 1) {
        onSettled?.call();
        return;
      }

      if (immediate) {
        _scrollController.jumpTo(targetOffset);
      } else {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }

      if (forceSettle) {
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (!mounted || !_scrollController.hasClients) {
            return;
          }

          final settledTarget = _scrollController.position.minScrollExtent;
          if ((_scrollController.position.pixels - settledTarget).abs() < 1) {
            onSettled?.call();
            return;
          }

          _scrollController.jumpTo(settledTarget);
          onSettled?.call();
        });
      } else {
        onSettled?.call();
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _openAttachment(ChatAttachmentModel attachment) async {
    final strings = AppStrings.of(context);
    if (attachment.isImage) {
      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FullscreenImageScreen(imageUrl: attachment.fileUrl),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(attachment.fileUrl);
    if (uri == null) {
      _showSnackBar(
        strings.isRu ? 'Некорректная ссылка на файл' : 'Invalid file link',
        isError: true,
      );
      return;
    }

    final launched = await openExternalUrl(uri.toString());
    if (!launched && mounted) {
      _showSnackBar(
        strings.isRu ? 'Не удалось открыть файл' : 'Could not open the file',
        isError: true,
      );
    }
  }

  void _openPeerProfile() {
    context.push('/profile/${widget.args.peerId}');
  }

  void _openForwardedProfile(ChatMessageModel message) {
    final forwardedFromUserId = message.forwardedFromUserId;
    if (forwardedFromUserId == null) {
      return;
    }

    context.push('/profile/$forwardedFromUserId');
  }

  String _formatPresenceLabel() {
    final strings = AppStrings.of(context);
    final profile = _peerProfile;
    final isOnline = profile?.isOnline ?? widget.args.initialIsOnline;
    final lastSeenAt = profile?.lastSeenAt ?? widget.args.initialLastSeenAt;

    if (isOnline == null && lastSeenAt == null) {
      return '...';
    }

    if (isOnline == true) {
      return strings.online;
    }

    if (lastSeenAt == null) {
      return '...';
    }

    final localLastSeen = lastSeenAt.toLocal();
    final timeLabel = DateFormat('HH:mm').format(localLastSeen);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final seenDay = DateTime(
      localLastSeen.year,
      localLastSeen.month,
      localLastSeen.day,
    );
    final dayDifference = today.difference(seenDay).inDays;

    if (dayDifference <= 0) {
      return strings.lastSeenAt(timeLabel);
    }

    if (dayDifference == 1) {
      return strings.lastSeenYesterdayAt(timeLabel);
    }

    return strings.lastSeenDaysAgoAt(dayDifference, timeLabel);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = AppStrings.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
    final messageState = ref.watch(
      chatMessagesNotifierProvider(widget.args.conversationId),
    );
    final timelineItems = _buildTimelineItems(messageState.messages);
    final peerBlockedViewer = _peerProfile?.hasBlockedViewer ?? false;
    final viewerBlockedPeer = _peerProfile?.isBlockedByViewer ?? false;
    final showTypingIndicator =
        messageState.isPeerTyping &&
        _editingMessage == null &&
        !peerBlockedViewer &&
        !viewerBlockedPeer;
    final isSavedMessagesConversation =
        currentUserId != null && widget.args.peerId == currentUserId;
    final subtitleLabel =
        showTypingIndicator
            ? strings.typing
            : isSavedMessagesConversation
            ? (strings.isRu
                ? 'Личные заметки, файлы и пересылки'
                : 'Private notes, files, and forwards')
            : _formatPresenceLabel();
    final isPeerOnline = _peerProfile?.isOnline ?? widget.args.initialIsOnline;
    final subtitleColor =
        showTypingIndicator
            ? const Color(0xFF2F67FF)
            : isSavedMessagesConversation
            ? const Color(0xFF4C6FAE)
            : isPeerOnline == true
            ? const Color(0xFF229C5A)
            : const Color(0xFF728098);
    final headerAvatar =
        isSavedMessagesConversation
            ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF132443).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AppAvatar(
                username: widget.args.peerUsername,
                imageUrl: widget.args.peerAvatarUrl,
                size: 44,
                scale: widget.args.peerAvatarScale,
                offsetX: widget.args.peerAvatarOffsetX,
                offsetY: widget.args.peerAvatarOffsetY,
              ),
            )
            : _PeerAvatar(
              username: widget.args.peerUsername,
              avatarUrl: widget.args.peerAvatarUrl,
              avatarScale: widget.args.peerAvatarScale,
              avatarOffsetX: widget.args.peerAvatarOffsetX,
              avatarOffsetY: widget.args.peerAvatarOffsetY,
              isOnline: isPeerOnline ?? false,
            );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 0,
        backgroundColor: Colors.white.withValues(alpha: 0.74),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
        title: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isSavedMessagesConversation ? null : _openPeerProfile,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  headerAvatar,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.args.peerUsername,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF162238),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Text(
                            subtitleLabel,
                            key: ValueKey(subtitleLabel),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: subtitleColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: strings.chatSettings,
            onSelected: (value) {
              if (value == 'clear') {
                _clearHistory();
              } else if (value == 'block') {
                _toggleBlockUser(unblock: false);
              } else if (value == 'unblock') {
                _toggleBlockUser(unblock: true);
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'clear',
                    child: Text(
                      strings.isRu ? 'Очистить историю' : 'Clear history',
                    ),
                  ),
                  PopupMenuItem(
                    value: viewerBlockedPeer ? 'unblock' : 'block',
                    child: Text(
                      viewerBlockedPeer
                          ? (strings.isRu
                              ? 'Разблокировать пользователя'
                              : 'Unblock user')
                          : (strings.isRu
                              ? 'Заблокировать пользователя'
                              : 'Block user'),
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F8FF), Color(0xFFF1EEFF), Color(0xFFFFFBF5)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -80,
              right: -60,
              child: _ConversationGlowOrb(
                size: 240,
                colors: [Color(0xFFBFD7FF), Color(0x33BFD7FF)],
              ),
            ),
            const Positioned(
              left: -90,
              top: 180,
              child: _ConversationGlowOrb(
                size: 220,
                colors: [Color(0xFFE2CCFF), Color(0x22E2CCFF)],
              ),
            ),
            const Positioned(
              right: -70,
              bottom: 110,
              child: _ConversationGlowOrb(
                size: 200,
                colors: [Color(0xFFFFE1F3), Color(0x22FFE1F3)],
              ),
            ),
            Column(
              children: [
                Expanded(
                  child:
                      messageState.isInitialLoading
                          ? const _ConversationLoadingTimeline()
                          : messageState.errorMessage != null &&
                              timelineItems.isEmpty
                          ? ErrorState(
                            message: messageState.errorMessage!,
                            onRetry:
                                () => ref
                                    .read(
                                      chatMessagesNotifierProvider(
                                        widget.args.conversationId,
                                      ).notifier,
                                    )
                                    .refresh(force: true),
                          )
                          : timelineItems.isEmpty
                          ? RefreshIndicator(
                            onRefresh:
                                () => ref
                                    .read(
                                      chatMessagesNotifierProvider(
                                        widget.args.conversationId,
                                      ).notifier,
                                    )
                                    .refresh(force: true),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.all(24),
                              children: [
                                EmptyState(
                                  icon: Icons.forum_outlined,
                                  title:
                                      strings.isRu
                                          ? 'Пока нет сообщений'
                                          : 'No messages yet',
                                  subtitle:
                                      strings.isRu
                                          ? 'Напишите первое сообщение, чтобы начать диалог.'
                                          : 'Send the first message to start the conversation.',
                                ),
                              ],
                            ),
                          )
                          : RefreshIndicator(
                            onRefresh:
                                () => ref
                                    .read(
                                      chatMessagesNotifierProvider(
                                        widget.args.conversationId,
                                      ).notifier,
                                    )
                                    .refresh(force: true),
                            child: Scrollbar(
                              controller: _scrollController,
                              child: ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  20,
                                  16,
                                  24,
                                ),
                                itemCount:
                                    timelineItems.length +
                                    (messageState.isLoadingOlder ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= timelineItems.length) {
                                    return const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final item = timelineItems[index];
                                  if (item.message != null) {
                                    final message = item.message!;
                                    return _MessageBubble(
                                      message: message,
                                      onReply: () => _startReply(message),
                                      onOpenForwardedProfile:
                                          message.forwardedFromUserId == null
                                              ? null
                                              : () => _openForwardedProfile(
                                                message,
                                              ),
                                      onOpenMenu:
                                          () =>
                                              _showMessageActionsSheet(message),
                                      onOpenAttachment: _openAttachment,
                                    );
                                  }

                                  final localMessage = item.localMessage!;
                                  return _LocalOutgoingMessageBubble(
                                    message: localMessage,
                                    onRetry:
                                        () => _retryLocalOutgoingMessage(
                                          localMessage,
                                        ),
                                    onOpenMenu:
                                        () => _showLocalMessageActionsSheet(
                                          localMessage,
                                        ),
                                    onDelete:
                                        () => _discardLocalOutgoingMessage(
                                          localMessage,
                                        ),
                                  );
                                },
                              ),
                            ),
                          ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1,
                        child: child,
                      ),
                    );
                  },
                  child:
                      showTypingIndicator
                          ? const Padding(
                            key: ValueKey('typing-indicator'),
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _ConversationTypingIndicator(),
                            ),
                          )
                          : const SizedBox.shrink(
                            key: ValueKey('typing-empty'),
                          ),
                ),
                if (peerBlockedViewer)
                  _BlockedComposerBanner(
                    message: strings.youCannotSendMessagesToThisUser,
                    icon: Icons.block_rounded,
                  )
                else if (viewerBlockedPeer)
                  _BlockedComposerBanner(
                    message:
                        strings.isRu
                            ? 'Вы заблокировали этого пользователя'
                            : 'You blocked this user',
                    icon: Icons.lock_open_rounded,
                    actionLabel: strings.unblockUser,
                    onAction: () => _toggleBlockUser(unblock: true),
                  )
                else
                  _MessageComposer(
                    controller: _messageController,
                    isSending: _isSending,
                    onSubmit: _submit,
                    replyingTo: _replyingTo,
                    editingMessage: _editingMessage,
                    onCancelContext: _resetComposer,
                    pendingAttachments: _pendingAttachments,
                    onPickImages:
                        () => _pickAttachments(AttachmentPickType.image),
                    onPickFiles: () => _pickAttachments(AttachmentPickType.any),
                    onRemoveAttachment: _removePendingAttachment,
                    totalAttachmentBytes: _pendingAttachments.fold<int>(
                      0,
                      (sum, item) => sum + item.sizeBytes,
                    ),
                  ),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _backSwipeEdgeWidth + 20,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _handleBackSwipeStart,
                onHorizontalDragUpdate: _handleBackSwipeUpdate,
                onHorizontalDragEnd: _handleBackSwipeEnd,
                onHorizontalDragCancel: _resetBackSwipe,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final bool isOnline;

  const _PeerAvatar({
    required this.username,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF132443).withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AppAvatar(
            username: username,
            imageUrl: avatarUrl,
            size: 44,
            scale: avatarScale,
            offsetX: avatarOffsetX,
            offsetY: avatarOffsetY,
          ),
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
                  isOnline ? const Color(0xFF2FD16C) : const Color(0xFFD7DEE9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversationGlowOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _ConversationGlowOrb({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _ConversationTypingIndicator extends StatefulWidget {
  const _ConversationTypingIndicator();

  @override
  State<_ConversationTypingIndicator> createState() =>
      _ConversationTypingIndicatorState();
}

class _ConversationTypingIndicatorState
    extends State<_ConversationTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF132443).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final phase = (_controller.value + (index * 0.18)) % 1;
                final opacity = 0.35 + ((1 - (phase - 0.5).abs() * 2) * 0.65);
                final alpha = opacity.clamp(0.2, 1.0).toDouble();
                return Container(
                  width: 7,
                  height: 7,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B8BA6).withValues(alpha: alpha),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

class _BlockedComposerBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _BlockedComposerBanner({
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                blurRadius: 32,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: const Color(0xFF2F67FF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF24344E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 12),
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSubmit;
  final ChatMessageModel? replyingTo;
  final ChatMessageModel? editingMessage;
  final VoidCallback onCancelContext;
  final List<_PendingAttachment> pendingAttachments;
  final VoidCallback onPickImages;
  final VoidCallback onPickFiles;
  final ValueChanged<_PendingAttachment> onRemoveAttachment;
  final int totalAttachmentBytes;

  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSubmit,
    required this.replyingTo,
    required this.editingMessage,
    required this.onCancelContext,
    required this.pendingAttachments,
    required this.onPickImages,
    required this.onPickFiles,
    required this.onRemoveAttachment,
    required this.totalAttachmentBytes,
  });

  Future<void> _showAttachmentTypeSheet(BuildContext context) async {
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
                  leading: const Icon(Icons.image_rounded),
                  title: Text(strings.isRu ? 'Фото' : 'Photo'),
                  subtitle: Text(
                    strings.isRu
                        ? 'Отправить как изображение'
                        : 'Send as image',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onPickImages();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_rounded),
                  title: Text(strings.isRu ? 'Файл' : 'File'),
                  subtitle: Text(
                    strings.isRu
                        ? 'Отправить как файл или документ'
                        : 'Send as file or document',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onPickFiles();
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final hasContext = replyingTo != null || editingMessage != null;
    final canAttach = editingMessage == null;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                blurRadius: 32,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasContext)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF5F8FF), Color(0xFFEEF4FF)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDDE6F6)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF2F67FF), Color(0xFF6A9DFF)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            editingMessage != null
                                ? (strings.isRu
                                    ? 'Редактирование сообщения'
                                    : 'Editing message')
                                : (strings.isRu
                                    ? 'Ответ для ${replyingTo!.senderUsername}'
                                    : 'Reply to ${replyingTo!.senderUsername}'),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF21304A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onCancelContext,
                          icon: const Icon(Icons.close_rounded),
                          color: const Color(0xFF5E6C83),
                        ),
                      ],
                    ),
                  ),
                if (pendingAttachments.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FE),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E9F6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${strings.isRu ? 'Вложения' : 'Attachments'} • ${_formatBytes(context, totalAttachmentBytes)} / 15 MB',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF55657C),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: pendingAttachments
                              .map(
                                (attachment) => _PendingAttachmentChip(
                                  attachment: attachment,
                                  onRemove:
                                      () => onRemoveAttachment(attachment),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final hasDraft =
                        value.text.trim().isNotEmpty ||
                        pendingAttachments.isNotEmpty ||
                        editingMessage != null;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (canAttach)
                          Material(
                            color: const Color(0xFFEAF0FF),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              onTap:
                                  isSending
                                      ? null
                                      : () => _showAttachmentTypeSheet(context),
                              borderRadius: BorderRadius.circular(18),
                              child: const SizedBox(
                                width: 46,
                                height: 46,
                                child: Icon(
                                  Icons.attach_file_rounded,
                                  color: Color(0xFF3557A8),
                                ),
                              ),
                            ),
                          ),
                        if (canAttach) const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color:
                                    hasDraft
                                        ? const Color(0xFFCAD8F4)
                                        : const Color(0xFFDCE3F1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF18243C,
                                  ).withValues(alpha: 0.05),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: controller,
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText:
                                    editingMessage != null
                                        ? (strings.isRu
                                            ? 'Измените сообщение...'
                                            : 'Edit the message...')
                                        : replyingTo != null
                                        ? (strings.isRu
                                            ? 'Напишите ответ...'
                                            : 'Write a reply...')
                                        : (strings.isRu
                                            ? 'Напишите сообщение...'
                                            : 'Write a message...'),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                border: InputBorder.none,
                                hintStyle: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: const Color(0xFF8894A8)),
                              ),
                              onSubmitted: (_) => onSubmit(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedScale(
                          duration: const Duration(milliseconds: 180),
                          scale: hasDraft ? 1 : 0.96,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient:
                                  hasDraft
                                      ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF2F67FF),
                                          Color(0xFF5D8CFF),
                                        ],
                                      )
                                      : const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFC9D4EA),
                                          Color(0xFFB8C6E0),
                                        ],
                                      ),
                              shape: BoxShape.circle,
                              boxShadow:
                                  hasDraft
                                      ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF2F67FF,
                                          ).withValues(alpha: 0.28),
                                          blurRadius: 16,
                                          offset: const Offset(0, 10),
                                        ),
                                      ]
                                      : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isSending ? null : onSubmit,
                                customBorder: const CircleBorder(),
                                child: Center(
                                  child:
                                      isSending
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : Icon(
                                            editingMessage != null
                                                ? Icons.check_rounded
                                                : Icons.send_rounded,
                                            color: Colors.white,
                                          ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatBytes(BuildContext context, int bytes) {
    final strings = AppStrings.of(context);
    if (bytes < 1024) {
      return strings.isRu ? '$bytes Б' : '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback onReply;
  final VoidCallback? onOpenForwardedProfile;
  final VoidCallback onOpenMenu;
  final ValueChanged<ChatAttachmentModel> onOpenAttachment;

  const _MessageBubble({
    required this.message,
    required this.onReply,
    required this.onOpenForwardedProfile,
    required this.onOpenMenu,
    required this.onOpenAttachment,
  });

  BorderRadius get _bubbleRadius {
    if (message.isMine) {
      return const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(8),
      );
    }

    return const BorderRadius.only(
      topLeft: Radius.circular(20),
      topRight: Radius.circular(20),
      bottomLeft: Radius.circular(8),
      bottomRight: Radius.circular(20),
    );
  }

  String? _readReceiptTooltip(BuildContext context) {
    if (!message.isMine ||
        !message.isReadByPeer ||
        message.readByPeerAt == null) {
      return null;
    }

    final strings = AppStrings.of(context);
    final localReadAt = message.readByPeerAt!.toLocal();
    final timeLabel = DateFormat('HH:mm').format(localReadAt);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final readDay = DateTime(
      localReadAt.year,
      localReadAt.month,
      localReadAt.day,
    );
    final dayDifference = today.difference(readDay).inDays;

    if (dayDifference <= 0) {
      return strings.isRu ? 'Прочитано в $timeLabel' : 'Read at $timeLabel';
    }

    if (dayDifference == 1) {
      return strings.isRu
          ? 'Прочитано вчера в $timeLabel'
          : 'Read yesterday at $timeLabel';
    }

    final dateLabel = DateFormat('dd.MM.yyyy').format(localReadAt);
    return strings.isRu
        ? 'Прочитано $dateLabel в $timeLabel'
        : 'Read on $dateLabel at $timeLabel';
  }

  double _footerReserveWidth() {
    var width = message.isMine ? 78.0 : 52.0;
    if (message.editedAt != null) {
      width += 38;
    }
    return width;
  }

  Widget _buildForwardedHeader(BuildContext context) {
    final username = message.forwardedFromSenderUsername;
    if (username == null) {
      return const SizedBox.shrink();
    }

    final strings = AppStrings.of(context);
    final accentColor =
        message.isMine ? const Color(0xFFE5EEFF) : const Color(0xFF2E63E6);
    final secondaryColor =
        message.isMine ? const Color(0xFFD4E2FF) : const Color(0xFF5680D9);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.forward_rounded, size: 15, color: accentColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: secondaryColor,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: strings.isRu ? 'Переслано от ' : 'Forwarded from ',
                ),
                TextSpan(
                  text: username,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    decoration:
                        onOpenForwardedProfile != null
                            ? TextDecoration.underline
                            : TextDecoration.none,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (onOpenForwardedProfile == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: content);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onOpenForwardedProfile,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: content,
        ),
      ),
    );
  }

  Widget _buildReplyCard(BuildContext context, AppStrings strings) {
    if (message.replyToContent == null) {
      return const SizedBox.shrink();
    }

    final localizedReplyPreview = _localizeChatGeneratedPreview(
      message.replyToContent,
      strings,
      fallback: strings.message,
    );

    final accentColor =
        message.isMine ? const Color(0xFFE2ECFF) : const Color(0xFF2F67FF);
    final titleColor =
        message.isMine ? const Color(0xFFF3F7FF) : const Color(0xFF3154A5);
    final bodyColor =
        message.isMine ? const Color(0xFFD6E4FF) : const Color(0xFF62718A);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
      decoration: BoxDecoration(
        color:
            message.isMine
                ? Colors.white.withValues(alpha: 0.14)
                : const Color(0xFFF2F6FD),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.replyToSenderUsername ??
                (strings.isRu ? 'Сообщение' : 'Message'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            localizedReplyPreview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: bodyColor, height: 1.25),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    AppStrings strings,
    String? readTooltip, {
    bool compact = false,
  }) {
    final footerColor =
        message.isMine ? const Color(0xFFD6E4FF) : const Color(0xFF7D8BA4);
    final timeLabel = DateFormat('HH:mm').format(message.createdAt.toLocal());
    final statusIcon =
        message.isReadByPeer
            ? Icons.done_all_rounded
            : message.isDeliveredToPeer
            ? Icons.done_all_rounded
            : Icons.done_rounded;
    final statusColor =
        message.isReadByPeer
            ? const Color(0xFFD9E6FF)
            : message.isDeliveredToPeer
            ? (message.isMine
                ? const Color(0xFFE6EEFF)
                : const Color(0xFF97A6C2))
            : (message.isMine
                ? const Color(0xFFC6D8FF)
                : const Color(0xFF97A6C2));

    final footerRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!compact && message.editedAt != null) ...[
          Text(
            strings.isRu ? 'изм.' : 'edited',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: footerColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          timeLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: footerColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        if (message.isMine) ...[
          const SizedBox(width: 4),
          if (readTooltip != null)
            Tooltip(
              message: readTooltip,
              waitDuration: const Duration(milliseconds: 250),
              child: Icon(statusIcon, size: 16, color: statusColor),
            )
          else
            Icon(statusIcon, size: 16, color: statusColor),
        ],
      ],
    );

    if (!compact || message.editedAt == null) {
      return footerRow;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          strings.isRu ? 'изм.' : 'edited',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: footerColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 4),
        footerRow,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final alignment =
        message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final backgroundGradient =
        message.isMine
            ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2F67FF), Color(0xFF4C7CFF)],
            )
            : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
            );
    final textColor = message.isMine ? Colors.white : const Color(0xFF18243C);
    final imageAttachments = message.attachments
        .where((attachment) => attachment.isImage)
        .toList(growable: false);
    final fileAttachments = message.attachments
        .where((attachment) => !attachment.isImage)
        .toList(growable: false);
    final readTooltip = _readReceiptTooltip(context);
    final hasTextOnlyBody =
        message.content.isNotEmpty &&
        imageAttachments.isEmpty &&
        fileAttachments.isEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = math.min(constraints.maxWidth * 0.76, 430.0);

        return Align(
          alignment: alignment,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('message-${message.id}'),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, child) {
              final progress = Curves.easeOutCubic.transform(value);
              return Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(
                    (1 - progress) * (message.isMine ? 26 : -26),
                    (1 - progress) * 10,
                  ),
                  child: Transform.scale(
                    scale: 0.97 + (progress * 0.03),
                    child: child,
                  ),
                ),
              );
            },
            child: Dismissible(
              key: ValueKey('reply-swipe-${message.id}'),
              direction: DismissDirection.endToStart,
              dismissThresholds: const {DismissDirection.endToStart: 0.18},
              movementDuration: const Duration(milliseconds: 180),
              resizeDuration: null,
              confirmDismiss: (_) async {
                HapticFeedback.selectionClick();
                onReply();
                return false;
              },
              background: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE9F0FF), Color(0xFFDDE8FF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2F67FF).withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.reply_rounded,
                    color: Color(0xFF2F67FF),
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                decoration: BoxDecoration(
                  gradient: backgroundGradient,
                  borderRadius: _bubbleRadius,
                  border: Border.all(
                    color:
                        message.isMine
                            ? const Color(0xFF7EA4FF).withValues(alpha: 0.22)
                            : const Color(0xFFE2E9F5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          message.isMine
                              ? const Color(0xFF2F67FF).withValues(alpha: 0.16)
                              : const Color(0xFF132443).withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: _bubbleRadius,
                  child: InkWell(
                    onLongPress: onOpenMenu,
                    borderRadius: _bubbleRadius,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.forwardedFromSenderUsername != null)
                            _buildForwardedHeader(context),
                          if (message.replyToContent != null)
                            _buildReplyCard(context, strings),
                          if (hasTextOnlyBody)
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: _footerReserveWidth(),
                                    bottom: 2,
                                  ),
                                  child: Text(
                                    message.content,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.copyWith(
                                      color: textColor,
                                      height: 1.3,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: _buildFooter(
                                    context,
                                    strings,
                                    readTooltip,
                                    compact: true,
                                  ),
                                ),
                              ],
                            ),
                          if (!hasTextOnlyBody && message.content.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: message.attachments.isNotEmpty ? 10 : 0,
                              ),
                              child: Text(
                                message.content,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(
                                  color: textColor,
                                  height: 1.32,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (imageAttachments.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: fileAttachments.isNotEmpty ? 10 : 0,
                              ),
                              child: Column(
                                children: imageAttachments
                                    .map(
                                      (attachment) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: _ImageAttachmentCard(
                                          attachment: attachment,
                                          onTap:
                                              () =>
                                                  onOpenAttachment(attachment),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                          if (fileAttachments.isNotEmpty)
                            Column(
                              children: fileAttachments
                                  .map(
                                    (attachment) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _FileAttachmentTile(
                                        attachment: attachment,
                                        isMine: message.isMine,
                                        onTap:
                                            () => onOpenAttachment(attachment),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          if (!hasTextOnlyBody) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Spacer(),
                                _buildFooter(context, strings, readTooltip),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _FailedMessageBubble extends StatelessWidget {
  final _LocalOutgoingMessage message;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  const _FailedMessageBubble({
    required this.message,
    required this.onRetry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final imageAttachments = message.attachments
        .where((attachment) => attachment.isImage)
        .toList(growable: false);
    final fileAttachments = message.attachments
        .where((attachment) => !attachment.isImage)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = math.min(constraints.maxWidth * 0.76, 430.0);

        return Align(
          alignment: Alignment.centerRight,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('failed-${message.localId}'),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0.96, end: 1),
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              decoration: BoxDecoration(
                color: const Color(0xFF2F67FF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2F67FF).withValues(alpha: 0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (message.replyToContent != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.replyToSenderUsername ??
                                  (strings.isRu ? 'Сообщение' : 'Message'),
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (message.replyToContent != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                message.replyToContent!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (message.content.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: message.attachments.isNotEmpty ? 10 : 0,
                        ),
                        child: Text(
                          message.content,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (imageAttachments.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: fileAttachments.isNotEmpty ? 10 : 0,
                        ),
                        child: Column(
                          children: imageAttachments
                              .map(
                                (attachment) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _PendingImageAttachmentCard(
                                    attachment: attachment,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    if (fileAttachments.isNotEmpty)
                      Column(
                        children: fileAttachments
                            .map(
                              (attachment) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PendingFileAttachmentTile(
                                  attachment: attachment,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat(
                            'HH:mm',
                          ).format(message.createdAt.toLocal()),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: onRetry,
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: Color(0xFFFFD6D6),
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const SizedBox.shrink(),
                          onSelected: (value) {
                            if (value == 'retry') {
                              onRetry();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder:
                              (context) => [
                                PopupMenuItem(
                                  value: 'retry',
                                  child: Text(strings.retry),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(strings.delete),
                                ),
                              ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LocalOutgoingMessageBubble extends StatelessWidget {
  final _LocalOutgoingMessage message;
  final VoidCallback onRetry;
  final VoidCallback onOpenMenu;
  final VoidCallback onDelete;

  const _LocalOutgoingMessageBubble({
    required this.message,
    required this.onRetry,
    required this.onOpenMenu,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final imageAttachments = message.attachments
        .where((attachment) => attachment.isImage)
        .toList(growable: false);
    final fileAttachments = message.attachments
        .where((attachment) => !attachment.isImage)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = math.min(constraints.maxWidth * 0.76, 430.0);

        return Align(
          alignment: Alignment.centerRight,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('local-${message.localId}-${message.status.name}'),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, child) {
              final progress = Curves.easeOutCubic.transform(value);
              return Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset((1 - progress) * 24, (1 - progress) * 10),
                  child: Transform.scale(
                    scale: 0.97 + (progress * 0.03),
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2F67FF),
                    Color(0xFF4A7DFF),
                    Color(0xFF3A89FF),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(10),
                ),
                border: Border.all(
                  color: const Color(0xFF7EA4FF).withValues(alpha: 0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2F67FF).withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (message.replyToContent != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: const Border(
                            left: BorderSide(
                              color: Color(0xFFDDE9FF),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.replyToSenderUsername ?? strings.message,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (message.replyToContent != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                message.replyToContent!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (message.content.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: message.attachments.isNotEmpty ? 10 : 0,
                        ),
                        child: Text(
                          message.content,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (imageAttachments.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: fileAttachments.isNotEmpty ? 10 : 0,
                        ),
                        child: Column(
                          children: imageAttachments
                              .map(
                                (attachment) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _PendingImageAttachmentCard(
                                    attachment: attachment,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    if (fileAttachments.isNotEmpty)
                      Column(
                        children: fileAttachments
                            .map(
                              (attachment) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PendingFileAttachmentTile(
                                  attachment: attachment,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    if (message.isUploading) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: message.uploadProgress,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat(
                            'HH:mm',
                          ).format(message.createdAt.toLocal()),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          switch (message.status) {
                            _LocalOutgoingMessageStatus.uploading =>
                              message.uploadProgress != null
                                  ? strings.uploadingWithProgress(
                                    (message.uploadProgress! * 100).round(),
                                  )
                                  : strings.uploading,
                            _LocalOutgoingMessageStatus.sending =>
                              strings.sendingMessage,
                            _LocalOutgoingMessageStatus.failed =>
                              strings.failedStatus,
                          },
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                message.isFailed
                                    ? const Color(0xFFFFD6D6)
                                    : Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (message.isFailed)
                          InkWell(
                            onTap: onRetry,
                            borderRadius: BorderRadius.circular(999),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: Color(0xFFFFD6D6),
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.schedule_rounded,
                            size: 17,
                            color: Colors.white70,
                          ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const SizedBox.shrink(),
                          onSelected: (value) {
                            if (value == 'retry') {
                              onRetry();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder:
                              (context) => [
                                if (message.isFailed)
                                  PopupMenuItem(
                                    value: 'retry',
                                    child: Text(strings.retry),
                                  ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(strings.delete),
                                ),
                              ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ForwardDestination {
  final int? conversationId;
  final int peerId;
  final String title;
  final String subtitle;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final bool isSavedMessages;

  const _ForwardDestination({
    required this.conversationId,
    required this.peerId,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.avatarScale,
    required this.avatarOffsetX,
    required this.avatarOffsetY,
    this.isSavedMessages = false,
  });
}

class _ForwardDestinationSheet extends StatefulWidget {
  final List<_ForwardDestination> destinations;

  const _ForwardDestinationSheet({required this.destinations});

  @override
  State<_ForwardDestinationSheet> createState() =>
      _ForwardDestinationSheetState();
}

class _ForwardDestinationSheetState extends State<_ForwardDestinationSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final normalizedQuery = _query.trim().toLowerCase();
    final destinations =
        normalizedQuery.isEmpty
            ? widget.destinations
            : widget.destinations
                .where(
                  (destination) =>
                      destination.title.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                      destination.subtitle.toLowerCase().contains(
                        normalizedQuery,
                      ),
                )
                .toList(growable: false);

    return SizedBox(
      height: math.min(MediaQuery.sizeOf(context).height * 0.82, 620),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.isRu ? 'Переслать сообщение' : 'Forward message',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF18243C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.isRu
                      ? 'Выберите чат или Saved Messages'
                      : 'Choose a chat or Saved Messages',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF74839C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FE),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDDE6F6)),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText:
                          strings.isRu ? 'Поиск по чатам' : 'Search chats',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                destinations.isEmpty
                    ? Center(
                      child: Text(
                        strings.isRu ? 'Ничего не найдено' : 'Nothing found',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF7C889C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      itemCount: destinations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final destination = destinations[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => Navigator.of(context).pop(destination),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color:
                                      destination.isSavedMessages
                                          ? const Color(0xFFD6E4FF)
                                          : const Color(0xFFE7EDF7),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF132443,
                                    ).withValues(alpha: 0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AppAvatar(
                                        username: destination.title,
                                        imageUrl: destination.avatarUrl,
                                        size: 48,
                                        scale: destination.avatarScale,
                                        offsetX: destination.avatarOffsetX,
                                        offsetY: destination.avatarOffsetY,
                                      ),
                                      if (destination.isSavedMessages)
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2F67FF),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.bookmark_rounded,
                                              size: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          destination.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall?.copyWith(
                                            color: const Color(0xFF18243C),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          destination.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xFF75839C),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: Color(0xFF8A97AD),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _PendingAttachmentChip extends StatelessWidget {
  final _PendingAttachment attachment;
  final VoidCallback onRemove;

  const _PendingAttachmentChip({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _resolveAttachmentVisual(
      fileName: attachment.fileName,
      isImage: attachment.isImage,
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E8F5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: visual.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(visual.icon, size: 16, color: visual.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.fileName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF20304A),
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF66758F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationLoadingTimeline extends StatelessWidget {
  const _ConversationLoadingTimeline();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: const [
        _LoadingMessagePlaceholder(
          alignment: Alignment.centerRight,
          widthFactor: 0.54,
          height: 72,
        ),
        _LoadingMessagePlaceholder(
          alignment: Alignment.centerLeft,
          widthFactor: 0.42,
          height: 52,
        ),
        _LoadingMessagePlaceholder(
          alignment: Alignment.centerRight,
          widthFactor: 0.68,
          height: 60,
        ),
        _LoadingMessagePlaceholder(
          alignment: Alignment.centerLeft,
          widthFactor: 0.58,
          height: 94,
        ),
        _LoadingMessagePlaceholder(
          alignment: Alignment.centerRight,
          widthFactor: 0.46,
          height: 54,
        ),
      ],
    );
  }
}

class _LoadingMessagePlaceholder extends StatelessWidget {
  final Alignment alignment;
  final double widthFactor;
  final double height;

  const _LoadingMessagePlaceholder({
    required this.alignment,
    required this.widthFactor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = alignment == Alignment.centerRight;

    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color:
                isMine
                    ? const Color(0xFF2F67FF).withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(isMine ? 22 : 10),
              bottomRight: Radius.circular(isMine ? 10 : 22),
            ),
            border: Border.all(
              color: const Color(0xFFDDE5F4).withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageAttachmentCard extends StatelessWidget {
  final ChatAttachmentModel attachment;
  final VoidCallback onTap;

  const _ImageAttachmentCard({required this.attachment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF132443).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: const Color(0x14000000),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 260,
              child: AspectRatio(
                aspectRatio: 1.25,
                child: CachedNetworkImage(
                  imageUrl: attachment.fileUrl,
                  fit: BoxFit.cover,
                  placeholder:
                      (_, __) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  errorWidget:
                      (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, size: 34),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileAttachmentTile extends StatelessWidget {
  final ChatAttachmentModel attachment;
  final bool isMine;
  final VoidCallback onTap;

  const _FileAttachmentTile({
    required this.attachment,
    required this.isMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _resolveAttachmentVisual(
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      isImage: attachment.isImage,
    );
    final primaryColor = isMine ? Colors.white : const Color(0xFF20304A);
    final secondaryColor = isMine ? Colors.white70 : const Color(0xFF75839A);

    return Material(
      color:
          isMine
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      isMine
                          ? Colors.white.withValues(alpha: 0.18)
                          : visual.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  visual.icon,
                  color: isMine ? Colors.white : visual.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatBytes(context, attachment.sizeBytes),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatBytes(BuildContext context, int bytes) {
    final strings = AppStrings.of(context);
    if (bytes < 1024) {
      return strings.isRu ? '$bytes Б' : '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _PendingImageAttachmentCard extends StatelessWidget {
  final _PendingAttachment attachment;

  const _PendingImageAttachmentCard({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF132443).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 260,
          child: AspectRatio(
            aspectRatio: 1.25,
            child: Image.memory(
              attachment.bytes,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => const ColoredBox(
                    color: Color(0x14000000),
                    child: Center(
                      child: Icon(Icons.broken_image_rounded, size: 34),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingFileAttachmentTile extends StatelessWidget {
  final _PendingAttachment attachment;

  const _PendingFileAttachmentTile({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final visual = _resolveAttachmentVisual(
      fileName: attachment.fileName,
      isImage: attachment.isImage,
    );

    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(visual.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _FileAttachmentTile._formatBytes(
                      context,
                      attachment.sizeBytes,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentVisual {
  final IconData icon;
  final Color accent;
  final Color background;

  const _AttachmentVisual({
    required this.icon,
    required this.accent,
    required this.background,
  });
}

_AttachmentVisual _resolveAttachmentVisual({
  required String fileName,
  String? contentType,
  required bool isImage,
}) {
  if (isImage || (contentType?.startsWith('image/') ?? false)) {
    return const _AttachmentVisual(
      icon: Icons.image_rounded,
      accent: Color(0xFF2F67FF),
      background: Color(0xFFEAF0FF),
    );
  }

  final extension =
      fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

  switch (extension) {
    case 'pdf':
      return const _AttachmentVisual(
        icon: Icons.picture_as_pdf_rounded,
        accent: Color(0xFFE45555),
        background: Color(0xFFFFECEC),
      );
    case 'doc':
    case 'docx':
    case 'txt':
    case 'rtf':
      return const _AttachmentVisual(
        icon: Icons.description_rounded,
        accent: Color(0xFF2F67FF),
        background: Color(0xFFEAF0FF),
      );
    case 'xls':
    case 'xlsx':
    case 'csv':
      return const _AttachmentVisual(
        icon: Icons.table_chart_rounded,
        accent: Color(0xFF21925C),
        background: Color(0xFFE8F8EF),
      );
    case 'zip':
    case 'rar':
    case '7z':
      return const _AttachmentVisual(
        icon: Icons.archive_rounded,
        accent: Color(0xFFB07618),
        background: Color(0xFFFFF4DE),
      );
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
      return const _AttachmentVisual(
        icon: Icons.videocam_rounded,
        accent: Color(0xFF7357D8),
        background: Color(0xFFF0EAFF),
      );
    case 'mp3':
    case 'wav':
    case 'aac':
    case 'ogg':
      return const _AttachmentVisual(
        icon: Icons.music_note_rounded,
        accent: Color(0xFFC658AF),
        background: Color(0xFFFFECFA),
      );
    default:
      return const _AttachmentVisual(
        icon: Icons.insert_drive_file_rounded,
        accent: Color(0xFF66758F),
        background: Color(0xFFF1F5FB),
      );
  }
}

class _PendingAttachment {
  final String fileName;
  final Uint8List bytes;
  final bool isImage;

  const _PendingAttachment({
    required this.fileName,
    required this.bytes,
    required this.isImage,
  });

  int get sizeBytes => bytes.lengthInBytes;
}

enum _LocalOutgoingMessageStatus { uploading, sending, failed }

class _LocalOutgoingMessage {
  final int localId;
  final String content;
  final DateTime createdAt;
  final int? replyToMessageId;
  final String? replyToSenderUsername;
  final String? replyToContent;
  final List<_PendingAttachment> attachments;
  final _LocalOutgoingMessageStatus status;
  final double? uploadProgress;
  final String? errorMessage;

  const _LocalOutgoingMessage({
    required this.localId,
    required this.content,
    required this.createdAt,
    required this.replyToMessageId,
    required this.replyToSenderUsername,
    required this.replyToContent,
    required this.attachments,
    required this.status,
    required this.uploadProgress,
    this.errorMessage,
  });

  _LocalOutgoingMessage copyWith({
    _LocalOutgoingMessageStatus? status,
    double? uploadProgress,
    String? errorMessage,
  }) {
    return _LocalOutgoingMessage(
      localId: localId,
      content: content,
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
      replyToSenderUsername: replyToSenderUsername,
      replyToContent: replyToContent,
      attachments: attachments,
      status: status ?? this.status,
      uploadProgress: uploadProgress,
      errorMessage: errorMessage,
    );
  }

  bool get isUploading => status == _LocalOutgoingMessageStatus.uploading;

  bool get isFailed => status == _LocalOutgoingMessageStatus.failed;
}

class _TimelineMessageItem {
  final ChatMessageModel? message;
  final _LocalOutgoingMessage? localMessage;

  const _TimelineMessageItem._({this.message, this.localMessage});

  factory _TimelineMessageItem.remote(ChatMessageModel message) {
    return _TimelineMessageItem._(message: message);
  }

  factory _TimelineMessageItem.local(_LocalOutgoingMessage message) {
    return _TimelineMessageItem._(localMessage: message);
  }

  DateTime get createdAt => message?.createdAt ?? localMessage!.createdAt;

  int get sortKey => message?.id ?? localMessage!.localId;
}

import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/utils/attachment_picker.dart';
import 'package:mishon_app/core/utils/external_url.dart';
import 'package:mishon_app/core/widgets/fullscreen_image_screen.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';

class ChatScreenArgs {
  final int conversationId;
  final int peerId;
  final String peerUsername;
  final String? peerAvatarUrl;
  final double peerAvatarScale;
  final double peerAvatarOffsetX;
  final double peerAvatarOffsetY;

  const ChatScreenArgs({
    required this.conversationId,
    required this.peerId,
    required this.peerUsername,
    required this.peerAvatarUrl,
    this.peerAvatarScale = 1,
    this.peerAvatarOffsetX = 0,
    this.peerAvatarOffsetY = 0,
  });
}

class ChatScreen extends ConsumerStatefulWidget {
  final ChatScreenArgs args;

  const ChatScreen({super.key, required this.args});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const int _maxAttachmentBytes = 15 * 1024 * 1024;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _poller;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  List<ChatMessageModel> _messages = const [];
  ChatMessageModel? _replyingTo;
  ChatMessageModel? _editingMessage;
  UserProfile? _peerProfile;
  List<_PendingAttachment> _pendingAttachments = const [];
  List<_FailedOutgoingMessage> _failedMessages = const [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    unawaited(_loadPeerProfile());
    _poller = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadMessages(silent: true);
      if (timer.tick % 5 == 0) {
        _loadPeerProfile(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final messages = await ref
          .read(socialRepositoryProvider)
          .getMessages(widget.args.conversationId);
      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      unawaited(
        ref.read(notificationSummaryProvider.notifier).refresh(silent: true),
      );
      _scrollToBottom();
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
        _errorMessage = 'Не удалось загрузить сообщения';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPeerProfile({bool silent = false}) async {
    try {
      final profile = await ref
          .read(authRepositoryProvider)
          .getUserProfile(widget.args.peerId);
      if (!mounted) {
        return;
      }

      setState(() {
        _peerProfile = profile;
      });
    } on ApiException catch (_) {
      if (!silent && mounted) {
        _showSnackBar('Не удалось загрузить статус собеседника', isError: true);
      }
    } on OfflineException catch (_) {
      if (!silent && mounted) {
        _showSnackBar('Нет соединения для загрузки статуса', isError: true);
      }
    } catch (_) {
      if (!silent && mounted) {
        _showSnackBar('Не удалось обновить статус собеседника', isError: true);
      }
    }
  }

  Future<void> _pickAttachments(AttachmentPickType type) async {
    if (_editingMessage != null) {
      _showSnackBar(
        'Во время редактирования вложения менять нельзя',
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
          'Общий размер вложений не должен превышать 15 МБ',
          isError: true,
        );
        return;
      }

      setState(() {
        _pendingAttachments = [..._pendingAttachments, ...selected];
      });
    } catch (error) {
      _showSnackBar('Не удалось выбрать файлы: $error', isError: true);
    }
  }

  Future<void> _submit() async {
    final content = _messageController.text.trim();
    final hasAttachments = _pendingAttachments.isNotEmpty;
    final draftAttachments = List<_PendingAttachment>.of(_pendingAttachments);
    final draftReplyingTo = _replyingTo;

    if (_isSending) {
      return;
    }

    if (_editingMessage != null && content.isEmpty) {
      return;
    }

    if (_editingMessage == null && content.isEmpty && !hasAttachments) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final repository = ref.read(socialRepositoryProvider);
      if (_editingMessage != null) {
        await repository.updateMessage(
          widget.args.conversationId,
          _editingMessage!.id,
          content,
        );
        _showSnackBar('Сообщение изменено');
      } else {
        await repository.sendMessage(
          widget.args.conversationId,
          content.isEmpty ? null : content,
          replyToMessageId: _replyingTo?.id,
          attachments: _pendingAttachments
              .map(
                (attachment) => ChatUploadAttachment(
                  fileName: attachment.fileName,
                  bytes: attachment.bytes,
                  isImage: attachment.isImage,
                ),
              )
              .toList(growable: false),
        );
      }

      _resetComposer();
      await _loadMessages(silent: true);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      if (_editingMessage == null) {
        _addFailedMessage(content, draftAttachments, draftReplyingTo);
        _resetComposer();
        _scrollToBottom();
      }
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось сохранить сообщение', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteMessage(ChatMessageModel message) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Удалить сообщение?'),
                content: const Text(
                  'После удаления вернуть его уже не получится.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Удалить'),
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
          .deleteMessage(widget.args.conversationId, message.id);
      if (_editingMessage?.id == message.id || _replyingTo?.id == message.id) {
        _resetComposer();
      }
      await _loadMessages(silent: true);
      _showSnackBar('Сообщение удалено');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось удалить сообщение', isError: true);
    }
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

  void _addFailedMessage(
    String content,
    List<_PendingAttachment> attachments,
    ChatMessageModel? replyTo,
  ) {
    setState(() {
      _failedMessages = [
        ..._failedMessages,
        _FailedOutgoingMessage(
          localId: DateTime.now().microsecondsSinceEpoch,
          content: content,
          createdAt: DateTime.now(),
          replyToMessageId: replyTo?.id,
          replyToSenderUsername: replyTo?.senderUsername,
          replyToContent:
              replyTo?.content.isNotEmpty == true
                  ? replyTo!.content
                  : replyTo != null && replyTo.attachments.isNotEmpty
                  ? 'Вложение'
                  : null,
          attachments: attachments
              .map(
                (attachment) => _PendingAttachment(
                  fileName: attachment.fileName,
                  bytes: attachment.bytes,
                  isImage: attachment.isImage,
                ),
              )
              .toList(growable: false),
        ),
      ];
    });
  }

  Future<void> _retryFailedMessage(_FailedOutgoingMessage message) async {
    if (_isSending) {
      return;
    }

    setState(() => _isSending = true);
    try {
      await ref
          .read(socialRepositoryProvider)
          .sendMessage(
            widget.args.conversationId,
            message.content.isEmpty ? null : message.content,
            replyToMessageId: message.replyToMessageId,
            attachments: message.attachments
                .map(
                  (attachment) => ChatUploadAttachment(
                    fileName: attachment.fileName,
                    bytes: attachment.bytes,
                    isImage: attachment.isImage,
                  ),
                )
                .toList(growable: false),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _failedMessages = _failedMessages
            .where((item) => item.localId != message.localId)
            .toList(growable: false);
      });
      await _loadMessages(silent: true);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось отправить сообщение', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _discardFailedMessage(_FailedOutgoingMessage message) {
    setState(() {
      _failedMessages = _failedMessages
          .where((item) => item.localId != message.localId)
          .toList(growable: false);
    });
  }

  List<_TimelineMessageItem> _buildTimelineItems() {
    final items = <_TimelineMessageItem>[
      ..._messages.map(_TimelineMessageItem.remote),
      ..._failedMessages.map(_TimelineMessageItem.failed),
    ];

    items.sort((left, right) {
      final dateCompare = left.createdAt.compareTo(right.createdAt);
      if (dateCompare != 0) {
        return dateCompare;
      }

      return left.sortKey.compareTo(right.sortKey);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 140,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
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
      _showSnackBar('Некорректная ссылка на файл', isError: true);
      return;
    }

    final launched = await openExternalUrl(uri.toString());
    if (!launched && mounted) {
      _showSnackBar('Не удалось открыть файл', isError: true);
    }
  }

  void _openPeerProfile() {
    context.push('/profile/${widget.args.peerId}');
  }

  String _formatPresenceLabel() {
    final profile = _peerProfile;
    if (profile == null) {
      return '...';
    }

    if (profile.isOnline) {
      return 'онлайн';
    }

    final localLastSeen = profile.lastSeenAt.toLocal();
    final timeLabel = DateFormat('HH:mm').format(localLastSeen);
    final difference = DateTime.now().difference(localLastSeen);

    if (difference.inDays >= 1) {
      return 'был в сети ${difference.inDays} д. $timeLabel';
    }

    return 'был в сети $timeLabel';
  }

  @override
  Widget build(BuildContext context) {
    final timelineItems = _buildTimelineItems();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openPeerProfile,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _PeerAvatar(
                    username: widget.args.peerUsername,
                    avatarUrl: widget.args.peerAvatarUrl,
                    avatarScale: widget.args.peerAvatarScale,
                    avatarOffsetX: widget.args.peerAvatarOffsetX,
                    avatarOffsetY: widget.args.peerAvatarOffsetY,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.args.peerUsername,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          _formatPresenceLabel(),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF7A879A),
                            fontWeight: FontWeight.w600,
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
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7F6FF), Color(0xFFF9FBFF), Color(0xFFFFFBF6)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child:
                  _isLoading
                      ? const LoadingState()
                      : _errorMessage != null
                      ? ErrorState(
                        message: _errorMessage!,
                        onRetry: () => _loadMessages(),
                      )
                      : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: timelineItems.length,
                        itemBuilder: (context, index) {
                          final item = timelineItems[index];
                          if (item.message != null) {
                            final message = item.message!;
                            return _MessageBubble(
                              message: message,
                              onReply: () => _startReply(message),
                              onEdit:
                                  message.isMine
                                      ? () => _startEdit(message)
                                      : null,
                              onDelete:
                                  message.isMine
                                      ? () => _deleteMessage(message)
                                      : null,
                              onOpenAttachment: _openAttachment,
                            );
                          }

                          final failedMessage = item.failedMessage!;
                          return _FailedMessageBubble(
                            message: failedMessage,
                            onRetry: () => _retryFailedMessage(failedMessage),
                            onDelete:
                                () => _discardFailedMessage(failedMessage),
                          );
                        },
                      ),
            ),
            _MessageComposer(
              controller: _messageController,
              isSending: _isSending,
              onSubmit: _submit,
              replyingTo: _replyingTo,
              editingMessage: _editingMessage,
              onCancelContext: _resetComposer,
              pendingAttachments: _pendingAttachments,
              onPickImages: () => _pickAttachments(AttachmentPickType.image),
              onPickFiles: () => _pickAttachments(AttachmentPickType.any),
              onRemoveAttachment: _removePendingAttachment,
              totalAttachmentBytes: _pendingAttachments.fold<int>(
                0,
                (sum, item) => sum + item.sizeBytes,
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

  const _PeerAvatar({
    required this.username,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      username: username,
      imageUrl: avatarUrl,
      size: 40,
      circle: false,
      borderRadius: BorderRadius.circular(16),
      scale: avatarScale,
      offsetX: avatarOffsetX,
      offsetY: avatarOffsetY,
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
                  title: const Text('Фото'),
                  subtitle: const Text('Картинка придет как изображение в чат'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onPickImages();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_rounded),
                  title: const Text('Файл'),
                  subtitle: const Text('Картинка или документ придут как файл'),
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
    final hasContext = replyingTo != null || editingMessage != null;
    final canAttach = editingMessage == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -10),
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
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      editingMessage != null
                          ? Icons.edit_rounded
                          : Icons.reply_rounded,
                      color: const Color(0xFF2F67FF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        editingMessage != null
                            ? 'Редактирование сообщения'
                            : 'Ответ для ${replyingTo!.senderUsername}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onCancelContext,
                      icon: const Icon(Icons.close_rounded),
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
                  color: const Color(0xFFF8F9FD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Вложения • ${_formatBytes(totalAttachmentBytes)} / 15 МБ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                              onRemove: () => onRemoveAttachment(attachment),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                if (canAttach)
                  IconButton.filledTonal(
                    onPressed:
                        isSending
                            ? null
                            : () => _showAttachmentTypeSheet(context),
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                if (canAttach) const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText:
                          editingMessage != null
                              ? 'Измените сообщение...'
                              : replyingTo != null
                              ? 'Напишите ответ...'
                              : 'Напишите сообщение...',
                      filled: true,
                      fillColor: const Color(0xFFF8F9FD),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: isSending ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
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
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes Б';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<ChatAttachmentModel> onOpenAttachment;

  const _MessageBubble({
    required this.message,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final alignment =
        message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final backgroundColor =
        message.isMine ? const Color(0xFF2F67FF) : Colors.white;
    final textColor = message.isMine ? Colors.white : const Color(0xFF18243C);
    final imageAttachments = message.attachments
        .where((attachment) => attachment.isImage)
        .toList(growable: false);
    final fileAttachments = message.attachments
        .where((attachment) => !attachment.isImage)
        .toList(growable: false);

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onLongPress: onReply,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment:
                    message.isMine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                children: [
                  if (message.replyToContent != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            message.isMine
                                ? Colors.white.withValues(alpha: 0.18)
                                : const Color(0xFFF3F6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyToSenderUsername ?? 'Сообщение',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  message.isMine
                                      ? Colors.white70
                                      : const Color(0xFF3557A8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message.replyToContent!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  message.isMine
                                      ? Colors.white70
                                      : const Color(0xFF52627B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!message.isMine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderUsername,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4E5D78),
                        ),
                      ),
                    ),
                  if (message.content.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: message.attachments.isNotEmpty ? 10 : 0,
                      ),
                      child: Text(
                        message.content,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          height: 1.35,
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
                                child: _ImageAttachmentCard(
                                  attachment: attachment,
                                  onTap: () => onOpenAttachment(attachment),
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
                                onTap: () => onOpenAttachment(attachment),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              message.isMine
                                  ? Colors.white70
                                  : Colors.grey.shade500,
                        ),
                      ),
                      if (message.editedAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'изменено',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                message.isMine
                                    ? Colors.white70
                                    : Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (message.isMine) ...[
                        const SizedBox(width: 8),
                        Icon(
                          message.isReadByPeer
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 18,
                          color:
                              message.isReadByPeer
                                  ? const Color(0xFFCFE0FF)
                                  : Colors.white70,
                        ),
                      ],
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color:
                              message.isMine
                                  ? Colors.white70
                                  : Colors.grey.shade500,
                        ),
                        onSelected: (value) {
                          if (value == 'reply') {
                            onReply();
                          } else if (value == 'edit') {
                            onEdit?.call();
                          } else if (value == 'delete') {
                            onDelete?.call();
                          }
                        },
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'reply',
                                child: Text('Ответить'),
                              ),
                              if (onEdit != null)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Редактировать'),
                                ),
                              if (onDelete != null)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Удалить'),
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
      ),
    );
  }
}

class _FailedMessageBubble extends StatelessWidget {
  final _FailedOutgoingMessage message;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  const _FailedMessageBubble({
    required this.message,
    required this.onRetry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageAttachments = message.attachments
        .where((attachment) => attachment.isImage)
        .toList(growable: false);
    final fileAttachments = message.attachments
        .where((attachment) => !attachment.isImage)
        .toList(growable: false);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: const Color(0xFF2F67FF),
          borderRadius: BorderRadius.circular(24),
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
                          message.replyToSenderUsername ?? 'Сообщение',
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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        height: 1.35,
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
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.createdAt.toLocal()),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
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
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      onSelected: (value) {
                        if (value == 'retry') {
                          onRetry();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder:
                          (context) => const [
                            PopupMenuItem(
                              value: 'retry',
                              child: Text('Повторить'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Удалить'),
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
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            attachment.isImage
                ? Icons.image_rounded
                : Icons.insert_drive_file_rounded,
            size: 18,
            color: const Color(0xFF2F67FF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.fileName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 16),
            ),
          ),
        ],
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: const Color(0x14000000),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 240,
            height: 180,
            child: CachedNetworkImage(
              imageUrl: attachment.fileUrl,
              fit: BoxFit.cover,
              placeholder:
                  (_, __) => const Center(child: CircularProgressIndicator()),
              errorWidget:
                  (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_rounded, size: 34),
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
    final foreground = isMine ? Colors.white : const Color(0xFF24324A);

    return Material(
      color:
          isMine
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFF4F7FC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attach_file_rounded, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatBytes(attachment.sizeBytes),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            isMine ? Colors.white70 : const Color(0xFF6E7E95),
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

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes Б';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}

class _PendingImageAttachmentCard extends StatelessWidget {
  final _PendingAttachment attachment;

  const _PendingImageAttachmentCard({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 240,
        height: 180,
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
    );
  }
}

class _PendingFileAttachmentTile extends StatelessWidget {
  final _PendingAttachment attachment;

  const _PendingFileAttachmentTile({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file_rounded, color: Colors.white),
            const SizedBox(width: 8),
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
                    _FileAttachmentTile._formatBytes(attachment.sizeBytes),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
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

class _FailedOutgoingMessage {
  final int localId;
  final String content;
  final DateTime createdAt;
  final int? replyToMessageId;
  final String? replyToSenderUsername;
  final String? replyToContent;
  final List<_PendingAttachment> attachments;

  const _FailedOutgoingMessage({
    required this.localId,
    required this.content,
    required this.createdAt,
    required this.replyToMessageId,
    required this.replyToSenderUsername,
    required this.replyToContent,
    required this.attachments,
  });
}

class _TimelineMessageItem {
  final ChatMessageModel? message;
  final _FailedOutgoingMessage? failedMessage;

  const _TimelineMessageItem._({this.message, this.failedMessage});

  factory _TimelineMessageItem.remote(ChatMessageModel message) {
    return _TimelineMessageItem._(message: message);
  }

  factory _TimelineMessageItem.failed(_FailedOutgoingMessage message) {
    return _TimelineMessageItem._(failedMessage: message);
  }

  DateTime get createdAt => message?.createdAt ?? failedMessage!.createdAt;

  int get sortKey => message?.id ?? failedMessage!.localId;
}

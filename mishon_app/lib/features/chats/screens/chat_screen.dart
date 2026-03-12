import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

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
  bool _isTyping = false;
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
    _messageController.addListener(_handleComposerChanged);
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
    _messageController.removeListener(_handleComposerChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    final isTyping = _messageController.text.trim().isNotEmpty;
    if (!mounted || isTyping == _isTyping) {
      return;
    }

    setState(() {
      _isTyping = isTyping;
    });
  }

  bool _isNearBottom({double threshold = 96}) {
    if (!_scrollController.hasClients) {
      return true;
    }

    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= threshold;
  }

  Future<void> _loadMessages({
    bool silent = false,
    bool forceScrollToBottom = false,
  }) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final shouldAutoScroll =
        forceScrollToBottom ||
        !silent ||
        !_scrollController.hasClients ||
        _isNearBottom();

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
      if (shouldAutoScroll) {
        _scrollToBottom();
      }
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
      await _loadMessages(silent: true, forceScrollToBottom: true);
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
      await _loadMessages(silent: true, forceScrollToBottom: true);
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final seenDay = DateTime(
      localLastSeen.year,
      localLastSeen.month,
      localLastSeen.day,
    );
    final dayDifference = today.difference(seenDay).inDays;

    if (dayDifference <= 0) {
      return 'был в сети $timeLabel';
    }

    if (dayDifference == 1) {
      return 'был в сети вчера в $timeLabel';
    }

    return 'был в сети $dayDifference д. назад в $timeLabel';
  }

  @override
  Widget build(BuildContext context) {
    final timelineItems = _buildTimelineItems();
    final showTypingIndicator =
        _isTyping &&
        _editingMessage == null &&
        (_peerProfile?.isOnline ?? true);

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
            onTap: _openPeerProfile,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  _PeerAvatar(
                    username: widget.args.peerUsername,
                    avatarUrl: widget.args.peerAvatarUrl,
                    avatarScale: widget.args.peerAvatarScale,
                    avatarOffsetX: widget.args.peerAvatarOffsetX,
                    avatarOffsetY: widget.args.peerAvatarOffsetY,
                    isOnline: _peerProfile?.isOnline ?? false,
                  ),
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
                        Text(
                          _formatPresenceLabel(),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                _peerProfile?.isOnline == true
                                    ? const Color(0xFF229C5A)
                                    : const Color(0xFF728098),
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
                      _isLoading
                          ? const LoadingState()
                          : _errorMessage != null
                          ? ErrorState(
                            message: _errorMessage!,
                            onRetry: () => _loadMessages(),
                          )
                          : timelineItems.isEmpty
                          ? RefreshIndicator(
                            onRefresh: () => _loadMessages(),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.all(24),
                              children: const [
                                EmptyState(
                                  icon: Icons.forum_outlined,
                                  title: 'Пока нет сообщений',
                                  subtitle:
                                      'Напишите первое сообщение, чтобы начать диалог.',
                                ),
                              ],
                            ),
                          )
                          : RefreshIndicator(
                            onRefresh: () => _loadMessages(),
                            child: Scrollbar(
                              controller: _scrollController,
                              child: ListView.builder(
                                controller: _scrollController,
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
                                    onRetry:
                                        () =>
                                            _retryFailedMessage(failedMessage),
                                    onDelete:
                                        () => _discardFailedMessage(
                                          failedMessage,
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
                  subtitle: const Text('Отправить как изображение'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onPickImages();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_rounded),
                  title: const Text('Файл'),
                  subtitle: const Text('Отправить как файл или документ'),
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
                      color: const Color(0xFFF3F6FF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDDE6F6)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7EEFF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            editingMessage != null
                                ? Icons.edit_rounded
                                : Icons.reply_rounded,
                            color: const Color(0xFF2F67FF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            editingMessage != null
                                ? 'Редактирование сообщения'
                                : 'Ответ для ${replyingTo!.senderUsername}',
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
                          'Вложения • ${_formatBytes(totalAttachmentBytes)} / 15 МБ',
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
                                        ? 'Измените сообщение...'
                                        : replyingTo != null
                                        ? 'Напишите ответ...'
                                        : 'Напишите сообщение...',
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
                              color:
                                  hasDraft
                                      ? const Color(0xFF2F67FF)
                                      : const Color(0xFFC9D4EA),
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
                                                : Icons.arrow_upward_rounded,
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

  BorderRadius get _bubbleRadius {
    if (message.isMine) {
      return const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(10),
      );
    }

    return const BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
      bottomLeft: Radius.circular(10),
      bottomRight: Radius.circular(24),
    );
  }

  String? _readReceiptTooltip() {
    if (!message.isMine ||
        !message.isReadByPeer ||
        message.readByPeerAt == null) {
      return null;
    }

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
      return 'Прочитано в $timeLabel';
    }

    if (dayDifference == 1) {
      return 'Прочитано вчера в $timeLabel';
    }

    final dateLabel = DateFormat('dd.MM.yyyy').format(localReadAt);
    return 'Прочитано $dateLabel в $timeLabel';
  }

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
    final readTooltip = _readReceiptTooltip();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = math.min(constraints.maxWidth * 0.72, 420.0);

        return Align(
          alignment: alignment,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('message-${message.id}'),
            duration: const Duration(milliseconds: 240),
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
                color: backgroundColor,
                borderRadius: _bubbleRadius,
                boxShadow: [
                  BoxShadow(
                    color:
                        message.isMine
                            ? const Color(0xFF2F67FF).withValues(alpha: 0.16)
                            : const Color(0xFF132443).withValues(alpha: 0.06),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: _bubbleRadius,
                child: InkWell(
                  onLongPress: onReply,
                  borderRadius: _bubbleRadius,
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
                                      ? Colors.white.withValues(alpha: 0.16)
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
                                color: textColor,
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
                                      child: _ImageAttachmentCard(
                                        attachment: attachment,
                                        onTap:
                                            () => onOpenAttachment(attachment),
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
                                color:
                                    message.isMine
                                        ? Colors.white70
                                        : const Color(0xFF738299),
                                fontWeight: FontWeight.w600,
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
                                          : const Color(0xFF738299),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (message.isMine) ...[
                              const SizedBox(width: 8),
                              if (readTooltip != null)
                                Tooltip(
                                  message: readTooltip,
                                  waitDuration: const Duration(
                                    milliseconds: 250,
                                  ),
                                  child: const Icon(
                                    Icons.done_all_rounded,
                                    size: 18,
                                    color: Color(0xFFCFE0FF),
                                  ),
                                )
                              else
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
                            const SizedBox(width: 2),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                                color:
                                    message.isMine
                                        ? Colors.white70
                                        : const Color(0xFF738299),
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
          ),
        );
      },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = math.min(constraints.maxWidth * 0.72, 420.0);

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
      },
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
                      _formatBytes(attachment.sizeBytes),
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
                    _FileAttachmentTile._formatBytes(attachment.sizeBytes),
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

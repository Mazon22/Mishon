import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
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
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _poller;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  List<ChatMessageModel> _messages = const [];
  ChatMessageModel? _replyingTo;
  ChatMessageModel? _editingMessage;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _poller = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages(silent: true));
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
      final messages = await ref.read(socialRepositoryProvider).getMessages(widget.args.conversationId);
      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      unawaited(ref.read(notificationSummaryProvider.notifier).refresh(silent: true));
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

  Future<void> _submit() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final repository = ref.read(socialRepositoryProvider);
      if (_editingMessage != null) {
        await repository.updateMessage(widget.args.conversationId, _editingMessage!.id, content);
        _showSnackBar('Сообщение изменено');
      } else {
        await repository.sendMessage(
          widget.args.conversationId,
          content,
          replyToMessageId: _replyingTo?.id,
        );
        _showSnackBar(_replyingTo != null ? 'Ответ отправлен' : 'Сообщение отправлено');
      }

      _resetComposer();
      await _loadMessages(silent: true);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
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
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить сообщение?'),
            content: const Text('После удаления вернуть его уже не получится.'),
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
      await ref.read(socialRepositoryProvider).deleteMessage(widget.args.conversationId, message.id);
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
      _messageController.text = message.content;
      _messageController.selection = TextSelection.collapsed(offset: _messageController.text.length);
    });
  }

  void _resetComposer() {
    setState(() {
      _replyingTo = null;
      _editingMessage = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Личные сообщения',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7F6FF),
              Color(0xFFF9FBFF),
              Color(0xFFFFFBF6),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const LoadingState()
                  : _errorMessage != null
                      ? ErrorState(
                          message: _errorMessage!,
                          onRetry: () => _loadMessages(),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _MessageBubble(
                              message: message,
                              onReply: () => _startReply(message),
                              onEdit: message.isMine ? () => _startEdit(message) : null,
                              onDelete: message.isMine ? () => _deleteMessage(message) : null,
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

  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSubmit,
    required this.replyingTo,
    required this.editingMessage,
    required this.onCancelContext,
  });

  @override
  Widget build(BuildContext context) {
    final hasContext = replyingTo != null || editingMessage != null;

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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      editingMessage != null ? Icons.edit_rounded : Icons.reply_rounded,
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: editingMessage != null
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
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(editingMessage != null ? Icons.check_rounded : Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.message,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final backgroundColor = message.isMine ? const Color(0xFF2F67FF) : Colors.white;
    final textColor = message.isMine ? Colors.white : const Color(0xFF18243C);

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
                crossAxisAlignment: message.isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (message.replyToContent != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: message.isMine
                            ? Colors.white.withValues(alpha: 0.18)
                            : const Color(0xFFF3F6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyToSenderUsername ?? 'Сообщение',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: message.isMine ? Colors.white70 : const Color(0xFF3557A8),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message.replyToContent!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: message.isMine ? Colors.white70 : const Color(0xFF52627B),
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
                  Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: message.isMine ? Colors.white70 : Colors.grey.shade500,
                            ),
                      ),
                      if (message.editedAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'изменено',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: message.isMine ? Colors.white70 : Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color: message.isMine ? Colors.white70 : Colors.grey.shade500,
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
                        itemBuilder: (context) => [
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

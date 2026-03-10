import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/states.dart';

class ChatScreenArgs {
  final int conversationId;
  final int peerId;
  final String peerUsername;
  final String? peerAvatarUrl;

  const ChatScreenArgs({
    required this.conversationId,
    required this.peerId,
    required this.peerUsername,
    required this.peerAvatarUrl,
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
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
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
        _errorMessage = 'Не удалось загрузить сообщения';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final message = await ref.read(socialRepositoryProvider).sendMessage(
            widget.args.conversationId,
            content,
          );
      if (!mounted) return;

      _messageController.clear();
      setState(() {
        _messages = [..._messages, message];
      });
      _scrollToBottom();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Text(widget.args.peerUsername.substring(0, 1).toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.args.peerUsername,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF8F9FC),
                    Color(0xFFFDF8F3),
                  ],
                ),
              ),
              child: _isLoading
                  ? const LoadingState()
                  : _errorMessage != null
                      ? ErrorState(
                          message: _errorMessage!,
                          onRetry: () => _loadMessages(),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _MessageBubble(message: message);
                          },
                        ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Напишите сообщение...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSending ? null : _sendMessage,
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment = message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final backgroundColor = message.isMine
        ? Theme.of(context).colorScheme.primary
        : Colors.white;
    final textColor = message.isMine ? Colors.white : Colors.black87;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              message.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!message.isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderUsername,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            Text(
              message.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: textColor),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('HH:mm').format(message.createdAt.toLocal()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: message.isMine ? Colors.white70 : Colors.grey.shade500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

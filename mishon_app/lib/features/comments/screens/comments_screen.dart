import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/auth/providers/auth_provider.dart';
import 'package:mishon_app/features/comments/providers/comments_provider.dart';
import 'package:mishon_app/features/profile/providers/profile_provider.dart';

class CommentsScreenArgs {
  final int postId;
  final int postUserId;

  const CommentsScreenArgs({required this.postId, required this.postUserId});
}

class CommentsScreen extends ConsumerStatefulWidget {
  final CommentsScreenArgs args;

  const CommentsScreen({super.key, required this.args});

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _poller;
  bool _isSubmitting = false;
  Comment? _replyingTo;
  Comment? _editingComment;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _poller = Timer.periodic(const Duration(seconds: 8), (_) => _loadComments());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    await ref.read(commentsProvider(widget.args.postId).notifier).refresh();
  }

  Future<void> _submit() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmitting) {
      return;
    }

    if (kIsWeb && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(postRepositoryProvider);
      if (_editingComment != null) {
        await repository.updateComment(widget.args.postId, _editingComment!.id, content);
        _showSnackBar('Комментарий сохранён');
      } else {
        await repository.createComment(
          widget.args.postId,
          content,
          parentCommentId: _replyingTo?.id,
        );
        _showSnackBar(_replyingTo != null ? 'Ответ отправлен' : 'Комментарий добавлен');
      }

      _resetComposer();
      await _loadComments();
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось сохранить комментарий', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить комментарий?'),
            content: const Text('Это действие нельзя отменить.'),
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
      await ref.read(postRepositoryProvider).deleteComment(widget.args.postId, comment.id);
      if (_editingComment?.id == comment.id || _replyingTo?.id == comment.id) {
        _resetComposer();
      }
      await _loadComments();
      _showSnackBar('Комментарий удалён');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось удалить комментарий', isError: true);
    }
  }

  void _startReply(Comment comment) {
    setState(() {
      _replyingTo = comment;
      _editingComment = null;
    });
    _focusNode.requestFocus();
  }

  void _startEdit(Comment comment) {
    setState(() {
      _editingComment = comment;
      _replyingTo = null;
      _commentController.text = comment.content;
      _commentController.selection = TextSelection.collapsed(offset: _commentController.text.length);
    });
    _focusNode.requestFocus();
  }

  void _resetComposer() {
    setState(() {
      _replyingTo = null;
      _editingComment = null;
      _commentController.clear();
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
    final commentsAsync = ref.watch(commentsProvider(widget.args.postId));
    final currentUserId = ref.watch(userIdProvider).value;
    final currentProfile = ref.watch(profileNotifierProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Комментарии'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7F6FF),
              Color(0xFFFFFBF5),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: commentsAsync.when(
                data: (comments) {
                  if (comments.isEmpty) {
                    return const EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Пока нет комментариев',
                      subtitle: 'Будьте первым, кто начнёт обсуждение.',
                    );
                  }

                  final byId = {
                    for (final comment in comments) comment.id: comment,
                  };

                  return RefreshIndicator(
                    onRefresh: _loadComments,
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final depth = _depthFor(comment, byId);

                        return _CommentTile(
                          comment: comment,
                          depth: depth,
                          isOwnComment: currentUserId != null && currentUserId == comment.userId,
                          onOpenProfile: () => context.push('/profile/${comment.userId}'),
                          onReply: () => _startReply(comment),
                          onEdit: () => _startEdit(comment),
                          onDelete: () => _deleteComment(comment),
                        );
                      },
                    ),
                  );
                },
                loading: () => const LoadingState(),
                error: (error, stack) => ErrorState(
                  message: _getErrorMessage(error),
                  onRetry: _loadComments,
                ),
              ),
            ),
            _ComposerPanel(
              controller: _commentController,
              focusNode: _focusNode,
              isSubmitting: _isSubmitting,
              onSubmit: _submit,
              currentUsername: currentProfile?.username ?? 'You',
              currentAvatarUrl: currentProfile?.avatarUrl,
              currentAvatarScale: currentProfile?.avatarScale ?? 1,
              currentAvatarOffsetX: currentProfile?.avatarOffsetX ?? 0,
              currentAvatarOffsetY: currentProfile?.avatarOffsetY ?? 0,
              replyingTo: _replyingTo,
              editingComment: _editingComment,
              onCancelContext: _resetComposer,
            ),
          ],
        ),
      ),
    );
  }

  int _depthFor(Comment comment, Map<int, Comment> byId) {
    var depth = 0;
    Comment? current = comment;
    while (current?.parentCommentId != null && depth < 6) {
      current = byId[current!.parentCommentId!];
      depth++;
    }
    return depth;
  }

  String _getErrorMessage(Object error) {
    if (error is OfflineException) {
      return 'Нет подключения к интернету';
    }
    if (error is String) {
      return error;
    }
    return 'Ошибка загрузки комментариев';
  }
}

class _ComposerPanel extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final String currentUsername;
  final String? currentAvatarUrl;
  final double currentAvatarScale;
  final double currentAvatarOffsetX;
  final double currentAvatarOffsetY;
  final Comment? replyingTo;
  final Comment? editingComment;
  final VoidCallback onCancelContext;

  const _ComposerPanel({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onSubmit,
    required this.currentUsername,
    required this.currentAvatarUrl,
    required this.currentAvatarScale,
    required this.currentAvatarOffsetX,
    required this.currentAvatarOffsetY,
    required this.replyingTo,
    required this.editingComment,
    required this.onCancelContext,
  });

  @override
  Widget build(BuildContext context) {
    final hasContext = replyingTo != null || editingComment != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
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
                      editingComment != null ? Icons.edit_outlined : Icons.reply_rounded,
                      color: const Color(0xFF2F67FF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        editingComment != null
                            ? 'Редактирование комментария'
                            : 'Ответ для ${replyingTo!.username}',
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 2),
                  child: AppAvatar(
                    username: currentUsername,
                    imageUrl: currentAvatarUrl,
                    size: 42,
                    scale: currentAvatarScale,
                    offsetX: currentAvatarOffsetX,
                    offsetY: currentAvatarOffsetY,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: null,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: editingComment != null
                          ? 'Измените комментарий...'
                          : replyingTo != null
                              ? 'Напишите ответ...'
                              : 'Напишите комментарий...',
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
                  onPressed: isSubmitting ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(editingComment != null ? Icons.check_rounded : Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final int depth;
  final bool isOwnComment;
  final VoidCallback onOpenProfile;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.depth,
    required this.isOwnComment,
    required this.onOpenProfile,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, HH:mm');
    final horizontalInset = 12.0 * depth;

    return Padding(
      padding: EdgeInsets.only(left: horizontalInset),
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                username: comment.username,
                imageUrl: comment.userAvatarUrl,
                size: 42,
                scale: comment.userAvatarScale,
                offsetX: comment.userAvatarOffsetX,
                offsetY: comment.userAvatarOffsetY,
                onTap: onOpenProfile,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: onOpenProfile,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    comment.username,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateFormat.format(comment.createdAt.toLocal()),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (isOwnComment)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit();
                              } else if (value == 'delete') {
                                onDelete();
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Редактировать'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Удалить'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (comment.replyToUsername != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Ответ для ${comment.replyToUsername}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF3557A8),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      comment.content,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: onReply,
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: const Text('Ответить'),
                        ),
                        if (comment.editedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'изменено',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ),
                      ],
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
}

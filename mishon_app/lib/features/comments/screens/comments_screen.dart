import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
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
  bool _isSubmitting = false;
  Comment? _replyingTo;
  Comment? _editingComment;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    await ref.read(commentsProvider(widget.args.postId).notifier).refresh();
  }

  Future<void> _submit() async {
    final strings = AppStrings.of(context);
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
        await repository.updateComment(
          widget.args.postId,
          _editingComment!.id,
          content,
        );
        _showSnackBar('Комментарий сохранён');
      } else {
        await repository.createComment(
          widget.args.postId,
          content,
          parentCommentId: _replyingTo?.id,
        );
        _showSnackBar(
          _replyingTo != null ? 'Ответ отправлен' : 'Комментарий добавлен',
        );
      }

      _resetComposer();
      await _loadComments();
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        strings.isRu
            ? 'Не удалось сохранить комментарий'
            : 'Could not save the comment',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final strings = AppStrings.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  strings.isRu ? 'Удалить комментарий?' : 'Delete comment?',
                ),
                content: Text(
                  strings.isRu
                      ? 'Это действие нельзя отменить.'
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

    try {
      await ref
          .read(postRepositoryProvider)
          .deleteComment(widget.args.postId, comment.id);
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
      _showSnackBar(
        strings.isRu
            ? 'Не удалось удалить комментарий'
            : 'Could not delete the comment',
        isError: true,
      );
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
      _commentController.selection = TextSelection.collapsed(
        offset: _commentController.text.length,
      );
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
    if (!mounted || !isError) {
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
    final strings = AppStrings.of(context);
    final commentsAsync = ref.watch(commentsProvider(widget.args.postId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final currentProfile = ref.watch(profileNotifierProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(strings.isRu ? 'Комментарии' : 'Comments'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F6FF), Color(0xFFFFFBF5)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: commentsAsync.when(
                data: (comments) {
                  if (comments.isEmpty) {
                    return EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title:
                          strings.isRu
                              ? 'Пока нет комментариев'
                              : 'No comments yet',
                      subtitle:
                          strings.isRu
                              ? 'Будьте первым, кто начнёт обсуждение.'
                              : 'Be the first to start the discussion.',
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
                          isOwnComment:
                              currentUserId != null &&
                              currentUserId == comment.userId,
                          onOpenProfile:
                              () => context.push('/profile/${comment.userId}'),
                          onReply: () => _startReply(comment),
                          onEdit: () => _startEdit(comment),
                          onDelete: () => _deleteComment(comment),
                        );
                      },
                    ),
                  );
                },
                loading: () => const LoadingState(),
                error:
                    (error, stack) => ErrorState(
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
              currentUsername:
                  currentProfile?.username ?? (strings.isRu ? 'Вы' : 'You'),
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
    final strings = AppStrings.of(context);
    if (error is OfflineException) {
      return strings.isRu
          ? 'Нет подключения к интернету'
          : 'No internet connection';
    }
    if (error is String) {
      return error;
    }
    return strings.isRu
        ? 'Ошибка загрузки комментариев'
        : 'Could not load comments';
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
    final strings = AppStrings.of(context);
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
                      editingComment != null
                          ? Icons.edit_outlined
                          : Icons.reply_rounded,
                      color: const Color(0xFF2F67FF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        editingComment != null
                            ? (strings.isRu
                                ? 'Редактирование комментария'
                                : 'Editing comment')
                            : (strings.isRu
                                ? 'Ответ для ${replyingTo!.username}'
                                : 'Reply to ${replyingTo!.username}'),
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
                      hintText:
                          editingComment != null
                              ? (strings.isRu
                                  ? 'Измените комментарий...'
                                  : 'Edit the comment...')
                              : replyingTo != null
                              ? (strings.isRu
                                  ? 'Напишите ответ...'
                                  : 'Write a reply...')
                              : (strings.isRu
                                  ? 'Напишите комментарий...'
                                  : 'Write a comment...'),
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
                  child:
                      isSubmitting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Icon(
                            editingComment != null
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
    final strings = AppStrings.of(context);
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    comment.username,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
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
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(
                                      strings.isRu ? 'Редактировать' : 'Edit',
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(strings.delete),
                                  ),
                                ],
                          ),
                      ],
                    ),
                    if (comment.replyToUsername != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          strings.isRu
                              ? 'Ответ для ${comment.replyToUsername}'
                              : 'Reply to ${comment.replyToUsername}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF3557A8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      comment.content,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: onReply,
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: Text(strings.isRu ? 'Ответить' : 'Reply'),
                        ),
                        if (comment.editedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              strings.isRu ? 'изменено' : 'edited',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic),
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

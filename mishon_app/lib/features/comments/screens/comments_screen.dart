import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/comments/providers/comments_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  bool _isLoading = false;

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
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.getComments(widget.args.postId);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    // Получаем текст до любых изменений фокуса
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    // На Web сначала запрашиваем фокус, иначе будет ошибка при очистке TextField
    // eventTarget == domElement error occurs when trying to clear unfocused TextField on Web
    if (kIsWeb && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
      // Небольшая задержка для Web чтобы фокус успел установиться
      await Future.delayed(const Duration(milliseconds: 50));
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(postRepositoryProvider);
      final newComment = await repository.createComment(widget.args.postId, content);

      // Очищаем поле после успешной отправки
      _commentController.clear();
      setState(() => _isLoading = false);

      // Добавляем новый комментарий в список через provider
      ref.read(commentsProvider(widget.args.postId).notifier).addComment(newComment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Комментарий добавлен'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.apiError.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка отправки комментария'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.args.postId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Комментарии'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Список комментариев
          Expanded(
            child: commentsAsync.when(
              data: (comments) => comments.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _CommentTile(comment: comment);
                      },
                    ),
              loading: () => const LoadingState(),
              error: (error, stack) => ErrorState(
                message: _getErrorMessage(error),
                onRetry: () => ref.read(commentsProvider(widget.args.postId).notifier).refresh(),
              ),
            ),
          ),

          // Поле ввода
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Напишите комментарий...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isLoading
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: _commentController.text.trim().isNotEmpty
                              ? _sendComment
                              : null,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Нет комментариев',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Будьте первым!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
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

// Виджет комментария
class _CommentTile extends StatelessWidget {
  final Comment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Аватар
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: comment.userAvatarUrl != null && comment.userAvatarUrl!.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: comment.userAvatarUrl!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: Text(
                          comment.username[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Text(
                          comment.username[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      comment.username[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // Контент
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(comment.createdAt.toLocal()),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

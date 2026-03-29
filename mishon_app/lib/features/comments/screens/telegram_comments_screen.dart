import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mishon_app/core/constants/api_constants.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/utils/external_url.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/core/widgets/interactive_content_text.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/comments/providers/comments_provider.dart';
import 'package:mishon_app/features/comments/screens/comments_screen_args.dart';
import 'package:mishon_app/features/profile/providers/profile_provider.dart';

final telegramThreadPostProvider = FutureProvider.autoDispose
    .family<Post?, int>(
      (ref, postId) => ref.watch(postRepositoryProvider).getPost(postId),
    );

class TelegramCommentsScreen extends ConsumerStatefulWidget {
  final CommentsScreenArgs args;

  const TelegramCommentsScreen({super.key, required this.args});

  @override
  ConsumerState<TelegramCommentsScreen> createState() =>
      _TelegramCommentsScreenState();
}

class _TelegramCommentsScreenState
    extends ConsumerState<TelegramCommentsScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;
  bool _isTogglingLike = false;
  Comment? _replyingTo;
  Comment? _editingComment;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(commentsProvider(widget.args.postId).notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    return ref.read(commentsProvider(widget.args.postId).notifier).refresh();
  }

  Future<void> _refreshThreadPost() async {
    ref.invalidate(telegramThreadPostProvider(widget.args.postId));
    await ref.read(telegramThreadPostProvider(widget.args.postId).future);
  }

  Future<void> _submit() async {
    final strings = AppStrings.of(context);
    final content = _controller.text.trim();
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
      } else {
        await repository.createComment(
          widget.args.postId,
          content,
          parentCommentId: _replyingTo?.id,
        );
      }
      _resetComposer();
      await _refresh();
      await _refreshThreadPost();
    } on ApiException catch (e) {
      _toast(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _toast(e.message, isError: true);
    } catch (_) {
      _toast(
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

  Future<void> _delete(Comment comment) async {
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
      if (_replyingTo?.id == comment.id || _editingComment?.id == comment.id) {
        _resetComposer();
      }
      await _refresh();
      await _refreshThreadPost();
    } on ApiException catch (e) {
      _toast(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _toast(e.message, isError: true);
    }
  }

  Future<void> _togglePostLike() async {
    final strings = AppStrings.of(context);
    if (_isTogglingLike) {
      return;
    }

    setState(() => _isTogglingLike = true);
    try {
      await ref.read(postRepositoryProvider).toggleLike(widget.args.postId);
      await _refreshThreadPost();
    } on ApiException catch (e) {
      _toast(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _toast(e.message, isError: true);
    } catch (_) {
      _toast(
        strings.isRu ? 'Не удалось обновить лайк' : 'Could not update like',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isTogglingLike = false);
      }
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    showAppToast(context, message: message, isError: isError);
  }

  void _resetComposer() {
    setState(() {
      _replyingTo = null;
      _editingComment = null;
      _controller.clear();
    });
  }

  Future<void> _openMentionProfile(String username) async {
    final normalized = username.trim().replaceFirst('@', '').toLowerCase();
    if (normalized.isEmpty) {
      return;
    }

    final currentUserId = ref.read(currentUserIdProvider);
    final currentProfile = ref.read(profileNotifierProvider).valueOrNull;
    if (currentUserId != null &&
        currentProfile?.username.toLowerCase() == normalized) {
      if (!mounted) {
        return;
      }
      context.push('/profile/$currentUserId');
      return;
    }

    try {
      final users = await ref
          .read(socialRepositoryProvider)
          .getUsers(query: normalized, limit: 12, forceRefresh: true);
      DiscoverUser? match;
      for (final user in users) {
        if (user.username.toLowerCase() == normalized) {
          match = user;
          break;
        }
      }

      if (!mounted) {
        return;
      }

      if (match == null) {
        _toast(
          AppStrings.of(context).isRu
              ? 'Профиль @$normalized не найден'
              : 'Profile @$normalized was not found',
          isError: true,
        );
        return;
      }

      context.push('/profile/${match.id}');
    } on ApiException catch (e) {
      _toast(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _toast(e.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _toast(
        AppStrings.of(context).isRu
            ? 'Не удалось открыть профиль'
            : 'Could not open profile',
        isError: true,
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final opened = await openExternalUrl(url);
    if (!mounted || opened) {
      return;
    }

    _toast(
      AppStrings.of(context).isRu
          ? 'Не удалось открыть ссылку'
          : 'Could not open the link',
      isError: true,
    );
  }

  int _depthFor(Comment comment, Map<int, Comment> byId) {
    var depth = 0;
    Comment? current = comment;
    while (current?.parentCommentId != null && depth < 5) {
      current = byId[current!.parentCommentId!];
      depth++;
    }
    return depth;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final postAsync = ref.watch(telegramThreadPostProvider(widget.args.postId));
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
            colors: [Color(0xFFF6F8FF), Color(0xFFFFFBF5)],
          ),
        ),
        child: Column(
          children: [
            _TelegramThreadHeader(
              postAsync: postAsync,
              postUserId: widget.args.postUserId,
              isLiking: _isTogglingLike,
              onOpenProfile: (userId) => context.push('/profile/$userId'),
              onLike: _togglePostLike,
              onOpenMentionProfile: (username) {
                unawaited(_openMentionProfile(username));
              },
              onOpenUrl: (url) {
                unawaited(_openUrl(url));
              },
            ),
            Expanded(
              child: commentsAsync.when(
                data: (comments) {
                  final byId = {
                    for (final comment in comments) comment.id: comment,
                  };
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: comments.isEmpty ? 2 : comments.length + 1,
                      separatorBuilder:
                          (_, index) => SizedBox(height: index == 0 ? 14 : 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _DiscussionPill(count: comments.length);
                        }
                        if (comments.isEmpty) {
                          return _NoCommentsCard(strings: strings);
                        }
                        final comment = comments[index - 1];
                        return _TelegramCommentBubble(
                          comment: comment,
                          depth: _depthFor(comment, byId),
                          isOwnComment:
                              currentUserId != null &&
                              currentUserId == comment.userId,
                          onOpenProfile:
                              () => context.push('/profile/${comment.userId}'),
                          onReply:
                              () => setState(() {
                                _replyingTo = comment;
                                _editingComment = null;
                              }),
                          onEdit:
                              () => setState(() {
                                _editingComment = comment;
                                _replyingTo = null;
                                _controller.text = comment.content;
                                _controller.selection = TextSelection.collapsed(
                                  offset: _controller.text.length,
                                );
                              }),
                          onDelete: () => _delete(comment),
                          onOpenMentionProfile: (username) {
                            unawaited(_openMentionProfile(username));
                          },
                          onOpenUrl: (url) {
                            unawaited(_openUrl(url));
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const LoadingState(),
                error:
                    (error, _) => ErrorState(
                      message:
                          error is OfflineException
                              ? (strings.isRu
                                  ? 'Нет подключения к интернету'
                                  : 'No internet connection')
                              : (strings.isRu
                                  ? 'Ошибка загрузки комментариев'
                                  : 'Could not load comments'),
                      onRetry: _refresh,
                    ),
              ),
            ),
            _TelegramCommentComposer(
              controller: _controller,
              focusNode: _focusNode,
              isSubmitting: _isSubmitting,
              onSubmit: _submit,
              replyingTo: _replyingTo,
              editingComment: _editingComment,
              onCancelContext: _resetComposer,
              currentUsername:
                  currentProfile?.username ?? (strings.isRu ? 'Вы' : 'You'),
              currentAvatarUrl: currentProfile?.avatarUrl,
              currentAvatarScale: currentProfile?.avatarScale ?? 1,
              currentAvatarOffsetX: currentProfile?.avatarOffsetX ?? 0,
              currentAvatarOffsetY: currentProfile?.avatarOffsetY ?? 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _TelegramThreadHeader extends StatelessWidget {
  final AsyncValue<Post?> postAsync;
  final int postUserId;
  final bool isLiking;
  final ValueChanged<int> onOpenProfile;
  final VoidCallback onLike;
  final ValueChanged<String> onOpenMentionProfile;
  final ValueChanged<String> onOpenUrl;

  const _TelegramThreadHeader({
    required this.postAsync,
    required this.postUserId,
    required this.isLiking,
    required this.onOpenProfile,
    required this.onLike,
    required this.onOpenMentionProfile,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: postAsync.when(
        data:
            (post) =>
                post == null
                    ? _ThreadFallbackCard(postUserId: postUserId)
                    : _ThreadPostCard(
                      post: post,
                      isLiking: isLiking,
                      onOpenProfile: () => onOpenProfile(post.userId),
                      onLike: onLike,
                      onOpenMentionProfile: onOpenMentionProfile,
                      onOpenUrl: onOpenUrl,
                    ),
        loading: () => const _ThreadSkeletonCard(),
        error: (_, __) => _ThreadFallbackCard(postUserId: postUserId),
      ),
    );
  }
}

class _ThreadPostCard extends StatelessWidget {
  final Post post;
  final bool isLiking;
  final VoidCallback onOpenProfile;
  final VoidCallback onLike;
  final ValueChanged<String> onOpenMentionProfile;
  final ValueChanged<String> onOpenUrl;

  const _ThreadPostCard({
    required this.post,
    required this.isLiking,
    required this.onOpenProfile,
    required this.onLike,
    required this.onOpenMentionProfile,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveMediaUrl(post.imageUrl);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE3EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                username: post.username,
                imageUrl: _resolveMediaUrl(post.userAvatarUrl),
                size: 44,
                scale: post.userAvatarScale,
                offsetX: post.userAvatarOffsetX,
                offsetY: post.userAvatarOffsetY,
                onTap: onOpenProfile,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onOpenProfile,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      post.username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                DateFormat('dd MMM, HH:mm').format(post.createdAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF76849A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          if (post.content.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            InteractiveContentText(
              text: post.content.trim(),
              maxLines: imageUrl == null ? 6 : 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.45,
                color: const Color(0xFF1E293B),
              ),
              mentionStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.45,
                color: const Color(0xFF1D5FE9),
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationColor: const Color(
                  0xFF1D5FE9,
                ).withValues(alpha: 0.55),
              ),
              linkStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.45,
                color: const Color(0xFF1D5FE9),
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationColor: const Color(
                  0xFF1D5FE9,
                ).withValues(alpha: 0.55),
              ),
              onMentionTap: onOpenMentionProfile,
              onUrlTap: onOpenUrl,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _ThreadActionButton(
                icon:
                    post.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                label: '${post.likesCount}',
                color:
                    post.isLiked
                        ? const Color(0xFFE33F6C)
                        : const Color(0xFF55657E),
                isActive: post.isLiked,
                isLoading: isLiking,
                onTap: onLike,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThreadActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  const _ThreadActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFEEF4) : const Color(0xFFF4F7FC),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadSkeletonCard extends StatelessWidget {
  const _ThreadSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }
}

class _ThreadFallbackCard extends StatelessWidget {
  final int postUserId;

  const _ThreadFallbackCard({required this.postUserId});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.article_outlined, color: Color(0xFF48627F)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              strings.isRu
                  ? 'Не удалось загрузить исходный пост'
                  : 'Could not load the original post',
            ),
          ),
          TextButton(
            onPressed: () => context.push('/profile/$postUserId'),
            child: Text(strings.isRu ? 'Профиль' : 'Profile'),
          ),
        ],
      ),
    );
  }
}

class _DiscussionPill extends StatelessWidget {
  final int count;

  const _DiscussionPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDDEACB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          count == 0
              ? (strings.isRu ? 'Начало обсуждения' : 'Discussion started')
              : (strings.isRu ? 'Обсуждение · $count' : 'Discussion · $count'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF466325),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _NoCommentsCard extends StatelessWidget {
  final AppStrings strings;

  const _NoCommentsCard({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(28),
      ),
      child: EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: strings.isRu ? 'Пока нет комментариев' : 'No comments yet',
        subtitle:
            strings.isRu
                ? 'Будьте первым, кто начнёт обсуждение.'
                : 'Be the first to start the discussion.',
      ),
    );
  }
}

class _TelegramCommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final Comment? replyingTo;
  final Comment? editingComment;
  final VoidCallback onCancelContext;
  final String currentUsername;
  final String? currentAvatarUrl;
  final double currentAvatarScale;
  final double currentAvatarOffsetX;
  final double currentAvatarOffsetY;

  const _TelegramCommentComposer({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onSubmit,
    required this.replyingTo,
    required this.editingComment,
    required this.onCancelContext,
    required this.currentUsername,
    required this.currentAvatarUrl,
    required this.currentAvatarScale,
    required this.currentAvatarOffsetX,
    required this.currentAvatarOffsetY,
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
                    imageUrl: _resolveMediaUrl(currentAvatarUrl),
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

class _TelegramCommentBubble extends StatelessWidget {
  final Comment comment;
  final int depth;
  final bool isOwnComment;
  final VoidCallback onOpenProfile;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onOpenMentionProfile;
  final ValueChanged<String> onOpenUrl;

  const _TelegramCommentBubble({
    required this.comment,
    required this.depth,
    required this.isOwnComment,
    required this.onOpenProfile,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenMentionProfile,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0),
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
                imageUrl: _resolveMediaUrl(comment.userAvatarUrl),
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
                                child: Text(
                                  comment.username,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat(
                                  'dd MMM, HH:mm',
                                ).format(comment.createdAt.toLocal()),
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
                                (_) => [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text(
                                      strings.isRu ? 'Редактировать' : 'Edit',
                                    ),
                                  ),
                                  PopupMenuItem<String>(
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
                    InteractiveContentText(
                      text: comment.content,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.4),
                      mentionStyle: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(
                        height: 1.4,
                        color: const Color(0xFF1D5FE9),
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(
                          0xFF1D5FE9,
                        ).withValues(alpha: 0.55),
                      ),
                      linkStyle: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(
                        height: 1.4,
                        color: const Color(0xFF1D5FE9),
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(
                          0xFF1D5FE9,
                        ).withValues(alpha: 0.55),
                      ),
                      onMentionTap: onOpenMentionProfile,
                      onUrlTap: onOpenUrl,
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

String? _resolveMediaUrl(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  final origin = ApiConstants.baseUrl.replaceFirst('/api', '');
  return trimmed.startsWith('/') ? '$origin$trimmed' : '$origin/$trimmed';
}

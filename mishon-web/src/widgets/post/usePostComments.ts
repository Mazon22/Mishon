import { useCallback, useEffect, useMemo, useState } from 'react';

import { useLiveSync } from '../../app/providers/useLiveSync';
import { api } from '../../shared/api/api';
import type { Comment, CommentSort } from '../../shared/types/api';

type UsePostCommentsOptions = {
  mode?: 'inline' | 'detail';
  autoOpen?: boolean;
};

function patchComment(items: Comment[], commentId: number, updater: (comment: Comment) => Comment): Comment[] {
  return items.map((item) => {
    if (item.id === commentId) {
      return updater(item);
    }

    if (Array.isArray(item.previewReplies) && item.previewReplies.length) {
      return {
        ...item,
        previewReplies: patchComment(item.previewReplies, commentId, updater),
      };
    }

    return item;
  });
}

function toggleCommentLikeLocally(comment: Comment) {
  return {
    ...comment,
    isLiked: !comment.isLiked,
    likesCount: comment.likesCount + (comment.isLiked ? -1 : 1),
  };
}

export function usePostComments(postId: number, options: UsePostCommentsOptions = {}) {
  const { subscribe } = useLiveSync();
  const mode = options.mode ?? 'inline';
  const pageSize = mode === 'detail' ? 20 : 2;

  const [comments, setComments] = useState<Comment[]>([]);
  const [commentsOpen, setCommentsOpen] = useState(options.autoOpen ?? mode === 'detail');
  const [commentDraft, setCommentDraft] = useState('');
  const [commentBusy, setCommentBusy] = useState(false);
  const [commentsBusy, setCommentsBusy] = useState(false);
  const [commentsError, setCommentsError] = useState<string | null>(null);
  const [editingCommentId, setEditingCommentId] = useState<number | null>(null);
  const [replyTargetId, setReplyTargetId] = useState<number | null>(null);
  const [sort, setSort] = useState<CommentSort>(mode === 'detail' ? 'top' : 'latest');
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [expandedReplyIds, setExpandedReplyIds] = useState<Record<number, boolean>>({});
  const [repliesByParent, setRepliesByParent] = useState<Record<number, Comment[]>>({});
  const [loadingReplies, setLoadingReplies] = useState<Record<number, boolean>>({});

  const replyTarget = useMemo(() => {
    const rootTarget = comments.find((item) => item.id === replyTargetId);
    if (rootTarget) {
      return rootTarget;
    }

    for (const replies of Object.values(repliesByParent)) {
      const foundReply = replies.find((item) => item.id === replyTargetId);
      if (foundReply) {
        return foundReply;
      }
    }

    for (const item of comments) {
      const foundPreviewReply = item.previewReplies?.find((reply) => reply.id === replyTargetId);
      if (foundPreviewReply) {
        return foundPreviewReply;
      }
    }

    return null;
  }, [comments, repliesByParent, replyTargetId]);

  const loadComments = useCallback(
    async (targetPage = 1, append = false, silent = false) => {
      if (!commentsOpen && mode !== 'detail') {
        return;
      }

      if (!silent) {
        setCommentsBusy(true);
      }
      setCommentsError(null);

      try {
        const response = await api.feed.comments(postId, {
          page: targetPage,
          pageSize,
          sort,
        });

        setComments((current) => {
          if (!append) {
            return response.items;
          }

          const seen = new Set(current.map((item) => item.id));
          return [...current, ...response.items.filter((item) => !seen.has(item.id))];
        });
        setPage(targetPage);
        setHasMore(Boolean(response.hasMore));
      } catch (nextError) {
        setCommentsError(nextError instanceof Error ? nextError.message : 'Не удалось загрузить комментарии.');
        if (!append) {
          setComments([]);
        }
      } finally {
        if (!silent) {
          setCommentsBusy(false);
        }
      }
    },
    [commentsOpen, mode, pageSize, postId, sort],
  );

  const reloadExpandedReplies = useCallback(async () => {
    const expandedParents = Object.entries(expandedReplyIds)
      .filter(([, isExpanded]) => isExpanded)
      .map(([id]) => Number(id));

    await Promise.all(
      expandedParents.map(async (parentCommentId) => {
        const response = await api.feed.comments(postId, {
          parentCommentId,
          page: 1,
          pageSize: 100,
        });
        setRepliesByParent((current) => ({ ...current, [parentCommentId]: response.items }));
      }),
    );
  }, [expandedReplyIds, postId]);

  useEffect(() => {
    if (!commentsOpen && mode !== 'detail') {
      return;
    }

    void loadComments(1);
  }, [commentsOpen, loadComments, mode, sort]);

  useEffect(() => {
    if (!commentsOpen) {
      return undefined;
    }

    return subscribe((event) => {
      const payload = event.data as { postId?: number } | undefined;
      const eventPostId = Number(payload?.postId ?? 0);

      if (
        event.type === 'sync.resync' ||
        (event.type.startsWith('comment.') && (!eventPostId || eventPostId === postId))
      ) {
        void loadComments(1, false, true);
        void reloadExpandedReplies().catch(() => undefined);
      }
    });
  }, [commentsOpen, loadComments, postId, reloadExpandedReplies, subscribe]);

  async function submitComment() {
    const trimmed = commentDraft.trim();
    if (!trimmed || commentBusy) {
      return;
    }

    setCommentBusy(true);
    setCommentsError(null);

    try {
      if (editingCommentId) {
        await api.feed.updateComment(postId, editingCommentId, trimmed);
        setEditingCommentId(null);
      } else {
        const parentCommentId = replyTarget ? (replyTarget.parentCommentId ?? replyTarget.id) : undefined;
        await api.feed.createComment(postId, trimmed, parentCommentId);
        setReplyTargetId(null);
      }

      setCommentDraft('');
      setCommentsOpen(true);
      await loadComments(1);
      await reloadExpandedReplies();
    } catch (nextError) {
      setCommentsError(nextError instanceof Error ? nextError.message : 'Не удалось отправить комментарий.');
    } finally {
      setCommentBusy(false);
    }
  }

  async function deleteComment(commentId: number) {
    await api.feed.deleteComment(postId, commentId);
    if (editingCommentId === commentId) {
      setEditingCommentId(null);
      setCommentDraft('');
    }
    if (replyTargetId === commentId) {
      setReplyTargetId(null);
    }
    await loadComments(1);
    await reloadExpandedReplies();
  }

  async function loadMoreComments() {
    if (!hasMore || commentsBusy) {
      return;
    }
    await loadComments(page + 1, true);
  }

  async function toggleReplies(comment: Comment) {
    const parentCommentId = comment.id;
    const isExpanded = Boolean(expandedReplyIds[parentCommentId]);
    if (isExpanded) {
      setExpandedReplyIds((current) => ({ ...current, [parentCommentId]: false }));
      return;
    }

    setExpandedReplyIds((current) => ({ ...current, [parentCommentId]: true }));
    if (repliesByParent[parentCommentId]?.length) {
      return;
    }

    setLoadingReplies((current) => ({ ...current, [parentCommentId]: true }));
    try {
      const response = await api.feed.comments(postId, {
        parentCommentId,
        page: 1,
        pageSize: 100,
      });
      setRepliesByParent((current) => ({ ...current, [parentCommentId]: response.items }));
    } finally {
      setLoadingReplies((current) => ({ ...current, [parentCommentId]: false }));
    }
  }

  async function toggleCommentLike(comment: Comment) {
    const previousComments = comments;
    const previousReplies = repliesByParent;

    setComments((current) => patchComment(current, comment.id, toggleCommentLikeLocally));
    setRepliesByParent((current) => {
      const nextEntries = Object.entries(current).map(([parentId, items]) => [parentId, patchComment(items, comment.id, toggleCommentLikeLocally)] as const);
      return Object.fromEntries(nextEntries);
    });

    try {
      const updated = await api.feed.toggleCommentLike(postId, comment.id);
      setComments((current) => patchComment(current, comment.id, () => updated));
      setRepliesByParent((current) => {
        const nextEntries = Object.entries(current).map(([parentId, items]) => [parentId, patchComment(items, comment.id, () => updated)] as const);
        return Object.fromEntries(nextEntries);
      });
    } catch (nextError) {
      setComments(previousComments);
      setRepliesByParent(previousReplies);
      setCommentsError(nextError instanceof Error ? nextError.message : 'Не удалось обновить лайк комментария.');
    }
  }

  function startEdit(comment: Comment) {
    setReplyTargetId(null);
    setEditingCommentId(comment.id);
    setCommentDraft(comment.content);
    setCommentsOpen(true);
  }

  function cancelEdit() {
    setEditingCommentId(null);
    setCommentDraft('');
  }

  function startReply(comment: Comment) {
    setEditingCommentId(null);
    setReplyTargetId(comment.id);
    setCommentDraft('');
    setCommentsOpen(true);
  }

  function cancelReply() {
    setReplyTargetId(null);
    setCommentDraft('');
  }

  return {
    comments,
    commentsOpen,
    commentsBusy,
    commentsError,
    commentDraft,
    commentBusy,
    editingCommentId,
    replyTarget,
    sort,
    hasMore,
    repliesByParent,
    expandedReplyIds,
    loadingReplies,
    setCommentDraft,
    setCommentsOpen,
    setSort,
    submitComment,
    deleteComment,
    toggleCommentLike,
    loadMoreComments,
    toggleReplies,
    startEdit,
    cancelEdit,
    startReply,
    cancelReply,
    reloadComments: () => loadComments(1),
  };
}

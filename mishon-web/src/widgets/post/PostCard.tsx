import { useEffect, useState, type KeyboardEvent } from 'react';
import { useNavigate } from 'react-router-dom';

import type { Post } from '../../shared/types/api';
import { UserAvatar } from '../../shared/ui/UserAvatar';
import { CommentThread } from './CommentThread';
import { PostActions } from './PostActions';
import { PostBody } from './PostBody';
import { PostHeader } from './PostHeader';
import { PostMedia } from './PostMedia';
import { usePostComments } from './usePostComments';

type PostCardProps = {
  post: Post;
  currentUserId: number;
  canDelete?: boolean;
  view?: 'feed' | 'detail';
  onLike: (post: Post) => Promise<void>;
  onBookmark: (post: Post) => Promise<void>;
  onUpdate?: (postId: number, payload: { content: string; imageUrl?: string }) => Promise<Post>;
  onDelete?: (postId: number) => Promise<void>;
};

const POST_LIMIT = 1000;

export function PostCard({
  post,
  currentUserId,
  canDelete,
  view = 'feed',
  onLike,
  onBookmark,
  onUpdate,
  onDelete,
}: PostCardProps) {
  const navigate = useNavigate();
  const {
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
  } = usePostComments(post.id, { autoOpen: view === 'detail', mode: view === 'detail' ? 'detail' : 'inline' });
  const [isEditingPost, setIsEditingPost] = useState(false);
  const [postDraft, setPostDraft] = useState(post.content);
  const [postImageDraft, setPostImageDraft] = useState(post.imageUrl ?? '');
  const [updateBusy, setUpdateBusy] = useState(false);

  useEffect(() => {
    setPostDraft(post.content);
    setPostImageDraft(post.imageUrl ?? '');
  }, [post.content, post.imageUrl]);

  const displayName = post.author.displayName || post.author.username;

  async function handleUpdatePost() {
    const trimmed = postDraft.trim();
    if (!trimmed || !onUpdate || updateBusy || trimmed.length > POST_LIMIT) {
      return;
    }

    setUpdateBusy(true);
    try {
      await onUpdate(post.id, {
        content: trimmed,
        imageUrl: postImageDraft.trim() || undefined,
      });
      setIsEditingPost(false);
    } finally {
      setUpdateBusy(false);
    }
  }

  function handleStartEdit() {
    setPostDraft(post.content);
    setPostImageDraft(post.imageUrl ?? '');
    setIsEditingPost(true);
  }

  function handleCancelEdit() {
    setPostDraft(post.content);
    setPostImageDraft(post.imageUrl ?? '');
    setIsEditingPost(false);
  }

  function openThread() {
    if (view === 'detail') {
      return;
    }
    navigate(`/posts/${post.id}`);
  }

  function handleThreadKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      openThread();
    }
  }

  async function handleShare() {
    const shareUrl = `${window.location.origin}/posts/${post.id}`;

    if (navigator.share) {
      try {
        await navigator.share({
          title: displayName,
          text: post.content || 'Публикация Mishon',
          url: shareUrl,
        });
        return;
      } catch {
        // Fall back to copy.
      }
    }

    try {
      await navigator.clipboard.writeText(shareUrl);
    } catch {
      window.prompt('Ссылка на публикацию', shareUrl);
    }
  }

  return (
    <article className={`post-card${view === 'detail' ? ' post-card--detail' : ''}`} id={`post-${post.id}`}>
      <UserAvatar
        className="post-card__avatar"
        imageUrl={post.author.avatarUrl}
        name={displayName}
        offsetX={post.author.avatarOffsetX}
        offsetY={post.author.avatarOffsetY}
        scale={post.author.avatarScale}
        size="md"
      />

      <div className="post-card__main">
        <PostHeader
          canDelete={canDelete}
          onDelete={onDelete}
          onEdit={canDelete ? handleStartEdit : undefined}
          onOpenThread={view === 'feed' ? openThread : undefined}
          post={post}
        />

        <div className="post-card__body">
          {isEditingPost ? (
            <div className="post-editor">
              <textarea
                className="input input--area post-editor__textarea"
                value={postDraft}
                placeholder="Обновите текст публикации"
                rows={4}
                onChange={(event) => setPostDraft(event.target.value)}
              />
              <input
                className="input input--compact"
                value={postImageDraft}
                placeholder="Ссылка на изображение"
                onChange={(event) => setPostImageDraft(event.target.value)}
              />
              <div className="post-editor__actions">
                <button className="ghost-button ghost-button--sm" type="button" onClick={handleCancelEdit}>
                  Отмена
                </button>
                <button
                  className="primary-button primary-button--sm"
                  disabled={updateBusy || !postDraft.trim() || postDraft.length > POST_LIMIT}
                  type="button"
                  onClick={() => void handleUpdatePost()}
                >
                  {updateBusy ? 'Сохраняем...' : 'Сохранить'}
                </button>
              </div>
            </div>
          ) : (
            <>
              {view === 'feed' ? (
                <div className="post-card__thread-link" role="button" tabIndex={0} onClick={openThread} onKeyDown={handleThreadKeyDown}>
                  <PostBody content={post.content} />
                </div>
              ) : (
                <PostBody content={post.content} />
              )}

              <PostMedia
                post={post}
                onBookmark={() => onBookmark(post)}
                onLike={() => onLike(post)}
                onOpenThread={openThread}
                onShare={handleShare}
              />

              <PostActions
                commentsActive={commentsOpen || view === 'detail'}
                commentsCount={post.commentsCount}
                isBookmarked={post.isBookmarked}
                isLiked={post.isLiked}
                likesCount={post.likesCount}
                onBookmark={() => onBookmark(post)}
                onCommentClick={() => {
                  if (view === 'detail') {
                    return;
                  }
                  setCommentsOpen((current) => !current);
                }}
                onLike={() => onLike(post)}
                onShare={handleShare}
              />
            </>
          )}
        </div>

        {(commentsOpen || view === 'detail') && !isEditingPost ? (
          <CommentThread
            busy={commentBusy}
            comments={comments}
            currentUserId={currentUserId}
            draft={commentDraft}
            editingCommentId={editingCommentId}
            error={commentsError}
            expandedReplyIds={expandedReplyIds}
            hasMore={hasMore}
            loading={commentsBusy}
            loadingReplies={loadingReplies}
            mode={view === 'detail' ? 'detail' : 'inline'}
            post={post}
            repliesByParent={repliesByParent}
            replyTarget={replyTarget}
            sort={sort}
            onCancelEdit={cancelEdit}
            onCancelReply={cancelReply}
            onDelete={deleteComment}
            onDraftChange={setCommentDraft}
            onEdit={startEdit}
            onLoadMore={loadMoreComments}
            onOpenDetail={view === 'feed' ? openThread : undefined}
            onReply={startReply}
            onSortChange={setSort}
            onSubmit={submitComment}
            onToggleLike={toggleCommentLike}
            onToggleReplies={toggleReplies}
          />
        ) : null}
      </div>
    </article>
  );
}

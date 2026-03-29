import { useEffect, useState } from 'react';

import { api } from '../../shared/api/api';
import { formatRelativeDate, initials } from '../../shared/lib/format';
import type { Comment, Post } from '../../shared/types/api';

type PostCardProps = {
  post: Post;
  canDelete?: boolean;
  onLike: (post: Post) => Promise<void>;
  onDelete?: (postId: number) => Promise<void>;
};

export function PostCard({ post, canDelete, onLike, onDelete }: PostCardProps) {
  const [comments, setComments] = useState<Comment[]>([]);
  const [commentsOpen, setCommentsOpen] = useState(false);
  const [commentDraft, setCommentDraft] = useState('');
  const [commentBusy, setCommentBusy] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function loadComments() {
      if (!commentsOpen) {
        return;
      }

      try {
        const items = await api.feed.comments(post.id);
        if (!cancelled) {
          setComments(items);
        }
      } catch {
        if (!cancelled) {
          setComments([]);
        }
      }
    }

    void loadComments();

    return () => {
      cancelled = true;
    };
  }, [commentsOpen, post.id]);

  async function submitComment() {
    if (!commentDraft.trim()) {
      return;
    }
    setCommentBusy(true);
    try {
      const nextComments = await api.feed.createComment(post.id, commentDraft.trim());
      setComments(nextComments);
      setCommentDraft('');
      setCommentsOpen(true);
    } finally {
      setCommentBusy(false);
    }
  }

  return (
    <article className="post-card">
      <header className="post-card__header">
        <div className="author-row">
          <div className="avatar">
            {post.author.avatarUrl ? (
              <img alt={post.author.username} className="avatar__image" src={post.author.avatarUrl} />
            ) : (
              initials(post.author.displayName || post.author.username)
            )}
          </div>
          <div>
            <div className="author-row__title">{post.author.displayName || post.author.username}</div>
            <div className="author-row__meta">
              @{post.author.username} • {formatRelativeDate(post.createdAt)}
            </div>
          </div>
        </div>
        {canDelete && onDelete ? (
          <button className="text-button" type="button" onClick={() => void onDelete(post.id)}>
            Удалить
          </button>
        ) : null}
      </header>

      <div className="post-card__content">{post.content}</div>

      {post.imageUrl ? (
        <div className="post-card__media">
          <img alt={post.content.slice(0, 40)} src={post.imageUrl} />
        </div>
      ) : null}

      <footer className="post-card__footer">
        <button className={`ghost-button${post.isLiked ? ' ghost-button--liked' : ''}`} type="button" onClick={() => void onLike(post)}>
          {post.isLiked ? 'Убрать лайк' : 'Лайк'} • {post.likesCount}
        </button>
        <button className="ghost-button" type="button" onClick={() => setCommentsOpen((current) => !current)}>
          Комментарии • {post.commentsCount}
        </button>
      </footer>

      {commentsOpen ? (
        <div className="comments-panel">
          <div className="comments-panel__composer">
            <input
              className="input"
              value={commentDraft}
              placeholder="Ответить на пост"
              onChange={(event) => setCommentDraft(event.target.value)}
              onKeyDown={(event) => {
                if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
                  event.preventDefault();
                  void submitComment();
                }
              }}
            />
            <button className="primary-button" disabled={commentBusy} type="button" onClick={() => void submitComment()}>
              {commentBusy ? '...' : 'Ответить'}
            </button>
          </div>

          <div className="stack-list">
            {comments.length === 0 ? (
              <div className="empty-card">Пока нет комментариев. Станьте первым, кто поддержит обсуждение.</div>
            ) : (
              comments.map((comment) => (
                <div key={comment.id} className="comment-card">
                  <div className="comment-card__title">
                    {comment.author.displayName || comment.author.username}
                    <span>{formatRelativeDate(comment.createdAt)}</span>
                  </div>
                  <div className="comment-card__text">{comment.content}</div>
                </div>
              ))
            )}
          </div>
        </div>
      ) : null}
    </article>
  );
}

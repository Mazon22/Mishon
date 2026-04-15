import { AppIcon } from '../../shared/ui/AppIcon';

type PostActionsProps = {
  isLiked: boolean;
  isBookmarked: boolean;
  likesCount: number;
  commentsCount: number;
  commentsActive?: boolean;
  onLike: () => void | Promise<void>;
  onCommentClick: () => void;
  onBookmark: () => void | Promise<void>;
  onShare: () => void | Promise<void>;
};

export function PostActions({
  isLiked,
  isBookmarked,
  likesCount,
  commentsCount,
  commentsActive = false,
  onLike,
  onCommentClick,
  onBookmark,
  onShare,
}: PostActionsProps) {
  return (
    <footer className="post-actions">
      <button
        aria-label="Открыть обсуждение"
        className={`post-action${commentsActive ? ' post-action--active' : ''}`}
        type="button"
        onClick={onCommentClick}
      >
        <span className="post-action__icon">
          <AppIcon className="app-icon" name="comment" />
        </span>
        <span className="post-action__count">{commentsCount}</span>
      </button>

      <button
        aria-label={isLiked ? 'Убрать лайк' : 'Поставить лайк'}
        className={`post-action${isLiked ? ' post-action--liked' : ''}`}
        type="button"
        onClick={() => void onLike()}
      >
        <span className="post-action__icon">
          <AppIcon className="app-icon" filled={isLiked} name="heart" />
        </span>
        <span className="post-action__count">{likesCount}</span>
      </button>

      <button
        aria-label={isBookmarked ? 'Убрать из закладок' : 'Сохранить в закладки'}
        className={`post-action${isBookmarked ? ' post-action--active' : ''}`}
        type="button"
        onClick={() => void onBookmark()}
      >
        <span className="post-action__icon">
          <AppIcon className="app-icon" filled={isBookmarked} name="bookmark" />
        </span>
        <span className="post-action__label">{isBookmarked ? 'В закладках' : 'Закладка'}</span>
      </button>

      <button aria-label="Поделиться публикацией" className="post-action post-action--share" type="button" onClick={() => void onShare()}>
        <span className="post-action__icon">
          <AppIcon className="app-icon" name="share" />
        </span>
        <span className="post-action__label">Поделиться</span>
      </button>
    </footer>
  );
}

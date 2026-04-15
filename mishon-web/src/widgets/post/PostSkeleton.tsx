export function PostSkeleton() {
  return (
    <article className="post-card post-card--skeleton" aria-hidden="true">
      <div className="skeleton skeleton--avatar post-card__avatar" />

      <div className="post-card__main">
        <div className="post-card__header">
          <div className="author-row__content">
            <div className="skeleton skeleton--line skeleton--line-sm" />
          </div>
        </div>

        <div className="post-card__body">
          <div className="skeleton skeleton--line" />
          <div className="skeleton skeleton--line" />
          <div className="skeleton skeleton--line skeleton--line-md" />
          <div className="skeleton skeleton--media" />
          <div className="post-actions">
            <div className="skeleton skeleton--action" />
            <div className="skeleton skeleton--action" />
            <div className="skeleton skeleton--action skeleton--action-lg" />
          </div>
        </div>
      </div>
    </article>
  );
}

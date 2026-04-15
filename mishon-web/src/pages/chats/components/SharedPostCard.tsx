import type { SharedPostPayload } from '../../../shared/lib/chatContent';
import { UserAvatar } from '../../../shared/ui/UserAvatar';

export function SharedPostCard({ payload }: { payload: SharedPostPayload }) {
  return (
    <div className="shared-post">
      <div className="shared-post__header">
        <UserAvatar
          imageUrl={payload.userAvatarUrl}
          name={payload.username}
          offsetX={payload.userAvatarOffsetX ?? 0}
          offsetY={payload.userAvatarOffsetY ?? 0}
          scale={payload.userAvatarScale ?? 1}
          size="mini"
        />
        <div>
          <div className="shared-post__label">Поделился постом</div>
          <div className="shared-post__author">@{payload.username}</div>
        </div>
      </div>

      {payload.contentPreview ? <div className="shared-post__content">{payload.contentPreview}</div> : null}

      {payload.imageUrl ? (
        <div className="shared-post__image">
          <img alt={`Пост пользователя @${payload.username}`} src={payload.imageUrl} />
        </div>
      ) : null}
    </div>
  );
}

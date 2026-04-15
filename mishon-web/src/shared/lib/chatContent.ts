import { resolveMediaUrl } from './media';

export type SharedPostPayload = {
  postId: number;
  userId: number;
  username: string;
  userAvatarUrl?: string | null;
  userAvatarScale?: number;
  userAvatarOffsetX?: number;
  userAvatarOffsetY?: number;
  contentPreview: string;
  imageUrl?: string | null;
  createdAt?: string | null;
};

const SHARED_POST_PREFIX = '__mishon_shared_post__:';

function normalizeText(value?: string | null) {
  return value?.trim().replace(/\s+/g, ' ') ?? '';
}

function asNumber(value: unknown, fallback = 0) {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

export function parseSharedPostMessage(rawContent?: string | null): SharedPostPayload | null {
  const trimmed = rawContent?.trim();
  if (!trimmed || !trimmed.startsWith(SHARED_POST_PREFIX)) {
    return null;
  }

  try {
    const decoded = JSON.parse(trimmed.slice(SHARED_POST_PREFIX.length)) as Record<string, unknown>;
    if (decoded.type !== 'post') {
      return null;
    }

    return {
      postId: asNumber(decoded.postId),
      userId: asNumber(decoded.userId),
      username: typeof decoded.username === 'string' && decoded.username.trim() ? decoded.username : 'mishon',
      userAvatarUrl: resolveMediaUrl(typeof decoded.userAvatarUrl === 'string' ? decoded.userAvatarUrl : null),
      userAvatarScale: asNumber(decoded.userAvatarScale, 1),
      userAvatarOffsetX: asNumber(decoded.userAvatarOffsetX),
      userAvatarOffsetY: asNumber(decoded.userAvatarOffsetY),
      contentPreview: typeof decoded.contentPreview === 'string' ? decoded.contentPreview.trim() : '',
      imageUrl: resolveMediaUrl(typeof decoded.imageUrl === 'string' ? decoded.imageUrl : null),
      createdAt: typeof decoded.createdAt === 'string' ? decoded.createdAt : null,
    };
  } catch {
    return null;
  }
}

export function getConversationPreview(rawContent?: string | null) {
  const sharedPost = parseSharedPostMessage(rawContent);
  if (sharedPost) {
    return `Пост от @${sharedPost.username}`;
  }

  const normalized = normalizeText(rawContent);
  return normalized || 'Вложение';
}

export function getMessageText(rawContent?: string | null) {
  const sharedPost = parseSharedPostMessage(rawContent);
  if (sharedPost) {
    return `Пост от @${sharedPost.username}`;
  }

  return normalizeText(rawContent);
}

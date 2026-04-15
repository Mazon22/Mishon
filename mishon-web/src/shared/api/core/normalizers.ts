import { resolveMediaUrl } from '../../lib/media';
import type {
  AdminModerationAction,
  AdminUserDetail,
  AdminUserSummary,
  ChatAttachment,
  Comment,
  Conversation,
  FriendCard,
  FriendRequestsPayload,
  Message,
  NotificationItem,
  Post,
  Profile,
  SupportMessage,
  SupportThread,
  SupportThreadDetail,
  SupportThreadStatus,
  SupportThreadUser,
  UserPreview,
} from '../../types/api';

export function extractItems<T>(payload: { items: T[] }) {
  return payload.items;
}

function resolveVerifiedFlag(payload: Record<string, unknown>) {
  if (typeof payload.isVerified === 'boolean') {
    return payload.isVerified;
  }

  if (typeof payload.verified === 'boolean') {
    return payload.verified;
  }

  if (typeof payload.emailVerified === 'boolean') {
    return payload.emailVerified;
  }

  return false;
}

function normalizeSupportStatus(value: unknown): SupportThreadStatus {
  switch (value) {
    case 'WaitingForUser':
      return 'WaitingForUser';
    case 'Closed':
      return 'Closed';
    default:
      return 'WaitingForAdmin';
  }
}

export function normalizeUserPreview(preview: UserPreview): UserPreview {
  const payload = preview as UserPreview & Record<string, unknown>;

  return {
    ...preview,
    isVerified: resolveVerifiedFlag(payload),
    avatarUrl: resolveMediaUrl(preview.avatarUrl),
  };
}

export function normalizeProfile(profile: Profile): Profile {
  const payload = profile as Profile & Record<string, unknown>;

  return {
    ...profile,
    isVerified: resolveVerifiedFlag(payload),
    avatarUrl: resolveMediaUrl(profile.avatarUrl),
    bannerUrl: resolveMediaUrl(profile.bannerUrl),
  };
}

export function normalizeMobileProfile(payload: Record<string, unknown>): Profile {
  return normalizeProfile({
    id: Number(payload.id ?? 0),
    username: typeof payload.username === 'string' ? payload.username : 'mishon',
    email: typeof payload.email === 'string' ? payload.email : '',
    displayName: typeof payload.displayName === 'string' ? payload.displayName : null,
    isVerified: resolveVerifiedFlag(payload),
    aboutMe: typeof payload.aboutMe === 'string' ? payload.aboutMe : null,
    avatarUrl: typeof payload.avatarUrl === 'string' ? payload.avatarUrl : null,
    bannerUrl: typeof payload.bannerUrl === 'string' ? payload.bannerUrl : null,
    avatarScale: Number(payload.avatarScale ?? 1),
    avatarOffsetX: Number(payload.avatarOffsetX ?? 0),
    avatarOffsetY: Number(payload.avatarOffsetY ?? 0),
    bannerScale: Number(payload.bannerScale ?? 1),
    bannerOffsetX: Number(payload.bannerOffsetX ?? 0),
    bannerOffsetY: Number(payload.bannerOffsetY ?? 0),
    createdAt: typeof payload.createdAt === 'string' ? payload.createdAt : new Date(0).toISOString(),
    lastSeenAt: typeof payload.lastSeenAt === 'string' ? payload.lastSeenAt : new Date(0).toISOString(),
    isOnline: Boolean(payload.isOnline),
    followersCount: Number(payload.followersCount ?? 0),
    followingCount: Number(payload.followingCount ?? 0),
    postsCount: Number(payload.postsCount ?? 0),
    isFollowing: Boolean(payload.isFollowing),
    isFriend: Boolean(payload.isFriend),
    hasPendingFollowRequest: Boolean(payload.hasPendingFollowRequest),
    emailVerified: Boolean(payload.emailVerified),
    role: typeof payload.role === 'string' ? payload.role : 'User',
    isPrivateAccount: Boolean(payload.isPrivateAccount),
    profileVisibility: typeof payload.profileVisibility === 'string' ? payload.profileVisibility : 'Public',
    messagePrivacy: typeof payload.messagePrivacy === 'string' ? payload.messagePrivacy : 'Friends',
    commentPrivacy: typeof payload.commentPrivacy === 'string' ? payload.commentPrivacy : 'Everyone',
    presenceVisibility: typeof payload.presenceVisibility === 'string' ? payload.presenceVisibility : 'Everyone',
    isBlockedByViewer: Boolean(payload.isBlockedByViewer),
    hasBlockedViewer: Boolean(payload.hasBlockedViewer),
    canViewProfile: payload.canViewProfile !== false,
    canViewPosts: payload.canViewPosts !== false,
    canSendMessages: payload.canSendMessages !== false,
    canComment: payload.canComment !== false,
  });
}

export function normalizePost(post: Post): Post {
  return {
    ...post,
    author: normalizeUserPreview(post.author),
    imageUrl: resolveMediaUrl(post.imageUrl),
    isBookmarked: Boolean(post.isBookmarked),
  };
}

export function normalizeComment(comment: Comment): Comment {
  return {
    ...comment,
    author: normalizeUserPreview(comment.author),
    likesCount: Number(comment.likesCount ?? 0),
    isLiked: Boolean(comment.isLiked),
    repliesCount: Number(comment.repliesCount ?? 0),
    previewReplies: Array.isArray(comment.previewReplies) ? comment.previewReplies.map((item) => normalizeComment(item)) : undefined,
  };
}

export function normalizeMobilePost(payload: Record<string, unknown>): Post {
  return normalizePost({
    id: Number(payload.id ?? 0),
    userId: Number(payload.userId ?? 0),
    author: {
      id: Number(payload.userId ?? 0),
      username: typeof payload.username === 'string' ? payload.username : 'mishon',
      displayName: typeof payload.username === 'string' ? payload.username : 'mishon',
      isVerified: resolveVerifiedFlag(payload),
      avatarUrl: typeof payload.userAvatarUrl === 'string' ? payload.userAvatarUrl : null,
      avatarScale: Number(payload.userAvatarScale ?? 1),
      avatarOffsetX: Number(payload.userAvatarOffsetX ?? 0),
      avatarOffsetY: Number(payload.userAvatarOffsetY ?? 0),
      lastSeenAt: null,
      isOnline: false,
    },
    content: typeof payload.content === 'string' ? payload.content : '',
    imageUrl: typeof payload.imageUrl === 'string' ? payload.imageUrl : null,
    createdAt: typeof payload.createdAt === 'string' ? payload.createdAt : new Date().toISOString(),
    likesCount: Number(payload.likesCount ?? 0),
    commentsCount: Number(payload.commentsCount ?? 0),
    isLiked: Boolean(payload.isLiked),
    isBookmarked: Boolean(payload.isBookmarked),
    isFollowingAuthor: Boolean(payload.isFollowingAuthor),
  });
}

export function normalizeMobileComment(payload: Record<string, unknown>, postId?: number): Comment {
  const resolvedPostId = Number(payload.postId ?? postId ?? 0);
  return normalizeComment({
    id: Number(payload.id ?? 0),
    postId: resolvedPostId,
    userId: Number(payload.userId ?? 0),
    author: {
      id: Number(payload.userId ?? 0),
      username: typeof payload.username === 'string' ? payload.username : 'mishon',
      displayName: typeof payload.username === 'string' ? payload.username : 'mishon',
      isVerified: resolveVerifiedFlag(payload),
      avatarUrl: typeof payload.userAvatarUrl === 'string' ? payload.userAvatarUrl : null,
      avatarScale: Number(payload.userAvatarScale ?? 1),
      avatarOffsetX: Number(payload.userAvatarOffsetX ?? 0),
      avatarOffsetY: Number(payload.userAvatarOffsetY ?? 0),
      lastSeenAt: null,
      isOnline: false,
    },
    content: typeof payload.content === 'string' ? payload.content : '',
    createdAt: typeof payload.createdAt === 'string' ? payload.createdAt : new Date().toISOString(),
    editedAt: typeof payload.editedAt === 'string' ? payload.editedAt : null,
    parentCommentId: typeof payload.parentCommentId === 'number' ? payload.parentCommentId : null,
    replyToUsername: typeof payload.replyToUsername === 'string' ? payload.replyToUsername : null,
    likesCount: Number(payload.likesCount ?? 0),
    isLiked: Boolean(payload.isLiked),
    repliesCount: Number(payload.repliesCount ?? 0),
    previewReplies: Array.isArray(payload.previewReplies)
      ? payload.previewReplies.map((item) => normalizeMobileComment(asRecord(item), resolvedPostId))
      : undefined,
  });
}

export function normalizeFriendCard(item: FriendCard): FriendCard {
  return {
    ...item,
    avatarUrl: resolveMediaUrl(item.avatarUrl),
  };
}

export function normalizeFriendRequestPayload(payload: FriendRequestsPayload): FriendRequestsPayload {
  return {
    incoming: payload.incoming.map((item) => ({
      ...item,
      user: normalizeUserPreview(item.user),
    })),
    outgoing: payload.outgoing.map((item) => ({
      ...item,
      user: normalizeUserPreview(item.user),
    })),
  };
}

export function normalizeNotification(item: NotificationItem): NotificationItem {
  return {
    ...item,
    actor: item.actor ? normalizeUserPreview(item.actor) : item.actor,
  };
}

export function asRecord(value: unknown) {
  return value as Record<string, unknown>;
}

export function normalizeAttachment(payload: Record<string, unknown>): ChatAttachment {
  return {
    id: Number(payload.id ?? 0),
    fileName: typeof payload.fileName === 'string' ? payload.fileName : 'file',
    fileUrl: resolveMediaUrl(typeof payload.fileUrl === 'string' ? payload.fileUrl : null) ?? '',
    contentType: typeof payload.contentType === 'string' ? payload.contentType : 'application/octet-stream',
    sizeBytes: Number(payload.sizeBytes ?? 0),
    isImage: Boolean(payload.isImage),
  };
}

export function normalizeConversation(payload: Record<string, unknown>): Conversation {
  return {
    id: Number(payload.id ?? 0),
    peerId: Number(payload.peerId ?? 0),
    username: typeof payload.username === 'string' ? payload.username : 'mishon',
    avatarUrl: resolveMediaUrl(typeof payload.avatarUrl === 'string' ? payload.avatarUrl : null),
    avatarScale: Number(payload.avatarScale ?? 1),
    avatarOffsetX: Number(payload.avatarOffsetX ?? 0),
    avatarOffsetY: Number(payload.avatarOffsetY ?? 0),
    lastSeenAt: typeof payload.lastSeenAt === 'string' ? payload.lastSeenAt : new Date(0).toISOString(),
    isOnline: Boolean(payload.isOnline),
    pinOrder: typeof payload.pinOrder === 'number' ? payload.pinOrder : null,
    isPinned: Boolean(payload.isPinned),
    isArchived: Boolean(payload.isArchived),
    isFavorite: Boolean(payload.isFavorite),
    isMuted: Boolean(payload.isMuted),
    isBlockedByViewer: Boolean(payload.isBlockedByViewer),
    hasBlockedViewer: Boolean(payload.hasBlockedViewer),
    lastMessage: typeof payload.lastMessage === 'string' ? payload.lastMessage : null,
    lastMessageAt: typeof payload.lastMessageAt === 'string' ? payload.lastMessageAt : null,
    lastMessageIsMine: Boolean(payload.lastMessageIsMine),
    lastMessageIsDeliveredToPeer: Boolean(payload.lastMessageIsDeliveredToPeer),
    lastMessageIsReadByPeer: Boolean(payload.lastMessageIsReadByPeer),
    unreadCount: Number(payload.unreadCount ?? 0),
    canSendMessages: payload.canSendMessages !== false,
  };
}

export function normalizeMessage(payload: Record<string, unknown>): Message {
  const attachments = Array.isArray(payload.attachments)
    ? payload.attachments.map((item) => normalizeAttachment(asRecord(item)))
    : [];

  return {
    id: Number(payload.id ?? 0),
    conversationId: Number(payload.conversationId ?? 0),
    senderId: Number(payload.senderId ?? 0),
    senderUsername: typeof payload.senderUsername === 'string' ? payload.senderUsername : 'mishon',
    content: typeof payload.content === 'string' ? payload.content : '',
    createdAt: typeof payload.createdAt === 'string' ? payload.createdAt : new Date().toISOString(),
    editedAt: typeof payload.editedAt === 'string' ? payload.editedAt : null,
    isMine: Boolean(payload.isMine),
    isDeliveredToPeer: Boolean(payload.isDeliveredToPeer),
    deliveredToPeerAt: typeof payload.deliveredToPeerAt === 'string' ? payload.deliveredToPeerAt : null,
    isReadByPeer: Boolean(payload.isReadByPeer),
    readByPeerAt: typeof payload.readByPeerAt === 'string' ? payload.readByPeerAt : null,
    replyToMessageId: typeof payload.replyToMessageId === 'number' ? payload.replyToMessageId : null,
    replyToSenderUsername:
      typeof payload.replyToSenderUsername === 'string' ? payload.replyToSenderUsername : null,
    replyToContent: typeof payload.replyToContent === 'string' ? payload.replyToContent : null,
    forwardedFromMessageId:
      typeof payload.forwardedFromMessageId === 'number' ? payload.forwardedFromMessageId : null,
    forwardedFromUserId: typeof payload.forwardedFromUserId === 'number' ? payload.forwardedFromUserId : null,
    forwardedFromSenderUsername:
      typeof payload.forwardedFromSenderUsername === 'string' ? payload.forwardedFromSenderUsername : null,
    forwardedFromUserAvatarUrl:
      resolveMediaUrl(typeof payload.forwardedFromUserAvatarUrl === 'string' ? payload.forwardedFromUserAvatarUrl : null),
    forwardedFromUserAvatarScale: Number(payload.forwardedFromUserAvatarScale ?? 1),
    forwardedFromUserAvatarOffsetX: Number(payload.forwardedFromUserAvatarOffsetX ?? 0),
    forwardedFromUserAvatarOffsetY: Number(payload.forwardedFromUserAvatarOffsetY ?? 0),
    attachments,
    isHidden: Boolean(payload.isHidden),
    isRemoved: Boolean(payload.isRemoved),
  };
}

export function normalizeSupportThreadUser(payload: Record<string, unknown>): SupportThreadUser {
  return {
    id: Number(payload.id ?? 0),
    username: typeof payload.username === 'string' ? payload.username : 'mishon',
    displayName: typeof payload.displayName === 'string' ? payload.displayName : null,
    email: typeof payload.email === 'string' ? payload.email : null,
    role: typeof payload.role === 'string' ? payload.role : 'User',
    avatarUrl: resolveMediaUrl(typeof payload.avatarUrl === 'string' ? payload.avatarUrl : null),
    avatarScale: Number(payload.avatarScale ?? 1),
    avatarOffsetX: Number(payload.avatarOffsetX ?? 0),
    avatarOffsetY: Number(payload.avatarOffsetY ?? 0),
    lastSeenAt: typeof payload.lastSeenAt === 'string' ? payload.lastSeenAt : null,
    isOnline: Boolean(payload.isOnline),
  };
}

export function normalizeSupportThread(payload: Record<string, unknown>): SupportThread {
  return {
    id: Number(payload.id ?? 0),
    userId: Number(payload.userId ?? 0),
    subject: typeof payload.subject === 'string' ? payload.subject : '',
    status: normalizeSupportStatus(payload.status),
    createdAt: typeof payload.createdAt === 'string' ? payload.createdAt : new Date().toISOString(),
    updatedAt: typeof payload.updatedAt === 'string' ? payload.updatedAt : new Date().toISOString(),
    lastMessageAt: typeof payload.lastMessageAt === 'string' ? payload.lastMessageAt : new Date().toISOString(),
    lastMessagePreview: typeof payload.lastMessagePreview === 'string' ? payload.lastMessagePreview : null,
    lastMessageAuthorUserId:
      typeof payload.lastMessageAuthorUserId === 'number' ? payload.lastMessageAuthorUserId : null,
    adminUnreadCount: Number(payload.adminUnreadCount ?? 0),
    userUnreadCount: Number(payload.userUnreadCount ?? 0),
    closedAt: typeof payload.closedAt === 'string' ? payload.closedAt : null,
    closedByUserId: typeof payload.closedByUserId === 'number' ? payload.closedByUserId : null,
    user: payload.user && typeof payload.user === 'object' ? normalizeSupportThreadUser(asRecord(payload.user)) : null,
  };
}

export function normalizeSupportMessage(payload: Record<string, unknown>): SupportMessage {
  return {
    id: Number(payload.id ?? 0),
    threadId: Number(payload.threadId ?? 0),
    authorUserId: typeof payload.authorUserId === 'number' ? payload.authorUserId : null,
    authorUsername: typeof payload.authorUsername === 'string' ? payload.authorUsername : null,
    authorDisplayName: typeof payload.authorDisplayName === 'string' ? payload.authorDisplayName : null,
    authorRole: typeof payload.authorRole === 'string' ? payload.authorRole : null,
    authorAvatarUrl: resolveMediaUrl(typeof payload.authorAvatarUrl === 'string' ? payload.authorAvatarUrl : null),
    authorAvatarScale: Number(payload.authorAvatarScale ?? 1),
    authorAvatarOffsetX: Number(payload.authorAvatarOffsetX ?? 0),
    authorAvatarOffsetY: Number(payload.authorAvatarOffsetY ?? 0),
    content: typeof payload.content === 'string' ? payload.content : '',
    createdAt: typeof payload.createdAt === 'string' ? payload.createdAt : new Date().toISOString(),
    readAt: typeof payload.readAt === 'string' ? payload.readAt : null,
    isMine: Boolean(payload.isMine),
    isAdminAuthor: Boolean(payload.isAdminAuthor),
  };
}

export function normalizeSupportThreadDetail(payload: Record<string, unknown>): SupportThreadDetail {
  return {
    thread: normalizeSupportThread(asRecord(payload.thread)),
    messages: Array.isArray(payload.messages)
      ? payload.messages.map((item) => normalizeSupportMessage(asRecord(item)))
      : [],
  };
}

export function normalizeAdminUser(payload: Record<string, unknown>): AdminUserSummary {
  return {
    id: Number(payload.id ?? 0),
    username: typeof payload.username === 'string' ? payload.username : 'mishon',
    displayName: typeof payload.displayName === 'string' ? payload.displayName : null,
    email: typeof payload.email === 'string' ? payload.email : '',
    aboutMe: typeof payload.aboutMe === 'string' ? payload.aboutMe : null,
    avatarUrl: resolveMediaUrl(typeof payload.avatarUrl === 'string' ? payload.avatarUrl : null),
    avatarScale: Number(payload.avatarScale ?? 1),
    avatarOffsetX: Number(payload.avatarOffsetX ?? 0),
    avatarOffsetY: Number(payload.avatarOffsetY ?? 0),
    bannerUrl: resolveMediaUrl(typeof payload.bannerUrl === 'string' ? payload.bannerUrl : null),
    bannerScale: Number(payload.bannerScale ?? 1),
    bannerOffsetX: Number(payload.bannerOffsetX ?? 0),
    bannerOffsetY: Number(payload.bannerOffsetY ?? 0),
    role: typeof payload.role === 'string' ? payload.role : 'User',
    isEmailVerified: Boolean(payload.isEmailVerified),
    createdAt: typeof payload.createdAt === 'string' ? payload.createdAt : new Date().toISOString(),
    lastSeenAt: typeof payload.lastSeenAt === 'string' ? payload.lastSeenAt : new Date().toISOString(),
    suspendedUntil: typeof payload.suspendedUntil === 'string' ? payload.suspendedUntil : null,
    bannedAt: typeof payload.bannedAt === 'string' ? payload.bannedAt : null,
    status: typeof payload.status === 'string' ? payload.status : 'Active',
    postsCount: Number(payload.postsCount ?? 0),
    followersCount: Number(payload.followersCount ?? 0),
    followingCount: Number(payload.followingCount ?? 0),
    activeSessionsCount: Number(payload.activeSessionsCount ?? 0),
    openSupportThreads: Number(payload.openSupportThreads ?? 0),
  };
}

export function normalizeAdminModerationAction(payload: Record<string, unknown>): AdminModerationAction {
  return {
    id: Number(payload.id ?? 0),
    actionType: typeof payload.actionType === 'string' ? payload.actionType : '',
    note: typeof payload.note === 'string' ? payload.note : null,
    createdAt: typeof payload.createdAt === 'string' ? payload.createdAt : new Date().toISOString(),
    expiresAt: typeof payload.expiresAt === 'string' ? payload.expiresAt : null,
    actorUserId: typeof payload.actorUserId === 'number' ? payload.actorUserId : null,
    actorUsername: typeof payload.actorUsername === 'string' ? payload.actorUsername : null,
  };
}

export function normalizeAdminUserDetail(payload: Record<string, unknown>): AdminUserDetail {
  return {
    user: normalizeAdminUser(asRecord(payload.user)),
    recentModerationActions: Array.isArray(payload.recentModerationActions)
      ? payload.recentModerationActions.map((item) => normalizeAdminModerationAction(asRecord(item)))
      : [],
    recentSupportThreads: Array.isArray(payload.recentSupportThreads)
      ? payload.recentSupportThreads.map((item) => normalizeSupportThread(asRecord(item)))
      : [],
  };
}

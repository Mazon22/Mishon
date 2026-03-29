export type Nullable<T> = T | null;

export interface AuthResponse {
  userId: number;
  username: string;
  email: string;
  token: string;
  accessTokenExpiresAt: string;
  refreshToken: string;
  refreshTokenExpiry: string;
  sessionId: string;
  emailVerified: boolean;
  requiresEmailVerification: boolean;
  role: string;
}

export interface UserPreview {
  id: number;
  username: string;
  displayName?: string | null;
  avatarUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
  lastSeenAt?: string | null;
  isOnline: boolean;
}

export interface Profile {
  id: number;
  username: string;
  email: string;
  displayName?: string | null;
  aboutMe?: string | null;
  avatarUrl?: string | null;
  bannerUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
  bannerScale: number;
  bannerOffsetX: number;
  bannerOffsetY: number;
  createdAt: string;
  lastSeenAt: string;
  isOnline: boolean;
  followersCount: number;
  followingCount: number;
  postsCount: number;
  isFollowing: boolean;
  isFriend: boolean;
  hasPendingFollowRequest: boolean;
  emailVerified: boolean;
  role: string;
  isPrivateAccount: boolean;
  profileVisibility: string;
  messagePrivacy: string;
  commentPrivacy: string;
  presenceVisibility: string;
}

export interface Post {
  id: number;
  userId: number;
  author: UserPreview;
  content: string;
  imageUrl?: string | null;
  createdAt: string;
  likesCount: number;
  commentsCount: number;
  isLiked: boolean;
  isFollowingAuthor: boolean;
}

export interface Comment {
  id: number;
  postId: number;
  userId: number;
  author: UserPreview;
  content: string;
  createdAt: string;
  editedAt?: string | null;
  parentCommentId?: number | null;
  replyToUsername?: string | null;
}

export interface Conversation {
  id: number;
  peer: UserPreview;
  pinOrder?: number | null;
  isPinned: boolean;
  isArchived: boolean;
  isFavorite: boolean;
  isMuted: boolean;
  lastMessage?: string | null;
  lastMessageAt?: string | null;
  lastMessageIsMine: boolean;
  lastMessageDelivered: boolean;
  lastMessageRead: boolean;
  unreadCount: number;
}

export interface Message {
  id: number;
  conversationId: number;
  sender: UserPreview;
  content: string;
  createdAt: string;
  editedAt?: string | null;
  isMine: boolean;
}

export interface FriendCard {
  id: number;
  username: string;
  displayName?: string | null;
  aboutMe?: string | null;
  avatarUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
  lastSeenAt: string;
  isOnline: boolean;
  followersCount: number;
  postsCount: number;
  isFollowing: boolean;
  isFriend: boolean;
  incomingFriendRequestId?: number | null;
  outgoingFriendRequestId?: number | null;
  hasPendingFollowRequest: boolean;
  isPrivateAccount: boolean;
  profileVisibility: string;
}

export interface FriendRequestItem {
  id: number;
  userId: number;
  user: UserPreview;
  aboutMe?: string | null;
  isIncoming: boolean;
  createdAt: string;
}

export interface FriendRequestsPayload {
  incoming: FriendRequestItem[];
  outgoing: FriendRequestItem[];
}

export interface FollowToggleResponse {
  isFollowing: boolean;
  followersCount: number;
  isRequested: boolean;
  requestId?: number | null;
}

export interface NotificationItem {
  id: number;
  type: string;
  text: string;
  isRead: boolean;
  createdAt: string;
  actor?: UserPreview | null;
  postId?: number | null;
  commentId?: number | null;
  conversationId?: number | null;
  messageId?: number | null;
  relatedUserId?: number | null;
}

export interface NotificationSummary {
  unreadNotifications: number;
  unreadChats: number;
  incomingFriendRequests: number;
  pendingFollowRequests: number;
}

export interface PagedResponse<T> {
  items: T[];
  page: number;
  pageSize: number;
  hasMore: boolean;
}

export interface ApiError {
  message: string;
}

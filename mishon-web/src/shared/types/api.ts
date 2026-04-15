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
  isVerified?: boolean;
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
  isVerified?: boolean;
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
  isBlockedByViewer?: boolean;
  hasBlockedViewer?: boolean;
  canViewProfile?: boolean;
  canViewPosts?: boolean;
  canSendMessages?: boolean;
  canComment?: boolean;
}

export interface SessionInfo {
  id: string;
  createdAt: string;
  lastUsedAt: string;
  expiresAt: string;
  revokedAt?: string | null;
  deviceName?: string | null;
  platform?: string | null;
  userAgent?: string | null;
  ipAddress?: string | null;
  isCurrent: boolean;
  isActive: boolean;
  revocationReason?: string | null;
}

export interface PrivacySettings {
  isPrivateAccount: boolean;
  profileVisibility: string;
  messagePrivacy: string;
  commentPrivacy: string;
  presenceVisibility: string;
}

export type ProfileTimelineTab = 'posts' | 'media' | 'likes';

export interface ProfileUpdateInput {
  displayName?: string | null;
  username?: string | null;
  aboutMe?: string | null;
}

export interface ProfileMediaUpdateInput {
  avatar?: File | null;
  banner?: File | null;
  avatarScale?: number;
  avatarOffsetX?: number;
  avatarOffsetY?: number;
  bannerScale?: number;
  bannerOffsetX?: number;
  bannerOffsetY?: number;
  removeAvatar?: boolean;
  removeBanner?: boolean;
}

export interface ProfilePostsQuery {
  userId?: number;
  page?: number;
  pageSize?: number;
  tab?: ProfileTimelineTab;
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
  isBookmarked: boolean;
  isFollowingAuthor: boolean;
}

export type CommentSort = 'top' | 'latest';

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
  likesCount: number;
  isLiked: boolean;
  repliesCount: number;
  previewReplies?: Comment[];
}

export interface CommentListQuery {
  sort?: CommentSort;
  page?: number;
  pageSize?: number;
  parentCommentId?: number;
}

export interface Conversation {
  id: number;
  peerId: number;
  username: string;
  avatarUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
  lastSeenAt: string;
  isOnline: boolean;
  pinOrder?: number | null;
  isPinned: boolean;
  isArchived: boolean;
  isFavorite: boolean;
  isMuted: boolean;
  isBlockedByViewer: boolean;
  hasBlockedViewer: boolean;
  lastMessage?: string | null;
  lastMessageAt?: string | null;
  lastMessageIsMine: boolean;
  lastMessageIsDeliveredToPeer: boolean;
  lastMessageIsReadByPeer: boolean;
  unreadCount: number;
  canSendMessages: boolean;
}

export interface ChatAttachment {
  id: number;
  fileName: string;
  fileUrl: string;
  contentType: string;
  sizeBytes: number;
  isImage: boolean;
}

export interface Message {
  id: number;
  conversationId: number;
  senderId: number;
  senderUsername: string;
  content: string;
  createdAt: string;
  editedAt?: string | null;
  isMine: boolean;
  isDeliveredToPeer: boolean;
  deliveredToPeerAt?: string | null;
  isReadByPeer: boolean;
  readByPeerAt?: string | null;
  replyToMessageId?: number | null;
  replyToSenderUsername?: string | null;
  replyToContent?: string | null;
  forwardedFromMessageId?: number | null;
  forwardedFromUserId?: number | null;
  forwardedFromSenderUsername?: string | null;
  forwardedFromUserAvatarUrl?: string | null;
  forwardedFromUserAvatarScale: number;
  forwardedFromUserAvatarOffsetX: number;
  forwardedFromUserAvatarOffsetY: number;
  attachments: ChatAttachment[];
  isHidden: boolean;
  isRemoved: boolean;
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

export interface FollowListEntry {
  id: number;
  username: string;
  displayName?: string | null;
  isVerified?: boolean;
  avatarUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
  isFollowing: boolean;
  isPrivateAccount: boolean;
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

export type AdminUsersFilter = 'all' | 'active' | 'frozen' | 'admins' | 'moderators';
export type SupportThreadStatus = 'WaitingForAdmin' | 'WaitingForUser' | 'Closed';

export interface SupportThreadUser {
  id: number;
  username: string;
  displayName?: string | null;
  email?: string | null;
  role: string;
  avatarUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
  lastSeenAt?: string | null;
  isOnline: boolean;
}

export interface SupportThread {
  id: number;
  userId: number;
  subject: string;
  status: SupportThreadStatus;
  createdAt: string;
  updatedAt: string;
  lastMessageAt: string;
  lastMessagePreview?: string | null;
  lastMessageAuthorUserId?: number | null;
  adminUnreadCount: number;
  userUnreadCount: number;
  closedAt?: string | null;
  closedByUserId?: number | null;
  user?: SupportThreadUser | null;
}

export interface SupportMessage {
  id: number;
  threadId: number;
  authorUserId?: number | null;
  authorUsername?: string | null;
  authorDisplayName?: string | null;
  authorRole?: string | null;
  authorAvatarUrl?: string | null;
  authorAvatarScale: number;
  authorAvatarOffsetX: number;
  authorAvatarOffsetY: number;
  content: string;
  createdAt: string;
  readAt?: string | null;
  isMine: boolean;
  isAdminAuthor: boolean;
}

export interface SupportThreadDetail {
  thread: SupportThread;
  messages: SupportMessage[];
}

export interface CreateSupportThreadInput {
  subject: string;
  message: string;
}

export interface ReplySupportThreadInput {
  message: string;
}

export interface FreezeUserInput {
  until: string;
  note: string;
}

export interface HardDeleteUserInput {
  note: string;
}

export interface AdminUserSummary {
  id: number;
  username: string;
  displayName?: string | null;
  email: string;
  aboutMe?: string | null;
  avatarUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
  bannerUrl?: string | null;
  bannerScale: number;
  bannerOffsetX: number;
  bannerOffsetY: number;
  role: string;
  isEmailVerified: boolean;
  createdAt: string;
  lastSeenAt: string;
  suspendedUntil?: string | null;
  bannedAt?: string | null;
  status: string;
  postsCount: number;
  followersCount: number;
  followingCount: number;
  activeSessionsCount: number;
  openSupportThreads: number;
}

export interface AdminModerationAction {
  id: number;
  actionType: string;
  note?: string | null;
  createdAt: string;
  expiresAt?: string | null;
  actorUserId?: number | null;
  actorUsername?: string | null;
}

export interface AdminUserDetail {
  user: AdminUserSummary;
  recentModerationActions: AdminModerationAction[];
  recentSupportThreads: SupportThread[];
}

export interface PagedResponse<T> {
  items: T[];
  page: number;
  pageSize: number;
  hasMore: boolean;
  hasPrevious?: boolean;
  hasNext?: boolean;
  totalCount?: number;
  totalPages?: number;
}

export interface ApiError {
  message: string;
}

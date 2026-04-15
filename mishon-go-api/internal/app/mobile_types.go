package app

import "time"

type mobilePagedResponse[T any] struct {
	Items       []T  `json:"items"`
	Page        int  `json:"page"`
	PageSize    int  `json:"pageSize"`
	TotalCount  int  `json:"totalCount"`
	TotalPages  int  `json:"totalPages"`
	HasPrevious bool `json:"hasPrevious"`
	HasNext     bool `json:"hasNext"`
}

type mobileProfileResponse struct {
	ID                      int       `json:"id"`
	Username                string    `json:"username"`
	Email                   string    `json:"email"`
	DisplayName             *string   `json:"displayName,omitempty"`
	AboutMe                 *string   `json:"aboutMe,omitempty"`
	AvatarURL               *string   `json:"avatarUrl,omitempty"`
	BannerURL               *string   `json:"bannerUrl,omitempty"`
	AvatarScale             float64   `json:"avatarScale"`
	AvatarOffsetX           float64   `json:"avatarOffsetX"`
	AvatarOffsetY           float64   `json:"avatarOffsetY"`
	BannerScale             float64   `json:"bannerScale"`
	BannerOffsetX           float64   `json:"bannerOffsetX"`
	BannerOffsetY           float64   `json:"bannerOffsetY"`
	CreatedAt               time.Time `json:"createdAt"`
	LastSeenAt              time.Time `json:"lastSeenAt"`
	IsOnline                bool      `json:"isOnline"`
	FollowersCount          int       `json:"followersCount"`
	FollowingCount          int       `json:"followingCount"`
	PostsCount              int       `json:"postsCount"`
	IsBlockedByViewer       bool      `json:"isBlockedByViewer"`
	HasBlockedViewer        bool      `json:"hasBlockedViewer"`
	IsFollowing             bool      `json:"isFollowing"`
	EmailVerified           bool      `json:"emailVerified"`
	Role                    string    `json:"role"`
	IsPrivateAccount        bool      `json:"isPrivateAccount"`
	ProfileVisibility       string    `json:"profileVisibility"`
	MessagePrivacy          string    `json:"messagePrivacy"`
	CommentPrivacy          string    `json:"commentPrivacy"`
	PresenceVisibility      string    `json:"presenceVisibility"`
	CanViewProfile          bool      `json:"canViewProfile"`
	CanViewPosts            bool      `json:"canViewPosts"`
	CanSendMessages         bool      `json:"canSendMessages"`
	CanComment              bool      `json:"canComment"`
	CanViewPresence         bool      `json:"canViewPresence"`
	HasPendingFollowRequest bool      `json:"hasPendingFollowRequest"`
}

type mobilePrivacyResponse struct {
	IsPrivateAccount   bool   `json:"isPrivateAccount"`
	ProfileVisibility  string `json:"profileVisibility"`
	MessagePrivacy     string `json:"messagePrivacy"`
	CommentPrivacy     string `json:"commentPrivacy"`
	PresenceVisibility string `json:"presenceVisibility"`
}

type mobilePostResponse struct {
	ID                int       `json:"id"`
	UserID            int       `json:"userId"`
	Username          string    `json:"username"`
	UserAvatarURL     *string   `json:"userAvatarUrl,omitempty"`
	UserAvatarScale   float64   `json:"userAvatarScale"`
	UserAvatarOffsetX float64   `json:"userAvatarOffsetX"`
	UserAvatarOffsetY float64   `json:"userAvatarOffsetY"`
	Content           string    `json:"content"`
	ImageURL          *string   `json:"imageUrl,omitempty"`
	CreatedAt         time.Time `json:"createdAt"`
	LikesCount        int       `json:"likesCount"`
	CommentsCount     int       `json:"commentsCount"`
	IsLiked           bool      `json:"isLiked"`
	IsBookmarked      bool      `json:"isBookmarked"`
	IsFollowingAuthor bool      `json:"isFollowingAuthor"`
	CanComment        bool      `json:"canComment"`
	IsHidden          bool      `json:"isHidden"`
	IsRemoved         bool      `json:"isRemoved"`
}

type mobileCommentResponse struct {
	ID                int        `json:"id"`
	UserID            int        `json:"userId"`
	Username          string     `json:"username"`
	UserAvatarURL     *string    `json:"userAvatarUrl,omitempty"`
	UserAvatarScale   float64    `json:"userAvatarScale"`
	UserAvatarOffsetX float64    `json:"userAvatarOffsetX"`
	UserAvatarOffsetY float64    `json:"userAvatarOffsetY"`
	Content           string     `json:"content"`
	CreatedAt         time.Time  `json:"createdAt"`
	EditedAt          *time.Time `json:"editedAt,omitempty"`
	ParentCommentID   *int       `json:"parentCommentId,omitempty"`
	ReplyToUsername   *string    `json:"replyToUsername,omitempty"`
	LikesCount        int        `json:"likesCount"`
	IsLiked           bool       `json:"isLiked"`
	RepliesCount      int        `json:"repliesCount"`
	IsHidden          bool       `json:"isHidden"`
	IsRemoved         bool       `json:"isRemoved"`
}

type mobileFollowResponse struct {
	ID               int     `json:"id"`
	Username         string  `json:"username"`
	AvatarURL        *string `json:"avatarUrl,omitempty"`
	AvatarScale      float64 `json:"avatarScale"`
	AvatarOffsetX    float64 `json:"avatarOffsetX"`
	AvatarOffsetY    float64 `json:"avatarOffsetY"`
	IsFollowing      bool    `json:"isFollowing"`
	IsPrivateAccount bool    `json:"isPrivateAccount"`
}

type mobileDiscoverUserResponse struct {
	ID                 int       `json:"id"`
	Username           string    `json:"username"`
	AboutMe            *string   `json:"aboutMe,omitempty"`
	AvatarURL          *string   `json:"avatarUrl,omitempty"`
	AvatarScale        float64   `json:"avatarScale"`
	AvatarOffsetX      float64   `json:"avatarOffsetX"`
	AvatarOffsetY      float64   `json:"avatarOffsetY"`
	LastSeenAt         time.Time `json:"lastSeenAt"`
	IsOnline           bool      `json:"isOnline"`
	FollowersCount     int       `json:"followersCount"`
	PostsCount         int       `json:"postsCount"`
	MutualFriendsCount int       `json:"mutualFriendsCount"`
	EngagementScore    int       `json:"engagementScore"`
	IsFollowing        bool      `json:"isFollowing"`
	IsFriend           bool      `json:"isFriend"`
	IncomingRequestID  *int      `json:"incomingFriendRequestId,omitempty"`
	OutgoingRequestID  *int      `json:"outgoingFriendRequestId,omitempty"`
	IsPrivateAccount   bool      `json:"isPrivateAccount"`
	ProfileVisibility  string    `json:"profileVisibility"`
	CanViewProfile     bool      `json:"canViewProfile"`
	CanSendMessages    bool      `json:"canSendMessages"`
	HasPendingFollow   bool      `json:"hasPendingFollowRequest"`
}

type mobileFriendResponse struct {
	ID            int       `json:"id"`
	Username      string    `json:"username"`
	AboutMe       *string   `json:"aboutMe,omitempty"`
	AvatarURL     *string   `json:"avatarUrl,omitempty"`
	AvatarScale   float64   `json:"avatarScale"`
	AvatarOffsetX float64   `json:"avatarOffsetX"`
	AvatarOffsetY float64   `json:"avatarOffsetY"`
	LastSeenAt    time.Time `json:"lastSeenAt"`
	IsOnline      bool      `json:"isOnline"`
}

type mobileFriendRequestResponse struct {
	ID            int       `json:"id"`
	UserID        int       `json:"userId"`
	Username      string    `json:"username"`
	AboutMe       *string   `json:"aboutMe,omitempty"`
	AvatarURL     *string   `json:"avatarUrl,omitempty"`
	AvatarScale   float64   `json:"avatarScale"`
	AvatarOffsetX float64   `json:"avatarOffsetX"`
	AvatarOffsetY float64   `json:"avatarOffsetY"`
	LastSeenAt    time.Time `json:"lastSeenAt"`
	IsOnline      bool      `json:"isOnline"`
	IsIncoming    bool      `json:"isIncoming"`
	CreatedAt     time.Time `json:"createdAt"`
}

type mobileConversationResponse struct {
	ID                           int        `json:"id"`
	PeerID                       int        `json:"peerId"`
	Username                     string     `json:"username"`
	AvatarURL                    *string    `json:"avatarUrl,omitempty"`
	AvatarScale                  float64    `json:"avatarScale"`
	AvatarOffsetX                float64    `json:"avatarOffsetX"`
	AvatarOffsetY                float64    `json:"avatarOffsetY"`
	LastSeenAt                   time.Time  `json:"lastSeenAt"`
	IsOnline                     bool       `json:"isOnline"`
	PinOrder                     *int       `json:"pinOrder,omitempty"`
	IsPinned                     bool       `json:"isPinned"`
	IsArchived                   bool       `json:"isArchived"`
	IsFavorite                   bool       `json:"isFavorite"`
	IsMuted                      bool       `json:"isMuted"`
	IsBlockedByViewer            bool       `json:"isBlockedByViewer"`
	HasBlockedViewer             bool       `json:"hasBlockedViewer"`
	LastMessage                  *string    `json:"lastMessage,omitempty"`
	LastMessageAt                *time.Time `json:"lastMessageAt,omitempty"`
	LastMessageIsMine            bool       `json:"lastMessageIsMine"`
	LastMessageIsDeliveredToPeer bool       `json:"lastMessageIsDeliveredToPeer"`
	LastMessageIsReadByPeer      bool       `json:"lastMessageIsReadByPeer"`
	UnreadCount                  int        `json:"unreadCount"`
	CanSendMessages              bool       `json:"canSendMessages"`
}

type mobileDirectConversationResponse struct {
	ID              int       `json:"id"`
	PeerID          int       `json:"peerId"`
	Username        string    `json:"username"`
	AvatarURL       *string   `json:"avatarUrl,omitempty"`
	AvatarScale     float64   `json:"avatarScale"`
	AvatarOffsetX   float64   `json:"avatarOffsetX"`
	AvatarOffsetY   float64   `json:"avatarOffsetY"`
	LastSeenAt      time.Time `json:"lastSeenAt"`
	IsOnline        bool      `json:"isOnline"`
	CanSendMessages bool      `json:"canSendMessages"`
}

type mobileAttachmentResponse struct {
	ID          int    `json:"id"`
	FileName    string `json:"fileName"`
	FileURL     string `json:"fileUrl"`
	ContentType string `json:"contentType"`
	SizeBytes   int64  `json:"sizeBytes"`
	IsImage     bool   `json:"isImage"`
}

type mobileMessageResponse struct {
	ID                             int                        `json:"id"`
	ConversationID                 int                        `json:"conversationId"`
	SenderID                       int                        `json:"senderId"`
	SenderUsername                 string                     `json:"senderUsername"`
	Content                        string                     `json:"content"`
	CreatedAt                      time.Time                  `json:"createdAt"`
	EditedAt                       *time.Time                 `json:"editedAt,omitempty"`
	IsMine                         bool                       `json:"isMine"`
	IsDeliveredToPeer              bool                       `json:"isDeliveredToPeer"`
	DeliveredToPeerAt              *time.Time                 `json:"deliveredToPeerAt,omitempty"`
	IsReadByPeer                   bool                       `json:"isReadByPeer"`
	ReadByPeerAt                   *time.Time                 `json:"readByPeerAt,omitempty"`
	ReplyToMessageID               *int                       `json:"replyToMessageId,omitempty"`
	ReplyToSenderUsername          *string                    `json:"replyToSenderUsername,omitempty"`
	ReplyToContent                 *string                    `json:"replyToContent,omitempty"`
	ForwardedFromMessageID         *int                       `json:"forwardedFromMessageId,omitempty"`
	ForwardedFromUserID            *int                       `json:"forwardedFromUserId,omitempty"`
	ForwardedFromSenderUsername    *string                    `json:"forwardedFromSenderUsername,omitempty"`
	ForwardedFromUserAvatarURL     *string                    `json:"forwardedFromUserAvatarUrl,omitempty"`
	ForwardedFromUserAvatarScale   float64                    `json:"forwardedFromUserAvatarScale"`
	ForwardedFromUserAvatarOffsetX float64                    `json:"forwardedFromUserAvatarOffsetX"`
	ForwardedFromUserAvatarOffsetY float64                    `json:"forwardedFromUserAvatarOffsetY"`
	Attachments                    []mobileAttachmentResponse `json:"attachments"`
	IsHidden                       bool                       `json:"isHidden"`
	IsRemoved                      bool                       `json:"isRemoved"`
}

type mobileMessagePageResponse struct {
	Items               []mobileMessageResponse `json:"items"`
	HasMore             bool                    `json:"hasMore"`
	NextBeforeMessageID *int                    `json:"nextBeforeMessageId,omitempty"`
}

type mobileNotificationResponse struct {
	ID                 int       `json:"id"`
	Type               string    `json:"type"`
	Text               string    `json:"text"`
	IsRead             bool      `json:"isRead"`
	CreatedAt          time.Time `json:"createdAt"`
	ActorUserID        *int      `json:"actorUserId,omitempty"`
	ActorUsername      *string   `json:"actorUsername,omitempty"`
	ActorAvatarURL     *string   `json:"actorAvatarUrl,omitempty"`
	ActorAvatarScale   float64   `json:"actorAvatarScale"`
	ActorAvatarOffsetX float64   `json:"actorAvatarOffsetX"`
	ActorAvatarOffsetY float64   `json:"actorAvatarOffsetY"`
	PostID             *int      `json:"postId,omitempty"`
	CommentID          *int      `json:"commentId,omitempty"`
	ConversationID     *int      `json:"conversationId,omitempty"`
	MessageID          *int      `json:"messageId,omitempty"`
	RelatedUserID      *int      `json:"relatedUserId,omitempty"`
}

type mobileSessionResponse struct {
	ID               string     `json:"id"`
	CreatedAt        time.Time  `json:"createdAt"`
	LastUsedAt       time.Time  `json:"lastUsedAt"`
	ExpiresAt        time.Time  `json:"expiresAt"`
	RevokedAt        *time.Time `json:"revokedAt,omitempty"`
	DeviceName       *string    `json:"deviceName,omitempty"`
	Platform         *string    `json:"platform,omitempty"`
	UserAgent        *string    `json:"userAgent,omitempty"`
	IPAddress        *string    `json:"ipAddress,omitempty"`
	IsCurrent        bool       `json:"isCurrent"`
	IsActive         bool       `json:"isActive"`
	RevocationReason *string    `json:"revocationReason,omitempty"`
}

type mobileAvailabilityResponse struct {
	Available bool `json:"available"`
}

type mobileUpdateProfileRequest struct {
	DisplayName   *string  `json:"displayName"`
	Username      *string  `json:"username"`
	AboutMe       *string  `json:"aboutMe"`
	AvatarURL     *string  `json:"avatarUrl"`
	BannerURL     *string  `json:"bannerUrl"`
	AvatarScale   *float64 `json:"avatarScale"`
	AvatarOffsetX *float64 `json:"avatarOffsetX"`
	AvatarOffsetY *float64 `json:"avatarOffsetY"`
	BannerScale   *float64 `json:"bannerScale"`
	BannerOffsetX *float64 `json:"bannerOffsetX"`
	BannerOffsetY *float64 `json:"bannerOffsetY"`
	RemoveAvatar  *bool    `json:"removeAvatar"`
	RemoveBanner  *bool    `json:"removeBanner"`
}

type mobileUpdatePrivacyRequest struct {
	IsPrivateAccount   bool   `json:"isPrivateAccount"`
	ProfileVisibility  string `json:"profileVisibility"`
	MessagePrivacy     string `json:"messagePrivacy"`
	CommentPrivacy     string `json:"commentPrivacy"`
	PresenceVisibility string `json:"presenceVisibility"`
}

type mobileDeleteConversationRequest struct {
	ConversationID int  `json:"conversationId"`
	DeleteForBoth  bool `json:"deleteForBoth"`
}

type mobileClearConversationHistoryRequest struct {
	ConversationID int `json:"conversationId"`
}

type mobileToggleConversationPinRequest struct {
	ConversationID int  `json:"conversationId"`
	IsPinned       bool `json:"isPinned"`
}

type mobileToggleConversationArchiveRequest struct {
	ConversationID int  `json:"conversationId"`
	IsArchived     bool `json:"isArchived"`
}

type mobileToggleConversationFavoriteRequest struct {
	ConversationID int  `json:"conversationId"`
	IsFavorite     bool `json:"isFavorite"`
}

type mobileToggleConversationMuteRequest struct {
	ConversationID int  `json:"conversationId"`
	IsMuted        bool `json:"isMuted"`
}

type mobileToggleUserBlockRequest struct {
	UserID int `json:"userId"`
}

type mobileDeleteForAllRequest struct {
	ConversationID int `json:"conversationId"`
	MessageID      int `json:"messageId"`
}

type mobilePushTokenRequest struct {
	DeviceID   string `json:"deviceId"`
	Token      string `json:"token"`
	Platform   string `json:"platform"`
	DeviceName string `json:"deviceName"`
	AppVersion string `json:"appVersion"`
}

type mobileForwardMessageRequest struct {
	MessageID int `json:"messageId"`
}

type mobileTypingRequest struct {
	ConversationID int `json:"conversationId"`
}

type mobileUpdateMessageRequest struct {
	Content string `json:"content"`
}

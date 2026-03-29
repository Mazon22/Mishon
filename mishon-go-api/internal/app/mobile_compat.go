package app

import (
	"context"
	"database/sql"
	"errors"
	"io"
	"mime/multipart"
	"net/http"
	"net/mail"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
)

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

type mobileUpdateMessageRequest struct {
	Content string `json:"content"`
}

func (s *Server) registerMobileRoutes(router chi.Router) {
	router.Route("/api", func(r chi.Router) {
		r.Route("/auth", func(r chi.Router) {
			r.Post("/register", s.handleRegister)
			r.Post("/login", s.handleLogin)
			r.Post("/refresh", s.handleRefresh)
			r.Post("/refresh-token", s.handleRefresh)
			r.Get("/check-username", s.mobileHandleCheckRegistrationUsername)
			r.Get("/check-email", s.mobileHandleCheckRegistrationEmail)
			r.Post("/verify-email", s.mobileHandleNoop)
			r.Post("/resend-verification", s.mobileHandleNoop)
			r.Post("/forgot-password", s.mobileHandleNoop)
			r.Post("/reset-password", s.mobileHandleNoop)

			r.Group(func(r chi.Router) {
				r.Use(s.requireAuth)
				r.Post("/logout", s.handleLogout)
				r.Post("/logout-all", s.mobileHandleLogoutAllSessions)
				r.Get("/sessions", s.mobileHandleGetSessions)
				r.Delete("/sessions/{sessionID}", s.mobileHandleRevokeSession)
				r.Get("/profile", s.mobileHandleProfile)
				r.Get("/profile/{userID}", s.mobileHandleUserProfile)
				r.Put("/profile", s.mobileHandleUpdateProfile)
				r.Put("/profile/media", s.mobileHandleUpdateProfileMedia)
			})
		})

		r.Group(func(r chi.Router) {
			r.Use(s.requireAuth)
			r.Get("/users/check-username", s.mobileHandleCheckUsername)
			r.Get("/users", s.mobileHandleUsers)
			r.Get("/users/search", s.mobileHandleSearchUsers)
			r.Get("/users/me/privacy", s.mobileHandleGetPrivacy)
			r.Put("/users/me/privacy", s.mobileHandleUpdatePrivacy)
			r.Get("/feed", s.mobileHandleFeed)
			r.Get("/feed/following", s.mobileHandleFollowingFeed)
			r.Post("/posts", s.mobileHandleCreatePost)
			r.Get("/posts/{postID}", s.mobileHandleGetPost)
			r.Delete("/posts/{postID}", s.handleDeletePost)
			r.Get("/posts/user/{userID}", s.mobileHandleUserPosts)
			r.Post("/posts/{postID}/like", s.mobileHandleToggleLike)
			r.Get("/posts/{postID}/comments", s.mobileHandleComments)
			r.Post("/posts/{postID}/comments", s.mobileHandleCreateComment)
			r.Put("/posts/{postID}/comments/{commentID}", s.mobileHandleUpdateComment)
			r.Delete("/posts/{postID}/comments/{commentID}", s.mobileHandleDeleteComment)
			r.Post("/follows/{userID}", s.mobileHandleToggleFollow)
			r.Get("/follows/{userID}/following", s.mobileHandleFollowingList)
			r.Get("/follows/{userID}/followers", s.mobileHandleFollowersList)
			r.Get("/follows/followings", s.mobileHandleMyFollowingList)
			r.Get("/follows/followers", s.mobileHandleMyFollowersList)
			r.Get("/follows/check/{userID}", s.mobileHandleIsFollowing)
			r.Get("/follows/{userID}/followers/count", s.mobileHandleFollowersCount)
			r.Get("/follows/requests", s.mobileHandleIncomingFollowRequests)
			r.Post("/follows/requests/{requestID}/approve", s.mobileHandleApproveFollowRequest)
			r.Post("/follows/requests/{requestID}/reject", s.mobileHandleRejectFollowRequest)
			r.Get("/friends", s.mobileHandleFriends)
			r.Get("/friends/requests/incoming", s.mobileHandleIncomingFriendRequests)
			r.Get("/friends/requests/outgoing", s.mobileHandleOutgoingFriendRequests)
			r.Post("/friends/requests/{userID}", s.mobileHandleSendFriendRequestCompat)
			r.Post("/friends/requests/{requestID}/accept", s.handleAcceptFriendRequest)
			r.Delete("/friends/requests/{requestID}", s.handleDeleteFriendRequest)
			r.Delete("/friends/{userID}", s.handleRemoveFriend)
			r.Get("/conversations", s.mobileHandleConversations)
			r.Post("/conversations/direct/{userID}", s.mobileHandleDirectConversation)
			r.Get("/conversations/{conversationID}/messages", s.mobileHandleMessages)
			r.Post("/conversations/{conversationID}/messages", s.mobileHandleSendMessage)
			r.Post("/conversations/{conversationID}/messages/forward", s.mobileHandleForwardMessage)
			r.Put("/conversations/{conversationID}/messages/{messageID}", s.mobileHandleUpdateMessage)
			r.Delete("/conversations/{conversationID}/messages/{messageID}", s.mobileHandleDeleteMessage)
			r.Post("/message/delete-for-all", s.mobileHandleDeleteMessageForAll)
			r.Post("/chat/pin", s.mobileHandlePinConversation)
			r.Post("/chat/archive", s.mobileHandleArchiveConversation)
			r.Post("/chat/favorite", s.mobileHandleFavoriteConversation)
			r.Post("/chat/mute", s.mobileHandleMuteConversation)
			r.Delete("/chat", s.mobileHandleDeleteConversation)
			r.Post("/chat/clear-history", s.mobileHandleClearConversationHistory)
			r.Post("/chat/block-user", s.mobileHandleBlockUser)
			r.Post("/chat/unblock-user", s.mobileHandleUnblockUser)
			r.Get("/chat/blocked-users", s.mobileHandleBlockedUsers)
			r.Post("/chat/typing-start", s.mobileHandleTypingNoop)
			r.Post("/chat/typing-stop", s.mobileHandleTypingNoop)
			r.Get("/notifications", s.mobileHandleNotifications)
			r.Get("/notifications/summary", s.handleNotificationSummary)
			r.Post("/notifications/{notificationID}/read", s.handleReadNotification)
			r.Post("/notifications/read-all", s.handleReadAllNotifications)
			r.Post("/notifications/push-token", s.mobileHandleRegisterPushToken)
			r.Delete("/notifications/push-token", s.mobileHandleRemovePushToken)
		})
	})
}

func (s *Server) mobileHandleNoop(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) mobileHandleCheckRegistrationUsername(w http.ResponseWriter, r *http.Request) {
	username := normalizeUsername(r.URL.Query().Get("username"))
	if !isValidUsername(username) {
		writeJSON(w, http.StatusOK, mobileAvailabilityResponse{Available: false})
		return
	}

	var exists bool
	if err := s.db.GetContext(r.Context(), &exists, `SELECT EXISTS(SELECT 1 FROM "Users" WHERE "NormalizedUsername" = $1)`, username); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to check username")
		return
	}
	writeJSON(w, http.StatusOK, mobileAvailabilityResponse{Available: !exists})
}

func (s *Server) mobileHandleCheckRegistrationEmail(w http.ResponseWriter, r *http.Request) {
	email := normalizeEmail(r.URL.Query().Get("email"))
	if email == "" {
		writeJSON(w, http.StatusOK, mobileAvailabilityResponse{Available: false})
		return
	}
	if _, err := mail.ParseAddress(email); err != nil {
		writeJSON(w, http.StatusOK, mobileAvailabilityResponse{Available: false})
		return
	}

	var exists bool
	if err := s.db.GetContext(r.Context(), &exists, `SELECT EXISTS(SELECT 1 FROM "Users" WHERE "NormalizedEmail" = $1)`, email); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to check email")
		return
	}
	writeJSON(w, http.StatusOK, mobileAvailabilityResponse{Available: !exists})
}

func (s *Server) mobileHandleCheckUsername(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	username := normalizeUsername(r.URL.Query().Get("username"))
	if !isValidUsername(username) {
		writeJSON(w, http.StatusOK, mobileAvailabilityResponse{Available: false})
		return
	}

	var exists bool
	if err := s.db.GetContext(r.Context(), &exists, `SELECT EXISTS(SELECT 1 FROM "Users" WHERE "NormalizedUsername" = $1 AND "Id" <> $2)`, username, user.ID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to check username")
		return
	}
	writeJSON(w, http.StatusOK, mobileAvailabilityResponse{Available: !exists})
}

func (s *Server) mobileHandleLogoutAllSessions(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if _, err := s.db.ExecContext(r.Context(), `
		UPDATE "UserSessions"
		SET "RevokedAt" = NOW(), "RevocationReason" = 'logout_all'
		WHERE "UserId" = $1 AND "RevokedAt" IS NULL
	`, user.ID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to revoke sessions")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleGetSessions(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	items, err := s.loadMobileSessions(r.Context(), user.ID, user.SessionID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load sessions")
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) mobileHandleRevokeSession(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	sessionID, err := uuid.Parse(strings.TrimSpace(chi.URLParam(r, "sessionID")))
	if err != nil {
		writeError(w, http.StatusBadRequest, "Invalid sessionID")
		return
	}

	result, err := s.db.ExecContext(r.Context(), `
		UPDATE "UserSessions"
		SET "RevokedAt" = NOW(), "RevocationReason" = 'manual_revoke'
		WHERE "Id" = $1 AND "UserId" = $2 AND "Id" <> $3
	`, sessionID, user.ID, user.SessionID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to revoke session")
		return
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		writeError(w, http.StatusNotFound, "Session not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleProfile(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	profile, err := s.loadMobileProfile(r.Context(), r, user.ID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load profile")
		return
	}
	writeJSON(w, http.StatusOK, profile)
}

func (s *Server) mobileHandleUserProfile(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	targetID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	profile, err := s.loadMobileProfile(r.Context(), r, user.ID, targetID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Profile not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load profile")
		return
	}
	writeJSON(w, http.StatusOK, profile)
}

func (s *Server) mobileHandleUpdateProfile(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	current, err := s.loadProfile(r.Context(), user.ID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load current profile")
		return
	}

	var req mobileUpdateProfileRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	username := current.Username
	if req.Username != nil {
		username = normalizeUsername(*req.Username)
	}
	if !isValidUsername(username) {
		writeError(w, http.StatusBadRequest, "Username must be 5-32 chars and may contain a-z, 0-9, . and _")
		return
	}

	avatarURL := stringValue(req.AvatarURL, current.AvatarURL)
	bannerURL := stringValue(req.BannerURL, current.BannerURL)
	if boolValue(req.RemoveAvatar) {
		avatarURL = nil
	}
	if boolValue(req.RemoveBanner) {
		bannerURL = nil
	}

	_, err = s.db.ExecContext(r.Context(), `
		UPDATE "Users"
		SET "DisplayName" = $2,
		    "Username" = $3,
		    "NormalizedUsername" = $4,
		    "AboutMe" = $5,
		    "AvatarUrl" = $6,
		    "BannerUrl" = $7,
		    "AvatarScale" = $8,
		    "AvatarOffsetX" = $9,
		    "AvatarOffsetY" = $10,
		    "BannerScale" = $11,
		    "BannerOffsetX" = $12,
		    "BannerOffsetY" = $13
		WHERE "Id" = $1
	`, user.ID,
		stringValue(req.DisplayName, current.DisplayName),
		username,
		username,
		stringValue(req.AboutMe, current.AboutMe),
		avatarURL,
		bannerURL,
		floatValue(req.AvatarScale, current.AvatarScale),
		floatValue(req.AvatarOffsetX, current.AvatarOffsetX),
		floatValue(req.AvatarOffsetY, current.AvatarOffsetY),
		floatValue(req.BannerScale, current.BannerScale),
		floatValue(req.BannerOffsetX, current.BannerOffsetX),
		floatValue(req.BannerOffsetY, current.BannerOffsetY),
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			writeError(w, http.StatusConflict, "Username is already in use")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to update profile")
		return
	}

	profile, err := s.loadMobileProfile(r.Context(), r, user.ID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load updated profile")
		return
	}
	writeJSON(w, http.StatusOK, profile)
}

func (s *Server) mobileHandleUpdateProfileMedia(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if err := r.ParseMultipartForm(12 << 20); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid multipart form")
		return
	}

	current, err := s.loadProfile(r.Context(), user.ID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load current profile")
		return
	}

	avatarURL := current.AvatarURL
	bannerURL := current.BannerURL
	if truthyFormValue(r.FormValue("removeAvatar")) {
		avatarURL = nil
	}
	if truthyFormValue(r.FormValue("removeBanner")) {
		bannerURL = nil
	}

	if file, header, err := r.FormFile("avatar"); err == nil {
		defer file.Close()
		savedPath, saveErr := saveUploadedFile("profile", file, header)
		if saveErr != nil {
			writeError(w, http.StatusInternalServerError, "Failed to save avatar")
			return
		}
		avatarURL = &savedPath
	}

	if file, header, err := r.FormFile("banner"); err == nil {
		defer file.Close()
		savedPath, saveErr := saveUploadedFile("profile", file, header)
		if saveErr != nil {
			writeError(w, http.StatusInternalServerError, "Failed to save banner")
			return
		}
		bannerURL = &savedPath
	}

	_, err = s.db.ExecContext(r.Context(), `
		UPDATE "Users"
		SET "AvatarUrl" = $2,
		    "BannerUrl" = $3,
		    "AvatarScale" = $4,
		    "AvatarOffsetX" = $5,
		    "AvatarOffsetY" = $6,
		    "BannerScale" = $7,
		    "BannerOffsetX" = $8,
		    "BannerOffsetY" = $9
		WHERE "Id" = $1
	`, user.ID,
		avatarURL,
		bannerURL,
		parseFormFloatWithDefault(r.FormValue("avatarScale"), current.AvatarScale),
		parseFormFloatWithDefault(r.FormValue("avatarOffsetX"), current.AvatarOffsetX),
		parseFormFloatWithDefault(r.FormValue("avatarOffsetY"), current.AvatarOffsetY),
		parseFormFloatWithDefault(r.FormValue("bannerScale"), current.BannerScale),
		parseFormFloatWithDefault(r.FormValue("bannerOffsetX"), current.BannerOffsetX),
		parseFormFloatWithDefault(r.FormValue("bannerOffsetY"), current.BannerOffsetY),
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update media")
		return
	}

	profile, err := s.loadMobileProfile(r.Context(), r, user.ID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load updated profile")
		return
	}
	writeJSON(w, http.StatusOK, profile)
}

func (s *Server) mobileHandleGetPrivacy(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	profile, err := s.loadProfile(r.Context(), user.ID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load privacy settings")
		return
	}
	writeJSON(w, http.StatusOK, mobilePrivacyResponse{
		IsPrivateAccount:   profile.IsPrivateAccount,
		ProfileVisibility:  profile.ProfileVisibility,
		MessagePrivacy:     profile.MessagePrivacy,
		CommentPrivacy:     profile.CommentPrivacy,
		PresenceVisibility: profile.PresenceVisibility,
	})
}

func (s *Server) mobileHandleUpdatePrivacy(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req mobileUpdatePrivacyRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	profileVisibility, ok := parsePrivacy(req.ProfileVisibility, map[string]int{"Public": 0, "FollowersOnly": 1, "Private": 2})
	if !ok {
		writeError(w, http.StatusBadRequest, "Invalid profile visibility")
		return
	}
	messagePrivacy, ok := parsePrivacy(req.MessagePrivacy, map[string]int{"Everyone": 0, "Followers": 1, "Friends": 2, "Nobody": 3})
	if !ok {
		writeError(w, http.StatusBadRequest, "Invalid message privacy")
		return
	}
	commentPrivacy, ok := parsePrivacy(req.CommentPrivacy, map[string]int{"Everyone": 0, "Followers": 1, "Friends": 2, "Nobody": 3})
	if !ok {
		writeError(w, http.StatusBadRequest, "Invalid comment privacy")
		return
	}
	presencePrivacy, ok := parsePrivacy(req.PresenceVisibility, map[string]int{"Everyone": 0, "Followers": 1, "Friends": 2, "Nobody": 3})
	if !ok {
		writeError(w, http.StatusBadRequest, "Invalid presence visibility")
		return
	}

	if _, err := s.db.ExecContext(r.Context(), `
		UPDATE "Users"
		SET "IsPrivateAccount" = $2,
		    "ProfileVisibility" = $3,
		    "MessagePrivacy" = $4,
		    "CommentPrivacy" = $5,
		    "PresenceVisibility" = $6
		WHERE "Id" = $1
	`, user.ID, req.IsPrivateAccount, profileVisibility, messagePrivacy, commentPrivacy, presencePrivacy); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update privacy settings")
		return
	}

	writeJSON(w, http.StatusOK, mobilePrivacyResponse{
		IsPrivateAccount:   req.IsPrivateAccount,
		ProfileVisibility:  req.ProfileVisibility,
		MessagePrivacy:     req.MessagePrivacy,
		CommentPrivacy:     req.CommentPrivacy,
		PresenceVisibility: req.PresenceVisibility,
	})
}

func (s *Server) mobileHandleUsers(w http.ResponseWriter, r *http.Request) {
	s.mobileHandleUsersWithQuery(w, r, normalizeText(r.URL.Query().Get("q")))
}

func (s *Server) mobileHandleSearchUsers(w http.ResponseWriter, r *http.Request) {
	s.mobileHandleUsersWithQuery(w, r, normalizeText(r.URL.Query().Get("q")))
}

func (s *Server) mobileHandleUsersWithQuery(w http.ResponseWriter, r *http.Request, query string) {
	user := authUser(r.Context())
	page, pageSize := paginationFromRequest(r)
	items, hasMore, err := s.loadDiscoverUsers(r.Context(), user.ID, query, page, pageSize)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load users")
		return
	}
	totalCount, err := s.countDiscoverUsers(r.Context(), user.ID, query)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load users")
		return
	}
	writeJSON(w, http.StatusOK, buildMobilePage(mapMobileDiscoverUsers(r, items), page, pageSize, totalCount, hasMore))
}

func (s *Server) mobileHandleFeed(w http.ResponseWriter, r *http.Request) {
	s.mobileHandleFeedWithMode(w, r, false)
}

func (s *Server) mobileHandleFollowingFeed(w http.ResponseWriter, r *http.Request) {
	s.mobileHandleFeedWithMode(w, r, true)
}

func (s *Server) mobileHandleFeedWithMode(w http.ResponseWriter, r *http.Request, followingOnly bool) {
	user := authUser(r.Context())
	page, pageSize := paginationFromRequest(r)
	items, hasMore, err := s.loadFeed(r.Context(), user.ID, page, pageSize, followingOnly)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load feed")
		return
	}
	totalCount, err := s.countFeedPosts(r.Context(), user.ID, followingOnly)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load feed")
		return
	}
	writeJSON(w, http.StatusOK, buildMobilePage(mapMobilePosts(r, items), page, pageSize, totalCount, hasMore))
}

func (s *Server) mobileHandleUserPosts(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	targetID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	page, pageSize := paginationFromRequest(r)
	items, _, err := s.loadUserPosts(r.Context(), user.ID, targetID, page, pageSize)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load posts")
		return
	}
	writeJSON(w, http.StatusOK, mapMobilePosts(r, items))
}

func (s *Server) mobileHandleCreatePost(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())

	var content string
	var imageURL *string

	if usesMultipartForm(r) {
		if err := r.ParseMultipartForm(12 << 20); err != nil {
			writeError(w, http.StatusBadRequest, "Invalid multipart form")
			return
		}
		content = normalizeText(r.FormValue("content"))
		if file, header, err := r.FormFile("image"); err == nil {
			defer file.Close()
			savedPath, saveErr := saveUploadedFile("posts", file, header)
			if saveErr != nil {
				writeError(w, http.StatusInternalServerError, "Failed to save image")
				return
			}
			imageURL = &savedPath
		}
	} else {
		var req createPostRequest
		if err := decodeJSON(r, &req); err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		content = normalizeText(req.Content)
		if normalizedImageURL := normalizeText(req.ImageURL); normalizedImageURL != "" {
			imageURL = &normalizedImageURL
		}
	}

	if content == "" || len(content) > 1000 {
		writeError(w, http.StatusBadRequest, "Post content must be 1-1000 characters")
		return
	}

	var postID int
	if err := s.db.GetContext(r.Context(), &postID, `
		INSERT INTO "Posts" ("UserId", "Content", "ImageUrl", "CreatedAt")
		VALUES ($1, $2, $3, NOW())
		RETURNING "Id"
	`, user.ID, content, imageURL); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create post")
		return
	}

	post, err := s.loadPostByID(r.Context(), user.ID, postID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load post")
		return
	}
	writeJSON(w, http.StatusCreated, mapMobilePost(r, post))
}

func (s *Server) mobileHandleGetPost(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	post, err := s.loadPostByID(r.Context(), user.ID, postID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Post not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load post")
		return
	}
	writeJSON(w, http.StatusOK, mapMobilePost(r, post))
}

func (s *Server) mobileHandleToggleLike(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	response, err := s.toggleLikeForMobile(r.Context(), r, user.ID, postID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update like")
		return
	}
	writeJSON(w, http.StatusOK, response)
}

func (s *Server) toggleLikeForMobile(ctx context.Context, r *http.Request, userID, postID int) (mobilePostResponse, error) {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return mobilePostResponse{}, err
	}
	defer tx.Rollback()

	var liked bool
	if err := tx.GetContext(ctx, &liked, `SELECT EXISTS(SELECT 1 FROM "Likes" WHERE "UserId" = $1 AND "PostId" = $2)`, userID, postID); err != nil {
		return mobilePostResponse{}, err
	}
	if liked {
		if _, err := tx.ExecContext(ctx, `DELETE FROM "Likes" WHERE "UserId" = $1 AND "PostId" = $2`, userID, postID); err != nil {
			return mobilePostResponse{}, err
		}
	} else {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO "Likes" ("UserId", "PostId", "CreatedAt")
			VALUES ($1, $2, NOW())
			ON CONFLICT ("UserId", "PostId") DO NOTHING
		`, userID, postID); err != nil {
			return mobilePostResponse{}, err
		}
	}
	if err := tx.Commit(); err != nil {
		return mobilePostResponse{}, err
	}
	post, err := s.loadPostByID(ctx, userID, postID)
	if err != nil {
		return mobilePostResponse{}, err
	}
	return mapMobilePost(r, post), nil
}

func (s *Server) mobileHandleComments(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	items, err := s.loadComments(r.Context(), user.ID, postID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load comments")
		return
	}
	writeJSON(w, http.StatusOK, mapMobileComments(r, items))
}

func (s *Server) mobileHandleCreateComment(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var req createCommentRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	content := normalizeText(req.Content)
	if content == "" || len(content) > 500 {
		writeError(w, http.StatusBadRequest, "Comment content must be 1-500 characters")
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open transaction")
		return
	}
	defer tx.Rollback()

	var commentID int
	if err := tx.GetContext(r.Context(), &commentID, `
		INSERT INTO "Comments" ("Content", "CreatedAt", "UserId", "PostId", "ParentCommentId")
		VALUES ($1, NOW(), $2, $3, $4)
		RETURNING "Id"
	`, content, user.ID, postID, req.ParentCommentID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create comment")
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save comment")
		return
	}

	comment, err := s.loadCommentByID(r.Context(), user.ID, commentID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load comment")
		return
	}
	writeJSON(w, http.StatusCreated, mapMobileComment(r, comment))
}

func (s *Server) mobileHandleUpdateComment(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	commentID, err := parseIDParam(r, "commentID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var req createCommentRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	content := normalizeText(req.Content)
	if content == "" || len(content) > 500 {
		writeError(w, http.StatusBadRequest, "Comment content must be 1-500 characters")
		return
	}

	result, err := s.db.ExecContext(r.Context(), `
		UPDATE "Comments"
		SET "Content" = $3, "EditedAt" = NOW()
		WHERE "Id" = $1 AND "UserId" = $2 AND "IsHidden" = false AND "IsRemoved" = false
	`, commentID, user.ID, content)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update comment")
		return
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		writeError(w, http.StatusNotFound, "Comment not found")
		return
	}

	comment, err := s.loadCommentByID(r.Context(), user.ID, commentID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load comment")
		return
	}
	writeJSON(w, http.StatusOK, mapMobileComment(r, comment))
}

func (s *Server) mobileHandleDeleteComment(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	commentID, err := parseIDParam(r, "commentID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	result, err := s.db.ExecContext(r.Context(), `DELETE FROM "Comments" WHERE "Id" = $1 AND "UserId" = $2`, commentID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to delete comment")
		return
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		writeError(w, http.StatusNotFound, "Comment not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleToggleFollow(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	targetID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	response, err := s.toggleFollow(r.Context(), user.ID, targetID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update follow state")
		return
	}
	writeJSON(w, http.StatusOK, response)
}

func (s *Server) mobileHandleFollowingList(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	targetID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	items, err := s.loadMobileFollowList(r.Context(), r, user.ID, targetID, false)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load following")
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) mobileHandleFollowersList(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	targetID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	items, err := s.loadMobileFollowList(r.Context(), r, user.ID, targetID, true)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load followers")
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) mobileHandleMyFollowingList(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	items, err := s.loadMobileFollowList(r.Context(), r, user.ID, user.ID, false)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load following")
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) mobileHandleMyFollowersList(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	items, err := s.loadMobileFollowList(r.Context(), r, user.ID, user.ID, true)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load followers")
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) mobileHandleIsFollowing(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	targetID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	var following bool
	if err := s.db.GetContext(r.Context(), &following, `SELECT EXISTS(SELECT 1 FROM "Follows" WHERE "FollowerId" = $1 AND "FollowingId" = $2)`, user.ID, targetID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load follow state")
		return
	}
	writeJSON(w, http.StatusOK, following)
}

func (s *Server) mobileHandleFollowersCount(w http.ResponseWriter, r *http.Request) {
	targetID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	var count int
	if err := s.db.GetContext(r.Context(), &count, `SELECT COUNT(*) FROM "Follows" WHERE "FollowingId" = $1`, targetID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load followers count")
		return
	}
	writeJSON(w, http.StatusOK, count)
}

func (s *Server) mobileHandleIncomingFollowRequests(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	items, err := s.loadMobileFollowRequests(r.Context(), r, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load follow requests")
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) mobileHandleApproveFollowRequest(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	requestID, err := parseIDParam(r, "requestID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := s.approveFollowRequest(r.Context(), user.ID, requestID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Follow request not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to approve request")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleRejectFollowRequest(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	requestID, err := parseIDParam(r, "requestID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := s.rejectFollowRequest(r.Context(), user.ID, requestID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Follow request not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to reject request")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleFriends(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	items, err := s.loadFriends(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load friends")
		return
	}
	writeJSON(w, http.StatusOK, mapMobileFriends(r, items))
}

func (s *Server) mobileHandleIncomingFriendRequests(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	incoming, _, err := s.loadFriendRequests(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load friend requests")
		return
	}
	writeJSON(w, http.StatusOK, mapMobileFriendRequests(r, incoming))
}

func (s *Server) mobileHandleOutgoingFriendRequests(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	_, outgoing, err := s.loadFriendRequests(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load friend requests")
		return
	}
	writeJSON(w, http.StatusOK, mapMobileFriendRequests(r, outgoing))
}

func (s *Server) mobileHandleSendFriendRequestCompat(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	targetID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if targetID == user.ID {
		writeError(w, http.StatusBadRequest, "Cannot send a friend request to yourself")
		return
	}
	if _, err := s.db.ExecContext(r.Context(), `
		INSERT INTO "FriendRequests" ("SenderId", "ReceiverId", "CreatedAt")
		VALUES ($1, $2, NOW())
		ON CONFLICT ("SenderId", "ReceiverId") DO NOTHING
	`, user.ID, targetID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to send friend request")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleConversations(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	items, err := s.loadChats(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load conversations")
		return
	}
	writeJSON(w, http.StatusOK, s.mapMobileConversations(r, user.ID, items))
}

func (s *Server) mobileHandleDirectConversation(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	peerID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open transaction")
		return
	}
	defer tx.Rollback()

	var conversationID int
	err = tx.GetContext(r.Context(), &conversationID, `
		SELECT "Id"
		FROM "Conversations"
		WHERE ("UserAId" = $1 AND "UserBId" = $2) OR ("UserAId" = $2 AND "UserBId" = $1)
	`, user.ID, peerID)
	if errors.Is(err, sql.ErrNoRows) {
		if err := tx.GetContext(r.Context(), &conversationID, `
			INSERT INTO "Conversations" ("UserAId", "UserBId", "CreatedAt", "UpdatedAt")
			VALUES ($1, $2, NOW(), NOW())
			RETURNING "Id"
		`, minInt(user.ID, peerID), maxInt(user.ID, peerID)); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to create conversation")
			return
		}
	} else if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load conversation")
		return
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save conversation")
		return
	}

	items, err := s.loadChats(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load conversation")
		return
	}
	for _, item := range items {
		if item.ID == conversationID {
			status, statusErr := s.loadUserBlockStatus(r.Context(), user.ID, item.Peer.ID)
			if statusErr != nil {
				writeError(w, http.StatusInternalServerError, "Failed to load conversation")
				return
			}
			writeJSON(w, http.StatusOK, mapMobileDirectConversation(r, item, status))
			return
		}
	}
	writeError(w, http.StatusNotFound, "Conversation not found")
}

func (s *Server) mobileHandleNotifications(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	page, pageSize := paginationFromRequest(r)
	items, hasMore, err := s.loadNotifications(r.Context(), user.ID, page, pageSize)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load notifications")
		return
	}
	totalCount, err := s.countNotifications(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load notifications")
		return
	}
	writeJSON(w, http.StatusOK, buildMobilePage(mapMobileNotifications(r, items), page, pageSize, totalCount, hasMore))
}

func (s *Server) mobileHandleMessages(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	conversationID, err := parseIDParam(r, "conversationID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	limit := clamp(parseIntWithDefault(r.URL.Query().Get("limit"), 20), 1, 100)
	beforeMessageID := parseOptionalInt(r.URL.Query().Get("beforeMessageId"))

	page, err := s.loadMobileMessages(r.Context(), r, user.ID, conversationID, limit, beforeMessageID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Conversation not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load messages")
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *Server) mobileHandleSendMessage(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	conversationID, err := parseIDParam(r, "conversationID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var content string
	var replyToMessageID *int
	attachments := make([]savedAttachment, 0)

	if usesMultipartForm(r) {
		if err := r.ParseMultipartForm(20 << 20); err != nil {
			writeError(w, http.StatusBadRequest, "Invalid multipart form")
			return
		}
		content = normalizeText(r.FormValue("content"))
		replyToMessageID = parseOptionalInt(r.FormValue("replyToMessageId"))
		if r.MultipartForm != nil {
			for _, header := range r.MultipartForm.File["files"] {
				attachment, saveErr := saveUploadedFileHeader("messages", header)
				if saveErr != nil {
					writeError(w, http.StatusInternalServerError, "Failed to save attachment")
					return
				}
				attachments = append(attachments, attachment)
			}
		}
	} else {
		var req createMessageRequest
		if err := decodeJSON(r, &req); err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		content = normalizeText(req.Content)
	}

	if content == "" && len(attachments) == 0 {
		writeError(w, http.StatusBadRequest, "Message must contain text or attachments")
		return
	}
	if len(content) > 1000 {
		writeError(w, http.StatusBadRequest, "Message content must be 1-1000 characters")
		return
	}

	message, err := s.createMobileMessage(r.Context(), r, user.ID, conversationID, content, replyToMessageID, nil, nil, attachments)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Conversation not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to send message")
		return
	}
	writeJSON(w, http.StatusOK, message)
}

func (s *Server) mobileHandleForwardMessage(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	conversationID, err := parseIDParam(r, "conversationID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var req mobileForwardMessageRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.MessageID <= 0 {
		writeError(w, http.StatusBadRequest, "Invalid messageId")
		return
	}

	forwardedFromUserID, content, attachments, err := s.loadMessageForForward(r.Context(), req.MessageID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Message not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to forward message")
		return
	}

	message, err := s.createMobileMessage(r.Context(), r, user.ID, conversationID, content, nil, &req.MessageID, forwardedFromUserID, attachments)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to forward message")
		return
	}
	writeJSON(w, http.StatusOK, message)
}

func (s *Server) mobileHandleUpdateMessage(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	conversationID, err := parseIDParam(r, "conversationID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	messageID, err := parseIDParam(r, "messageID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var req mobileUpdateMessageRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	content := normalizeText(req.Content)
	if content == "" || len(content) > 1000 {
		writeError(w, http.StatusBadRequest, "Message content must be 1-1000 characters")
		return
	}

	result, err := s.db.ExecContext(r.Context(), `
		UPDATE "Messages"
		SET "Content" = $4, "EditedAt" = NOW()
		WHERE "Id" = $1 AND "ConversationId" = $2 AND "SenderId" = $3 AND "IsHidden" = false AND "IsRemoved" = false
	`, messageID, conversationID, user.ID, content)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update message")
		return
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		writeError(w, http.StatusNotFound, "Message not found")
		return
	}

	message, err := s.loadMobileMessageByID(r.Context(), r, user.ID, conversationID, messageID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load message")
		return
	}
	writeJSON(w, http.StatusOK, message)
}

func (s *Server) mobileHandleDeleteMessage(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	conversationID, err := parseIDParam(r, "conversationID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	messageID, err := parseIDParam(r, "messageID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	column, err := s.viewerMessageDeleteColumn(r.Context(), conversationID, user.ID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Conversation not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to delete message")
		return
	}

	result, err := s.db.ExecContext(r.Context(), `UPDATE "Messages" SET `+column+` = true WHERE "Id" = $1 AND "ConversationId" = $2`, messageID, conversationID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to delete message")
		return
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		writeError(w, http.StatusNotFound, "Message not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleDeleteMessageForAll(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req mobileDeleteForAllRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	result, err := s.db.ExecContext(r.Context(), `
		UPDATE "Messages"
		SET "IsRemoved" = true
		WHERE "Id" = $1 AND "ConversationId" = $2 AND "SenderId" = $3
	`, req.MessageID, req.ConversationID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to delete message")
		return
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		writeError(w, http.StatusNotFound, "Message not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandlePinConversation(w http.ResponseWriter, r *http.Request) {
	var req mobileToggleConversationPinRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := s.updateConversationPin(r.Context(), authUser(r.Context()).ID, req.ConversationID, req.IsPinned); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update conversation")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleArchiveConversation(w http.ResponseWriter, r *http.Request) {
	var req mobileToggleConversationArchiveRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := s.updateConversationBoolFlag(r.Context(), authUser(r.Context()).ID, req.ConversationID, req.IsArchived, `"UserAArchived"`, `"UserBArchived"`); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update conversation")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleFavoriteConversation(w http.ResponseWriter, r *http.Request) {
	var req mobileToggleConversationFavoriteRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := s.updateConversationBoolFlag(r.Context(), authUser(r.Context()).ID, req.ConversationID, req.IsFavorite, `"UserAFavorite"`, `"UserBFavorite"`); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update conversation")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleMuteConversation(w http.ResponseWriter, r *http.Request) {
	var req mobileToggleConversationMuteRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := s.updateConversationBoolFlag(r.Context(), authUser(r.Context()).ID, req.ConversationID, req.IsMuted, `"UserAMuted"`, `"UserBMuted"`); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update conversation")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleDeleteConversation(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req mobileDeleteConversationRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := s.deleteConversationForUser(r.Context(), user.ID, req.ConversationID, req.DeleteForBoth); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Conversation not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to delete conversation")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleClearConversationHistory(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req mobileClearConversationHistoryRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	column, err := s.viewerMessageDeleteColumn(r.Context(), req.ConversationID, user.ID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Conversation not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to clear history")
		return
	}
	if _, err := s.db.ExecContext(r.Context(), `UPDATE "Messages" SET `+column+` = true WHERE "ConversationId" = $1`, req.ConversationID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to clear history")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleBlockUser(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req mobileToggleUserBlockRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := s.db.ExecContext(r.Context(), `
		INSERT INTO "UserBlocks" ("BlockerId", "BlockedUserId", "CreatedAt")
		VALUES ($1, $2, NOW())
		ON CONFLICT ("BlockerId", "BlockedUserId") DO NOTHING
	`, user.ID, req.UserID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to block user")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleUnblockUser(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req mobileToggleUserBlockRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := s.db.ExecContext(r.Context(), `DELETE FROM "UserBlocks" WHERE "BlockerId" = $1 AND "BlockedUserId" = $2`, user.ID, req.UserID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to unblock user")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleBlockedUsers(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	items, err := s.loadBlockedUsers(r.Context(), r, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load blocked users")
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) mobileHandleTypingNoop(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleRegisterPushToken(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req mobilePushTokenRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := s.db.ExecContext(r.Context(), `
		INSERT INTO "DevicePushTokens" (
			"UserId", "DeviceId", "Token", "DeviceName", "Platform", "AppVersion", "CreatedAt", "LastSeenAt", "RevokedAt"
		)
		VALUES ($1, $2, $3, NULLIF($4, ''), $5, NULLIF($6, ''), NOW(), NOW(), NULL)
		ON CONFLICT ("UserId", "DeviceId")
		DO UPDATE SET
			"Token" = EXCLUDED."Token",
			"DeviceName" = EXCLUDED."DeviceName",
			"Platform" = EXCLUDED."Platform",
			"AppVersion" = EXCLUDED."AppVersion",
			"LastSeenAt" = NOW(),
			"RevokedAt" = NULL
	`, user.ID, strings.TrimSpace(req.DeviceID), strings.TrimSpace(req.Token), strings.TrimSpace(req.DeviceName), strings.TrimSpace(req.Platform), strings.TrimSpace(req.AppVersion)); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save push token")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) mobileHandleRemovePushToken(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req struct {
		DeviceID string `json:"deviceId"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := s.db.ExecContext(r.Context(), `
		UPDATE "DevicePushTokens"
		SET "RevokedAt" = NOW()
		WHERE "UserId" = $1 AND "DeviceId" = $2
	`, user.ID, strings.TrimSpace(req.DeviceID)); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to remove push token")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type blockStatus struct {
	IsBlockedByViewer bool
	HasBlockedViewer  bool
}

func (s *Server) loadMobileProfile(ctx context.Context, r *http.Request, viewerID, targetID int) (mobileProfileResponse, error) {
	profile, err := s.loadProfile(ctx, viewerID, targetID)
	if err != nil {
		return mobileProfileResponse{}, err
	}
	status, err := s.loadUserBlockStatus(ctx, viewerID, targetID)
	if err != nil {
		return mobileProfileResponse{}, err
	}
	canViewProfile, canViewPosts, canSendMessages, canComment, canViewPresence := computeProfileAccess(profile, viewerID == targetID, status)
	return mobileProfileResponse{
		ID:                      profile.ID,
		Username:                profile.Username,
		Email:                   profile.Email,
		DisplayName:             profile.DisplayName,
		AboutMe:                 profile.AboutMe,
		AvatarURL:               absoluteStringPointer(r, profile.AvatarURL),
		BannerURL:               absoluteStringPointer(r, profile.BannerURL),
		AvatarScale:             profile.AvatarScale,
		AvatarOffsetX:           profile.AvatarOffsetX,
		AvatarOffsetY:           profile.AvatarOffsetY,
		BannerScale:             profile.BannerScale,
		BannerOffsetX:           profile.BannerOffsetX,
		BannerOffsetY:           profile.BannerOffsetY,
		CreatedAt:               profile.CreatedAt,
		LastSeenAt:              profile.LastSeenAt,
		IsOnline:                profile.IsOnline,
		FollowersCount:          profile.FollowersCount,
		FollowingCount:          profile.FollowingCount,
		PostsCount:              profile.PostsCount,
		IsBlockedByViewer:       status.IsBlockedByViewer,
		HasBlockedViewer:        status.HasBlockedViewer,
		IsFollowing:             profile.IsFollowing,
		EmailVerified:           profile.EmailVerified,
		Role:                    profile.Role,
		IsPrivateAccount:        profile.IsPrivateAccount,
		ProfileVisibility:       profile.ProfileVisibility,
		MessagePrivacy:          profile.MessagePrivacy,
		CommentPrivacy:          profile.CommentPrivacy,
		PresenceVisibility:      profile.PresenceVisibility,
		CanViewProfile:          canViewProfile,
		CanViewPosts:            canViewPosts,
		CanSendMessages:         canSendMessages,
		CanComment:              canComment,
		CanViewPresence:         canViewPresence,
		HasPendingFollowRequest: profile.HasPendingFollow,
	}, nil
}

func (s *Server) loadUserBlockStatus(ctx context.Context, viewerID, targetID int) (blockStatus, error) {
	if viewerID == targetID {
		return blockStatus{}, nil
	}
	rows := []struct {
		BlockerID     int `db:"blocker_id"`
		BlockedUserID int `db:"blocked_user_id"`
	}{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT "BlockerId" AS blocker_id, "BlockedUserId" AS blocked_user_id
		FROM "UserBlocks"
		WHERE ("BlockerId" = $1 AND "BlockedUserId" = $2) OR ("BlockerId" = $2 AND "BlockedUserId" = $1)
	`, viewerID, targetID); err != nil {
		return blockStatus{}, err
	}

	status := blockStatus{}
	for _, row := range rows {
		if row.BlockerID == viewerID && row.BlockedUserID == targetID {
			status.IsBlockedByViewer = true
		}
		if row.BlockerID == targetID && row.BlockedUserID == viewerID {
			status.HasBlockedViewer = true
		}
	}
	return status, nil
}

func (s *Server) loadMobileSessions(ctx context.Context, userID int, currentSessionID uuid.UUID) ([]mobileSessionResponse, error) {
	rows := []struct {
		ID               uuid.UUID      `db:"id"`
		CreatedAt        time.Time      `db:"created_at"`
		LastUsedAt       time.Time      `db:"last_used_at"`
		ExpiresAt        time.Time      `db:"expires_at"`
		RevokedAt        sql.NullTime   `db:"revoked_at"`
		DeviceName       sql.NullString `db:"device_name"`
		Platform         sql.NullString `db:"platform"`
		UserAgent        sql.NullString `db:"user_agent"`
		IPAddress        sql.NullString `db:"ip_address"`
		RevocationReason sql.NullString `db:"revocation_reason"`
	}{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			"Id" AS id, "CreatedAt" AS created_at, "LastUsedAt" AS last_used_at, "ExpiresAt" AS expires_at,
			"RevokedAt" AS revoked_at, "DeviceName" AS device_name, "Platform" AS platform,
			"UserAgent" AS user_agent, "IpAddress" AS ip_address, "RevocationReason" AS revocation_reason
		FROM "UserSessions"
		WHERE "UserId" = $1
		ORDER BY "LastUsedAt" DESC
	`, userID); err != nil {
		return nil, err
	}

	items := make([]mobileSessionResponse, 0, len(rows))
	for _, row := range rows {
		items = append(items, mobileSessionResponse{
			ID:               row.ID.String(),
			CreatedAt:        row.CreatedAt,
			LastUsedAt:       row.LastUsedAt,
			ExpiresAt:        row.ExpiresAt,
			RevokedAt:        nullableTime(row.RevokedAt),
			DeviceName:       nullableString(row.DeviceName),
			Platform:         nullableString(row.Platform),
			UserAgent:        nullableString(row.UserAgent),
			IPAddress:        nullableString(row.IPAddress),
			IsCurrent:        row.ID == currentSessionID,
			IsActive:         !row.RevokedAt.Valid && row.ExpiresAt.After(time.Now().UTC()),
			RevocationReason: nullableString(row.RevocationReason),
		})
	}
	return items, nil
}

func (s *Server) countDiscoverUsers(ctx context.Context, viewerID int, query string) (int, error) {
	search := "%"
	if query != "" {
		search = "%" + query + "%"
	}
	var count int
	err := s.db.GetContext(ctx, &count, `
		SELECT COUNT(*)
		FROM "Users" u
		WHERE u."Id" <> $1
		  AND (LOWER(u."Username") LIKE LOWER($2) OR LOWER(COALESCE(u."DisplayName", '')) LIKE LOWER($2))
	`, viewerID, search)
	return count, err
}

func (s *Server) countFeedPosts(ctx context.Context, viewerID int, followingOnly bool) (int, error) {
	filter := ""
	if followingOnly {
		filter = `AND EXISTS (SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = p."UserId")`
	}
	var count int
	err := s.db.GetContext(ctx, &count, `
		SELECT COUNT(*)
		FROM "Posts" p
		JOIN "Users" u ON u."Id" = p."UserId"
		WHERE p."IsHidden" = false
		  AND p."IsRemoved" = false
		  AND (u."Id" = $1 OR u."ProfileVisibility" = 0 OR EXISTS(SELECT 1 FROM "Follows" vf WHERE vf."FollowerId" = $1 AND vf."FollowingId" = u."Id"))
		  `+filter, viewerID)
	return count, err
}

func (s *Server) countNotifications(ctx context.Context, viewerID int) (int, error) {
	var count int
	err := s.db.GetContext(ctx, &count, `SELECT COUNT(*) FROM "Notifications" WHERE "UserId" = $1`, viewerID)
	return count, err
}

func (s *Server) loadCommentByID(ctx context.Context, _ int, commentID int) (commentResponse, error) {
	rows := []struct {
		ID              int            `db:"id"`
		PostID          int            `db:"post_id"`
		UserID          int            `db:"user_id"`
		Username        string         `db:"username"`
		DisplayName     sql.NullString `db:"display_name"`
		AvatarURL       sql.NullString `db:"avatar_url"`
		AvatarScale     float64        `db:"avatar_scale"`
		AvatarOffsetX   float64        `db:"avatar_offset_x"`
		AvatarOffsetY   float64        `db:"avatar_offset_y"`
		Content         string         `db:"content"`
		CreatedAt       time.Time      `db:"created_at"`
		EditedAt        sql.NullTime   `db:"edited_at"`
		ParentCommentID sql.NullInt64  `db:"parent_comment_id"`
		ReplyToUsername sql.NullString `db:"reply_to_username"`
		LastSeenAt      time.Time      `db:"last_seen_at"`
	}{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			c."Id" AS id, c."PostId" AS post_id, c."UserId" AS user_id,
			u."Username" AS username, u."DisplayName" AS display_name, u."AvatarUrl" AS avatar_url,
			u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x, u."AvatarOffsetY" AS avatar_offset_y,
			c."Content" AS content, c."CreatedAt" AS created_at, c."EditedAt" AS edited_at,
			c."ParentCommentId" AS parent_comment_id, parent_user."Username" AS reply_to_username,
			u."LastSeenAt" AS last_seen_at
		FROM "Comments" c
		JOIN "Users" u ON u."Id" = c."UserId"
		LEFT JOIN "Comments" parent_comment ON parent_comment."Id" = c."ParentCommentId"
		LEFT JOIN "Users" parent_user ON parent_user."Id" = parent_comment."UserId"
		WHERE c."Id" = $1 AND c."IsHidden" = false AND c."IsRemoved" = false
	`, commentID); err != nil {
		return commentResponse{}, err
	}
	if len(rows) == 0 {
		return commentResponse{}, sql.ErrNoRows
	}
	row := rows[0]
	lastSeen := row.LastSeenAt
	return commentResponse{
		ID:     row.ID,
		PostID: row.PostID,
		UserID: row.UserID,
		Author: userPreview{
			ID:            row.UserID,
			Username:      row.Username,
			DisplayName:   nullableString(row.DisplayName),
			AvatarURL:     nullableString(row.AvatarURL),
			AvatarScale:   row.AvatarScale,
			AvatarOffsetX: row.AvatarOffsetX,
			AvatarOffsetY: row.AvatarOffsetY,
			LastSeenAt:    &lastSeen,
			IsOnline:      isOnline(row.LastSeenAt),
		},
		Content:         row.Content,
		CreatedAt:       row.CreatedAt,
		EditedAt:        nullableTime(row.EditedAt),
		ParentCommentID: nullableInt(row.ParentCommentID),
		ReplyToUsername: nullableString(row.ReplyToUsername),
	}, nil
}

func (s *Server) loadMobileFollowList(ctx context.Context, r *http.Request, viewerID, targetID int, followers bool) ([]mobileFollowResponse, error) {
	type row struct {
		ID               int            `db:"id"`
		Username         string         `db:"username"`
		AvatarURL        sql.NullString `db:"avatar_url"`
		AvatarScale      float64        `db:"avatar_scale"`
		AvatarOffsetX    float64        `db:"avatar_offset_x"`
		AvatarOffsetY    float64        `db:"avatar_offset_y"`
		IsFollowing      bool           `db:"is_following"`
		IsPrivateAccount bool           `db:"is_private_account"`
	}
	rows := []row{}
	query := `
		SELECT
			u."Id" AS id,
			u."Username" AS username,
			u."AvatarUrl" AS avatar_url,
			u."AvatarScale" AS avatar_scale,
			u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y,
			EXISTS(SELECT 1 FROM "Follows" viewer_follow WHERE viewer_follow."FollowerId" = $1 AND viewer_follow."FollowingId" = u."Id") AS is_following,
			u."IsPrivateAccount" AS is_private_account
		FROM "Users" u
		JOIN "Follows" f ON `
	if followers {
		query += `f."FollowerId" = u."Id" AND f."FollowingId" = $2`
	} else {
		query += `f."FollowingId" = u."Id" AND f."FollowerId" = $2`
	}
	query += ` ORDER BY u."Username" ASC`
	if err := s.db.SelectContext(ctx, &rows, query, viewerID, targetID); err != nil {
		return nil, err
	}

	items := make([]mobileFollowResponse, 0, len(rows))
	for _, row := range rows {
		items = append(items, mobileFollowResponse{
			ID:               row.ID,
			Username:         row.Username,
			AvatarURL:        absoluteStringPointer(r, nullableString(row.AvatarURL)),
			AvatarScale:      row.AvatarScale,
			AvatarOffsetX:    row.AvatarOffsetX,
			AvatarOffsetY:    row.AvatarOffsetY,
			IsFollowing:      row.IsFollowing,
			IsPrivateAccount: row.IsPrivateAccount,
		})
	}
	return items, nil
}

func (s *Server) loadMobileFollowRequests(ctx context.Context, r *http.Request, viewerID int) ([]mobileFriendRequestResponse, error) {
	rows := []struct {
		ID            int            `db:"id"`
		UserID        int            `db:"user_id"`
		Username      string         `db:"username"`
		AboutMe       sql.NullString `db:"about_me"`
		AvatarURL     sql.NullString `db:"avatar_url"`
		AvatarScale   float64        `db:"avatar_scale"`
		AvatarOffsetX float64        `db:"avatar_offset_x"`
		AvatarOffsetY float64        `db:"avatar_offset_y"`
		CreatedAt     time.Time      `db:"created_at"`
	}{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			fr."Id" AS id,
			requester."Id" AS user_id,
			requester."Username" AS username,
			requester."AboutMe" AS about_me,
			requester."AvatarUrl" AS avatar_url,
			requester."AvatarScale" AS avatar_scale,
			requester."AvatarOffsetX" AS avatar_offset_x,
			requester."AvatarOffsetY" AS avatar_offset_y,
			fr."CreatedAt" AS created_at
		FROM "FollowRequests" fr
		JOIN "Users" requester ON requester."Id" = fr."RequesterId"
		WHERE fr."TargetUserId" = $1 AND fr."Status" = 0
		ORDER BY fr."CreatedAt" DESC
	`, viewerID); err != nil {
		return nil, err
	}

	items := make([]mobileFriendRequestResponse, 0, len(rows))
	for _, row := range rows {
		items = append(items, mobileFriendRequestResponse{
			ID:            row.ID,
			UserID:        row.UserID,
			Username:      row.Username,
			AboutMe:       nullableString(row.AboutMe),
			AvatarURL:     absoluteStringPointer(r, nullableString(row.AvatarURL)),
			AvatarScale:   row.AvatarScale,
			AvatarOffsetX: row.AvatarOffsetX,
			AvatarOffsetY: row.AvatarOffsetY,
			LastSeenAt:    row.CreatedAt,
			IsOnline:      false,
			IsIncoming:    true,
			CreatedAt:     row.CreatedAt,
		})
	}
	return items, nil
}

func (s *Server) approveFollowRequest(ctx context.Context, viewerID, requestID int) error {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var request struct {
		RequesterID int `db:"requester_id"`
		TargetID    int `db:"target_id"`
	}
	if err := tx.GetContext(ctx, &request, `
		SELECT "RequesterId" AS requester_id, "TargetUserId" AS target_id
		FROM "FollowRequests"
		WHERE "Id" = $1 AND "TargetUserId" = $2 AND "Status" = 0
	`, requestID, viewerID); err != nil {
		return err
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE "FollowRequests"
		SET "Status" = 1, "UpdatedAt" = NOW(), "ResolvedAt" = NOW()
		WHERE "Id" = $1
	`, requestID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO "Follows" ("FollowerId", "FollowingId", "CreatedAt")
		VALUES ($1, $2, NOW())
		ON CONFLICT ("FollowerId", "FollowingId") DO NOTHING
	`, request.RequesterID, request.TargetID); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Server) rejectFollowRequest(ctx context.Context, viewerID, requestID int) error {
	result, err := s.db.ExecContext(ctx, `
		UPDATE "FollowRequests"
		SET "Status" = 2, "UpdatedAt" = NOW(), "ResolvedAt" = NOW()
		WHERE "Id" = $1 AND "TargetUserId" = $2 AND "Status" = 0
	`, requestID, viewerID)
	if err != nil {
		return err
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func buildMobilePage[T any](items []T, page, pageSize, totalCount int, hasMore bool) mobilePagedResponse[T] {
	totalPages := 0
	if pageSize > 0 && totalCount > 0 {
		totalPages = (totalCount + pageSize - 1) / pageSize
	}
	return mobilePagedResponse[T]{
		Items:       items,
		Page:        page,
		PageSize:    pageSize,
		TotalCount:  totalCount,
		TotalPages:  totalPages,
		HasPrevious: page > 1,
		HasNext:     hasMore || (pageSize > 0 && page*pageSize < totalCount),
	}
}

func computeProfileAccess(profile profileResponse, isOwnProfile bool, status blockStatus) (bool, bool, bool, bool, bool) {
	if isOwnProfile {
		return true, true, true, true, true
	}
	if status.IsBlockedByViewer || status.HasBlockedViewer {
		return false, false, false, false, false
	}

	canViewProfile := profile.ProfileVisibility == "Public" ||
		(profile.ProfileVisibility == "FollowersOnly" && (profile.IsFollowing || profile.IsFriend)) ||
		(profile.ProfileVisibility == "Private" && profile.IsFriend)
	if !profile.IsPrivateAccount {
		canViewProfile = true
	}

	canSendMessages := false
	switch profile.MessagePrivacy {
	case "Everyone":
		canSendMessages = true
	case "Followers":
		canSendMessages = profile.IsFollowing || profile.IsFriend
	case "Friends":
		canSendMessages = profile.IsFriend
	}

	canComment := false
	switch profile.CommentPrivacy {
	case "Everyone":
		canComment = true
	case "Followers":
		canComment = profile.IsFollowing || profile.IsFriend
	case "Friends":
		canComment = profile.IsFriend
	}

	canViewPresence := false
	switch profile.PresenceVisibility {
	case "Everyone":
		canViewPresence = true
	case "Followers":
		canViewPresence = profile.IsFollowing || profile.IsFriend
	case "Friends":
		canViewPresence = profile.IsFriend
	}

	return canViewProfile, canViewProfile, canSendMessages, canComment, canViewPresence
}

func mapMobilePost(r *http.Request, item postResponse) mobilePostResponse {
	return mobilePostResponse{
		ID:                item.ID,
		UserID:            item.UserID,
		Username:          item.Author.Username,
		UserAvatarURL:     absoluteStringPointer(r, item.Author.AvatarURL),
		UserAvatarScale:   item.Author.AvatarScale,
		UserAvatarOffsetX: item.Author.AvatarOffsetX,
		UserAvatarOffsetY: item.Author.AvatarOffsetY,
		Content:           item.Content,
		ImageURL:          absoluteStringPointer(r, item.ImageURL),
		CreatedAt:         item.CreatedAt,
		LikesCount:        item.LikesCount,
		CommentsCount:     item.CommentsCount,
		IsLiked:           item.IsLiked,
		IsFollowingAuthor: item.IsFollowingAuthor,
		CanComment:        true,
	}
}

func mapMobilePosts(r *http.Request, items []postResponse) []mobilePostResponse {
	result := make([]mobilePostResponse, 0, len(items))
	for _, item := range items {
		result = append(result, mapMobilePost(r, item))
	}
	return result
}

func mapMobileComment(r *http.Request, item commentResponse) mobileCommentResponse {
	return mobileCommentResponse{
		ID:                item.ID,
		UserID:            item.UserID,
		Username:          item.Author.Username,
		UserAvatarURL:     absoluteStringPointer(r, item.Author.AvatarURL),
		UserAvatarScale:   item.Author.AvatarScale,
		UserAvatarOffsetX: item.Author.AvatarOffsetX,
		UserAvatarOffsetY: item.Author.AvatarOffsetY,
		Content:           item.Content,
		CreatedAt:         item.CreatedAt,
		EditedAt:          item.EditedAt,
		ParentCommentID:   item.ParentCommentID,
		ReplyToUsername:   item.ReplyToUsername,
	}
}

func mapMobileComments(r *http.Request, items []commentResponse) []mobileCommentResponse {
	result := make([]mobileCommentResponse, 0, len(items))
	for _, item := range items {
		result = append(result, mapMobileComment(r, item))
	}
	return result
}

func mapMobileDiscoverUsers(r *http.Request, items []friendCard) []mobileDiscoverUserResponse {
	result := make([]mobileDiscoverUserResponse, 0, len(items))
	for _, item := range items {
		canViewProfile := !item.IsPrivateAccount || item.ProfileVisibility == "Public" || item.IsFriend || item.IsFollowing
		result = append(result, mobileDiscoverUserResponse{
			ID:                 item.ID,
			Username:           item.Username,
			AboutMe:            item.AboutMe,
			AvatarURL:          absoluteStringPointer(r, item.AvatarURL),
			AvatarScale:        item.AvatarScale,
			AvatarOffsetX:      item.AvatarOffsetX,
			AvatarOffsetY:      item.AvatarOffsetY,
			LastSeenAt:         item.LastSeenAt,
			IsOnline:           item.IsOnline,
			FollowersCount:     item.FollowersCount,
			PostsCount:         item.PostsCount,
			MutualFriendsCount: 0,
			EngagementScore:    0,
			IsFollowing:        item.IsFollowing,
			IsFriend:           item.IsFriend,
			IncomingRequestID:  item.IncomingRequestID,
			OutgoingRequestID:  item.OutgoingRequestID,
			IsPrivateAccount:   item.IsPrivateAccount,
			ProfileVisibility:  item.ProfileVisibility,
			CanViewProfile:     canViewProfile,
			CanSendMessages:    item.IsFriend || item.IsFollowing || !item.IsPrivateAccount,
			HasPendingFollow:   item.HasPendingFollow,
		})
	}
	return result
}

func mapMobileFriends(r *http.Request, items []friendCard) []mobileFriendResponse {
	result := make([]mobileFriendResponse, 0, len(items))
	for _, item := range items {
		result = append(result, mobileFriendResponse{
			ID:            item.ID,
			Username:      item.Username,
			AboutMe:       item.AboutMe,
			AvatarURL:     absoluteStringPointer(r, item.AvatarURL),
			AvatarScale:   item.AvatarScale,
			AvatarOffsetX: item.AvatarOffsetX,
			AvatarOffsetY: item.AvatarOffsetY,
			LastSeenAt:    item.LastSeenAt,
			IsOnline:      item.IsOnline,
		})
	}
	return result
}

func mapMobileFriendRequests(r *http.Request, items []friendRequestResponse) []mobileFriendRequestResponse {
	result := make([]mobileFriendRequestResponse, 0, len(items))
	for _, item := range items {
		result = append(result, mobileFriendRequestResponse{
			ID:            item.ID,
			UserID:        item.UserID,
			Username:      item.User.Username,
			AboutMe:       item.AboutMe,
			AvatarURL:     absoluteStringPointer(r, item.User.AvatarURL),
			AvatarScale:   item.User.AvatarScale,
			AvatarOffsetX: item.User.AvatarOffsetX,
			AvatarOffsetY: item.User.AvatarOffsetY,
			LastSeenAt:    valueOrEpoch(item.User.LastSeenAt),
			IsOnline:      item.User.IsOnline,
			IsIncoming:    item.IsIncoming,
			CreatedAt:     item.CreatedAt,
		})
	}
	return result
}

func mapMobileNotifications(r *http.Request, items []notificationResponse) []mobileNotificationResponse {
	result := make([]mobileNotificationResponse, 0, len(items))
	for _, item := range items {
		var actorUserID *int
		var actorUsername *string
		var actorAvatarURL *string
		avatarScale := 1.0
		avatarOffsetX := 0.0
		avatarOffsetY := 0.0
		if item.Actor != nil {
			actorUserID = &item.Actor.ID
			username := item.Actor.Username
			actorUsername = &username
			actorAvatarURL = absoluteStringPointer(r, item.Actor.AvatarURL)
			avatarScale = item.Actor.AvatarScale
			avatarOffsetX = item.Actor.AvatarOffsetX
			avatarOffsetY = item.Actor.AvatarOffsetY
		}
		result = append(result, mobileNotificationResponse{
			ID:                 item.ID,
			Type:               item.Type,
			Text:               item.Text,
			IsRead:             item.IsRead,
			CreatedAt:          item.CreatedAt,
			ActorUserID:        actorUserID,
			ActorUsername:      actorUsername,
			ActorAvatarURL:     actorAvatarURL,
			ActorAvatarScale:   avatarScale,
			ActorAvatarOffsetX: avatarOffsetX,
			ActorAvatarOffsetY: avatarOffsetY,
			PostID:             item.PostID,
			CommentID:          item.CommentID,
			ConversationID:     item.ConversationID,
			MessageID:          item.MessageID,
			RelatedUserID:      item.RelatedUserID,
		})
	}
	return result
}

func stringValue(value *string, fallback *string) any {
	if value == nil {
		return fallback
	}
	trimmed := strings.TrimSpace(*value)
	if trimmed == "" {
		return nil
	}
	return trimmed
}

func floatValue(value *float64, fallback float64) float64 {
	if value == nil {
		return fallback
	}
	return *value
}

func boolValue(value *bool) bool {
	return value != nil && *value
}

func parseFormFloatWithDefault(value string, fallback float64) float64 {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return fallback
	}
	parsed, err := strconv.ParseFloat(trimmed, 64)
	if err != nil {
		return fallback
	}
	return parsed
}

func truthyFormValue(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "true", "yes", "on":
		return true
	default:
		return false
	}
}

func usesMultipartForm(r *http.Request) bool {
	return strings.HasPrefix(strings.ToLower(strings.TrimSpace(r.Header.Get("Content-Type"))), "multipart/form-data")
}

func absoluteStringPointer(r *http.Request, value *string) *string {
	if value == nil {
		return nil
	}
	absolute := absoluteURL(r, *value)
	return &absolute
}

func absoluteURL(r *http.Request, raw string) string {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return ""
	}
	parsed, err := url.Parse(trimmed)
	if err == nil && parsed.IsAbs() {
		return trimmed
	}
	if !strings.HasPrefix(trimmed, "/") || r == nil {
		return trimmed
	}
	return requestScheme(r) + "://" + r.Host + trimmed
}

func requestScheme(r *http.Request) string {
	if r == nil {
		return "http"
	}
	if forwarded := strings.TrimSpace(r.Header.Get("X-Forwarded-Proto")); forwarded != "" {
		return forwarded
	}
	if r.TLS != nil {
		return "https"
	}
	return "http"
}

func valueOrEpoch(value *time.Time) time.Time {
	if value == nil {
		return time.Unix(0, 0).UTC()
	}
	return *value
}

type savedAttachment struct {
	FileName     string
	RelativePath string
	ContentType  string
	SizeBytes    int64
	IsImage      bool
}

func saveUploadedFile(category string, file multipart.File, header *multipart.FileHeader) (string, error) {
	saved, err := saveUploadedFileInternal(category, file, header)
	if err != nil {
		return "", err
	}
	return saved.RelativePath, nil
}

func saveUploadedFileHeader(category string, header *multipart.FileHeader) (savedAttachment, error) {
	file, err := header.Open()
	if err != nil {
		return savedAttachment{}, err
	}
	defer file.Close()
	return saveUploadedFileInternal(category, file, header)
}

func saveUploadedFileInternal(category string, file io.Reader, header *multipart.FileHeader) (savedAttachment, error) {
	safeCategory := strings.Trim(strings.ToLower(category), "/\\ ")
	if safeCategory == "" {
		safeCategory = "misc"
	}
	uploadsDir := filepath.Join("uploads", safeCategory)
	if err := os.MkdirAll(uploadsDir, 0o755); err != nil {
		return savedAttachment{}, err
	}

	extension := strings.ToLower(filepath.Ext(header.Filename))
	if extension == "" {
		extension = ".bin"
	}
	fileName := uuid.NewString() + extension
	fullPath := filepath.Join(uploadsDir, fileName)
	target, err := os.Create(fullPath)
	if err != nil {
		return savedAttachment{}, err
	}
	defer target.Close()

	written, err := io.Copy(target, file)
	if err != nil {
		return savedAttachment{}, err
	}
	contentType := strings.TrimSpace(header.Header.Get("Content-Type"))
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	return savedAttachment{
		FileName:     header.Filename,
		RelativePath: "/" + filepath.ToSlash(filepath.Join("uploads", safeCategory, fileName)),
		ContentType:  contentType,
		SizeBytes:    written,
		IsImage:      strings.HasPrefix(strings.ToLower(contentType), "image/"),
	}, nil
}

func (s *Server) mapMobileConversations(r *http.Request, viewerID int, items []conversationResponse) []mobileConversationResponse {
	result := make([]mobileConversationResponse, 0, len(items))
	for _, item := range items {
		status, _ := s.loadUserBlockStatus(context.Background(), viewerID, item.Peer.ID)
		result = append(result, mobileConversationResponse{
			ID:                           item.ID,
			PeerID:                       item.Peer.ID,
			Username:                     item.Peer.Username,
			AvatarURL:                    absoluteStringPointer(r, item.Peer.AvatarURL),
			AvatarScale:                  item.Peer.AvatarScale,
			AvatarOffsetX:                item.Peer.AvatarOffsetX,
			AvatarOffsetY:                item.Peer.AvatarOffsetY,
			LastSeenAt:                   valueOrEpoch(item.Peer.LastSeenAt),
			IsOnline:                     item.Peer.IsOnline,
			PinOrder:                     item.PinOrder,
			IsPinned:                     item.IsPinned,
			IsArchived:                   item.IsArchived,
			IsFavorite:                   item.IsFavorite,
			IsMuted:                      item.IsMuted,
			IsBlockedByViewer:            status.IsBlockedByViewer,
			HasBlockedViewer:             status.HasBlockedViewer,
			LastMessage:                  item.LastMessage,
			LastMessageAt:                item.LastMessageAt,
			LastMessageIsMine:            item.LastMessageIsMine,
			LastMessageIsDeliveredToPeer: item.LastMessageDelivered,
			LastMessageIsReadByPeer:      item.LastMessageRead,
			UnreadCount:                  item.UnreadCount,
			CanSendMessages:              !status.IsBlockedByViewer && !status.HasBlockedViewer,
		})
	}
	return result
}

func mapMobileDirectConversation(r *http.Request, item conversationResponse, status blockStatus) mobileDirectConversationResponse {
	return mobileDirectConversationResponse{
		ID:              item.ID,
		PeerID:          item.Peer.ID,
		Username:        item.Peer.Username,
		AvatarURL:       absoluteStringPointer(r, item.Peer.AvatarURL),
		AvatarScale:     item.Peer.AvatarScale,
		AvatarOffsetX:   item.Peer.AvatarOffsetX,
		AvatarOffsetY:   item.Peer.AvatarOffsetY,
		LastSeenAt:      valueOrEpoch(item.Peer.LastSeenAt),
		IsOnline:        item.Peer.IsOnline,
		CanSendMessages: !status.IsBlockedByViewer && !status.HasBlockedViewer,
	}
}

func (s *Server) loadMessageAttachments(ctx context.Context, r *http.Request, messageIDs []int) (map[int][]mobileAttachmentResponse, error) {
	result := make(map[int][]mobileAttachmentResponse, len(messageIDs))
	if len(messageIDs) == 0 {
		return result, nil
	}

	var builder strings.Builder
	builder.WriteString(`
		SELECT "Id" AS id, "MessageId" AS message_id, "FileName" AS file_name, "FileUrl" AS file_url, "ContentType" AS content_type, "SizeBytes" AS size_bytes, "IsImage" AS is_image
		FROM "MessageAttachments"
		WHERE "MessageId" IN (`)
	args := make([]any, 0, len(messageIDs))
	for index, messageID := range messageIDs {
		if index > 0 {
			builder.WriteString(", ")
		}
		builder.WriteString("$")
		builder.WriteString(strconv.Itoa(index + 1))
		args = append(args, messageID)
	}
	builder.WriteString(`) ORDER BY "Id" ASC`)

	rows := []struct {
		ID          int    `db:"id"`
		MessageID   int    `db:"message_id"`
		FileName    string `db:"file_name"`
		FileURL     string `db:"file_url"`
		ContentType string `db:"content_type"`
		SizeBytes   int64  `db:"size_bytes"`
		IsImage     bool   `db:"is_image"`
	}{}
	if err := s.db.SelectContext(ctx, &rows, builder.String(), args...); err != nil {
		return nil, err
	}
	for _, row := range rows {
		result[row.MessageID] = append(result[row.MessageID], mobileAttachmentResponse{
			ID:          row.ID,
			FileName:    row.FileName,
			FileURL:     absoluteURL(r, row.FileURL),
			ContentType: row.ContentType,
			SizeBytes:   row.SizeBytes,
			IsImage:     row.IsImage,
		})
	}
	return result, nil
}

func (s *Server) loadMobileMessages(ctx context.Context, r *http.Request, viewerID, conversationID, limit int, beforeMessageID *int) (mobileMessagePageResponse, error) {
	var conversation struct {
		UserAID   int          `db:"user_a_id"`
		UserBID   int          `db:"user_b_id"`
		UserARead sql.NullTime `db:"user_a_read_at"`
		UserBRead sql.NullTime `db:"user_b_read_at"`
	}
	if err := s.db.GetContext(ctx, &conversation, `
		SELECT "UserAId" AS user_a_id, "UserBId" AS user_b_id, "UserAReadAt" AS user_a_read_at, "UserBReadAt" AS user_b_read_at
		FROM "Conversations"
		WHERE "Id" = $1 AND ("UserAId" = $2 OR "UserBId" = $2)
	`, conversationID, viewerID); err != nil {
		return mobileMessagePageResponse{}, err
	}

	deleteColumn := `"DeletedForUserA"`
	readColumn := `"UserAReadAt"`
	peerReadAt := nullableTime(conversation.UserBRead)
	if viewerID != conversation.UserAID {
		deleteColumn = `"DeletedForUserB"`
		readColumn = `"UserBReadAt"`
		peerReadAt = nullableTime(conversation.UserARead)
	}

	args := []any{conversationID, limit + 1}
	beforeFilter := ""
	if beforeMessageID != nil {
		beforeFilter = `AND m."Id" < $3`
		args = append(args, *beforeMessageID)
	}

	rows := []struct {
		ID                             int             `db:"id"`
		SenderID                       int             `db:"sender_id"`
		SenderUsername                 string          `db:"sender_username"`
		Content                        string          `db:"content"`
		CreatedAt                      time.Time       `db:"created_at"`
		EditedAt                       sql.NullTime    `db:"edited_at"`
		DeliveredToPeerAt              sql.NullTime    `db:"delivered_to_peer_at"`
		ReplyToMessageID               sql.NullInt64   `db:"reply_to_message_id"`
		ReplyToSenderUsername          sql.NullString  `db:"reply_to_sender_username"`
		ReplyToContent                 sql.NullString  `db:"reply_to_content"`
		ForwardedFromMessageID         sql.NullInt64   `db:"forwarded_from_message_id"`
		ForwardedFromUserID            sql.NullInt64   `db:"forwarded_from_user_id"`
		ForwardedFromSenderUsername    sql.NullString  `db:"forwarded_from_sender_username"`
		ForwardedFromUserAvatarURL     sql.NullString  `db:"forwarded_from_user_avatar_url"`
		ForwardedFromUserAvatarScale   sql.NullFloat64 `db:"forwarded_from_user_avatar_scale"`
		ForwardedFromUserAvatarOffsetX sql.NullFloat64 `db:"forwarded_from_user_avatar_offset_x"`
		ForwardedFromUserAvatarOffsetY sql.NullFloat64 `db:"forwarded_from_user_avatar_offset_y"`
		IsHidden                       bool            `db:"is_hidden"`
		IsRemoved                      bool            `db:"is_removed"`
	}{}

	query := `
		SELECT
			m."Id" AS id,
			m."SenderId" AS sender_id,
			sender."Username" AS sender_username,
			m."Content" AS content,
			m."CreatedAt" AS created_at,
			m."EditedAt" AS edited_at,
			m."DeliveredToPeerAt" AS delivered_to_peer_at,
			m."ReplyToMessageId" AS reply_to_message_id,
			reply_sender."Username" AS reply_to_sender_username,
			reply_message."Content" AS reply_to_content,
			m."ForwardedFromMessageId" AS forwarded_from_message_id,
			m."ForwardedFromUserId" AS forwarded_from_user_id,
			forwarded_user."Username" AS forwarded_from_sender_username,
			forwarded_user."AvatarUrl" AS forwarded_from_user_avatar_url,
			forwarded_user."AvatarScale" AS forwarded_from_user_avatar_scale,
			forwarded_user."AvatarOffsetX" AS forwarded_from_user_avatar_offset_x,
			forwarded_user."AvatarOffsetY" AS forwarded_from_user_avatar_offset_y,
			m."IsHidden" AS is_hidden,
			m."IsRemoved" AS is_removed
		FROM "Messages" m
		JOIN "Users" sender ON sender."Id" = m."SenderId"
		LEFT JOIN "Messages" reply_message ON reply_message."Id" = m."ReplyToMessageId"
		LEFT JOIN "Users" reply_sender ON reply_sender."Id" = reply_message."SenderId"
		LEFT JOIN "Users" forwarded_user ON forwarded_user."Id" = m."ForwardedFromUserId"
		WHERE m."ConversationId" = $1
		  AND m.` + deleteColumn + ` = false
		  AND m."IsHidden" = false
		  AND m."IsRemoved" = false
		  ` + beforeFilter + `
		ORDER BY m."Id" DESC
		LIMIT $2
	`
	if err := s.db.SelectContext(ctx, &rows, query, args...); err != nil {
		return mobileMessagePageResponse{}, err
	}

	hasMore := len(rows) > limit
	if hasMore {
		rows = rows[:limit]
	}

	messageIDs := make([]int, 0, len(rows))
	for _, row := range rows {
		messageIDs = append(messageIDs, row.ID)
	}
	attachmentsByMessage, err := s.loadMessageAttachments(ctx, r, messageIDs)
	if err != nil {
		return mobileMessagePageResponse{}, err
	}

	_, _ = s.db.ExecContext(ctx, `UPDATE "Conversations" SET `+readColumn+` = NOW() WHERE "Id" = $1`, conversationID)
	_, _ = s.db.ExecContext(ctx, `UPDATE "Messages" SET "DeliveredToPeerAt" = COALESCE("DeliveredToPeerAt", NOW()) WHERE "ConversationId" = $1 AND "SenderId" <> $2`, conversationID, viewerID)

	items := make([]mobileMessageResponse, 0, len(rows))
	for index := len(rows) - 1; index >= 0; index-- {
		row := rows[index]
		isMine := row.SenderID == viewerID
		var readByPeerAt *time.Time
		isReadByPeer := false
		if isMine && peerReadAt != nil && !peerReadAt.Before(row.CreatedAt) {
			isReadByPeer = true
			readByPeerAt = peerReadAt
		}
		items = append(items, mobileMessageResponse{
			ID:                             row.ID,
			ConversationID:                 conversationID,
			SenderID:                       row.SenderID,
			SenderUsername:                 row.SenderUsername,
			Content:                        row.Content,
			CreatedAt:                      row.CreatedAt,
			EditedAt:                       nullableTime(row.EditedAt),
			IsMine:                         isMine,
			IsDeliveredToPeer:              row.DeliveredToPeerAt.Valid || !isMine,
			DeliveredToPeerAt:              nullableTime(row.DeliveredToPeerAt),
			IsReadByPeer:                   isReadByPeer,
			ReadByPeerAt:                   readByPeerAt,
			ReplyToMessageID:               nullableInt(row.ReplyToMessageID),
			ReplyToSenderUsername:          nullableString(row.ReplyToSenderUsername),
			ReplyToContent:                 nullableString(row.ReplyToContent),
			ForwardedFromMessageID:         nullableInt(row.ForwardedFromMessageID),
			ForwardedFromUserID:            nullableInt(row.ForwardedFromUserID),
			ForwardedFromSenderUsername:    nullableString(row.ForwardedFromSenderUsername),
			ForwardedFromUserAvatarURL:     absoluteStringPointer(r, nullableString(row.ForwardedFromUserAvatarURL)),
			ForwardedFromUserAvatarScale:   nullableFloat(row.ForwardedFromUserAvatarScale, 1),
			ForwardedFromUserAvatarOffsetX: nullableFloat(row.ForwardedFromUserAvatarOffsetX, 0),
			ForwardedFromUserAvatarOffsetY: nullableFloat(row.ForwardedFromUserAvatarOffsetY, 0),
			Attachments:                    attachmentsByMessage[row.ID],
			IsHidden:                       row.IsHidden,
			IsRemoved:                      row.IsRemoved,
		})
	}

	var nextBeforeID *int
	if hasMore && len(rows) > 0 {
		lastID := rows[len(rows)-1].ID
		nextBeforeID = &lastID
	}
	return mobileMessagePageResponse{Items: items, HasMore: hasMore, NextBeforeMessageID: nextBeforeID}, nil
}

func (s *Server) loadMobileMessageByID(ctx context.Context, r *http.Request, viewerID, conversationID, messageID int) (mobileMessageResponse, error) {
	page, err := s.loadMobileMessages(ctx, r, viewerID, conversationID, 100, nil)
	if err != nil {
		return mobileMessageResponse{}, err
	}
	for _, item := range page.Items {
		if item.ID == messageID {
			return item, nil
		}
	}
	return mobileMessageResponse{}, sql.ErrNoRows
}

func (s *Server) createMobileMessage(ctx context.Context, r *http.Request, viewerID, conversationID int, content string, replyToMessageID, forwardedFromMessageID, forwardedFromUserID *int, attachments []savedAttachment) (mobileMessageResponse, error) {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return mobileMessageResponse{}, err
	}
	defer tx.Rollback()

	var peerID int
	if err := tx.GetContext(ctx, &peerID, `
		SELECT CASE WHEN "UserAId" = $2 THEN "UserBId" ELSE "UserAId" END
		FROM "Conversations"
		WHERE "Id" = $1 AND ("UserAId" = $2 OR "UserBId" = $2)
	`, conversationID, viewerID); err != nil {
		return mobileMessageResponse{}, err
	}

	var messageID int
	if err := tx.GetContext(ctx, &messageID, `
		INSERT INTO "Messages" ("ConversationId", "SenderId", "Content", "CreatedAt", "ReplyToMessageId", "ForwardedFromMessageId", "ForwardedFromUserId")
		VALUES ($1, $2, $3, NOW(), $4, $5, $6)
		RETURNING "Id"
	`, conversationID, viewerID, content, replyToMessageID, forwardedFromMessageID, forwardedFromUserID); err != nil {
		return mobileMessageResponse{}, err
	}

	for _, attachment := range attachments {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO "MessageAttachments" ("MessageId", "FileName", "FileUrl", "ContentType", "SizeBytes", "IsImage")
			VALUES ($1, $2, $3, $4, $5, $6)
		`, messageID, attachment.FileName, attachment.RelativePath, attachment.ContentType, attachment.SizeBytes, attachment.IsImage); err != nil {
			return mobileMessageResponse{}, err
		}
	}

	if _, err := tx.ExecContext(ctx, `UPDATE "Conversations" SET "UpdatedAt" = NOW(), "UserADeleted" = false, "UserBDeleted" = false WHERE "Id" = $1`, conversationID); err != nil {
		return mobileMessageResponse{}, err
	}
	_ = s.insertNotificationTx(ctx, tx, peerID, &viewerID, "message", "sent you a new message", nil, nil, &conversationID, &messageID, &viewerID)
	if err := tx.Commit(); err != nil {
		return mobileMessageResponse{}, err
	}
	return s.loadMobileMessageByID(ctx, r, viewerID, conversationID, messageID)
}

func (s *Server) loadMessageForForward(ctx context.Context, messageID int) (*int, string, []savedAttachment, error) {
	var row struct {
		Content             string        `db:"content"`
		SenderID            int           `db:"sender_id"`
		ForwardedFromUserID sql.NullInt64 `db:"forwarded_from_user_id"`
	}
	if err := s.db.GetContext(ctx, &row, `SELECT "Content" AS content, "SenderId" AS sender_id, "ForwardedFromUserId" AS forwarded_from_user_id FROM "Messages" WHERE "Id" = $1`, messageID); err != nil {
		return nil, "", nil, err
	}
	attachmentRows := []struct {
		FileName    string `db:"file_name"`
		FileURL     string `db:"file_url"`
		ContentType string `db:"content_type"`
		SizeBytes   int64  `db:"size_bytes"`
		IsImage     bool   `db:"is_image"`
	}{}
	if err := s.db.SelectContext(ctx, &attachmentRows, `SELECT "FileName" AS file_name, "FileUrl" AS file_url, "ContentType" AS content_type, "SizeBytes" AS size_bytes, "IsImage" AS is_image FROM "MessageAttachments" WHERE "MessageId" = $1 ORDER BY "Id" ASC`, messageID); err != nil {
		return nil, "", nil, err
	}
	attachments := make([]savedAttachment, 0, len(attachmentRows))
	for _, rowAttachment := range attachmentRows {
		attachments = append(attachments, savedAttachment{
			FileName:     rowAttachment.FileName,
			RelativePath: rowAttachment.FileURL,
			ContentType:  rowAttachment.ContentType,
			SizeBytes:    rowAttachment.SizeBytes,
			IsImage:      rowAttachment.IsImage,
		})
	}
	originalUserID := row.SenderID
	if row.ForwardedFromUserID.Valid {
		originalUserID = int(row.ForwardedFromUserID.Int64)
	}
	return &originalUserID, row.Content, attachments, nil
}

func (s *Server) viewerMessageDeleteColumn(ctx context.Context, conversationID, viewerID int) (string, error) {
	var userAID int
	if err := s.db.GetContext(ctx, &userAID, `SELECT "UserAId" FROM "Conversations" WHERE "Id" = $1 AND ("UserAId" = $2 OR "UserBId" = $2)`, conversationID, viewerID); err != nil {
		return "", err
	}
	if userAID == viewerID {
		return `"DeletedForUserA"`, nil
	}
	return `"DeletedForUserB"`, nil
}

func (s *Server) updateConversationBoolFlag(ctx context.Context, viewerID, conversationID int, value bool, userAColumn, userBColumn string) error {
	var userAID int
	if err := s.db.GetContext(ctx, &userAID, `SELECT "UserAId" FROM "Conversations" WHERE "Id" = $1 AND ("UserAId" = $2 OR "UserBId" = $2)`, conversationID, viewerID); err != nil {
		return err
	}
	column := userAColumn
	if userAID != viewerID {
		column = userBColumn
	}
	_, err := s.db.ExecContext(ctx, `UPDATE "Conversations" SET `+column+` = $2 WHERE "Id" = $1`, conversationID, value)
	return err
}

func (s *Server) updateConversationPin(ctx context.Context, viewerID, conversationID int, isPinned bool) error {
	var userAID int
	if err := s.db.GetContext(ctx, &userAID, `SELECT "UserAId" FROM "Conversations" WHERE "Id" = $1 AND ("UserAId" = $2 OR "UserBId" = $2)`, conversationID, viewerID); err != nil {
		return err
	}
	column := `"UserAPinOrder"`
	if userAID != viewerID {
		column = `"UserBPinOrder"`
	}
	if !isPinned {
		_, err := s.db.ExecContext(ctx, `UPDATE "Conversations" SET `+column+` = NULL WHERE "Id" = $1`, conversationID)
		return err
	}
	var nextOrder int
	if err := s.db.GetContext(ctx, &nextOrder, `SELECT COALESCE(MAX(`+column+`), 0) + 1 FROM "Conversations" WHERE ("UserAId" = $1 OR "UserBId" = $1)`, viewerID); err != nil {
		return err
	}
	_, err := s.db.ExecContext(ctx, `UPDATE "Conversations" SET `+column+` = $2 WHERE "Id" = $1`, conversationID, nextOrder)
	return err
}

func (s *Server) deleteConversationForUser(ctx context.Context, viewerID, conversationID int, deleteForBoth bool) error {
	var userAID int
	if err := s.db.GetContext(ctx, &userAID, `SELECT "UserAId" FROM "Conversations" WHERE "Id" = $1 AND ("UserAId" = $2 OR "UserBId" = $2)`, conversationID, viewerID); err != nil {
		return err
	}
	userDeletedColumn := `"UserADeleted"`
	messageDeletedColumn := `"DeletedForUserA"`
	if userAID != viewerID {
		userDeletedColumn = `"UserBDeleted"`
		messageDeletedColumn = `"DeletedForUserB"`
	}
	if deleteForBoth {
		if _, err := s.db.ExecContext(ctx, `UPDATE "Conversations" SET "UserADeleted" = true, "UserBDeleted" = true WHERE "Id" = $1`, conversationID); err != nil {
			return err
		}
		_, err := s.db.ExecContext(ctx, `UPDATE "Messages" SET "DeletedForUserA" = true, "DeletedForUserB" = true WHERE "ConversationId" = $1`, conversationID)
		return err
	}
	if _, err := s.db.ExecContext(ctx, `UPDATE "Conversations" SET `+userDeletedColumn+` = true WHERE "Id" = $1`, conversationID); err != nil {
		return err
	}
	_, err := s.db.ExecContext(ctx, `UPDATE "Messages" SET `+messageDeletedColumn+` = true WHERE "ConversationId" = $1`, conversationID)
	return err
}

func (s *Server) loadBlockedUsers(ctx context.Context, r *http.Request, viewerID int) ([]mobileFriendResponse, error) {
	rows := []struct {
		ID            int            `db:"id"`
		Username      string         `db:"username"`
		AboutMe       sql.NullString `db:"about_me"`
		AvatarURL     sql.NullString `db:"avatar_url"`
		AvatarScale   float64        `db:"avatar_scale"`
		AvatarOffsetX float64        `db:"avatar_offset_x"`
		AvatarOffsetY float64        `db:"avatar_offset_y"`
		LastSeenAt    time.Time      `db:"last_seen_at"`
	}{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT u."Id" AS id, u."Username" AS username, u."AboutMe" AS about_me, u."AvatarUrl" AS avatar_url,
		       u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x, u."AvatarOffsetY" AS avatar_offset_y,
		       u."LastSeenAt" AS last_seen_at
		FROM "UserBlocks" b
		JOIN "Users" u ON u."Id" = b."BlockedUserId"
		WHERE b."BlockerId" = $1
		ORDER BY b."CreatedAt" DESC
	`, viewerID); err != nil {
		return nil, err
	}
	items := make([]mobileFriendResponse, 0, len(rows))
	for _, row := range rows {
		items = append(items, mobileFriendResponse{
			ID:            row.ID,
			Username:      row.Username,
			AboutMe:       nullableString(row.AboutMe),
			AvatarURL:     absoluteStringPointer(r, nullableString(row.AvatarURL)),
			AvatarScale:   row.AvatarScale,
			AvatarOffsetX: row.AvatarOffsetX,
			AvatarOffsetY: row.AvatarOffsetY,
			LastSeenAt:    row.LastSeenAt,
			IsOnline:      isOnline(row.LastSeenAt),
		})
	}
	return items, nil
}

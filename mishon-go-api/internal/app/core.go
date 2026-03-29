package app

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/mail"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/jmoiron/sqlx"
	"golang.org/x/crypto/bcrypt"

	"mishon/mishon-go-api/internal/config"
)

type Server struct {
	cfg config.Config
	db  *sqlx.DB
}

type authClaims struct {
	UserID    int    `json:"uid"`
	Username  string `json:"username"`
	Email     string `json:"email"`
	Role      string `json:"role"`
	SessionID string `json:"sid"`
	jwt.RegisteredClaims
}

type sessionUser struct {
	ID        int
	Username  string
	Email     string
	Role      string
	SessionID uuid.UUID
}

type contextKey string

const authContextKey contextKey = "mishon-auth-user"

type apiError struct {
	Message string `json:"message"`
}

type authRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type refreshRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type updateProfileRequest struct {
	DisplayName        string `json:"displayName"`
	Username           string `json:"username"`
	AboutMe            string `json:"aboutMe"`
	IsPrivateAccount   bool   `json:"isPrivateAccount"`
	ProfileVisibility  string `json:"profileVisibility"`
	MessagePrivacy     string `json:"messagePrivacy"`
	CommentPrivacy     string `json:"commentPrivacy"`
	PresenceVisibility string `json:"presenceVisibility"`
	AvatarURL          string `json:"avatarUrl"`
	BannerURL          string `json:"bannerUrl"`
}

type createFriendRequestRequest struct {
	UserID int `json:"userId"`
}

type createPostRequest struct {
	Content  string `json:"content"`
	ImageURL string `json:"imageUrl"`
}

type updatePostRequest struct {
	Content  string `json:"content"`
	ImageURL string `json:"imageUrl"`
}

type createCommentRequest struct {
	Content         string `json:"content"`
	ParentCommentID *int   `json:"parentCommentId"`
}

type createMessageRequest struct {
	Content string `json:"content"`
}

type authResponse struct {
	UserID               int       `json:"userId"`
	Username             string    `json:"username"`
	Email                string    `json:"email"`
	Token                string    `json:"token"`
	AccessTokenExpiresAt time.Time `json:"accessTokenExpiresAt"`
	RefreshToken         string    `json:"refreshToken"`
	RefreshTokenExpiry   time.Time `json:"refreshTokenExpiry"`
	SessionID            string    `json:"sessionId"`
	EmailVerified        bool      `json:"emailVerified"`
	RequiresVerification bool      `json:"requiresEmailVerification"`
	Role                 string    `json:"role"`
}

type profileResponse struct {
	ID                 int       `json:"id"`
	Username           string    `json:"username"`
	Email              string    `json:"email"`
	DisplayName        *string   `json:"displayName,omitempty"`
	AboutMe            *string   `json:"aboutMe,omitempty"`
	AvatarURL          *string   `json:"avatarUrl,omitempty"`
	BannerURL          *string   `json:"bannerUrl,omitempty"`
	AvatarScale        float64   `json:"avatarScale"`
	AvatarOffsetX      float64   `json:"avatarOffsetX"`
	AvatarOffsetY      float64   `json:"avatarOffsetY"`
	BannerScale        float64   `json:"bannerScale"`
	BannerOffsetX      float64   `json:"bannerOffsetX"`
	BannerOffsetY      float64   `json:"bannerOffsetY"`
	CreatedAt          time.Time `json:"createdAt"`
	LastSeenAt         time.Time `json:"lastSeenAt"`
	IsOnline           bool      `json:"isOnline"`
	FollowersCount     int       `json:"followersCount"`
	FollowingCount     int       `json:"followingCount"`
	PostsCount         int       `json:"postsCount"`
	IsFollowing        bool      `json:"isFollowing"`
	IsFriend           bool      `json:"isFriend"`
	HasPendingFollow   bool      `json:"hasPendingFollowRequest"`
	EmailVerified      bool      `json:"emailVerified"`
	Role               string    `json:"role"`
	IsPrivateAccount   bool      `json:"isPrivateAccount"`
	ProfileVisibility  string    `json:"profileVisibility"`
	MessagePrivacy     string    `json:"messagePrivacy"`
	CommentPrivacy     string    `json:"commentPrivacy"`
	PresenceVisibility string    `json:"presenceVisibility"`
}

type userPreview struct {
	ID            int        `json:"id"`
	Username      string     `json:"username"`
	DisplayName   *string    `json:"displayName,omitempty"`
	AvatarURL     *string    `json:"avatarUrl,omitempty"`
	AvatarScale   float64    `json:"avatarScale"`
	AvatarOffsetX float64    `json:"avatarOffsetX"`
	AvatarOffsetY float64    `json:"avatarOffsetY"`
	LastSeenAt    *time.Time `json:"lastSeenAt,omitempty"`
	IsOnline      bool       `json:"isOnline"`
}

type postResponse struct {
	ID                int         `json:"id"`
	UserID            int         `json:"userId"`
	Author            userPreview `json:"author"`
	Content           string      `json:"content"`
	ImageURL          *string     `json:"imageUrl,omitempty"`
	CreatedAt         time.Time   `json:"createdAt"`
	LikesCount        int         `json:"likesCount"`
	CommentsCount     int         `json:"commentsCount"`
	IsLiked           bool        `json:"isLiked"`
	IsFollowingAuthor bool        `json:"isFollowingAuthor"`
}

type commentResponse struct {
	ID              int         `json:"id"`
	PostID          int         `json:"postId"`
	UserID          int         `json:"userId"`
	Author          userPreview `json:"author"`
	Content         string      `json:"content"`
	CreatedAt       time.Time   `json:"createdAt"`
	EditedAt        *time.Time  `json:"editedAt,omitempty"`
	ParentCommentID *int        `json:"parentCommentId,omitempty"`
	ReplyToUsername *string     `json:"replyToUsername,omitempty"`
}

type conversationResponse struct {
	ID                   int         `json:"id"`
	Peer                 userPreview `json:"peer"`
	PinOrder             *int        `json:"pinOrder,omitempty"`
	IsPinned             bool        `json:"isPinned"`
	IsArchived           bool        `json:"isArchived"`
	IsFavorite           bool        `json:"isFavorite"`
	IsMuted              bool        `json:"isMuted"`
	LastMessage          *string     `json:"lastMessage,omitempty"`
	LastMessageAt        *time.Time  `json:"lastMessageAt,omitempty"`
	LastMessageIsMine    bool        `json:"lastMessageIsMine"`
	LastMessageDelivered bool        `json:"lastMessageDelivered"`
	LastMessageRead      bool        `json:"lastMessageRead"`
	UnreadCount          int         `json:"unreadCount"`
}

type messageResponse struct {
	ID             int         `json:"id"`
	ConversationID int         `json:"conversationId"`
	Sender         userPreview `json:"sender"`
	Content        string      `json:"content"`
	CreatedAt      time.Time   `json:"createdAt"`
	EditedAt       *time.Time  `json:"editedAt,omitempty"`
	IsMine         bool        `json:"isMine"`
}

type friendCard struct {
	ID                int       `json:"id"`
	Username          string    `json:"username"`
	DisplayName       *string   `json:"displayName,omitempty"`
	AboutMe           *string   `json:"aboutMe,omitempty"`
	AvatarURL         *string   `json:"avatarUrl,omitempty"`
	AvatarScale       float64   `json:"avatarScale"`
	AvatarOffsetX     float64   `json:"avatarOffsetX"`
	AvatarOffsetY     float64   `json:"avatarOffsetY"`
	LastSeenAt        time.Time `json:"lastSeenAt"`
	IsOnline          bool      `json:"isOnline"`
	FollowersCount    int       `json:"followersCount"`
	PostsCount        int       `json:"postsCount"`
	IsFollowing       bool      `json:"isFollowing"`
	IsFriend          bool      `json:"isFriend"`
	IncomingRequestID *int      `json:"incomingFriendRequestId,omitempty"`
	OutgoingRequestID *int      `json:"outgoingFriendRequestId,omitempty"`
	HasPendingFollow  bool      `json:"hasPendingFollowRequest"`
	IsPrivateAccount  bool      `json:"isPrivateAccount"`
	ProfileVisibility string    `json:"profileVisibility"`
}

type friendRequestResponse struct {
	ID         int         `json:"id"`
	UserID     int         `json:"userId"`
	User       userPreview `json:"user"`
	AboutMe    *string     `json:"aboutMe,omitempty"`
	IsIncoming bool        `json:"isIncoming"`
	CreatedAt  time.Time   `json:"createdAt"`
}

type friendRequestsPayload struct {
	Incoming []friendRequestResponse `json:"incoming"`
	Outgoing []friendRequestResponse `json:"outgoing"`
}

type followToggleResponse struct {
	IsFollowing    bool `json:"isFollowing"`
	FollowersCount int  `json:"followersCount"`
	IsRequested    bool `json:"isRequested"`
	RequestID      *int `json:"requestId,omitempty"`
}

type notificationResponse struct {
	ID             int          `json:"id"`
	Type           string       `json:"type"`
	Text           string       `json:"text"`
	IsRead         bool         `json:"isRead"`
	CreatedAt      time.Time    `json:"createdAt"`
	Actor          *userPreview `json:"actor,omitempty"`
	PostID         *int         `json:"postId,omitempty"`
	CommentID      *int         `json:"commentId,omitempty"`
	ConversationID *int         `json:"conversationId,omitempty"`
	MessageID      *int         `json:"messageId,omitempty"`
	RelatedUserID  *int         `json:"relatedUserId,omitempty"`
}

type notificationSummary struct {
	UnreadNotifications    int `json:"unreadNotifications"`
	UnreadChats            int `json:"unreadChats"`
	IncomingFriendRequests int `json:"incomingFriendRequests"`
	PendingFollowRequests  int `json:"pendingFollowRequests"`
}

type pagedResponse[T any] struct {
	Items    []T  `json:"items"`
	Page     int  `json:"page"`
	PageSize int  `json:"pageSize"`
	HasMore  bool `json:"hasMore"`
}

func New(cfg config.Config) (*Server, error) {
	db, err := sqlx.Connect("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("connect database: %w", err)
	}

	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(30 * time.Minute)

	return &Server{cfg: cfg, db: db}, nil
}

func (s *Server) Close() error {
	return s.db.Close()
}

func (s *Server) Router() http.Handler {
	router := chi.NewRouter()
	router.Use(middleware.RequestID)
	router.Use(middleware.RealIP)
	router.Use(middleware.Logger)
	router.Use(middleware.Recoverer)
	router.Use(cors.Handler(cors.Options{
		AllowedOrigins:   s.cfg.AllowedOrigins,
		AllowedMethods:   []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	router.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	router.Route("/api/v1", func(r chi.Router) {
		r.Route("/auth", func(r chi.Router) {
			r.Post("/register", s.handleRegister)
			r.Post("/login", s.handleLogin)
			r.Post("/refresh", s.handleRefresh)

			r.Group(func(r chi.Router) {
				r.Use(s.requireAuth)
				r.Get("/me", s.handleMe)
				r.Post("/logout", s.handleLogout)
			})
		})

		r.Group(func(r chi.Router) {
			r.Use(s.requireAuth)
			r.Get("/profile", s.handleProfile)
			r.Put("/profile", s.handleUpdateProfile)
			r.Get("/profile/posts", s.handleProfilePosts)
			r.Get("/feed", s.handleFeed)
			r.Get("/discover", s.handleDiscover)
			r.Post("/posts", s.handleCreatePost)
			r.Patch("/posts/{postID}", s.handleUpdatePost)
			r.Delete("/posts/{postID}", s.handleDeletePost)
			r.Post("/posts/{postID}/like", s.handleToggleLike)
			r.Get("/posts/{postID}/comments", s.handleComments)
			r.Post("/posts/{postID}/comments", s.handleCreateComment)
			r.Get("/chats", s.handleChats)
			r.Post("/chats/direct/{userID}", s.handleCreateOrGetDirectChat)
			r.Get("/chats/{chatID}/messages", s.handleChatMessages)
			r.Post("/chats/{chatID}/messages", s.handleSendMessage)
			r.Get("/friends", s.handleFriends)
			r.Get("/friends/requests", s.handleFriendRequests)
			r.Post("/friends/requests", s.handleSendFriendRequest)
			r.Post("/friends/requests/{requestID}/accept", s.handleAcceptFriendRequest)
			r.Delete("/friends/requests/{requestID}", s.handleDeleteFriendRequest)
			r.Delete("/friends/{userID}", s.handleRemoveFriend)
			r.Post("/follows/{userID}/toggle", s.handleToggleFollow)
			r.Get("/notifications", s.handleNotifications)
			r.Get("/notifications/summary", s.handleNotificationSummary)
			r.Post("/notifications/read-all", s.handleReadAllNotifications)
			r.Post("/notifications/{notificationID}/read", s.handleReadNotification)
		})
	})

	s.registerMobileRoutes(router)
	s.registerStaticRoutes(router)

	return router
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req authRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	username := normalizeUsername(req.Username)
	if !isValidUsername(username) {
		writeError(w, http.StatusBadRequest, "Username must be 5-32 chars and may contain a-z, 0-9, . and _")
		return
	}

	email := normalizeEmail(req.Email)
	if _, err := mail.ParseAddress(email); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid email address")
		return
	}

	if !isValidPassword(req.Password) {
		writeError(w, http.StatusBadRequest, "Password must contain upper, lower case letters and digits")
		return
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to hash password")
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open transaction")
		return
	}
	defer tx.Rollback()

	var user struct {
		ID              int    `db:"id"`
		Username        string `db:"username"`
		Email           string `db:"email"`
		IsEmailVerified bool   `db:"is_email_verified"`
		Role            int    `db:"role"`
	}

	err = tx.GetContext(r.Context(), &user, `
		INSERT INTO "Users" (
			"Username", "NormalizedUsername", "Email", "NormalizedEmail", "PasswordHash",
			"CreatedAt", "LastSeenAt", "Role", "ProfileVisibility", "MessagePrivacy",
			"CommentPrivacy", "PresenceVisibility", "AvatarScale", "BannerScale"
		)
		VALUES ($1, $2, $3, $4, $5, NOW(), NOW(), 0, 0, 2, 0, 0, 1, 1)
		RETURNING "Id" AS id, "Username" AS username, "Email" AS email,
		          "IsEmailVerified" AS is_email_verified, "Role" AS role
	`, username, username, email, email, string(passwordHash))
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			writeError(w, http.StatusConflict, "User with that email or username already exists")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to create account")
		return
	}

	sessionID, refreshToken, refreshExpiry, err := s.createSession(r.Context(), tx, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create session")
		return
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save account")
		return
	}

	token, expiresAt, err := s.issueAccessToken(user.ID, user.Username, user.Email, roleName(user.Role), sessionID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create access token")
		return
	}

	writeJSON(w, http.StatusCreated, authResponse{
		UserID:               user.ID,
		Username:             user.Username,
		Email:                user.Email,
		Token:                token,
		AccessTokenExpiresAt: expiresAt,
		RefreshToken:         refreshToken,
		RefreshTokenExpiry:   refreshExpiry,
		SessionID:            sessionID.String(),
		EmailVerified:        user.IsEmailVerified,
		RequiresVerification: !user.IsEmailVerified,
		Role:                 roleName(user.Role),
	})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req authRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	email := normalizeEmail(req.Email)
	var user struct {
		ID              int    `db:"id"`
		Username        string `db:"username"`
		Email           string `db:"email"`
		PasswordHash    string `db:"password_hash"`
		IsEmailVerified bool   `db:"is_email_verified"`
		Role            int    `db:"role"`
	}
	err := s.db.GetContext(r.Context(), &user, `
		SELECT "Id" AS id, "Username" AS username, "Email" AS email,
		       "PasswordHash" AS password_hash, "IsEmailVerified" AS is_email_verified, "Role" AS role
		FROM "Users"
		WHERE "NormalizedEmail" = $1
		  AND "BannedAt" IS NULL
		  AND ("SuspendedUntil" IS NULL OR "SuspendedUntil" < NOW())
	`, email)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "Invalid email or password")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load account")
		return
	}

	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)) != nil {
		writeError(w, http.StatusUnauthorized, "Invalid email or password")
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open session transaction")
		return
	}
	defer tx.Rollback()

	sessionID, refreshToken, refreshExpiry, err := s.createSession(r.Context(), tx, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create session")
		return
	}

	if _, err := tx.ExecContext(r.Context(), `UPDATE "Users" SET "LastSeenAt" = NOW() WHERE "Id" = $1`, user.ID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update last seen")
		return
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to finish login")
		return
	}

	token, expiresAt, err := s.issueAccessToken(user.ID, user.Username, user.Email, roleName(user.Role), sessionID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create access token")
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		UserID:               user.ID,
		Username:             user.Username,
		Email:                user.Email,
		Token:                token,
		AccessTokenExpiresAt: expiresAt,
		RefreshToken:         refreshToken,
		RefreshTokenExpiry:   refreshExpiry,
		SessionID:            sessionID.String(),
		EmailVerified:        user.IsEmailVerified,
		RequiresVerification: !user.IsEmailVerified,
		Role:                 roleName(user.Role),
	})
}

func (s *Server) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	sessionID, ok := parseStructuredToken(req.RefreshToken)
	if !ok {
		writeError(w, http.StatusUnauthorized, "Invalid refresh token")
		return
	}

	hashed := hashToken(req.RefreshToken)
	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open transaction")
		return
	}
	defer tx.Rollback()

	var session struct {
		ID              uuid.UUID      `db:"id"`
		UserID          int            `db:"user_id"`
		RefreshHash     string         `db:"refresh_hash"`
		PreviousHash    sql.NullString `db:"previous_hash"`
		ExpiresAt       time.Time      `db:"expires_at"`
		RevokedAt       sql.NullTime   `db:"revoked_at"`
		Username        string         `db:"username"`
		Email           string         `db:"email"`
		Role            int            `db:"role"`
		IsEmailVerified bool           `db:"is_email_verified"`
	}
	err = tx.GetContext(r.Context(), &session, `
		SELECT s."Id" AS id, s."UserId" AS user_id, s."RefreshTokenHash" AS refresh_hash,
		       s."PreviousRefreshTokenHash" AS previous_hash, s."ExpiresAt" AS expires_at,
		       s."RevokedAt" AS revoked_at, u."Username" AS username, u."Email" AS email,
		       u."Role" AS role, u."IsEmailVerified" AS is_email_verified
		FROM "UserSessions" s
		JOIN "Users" u ON u."Id" = s."UserId"
		WHERE s."Id" = $1
	`, sessionID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "Refresh token is not valid")
		return
	}

	if session.RevokedAt.Valid || session.ExpiresAt.Before(time.Now().UTC()) {
		writeError(w, http.StatusUnauthorized, "Refresh token expired")
		return
	}

	if session.RefreshHash != hashed && (!session.PreviousHash.Valid || session.PreviousHash.String != hashed) {
		writeError(w, http.StatusUnauthorized, "Refresh token mismatch")
		return
	}

	newRefreshToken := generateStructuredToken(session.ID)
	if _, err := tx.ExecContext(r.Context(), `
		UPDATE "UserSessions"
		SET "PreviousRefreshTokenHash" = "RefreshTokenHash",
		    "RefreshTokenHash" = $2,
		    "LastUsedAt" = NOW()
		WHERE "Id" = $1
	`, session.ID, hashToken(newRefreshToken)); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to rotate refresh token")
		return
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to commit refresh")
		return
	}

	token, expiresAt, err := s.issueAccessToken(session.UserID, session.Username, session.Email, roleName(session.Role), session.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create access token")
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		UserID:               session.UserID,
		Username:             session.Username,
		Email:                session.Email,
		Token:                token,
		AccessTokenExpiresAt: expiresAt,
		RefreshToken:         newRefreshToken,
		RefreshTokenExpiry:   session.ExpiresAt,
		SessionID:            session.ID.String(),
		EmailVerified:        session.IsEmailVerified,
		RequiresVerification: !session.IsEmailVerified,
		Role:                 roleName(session.Role),
	})
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if _, err := s.db.ExecContext(r.Context(), `
		UPDATE "UserSessions"
		SET "RevokedAt" = NOW(), "RevocationReason" = 'logout'
		WHERE "Id" = $1 AND "UserId" = $2
	`, user.SessionID, user.ID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to revoke session")
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	profile, err := s.loadProfile(r.Context(), user.ID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load profile")
		return
	}
	writeJSON(w, http.StatusOK, profile)
}

func (s *Server) handleProfile(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	profile, err := s.loadProfile(r.Context(), user.ID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load profile")
		return
	}
	writeJSON(w, http.StatusOK, profile)
}

func (s *Server) handleUpdateProfile(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req updateProfileRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	username := normalizeUsername(req.Username)
	if !isValidUsername(username) {
		writeError(w, http.StatusBadRequest, "Username must be 5-32 chars and may contain a-z, 0-9, . and _")
		return
	}

	profileVisibility, ok := parsePrivacy(req.ProfileVisibility, map[string]int{"Public": 0, "FollowersOnly": 1, "Private": 2})
	if !ok {
		writeError(w, http.StatusBadRequest, "Unsupported profile visibility")
		return
	}
	messagePrivacy, ok := parsePrivacy(req.MessagePrivacy, map[string]int{"Everyone": 0, "Followers": 1, "Friends": 2, "Nobody": 3})
	if !ok {
		writeError(w, http.StatusBadRequest, "Unsupported message privacy")
		return
	}
	commentPrivacy, ok := parsePrivacy(req.CommentPrivacy, map[string]int{"Everyone": 0, "Followers": 1, "Friends": 2, "Nobody": 3})
	if !ok {
		writeError(w, http.StatusBadRequest, "Unsupported comment privacy")
		return
	}
	presencePrivacy, ok := parsePrivacy(req.PresenceVisibility, map[string]int{"Everyone": 0, "Followers": 1, "Friends": 2, "Nobody": 3})
	if !ok {
		writeError(w, http.StatusBadRequest, "Unsupported presence visibility")
		return
	}

	_, err := s.db.ExecContext(r.Context(), `
		UPDATE "Users"
		SET "DisplayName" = $2, "Username" = $3, "NormalizedUsername" = $4,
		    "AboutMe" = $5, "AvatarUrl" = $6, "BannerUrl" = $7,
		    "IsPrivateAccount" = $8, "ProfileVisibility" = $9, "MessagePrivacy" = $10,
		    "CommentPrivacy" = $11, "PresenceVisibility" = $12
		WHERE "Id" = $1
	`, user.ID, nullStringFromInput(req.DisplayName), username, username, nullStringFromInput(req.AboutMe), nullStringFromInput(req.AvatarURL), nullStringFromInput(req.BannerURL), req.IsPrivateAccount, profileVisibility, messagePrivacy, commentPrivacy, presencePrivacy)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			writeError(w, http.StatusConflict, "Username is already in use")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to update profile")
		return
	}

	profile, err := s.loadProfile(r.Context(), user.ID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to reload profile")
		return
	}
	writeJSON(w, http.StatusOK, profile)
}

func (s *Server) loadProfile(ctx context.Context, viewerID, targetID int) (profileResponse, error) {
	var row struct {
		ID                 int            `db:"id"`
		Username           string         `db:"username"`
		Email              string         `db:"email"`
		DisplayName        sql.NullString `db:"display_name"`
		AboutMe            sql.NullString `db:"about_me"`
		AvatarURL          sql.NullString `db:"avatar_url"`
		BannerURL          sql.NullString `db:"banner_url"`
		AvatarScale        float64        `db:"avatar_scale"`
		AvatarOffsetX      float64        `db:"avatar_offset_x"`
		AvatarOffsetY      float64        `db:"avatar_offset_y"`
		BannerScale        float64        `db:"banner_scale"`
		BannerOffsetX      float64        `db:"banner_offset_x"`
		BannerOffsetY      float64        `db:"banner_offset_y"`
		CreatedAt          time.Time      `db:"created_at"`
		LastSeenAt         time.Time      `db:"last_seen_at"`
		FollowersCount     int            `db:"followers_count"`
		FollowingCount     int            `db:"following_count"`
		PostsCount         int            `db:"posts_count"`
		IsFollowing        bool           `db:"is_following"`
		IsFriend           bool           `db:"is_friend"`
		HasPendingFollow   bool           `db:"has_pending_follow_request"`
		IsEmailVerified    bool           `db:"is_email_verified"`
		Role               int            `db:"role"`
		IsPrivateAccount   bool           `db:"is_private_account"`
		ProfileVisibility  int            `db:"profile_visibility"`
		MessagePrivacy     int            `db:"message_privacy"`
		CommentPrivacy     int            `db:"comment_privacy"`
		PresenceVisibility int            `db:"presence_visibility"`
	}

	err := s.db.GetContext(ctx, &row, `
		SELECT
			u."Id" AS id, u."Username" AS username, u."Email" AS email,
			u."DisplayName" AS display_name, u."AboutMe" AS about_me,
			u."AvatarUrl" AS avatar_url, u."BannerUrl" AS banner_url,
			u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x, u."AvatarOffsetY" AS avatar_offset_y,
			u."BannerScale" AS banner_scale, u."BannerOffsetX" AS banner_offset_x, u."BannerOffsetY" AS banner_offset_y,
			u."CreatedAt" AS created_at, u."LastSeenAt" AS last_seen_at,
			(SELECT COUNT(*) FROM "Follows" f WHERE f."FollowingId" = u."Id") AS followers_count,
			(SELECT COUNT(*) FROM "Follows" f WHERE f."FollowerId" = u."Id") AS following_count,
			(SELECT COUNT(*) FROM "Posts" p WHERE p."UserId" = u."Id" AND p."IsHidden" = false AND p."IsRemoved" = false) AS posts_count,
			EXISTS(SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = u."Id") AS is_following,
			EXISTS(SELECT 1 FROM "Friendships" fr WHERE (fr."UserAId" = $1 AND fr."UserBId" = u."Id") OR (fr."UserBId" = $1 AND fr."UserAId" = u."Id")) AS is_friend,
			EXISTS(SELECT 1 FROM "FollowRequests" fr WHERE fr."RequesterId" = $1 AND fr."TargetUserId" = u."Id" AND fr."Status" = 0) AS has_pending_follow_request,
			u."IsEmailVerified" AS is_email_verified, u."Role" AS role, u."IsPrivateAccount" AS is_private_account,
			u."ProfileVisibility" AS profile_visibility, u."MessagePrivacy" AS message_privacy,
			u."CommentPrivacy" AS comment_privacy, u."PresenceVisibility" AS presence_visibility
		FROM "Users" u
		WHERE u."Id" = $2
	`, viewerID, targetID)
	if err != nil {
		return profileResponse{}, err
	}

	return profileResponse{
		ID:                 row.ID,
		Username:           row.Username,
		Email:              row.Email,
		DisplayName:        nullableString(row.DisplayName),
		AboutMe:            nullableString(row.AboutMe),
		AvatarURL:          nullableString(row.AvatarURL),
		BannerURL:          nullableString(row.BannerURL),
		AvatarScale:        row.AvatarScale,
		AvatarOffsetX:      row.AvatarOffsetX,
		AvatarOffsetY:      row.AvatarOffsetY,
		BannerScale:        row.BannerScale,
		BannerOffsetX:      row.BannerOffsetX,
		BannerOffsetY:      row.BannerOffsetY,
		CreatedAt:          row.CreatedAt,
		LastSeenAt:         row.LastSeenAt,
		IsOnline:           isOnline(row.LastSeenAt),
		FollowersCount:     row.FollowersCount,
		FollowingCount:     row.FollowingCount,
		PostsCount:         row.PostsCount,
		IsFollowing:        row.IsFollowing,
		IsFriend:           row.IsFriend,
		HasPendingFollow:   row.HasPendingFollow,
		EmailVerified:      row.IsEmailVerified,
		Role:               roleName(row.Role),
		IsPrivateAccount:   row.IsPrivateAccount,
		ProfileVisibility:  profileVisibilityName(row.ProfileVisibility),
		MessagePrivacy:     privacyName(row.MessagePrivacy),
		CommentPrivacy:     privacyName(row.CommentPrivacy),
		PresenceVisibility: privacyName(row.PresenceVisibility),
	}, nil
}

func (s *Server) createSession(ctx context.Context, tx *sqlx.Tx, userID int) (uuid.UUID, string, time.Time, error) {
	sessionID := uuid.New()
	refreshToken := generateStructuredToken(sessionID)
	refreshExpiry := time.Now().UTC().Add(s.cfg.RefreshTokenTTL)

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO "UserSessions" ("Id", "UserId", "RefreshTokenHash", "CreatedAt", "LastUsedAt", "ExpiresAt")
		VALUES ($1, $2, $3, NOW(), NOW(), $4)
	`, sessionID, userID, hashToken(refreshToken), refreshExpiry); err != nil {
		return uuid.Nil, "", time.Time{}, err
	}

	return sessionID, refreshToken, refreshExpiry, nil
}

func (s *Server) issueAccessToken(userID int, username, email, role string, sessionID uuid.UUID) (string, time.Time, error) {
	expiresAt := time.Now().UTC().Add(s.cfg.AccessTokenTTL)
	claims := authClaims{
		UserID:    userID,
		Username:  username,
		Email:     email,
		Role:      role,
		SessionID: sessionID.String(),
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   strconv.Itoa(userID),
			Issuer:    s.cfg.JWTIssuer,
			Audience:  jwt.ClaimStrings{s.cfg.JWTAudience},
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			IssuedAt:  jwt.NewNumericDate(time.Now().UTC()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(s.cfg.JWTSecret))
	if err != nil {
		return "", time.Time{}, err
	}

	return signed, expiresAt, nil
}

func (s *Server) requireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := strings.TrimSpace(r.Header.Get("Authorization"))
		if header == "" || !strings.HasPrefix(strings.ToLower(header), "bearer ") {
			writeError(w, http.StatusUnauthorized, "Authorization header is required")
			return
		}

		rawToken := strings.TrimSpace(header[7:])
		token, err := jwt.ParseWithClaims(rawToken, &authClaims{}, func(token *jwt.Token) (any, error) {
			if token.Method != jwt.SigningMethodHS256 {
				return nil, fmt.Errorf("unexpected signing method")
			}
			return []byte(s.cfg.JWTSecret), nil
		}, jwt.WithAudience(s.cfg.JWTAudience), jwt.WithIssuer(s.cfg.JWTIssuer))
		if err != nil {
			writeError(w, http.StatusUnauthorized, "Invalid access token")
			return
		}

		claims, ok := token.Claims.(*authClaims)
		if !ok || !token.Valid {
			writeError(w, http.StatusUnauthorized, "Invalid access token")
			return
		}

		sessionID, err := uuid.Parse(claims.SessionID)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "Invalid session")
			return
		}

		var exists bool
		if err := s.db.GetContext(r.Context(), &exists, `
			SELECT EXISTS(
				SELECT 1
				FROM "UserSessions" s
				JOIN "Users" u ON u."Id" = s."UserId"
				WHERE s."Id" = $1
				  AND s."UserId" = $2
				  AND s."RevokedAt" IS NULL
				  AND s."ExpiresAt" > NOW()
				  AND u."BannedAt" IS NULL
				  AND (u."SuspendedUntil" IS NULL OR u."SuspendedUntil" < NOW())
			)
		`, sessionID, claims.UserID); err != nil || !exists {
			writeError(w, http.StatusUnauthorized, "Session is no longer valid")
			return
		}

		ctx := context.WithValue(r.Context(), authContextKey, sessionUser{
			ID:        claims.UserID,
			Username:  claims.Username,
			Email:     claims.Email,
			Role:      claims.Role,
			SessionID: sessionID,
		})
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func authUser(ctx context.Context) sessionUser {
	value, _ := ctx.Value(authContextKey).(sessionUser)
	return value
}

func decodeJSON(r *http.Request, target any) error {
	defer r.Body.Close()
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return fmt.Errorf("Invalid JSON body")
	}
	return nil
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, apiError{Message: message})
}

func parseIDParam(r *http.Request, key string) (int, error) {
	value := strings.TrimSpace(chi.URLParam(r, key))
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 {
		return 0, fmt.Errorf("Invalid %s", key)
	}
	return parsed, nil
}

func paginationFromRequest(r *http.Request) (int, int) {
	page := clamp(parseIntWithDefault(r.URL.Query().Get("page"), 1), 1, 10000)
	pageSize := clamp(parseIntWithDefault(r.URL.Query().Get("pageSize"), 12), 1, 50)
	return page, pageSize
}

func parseIntWithDefault(value string, fallback int) int {
	parsed, err := strconv.Atoi(strings.TrimSpace(value))
	if err != nil {
		return fallback
	}
	return parsed
}

func parseOptionalInt(value string) *int {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return nil
	}
	parsed, err := strconv.Atoi(trimmed)
	if err != nil {
		return nil
	}
	return &parsed
}

func nullableString(value sql.NullString) *string {
	if !value.Valid || strings.TrimSpace(value.String) == "" {
		return nil
	}
	trimmed := strings.TrimSpace(value.String)
	return &trimmed
}

func nullableTime(value sql.NullTime) *time.Time {
	if !value.Valid {
		return nil
	}
	return &value.Time
}

func nullableInt(value sql.NullInt64) *int {
	if !value.Valid {
		return nil
	}
	parsed := int(value.Int64)
	return &parsed
}

func nullableFloat(value sql.NullFloat64, fallback float64) float64 {
	if !value.Valid {
		return fallback
	}
	return value.Float64
}

func nullStringFromInput(value string) any {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return nil
	}
	return trimmed
}

func normalizeUsername(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}

func normalizeEmail(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}

func isValidUsername(value string) bool {
	if len(value) < 5 || len(value) > 32 {
		return false
	}
	if strings.HasPrefix(value, ".") || strings.HasSuffix(value, ".") || strings.Contains(value, "..") {
		return false
	}

	for _, char := range value {
		isLowercaseLetter := char >= 'a' && char <= 'z'
		isDigit := char >= '0' && char <= '9'
		isSeparator := char == '.' || char == '_'
		if !isLowercaseLetter && !isDigit && !isSeparator {
			return false
		}
	}

	return true
}

func isValidPassword(value string) bool {
	if len(value) < 8 || len(value) > 100 {
		return false
	}

	hasUpper := false
	hasLower := false
	hasDigit := false

	for _, char := range value {
		switch {
		case char >= 'A' && char <= 'Z':
			hasUpper = true
		case char >= 'a' && char <= 'z':
			hasLower = true
		case char >= '0' && char <= '9':
			hasDigit = true
		}
	}

	return hasUpper && hasLower && hasDigit
}

func generateStructuredToken(id uuid.UUID) string {
	bytes := make([]byte, 48)
	_, _ = rand.Read(bytes)
	return id.String() + "." + base64.RawURLEncoding.EncodeToString(bytes)
}

func parseStructuredToken(token string) (uuid.UUID, bool) {
	parts := strings.Split(strings.TrimSpace(token), ".")
	if len(parts) != 2 {
		return uuid.Nil, false
	}
	parsed, err := uuid.Parse(parts[0])
	if err != nil {
		return uuid.Nil, false
	}
	return parsed, true
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

func roleName(value int) string {
	switch value {
	case 1:
		return "Moderator"
	case 2:
		return "Admin"
	default:
		return "User"
	}
}

func profileVisibilityName(value int) string {
	switch value {
	case 1:
		return "FollowersOnly"
	case 2:
		return "Private"
	default:
		return "Public"
	}
}

func privacyName(value int) string {
	switch value {
	case 1:
		return "Followers"
	case 2:
		return "Friends"
	case 3:
		return "Nobody"
	default:
		return "Everyone"
	}
}

func parsePrivacy(value string, lookup map[string]int) (int, bool) {
	normalized := strings.TrimSpace(value)
	if normalized == "" {
		return 0, false
	}
	for key, item := range lookup {
		if strings.EqualFold(key, normalized) {
			return item, true
		}
	}
	return 0, false
}

func isOnline(lastSeenAt time.Time) bool {
	return time.Since(lastSeenAt.UTC()) <= 5*time.Minute
}

func clamp(value, minValue, maxValue int) int {
	if value < minValue {
		return minValue
	}
	if value > maxValue {
		return maxValue
	}
	return value
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

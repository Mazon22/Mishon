package app

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
)

const (
	adminUserFilterAll        = "all"
	adminUserFilterActive     = "active"
	adminUserFilterFrozen     = "frozen"
	adminUserFilterAdmins     = "admins"
	adminUserFilterModerators = "moderators"

	supportStatusWaitingForAdmin = "WaitingForAdmin"
	supportStatusWaitingForUser  = "WaitingForUser"
	supportStatusClosed          = "Closed"
)

type adminFreezeUserRequest struct {
	Until *time.Time `json:"until"`
	Note  string     `json:"note"`
}

type adminHardDeleteUserRequest struct {
	Note string `json:"note"`
}

type supportCreateThreadRequest struct {
	Subject string `json:"subject"`
	Message string `json:"message"`
}

type supportReplyMessageRequest struct {
	Message string `json:"message"`
}

type supportThreadUserResponse struct {
	ID            int        `json:"id"`
	Username      string     `json:"username"`
	DisplayName   *string    `json:"displayName,omitempty"`
	Email         *string    `json:"email,omitempty"`
	Role          string     `json:"role"`
	AvatarURL     *string    `json:"avatarUrl,omitempty"`
	AvatarScale   float64    `json:"avatarScale"`
	AvatarOffsetX float64    `json:"avatarOffsetX"`
	AvatarOffsetY float64    `json:"avatarOffsetY"`
	LastSeenAt    *time.Time `json:"lastSeenAt,omitempty"`
	IsOnline      bool       `json:"isOnline"`
}

type supportThreadSummaryResponse struct {
	ID                  int                        `json:"id"`
	UserID              int                        `json:"userId"`
	Subject             string                     `json:"subject"`
	Status              string                     `json:"status"`
	CreatedAt           time.Time                  `json:"createdAt"`
	UpdatedAt           time.Time                  `json:"updatedAt"`
	LastMessageAt       time.Time                  `json:"lastMessageAt"`
	LastMessagePreview  *string                    `json:"lastMessagePreview,omitempty"`
	LastMessageAuthorID *int                       `json:"lastMessageAuthorUserId,omitempty"`
	AdminUnreadCount    int                        `json:"adminUnreadCount"`
	UserUnreadCount     int                        `json:"userUnreadCount"`
	ClosedAt            *time.Time                 `json:"closedAt,omitempty"`
	ClosedByUserID      *int                       `json:"closedByUserId,omitempty"`
	User                *supportThreadUserResponse `json:"user,omitempty"`
}

type supportMessageResponse struct {
	ID                  int        `json:"id"`
	ThreadID            int        `json:"threadId"`
	AuthorUserID        *int       `json:"authorUserId,omitempty"`
	AuthorUsername      *string    `json:"authorUsername,omitempty"`
	AuthorDisplayName   *string    `json:"authorDisplayName,omitempty"`
	AuthorRole          *string    `json:"authorRole,omitempty"`
	AuthorAvatarURL     *string    `json:"authorAvatarUrl,omitempty"`
	AuthorAvatarScale   float64    `json:"authorAvatarScale"`
	AuthorAvatarOffsetX float64    `json:"authorAvatarOffsetX"`
	AuthorAvatarOffsetY float64    `json:"authorAvatarOffsetY"`
	Content             string     `json:"content"`
	CreatedAt           time.Time  `json:"createdAt"`
	ReadAt              *time.Time `json:"readAt,omitempty"`
	IsMine              bool       `json:"isMine"`
	IsAdminAuthor       bool       `json:"isAdminAuthor"`
}

type supportThreadDetailResponse struct {
	Thread   supportThreadSummaryResponse `json:"thread"`
	Messages []supportMessageResponse     `json:"messages"`
}

type adminUserSummaryResponse struct {
	ID                  int        `json:"id"`
	Username            string     `json:"username"`
	DisplayName         *string    `json:"displayName,omitempty"`
	Email               string     `json:"email"`
	AboutMe             *string    `json:"aboutMe,omitempty"`
	AvatarURL           *string    `json:"avatarUrl,omitempty"`
	AvatarScale         float64    `json:"avatarScale"`
	AvatarOffsetX       float64    `json:"avatarOffsetX"`
	AvatarOffsetY       float64    `json:"avatarOffsetY"`
	BannerURL           *string    `json:"bannerUrl,omitempty"`
	BannerScale         float64    `json:"bannerScale"`
	BannerOffsetX       float64    `json:"bannerOffsetX"`
	BannerOffsetY       float64    `json:"bannerOffsetY"`
	Role                string     `json:"role"`
	IsEmailVerified     bool       `json:"isEmailVerified"`
	CreatedAt           time.Time  `json:"createdAt"`
	LastSeenAt          time.Time  `json:"lastSeenAt"`
	SuspendedUntil      *time.Time `json:"suspendedUntil,omitempty"`
	BannedAt            *time.Time `json:"bannedAt,omitempty"`
	Status              string     `json:"status"`
	PostsCount          int        `json:"postsCount"`
	FollowersCount      int        `json:"followersCount"`
	FollowingCount      int        `json:"followingCount"`
	ActiveSessionsCount int        `json:"activeSessionsCount"`
	OpenSupportThreads  int        `json:"openSupportThreads"`
}

type adminModerationActionSummary struct {
	ID            int        `json:"id"`
	ActionType    string     `json:"actionType"`
	Note          *string    `json:"note,omitempty"`
	CreatedAt     time.Time  `json:"createdAt"`
	ExpiresAt     *time.Time `json:"expiresAt,omitempty"`
	ActorUserID   *int       `json:"actorUserId,omitempty"`
	ActorUsername *string    `json:"actorUsername,omitempty"`
}

type adminUserDetailResponse struct {
	User                    adminUserSummaryResponse        `json:"user"`
	RecentModerationActions []adminModerationActionSummary `json:"recentModerationActions"`
	RecentSupportThreads    []supportThreadSummaryResponse `json:"recentSupportThreads"`
}

type adminUserRow struct {
	ID                  int             `db:"id"`
	Username            string          `db:"username"`
	DisplayName         sql.NullString  `db:"display_name"`
	Email               string          `db:"email"`
	AboutMe             sql.NullString  `db:"about_me"`
	AvatarURL           sql.NullString  `db:"avatar_url"`
	AvatarScale         float64         `db:"avatar_scale"`
	AvatarOffsetX       float64         `db:"avatar_offset_x"`
	AvatarOffsetY       float64         `db:"avatar_offset_y"`
	BannerURL           sql.NullString  `db:"banner_url"`
	BannerScale         float64         `db:"banner_scale"`
	BannerOffsetX       float64         `db:"banner_offset_x"`
	BannerOffsetY       float64         `db:"banner_offset_y"`
	Role                int             `db:"role"`
	IsEmailVerified     bool            `db:"is_email_verified"`
	CreatedAt           time.Time       `db:"created_at"`
	LastSeenAt          time.Time       `db:"last_seen_at"`
	SuspendedUntil      sql.NullTime    `db:"suspended_until"`
	BannedAt            sql.NullTime    `db:"banned_at"`
	PostsCount          int             `db:"posts_count"`
	FollowersCount      int             `db:"followers_count"`
	FollowingCount      int             `db:"following_count"`
	ActiveSessionsCount int             `db:"active_sessions_count"`
	OpenSupportThreads  int             `db:"open_support_threads"`
}

type supportThreadRow struct {
	ID                  int             `db:"id"`
	UserID              int             `db:"user_id"`
	Subject             string          `db:"subject"`
	Status              string          `db:"status"`
	CreatedAt           time.Time       `db:"created_at"`
	UpdatedAt           time.Time       `db:"updated_at"`
	LastMessageAt       time.Time       `db:"last_message_at"`
	LastMessagePreview  sql.NullString  `db:"last_message_preview"`
	LastMessageAuthorID sql.NullInt64   `db:"last_message_author_user_id"`
	AdminUnreadCount    int             `db:"admin_unread_count"`
	UserUnreadCount     int             `db:"user_unread_count"`
	ClosedAt            sql.NullTime    `db:"closed_at"`
	ClosedByUserID      sql.NullInt64   `db:"closed_by_user_id"`
	UserUsername        sql.NullString  `db:"user_username"`
	UserDisplayName     sql.NullString  `db:"user_display_name"`
	UserEmail           sql.NullString  `db:"user_email"`
	UserRole            sql.NullInt64   `db:"user_role"`
	UserAvatarURL       sql.NullString  `db:"user_avatar_url"`
	UserAvatarScale     sql.NullFloat64 `db:"user_avatar_scale"`
	UserAvatarOffsetX   sql.NullFloat64 `db:"user_avatar_offset_x"`
	UserAvatarOffsetY   sql.NullFloat64 `db:"user_avatar_offset_y"`
	UserLastSeenAt      sql.NullTime    `db:"user_last_seen_at"`
}

type supportMessageRow struct {
	ID                  int             `db:"id"`
	ThreadID            int             `db:"thread_id"`
	AuthorUserID        sql.NullInt64   `db:"author_user_id"`
	AuthorUsername      sql.NullString  `db:"author_username"`
	AuthorDisplayName   sql.NullString  `db:"author_display_name"`
	AuthorRole          sql.NullInt64   `db:"author_role"`
	AuthorAvatarURL     sql.NullString  `db:"author_avatar_url"`
	AuthorAvatarScale   sql.NullFloat64 `db:"author_avatar_scale"`
	AuthorAvatarOffsetX sql.NullFloat64 `db:"author_avatar_offset_x"`
	AuthorAvatarOffsetY sql.NullFloat64 `db:"author_avatar_offset_y"`
	Content             string          `db:"content"`
	CreatedAt           time.Time       `db:"created_at"`
	ReadAt              sql.NullTime    `db:"read_at"`
}

func (s *Server) handleAdminUsers(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Admin") {
		writeError(w, http.StatusForbidden, "Admin access is required")
		return
	}

	page, pageSize := adminPaginationFromRequest(r)
	filter := normalizeAdminUserFilter(r.URL.Query().Get("filter"))
	query := normalizeText(r.URL.Query().Get("query"))

	items, totalCount, err := s.loadAdminUsersPage(r.Context(), page, pageSize, filter, query)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load admin users")
		return
	}

	writeJSON(w, http.StatusOK, buildPagedResponse(normalizeAdminUsersMedia(r, items), page, pageSize, totalCount, page*pageSize < totalCount))
}

func (s *Server) handleAdminUserDetail(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Admin") {
		writeError(w, http.StatusForbidden, "Admin access is required")
		return
	}

	targetUserID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	detail, err := s.loadAdminUserDetail(r.Context(), targetUserID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "User not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load admin user detail")
		return
	}

	writeJSON(w, http.StatusOK, normalizeAdminUserDetailMedia(r, detail))
}

func (s *Server) handleAdminFreezeUser(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Admin") {
		writeError(w, http.StatusForbidden, "Admin access is required")
		return
	}

	targetUserID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if targetUserID == user.ID {
		writeError(w, http.StatusForbidden, "You cannot freeze your own account")
		return
	}

	var req adminFreezeUserRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.Until == nil || !req.Until.After(time.Now().UTC()) {
		writeError(w, http.StatusBadRequest, "A future freeze expiry is required")
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open freeze transaction")
		return
	}
	defer tx.Rollback()

	if _, _, _, err := loadManagedUserIdentity(r.Context(), tx, targetUserID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "User not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load target user")
		return
	}

	if _, err := tx.ExecContext(r.Context(), `
		UPDATE "Users"
		SET "SuspendedUntil" = $2
		WHERE "Id" = $1
	`, targetUserID, req.Until.UTC()); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to freeze user")
		return
	}

	if err := revokeUserSessionsTx(r.Context(), tx, targetUserID, "admin_freeze"); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to revoke active sessions")
		return
	}

	if _, err := s.insertModerationAction(r.Context(), tx, user, moderationActionRequest{
		UserID: targetUserID,
		Note:   req.Note,
		Until:  req.Until,
	}, "Freeze"); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to record freeze action")
		return
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to freeze user")
		return
	}

	s.emitAdminUserUpdatedSync(r.Context(), targetUserID)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleAdminUnfreezeUser(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Admin") {
		writeError(w, http.StatusForbidden, "Admin access is required")
		return
	}

	targetUserID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if targetUserID == user.ID {
		writeError(w, http.StatusForbidden, "You cannot unfreeze your own account here")
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open unfreeze transaction")
		return
	}
	defer tx.Rollback()

	if _, _, _, err := loadManagedUserIdentity(r.Context(), tx, targetUserID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "User not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load target user")
		return
	}

	if _, err := tx.ExecContext(r.Context(), `
		UPDATE "Users"
		SET "SuspendedUntil" = NULL
		WHERE "Id" = $1
	`, targetUserID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to unfreeze user")
		return
	}

	if _, err := s.insertModerationAction(r.Context(), tx, user, moderationActionRequest{
		UserID: targetUserID,
		Note:   "Manual unfreeze",
	}, "Unfreeze"); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to record unfreeze action")
		return
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to unfreeze user")
		return
	}

	s.emitAdminUserUpdatedSync(r.Context(), targetUserID)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleAdminHardDeleteUser(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Admin") {
		writeError(w, http.StatusForbidden, "Admin access is required")
		return
	}

	targetUserID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if targetUserID == user.ID {
		writeError(w, http.StatusForbidden, "You cannot delete your own account here")
		return
	}

	var req adminHardDeleteUserRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open delete transaction")
		return
	}
	defer tx.Rollback()

	username, _, mediaValues, err := loadManagedUserIdentity(r.Context(), tx, targetUserID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "User not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load target user")
		return
	}

	threadIDs, err := loadSupportThreadIDsForUser(r.Context(), tx, targetUserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load support threads")
		return
	}

	extraMedia, err := loadManagedMediaValuesForUserDeletion(r.Context(), tx, targetUserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to collect user media")
		return
	}
	mediaValues = append(mediaValues, extraMedia...)

	if _, err := s.insertModerationAction(r.Context(), tx, user, moderationActionRequest{
		UserID: targetUserID,
		Note:   strings.TrimSpace(req.Note),
	}, "HardDelete"); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to record delete action")
		return
	}

	if _, err := tx.ExecContext(r.Context(), `
		DELETE FROM "Users"
		WHERE "Id" = $1
	`, targetUserID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to delete user")
		return
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to complete delete")
		return
	}

	s.cleanupManagedMediaIfOrphaned(r.Context(), mediaValues...)
	s.emitAdminUserDeletedSync(r.Context(), targetUserID, username, threadIDs)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleAdminSupportThreads(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Admin") {
		writeError(w, http.StatusForbidden, "Admin access is required")
		return
	}

	page, pageSize := supportPaginationFromRequest(r)
	query := normalizeText(r.URL.Query().Get("query"))
	status := normalizeSupportStatusFilter(r.URL.Query().Get("status"))
	items, totalCount, err := s.loadSupportThreadsPage(r.Context(), true, page, pageSize, status, query, nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load support inbox")
		return
	}

	writeJSON(w, http.StatusOK, buildPagedResponse(normalizeSupportThreadsMedia(r, items), page, pageSize, totalCount, page*pageSize < totalCount))
}

func (s *Server) handleAdminSupportThreadDetail(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Admin") {
		writeError(w, http.StatusForbidden, "Admin access is required")
		return
	}

	threadID, err := parseIDParam(r, "threadID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := s.markSupportThreadRead(r.Context(), threadID, user.ID, true); err != nil && !errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusInternalServerError, "Failed to update thread state")
		return
	}

	detail, err := s.loadSupportThreadDetail(r.Context(), threadID, user.ID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Support thread not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load support thread")
		return
	}

	s.emitSupportThreadSync(r.Context(), detail.Thread, "support.thread.updated", map[string]any{
		"threadId": detail.Thread.ID,
		"status":   detail.Thread.Status,
		"userId":   detail.Thread.UserID,
	})
	writeJSON(w, http.StatusOK, normalizeSupportThreadDetailMedia(r, detail))
}

func (s *Server) handleAdminSupportReply(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Admin") {
		writeError(w, http.StatusForbidden, "Admin access is required")
		return
	}

	threadID, err := parseIDParam(r, "threadID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var req supportReplyMessageRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	messageText := normalizeText(req.Message)
	if messageText == "" {
		writeError(w, http.StatusBadRequest, "Reply message is required")
		return
	}

	message, thread, err := s.appendSupportMessage(r.Context(), threadID, user, true, messageText)
	if err != nil {
		switch {
		case errors.Is(err, sql.ErrNoRows):
			writeError(w, http.StatusNotFound, "Support thread not found")
		case strings.Contains(strings.ToLower(err.Error()), "closed"):
			writeError(w, http.StatusConflict, "Reopen the thread before replying")
		default:
			writeError(w, http.StatusInternalServerError, "Failed to send support reply")
		}
		return
	}

	s.emitSupportThreadSync(r.Context(), thread, "support.message.created", map[string]any{
		"threadId":  thread.ID,
		"userId":    thread.UserID,
		"messageId": message.ID,
	})
	writeJSON(w, http.StatusCreated, normalizeSupportMessageMedia(r, message))
}

func (s *Server) handleAdminSupportClose(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Admin") {
		writeError(w, http.StatusForbidden, "Admin access is required")
		return
	}

	threadID, err := parseIDParam(r, "threadID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	thread, err := s.updateSupportThreadStatus(r.Context(), threadID, user.ID, supportStatusClosed)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Support thread not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to close support thread")
		return
	}

	s.emitSupportThreadSync(r.Context(), thread, "support.thread.updated", map[string]any{
		"threadId": thread.ID,
		"status":   thread.Status,
		"userId":   thread.UserID,
	})
	writeJSON(w, http.StatusOK, normalizeSupportThreadMedia(r, thread))
}

func (s *Server) handleAdminSupportReopen(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Admin") {
		writeError(w, http.StatusForbidden, "Admin access is required")
		return
	}

	threadID, err := parseIDParam(r, "threadID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	thread, err := s.updateSupportThreadStatus(r.Context(), threadID, user.ID, supportStatusWaitingForUser)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Support thread not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to reopen support thread")
		return
	}

	s.emitSupportThreadSync(r.Context(), thread, "support.thread.updated", map[string]any{
		"threadId": thread.ID,
		"status":   thread.Status,
		"userId":   thread.UserID,
	})
	writeJSON(w, http.StatusOK, normalizeSupportThreadMedia(r, thread))
}

func (s *Server) handleSupportThreads(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	page, pageSize := supportPaginationFromRequest(r)
	status := normalizeSupportStatusFilter(r.URL.Query().Get("status"))

	items, totalCount, err := s.loadSupportThreadsPage(r.Context(), false, page, pageSize, status, "", &user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load support threads")
		return
	}

	writeJSON(w, http.StatusOK, buildPagedResponse(normalizeSupportThreadsMedia(r, items), page, pageSize, totalCount, page*pageSize < totalCount))
}

func (s *Server) handleCreateSupportThread(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())

	var req supportCreateThreadRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	subject := normalizeText(req.Subject)
	messageText := normalizeText(req.Message)
	if subject == "" || messageText == "" {
		writeError(w, http.StatusBadRequest, "Subject and message are required")
		return
	}

	thread, created, err := s.createOrReuseSupportThread(r.Context(), user, subject, messageText)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create support thread")
		return
	}

	detail, err := s.loadSupportThreadDetail(r.Context(), thread.ID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load support thread")
		return
	}

	statusCode := http.StatusOK
	if created {
		statusCode = http.StatusCreated
	}
	writeJSON(w, statusCode, normalizeSupportThreadDetailMedia(r, detail))
}

func (s *Server) handleSupportThreadDetail(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	threadID, err := parseIDParam(r, "threadID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	detail, err := s.loadSupportThreadDetailForUser(r.Context(), threadID, user.ID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Support thread not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load support thread")
		return
	}

	writeJSON(w, http.StatusOK, normalizeSupportThreadDetailMedia(r, detail))
}

func (s *Server) handleCreateSupportMessage(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	threadID, err := parseIDParam(r, "threadID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var req supportReplyMessageRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	messageText := normalizeText(req.Message)
	if messageText == "" {
		writeError(w, http.StatusBadRequest, "Message is required")
		return
	}

	message, thread, err := s.appendSupportMessageForUser(r.Context(), threadID, user, messageText)
	if err != nil {
		switch {
		case errors.Is(err, sql.ErrNoRows):
			writeError(w, http.StatusNotFound, "Support thread not found")
		default:
			writeError(w, http.StatusInternalServerError, "Failed to send support message")
		}
		return
	}

	s.emitSupportThreadSync(r.Context(), thread, "support.message.created", map[string]any{
		"threadId":  thread.ID,
		"userId":    thread.UserID,
		"messageId": message.ID,
	})
	writeJSON(w, http.StatusCreated, normalizeSupportMessageMedia(r, message))
}

func (s *Server) handleMarkSupportThreadRead(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	threadID, err := parseIDParam(r, "threadID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	thread, err := s.loadSupportThreadSummaryForUser(r.Context(), threadID, user.ID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Support thread not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load support thread")
		return
	}

	if err := s.markSupportThreadRead(r.Context(), threadID, user.ID, false); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to mark support thread as read")
		return
	}

	s.emitSupportThreadSync(r.Context(), thread, "support.thread.updated", map[string]any{
		"threadId": thread.ID,
		"status":   thread.Status,
		"userId":   thread.UserID,
	})
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func adminPaginationFromRequest(r *http.Request) (int, int) {
	page := clamp(parseIntWithDefault(r.URL.Query().Get("page"), 1), 1, 10000)
	pageSize := clamp(parseIntWithDefault(r.URL.Query().Get("pageSize"), 25), 1, 100)
	return page, pageSize
}

func supportPaginationFromRequest(r *http.Request) (int, int) {
	page := clamp(parseIntWithDefault(r.URL.Query().Get("page"), 1), 1, 10000)
	pageSize := clamp(parseIntWithDefault(r.URL.Query().Get("pageSize"), 20), 1, 100)
	return page, pageSize
}

func normalizeAdminUserFilter(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case adminUserFilterActive:
		return adminUserFilterActive
	case adminUserFilterFrozen:
		return adminUserFilterFrozen
	case adminUserFilterAdmins:
		return adminUserFilterAdmins
	case adminUserFilterModerators:
		return adminUserFilterModerators
	default:
		return adminUserFilterAll
	}
}

func normalizeSupportStatusFilter(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case strings.ToLower(supportStatusWaitingForAdmin):
		return supportStatusWaitingForAdmin
	case strings.ToLower(supportStatusWaitingForUser):
		return supportStatusWaitingForUser
	case strings.ToLower(supportStatusClosed):
		return supportStatusClosed
	default:
		return ""
	}
}

func (s *Server) loadAdminUsersPage(ctx context.Context, page, pageSize int, filter, query string) ([]adminUserSummaryResponse, int, error) {
	whereClause, args := buildAdminUsersWhereClause(filter, query)
	offset := (page - 1) * pageSize
	argsWithPaging := append(append([]any{}, args...), pageSize, offset, supportStatusClosed)

	rows := []adminUserRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		WITH filtered AS (
			SELECT
				u."Id" AS id,
				u."Username" AS username,
				u."DisplayName" AS display_name,
				u."Email" AS email,
				u."AboutMe" AS about_me,
				u."AvatarUrl" AS avatar_url,
				u."AvatarScale" AS avatar_scale,
				u."AvatarOffsetX" AS avatar_offset_x,
				u."AvatarOffsetY" AS avatar_offset_y,
				u."BannerUrl" AS banner_url,
				u."BannerScale" AS banner_scale,
				u."BannerOffsetX" AS banner_offset_x,
				u."BannerOffsetY" AS banner_offset_y,
				u."Role" AS role,
				u."IsEmailVerified" AS is_email_verified,
				u."CreatedAt" AS created_at,
				u."LastSeenAt" AS last_seen_at,
				u."SuspendedUntil" AS suspended_until,
				u."BannedAt" AS banned_at
			FROM "Users" u
			`+whereClause+`
			ORDER BY u."LastSeenAt" DESC, u."Id" DESC
			LIMIT $`+fmt.Sprintf("%d", len(args)+1)+` OFFSET $`+fmt.Sprintf("%d", len(args)+2)+`
		),
		post_counts AS (
			SELECT p."UserId" AS user_id, COUNT(*)::int AS posts_count
			FROM "Posts" p
			WHERE p."IsHidden" = false
			  AND p."IsRemoved" = false
			  AND p."UserId" IN (SELECT id FROM filtered)
			GROUP BY p."UserId"
		),
		follower_counts AS (
			SELECT f."FollowingId" AS user_id, COUNT(*)::int AS followers_count
			FROM "Follows" f
			WHERE f."FollowingId" IN (SELECT id FROM filtered)
			GROUP BY f."FollowingId"
		),
		following_counts AS (
			SELECT f."FollowerId" AS user_id, COUNT(*)::int AS following_count
			FROM "Follows" f
			WHERE f."FollowerId" IN (SELECT id FROM filtered)
			GROUP BY f."FollowerId"
		),
		session_counts AS (
			SELECT s."UserId" AS user_id, COUNT(*)::int AS active_sessions_count
			FROM "UserSessions" s
			WHERE s."RevokedAt" IS NULL
			  AND s."ExpiresAt" > NOW()
			  AND s."UserId" IN (SELECT id FROM filtered)
			GROUP BY s."UserId"
		),
		support_counts AS (
			SELECT t."UserId" AS user_id, COUNT(*)::int AS open_support_threads
			FROM "SupportThreads" t
			WHERE t."Status" <> $`+fmt.Sprintf("%d", len(args)+3)+`
			  AND t."UserId" IN (SELECT id FROM filtered)
			GROUP BY t."UserId"
		)
		SELECT
			f.id,
			f.username,
			f.display_name,
			f.email,
			f.about_me,
			f.avatar_url,
			f.avatar_scale,
			f.avatar_offset_x,
			f.avatar_offset_y,
			f.banner_url,
			f.banner_scale,
			f.banner_offset_x,
			f.banner_offset_y,
			f.role,
			f.is_email_verified,
			f.created_at,
			f.last_seen_at,
			f.suspended_until,
			f.banned_at,
			COALESCE(pc.posts_count, 0) AS posts_count,
			COALESCE(fc.followers_count, 0) AS followers_count,
			COALESCE(fgc.following_count, 0) AS following_count,
			COALESCE(sc.active_sessions_count, 0) AS active_sessions_count,
			COALESCE(stc.open_support_threads, 0) AS open_support_threads
		FROM filtered f
		LEFT JOIN post_counts pc ON pc.user_id = f.id
		LEFT JOIN follower_counts fc ON fc.user_id = f.id
		LEFT JOIN following_counts fgc ON fgc.user_id = f.id
		LEFT JOIN session_counts sc ON sc.user_id = f.id
		LEFT JOIN support_counts stc ON stc.user_id = f.id
		ORDER BY f.last_seen_at DESC, f.id DESC
	`, argsWithPaging...); err != nil {
		return nil, 0, err
	}

	var totalCount int
	if err := s.db.GetContext(ctx, &totalCount, `
		SELECT COUNT(*)
		FROM "Users" u
		`+whereClause, args...); err != nil {
		return nil, 0, err
	}

	items := make([]adminUserSummaryResponse, 0, len(rows))
	for _, row := range rows {
		items = append(items, mapAdminUserRow(row))
	}
	return items, totalCount, nil
}

func (s *Server) loadAdminUserDetail(ctx context.Context, userID int) (adminUserDetailResponse, error) {
	var row adminUserRow
	if err := s.db.GetContext(ctx, &row, `
		WITH post_counts AS (
			SELECT COUNT(*)::int AS posts_count
			FROM "Posts"
			WHERE "UserId" = $1
			  AND "IsHidden" = false
			  AND "IsRemoved" = false
		),
		follower_counts AS (
			SELECT COUNT(*)::int AS followers_count
			FROM "Follows"
			WHERE "FollowingId" = $1
		),
		following_counts AS (
			SELECT COUNT(*)::int AS following_count
			FROM "Follows"
			WHERE "FollowerId" = $1
		),
		session_counts AS (
			SELECT COUNT(*)::int AS active_sessions_count
			FROM "UserSessions"
			WHERE "UserId" = $1
			  AND "RevokedAt" IS NULL
			  AND "ExpiresAt" > NOW()
		),
		support_counts AS (
			SELECT COUNT(*)::int AS open_support_threads
			FROM "SupportThreads"
			WHERE "UserId" = $1
			  AND "Status" <> $2
		)
		SELECT
			u."Id" AS id,
			u."Username" AS username,
			u."DisplayName" AS display_name,
			u."Email" AS email,
			u."AboutMe" AS about_me,
			u."AvatarUrl" AS avatar_url,
			u."AvatarScale" AS avatar_scale,
			u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y,
			u."BannerUrl" AS banner_url,
			u."BannerScale" AS banner_scale,
			u."BannerOffsetX" AS banner_offset_x,
			u."BannerOffsetY" AS banner_offset_y,
			u."Role" AS role,
			u."IsEmailVerified" AS is_email_verified,
			u."CreatedAt" AS created_at,
			u."LastSeenAt" AS last_seen_at,
			u."SuspendedUntil" AS suspended_until,
			u."BannedAt" AS banned_at,
			COALESCE((SELECT posts_count FROM post_counts), 0) AS posts_count,
			COALESCE((SELECT followers_count FROM follower_counts), 0) AS followers_count,
			COALESCE((SELECT following_count FROM following_counts), 0) AS following_count,
			COALESCE((SELECT active_sessions_count FROM session_counts), 0) AS active_sessions_count,
			COALESCE((SELECT open_support_threads FROM support_counts), 0) AS open_support_threads
		FROM "Users" u
		WHERE u."Id" = $1
	`, userID, supportStatusClosed); err != nil {
		return adminUserDetailResponse{}, err
	}

	moderationActions, err := s.loadRecentModerationActions(ctx, userID, 8)
	if err != nil {
		return adminUserDetailResponse{}, err
	}

	recentThreads, err := s.loadRecentSupportThreadsForUser(ctx, userID, 5)
	if err != nil {
		return adminUserDetailResponse{}, err
	}

	return adminUserDetailResponse{
		User:                    mapAdminUserRow(row),
		RecentModerationActions: moderationActions,
		RecentSupportThreads:    recentThreads,
	}, nil
}

func buildAdminUsersWhereClause(filter, query string) (string, []any) {
	clauses := []string{"WHERE 1 = 1"}
	args := make([]any, 0, 4)

	switch filter {
	case adminUserFilterActive:
		clauses = append(clauses, `AND u."BannedAt" IS NULL AND (u."SuspendedUntil" IS NULL OR u."SuspendedUntil" < NOW())`)
	case adminUserFilterFrozen:
		clauses = append(clauses, `AND u."SuspendedUntil" IS NOT NULL AND u."SuspendedUntil" > NOW()`)
	case adminUserFilterAdmins:
		clauses = append(clauses, `AND u."Role" = 2`)
	case adminUserFilterModerators:
		clauses = append(clauses, `AND u."Role" = 1`)
	}

	if trimmedQuery := strings.ToLower(strings.TrimSpace(query)); trimmedQuery != "" {
		args = append(args, "%"+trimmedQuery+"%")
		argRef := fmt.Sprintf("$%d", len(args))
		clauses = append(clauses, `
			AND (
				u."NormalizedUsername" LIKE `+argRef+`
				OR u."NormalizedEmail" LIKE `+argRef+`
				OR LOWER(COALESCE(u."DisplayName", '')) LIKE `+argRef+`
			)
		`)
	}

	return strings.Join(clauses, "\n"), args
}

func mapAdminUserRow(row adminUserRow) adminUserSummaryResponse {
	return adminUserSummaryResponse{
		ID:                  row.ID,
		Username:            row.Username,
		DisplayName:         nullableString(row.DisplayName),
		Email:               row.Email,
		AboutMe:             nullableString(row.AboutMe),
		AvatarURL:           nullableString(row.AvatarURL),
		AvatarScale:         row.AvatarScale,
		AvatarOffsetX:       row.AvatarOffsetX,
		AvatarOffsetY:       row.AvatarOffsetY,
		BannerURL:           nullableString(row.BannerURL),
		BannerScale:         row.BannerScale,
		BannerOffsetX:       row.BannerOffsetX,
		BannerOffsetY:       row.BannerOffsetY,
		Role:                roleName(row.Role),
		IsEmailVerified:     row.IsEmailVerified,
		CreatedAt:           row.CreatedAt,
		LastSeenAt:          row.LastSeenAt,
		SuspendedUntil:      nullableTime(row.SuspendedUntil),
		BannedAt:            nullableTime(row.BannedAt),
		Status:              accountStatus(row.BannedAt, row.SuspendedUntil),
		PostsCount:          row.PostsCount,
		FollowersCount:      row.FollowersCount,
		FollowingCount:      row.FollowingCount,
		ActiveSessionsCount: row.ActiveSessionsCount,
		OpenSupportThreads:  row.OpenSupportThreads,
	}
}

func accountStatus(bannedAt sql.NullTime, suspendedUntil sql.NullTime) string {
	if bannedAt.Valid {
		return "Banned"
	}
	if suspendedUntil.Valid && suspendedUntil.Time.After(time.Now().UTC()) {
		return "Frozen"
	}
	return "Active"
}

func (s *Server) loadRecentModerationActions(ctx context.Context, userID, limit int) ([]adminModerationActionSummary, error) {
	rows := []struct {
		ID            int            `db:"id"`
		ActionType    string         `db:"action_type"`
		Note          sql.NullString `db:"note"`
		CreatedAt     time.Time      `db:"created_at"`
		ExpiresAt     sql.NullTime   `db:"expires_at"`
		ActorUserID   sql.NullInt64  `db:"actor_user_id"`
		ActorUsername sql.NullString `db:"actor_username"`
	}{}

	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			a."Id" AS id,
			a."ActionType" AS action_type,
			a."Note" AS note,
			a."CreatedAt" AS created_at,
			a."ExpiresAt" AS expires_at,
			a."ActorUserId" AS actor_user_id,
			actor."Username" AS actor_username
		FROM "ModerationActions" a
		LEFT JOIN "Users" actor ON actor."Id" = a."ActorUserId"
		WHERE a."TargetUserId" = $1
		ORDER BY a."CreatedAt" DESC
		LIMIT $2
	`, userID, limit); err != nil {
		return nil, err
	}

	items := make([]adminModerationActionSummary, 0, len(rows))
	for _, row := range rows {
		items = append(items, adminModerationActionSummary{
			ID:            row.ID,
			ActionType:    row.ActionType,
			Note:          nullableString(row.Note),
			CreatedAt:     row.CreatedAt,
			ExpiresAt:     nullableTime(row.ExpiresAt),
			ActorUserID:   nullableInt(row.ActorUserID),
			ActorUsername: nullableString(row.ActorUsername),
		})
	}
	return items, nil
}

func (s *Server) loadRecentSupportThreadsForUser(ctx context.Context, userID, limit int) ([]supportThreadSummaryResponse, error) {
	rows := []supportThreadRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			t."Id" AS id,
			t."UserId" AS user_id,
			t."Subject" AS subject,
			t."Status" AS status,
			t."CreatedAt" AS created_at,
			t."UpdatedAt" AS updated_at,
			t."LastMessageAt" AS last_message_at,
			t."LastMessagePreview" AS last_message_preview,
			t."LastMessageAuthorUserId" AS last_message_author_user_id,
			t."AdminUnreadCount" AS admin_unread_count,
			t."UserUnreadCount" AS user_unread_count,
			t."ClosedAt" AS closed_at,
			t."ClosedByUserId" AS closed_by_user_id,
			u."Username" AS user_username,
			u."DisplayName" AS user_display_name,
			u."Email" AS user_email,
			u."Role" AS user_role,
			u."AvatarUrl" AS user_avatar_url,
			u."AvatarScale" AS user_avatar_scale,
			u."AvatarOffsetX" AS user_avatar_offset_x,
			u."AvatarOffsetY" AS user_avatar_offset_y,
			u."LastSeenAt" AS user_last_seen_at
		FROM "SupportThreads" t
		JOIN "Users" u ON u."Id" = t."UserId"
		WHERE t."UserId" = $1
		ORDER BY t."UpdatedAt" DESC
		LIMIT $2
	`, userID, limit); err != nil {
		return nil, err
	}

	items := make([]supportThreadSummaryResponse, 0, len(rows))
	for _, row := range rows {
		items = append(items, mapSupportThreadRow(row))
	}
	return items, nil
}

func (s *Server) createOrReuseSupportThread(ctx context.Context, user sessionUser, subject, messageText string) (supportThreadSummaryResponse, bool, error) {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return supportThreadSummaryResponse{}, false, err
	}
	defer tx.Rollback()

	var existingID int
	err = tx.GetContext(ctx, &existingID, `
		SELECT "Id"
		FROM "SupportThreads"
		WHERE "UserId" = $1
		  AND "Status" <> $2
		ORDER BY "UpdatedAt" DESC
		LIMIT 1
	`, user.ID, supportStatusClosed)
	if err == nil {
		if err := tx.Commit(); err != nil {
			return supportThreadSummaryResponse{}, false, err
		}
		thread, loadErr := s.loadSupportThreadSummaryForUser(ctx, existingID, user.ID)
		return thread, false, loadErr
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return supportThreadSummaryResponse{}, false, err
	}

	preview := supportMessagePreview(messageText)
	var threadID int
	if err := tx.GetContext(ctx, &threadID, `
		INSERT INTO "SupportThreads" (
			"UserId", "Subject", "Status", "CreatedAt", "UpdatedAt", "LastMessageAt",
			"LastMessagePreview", "LastMessageAuthorUserId", "AdminUnreadCount", "UserUnreadCount"
		)
		VALUES ($1, $2, $3, NOW(), NOW(), NOW(), $4, $5, 1, 0)
		RETURNING "Id"
	`, user.ID, subject, supportStatusWaitingForAdmin, preview, user.ID); err != nil {
		return supportThreadSummaryResponse{}, false, err
	}

	var messageID int
	if err := tx.GetContext(ctx, &messageID, `
		INSERT INTO "SupportMessages" (
			"ThreadId", "AuthorUserId", "Content", "CreatedAt"
		)
		VALUES ($1, $2, $3, NOW())
		RETURNING "Id"
	`, threadID, user.ID, messageText); err != nil {
		return supportThreadSummaryResponse{}, false, err
	}

	if err := tx.Commit(); err != nil {
		return supportThreadSummaryResponse{}, false, err
	}

	thread, err := s.loadSupportThreadSummaryForUser(ctx, threadID, user.ID)
	if err != nil {
		return supportThreadSummaryResponse{}, false, err
	}

	s.emitSupportThreadSync(ctx, thread, "support.message.created", map[string]any{
		"threadId":  thread.ID,
		"userId":    thread.UserID,
		"messageId": messageID,
	})
	return thread, true, nil
}

func (s *Server) appendSupportMessageForUser(ctx context.Context, threadID int, user sessionUser, messageText string) (supportMessageResponse, supportThreadSummaryResponse, error) {
	thread, err := s.loadSupportThreadSummaryForUser(ctx, threadID, user.ID)
	if err != nil {
		return supportMessageResponse{}, supportThreadSummaryResponse{}, err
	}

	message, updatedThread, err := s.appendSupportMessage(ctx, threadID, user, false, messageText)
	if err != nil {
		return supportMessageResponse{}, supportThreadSummaryResponse{}, err
	}
	if updatedThread.ID == 0 {
		updatedThread = thread
	}
	return message, updatedThread, nil
}

func (s *Server) appendSupportMessage(ctx context.Context, threadID int, actor sessionUser, actorIsAdmin bool, messageText string) (supportMessageResponse, supportThreadSummaryResponse, error) {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return supportMessageResponse{}, supportThreadSummaryResponse{}, err
	}
	defer tx.Rollback()

	thread, err := loadSupportThreadSummaryTx(ctx, tx, threadID)
	if err != nil {
		return supportMessageResponse{}, supportThreadSummaryResponse{}, err
	}
	if actorIsAdmin {
		if thread.Status == supportStatusClosed {
			return supportMessageResponse{}, supportThreadSummaryResponse{}, fmt.Errorf("thread is closed")
		}
	} else if thread.UserID != actor.ID {
		return supportMessageResponse{}, supportThreadSummaryResponse{}, sql.ErrNoRows
	}

	var messageID int
	if err := tx.GetContext(ctx, &messageID, `
		INSERT INTO "SupportMessages" (
			"ThreadId", "AuthorUserId", "Content", "CreatedAt"
		)
		VALUES ($1, $2, $3, NOW())
		RETURNING "Id"
	`, threadID, actor.ID, messageText); err != nil {
		return supportMessageResponse{}, supportThreadSummaryResponse{}, err
	}

	nextStatus := supportStatusWaitingForAdmin
	adminUnreadDelta := 1
	userUnreadDelta := 0
	if actorIsAdmin {
		nextStatus = supportStatusWaitingForUser
		adminUnreadDelta = 0
		userUnreadDelta = 1
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE "SupportThreads"
		SET "Status" = $2,
		    "UpdatedAt" = NOW(),
		    "LastMessageAt" = NOW(),
		    "LastMessagePreview" = $3,
		    "LastMessageAuthorUserId" = $4,
		    "AdminUnreadCount" = CASE WHEN $5 = 0 THEN 0 ELSE "AdminUnreadCount" + $5 END,
		    "UserUnreadCount" = CASE WHEN $6 = 0 THEN 0 ELSE "UserUnreadCount" + $6 END,
		    "ClosedAt" = NULL,
		    "ClosedByUserId" = NULL
		WHERE "Id" = $1
	`, threadID, nextStatus, supportMessagePreview(messageText), actor.ID, adminUnreadDelta, userUnreadDelta); err != nil {
		return supportMessageResponse{}, supportThreadSummaryResponse{}, err
	}

	if err := tx.Commit(); err != nil {
		return supportMessageResponse{}, supportThreadSummaryResponse{}, err
	}

	message, err := s.loadSupportMessage(ctx, messageID, actor.ID)
	if err != nil {
		return supportMessageResponse{}, supportThreadSummaryResponse{}, err
	}
	updatedThread, err := s.loadSupportThreadDetailSummary(ctx, threadID)
	if err != nil {
		return supportMessageResponse{}, supportThreadSummaryResponse{}, err
	}
	return message, updatedThread, nil
}

func (s *Server) updateSupportThreadStatus(ctx context.Context, threadID, actorUserID int, status string) (supportThreadSummaryResponse, error) {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return supportThreadSummaryResponse{}, err
	}
	defer tx.Rollback()

	if _, err := loadSupportThreadSummaryTx(ctx, tx, threadID); err != nil {
		return supportThreadSummaryResponse{}, err
	}

	switch status {
	case supportStatusClosed:
		if _, err := tx.ExecContext(ctx, `
			UPDATE "SupportThreads"
			SET "Status" = $2,
			    "ClosedAt" = NOW(),
			    "ClosedByUserId" = $3,
			    "AdminUnreadCount" = 0,
			    "UserUnreadCount" = 0,
			    "UpdatedAt" = NOW()
			WHERE "Id" = $1
		`, threadID, supportStatusClosed, actorUserID); err != nil {
			return supportThreadSummaryResponse{}, err
		}
	case supportStatusWaitingForUser:
		if _, err := tx.ExecContext(ctx, `
			UPDATE "SupportThreads"
			SET "Status" = $2,
			    "ClosedAt" = NULL,
			    "ClosedByUserId" = NULL,
			    "AdminUnreadCount" = 0,
			    "UserUnreadCount" = 0,
			    "UpdatedAt" = NOW()
			WHERE "Id" = $1
		`, threadID, supportStatusWaitingForUser); err != nil {
			return supportThreadSummaryResponse{}, err
		}
	default:
		return supportThreadSummaryResponse{}, fmt.Errorf("unsupported support status")
	}

	if err := tx.Commit(); err != nil {
		return supportThreadSummaryResponse{}, err
	}

	return s.loadSupportThreadDetailSummary(ctx, threadID)
}

func (s *Server) markSupportThreadRead(ctx context.Context, threadID, readerUserID int, readerIsAdmin bool) error {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	thread, err := loadSupportThreadSummaryTx(ctx, tx, threadID)
	if err != nil {
		return err
	}
	if !readerIsAdmin && thread.UserID != readerUserID {
		return sql.ErrNoRows
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE "SupportMessages"
		SET "ReadAt" = NOW()
		WHERE "ThreadId" = $1
		  AND ("AuthorUserId" IS NULL OR "AuthorUserId" <> $2)
		  AND "ReadAt" IS NULL
	`, threadID, readerUserID); err != nil {
		return err
	}

	if readerIsAdmin {
		if _, err := tx.ExecContext(ctx, `UPDATE "SupportThreads" SET "AdminUnreadCount" = 0 WHERE "Id" = $1`, threadID); err != nil {
			return err
		}
	} else {
		if _, err := tx.ExecContext(ctx, `UPDATE "SupportThreads" SET "UserUnreadCount" = 0 WHERE "Id" = $1`, threadID); err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (s *Server) loadSupportThreadSummaryForUser(ctx context.Context, threadID, userID int) (supportThreadSummaryResponse, error) {
	thread, err := s.loadSupportThreadDetailSummary(ctx, threadID)
	if err != nil {
		return supportThreadSummaryResponse{}, err
	}
	if thread.UserID != userID {
		return supportThreadSummaryResponse{}, sql.ErrNoRows
	}
	return thread, nil
}

func (s *Server) loadSupportThreadDetailForUser(ctx context.Context, threadID, userID int) (supportThreadDetailResponse, error) {
	detail, err := s.loadSupportThreadDetail(ctx, threadID, userID)
	if err != nil {
		return supportThreadDetailResponse{}, err
	}
	if detail.Thread.UserID != userID {
		return supportThreadDetailResponse{}, sql.ErrNoRows
	}
	return detail, nil
}

func (s *Server) loadSupportThreadDetail(ctx context.Context, threadID, viewerUserID int) (supportThreadDetailResponse, error) {
	thread, err := s.loadSupportThreadDetailSummary(ctx, threadID)
	if err != nil {
		return supportThreadDetailResponse{}, err
	}

	rows := []supportMessageRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			m."Id" AS id,
			m."ThreadId" AS thread_id,
			m."AuthorUserId" AS author_user_id,
			author."Username" AS author_username,
			author."DisplayName" AS author_display_name,
			author."Role" AS author_role,
			author."AvatarUrl" AS author_avatar_url,
			author."AvatarScale" AS author_avatar_scale,
			author."AvatarOffsetX" AS author_avatar_offset_x,
			author."AvatarOffsetY" AS author_avatar_offset_y,
			m."Content" AS content,
			m."CreatedAt" AS created_at,
			m."ReadAt" AS read_at
		FROM "SupportMessages" m
		LEFT JOIN "Users" author ON author."Id" = m."AuthorUserId"
		WHERE m."ThreadId" = $1
		ORDER BY m."CreatedAt" ASC, m."Id" ASC
	`, threadID); err != nil {
		return supportThreadDetailResponse{}, err
	}

	messages := make([]supportMessageResponse, 0, len(rows))
	for _, row := range rows {
		messages = append(messages, mapSupportMessageRow(row, viewerUserID))
	}

	return supportThreadDetailResponse{
		Thread:   thread,
		Messages: messages,
	}, nil
}

func (s *Server) loadSupportMessage(ctx context.Context, messageID, viewerUserID int) (supportMessageResponse, error) {
	var row supportMessageRow
	if err := s.db.GetContext(ctx, &row, `
		SELECT
			m."Id" AS id,
			m."ThreadId" AS thread_id,
			m."AuthorUserId" AS author_user_id,
			author."Username" AS author_username,
			author."DisplayName" AS author_display_name,
			author."Role" AS author_role,
			author."AvatarUrl" AS author_avatar_url,
			author."AvatarScale" AS author_avatar_scale,
			author."AvatarOffsetX" AS author_avatar_offset_x,
			author."AvatarOffsetY" AS author_avatar_offset_y,
			m."Content" AS content,
			m."CreatedAt" AS created_at,
			m."ReadAt" AS read_at
		FROM "SupportMessages" m
		LEFT JOIN "Users" author ON author."Id" = m."AuthorUserId"
		WHERE m."Id" = $1
	`, messageID); err != nil {
		return supportMessageResponse{}, err
	}

	return mapSupportMessageRow(row, viewerUserID), nil
}

func (s *Server) loadSupportThreadsPage(ctx context.Context, forAdmin bool, page, pageSize int, status, query string, userID *int) ([]supportThreadSummaryResponse, int, error) {
	whereClause, args := buildSupportThreadsWhereClause(forAdmin, status, query, userID)
	offset := (page - 1) * pageSize
	listArgs := append(append([]any{}, args...), pageSize, offset)

	rows := []supportThreadRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			t."Id" AS id,
			t."UserId" AS user_id,
			t."Subject" AS subject,
			t."Status" AS status,
			t."CreatedAt" AS created_at,
			t."UpdatedAt" AS updated_at,
			t."LastMessageAt" AS last_message_at,
			t."LastMessagePreview" AS last_message_preview,
			t."LastMessageAuthorUserId" AS last_message_author_user_id,
			t."AdminUnreadCount" AS admin_unread_count,
			t."UserUnreadCount" AS user_unread_count,
			t."ClosedAt" AS closed_at,
			t."ClosedByUserId" AS closed_by_user_id,
			u."Username" AS user_username,
			u."DisplayName" AS user_display_name,
			u."Email" AS user_email,
			u."Role" AS user_role,
			u."AvatarUrl" AS user_avatar_url,
			u."AvatarScale" AS user_avatar_scale,
			u."AvatarOffsetX" AS user_avatar_offset_x,
			u."AvatarOffsetY" AS user_avatar_offset_y,
			u."LastSeenAt" AS user_last_seen_at
		FROM "SupportThreads" t
		JOIN "Users" u ON u."Id" = t."UserId"
		`+whereClause+`
		ORDER BY
			CASE t."Status"
				WHEN 'WaitingForAdmin' THEN 0
				WHEN 'WaitingForUser' THEN 1
				ELSE 2
			END,
			t."UpdatedAt" DESC,
			t."Id" DESC
		LIMIT $`+fmt.Sprintf("%d", len(args)+1)+` OFFSET $`+fmt.Sprintf("%d", len(args)+2)+`
	`, listArgs...); err != nil {
		return nil, 0, err
	}

	var totalCount int
	if err := s.db.GetContext(ctx, &totalCount, `
		SELECT COUNT(*)
		FROM "SupportThreads" t
		JOIN "Users" u ON u."Id" = t."UserId"
		`+whereClause, args...); err != nil {
		return nil, 0, err
	}

	items := make([]supportThreadSummaryResponse, 0, len(rows))
	for _, row := range rows {
		items = append(items, mapSupportThreadRow(row))
	}
	return items, totalCount, nil
}

func buildSupportThreadsWhereClause(forAdmin bool, status, query string, userID *int) (string, []any) {
	clauses := []string{"WHERE 1 = 1"}
	args := make([]any, 0, 4)

	if !forAdmin && userID != nil {
		args = append(args, *userID)
		clauses = append(clauses, fmt.Sprintf(`AND t."UserId" = $%d`, len(args)))
	}
	if status != "" {
		args = append(args, status)
		clauses = append(clauses, fmt.Sprintf(`AND t."Status" = $%d`, len(args)))
	}
	if trimmedQuery := strings.ToLower(strings.TrimSpace(query)); trimmedQuery != "" {
		args = append(args, "%"+trimmedQuery+"%")
		argRef := fmt.Sprintf("$%d", len(args))
		clauses = append(clauses, `
			AND (
				LOWER(t."Subject") LIKE `+argRef+`
				OR LOWER(COALESCE(t."LastMessagePreview", '')) LIKE `+argRef+`
				OR u."NormalizedUsername" LIKE `+argRef+`
				OR u."NormalizedEmail" LIKE `+argRef+`
				OR LOWER(COALESCE(u."DisplayName", '')) LIKE `+argRef+`
			)
		`)
	}

	return strings.Join(clauses, "\n"), args
}

func (s *Server) loadSupportThreadDetailSummary(ctx context.Context, threadID int) (supportThreadSummaryResponse, error) {
	row, err := loadSupportThreadSummaryWithUser(ctx, s.db, threadID)
	if err != nil {
		return supportThreadSummaryResponse{}, err
	}
	return mapSupportThreadRow(row), nil
}

func loadSupportThreadSummaryTx(ctx context.Context, tx *sqlx.Tx, threadID int) (supportThreadSummaryResponse, error) {
	row, err := loadSupportThreadSummaryWithUser(ctx, tx, threadID)
	if err != nil {
		return supportThreadSummaryResponse{}, err
	}
	return mapSupportThreadRow(row), nil
}

func loadSupportThreadSummaryWithUser(ctx context.Context, queryer sqlx.QueryerContext, threadID int) (supportThreadRow, error) {
	var row supportThreadRow
	err := sqlx.GetContext(ctx, queryer, &row, `
		SELECT
			t."Id" AS id,
			t."UserId" AS user_id,
			t."Subject" AS subject,
			t."Status" AS status,
			t."CreatedAt" AS created_at,
			t."UpdatedAt" AS updated_at,
			t."LastMessageAt" AS last_message_at,
			t."LastMessagePreview" AS last_message_preview,
			t."LastMessageAuthorUserId" AS last_message_author_user_id,
			t."AdminUnreadCount" AS admin_unread_count,
			t."UserUnreadCount" AS user_unread_count,
			t."ClosedAt" AS closed_at,
			t."ClosedByUserId" AS closed_by_user_id,
			u."Username" AS user_username,
			u."DisplayName" AS user_display_name,
			u."Email" AS user_email,
			u."Role" AS user_role,
			u."AvatarUrl" AS user_avatar_url,
			u."AvatarScale" AS user_avatar_scale,
			u."AvatarOffsetX" AS user_avatar_offset_x,
			u."AvatarOffsetY" AS user_avatar_offset_y,
			u."LastSeenAt" AS user_last_seen_at
		FROM "SupportThreads" t
		JOIN "Users" u ON u."Id" = t."UserId"
		WHERE t."Id" = $1
	`, threadID)
	return row, err
}

func mapSupportThreadRow(row supportThreadRow) supportThreadSummaryResponse {
	var user *supportThreadUserResponse
	if row.UserUsername.Valid {
		user = &supportThreadUserResponse{
			ID:            row.UserID,
			Username:      row.UserUsername.String,
			DisplayName:   nullableString(row.UserDisplayName),
			Email:         nullableString(row.UserEmail),
			Role:          roleName(int(row.UserRole.Int64)),
			AvatarURL:     nullableString(row.UserAvatarURL),
			AvatarScale:   nullableFloat(row.UserAvatarScale, 1),
			AvatarOffsetX: nullableFloat(row.UserAvatarOffsetX, 0),
			AvatarOffsetY: nullableFloat(row.UserAvatarOffsetY, 0),
			LastSeenAt:    nullableTime(row.UserLastSeenAt),
			IsOnline:      row.UserLastSeenAt.Valid && isOnline(row.UserLastSeenAt.Time),
		}
	}

	return supportThreadSummaryResponse{
		ID:                  row.ID,
		UserID:              row.UserID,
		Subject:             row.Subject,
		Status:              row.Status,
		CreatedAt:           row.CreatedAt,
		UpdatedAt:           row.UpdatedAt,
		LastMessageAt:       row.LastMessageAt,
		LastMessagePreview:  nullableString(row.LastMessagePreview),
		LastMessageAuthorID: nullableInt(row.LastMessageAuthorID),
		AdminUnreadCount:    row.AdminUnreadCount,
		UserUnreadCount:     row.UserUnreadCount,
		ClosedAt:            nullableTime(row.ClosedAt),
		ClosedByUserID:      nullableInt(row.ClosedByUserID),
		User:                user,
	}
}

func mapSupportMessageRow(row supportMessageRow, viewerUserID int) supportMessageResponse {
	role := ""
	if row.AuthorRole.Valid {
		role = roleName(int(row.AuthorRole.Int64))
	}

	return supportMessageResponse{
		ID:                  row.ID,
		ThreadID:            row.ThreadID,
		AuthorUserID:        nullableInt(row.AuthorUserID),
		AuthorUsername:      nullableString(row.AuthorUsername),
		AuthorDisplayName:   nullableString(row.AuthorDisplayName),
		AuthorRole:          nullableTrimmedString(role),
		AuthorAvatarURL:     nullableString(row.AuthorAvatarURL),
		AuthorAvatarScale:   nullableFloat(row.AuthorAvatarScale, 1),
		AuthorAvatarOffsetX: nullableFloat(row.AuthorAvatarOffsetX, 0),
		AuthorAvatarOffsetY: nullableFloat(row.AuthorAvatarOffsetY, 0),
		Content:             row.Content,
		CreatedAt:           row.CreatedAt,
		ReadAt:              nullableTime(row.ReadAt),
		IsMine:              row.AuthorUserID.Valid && int(row.AuthorUserID.Int64) == viewerUserID,
		IsAdminAuthor:       role == "Admin" || role == "Moderator",
	}
}

func supportMessagePreview(content string) string {
	normalized := strings.Join(strings.Fields(strings.TrimSpace(content)), " ")
	if normalized == "" {
		return ""
	}
	runes := []rune(normalized)
	if len(runes) <= 160 {
		return normalized
	}
	return string(runes[:157]) + "..."
}

func revokeUserSessionsTx(ctx context.Context, tx *sqlx.Tx, userID int, reason string) error {
	_, err := tx.ExecContext(ctx, `
		UPDATE "UserSessions"
		SET "RevokedAt" = NOW(), "RevocationReason" = $2
		WHERE "UserId" = $1 AND "RevokedAt" IS NULL
	`, userID, reason)
	return err
}

func loadManagedUserIdentity(ctx context.Context, tx *sqlx.Tx, userID int) (string, string, []string, error) {
	var row struct {
		Username  string         `db:"username"`
		Email     string         `db:"email"`
		AvatarURL sql.NullString `db:"avatar_url"`
		BannerURL sql.NullString `db:"banner_url"`
	}
	if err := tx.GetContext(ctx, &row, `
		SELECT
			"Username" AS username,
			"Email" AS email,
			"AvatarUrl" AS avatar_url,
			"BannerUrl" AS banner_url
		FROM "Users"
		WHERE "Id" = $1
	`, userID); err != nil {
		return "", "", nil, err
	}

	values := []string{}
	if row.AvatarURL.Valid {
		values = append(values, strings.TrimSpace(row.AvatarURL.String))
	}
	if row.BannerURL.Valid {
		values = append(values, strings.TrimSpace(row.BannerURL.String))
	}
	return row.Username, row.Email, values, nil
}

func loadManagedMediaValuesForUserDeletion(ctx context.Context, tx *sqlx.Tx, userID int) ([]string, error) {
	rows := []struct {
		Value sql.NullString `db:"value"`
	}{}

	if err := tx.SelectContext(ctx, &rows, `
		SELECT value
		FROM (
			SELECT "AvatarUrl" AS value FROM "Users" WHERE "Id" = $1
			UNION ALL
			SELECT "BannerUrl" AS value FROM "Users" WHERE "Id" = $1
			UNION ALL
			SELECT "ImageUrl" AS value FROM "Posts" WHERE "UserId" = $1
			UNION ALL
			SELECT ma."FileUrl" AS value
			FROM "MessageAttachments" ma
			JOIN "Messages" m ON m."Id" = ma."MessageId"
			WHERE m."SenderId" = $1
		) AS media_values
	`, userID); err != nil {
		return nil, err
	}

	values := make([]string, 0, len(rows))
	for _, row := range rows {
		if !row.Value.Valid {
			continue
		}
		trimmed := strings.TrimSpace(row.Value.String)
		if trimmed == "" {
			continue
		}
		values = append(values, trimmed)
	}
	return values, nil
}

func loadSupportThreadIDsForUser(ctx context.Context, tx *sqlx.Tx, userID int) ([]int, error) {
	ids := []int{}
	if err := tx.SelectContext(ctx, &ids, `
		SELECT "Id"
		FROM "SupportThreads"
		WHERE "UserId" = $1
	`, userID); err != nil {
		return nil, err
	}
	return ids, nil
}

func (s *Server) emitAdminUserUpdatedSync(ctx context.Context, targetUserID int) {
	targets, err := s.loadPrivilegedUserIDs(ctx, 2)
	if err == nil {
		targets = append(targets, targetUserID)
		s.emitSyncToUsers("admin.user.updated", targets, map[string]any{
			"userId": targetUserID,
		})
	}
	s.emitSyncToUsers("profile.updated", []int{targetUserID}, map[string]any{
		"userId": targetUserID,
	})
}

func (s *Server) emitAdminUserDeletedSync(ctx context.Context, targetUserID int, username string, threadIDs []int) {
	targets, err := s.loadPrivilegedUserIDs(ctx, 2)
	if err == nil {
		s.emitSyncToUsers("admin.user.updated", targets, map[string]any{
			"userId":   targetUserID,
			"username": username,
			"deleted":  true,
		})
		for _, threadID := range threadIDs {
			s.emitSyncToUsers("support.thread.updated", targets, map[string]any{
				"threadId": threadID,
				"userId":   targetUserID,
				"deleted":  true,
			})
		}
	}
}

func (s *Server) emitSupportThreadSync(ctx context.Context, thread supportThreadSummaryResponse, eventType string, data map[string]any) {
	targets, err := s.loadPrivilegedUserIDs(ctx, 2)
	if err != nil {
		targets = nil
	}
	targets = append(targets, thread.UserID)
	s.emitSyncToUsers("support.thread.updated", targets, map[string]any{
		"threadId": thread.ID,
		"userId":   thread.UserID,
		"status":   thread.Status,
	})
	if eventType != "support.thread.updated" {
		s.emitSyncToUsers(eventType, targets, data)
	}
}

func (s *Server) loadPrivilegedUserIDs(ctx context.Context, minimumRole int) ([]int, error) {
	ids := []int{}
	if err := s.db.SelectContext(ctx, &ids, `
		SELECT "Id"
		FROM "Users"
		WHERE "Role" >= $1
	`, minimumRole); err != nil {
		return nil, err
	}
	return uniqueSyncUserIDs(ids), nil
}

func normalizeAdminUsersMedia(r *http.Request, items []adminUserSummaryResponse) []adminUserSummaryResponse {
	normalized := make([]adminUserSummaryResponse, 0, len(items))
	for _, item := range items {
		item.AvatarURL = resolveOptionalMediaURL(r, item.AvatarURL)
		item.BannerURL = resolveOptionalMediaURL(r, item.BannerURL)
		normalized = append(normalized, item)
	}
	return normalized
}

func normalizeAdminUserDetailMedia(r *http.Request, detail adminUserDetailResponse) adminUserDetailResponse {
	detail.User = normalizeAdminUsersMedia(r, []adminUserSummaryResponse{detail.User})[0]
	detail.RecentSupportThreads = normalizeSupportThreadsMedia(r, detail.RecentSupportThreads)
	return detail
}

func normalizeSupportThreadsMedia(r *http.Request, items []supportThreadSummaryResponse) []supportThreadSummaryResponse {
	normalized := make([]supportThreadSummaryResponse, 0, len(items))
	for _, item := range items {
		normalized = append(normalized, normalizeSupportThreadMedia(r, item))
	}
	return normalized
}

func normalizeSupportThreadMedia(r *http.Request, item supportThreadSummaryResponse) supportThreadSummaryResponse {
	if item.User != nil {
		item.User.AvatarURL = resolveOptionalMediaURL(r, item.User.AvatarURL)
	}
	return item
}

func normalizeSupportMessageMedia(r *http.Request, item supportMessageResponse) supportMessageResponse {
	item.AuthorAvatarURL = resolveOptionalMediaURL(r, item.AuthorAvatarURL)
	return item
}

func normalizeSupportThreadDetailMedia(r *http.Request, detail supportThreadDetailResponse) supportThreadDetailResponse {
	detail.Thread = normalizeSupportThreadMedia(r, detail.Thread)
	items := make([]supportMessageResponse, 0, len(detail.Messages))
	for _, item := range detail.Messages {
		items = append(items, normalizeSupportMessageMedia(r, item))
	}
	detail.Messages = items
	return detail
}

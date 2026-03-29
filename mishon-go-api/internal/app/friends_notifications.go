package app

import (
	"context"
	"database/sql"
	"net/http"
	"time"

	"github.com/jmoiron/sqlx"
)

func (s *Server) handleFriends(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	items, err := s.loadFriends(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load friends")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (s *Server) handleFriendRequests(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	incoming, outgoing, err := s.loadFriendRequests(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load friend requests")
		return
	}
	writeJSON(w, http.StatusOK, friendRequestsPayload{Incoming: incoming, Outgoing: outgoing})
}

func (s *Server) handleSendFriendRequest(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req createFriendRequestRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.UserID == user.ID {
		writeError(w, http.StatusBadRequest, "Cannot send a friend request to yourself")
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open transaction")
		return
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(r.Context(), `
		INSERT INTO "FriendRequests" ("SenderId", "ReceiverId", "CreatedAt")
		VALUES ($1, $2, NOW())
		ON CONFLICT ("SenderId", "ReceiverId") DO NOTHING
	`, user.ID, req.UserID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to send friend request")
		return
	}

	_ = s.insertNotificationTx(r.Context(), tx, req.UserID, &user.ID, "friend_request", "sent you a friend request", nil, nil, nil, nil, &user.ID)
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save friend request")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]bool{"ok": true})
}

func (s *Server) handleAcceptFriendRequest(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	requestID, err := parseIDParam(r, "requestID")
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

	var request struct {
		SenderID   int `db:"sender_id"`
		ReceiverID int `db:"receiver_id"`
	}
	if err := tx.GetContext(r.Context(), &request, `
		SELECT "SenderId" AS sender_id, "ReceiverId" AS receiver_id
		FROM "FriendRequests"
		WHERE "Id" = $1
	`, requestID); err != nil {
		writeError(w, http.StatusNotFound, "Friend request not found")
		return
	}

	if request.ReceiverID != user.ID {
		writeError(w, http.StatusForbidden, "You cannot accept this friend request")
		return
	}

	if _, err := tx.ExecContext(r.Context(), `
		INSERT INTO "Friendships" ("UserAId", "UserBId", "CreatedAt")
		VALUES ($1, $2, NOW())
		ON CONFLICT ("UserAId", "UserBId") DO NOTHING
	`, minInt(request.SenderID, request.ReceiverID), maxInt(request.SenderID, request.ReceiverID)); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create friendship")
		return
	}

	if _, err := tx.ExecContext(r.Context(), `
		DELETE FROM "FriendRequests"
		WHERE "Id" = $1 OR ("SenderId" = $2 AND "ReceiverId" = $3)
	`, requestID, request.ReceiverID, request.SenderID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to clear friend request")
		return
	}

	_ = s.insertNotificationTx(r.Context(), tx, request.SenderID, &user.ID, "friend_accept", "accepted your friend request", nil, nil, nil, nil, &user.ID)
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save friendship")
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleDeleteFriendRequest(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	requestID, err := parseIDParam(r, "requestID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	result, err := s.db.ExecContext(r.Context(), `
		DELETE FROM "FriendRequests"
		WHERE "Id" = $1 AND ("SenderId" = $2 OR "ReceiverId" = $2)
	`, requestID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to delete friend request")
		return
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		writeError(w, http.StatusNotFound, "Friend request not found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleRemoveFriend(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	peerID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	result, err := s.db.ExecContext(r.Context(), `
		DELETE FROM "Friendships"
		WHERE ("UserAId" = $1 AND "UserBId" = $2) OR ("UserAId" = $2 AND "UserBId" = $1)
	`, user.ID, peerID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to remove friend")
		return
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		writeError(w, http.StatusNotFound, "Friendship not found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleToggleFollow(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	targetID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if targetID == user.ID {
		writeError(w, http.StatusBadRequest, "Cannot follow yourself")
		return
	}

	response, err := s.toggleFollow(r.Context(), user.ID, targetID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update follow state")
		return
	}
	writeJSON(w, http.StatusOK, response)
}

func (s *Server) handleDiscover(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	page, pageSize := paginationFromRequest(r)
	items, hasMore, err := s.loadDiscoverUsers(r.Context(), user.ID, normalizeText(r.URL.Query().Get("query")), page, pageSize)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load people")
		return
	}
	writeJSON(w, http.StatusOK, pagedResponse[friendCard]{Items: items, Page: page, PageSize: pageSize, HasMore: hasMore})
}

func (s *Server) handleNotifications(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	page, pageSize := paginationFromRequest(r)
	items, hasMore, err := s.loadNotifications(r.Context(), user.ID, page, pageSize)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load notifications")
		return
	}
	writeJSON(w, http.StatusOK, pagedResponse[notificationResponse]{Items: items, Page: page, PageSize: pageSize, HasMore: hasMore})
}

func (s *Server) handleNotificationSummary(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	summary, err := s.loadNotificationSummary(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load notification summary")
		return
	}
	writeJSON(w, http.StatusOK, summary)
}

func (s *Server) handleReadAllNotifications(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if _, err := s.db.ExecContext(r.Context(), `UPDATE "Notifications" SET "IsRead" = true WHERE "UserId" = $1`, user.ID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to mark notifications as read")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleReadNotification(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	notificationID, err := parseIDParam(r, "notificationID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	result, err := s.db.ExecContext(r.Context(), `UPDATE "Notifications" SET "IsRead" = true WHERE "Id" = $1 AND "UserId" = $2`, notificationID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to mark notification as read")
		return
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		writeError(w, http.StatusNotFound, "Notification not found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) loadFriends(ctx context.Context, viewerID int) ([]friendCard, error) {
	rows := []friendDiscoverRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			u."Id" AS id, u."Username" AS username, u."DisplayName" AS display_name, u."AboutMe" AS about_me,
			u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, u."LastSeenAt" AS last_seen_at,
			(SELECT COUNT(*) FROM "Follows" f WHERE f."FollowingId" = u."Id") AS followers_count,
			(SELECT COUNT(*) FROM "Posts" p WHERE p."UserId" = u."Id" AND p."IsHidden" = false AND p."IsRemoved" = false) AS posts_count,
			EXISTS(SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = u."Id") AS is_following,
			true AS is_friend,
			NULL AS incoming_request_id,
			NULL AS outgoing_request_id,
			EXISTS(SELECT 1 FROM "FollowRequests" fr WHERE fr."RequesterId" = $1 AND fr."TargetUserId" = u."Id" AND fr."Status" = 0) AS has_pending_follow_request,
			u."IsPrivateAccount" AS is_private_account,
			u."ProfileVisibility" AS profile_visibility
		FROM "Users" u
		WHERE EXISTS (
			SELECT 1 FROM "Friendships" fr
			WHERE (fr."UserAId" = $1 AND fr."UserBId" = u."Id") OR (fr."UserBId" = $1 AND fr."UserAId" = u."Id")
		)
		ORDER BY u."LastSeenAt" DESC
	`, viewerID); err != nil {
		return nil, err
	}
	return mapDiscoverRows(rows), nil
}

func (s *Server) loadFriendRequests(ctx context.Context, viewerID int) ([]friendRequestResponse, []friendRequestResponse, error) {
	rows := []struct {
		ID            int            `db:"id"`
		UserID        int            `db:"user_id"`
		Username      string         `db:"username"`
		DisplayName   sql.NullString `db:"display_name"`
		AboutMe       sql.NullString `db:"about_me"`
		AvatarURL     sql.NullString `db:"avatar_url"`
		AvatarScale   float64        `db:"avatar_scale"`
		AvatarOffsetX float64        `db:"avatar_offset_x"`
		AvatarOffsetY float64        `db:"avatar_offset_y"`
		LastSeenAt    time.Time      `db:"last_seen_at"`
		IsIncoming    bool           `db:"is_incoming"`
		CreatedAt     time.Time      `db:"created_at"`
	}{}

	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			fr."Id" AS id,
			CASE WHEN fr."ReceiverId" = $1 THEN sender."Id" ELSE receiver."Id" END AS user_id,
			CASE WHEN fr."ReceiverId" = $1 THEN sender."Username" ELSE receiver."Username" END AS username,
			CASE WHEN fr."ReceiverId" = $1 THEN sender."DisplayName" ELSE receiver."DisplayName" END AS display_name,
			CASE WHEN fr."ReceiverId" = $1 THEN sender."AboutMe" ELSE receiver."AboutMe" END AS about_me,
			CASE WHEN fr."ReceiverId" = $1 THEN sender."AvatarUrl" ELSE receiver."AvatarUrl" END AS avatar_url,
			CASE WHEN fr."ReceiverId" = $1 THEN sender."AvatarScale" ELSE receiver."AvatarScale" END AS avatar_scale,
			CASE WHEN fr."ReceiverId" = $1 THEN sender."AvatarOffsetX" ELSE receiver."AvatarOffsetX" END AS avatar_offset_x,
			CASE WHEN fr."ReceiverId" = $1 THEN sender."AvatarOffsetY" ELSE receiver."AvatarOffsetY" END AS avatar_offset_y,
			CASE WHEN fr."ReceiverId" = $1 THEN sender."LastSeenAt" ELSE receiver."LastSeenAt" END AS last_seen_at,
			(fr."ReceiverId" = $1) AS is_incoming,
			fr."CreatedAt" AS created_at
		FROM "FriendRequests" fr
		JOIN "Users" sender ON sender."Id" = fr."SenderId"
		JOIN "Users" receiver ON receiver."Id" = fr."ReceiverId"
		WHERE fr."SenderId" = $1 OR fr."ReceiverId" = $1
		ORDER BY fr."CreatedAt" DESC
	`, viewerID); err != nil {
		return nil, nil, err
	}

	incoming := make([]friendRequestResponse, 0)
	outgoing := make([]friendRequestResponse, 0)
	for _, row := range rows {
		lastSeen := row.LastSeenAt
		item := friendRequestResponse{
			ID:     row.ID,
			UserID: row.UserID,
			User: userPreview{
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
			AboutMe:    nullableString(row.AboutMe),
			IsIncoming: row.IsIncoming,
			CreatedAt:  row.CreatedAt,
		}
		if row.IsIncoming {
			incoming = append(incoming, item)
		} else {
			outgoing = append(outgoing, item)
		}
	}

	return incoming, outgoing, nil
}

func (s *Server) toggleFollow(ctx context.Context, viewerID, targetID int) (followToggleResponse, error) {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return followToggleResponse{}, err
	}
	defer tx.Rollback()

	var isPrivate bool
	if err := tx.GetContext(ctx, &isPrivate, `SELECT "IsPrivateAccount" FROM "Users" WHERE "Id" = $1`, targetID); err != nil {
		return followToggleResponse{}, err
	}

	var isFollowing bool
	if err := tx.GetContext(ctx, &isFollowing, `SELECT EXISTS(SELECT 1 FROM "Follows" WHERE "FollowerId" = $1 AND "FollowingId" = $2)`, viewerID, targetID); err != nil {
		return followToggleResponse{}, err
	}

	response := followToggleResponse{}
	if isFollowing {
		if _, err := tx.ExecContext(ctx, `DELETE FROM "Follows" WHERE "FollowerId" = $1 AND "FollowingId" = $2`, viewerID, targetID); err != nil {
			return response, err
		}
		response.IsFollowing = false
	} else if isPrivate {
		var requestID sql.NullInt64
		if err := tx.GetContext(ctx, &requestID, `
			SELECT COALESCE((SELECT "Id" FROM "FollowRequests" WHERE "RequesterId" = $1 AND "TargetUserId" = $2 AND "Status" = 0 LIMIT 1), 0)
		`, viewerID, targetID); err != nil {
			return response, err
		}
		if requestID.Int64 > 0 {
			if _, err := tx.ExecContext(ctx, `
				UPDATE "FollowRequests" SET "Status" = 3, "UpdatedAt" = NOW(), "ResolvedAt" = NOW() WHERE "Id" = $1
			`, requestID.Int64); err != nil {
				return response, err
			}
		} else {
			var insertedID int
			if err := tx.GetContext(ctx, &insertedID, `
				INSERT INTO "FollowRequests" ("RequesterId", "TargetUserId", "Status", "CreatedAt", "UpdatedAt")
				VALUES ($1, $2, 0, NOW(), NOW())
				ON CONFLICT ("RequesterId", "TargetUserId")
				DO UPDATE SET "Status" = 0, "UpdatedAt" = NOW(), "ResolvedAt" = NULL
				RETURNING "Id"
			`, viewerID, targetID); err != nil {
				return response, err
			}
			response.IsRequested = true
			response.RequestID = &insertedID
			_ = s.insertNotificationTx(ctx, tx, targetID, &viewerID, "follow_request", "requested to follow you", nil, nil, nil, nil, &viewerID)
		}
	} else {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO "Follows" ("FollowerId", "FollowingId", "CreatedAt")
			VALUES ($1, $2, NOW())
			ON CONFLICT ("FollowerId", "FollowingId") DO NOTHING
		`, viewerID, targetID); err != nil {
			return response, err
		}
		response.IsFollowing = true
		_ = s.insertNotificationTx(ctx, tx, targetID, &viewerID, "follow", "started following you", nil, nil, nil, nil, &viewerID)
	}

	if err := tx.Commit(); err != nil {
		return response, err
	}
	if err := s.db.GetContext(ctx, &response.FollowersCount, `SELECT COUNT(*) FROM "Follows" WHERE "FollowingId" = $1`, targetID); err != nil {
		return response, err
	}
	return response, nil
}

func (s *Server) loadDiscoverUsers(ctx context.Context, viewerID int, query string, page, pageSize int) ([]friendCard, bool, error) {
	offset := (page - 1) * pageSize
	search := "%"
	if query != "" {
		search = "%" + query + "%"
	}

	rows := []friendDiscoverRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			u."Id" AS id, u."Username" AS username, u."DisplayName" AS display_name, u."AboutMe" AS about_me,
			u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, u."LastSeenAt" AS last_seen_at,
			(SELECT COUNT(*) FROM "Follows" f WHERE f."FollowingId" = u."Id") AS followers_count,
			(SELECT COUNT(*) FROM "Posts" p WHERE p."UserId" = u."Id" AND p."IsHidden" = false AND p."IsRemoved" = false) AS posts_count,
			EXISTS(SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = u."Id") AS is_following,
			EXISTS(SELECT 1 FROM "Friendships" fr WHERE (fr."UserAId" = $1 AND fr."UserBId" = u."Id") OR (fr."UserBId" = $1 AND fr."UserAId" = u."Id")) AS is_friend,
			(SELECT fr."Id" FROM "FriendRequests" fr WHERE fr."SenderId" = u."Id" AND fr."ReceiverId" = $1 LIMIT 1) AS incoming_request_id,
			(SELECT fr."Id" FROM "FriendRequests" fr WHERE fr."SenderId" = $1 AND fr."ReceiverId" = u."Id" LIMIT 1) AS outgoing_request_id,
			EXISTS(SELECT 1 FROM "FollowRequests" fr WHERE fr."RequesterId" = $1 AND fr."TargetUserId" = u."Id" AND fr."Status" = 0) AS has_pending_follow_request,
			u."IsPrivateAccount" AS is_private_account,
			u."ProfileVisibility" AS profile_visibility
		FROM "Users" u
		WHERE u."Id" <> $1
		  AND (LOWER(u."Username") LIKE LOWER($2) OR LOWER(COALESCE(u."DisplayName", '')) LIKE LOWER($2))
		ORDER BY is_friend DESC, u."LastSeenAt" DESC
		LIMIT $3 OFFSET $4
	`, viewerID, search, pageSize+1, offset); err != nil {
		return nil, false, err
	}

	hasMore := len(rows) > pageSize
	if hasMore {
		rows = rows[:pageSize]
	}
	return mapDiscoverRows(rows), hasMore, nil
}

func (s *Server) loadNotifications(ctx context.Context, viewerID, page, pageSize int) ([]notificationResponse, bool, error) {
	offset := (page - 1) * pageSize
	rows := []notificationRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			n."Id" AS id, n."Type" AS type, n."Text" AS text, n."IsRead" AS is_read, n."CreatedAt" AS created_at,
			n."ActorUserId" AS actor_user_id, actor."Username" AS actor_username, actor."DisplayName" AS actor_display_name,
			actor."AvatarUrl" AS actor_avatar_url, actor."AvatarScale" AS actor_avatar_scale,
			actor."AvatarOffsetX" AS actor_avatar_offset_x, actor."AvatarOffsetY" AS actor_avatar_offset_y,
			actor."LastSeenAt" AS actor_last_seen_at, n."PostId" AS post_id, n."CommentId" AS comment_id,
			n."ConversationId" AS conversation_id, n."MessageId" AS message_id, n."RelatedUserId" AS related_user_id
		FROM "Notifications" n
		LEFT JOIN "Users" actor ON actor."Id" = n."ActorUserId"
		WHERE n."UserId" = $1
		ORDER BY n."CreatedAt" DESC
		LIMIT $2 OFFSET $3
	`, viewerID, pageSize+1, offset); err != nil {
		return nil, false, err
	}

	hasMore := len(rows) > pageSize
	if hasMore {
		rows = rows[:pageSize]
	}
	return mapNotificationRows(rows), hasMore, nil
}

func (s *Server) loadNotificationSummary(ctx context.Context, viewerID int) (notificationSummary, error) {
	var summary notificationSummary
	if err := s.db.GetContext(ctx, &summary.UnreadNotifications, `SELECT COUNT(*) FROM "Notifications" WHERE "UserId" = $1 AND "IsRead" = false`, viewerID); err != nil {
		return summary, err
	}
	if err := s.db.GetContext(ctx, &summary.IncomingFriendRequests, `SELECT COUNT(*) FROM "FriendRequests" WHERE "ReceiverId" = $1`, viewerID); err != nil {
		return summary, err
	}
	if err := s.db.GetContext(ctx, &summary.PendingFollowRequests, `SELECT COUNT(*) FROM "FollowRequests" WHERE "TargetUserId" = $1 AND "Status" = 0`, viewerID); err != nil {
		return summary, err
	}
	if err := s.db.GetContext(ctx, &summary.UnreadChats, `
		SELECT COUNT(*)
		FROM "Messages" m
		JOIN "Conversations" c ON c."Id" = m."ConversationId"
		WHERE m."SenderId" <> $1
		  AND ((c."UserAId" = $1 AND m."DeletedForUserA" = false) OR (c."UserBId" = $1 AND m."DeletedForUserB" = false))
		  AND m."IsHidden" = false AND m."IsRemoved" = false
		  AND (
			(c."UserAId" = $1 AND m."CreatedAt" > COALESCE(c."UserAReadAt", TIMESTAMP 'epoch'))
			OR (c."UserBId" = $1 AND m."CreatedAt" > COALESCE(c."UserBReadAt", TIMESTAMP 'epoch'))
		  )
	`, viewerID); err != nil {
		return summary, err
	}
	return summary, nil
}

func (s *Server) insertNotificationTx(ctx context.Context, tx *sqlx.Tx, userID int, actorUserID *int, typ, text string, postID, commentID, conversationID, messageID, relatedUserID *int) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO "Notifications" ("UserId", "ActorUserId", "Type", "Text", "IsRead", "CreatedAt", "PostId", "CommentId", "ConversationId", "MessageId", "RelatedUserId")
		VALUES ($1, $2, $3, $4, false, NOW(), $5, $6, $7, $8, $9)
	`, userID, actorUserID, typ, text, postID, commentID, conversationID, messageID, relatedUserID)
	return err
}

type friendDiscoverRow struct {
	ID                int            `db:"id"`
	Username          string         `db:"username"`
	DisplayName       sql.NullString `db:"display_name"`
	AboutMe           sql.NullString `db:"about_me"`
	AvatarURL         sql.NullString `db:"avatar_url"`
	AvatarScale       float64        `db:"avatar_scale"`
	AvatarOffsetX     float64        `db:"avatar_offset_x"`
	AvatarOffsetY     float64        `db:"avatar_offset_y"`
	LastSeenAt        time.Time      `db:"last_seen_at"`
	FollowersCount    int            `db:"followers_count"`
	PostsCount        int            `db:"posts_count"`
	IsFollowing       bool           `db:"is_following"`
	IsFriend          bool           `db:"is_friend"`
	IncomingRequestID sql.NullInt64  `db:"incoming_request_id"`
	OutgoingRequestID sql.NullInt64  `db:"outgoing_request_id"`
	HasPendingFollow  bool           `db:"has_pending_follow_request"`
	IsPrivateAccount  bool           `db:"is_private_account"`
	ProfileVisibility int            `db:"profile_visibility"`
}

type notificationRow struct {
	ID                 int             `db:"id"`
	Type               string          `db:"type"`
	Text               string          `db:"text"`
	IsRead             bool            `db:"is_read"`
	CreatedAt          time.Time       `db:"created_at"`
	ActorUserID        sql.NullInt64   `db:"actor_user_id"`
	ActorUsername      sql.NullString  `db:"actor_username"`
	ActorDisplayName   sql.NullString  `db:"actor_display_name"`
	ActorAvatarURL     sql.NullString  `db:"actor_avatar_url"`
	ActorAvatarScale   sql.NullFloat64 `db:"actor_avatar_scale"`
	ActorAvatarOffsetX sql.NullFloat64 `db:"actor_avatar_offset_x"`
	ActorAvatarOffsetY sql.NullFloat64 `db:"actor_avatar_offset_y"`
	ActorLastSeenAt    sql.NullTime    `db:"actor_last_seen_at"`
	PostID             sql.NullInt64   `db:"post_id"`
	CommentID          sql.NullInt64   `db:"comment_id"`
	ConversationID     sql.NullInt64   `db:"conversation_id"`
	MessageID          sql.NullInt64   `db:"message_id"`
	RelatedUserID      sql.NullInt64   `db:"related_user_id"`
}

func mapDiscoverRows(rows []friendDiscoverRow) []friendCard {
	items := make([]friendCard, 0, len(rows))
	for _, row := range rows {
		items = append(items, friendCard{
			ID:                row.ID,
			Username:          row.Username,
			DisplayName:       nullableString(row.DisplayName),
			AboutMe:           nullableString(row.AboutMe),
			AvatarURL:         nullableString(row.AvatarURL),
			AvatarScale:       row.AvatarScale,
			AvatarOffsetX:     row.AvatarOffsetX,
			AvatarOffsetY:     row.AvatarOffsetY,
			LastSeenAt:        row.LastSeenAt,
			IsOnline:          isOnline(row.LastSeenAt),
			FollowersCount:    row.FollowersCount,
			PostsCount:        row.PostsCount,
			IsFollowing:       row.IsFollowing,
			IsFriend:          row.IsFriend,
			IncomingRequestID: nullableInt(row.IncomingRequestID),
			OutgoingRequestID: nullableInt(row.OutgoingRequestID),
			HasPendingFollow:  row.HasPendingFollow,
			IsPrivateAccount:  row.IsPrivateAccount,
			ProfileVisibility: profileVisibilityName(row.ProfileVisibility),
		})
	}
	return items
}

func mapNotificationRows(rows []notificationRow) []notificationResponse {
	items := make([]notificationResponse, 0, len(rows))
	for _, row := range rows {
		var actor *userPreview
		if row.ActorUserID.Valid {
			var lastSeen *time.Time
			if row.ActorLastSeenAt.Valid {
				value := row.ActorLastSeenAt.Time
				lastSeen = &value
			}
			actor = &userPreview{
				ID:            int(row.ActorUserID.Int64),
				Username:      row.ActorUsername.String,
				DisplayName:   nullableString(row.ActorDisplayName),
				AvatarURL:     nullableString(row.ActorAvatarURL),
				AvatarScale:   nullableFloat(row.ActorAvatarScale, 1),
				AvatarOffsetX: nullableFloat(row.ActorAvatarOffsetX, 0),
				AvatarOffsetY: nullableFloat(row.ActorAvatarOffsetY, 0),
				LastSeenAt:    lastSeen,
				IsOnline:      row.ActorLastSeenAt.Valid && isOnline(row.ActorLastSeenAt.Time),
			}
		}
		items = append(items, notificationResponse{
			ID:             row.ID,
			Type:           row.Type,
			Text:           row.Text,
			IsRead:         row.IsRead,
			CreatedAt:      row.CreatedAt,
			Actor:          actor,
			PostID:         nullableInt(row.PostID),
			CommentID:      nullableInt(row.CommentID),
			ConversationID: nullableInt(row.ConversationID),
			MessageID:      nullableInt(row.MessageID),
			RelatedUserID:  nullableInt(row.RelatedUserID),
		})
	}
	return items
}

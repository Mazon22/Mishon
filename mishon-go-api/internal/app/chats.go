package app

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"strconv"
	"time"
)

func (s *Server) handleChats(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	items, err := s.loadChats(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load chats")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (s *Server) handleCreateOrGetDirectChat(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	peerID, err := parseIDParam(r, "userID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if peerID == user.ID {
		writeError(w, http.StatusBadRequest, "Cannot create a conversation with yourself")
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open transaction")
		return
	}
	defer tx.Rollback()

	var chatID int
	err = tx.GetContext(r.Context(), &chatID, `
		SELECT "Id"
		FROM "Conversations"
		WHERE ("UserAId" = $1 AND "UserBId" = $2) OR ("UserAId" = $2 AND "UserBId" = $1)
	`, user.ID, peerID)
	if errors.Is(err, sql.ErrNoRows) {
		if err := tx.GetContext(r.Context(), &chatID, `
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

	chats, err := s.loadChats(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load conversation")
		return
	}
	for _, chat := range chats {
		if chat.ID == chatID {
			writeJSON(w, http.StatusOK, chat)
			return
		}
	}

	writeError(w, http.StatusNotFound, "Conversation not found")
}

func (s *Server) handleChatMessages(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	chatID, err := parseIDParam(r, "chatID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	limit := clamp(parseIntWithDefault(r.URL.Query().Get("limit"), 30), 1, 100)
	beforeID := parseOptionalInt(r.URL.Query().Get("before"))
	items, err := s.loadMessages(r.Context(), user.ID, chatID, limit, beforeID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Conversation not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load messages")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (s *Server) handleSendMessage(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	chatID, err := parseIDParam(r, "chatID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var req createMessageRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	content := normalizeText(req.Content)
	if content == "" || len(content) > 1000 {
		writeError(w, http.StatusBadRequest, "Message content must be 1-1000 characters")
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open transaction")
		return
	}
	defer tx.Rollback()

	var peerID int
	if err := tx.GetContext(r.Context(), &peerID, `
		SELECT CASE WHEN "UserAId" = $2 THEN "UserBId" ELSE "UserAId" END
		FROM "Conversations"
		WHERE "Id" = $1 AND ("UserAId" = $2 OR "UserBId" = $2)
	`, chatID, user.ID); err != nil {
		writeError(w, http.StatusNotFound, "Conversation not found")
		return
	}

	var messageID int
	if err := tx.GetContext(r.Context(), &messageID, `
		INSERT INTO "Messages" ("ConversationId", "SenderId", "Content", "CreatedAt")
		VALUES ($1, $2, $3, NOW())
		RETURNING "Id"
	`, chatID, user.ID, content); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to send message")
		return
	}

	if _, err := tx.ExecContext(r.Context(), `
		UPDATE "Conversations"
		SET "UpdatedAt" = NOW(), "UserADeleted" = false, "UserBDeleted" = false
		WHERE "Id" = $1
	`, chatID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update conversation")
		return
	}

	_ = s.insertNotificationTx(r.Context(), tx, peerID, &user.ID, "message", "sent you a new message", nil, nil, &chatID, &messageID, &user.ID)

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save message")
		return
	}

	items, err := s.loadMessages(r.Context(), user.ID, chatID, 1, nil)
	if err != nil || len(items) == 0 {
		writeError(w, http.StatusInternalServerError, "Failed to load sent message")
		return
	}

	writeJSON(w, http.StatusCreated, items[len(items)-1])
}

func (s *Server) loadChats(ctx context.Context, viewerID int) ([]conversationResponse, error) {
	rows := []struct {
		ID                   int            `db:"id"`
		PeerID               int            `db:"peer_id"`
		Username             string         `db:"username"`
		DisplayName          sql.NullString `db:"display_name"`
		AvatarURL            sql.NullString `db:"avatar_url"`
		AvatarScale          float64        `db:"avatar_scale"`
		AvatarOffsetX        float64        `db:"avatar_offset_x"`
		AvatarOffsetY        float64        `db:"avatar_offset_y"`
		LastSeenAt           time.Time      `db:"last_seen_at"`
		PinOrder             sql.NullInt64  `db:"pin_order"`
		IsArchived           bool           `db:"is_archived"`
		IsFavorite           bool           `db:"is_favorite"`
		IsMuted              bool           `db:"is_muted"`
		LastMessage          sql.NullString `db:"last_message"`
		LastMessageAt        sql.NullTime   `db:"last_message_at"`
		LastMessageIsMine    bool           `db:"last_message_is_mine"`
		LastMessageDelivered bool           `db:"last_message_delivered"`
		LastMessageRead      bool           `db:"last_message_read"`
		UnreadCount          int            `db:"unread_count"`
	}{}

	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			c."Id" AS id,
			peer."Id" AS peer_id,
			peer."Username" AS username,
			peer."DisplayName" AS display_name,
			peer."AvatarUrl" AS avatar_url,
			peer."AvatarScale" AS avatar_scale,
			peer."AvatarOffsetX" AS avatar_offset_x,
			peer."AvatarOffsetY" AS avatar_offset_y,
			peer."LastSeenAt" AS last_seen_at,
			CASE WHEN c."UserAId" = $1 THEN c."UserAPinOrder" ELSE c."UserBPinOrder" END AS pin_order,
			CASE WHEN c."UserAId" = $1 THEN c."UserAArchived" ELSE c."UserBArchived" END AS is_archived,
			CASE WHEN c."UserAId" = $1 THEN c."UserAFavorite" ELSE c."UserBFavorite" END AS is_favorite,
			CASE WHEN c."UserAId" = $1 THEN c."UserAMuted" ELSE c."UserBMuted" END AS is_muted,
			last_message."Content" AS last_message,
			last_message."CreatedAt" AS last_message_at,
			COALESCE(last_message."SenderId" = $1, false) AS last_message_is_mine,
			COALESCE(last_message."DeliveredToPeerAt" IS NOT NULL, false) AS last_message_delivered,
			COALESCE(
				CASE
					WHEN last_message."SenderId" = $1 AND c."UserAId" = $1 THEN c."UserBReadAt" >= last_message."CreatedAt"
					WHEN last_message."SenderId" = $1 AND c."UserBId" = $1 THEN c."UserAReadAt" >= last_message."CreatedAt"
					ELSE false
				END,
				false
			) AS last_message_read,
			COALESCE(unread.unread_count, 0) AS unread_count
		FROM "Conversations" c
		JOIN "Users" peer ON peer."Id" = CASE WHEN c."UserAId" = $1 THEN c."UserBId" ELSE c."UserAId" END
		LEFT JOIN LATERAL (
			SELECT m.*
			FROM "Messages" m
			WHERE m."ConversationId" = c."Id"
			  AND CASE WHEN c."UserAId" = $1 THEN m."DeletedForUserA" = false ELSE m."DeletedForUserB" = false END
			  AND m."IsHidden" = false AND m."IsRemoved" = false
			ORDER BY m."CreatedAt" DESC
			LIMIT 1
		) last_message ON true
		LEFT JOIN LATERAL (
			SELECT COUNT(*) AS unread_count
			FROM "Messages" m
			WHERE m."ConversationId" = c."Id"
			  AND m."SenderId" <> $1
			  AND CASE WHEN c."UserAId" = $1 THEN m."DeletedForUserA" = false ELSE m."DeletedForUserB" = false END
			  AND m."IsHidden" = false AND m."IsRemoved" = false
			  AND m."CreatedAt" > COALESCE(CASE WHEN c."UserAId" = $1 THEN c."UserAReadAt" ELSE c."UserBReadAt" END, TIMESTAMP 'epoch')
		) unread ON true
		WHERE (c."UserAId" = $1 OR c."UserBId" = $1)
		  AND CASE WHEN c."UserAId" = $1 THEN c."UserADeleted" = false ELSE c."UserBDeleted" = false END
		ORDER BY (CASE WHEN c."UserAId" = $1 THEN c."UserAPinOrder" ELSE c."UserBPinOrder" END) NULLS LAST,
		         COALESCE(last_message."CreatedAt", c."UpdatedAt") DESC
	`, viewerID); err != nil {
		return nil, err
	}

	items := make([]conversationResponse, 0, len(rows))
	for _, row := range rows {
		lastSeen := row.LastSeenAt
		items = append(items, conversationResponse{
			ID: row.ID,
			Peer: userPreview{
				ID:            row.PeerID,
				Username:      row.Username,
				DisplayName:   nullableString(row.DisplayName),
				AvatarURL:     nullableString(row.AvatarURL),
				AvatarScale:   row.AvatarScale,
				AvatarOffsetX: row.AvatarOffsetX,
				AvatarOffsetY: row.AvatarOffsetY,
				LastSeenAt:    &lastSeen,
				IsOnline:      isOnline(row.LastSeenAt),
			},
			PinOrder:             nullableInt(row.PinOrder),
			IsPinned:             row.PinOrder.Valid,
			IsArchived:           row.IsArchived,
			IsFavorite:           row.IsFavorite,
			IsMuted:              row.IsMuted,
			LastMessage:          nullableString(row.LastMessage),
			LastMessageAt:        nullableTime(row.LastMessageAt),
			LastMessageIsMine:    row.LastMessageIsMine,
			LastMessageDelivered: row.LastMessageDelivered,
			LastMessageRead:      row.LastMessageRead,
			UnreadCount:          row.UnreadCount,
		})
	}

	return items, nil
}

func (s *Server) loadMessages(ctx context.Context, viewerID, chatID, limit int, beforeID *int) ([]messageResponse, error) {
	var convo struct {
		UserAID int `db:"user_a_id"`
		UserBID int `db:"user_b_id"`
	}
	if err := s.db.GetContext(ctx, &convo, `
		SELECT "UserAId" AS user_a_id, "UserBId" AS user_b_id
		FROM "Conversations"
		WHERE "Id" = $1 AND ("UserAId" = $2 OR "UserBId" = $2)
	`, chatID, viewerID); err != nil {
		return nil, err
	}

	beforeFilter := ""
	args := []any{chatID, limit}
	if beforeID != nil {
		beforeFilter = `AND m."Id" < $3`
		args = append(args, *beforeID)
	}

	rows := []struct {
		ID            int            `db:"id"`
		SenderID      int            `db:"sender_id"`
		Username      string         `db:"username"`
		DisplayName   sql.NullString `db:"display_name"`
		AvatarURL     sql.NullString `db:"avatar_url"`
		AvatarScale   float64        `db:"avatar_scale"`
		AvatarOffsetX float64        `db:"avatar_offset_x"`
		AvatarOffsetY float64        `db:"avatar_offset_y"`
		Content       string         `db:"content"`
		CreatedAt     time.Time      `db:"created_at"`
		EditedAt      sql.NullTime   `db:"edited_at"`
		LastSeenAt    time.Time      `db:"last_seen_at"`
	}{}

	visibilityColumn := `"DeletedForUserA"`
	if viewerID != convo.UserAID {
		visibilityColumn = `"DeletedForUserB"`
	}

	query := `
		SELECT
			m."Id" AS id, m."SenderId" AS sender_id, u."Username" AS username, u."DisplayName" AS display_name,
			u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, m."Content" AS content, m."CreatedAt" AS created_at,
			m."EditedAt" AS edited_at, u."LastSeenAt" AS last_seen_at
		FROM "Messages" m
		JOIN "Users" u ON u."Id" = m."SenderId"
		WHERE m."ConversationId" = $1
		  AND m.` + visibilityColumn + ` = false
		  AND m."IsHidden" = false
		  AND m."IsRemoved" = false
		  ` + beforeFilter + `
		ORDER BY m."Id" DESC
		LIMIT $2
	`
	if err := s.db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}

	readColumn := `"UserAReadAt"`
	if viewerID != convo.UserAID {
		readColumn = `"UserBReadAt"`
	}
	_, _ = s.db.ExecContext(ctx, `UPDATE "Conversations" SET `+readColumn+` = NOW() WHERE "Id" = $1`, chatID)
	_, _ = s.db.ExecContext(ctx, `
		UPDATE "Messages"
		SET "DeliveredToPeerAt" = COALESCE("DeliveredToPeerAt", NOW())
		WHERE "ConversationId" = $1 AND "SenderId" <> $2
	`, chatID, viewerID)

	items := make([]messageResponse, 0, len(rows))
	for index := len(rows) - 1; index >= 0; index-- {
		row := rows[index]
		lastSeen := row.LastSeenAt
		items = append(items, messageResponse{
			ID:             row.ID,
			ConversationID: chatID,
			Sender: userPreview{
				ID:            row.SenderID,
				Username:      row.Username,
				DisplayName:   nullableString(row.DisplayName),
				AvatarURL:     nullableString(row.AvatarURL),
				AvatarScale:   row.AvatarScale,
				AvatarOffsetX: row.AvatarOffsetX,
				AvatarOffsetY: row.AvatarOffsetY,
				LastSeenAt:    &lastSeen,
				IsOnline:      isOnline(row.LastSeenAt),
			},
			Content:   row.Content,
			CreatedAt: row.CreatedAt,
			EditedAt:  nullableTime(row.EditedAt),
			IsMine:    row.SenderID == viewerID,
		})
	}

	return items, nil
}

var _ = strconv.Itoa

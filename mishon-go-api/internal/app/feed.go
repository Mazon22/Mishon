package app

import (
	"context"
	"database/sql"
	"net/http"
	"strings"
	"time"
)

func (s *Server) handleProfilePosts(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	page, pageSize := paginationFromRequest(r)
	items, hasMore, err := s.loadUserPosts(r.Context(), user.ID, user.ID, page, pageSize)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load posts")
		return
	}

	writeJSON(w, http.StatusOK, pagedResponse[postResponse]{Items: items, Page: page, PageSize: pageSize, HasMore: hasMore})
}

func (s *Server) handleFeed(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	page, pageSize := paginationFromRequest(r)
	items, hasMore, err := s.loadFeed(r.Context(), user.ID, page, pageSize, r.URL.Query().Get("mode") == "following")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load feed")
		return
	}

	writeJSON(w, http.StatusOK, pagedResponse[postResponse]{Items: items, Page: page, PageSize: pageSize, HasMore: hasMore})
}

func (s *Server) handleCreatePost(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req createPostRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	content := normalizeText(req.Content)
	if content == "" || len(content) > 1000 {
		writeError(w, http.StatusBadRequest, "Post content must be 1-1000 characters")
		return
	}

	var postID int
	if err := s.db.GetContext(r.Context(), &postID, `
		INSERT INTO "Posts" ("UserId", "Content", "ImageUrl", "CreatedAt")
		VALUES ($1, $2, NULLIF($3, ''), NOW())
		RETURNING "Id"
	`, user.ID, content, normalizeText(req.ImageURL)); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create post")
		return
	}

	post, err := s.loadPostByID(r.Context(), user.ID, postID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load created post")
		return
	}

	writeJSON(w, http.StatusCreated, post)
}

func (s *Server) handleUpdatePost(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var req updatePostRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	content := normalizeText(req.Content)
	if content == "" || len(content) > 1000 {
		writeError(w, http.StatusBadRequest, "Post content must be 1-1000 characters")
		return
	}

	result, err := s.db.ExecContext(r.Context(), `
		UPDATE "Posts"
		SET "Content" = $3, "ImageUrl" = NULLIF($4, '')
		WHERE "Id" = $1 AND "UserId" = $2
	`, postID, user.ID, content, normalizeText(req.ImageURL))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update post")
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		writeError(w, http.StatusNotFound, "Post not found")
		return
	}

	post, err := s.loadPostByID(r.Context(), user.ID, postID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load updated post")
		return
	}

	writeJSON(w, http.StatusOK, post)
}

func (s *Server) handleDeletePost(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	result, err := s.db.ExecContext(r.Context(), `DELETE FROM "Posts" WHERE "Id" = $1 AND "UserId" = $2`, postID, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to delete post")
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		writeError(w, http.StatusNotFound, "Post not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleToggleLike(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
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

	var liked bool
	if err := tx.GetContext(r.Context(), &liked, `
		SELECT EXISTS(SELECT 1 FROM "Likes" WHERE "UserId" = $1 AND "PostId" = $2)
	`, user.ID, postID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to check like state")
		return
	}

	if liked {
		if _, err := tx.ExecContext(r.Context(), `DELETE FROM "Likes" WHERE "UserId" = $1 AND "PostId" = $2`, user.ID, postID); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to remove like")
			return
		}
	} else {
		if _, err := tx.ExecContext(r.Context(), `
			INSERT INTO "Likes" ("UserId", "PostId", "CreatedAt")
			VALUES ($1, $2, NOW())
			ON CONFLICT ("UserId", "PostId") DO NOTHING
		`, user.ID, postID); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to add like")
			return
		}

		var ownerID int
		if err := tx.GetContext(r.Context(), &ownerID, `SELECT "UserId" FROM "Posts" WHERE "Id" = $1`, postID); err == nil && ownerID != user.ID {
			_ = s.insertNotificationTx(r.Context(), tx, ownerID, &user.ID, "like", "liked your post", &postID, nil, nil, nil, nil)
		}
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save like")
		return
	}

	post, err := s.loadPostByID(r.Context(), user.ID, postID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load post")
		return
	}
	writeJSON(w, http.StatusOK, post)
}

func (s *Server) handleComments(w http.ResponseWriter, r *http.Request) {
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
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (s *Server) handleCreateComment(w http.ResponseWriter, r *http.Request) {
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

	var ownerID int
	if err := tx.GetContext(r.Context(), &ownerID, `SELECT "UserId" FROM "Posts" WHERE "Id" = $1`, postID); err == nil && ownerID != user.ID {
		_ = s.insertNotificationTx(r.Context(), tx, ownerID, &user.ID, "comment", "commented on your post", &postID, &commentID, nil, nil, nil)
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save comment")
		return
	}

	items, err := s.loadComments(r.Context(), user.ID, postID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to reload comments")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"items": items})
}

func (s *Server) loadFeed(ctx context.Context, viewerID, page, pageSize int, followingOnly bool) ([]postResponse, bool, error) {
	offset := (page - 1) * pageSize
	filter := ""
	if followingOnly {
		filter = `AND EXISTS (SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = p."UserId")`
	}

	rows := []postRow{}
	query := `
		SELECT
			p."Id" AS id, p."UserId" AS user_id, u."Username" AS username, u."DisplayName" AS display_name,
			u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, p."Content" AS content, p."ImageUrl" AS image_url,
			p."CreatedAt" AS created_at, COUNT(DISTINCT l."Id") AS likes_count, COUNT(DISTINCT c."Id") AS comments_count,
			EXISTS(SELECT 1 FROM "Likes" xl WHERE xl."UserId" = $1 AND xl."PostId" = p."Id") AS is_liked,
			EXISTS(SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = p."UserId") AS is_following_author,
			u."LastSeenAt" AS last_seen_at
		FROM "Posts" p
		JOIN "Users" u ON u."Id" = p."UserId"
		LEFT JOIN "Likes" l ON l."PostId" = p."Id"
		LEFT JOIN "Comments" c ON c."PostId" = p."Id" AND c."IsHidden" = false AND c."IsRemoved" = false
		WHERE p."IsHidden" = false
		  AND p."IsRemoved" = false
		  AND (u."Id" = $1 OR u."ProfileVisibility" = 0 OR EXISTS(SELECT 1 FROM "Follows" vf WHERE vf."FollowerId" = $1 AND vf."FollowingId" = u."Id"))
		  ` + filter + `
		GROUP BY p."Id", u."Id"
		ORDER BY p."CreatedAt" DESC
		LIMIT $2 OFFSET $3
	`
	if err := s.db.SelectContext(ctx, &rows, query, viewerID, pageSize+1, offset); err != nil {
		return nil, false, err
	}

	return mapPostRows(rows, pageSize), len(rows) > pageSize, nil
}

func (s *Server) loadUserPosts(ctx context.Context, viewerID, targetID, page, pageSize int) ([]postResponse, bool, error) {
	offset := (page - 1) * pageSize
	rows := []postRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			p."Id" AS id, p."UserId" AS user_id, u."Username" AS username, u."DisplayName" AS display_name,
			u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, p."Content" AS content, p."ImageUrl" AS image_url,
			p."CreatedAt" AS created_at, COUNT(DISTINCT l."Id") AS likes_count, COUNT(DISTINCT c."Id") AS comments_count,
			EXISTS(SELECT 1 FROM "Likes" xl WHERE xl."UserId" = $1 AND xl."PostId" = p."Id") AS is_liked,
			EXISTS(SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = p."UserId") AS is_following_author,
			u."LastSeenAt" AS last_seen_at
		FROM "Posts" p
		JOIN "Users" u ON u."Id" = p."UserId"
		LEFT JOIN "Likes" l ON l."PostId" = p."Id"
		LEFT JOIN "Comments" c ON c."PostId" = p."Id" AND c."IsHidden" = false AND c."IsRemoved" = false
		WHERE p."UserId" = $2 AND p."IsHidden" = false AND p."IsRemoved" = false
		GROUP BY p."Id", u."Id"
		ORDER BY p."CreatedAt" DESC
		LIMIT $3 OFFSET $4
	`, viewerID, targetID, pageSize+1, offset); err != nil {
		return nil, false, err
	}

	return mapPostRows(rows, pageSize), len(rows) > pageSize, nil
}

func (s *Server) loadPostByID(ctx context.Context, viewerID, postID int) (postResponse, error) {
	rows := []postRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			p."Id" AS id, p."UserId" AS user_id, u."Username" AS username, u."DisplayName" AS display_name,
			u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, p."Content" AS content, p."ImageUrl" AS image_url,
			p."CreatedAt" AS created_at, COUNT(DISTINCT l."Id") AS likes_count, COUNT(DISTINCT c."Id") AS comments_count,
			EXISTS(SELECT 1 FROM "Likes" xl WHERE xl."UserId" = $1 AND xl."PostId" = p."Id") AS is_liked,
			EXISTS(SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = p."UserId") AS is_following_author,
			u."LastSeenAt" AS last_seen_at
		FROM "Posts" p
		JOIN "Users" u ON u."Id" = p."UserId"
		LEFT JOIN "Likes" l ON l."PostId" = p."Id"
		LEFT JOIN "Comments" c ON c."PostId" = p."Id" AND c."IsHidden" = false AND c."IsRemoved" = false
		WHERE p."Id" = $2
		GROUP BY p."Id", u."Id"
	`, viewerID, postID); err != nil {
		return postResponse{}, err
	}
	if len(rows) == 0 {
		return postResponse{}, sql.ErrNoRows
	}

	return mapPostRows(rows, 1)[0], nil
}

type postRow struct {
	ID                int            `db:"id"`
	UserID            int            `db:"user_id"`
	Username          string         `db:"username"`
	DisplayName       sql.NullString `db:"display_name"`
	AvatarURL         sql.NullString `db:"avatar_url"`
	AvatarScale       float64        `db:"avatar_scale"`
	AvatarOffsetX     float64        `db:"avatar_offset_x"`
	AvatarOffsetY     float64        `db:"avatar_offset_y"`
	Content           string         `db:"content"`
	ImageURL          sql.NullString `db:"image_url"`
	CreatedAt         time.Time      `db:"created_at"`
	LikesCount        int            `db:"likes_count"`
	CommentsCount     int            `db:"comments_count"`
	IsLiked           bool           `db:"is_liked"`
	IsFollowingAuthor bool           `db:"is_following_author"`
	LastSeenAt        time.Time      `db:"last_seen_at"`
}

func (s *Server) loadComments(ctx context.Context, _ int, postID int) ([]commentResponse, error) {
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
		WHERE c."PostId" = $1 AND c."IsHidden" = false AND c."IsRemoved" = false
		ORDER BY c."CreatedAt" ASC
	`, postID); err != nil {
		return nil, err
	}

	items := make([]commentResponse, 0, len(rows))
	for _, row := range rows {
		lastSeen := row.LastSeenAt
		items = append(items, commentResponse{
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
		})
	}
	return items, nil
}

func mapPostRows(rows []postRow, pageSize int) []postResponse {
	if len(rows) > pageSize {
		rows = rows[:pageSize]
	}

	items := make([]postResponse, 0, len(rows))
	for _, row := range rows {
		lastSeen := row.LastSeenAt
		items = append(items, postResponse{
			ID:     row.ID,
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
			Content:           row.Content,
			ImageURL:          nullableString(row.ImageURL),
			CreatedAt:         row.CreatedAt,
			LikesCount:        row.LikesCount,
			CommentsCount:     row.CommentsCount,
			IsLiked:           row.IsLiked,
			IsFollowingAuthor: row.IsFollowingAuthor,
		})
	}
	return items
}

func normalizeText(value string) string {
	return strings.TrimSpace(value)
}

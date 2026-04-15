package app

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
)

var (
	errProfilePostsForbidden = errors.New("profile posts forbidden")
	errUnsupportedProfileTab = errors.New("unsupported profile tab")
)

func (s *Server) handleProfilePosts(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	targetID := user.ID
	if rawTargetID := strings.TrimSpace(r.URL.Query().Get("userId")); rawTargetID != "" {
		parsedTargetID, err := strconv.Atoi(rawTargetID)
		if err != nil || parsedTargetID <= 0 {
			writeError(w, http.StatusBadRequest, "Invalid userId")
			return
		}
		targetID = parsedTargetID
	}

	page, pageSize := paginationFromRequest(r)
	tab := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("tab")))
	if tab == "" {
		tab = "posts"
	}

	items, hasMore, err := s.loadProfileTabPosts(r.Context(), user.ID, targetID, tab, page, pageSize)
	if err != nil {
		switch {
		case errors.Is(err, sql.ErrNoRows):
			writeError(w, http.StatusNotFound, "Profile not found")
		case errors.Is(err, errProfilePostsForbidden):
			writeError(w, http.StatusForbidden, "Posts are not available for this profile")
		case errors.Is(err, errUnsupportedProfileTab):
			writeError(w, http.StatusBadRequest, "Unsupported profile tab")
		default:
			writeError(w, http.StatusInternalServerError, "Failed to load posts")
		}
		return
	}

	totalCount, err := s.countProfileTabPosts(r.Context(), user.ID, targetID, tab)
	if err != nil {
		switch {
		case errors.Is(err, sql.ErrNoRows):
			writeError(w, http.StatusNotFound, "Profile not found")
		case errors.Is(err, errProfilePostsForbidden):
			writeError(w, http.StatusForbidden, "Posts are not available for this profile")
		case errors.Is(err, errUnsupportedProfileTab):
			writeError(w, http.StatusBadRequest, "Unsupported profile tab")
		default:
			writeError(w, http.StatusInternalServerError, "Failed to load posts")
		}
		return
	}

	writeJSON(w, http.StatusOK, buildPagedResponse(normalizePostsMedia(r, items), page, pageSize, totalCount, hasMore))
}

func (s *Server) loadProfileTabPosts(ctx context.Context, viewerID, targetID int, tab string, page, pageSize int) ([]postResponse, bool, error) {
	profile, err := s.loadProfile(ctx, viewerID, targetID)
	if err != nil {
		return nil, false, err
	}

	status, err := s.loadUserBlockStatus(ctx, viewerID, targetID)
	if err != nil {
		return nil, false, err
	}

	_, canViewPosts, _, _, _ := computeProfileAccess(profile, viewerID == targetID, status)
	if !canViewPosts {
		return nil, false, errProfilePostsForbidden
	}

	switch tab {
	case "posts":
		return s.loadUserPosts(ctx, viewerID, targetID, page, pageSize)
	case "media":
		return s.loadUserMediaPosts(ctx, viewerID, targetID, page, pageSize)
	case "likes":
		return s.loadUserLikedPosts(ctx, viewerID, targetID, page, pageSize)
	default:
		return nil, false, errUnsupportedProfileTab
	}
}

func (s *Server) countProfileTabPosts(ctx context.Context, viewerID, targetID int, tab string) (int, error) {
	profile, err := s.loadProfile(ctx, viewerID, targetID)
	if err != nil {
		return 0, err
	}

	status, err := s.loadUserBlockStatus(ctx, viewerID, targetID)
	if err != nil {
		return 0, err
	}

	_, canViewPosts, _, _, _ := computeProfileAccess(profile, viewerID == targetID, status)
	if !canViewPosts {
		return 0, errProfilePostsForbidden
	}

	var count int
	switch tab {
	case "posts":
		err = s.db.GetContext(ctx, &count, `
			SELECT COUNT(*)
			FROM "Posts"
			WHERE "UserId" = $1
			  AND "IsHidden" = false
			  AND "IsRemoved" = false
		`, targetID)
	case "media":
		err = s.db.GetContext(ctx, &count, `
			SELECT COUNT(*)
			FROM "Posts"
			WHERE "UserId" = $1
			  AND "IsHidden" = false
			  AND "IsRemoved" = false
			  AND NULLIF(BTRIM(COALESCE("ImageUrl", '')), '') IS NOT NULL
		`, targetID)
	case "likes":
		err = s.db.GetContext(ctx, &count, `
			SELECT COUNT(*)
			FROM "Likes" liked
			JOIN "Posts" p ON p."Id" = liked."PostId"
			JOIN "Users" u ON u."Id" = p."UserId"
			WHERE liked."UserId" = $2
			  AND p."IsHidden" = false
			  AND p."IsRemoved" = false
			  AND (u."Id" = $1 OR u."ProfileVisibility" = 0 OR EXISTS(SELECT 1 FROM "Follows" vf WHERE vf."FollowerId" = $1 AND vf."FollowingId" = u."Id"))
		`, viewerID, targetID)
	default:
		return 0, errUnsupportedProfileTab
	}

	return count, err
}

func (s *Server) handleFeed(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	page, pageSize := paginationFromRequest(r)
	followingOnly := r.URL.Query().Get("mode") == "following"
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

	writeJSON(w, http.StatusOK, buildPagedResponse(normalizePostsMedia(r, items), page, pageSize, totalCount, hasMore))
}

func (s *Server) handleGetPost(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	post, err := s.loadPostByID(r.Context(), user.ID, postID)
	if err != nil {
		switch {
		case errors.Is(err, sql.ErrNoRows):
			writeError(w, http.StatusNotFound, "Post not found")
		default:
			writeError(w, http.StatusInternalServerError, "Failed to load post")
		}
		return
	}

	writeJSON(w, http.StatusOK, normalizePostMedia(r, post))
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
		INSERT INTO "Posts" ("UserId", "Content", "ImageUrl", "ImageMediaId", "CreatedAt")
		VALUES ($1, $2, NULLIF($3, ''), NULL, NOW())
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

	s.emitSyncGlobal("post.created", map[string]any{
		"postId":  postID,
		"userId":  user.ID,
		"content": post.Content,
	})
	s.emitNotificationSummarySync(r.Context(), user.ID)

	writeJSON(w, http.StatusCreated, normalizePostMedia(r, post))
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

	var currentImage sql.NullString
	if err := s.db.GetContext(r.Context(), &currentImage, `SELECT "ImageUrl" FROM "Posts" WHERE "Id" = $1 AND "UserId" = $2`, postID, user.ID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Post not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load post")
		return
	}

	result, err := s.db.ExecContext(r.Context(), `
		UPDATE "Posts"
		SET "Content" = $3,
		    "ImageUrl" = NULLIF($4, ''),
		    "ImageMediaId" = NULL
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

	s.cleanupManagedMediaIfOrphaned(r.Context(), currentImage.String)

	post, err := s.loadPostByID(r.Context(), user.ID, postID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load updated post")
		return
	}

	s.emitSyncGlobal("post.updated", map[string]any{
		"postId": postID,
		"userId": user.ID,
	})
	s.emitNotificationSummarySync(r.Context(), user.ID)

	writeJSON(w, http.StatusOK, normalizePostMedia(r, post))
}

func (s *Server) handleDeletePost(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var currentImage sql.NullString
	if err := s.db.GetContext(r.Context(), &currentImage, `SELECT "ImageUrl" FROM "Posts" WHERE "Id" = $1 AND "UserId" = $2`, postID, user.ID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Post not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load post")
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

	s.cleanupManagedMediaIfOrphaned(r.Context(), currentImage.String)

	s.emitSyncGlobal("post.deleted", map[string]any{
		"postId": postID,
		"userId": user.ID,
	})
	s.emitNotificationSummarySync(r.Context(), user.ID)

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

	s.emitSyncGlobal("post.interaction.changed", map[string]any{
		"postId": postID,
		"userId": user.ID,
	})
	s.emitNotificationSummarySync(r.Context(), user.ID, post.UserID)
	writeJSON(w, http.StatusOK, normalizePostMedia(r, post))
}

func (s *Server) handleComments(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	page, pageSize := paginationFromRequest(r)
	sortMode := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("sort")))
	if sortMode == "" {
		sortMode = "latest"
	}
	if sortMode != "latest" && sortMode != "top" {
		writeError(w, http.StatusBadRequest, "Unsupported comment sort")
		return
	}

	if rawParentCommentID := strings.TrimSpace(r.URL.Query().Get("parentCommentId")); rawParentCommentID != "" {
		parentCommentID, convErr := strconv.Atoi(rawParentCommentID)
		if convErr != nil || parentCommentID <= 0 {
			writeError(w, http.StatusBadRequest, "Invalid parentCommentId")
			return
		}

		items, totalCount, hasMore, loadErr := s.loadCommentRepliesPage(r.Context(), user.ID, postID, parentCommentID, page, pageSize)
		if loadErr != nil {
			writeError(w, http.StatusInternalServerError, "Failed to load comments")
			return
		}

		writeJSON(w, http.StatusOK, buildPagedResponse(normalizeCommentsMedia(r, items), page, pageSize, totalCount, hasMore))
		return
	}

	items, totalCount, hasMore, err := s.loadRootCommentsPage(r.Context(), user.ID, postID, sortMode, page, pageSize)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load comments")
		return
	}

	writeJSON(w, http.StatusOK, buildPagedResponse(normalizeCommentsMedia(r, items), page, pageSize, totalCount, hasMore))
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

	comment, err := s.loadCommentByID(r.Context(), user.ID, commentID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load comment")
		return
	}

	s.emitSyncGlobal("comment.created", map[string]any{
		"postId":    postID,
		"commentId": commentID,
		"userId":    user.ID,
	})
	s.emitNotificationSummarySync(r.Context(), user.ID, ownerID)
	writeJSON(w, http.StatusCreated, normalizeCommentMedia(r, comment))
}

func (s *Server) handleToggleBookmark(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var bookmarked bool
	if err := s.db.GetContext(r.Context(), &bookmarked, `
		SELECT EXISTS(SELECT 1 FROM "PostBookmarks" WHERE "UserId" = $1 AND "PostId" = $2)
	`, user.ID, postID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to check bookmark state")
		return
	}

	if bookmarked {
		if _, err := s.db.ExecContext(r.Context(), `DELETE FROM "PostBookmarks" WHERE "UserId" = $1 AND "PostId" = $2`, user.ID, postID); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to remove bookmark")
			return
		}
	} else {
		if _, err := s.db.ExecContext(r.Context(), `
			INSERT INTO "PostBookmarks" ("UserId", "PostId", "CreatedAt")
			VALUES ($1, $2, NOW())
			ON CONFLICT ("UserId", "PostId") DO NOTHING
		`, user.ID, postID); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to save bookmark")
			return
		}
	}

	post, err := s.loadPostByID(r.Context(), user.ID, postID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load post")
		return
	}

	s.emitSyncGlobal("post.bookmarked", map[string]any{
		"postId": postID,
		"userId": user.ID,
	})
	writeJSON(w, http.StatusOK, normalizePostMedia(r, post))
}

func (s *Server) handleBookmarkedPosts(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	page, pageSize := paginationFromRequest(r)

	items, hasMore, err := s.loadBookmarkedPosts(r.Context(), user.ID, page, pageSize)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load bookmarks")
		return
	}

	totalCount, err := s.countBookmarkedPosts(r.Context(), user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load bookmarks")
		return
	}

	writeJSON(w, http.StatusOK, buildPagedResponse(normalizePostsMedia(r, items), page, pageSize, totalCount, hasMore))
}

func (s *Server) handleToggleCommentLike(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	postID, err := parseIDParam(r, "postID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	commentID, err := parseIDParam(r, "commentID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var belongsToPost bool
	if err := s.db.GetContext(r.Context(), &belongsToPost, `
		SELECT EXISTS(
			SELECT 1 FROM "Comments"
			WHERE "Id" = $1 AND "PostId" = $2 AND "IsHidden" = false AND "IsRemoved" = false
		)
	`, commentID, postID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to check comment state")
		return
	}
	if !belongsToPost {
		writeError(w, http.StatusNotFound, "Comment not found")
		return
	}

	var liked bool
	if err := s.db.GetContext(r.Context(), &liked, `
		SELECT EXISTS(SELECT 1 FROM "CommentLikes" WHERE "UserId" = $1 AND "CommentId" = $2)
	`, user.ID, commentID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to check like state")
		return
	}

	if liked {
		if _, err := s.db.ExecContext(r.Context(), `DELETE FROM "CommentLikes" WHERE "UserId" = $1 AND "CommentId" = $2`, user.ID, commentID); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to remove like")
			return
		}
	} else {
		if _, err := s.db.ExecContext(r.Context(), `
			INSERT INTO "CommentLikes" ("UserId", "CommentId", "CreatedAt")
			VALUES ($1, $2, NOW())
			ON CONFLICT ("UserId", "CommentId") DO NOTHING
		`, user.ID, commentID); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to save like")
			return
		}
	}

	comment, err := s.loadCommentByID(r.Context(), user.ID, commentID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load comment")
		return
	}

	s.emitSyncGlobal("comment.liked", map[string]any{
		"postId":    postID,
		"commentId": commentID,
		"userId":    user.ID,
	})
	writeJSON(w, http.StatusOK, normalizeCommentMedia(r, comment))
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
			u."IsEmailVerified" AS is_verified, u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, p."Content" AS content, p."ImageUrl" AS image_url,
			p."CreatedAt" AS created_at, COUNT(DISTINCT l."UserId") AS likes_count, COUNT(DISTINCT c."Id") AS comments_count,
			EXISTS(SELECT 1 FROM "Likes" xl WHERE xl."UserId" = $1 AND xl."PostId" = p."Id") AS is_liked,
			EXISTS(SELECT 1 FROM "PostBookmarks" pb WHERE pb."UserId" = $1 AND pb."PostId" = p."Id") AS is_bookmarked,
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
			u."IsEmailVerified" AS is_verified, u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, p."Content" AS content, p."ImageUrl" AS image_url,
			p."CreatedAt" AS created_at, COUNT(DISTINCT l."UserId") AS likes_count, COUNT(DISTINCT c."Id") AS comments_count,
			EXISTS(SELECT 1 FROM "Likes" xl WHERE xl."UserId" = $1 AND xl."PostId" = p."Id") AS is_liked,
			EXISTS(SELECT 1 FROM "PostBookmarks" pb WHERE pb."UserId" = $1 AND pb."PostId" = p."Id") AS is_bookmarked,
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

func (s *Server) loadUserMediaPosts(ctx context.Context, viewerID, targetID, page, pageSize int) ([]postResponse, bool, error) {
	offset := (page - 1) * pageSize
	rows := []postRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			p."Id" AS id, p."UserId" AS user_id, u."Username" AS username, u."DisplayName" AS display_name,
			u."IsEmailVerified" AS is_verified, u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, p."Content" AS content, p."ImageUrl" AS image_url,
			p."CreatedAt" AS created_at, COUNT(DISTINCT l."UserId") AS likes_count, COUNT(DISTINCT c."Id") AS comments_count,
			EXISTS(SELECT 1 FROM "Likes" xl WHERE xl."UserId" = $1 AND xl."PostId" = p."Id") AS is_liked,
			EXISTS(SELECT 1 FROM "PostBookmarks" pb WHERE pb."UserId" = $1 AND pb."PostId" = p."Id") AS is_bookmarked,
			EXISTS(SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = p."UserId") AS is_following_author,
			u."LastSeenAt" AS last_seen_at
		FROM "Posts" p
		JOIN "Users" u ON u."Id" = p."UserId"
		LEFT JOIN "Likes" l ON l."PostId" = p."Id"
		LEFT JOIN "Comments" c ON c."PostId" = p."Id" AND c."IsHidden" = false AND c."IsRemoved" = false
		WHERE p."UserId" = $2
		  AND p."IsHidden" = false
		  AND p."IsRemoved" = false
		  AND NULLIF(BTRIM(COALESCE(p."ImageUrl", '')), '') IS NOT NULL
		GROUP BY p."Id", u."Id"
		ORDER BY p."CreatedAt" DESC
		LIMIT $3 OFFSET $4
	`, viewerID, targetID, pageSize+1, offset); err != nil {
		return nil, false, err
	}

	return mapPostRows(rows, pageSize), len(rows) > pageSize, nil
}

func (s *Server) loadUserLikedPosts(ctx context.Context, viewerID, targetID, page, pageSize int) ([]postResponse, bool, error) {
	offset := (page - 1) * pageSize
	rows := []postRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			p."Id" AS id, p."UserId" AS user_id, u."Username" AS username, u."DisplayName" AS display_name,
			u."IsEmailVerified" AS is_verified, u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, p."Content" AS content, p."ImageUrl" AS image_url,
			p."CreatedAt" AS created_at, COUNT(DISTINCT l."UserId") AS likes_count, COUNT(DISTINCT c."Id") AS comments_count,
			EXISTS(SELECT 1 FROM "Likes" xl WHERE xl."UserId" = $1 AND xl."PostId" = p."Id") AS is_liked,
			EXISTS(SELECT 1 FROM "PostBookmarks" pb WHERE pb."UserId" = $1 AND pb."PostId" = p."Id") AS is_bookmarked,
			EXISTS(SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = p."UserId") AS is_following_author,
			u."LastSeenAt" AS last_seen_at
		FROM "Likes" liked
		JOIN "Posts" p ON p."Id" = liked."PostId"
		JOIN "Users" u ON u."Id" = p."UserId"
		LEFT JOIN "Likes" l ON l."PostId" = p."Id"
		LEFT JOIN "Comments" c ON c."PostId" = p."Id" AND c."IsHidden" = false AND c."IsRemoved" = false
		WHERE liked."UserId" = $2
		  AND p."IsHidden" = false
		  AND p."IsRemoved" = false
		  AND (u."Id" = $1 OR u."ProfileVisibility" = 0 OR EXISTS(SELECT 1 FROM "Follows" vf WHERE vf."FollowerId" = $1 AND vf."FollowingId" = u."Id"))
		GROUP BY p."Id", u."Id", liked."CreatedAt"
		ORDER BY liked."CreatedAt" DESC, p."CreatedAt" DESC
		LIMIT $3 OFFSET $4
	`, viewerID, targetID, pageSize+1, offset); err != nil {
		return nil, false, err
	}

	return mapPostRows(rows, pageSize), len(rows) > pageSize, nil
}

func (s *Server) loadBookmarkedPosts(ctx context.Context, viewerID, page, pageSize int) ([]postResponse, bool, error) {
	offset := (page - 1) * pageSize
	rows := []postRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			p."Id" AS id, p."UserId" AS user_id, u."Username" AS username, u."DisplayName" AS display_name,
			u."IsEmailVerified" AS is_verified, u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, p."Content" AS content, p."ImageUrl" AS image_url,
			p."CreatedAt" AS created_at, COUNT(DISTINCT l."UserId") AS likes_count, COUNT(DISTINCT c."Id") AS comments_count,
			EXISTS(SELECT 1 FROM "Likes" xl WHERE xl."UserId" = $1 AND xl."PostId" = p."Id") AS is_liked,
			EXISTS(SELECT 1 FROM "PostBookmarks" pb WHERE pb."UserId" = $1 AND pb."PostId" = p."Id") AS is_bookmarked,
			EXISTS(SELECT 1 FROM "Follows" f WHERE f."FollowerId" = $1 AND f."FollowingId" = p."UserId") AS is_following_author,
			u."LastSeenAt" AS last_seen_at
		FROM "PostBookmarks" bookmarked
		JOIN "Posts" p ON p."Id" = bookmarked."PostId"
		JOIN "Users" u ON u."Id" = p."UserId"
		LEFT JOIN "Likes" l ON l."PostId" = p."Id"
		LEFT JOIN "Comments" c ON c."PostId" = p."Id" AND c."IsHidden" = false AND c."IsRemoved" = false
		WHERE bookmarked."UserId" = $1
		  AND p."IsHidden" = false
		  AND p."IsRemoved" = false
		GROUP BY p."Id", u."Id", bookmarked."CreatedAt"
		ORDER BY bookmarked."CreatedAt" DESC, p."CreatedAt" DESC
		LIMIT $2 OFFSET $3
	`, viewerID, pageSize+1, offset); err != nil {
		return nil, false, err
	}

	return mapPostRows(rows, pageSize), len(rows) > pageSize, nil
}

func (s *Server) countBookmarkedPosts(ctx context.Context, viewerID int) (int, error) {
	var count int
	err := s.db.GetContext(ctx, &count, `
		SELECT COUNT(*)
		FROM "PostBookmarks" bookmarked
		JOIN "Posts" p ON p."Id" = bookmarked."PostId"
		WHERE bookmarked."UserId" = $1
		  AND p."IsHidden" = false
		  AND p."IsRemoved" = false
	`, viewerID)
	return count, err
}

func (s *Server) loadPostByID(ctx context.Context, viewerID, postID int) (postResponse, error) {
	rows := []postRow{}
	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			p."Id" AS id, p."UserId" AS user_id, u."Username" AS username, u."DisplayName" AS display_name,
			u."IsEmailVerified" AS is_verified, u."AvatarUrl" AS avatar_url, u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x,
			u."AvatarOffsetY" AS avatar_offset_y, p."Content" AS content, p."ImageUrl" AS image_url,
			p."CreatedAt" AS created_at, COUNT(DISTINCT l."UserId") AS likes_count, COUNT(DISTINCT c."Id") AS comments_count,
			EXISTS(SELECT 1 FROM "Likes" xl WHERE xl."UserId" = $1 AND xl."PostId" = p."Id") AS is_liked,
			EXISTS(SELECT 1 FROM "PostBookmarks" pb WHERE pb."UserId" = $1 AND pb."PostId" = p."Id") AS is_bookmarked,
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
	IsVerified        bool           `db:"is_verified"`
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
	IsBookmarked      bool           `db:"is_bookmarked"`
	IsFollowingAuthor bool           `db:"is_following_author"`
	LastSeenAt        time.Time      `db:"last_seen_at"`
}

type commentRow struct {
	ID              int            `db:"id"`
	PostID          int            `db:"post_id"`
	UserID          int            `db:"user_id"`
	Username        string         `db:"username"`
	DisplayName     sql.NullString `db:"display_name"`
	IsVerified      bool           `db:"is_verified"`
	AvatarURL       sql.NullString `db:"avatar_url"`
	AvatarScale     float64        `db:"avatar_scale"`
	AvatarOffsetX   float64        `db:"avatar_offset_x"`
	AvatarOffsetY   float64        `db:"avatar_offset_y"`
	Content         string         `db:"content"`
	CreatedAt       time.Time      `db:"created_at"`
	EditedAt        sql.NullTime   `db:"edited_at"`
	ParentCommentID sql.NullInt64  `db:"parent_comment_id"`
	ReplyToUsername sql.NullString `db:"reply_to_username"`
	LikesCount      int            `db:"likes_count"`
	IsLiked         bool           `db:"is_liked"`
	RepliesCount    int            `db:"replies_count"`
	LastSeenAt      time.Time      `db:"last_seen_at"`
}

func (s *Server) selectCommentRows(ctx context.Context, query string, args ...any) ([]commentRow, error) {
	rows := []commentRow{}
	if err := s.db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}
	return rows, nil
}

func mapCommentRows(rows []commentRow) []commentResponse {
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
				IsVerified:    row.IsVerified,
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
			LikesCount:      row.LikesCount,
			IsLiked:         row.IsLiked,
			RepliesCount:    row.RepliesCount,
		})
	}
	return items
}

func (s *Server) loadComments(ctx context.Context, viewerID int, postID int) ([]commentResponse, error) {
	rows, err := s.selectCommentRows(ctx, `
		SELECT
			c."Id" AS id, c."PostId" AS post_id, c."UserId" AS user_id,
			u."Username" AS username, u."DisplayName" AS display_name, u."IsEmailVerified" AS is_verified, u."AvatarUrl" AS avatar_url,
			u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x, u."AvatarOffsetY" AS avatar_offset_y,
			c."Content" AS content, c."CreatedAt" AS created_at, c."EditedAt" AS edited_at,
			c."ParentCommentId" AS parent_comment_id, parent_user."Username" AS reply_to_username,
			COUNT(DISTINCT cl."UserId") AS likes_count,
			EXISTS(SELECT 1 FROM "CommentLikes" viewer_like WHERE viewer_like."UserId" = $1 AND viewer_like."CommentId" = c."Id") AS is_liked,
			COALESCE(reply_counts.replies_count, 0) AS replies_count,
			u."LastSeenAt" AS last_seen_at
		FROM "Comments" c
		JOIN "Users" u ON u."Id" = c."UserId"
		LEFT JOIN "Comments" parent_comment ON parent_comment."Id" = c."ParentCommentId"
		LEFT JOIN "Users" parent_user ON parent_user."Id" = parent_comment."UserId"
		LEFT JOIN "CommentLikes" cl ON cl."CommentId" = c."Id"
		LEFT JOIN (
			SELECT "ParentCommentId" AS parent_comment_id, COUNT(*)::int AS replies_count
			FROM "Comments"
			WHERE "PostId" = $2 AND "IsHidden" = false AND "IsRemoved" = false AND "ParentCommentId" IS NOT NULL
			GROUP BY "ParentCommentId"
		) reply_counts ON reply_counts.parent_comment_id = c."Id"
		WHERE c."PostId" = $2 AND c."IsHidden" = false AND c."IsRemoved" = false
		GROUP BY c."Id", u."Id", parent_user."Username", reply_counts.replies_count
		ORDER BY c."CreatedAt" ASC
	`, viewerID, postID)
	if err != nil {
		return nil, err
	}

	return mapCommentRows(rows), nil
}

func (s *Server) loadRootCommentsPage(ctx context.Context, viewerID, postID int, sortMode string, page, pageSize int) ([]commentResponse, int, bool, error) {
	var totalCount int
	if err := s.db.GetContext(ctx, &totalCount, `
		SELECT COUNT(*)
		FROM "Comments"
		WHERE "PostId" = $1 AND "IsHidden" = false AND "IsRemoved" = false AND "ParentCommentId" IS NULL
	`, postID); err != nil {
		return nil, 0, false, err
	}

	orderClause := `c."CreatedAt" DESC`
	if sortMode == "top" {
		orderClause = `likes_count DESC, replies_count DESC, c."CreatedAt" DESC`
	}

	offset := (page - 1) * pageSize
	rows, err := s.selectCommentRows(ctx, `
		SELECT
			c."Id" AS id, c."PostId" AS post_id, c."UserId" AS user_id,
			u."Username" AS username, u."DisplayName" AS display_name, u."IsEmailVerified" AS is_verified, u."AvatarUrl" AS avatar_url,
			u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x, u."AvatarOffsetY" AS avatar_offset_y,
			c."Content" AS content, c."CreatedAt" AS created_at, c."EditedAt" AS edited_at,
			c."ParentCommentId" AS parent_comment_id, parent_user."Username" AS reply_to_username,
			COUNT(DISTINCT cl."UserId") AS likes_count,
			EXISTS(SELECT 1 FROM "CommentLikes" viewer_like WHERE viewer_like."UserId" = $1 AND viewer_like."CommentId" = c."Id") AS is_liked,
			COALESCE(reply_counts.replies_count, 0) AS replies_count,
			u."LastSeenAt" AS last_seen_at
		FROM "Comments" c
		JOIN "Users" u ON u."Id" = c."UserId"
		LEFT JOIN "Comments" parent_comment ON parent_comment."Id" = c."ParentCommentId"
		LEFT JOIN "Users" parent_user ON parent_user."Id" = parent_comment."UserId"
		LEFT JOIN "CommentLikes" cl ON cl."CommentId" = c."Id"
		LEFT JOIN (
			SELECT "ParentCommentId" AS parent_comment_id, COUNT(*)::int AS replies_count
			FROM "Comments"
			WHERE "PostId" = $2 AND "IsHidden" = false AND "IsRemoved" = false AND "ParentCommentId" IS NOT NULL
			GROUP BY "ParentCommentId"
		) reply_counts ON reply_counts.parent_comment_id = c."Id"
		WHERE c."PostId" = $2
		  AND c."IsHidden" = false
		  AND c."IsRemoved" = false
		  AND c."ParentCommentId" IS NULL
		GROUP BY c."Id", u."Id", parent_user."Username", reply_counts.replies_count
		ORDER BY `+orderClause+`
		LIMIT $3 OFFSET $4
	`, viewerID, postID, pageSize+1, offset)
	if err != nil {
		return nil, 0, false, err
	}

	items := mapCommentRows(rows)
	hasMore := len(items) > pageSize
	if hasMore {
		items = items[:pageSize]
	}

	previewReplies, err := s.loadCommentPreviewReplies(ctx, viewerID, postID, items, 2)
	if err != nil {
		return nil, 0, false, err
	}
	for index := range items {
		items[index].PreviewReplies = previewReplies[items[index].ID]
	}

	return items, totalCount, hasMore, nil
}

func (s *Server) loadCommentRepliesPage(ctx context.Context, viewerID, postID, parentCommentID, page, pageSize int) ([]commentResponse, int, bool, error) {
	var totalCount int
	if err := s.db.GetContext(ctx, &totalCount, `
		SELECT COUNT(*)
		FROM "Comments"
		WHERE "PostId" = $1 AND "ParentCommentId" = $2 AND "IsHidden" = false AND "IsRemoved" = false
	`, postID, parentCommentID); err != nil {
		return nil, 0, false, err
	}

	offset := (page - 1) * pageSize
	rows, err := s.selectCommentRows(ctx, `
		SELECT
			c."Id" AS id, c."PostId" AS post_id, c."UserId" AS user_id,
			u."Username" AS username, u."DisplayName" AS display_name, u."IsEmailVerified" AS is_verified, u."AvatarUrl" AS avatar_url,
			u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x, u."AvatarOffsetY" AS avatar_offset_y,
			c."Content" AS content, c."CreatedAt" AS created_at, c."EditedAt" AS edited_at,
			c."ParentCommentId" AS parent_comment_id, parent_user."Username" AS reply_to_username,
			COUNT(DISTINCT cl."UserId") AS likes_count,
			EXISTS(SELECT 1 FROM "CommentLikes" viewer_like WHERE viewer_like."UserId" = $1 AND viewer_like."CommentId" = c."Id") AS is_liked,
			0 AS replies_count,
			u."LastSeenAt" AS last_seen_at
		FROM "Comments" c
		JOIN "Users" u ON u."Id" = c."UserId"
		LEFT JOIN "Comments" parent_comment ON parent_comment."Id" = c."ParentCommentId"
		LEFT JOIN "Users" parent_user ON parent_user."Id" = parent_comment."UserId"
		LEFT JOIN "CommentLikes" cl ON cl."CommentId" = c."Id"
		WHERE c."PostId" = $2
		  AND c."ParentCommentId" = $3
		  AND c."IsHidden" = false
		  AND c."IsRemoved" = false
		GROUP BY c."Id", u."Id", parent_user."Username"
		ORDER BY c."CreatedAt" ASC
		LIMIT $4 OFFSET $5
	`, viewerID, postID, parentCommentID, pageSize+1, offset)
	if err != nil {
		return nil, 0, false, err
	}

	items := mapCommentRows(rows)
	hasMore := len(items) > pageSize
	if hasMore {
		items = items[:pageSize]
	}

	return items, totalCount, hasMore, nil
}

func (s *Server) loadCommentPreviewReplies(ctx context.Context, viewerID, postID int, rootComments []commentResponse, limit int) (map[int][]commentResponse, error) {
	if len(rootComments) == 0 {
		return map[int][]commentResponse{}, nil
	}

	parentIDs := make([]int, 0, len(rootComments))
	for _, item := range rootComments {
		parentIDs = append(parentIDs, item.ID)
	}

	query, args, err := sqlx.In(`
		WITH ranked_replies AS (
			SELECT
				c."Id" AS id, c."PostId" AS post_id, c."UserId" AS user_id,
				u."Username" AS username, u."DisplayName" AS display_name, u."IsEmailVerified" AS is_verified, u."AvatarUrl" AS avatar_url,
				u."AvatarScale" AS avatar_scale, u."AvatarOffsetX" AS avatar_offset_x, u."AvatarOffsetY" AS avatar_offset_y,
				c."Content" AS content, c."CreatedAt" AS created_at, c."EditedAt" AS edited_at,
				c."ParentCommentId" AS parent_comment_id, parent_user."Username" AS reply_to_username,
				COUNT(DISTINCT cl."UserId") AS likes_count,
				EXISTS(SELECT 1 FROM "CommentLikes" viewer_like WHERE viewer_like."UserId" = ? AND viewer_like."CommentId" = c."Id") AS is_liked,
				0 AS replies_count,
				u."LastSeenAt" AS last_seen_at,
				ROW_NUMBER() OVER (PARTITION BY c."ParentCommentId" ORDER BY c."CreatedAt" ASC) AS reply_rank
			FROM "Comments" c
			JOIN "Users" u ON u."Id" = c."UserId"
			LEFT JOIN "Comments" parent_comment ON parent_comment."Id" = c."ParentCommentId"
			LEFT JOIN "Users" parent_user ON parent_user."Id" = parent_comment."UserId"
			LEFT JOIN "CommentLikes" cl ON cl."CommentId" = c."Id"
			WHERE c."PostId" = ?
			  AND c."IsHidden" = false
			  AND c."IsRemoved" = false
			  AND c."ParentCommentId" IN (?)
			GROUP BY c."Id", u."Id", parent_user."Username"
		)
		SELECT
			id, post_id, user_id, username, display_name, is_verified, avatar_url,
			avatar_scale, avatar_offset_x, avatar_offset_y, content, created_at,
			edited_at, parent_comment_id, reply_to_username, likes_count, is_liked,
			replies_count, last_seen_at
		FROM ranked_replies
		WHERE reply_rank <= ?
		ORDER BY parent_comment_id ASC, created_at ASC
	`, viewerID, postID, parentIDs, limit)
	if err != nil {
		return nil, err
	}

	query = s.db.Rebind(query)
	rows := []commentRow{}
	if err := s.db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}

	result := make(map[int][]commentResponse, len(parentIDs))
	for _, item := range mapCommentRows(rows) {
		parentID := 0
		if item.ParentCommentID != nil {
			parentID = *item.ParentCommentID
		}
		result[parentID] = append(result[parentID], item)
	}

	return result, nil
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
				IsVerified:    row.IsVerified,
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
			IsBookmarked:      row.IsBookmarked,
			IsFollowingAuthor: row.IsFollowingAuthor,
		})
	}
	return items
}

func normalizeText(value string) string {
	return strings.TrimSpace(value)
}

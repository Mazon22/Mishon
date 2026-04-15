package app

import (
	"database/sql"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
)

func resolveOptionalMediaURL(r *http.Request, value *string) *string {
	if value == nil {
		return nil
	}

	resolved := resolveMediaURL(r, *value)
	if resolved == "" {
		return nil
	}

	return &resolved
}

func resolveMediaURL(r *http.Request, raw string) string {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return ""
	}

	parsed, err := url.Parse(trimmed)
	if err == nil && parsed.IsAbs() {
		if shouldRewriteLocalMediaURL(parsed) && r != nil {
			return requestScheme(r) + "://" + r.Host + parsed.Path
		}

		return trimmed
	}

	if !strings.HasPrefix(trimmed, "/") || r == nil {
		return trimmed
	}

	return requestScheme(r) + "://" + r.Host + trimmed
}

func shouldRewriteLocalMediaURL(parsed *url.URL) bool {
	if parsed == nil {
		return false
	}

	host := strings.TrimSpace(parsed.Hostname())
	if host == "" {
		return false
	}

	if !strings.HasPrefix(parsed.Path, "/uploads/") && !strings.HasPrefix(parsed.Path, "/media/") {
		return false
	}

	if host == "localhost" || host == "0.0.0.0" || host == "::1" || host == "[::1]" {
		return true
	}

	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

func (s *Server) handleMedia(w http.ResponseWriter, r *http.Request) {
	key := strings.TrimSpace(chi.URLParam(r, "mediaKey"))
	if key == "" {
		writeError(w, http.StatusBadRequest, "Invalid media key")
		return
	}

	object, err := s.media.Open(r.Context(), key)
	if err != nil {
		switch {
		case errors.Is(err, sql.ErrNoRows):
			writeError(w, http.StatusNotFound, "Media not found")
		default:
			writeError(w, http.StatusInternalServerError, "Failed to load media")
		}
		return
	}
	defer object.Reader.Close()

	contentType := strings.TrimSpace(object.ContentType)
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	if object.SizeBytes > 0 {
		w.Header().Set("Content-Length", strconv.FormatInt(object.SizeBytes, 10))
	}
	if object.IsImage {
		w.Header().Set("Content-Disposition", "inline")
	}

	if _, err := io.Copy(w, object.Reader); err != nil {
		return
	}
}

func normalizeUserPreviewMedia(r *http.Request, preview userPreview) userPreview {
	preview.AvatarURL = resolveOptionalMediaURL(r, preview.AvatarURL)
	return preview
}

func normalizeProfileMedia(r *http.Request, profile profileResponse) profileResponse {
	profile.AvatarURL = resolveOptionalMediaURL(r, profile.AvatarURL)
	profile.BannerURL = resolveOptionalMediaURL(r, profile.BannerURL)
	return profile
}

func normalizePostMedia(r *http.Request, post postResponse) postResponse {
	post.Author = normalizeUserPreviewMedia(r, post.Author)
	post.ImageURL = resolveOptionalMediaURL(r, post.ImageURL)
	return post
}

func normalizePostsMedia(r *http.Request, posts []postResponse) []postResponse {
	items := make([]postResponse, 0, len(posts))
	for _, post := range posts {
		items = append(items, normalizePostMedia(r, post))
	}
	return items
}

func normalizeCommentMedia(r *http.Request, comment commentResponse) commentResponse {
	comment.Author = normalizeUserPreviewMedia(r, comment.Author)
	if len(comment.PreviewReplies) > 0 {
		replies := make([]commentResponse, 0, len(comment.PreviewReplies))
		for _, reply := range comment.PreviewReplies {
			replies = append(replies, normalizeCommentMedia(r, reply))
		}
		comment.PreviewReplies = replies
	}
	return comment
}

func normalizeCommentsMedia(r *http.Request, comments []commentResponse) []commentResponse {
	items := make([]commentResponse, 0, len(comments))
	for _, comment := range comments {
		items = append(items, normalizeCommentMedia(r, comment))
	}
	return items
}

func normalizeConversationMedia(r *http.Request, conversation conversationResponse) conversationResponse {
	conversation.Peer = normalizeUserPreviewMedia(r, conversation.Peer)
	return conversation
}

func normalizeConversationsMedia(r *http.Request, conversations []conversationResponse) []conversationResponse {
	items := make([]conversationResponse, 0, len(conversations))
	for _, conversation := range conversations {
		items = append(items, normalizeConversationMedia(r, conversation))
	}
	return items
}

func normalizeMessageMedia(r *http.Request, message messageResponse) messageResponse {
	message.Sender = normalizeUserPreviewMedia(r, message.Sender)
	return message
}

func normalizeMessagesMedia(r *http.Request, messages []messageResponse) []messageResponse {
	items := make([]messageResponse, 0, len(messages))
	for _, message := range messages {
		items = append(items, normalizeMessageMedia(r, message))
	}
	return items
}

func normalizeFriendCardMedia(r *http.Request, item friendCard) friendCard {
	item.AvatarURL = resolveOptionalMediaURL(r, item.AvatarURL)
	return item
}

func normalizeFriendCardsMedia(r *http.Request, items []friendCard) []friendCard {
	normalized := make([]friendCard, 0, len(items))
	for _, item := range items {
		normalized = append(normalized, normalizeFriendCardMedia(r, item))
	}
	return normalized
}

func normalizeFriendRequestMedia(r *http.Request, item friendRequestResponse) friendRequestResponse {
	item.User = normalizeUserPreviewMedia(r, item.User)
	return item
}

func normalizeFriendRequestsMedia(r *http.Request, items []friendRequestResponse) []friendRequestResponse {
	normalized := make([]friendRequestResponse, 0, len(items))
	for _, item := range items {
		normalized = append(normalized, normalizeFriendRequestMedia(r, item))
	}
	return normalized
}

func normalizeNotificationMedia(r *http.Request, item notificationResponse) notificationResponse {
	if item.Actor != nil {
		actor := normalizeUserPreviewMedia(r, *item.Actor)
		item.Actor = &actor
	}
	return item
}

func normalizeNotificationsMedia(r *http.Request, items []notificationResponse) []notificationResponse {
	normalized := make([]notificationResponse, 0, len(items))
	for _, item := range items {
		normalized = append(normalized, normalizeNotificationMedia(r, item))
	}
	return normalized
}

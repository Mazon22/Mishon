package app

import (
	"bytes"
	"context"
	"database/sql"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

const (
	maxProfileMediaBytes = 5 << 20
	maxPostImageBytes    = 10 << 20
	maxMessageFileBytes  = 20 << 20
	maxVoiceNoteBytes    = 15 << 20
)

var (
	errMediaTooLarge         = errors.New("media file exceeds the configured limit")
	errUnsupportedMediaType  = errors.New("unsupported media type")
	errMissingMediaAssetData = errors.New("missing media asset data")
)

type storedMedia struct {
	Key         string
	StoredValue string
	FileName    string
	ContentType string
	SizeBytes   int64
	IsImage     bool
}

type managedMediaRef struct {
	Key string
}

type mediaReadResult struct {
	FileName    string
	ContentType string
	SizeBytes   int64
	IsImage     bool
	Reader      io.ReadCloser
}

type mediaStore interface {
	Save(ctx context.Context, category string, file io.Reader, header *multipart.FileHeader) (storedMedia, error)
	Open(ctx context.Context, key string) (mediaReadResult, error)
	Delete(ctx context.Context, key string) error
	ParseStoredValue(raw string) (managedMediaRef, bool)
	ServesLocally() bool
	LocalDir() string
}

func newMediaStore(db *sqlx.DB) (mediaStore, error) {
	if db == nil {
		return nil, fmt.Errorf("database is required for media storage")
	}
	return postgresMediaStore{db: db}, nil
}

type postgresMediaStore struct {
	db *sqlx.DB
}

func (s postgresMediaStore) Save(ctx context.Context, category string, file io.Reader, header *multipart.FileHeader) (storedMedia, error) {
	upload, err := readValidatedUpload(category, file, header)
	if err != nil {
		return storedMedia{}, err
	}

	assetID := uuid.New()
	if _, err := s.db.ExecContext(ctx, `
		INSERT INTO "MediaAssets" (
			"Id", "Category", "FileName", "ContentType", "SizeBytes", "StorageData", "IsImage", "CreatedAt"
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
	`, assetID, upload.Category, upload.FileName, upload.ContentType, upload.SizeBytes, upload.Bytes, upload.IsImage); err != nil {
		return storedMedia{}, err
	}

	return storedMedia{
		Key:         assetID.String(),
		StoredValue: "/media/" + assetID.String(),
		FileName:    upload.FileName,
		ContentType: upload.ContentType,
		SizeBytes:   upload.SizeBytes,
		IsImage:     upload.IsImage,
	}, nil
}

func (s postgresMediaStore) Open(ctx context.Context, key string) (mediaReadResult, error) {
	assetID, err := uuid.Parse(strings.TrimSpace(key))
	if err != nil {
		return mediaReadResult{}, sql.ErrNoRows
	}

	var row struct {
		FileName    string `db:"file_name"`
		ContentType string `db:"content_type"`
		SizeBytes   int64  `db:"size_bytes"`
		IsImage     bool   `db:"is_image"`
		StorageData []byte `db:"storage_data"`
	}
	if err := s.db.GetContext(ctx, &row, `
		SELECT
			"FileName" AS file_name,
			"ContentType" AS content_type,
			"SizeBytes" AS size_bytes,
			"IsImage" AS is_image,
			"StorageData" AS storage_data
		FROM "MediaAssets"
		WHERE "Id" = $1
	`, assetID); err != nil {
		return mediaReadResult{}, err
	}
	if len(row.StorageData) == 0 {
		return mediaReadResult{}, errMissingMediaAssetData
	}

	return mediaReadResult{
		FileName:    row.FileName,
		ContentType: row.ContentType,
		SizeBytes:   row.SizeBytes,
		IsImage:     row.IsImage,
		Reader:      io.NopCloser(bytes.NewReader(row.StorageData)),
	}, nil
}

func (s postgresMediaStore) Delete(ctx context.Context, key string) error {
	assetID, err := uuid.Parse(strings.TrimSpace(key))
	if err != nil {
		return nil
	}
	if _, err := s.db.ExecContext(ctx, `DELETE FROM "MediaAssets" WHERE "Id" = $1`, assetID); err != nil {
		return err
	}
	return nil
}

func (s postgresMediaStore) ParseStoredValue(raw string) (managedMediaRef, bool) {
	key, ok := parseDatabaseMediaKey(raw)
	if !ok {
		return managedMediaRef{}, false
	}
	return managedMediaRef{Key: key}, true
}

func (s postgresMediaStore) ServesLocally() bool {
	return false
}

func (s postgresMediaStore) LocalDir() string {
	return ""
}

type localMediaStore struct {
	uploadsDir string
}

func newLocalMediaStore(uploadsDir string) localMediaStore {
	cleaned := filepath.Clean(strings.TrimSpace(uploadsDir))
	if cleaned == "." || cleaned == "" {
		cleaned = "uploads"
	}

	return localMediaStore{uploadsDir: cleaned}
}

func (s localMediaStore) Save(_ context.Context, category string, file io.Reader, header *multipart.FileHeader) (storedMedia, error) {
	key, err := buildLocalMediaObjectKey(category, header)
	if err != nil {
		return storedMedia{}, err
	}

	fullPath, err := s.fullPathForKey(key)
	if err != nil {
		return storedMedia{}, err
	}

	if err := os.MkdirAll(filepath.Dir(fullPath), 0o755); err != nil {
		return storedMedia{}, err
	}

	target, err := os.Create(fullPath)
	if err != nil {
		return storedMedia{}, err
	}
	defer target.Close()

	written, err := io.Copy(target, file)
	if err != nil {
		return storedMedia{}, err
	}

	contentType := strings.TrimSpace(header.Header.Get("Content-Type"))
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	return storedMedia{
		Key:         key,
		StoredValue: "/uploads/" + key,
		FileName:    safeUploadFileName(header.Filename),
		ContentType: contentType,
		SizeBytes:   written,
		IsImage:     strings.HasPrefix(strings.ToLower(contentType), "image/"),
	}, nil
}

func (s localMediaStore) Open(_ context.Context, key string) (mediaReadResult, error) {
	fullPath, err := s.fullPathForKey(key)
	if err != nil {
		return mediaReadResult{}, err
	}

	file, err := os.Open(fullPath)
	if err != nil {
		return mediaReadResult{}, err
	}

	info, err := file.Stat()
	if err != nil {
		_ = file.Close()
		return mediaReadResult{}, err
	}

	return mediaReadResult{
		FileName:    filepath.Base(fullPath),
		ContentType: "application/octet-stream",
		SizeBytes:   info.Size(),
		Reader:      file,
	}, nil
}

func (s localMediaStore) Delete(_ context.Context, key string) error {
	fullPath, err := s.fullPathForKey(key)
	if err != nil {
		return err
	}

	if err := os.Remove(fullPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}

	s.pruneEmptyParents(fullPath)
	return nil
}

func (s localMediaStore) ParseStoredValue(raw string) (managedMediaRef, bool) {
	key, ok := parseLocalMediaKey(raw)
	if !ok {
		return managedMediaRef{}, false
	}
	return managedMediaRef{Key: key}, true
}

func (s localMediaStore) ServesLocally() bool {
	return true
}

func (s localMediaStore) LocalDir() string {
	return s.uploadsDir
}

func (s localMediaStore) fullPathForKey(key string) (string, error) {
	cleanKey := strings.TrimSpace(strings.ReplaceAll(key, "\\", "/"))
	cleanKey = path.Clean(strings.TrimPrefix(cleanKey, "/"))
	if cleanKey == "." || cleanKey == "" || strings.HasPrefix(cleanKey, "../") {
		return "", fmt.Errorf("invalid media key")
	}

	fullPath := filepath.Clean(filepath.Join(s.uploadsDir, filepath.FromSlash(cleanKey)))
	root := filepath.Clean(s.uploadsDir)
	relative, err := filepath.Rel(root, fullPath)
	if err != nil {
		return "", err
	}
	if relative == ".." || strings.HasPrefix(relative, ".."+string(os.PathSeparator)) {
		return "", fmt.Errorf("invalid media path")
	}
	return fullPath, nil
}

func (s localMediaStore) pruneEmptyParents(filePath string) {
	root := filepath.Clean(s.uploadsDir)
	current := filepath.Dir(filePath)
	for current != "." && current != root {
		err := os.Remove(current)
		if err != nil {
			return
		}
		current = filepath.Dir(current)
	}
}

type validatedUpload struct {
	Category    string
	FileName    string
	ContentType string
	SizeBytes   int64
	Bytes       []byte
	IsImage     bool
}

func readValidatedUpload(category string, file io.Reader, header *multipart.FileHeader) (validatedUpload, error) {
	maxBytes := maxUploadBytes(category, header)
	buffer, err := io.ReadAll(io.LimitReader(file, maxBytes+1))
	if err != nil {
		return validatedUpload{}, err
	}
	if int64(len(buffer)) > maxBytes {
		return validatedUpload{}, errMediaTooLarge
	}
	if len(buffer) == 0 {
		return validatedUpload{}, fmt.Errorf("empty media file")
	}

	fileName := safeUploadFileName(header.Filename)
	contentType := detectUploadedContentType(header, buffer, fileName)
	isImage := strings.HasPrefix(strings.ToLower(contentType), "image/")
	isAudio := isAudioMedia(contentType, fileName)
	if strings.EqualFold(contentType, "video/webm") && isAudio {
		contentType = "audio/webm"
	}

	switch strings.TrimSpace(strings.ToLower(category)) {
	case "profile":
		if !isImage {
			return validatedUpload{}, errUnsupportedMediaType
		}
	case "posts":
		if !isImage {
			return validatedUpload{}, errUnsupportedMediaType
		}
	case "messages":
		if isBlockedVideo(contentType, fileName) {
			return validatedUpload{}, errUnsupportedMediaType
		}
		if isAudio && int64(len(buffer)) > maxVoiceNoteBytes {
			return validatedUpload{}, errMediaTooLarge
		}
	default:
		if isBlockedVideo(contentType, fileName) {
			return validatedUpload{}, errUnsupportedMediaType
		}
	}

	return validatedUpload{
		Category:    strings.TrimSpace(strings.ToLower(category)),
		FileName:    fileName,
		ContentType: contentType,
		SizeBytes:   int64(len(buffer)),
		Bytes:       buffer,
		IsImage:     isImage,
	}, nil
}

func maxUploadBytes(category string, header *multipart.FileHeader) int64 {
	switch strings.TrimSpace(strings.ToLower(category)) {
	case "profile":
		return maxProfileMediaBytes
	case "posts":
		return maxPostImageBytes
	case "messages":
		if isAudioMedia(strings.TrimSpace(header.Header.Get("Content-Type")), header.Filename) {
			return maxVoiceNoteBytes
		}
		return maxMessageFileBytes
	default:
		return maxMessageFileBytes
	}
}

func safeUploadFileName(name string) string {
	trimmed := strings.TrimSpace(name)
	if trimmed == "" {
		return uuid.NewString() + ".bin"
	}
	base := filepath.Base(trimmed)
	if base == "." || base == string(filepath.Separator) {
		return uuid.NewString() + ".bin"
	}
	return base
}

func detectUploadedContentType(header *multipart.FileHeader, data []byte, fileName string) string {
	contentType := strings.TrimSpace(header.Header.Get("Content-Type"))
	if separator := strings.Index(contentType, ";"); separator >= 0 {
		contentType = strings.TrimSpace(contentType[:separator])
	}

	if len(data) > 0 {
		sniff := http.DetectContentType(data[:minInt(len(data), 512)])
		if contentType == "" || contentType == "application/octet-stream" {
			contentType = sniff
		} else if shouldTrustDeclaredContentType(contentType, fileName) {
			return strings.ToLower(contentType)
		}
	}

	if contentType == "" {
		contentType = "application/octet-stream"
	}
	return strings.ToLower(contentType)
}

func shouldTrustDeclaredContentType(contentType, fileName string) bool {
	normalized := strings.ToLower(strings.TrimSpace(contentType))
	switch {
	case strings.HasPrefix(normalized, "image/"):
		return true
	case strings.HasPrefix(normalized, "audio/"):
		return true
	case normalized == "video/webm" && isAudioMedia(normalized, fileName):
		return true
	default:
		return normalized != ""
	}
}

func isBlockedVideo(contentType, fileName string) bool {
	normalized := strings.ToLower(strings.TrimSpace(contentType))
	return strings.HasPrefix(normalized, "video/") && !isAudioMedia(normalized, fileName)
}

func isAudioMedia(contentType, fileName string) bool {
	normalized := strings.ToLower(strings.TrimSpace(contentType))
	if strings.HasPrefix(normalized, "audio/") {
		return true
	}

	extension := strings.ToLower(strings.TrimSpace(filepath.Ext(fileName)))
	switch extension {
	case ".wav", ".mp3", ".m4a", ".aac", ".ogg", ".webm", ".opus":
		return true
	default:
		return false
	}
}

func buildLocalMediaObjectKey(category string, header *multipart.FileHeader) (string, error) {
	safeCategory := strings.Trim(strings.ToLower(category), "/\\ ")
	if safeCategory == "" {
		safeCategory = "misc"
	}

	extension := strings.ToLower(filepath.Ext(strings.TrimSpace(header.Filename)))
	if extension == "" {
		extension = ".bin"
	}

	fileName := uuid.NewString() + extension
	key := path.Clean(path.Join(safeCategory, fileName))
	if key == "." || strings.HasPrefix(key, "../") {
		return "", fmt.Errorf("invalid media key")
	}
	return key, nil
}

func parseLocalMediaKey(raw string) (string, bool) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return "", false
	}

	parsed, err := url.Parse(trimmed)
	if err == nil && parsed.IsAbs() {
		trimmed = parsed.Path
	}

	trimmed = strings.ReplaceAll(trimmed, "\\", "/")
	if strings.HasPrefix(trimmed, "uploads/") {
		trimmed = "/" + trimmed
	}
	if !strings.HasPrefix(trimmed, "/uploads/") {
		return "", false
	}

	cleanPath := path.Clean(trimmed)
	if !strings.HasPrefix(cleanPath, "/uploads/") {
		return "", false
	}

	key := strings.TrimPrefix(cleanPath, "/uploads/")
	key = strings.Trim(strings.ReplaceAll(key, "\\", "/"), "/")
	if key == "" {
		return "", false
	}
	return key, true
}

func parseDatabaseMediaKey(raw string) (string, bool) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return "", false
	}

	parsed, err := url.Parse(trimmed)
	if err == nil && parsed.IsAbs() {
		trimmed = parsed.Path
	}

	trimmed = strings.ReplaceAll(trimmed, "\\", "/")
	if !strings.HasPrefix(trimmed, "/") {
		trimmed = "/" + trimmed
	}

	cleanPath := path.Clean(trimmed)
	prefixes := []string{"/media/", "/api/v1/media/", "/api/media/"}
	for _, prefix := range prefixes {
		if !strings.HasPrefix(cleanPath, prefix) {
			continue
		}
		key := strings.Trim(strings.TrimPrefix(cleanPath, prefix), "/")
		if _, err := uuid.Parse(key); err == nil {
			return key, true
		}
	}

	return "", false
}

func (s *Server) saveUploadedFile(ctx context.Context, category string, file multipart.File, header *multipart.FileHeader) (storedMedia, error) {
	return s.media.Save(ctx, category, file, header)
}

func (s *Server) saveUploadedFileHeader(ctx context.Context, category string, header *multipart.FileHeader) (savedAttachment, error) {
	file, err := header.Open()
	if err != nil {
		return savedAttachment{}, err
	}
	defer file.Close()

	saved, err := s.saveUploadedFile(ctx, category, file, header)
	if err != nil {
		return savedAttachment{}, err
	}

	return savedAttachment{
		FileName:     saved.FileName,
		RelativePath: saved.StoredValue,
		ContentType:  saved.ContentType,
		SizeBytes:    saved.SizeBytes,
		IsImage:      saved.IsImage,
		MediaKey:     saved.Key,
	}, nil
}

func (s *Server) deleteStoredMedia(ctx context.Context, item storedMedia) {
	if strings.TrimSpace(item.Key) == "" {
		return
	}
	_ = s.media.Delete(ctx, item.Key)
}

func (s *Server) deleteStoredMediaBatch(ctx context.Context, items ...storedMedia) {
	seen := make(map[string]struct{}, len(items))
	for _, item := range items {
		key := strings.TrimSpace(item.Key)
		if key == "" {
			continue
		}
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		_ = s.media.Delete(ctx, key)
	}
}

func (s *Server) cleanupManagedMediaIfOrphaned(ctx context.Context, rawValues ...string) {
	seen := make(map[string]struct{}, len(rawValues))
	for _, rawValue := range rawValues {
		ref, ok := s.media.ParseStoredValue(rawValue)
		if !ok {
			continue
		}
		if _, exists := seen[ref.Key]; exists {
			continue
		}
		seen[ref.Key] = struct{}{}

		inUse, err := s.mediaKeyInUse(ctx, ref.Key)
		if err != nil || inUse {
			continue
		}
		_ = s.media.Delete(ctx, ref.Key)
	}
}

func (s *Server) mediaKeyInUse(ctx context.Context, key string) (bool, error) {
	trimmed := strings.TrimSpace(key)
	if trimmed == "" {
		return false, nil
	}

	var exists bool
	err := s.db.GetContext(ctx, &exists, `
		SELECT EXISTS (
			SELECT 1 FROM "Users"
			WHERE COALESCE("AvatarMediaId"::text, '') = $1
			   OR COALESCE("BannerMediaId"::text, '') = $1
			   OR POSITION($1 IN COALESCE("AvatarUrl", '')) > 0
			   OR POSITION($1 IN COALESCE("BannerUrl", '')) > 0
			UNION ALL
			SELECT 1 FROM "Posts"
			WHERE COALESCE("ImageMediaId"::text, '') = $1
			   OR POSITION($1 IN COALESCE("ImageUrl", '')) > 0
			UNION ALL
			SELECT 1 FROM "MessageAttachments"
			WHERE COALESCE("MediaAssetId"::text, '') = $1
			   OR POSITION($1 IN COALESCE("FileUrl", '')) > 0
			UNION ALL
			SELECT 1 FROM "Messages"
			WHERE POSITION($1 IN COALESCE("Content", '')) > 0
		)
	`, trimmed)
	return exists, err
}

package app

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"net/smtp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"golang.org/x/crypto/bcrypt"
)

const (
	authTokenKindEmailVerification = "email_verification"
	authTokenKindPasswordReset     = "password_reset"
	emailVerificationTTL           = 48 * time.Hour
	passwordResetTTL               = 1 * time.Hour
)

type tokenRequest struct {
	Token string `json:"token"`
}

type forgotPasswordRequest struct {
	Email string `json:"email"`
}

type resetPasswordRequest struct {
	Token       string `json:"token"`
	NewPassword string `json:"newPassword"`
}

type authTokenRow struct {
	ID         uuid.UUID    `db:"id"`
	UserID     int          `db:"user_id"`
	Kind       string       `db:"kind"`
	TokenHash  string       `db:"token_hash"`
	ExpiresAt  time.Time    `db:"expires_at"`
	ConsumedAt sql.NullTime `db:"consumed_at"`
}

func (s *Server) handleVerifyEmail(w http.ResponseWriter, r *http.Request) {
	var req tokenRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open transaction")
		return
	}
	defer tx.Rollback()

	userID, err := s.consumeAuthToken(r.Context(), tx, authTokenKindEmailVerification, req.Token)
	if err != nil {
		writeError(w, http.StatusBadRequest, "Verification token is not valid")
		return
	}

	if _, err := tx.ExecContext(r.Context(), `UPDATE "Users" SET "IsEmailVerified" = true WHERE "Id" = $1`, userID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to verify email")
		return
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to complete verification")
		return
	}

	s.emitSyncToUsers("profile.updated", []int{userID}, map[string]any{
		"userId": userID,
	})
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleResendVerification(w http.ResponseWriter, r *http.Request) {
	var req forgotPasswordRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	email := normalizeEmail(req.Email)
	if email == "" {
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}

	var user struct {
		ID              int  `db:"id"`
		IsEmailVerified bool `db:"is_email_verified"`
	}
	err := s.db.GetContext(r.Context(), &user, `
		SELECT "Id" AS id, "IsEmailVerified" AS is_email_verified
		FROM "Users"
		WHERE "NormalizedEmail" = $1
	`, email)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}
	if user.IsEmailVerified {
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}

	if issueErr := s.issueAndDispatchAuthToken(r.Context(), user.ID, email, authTokenKindEmailVerification); issueErr != nil {
		log.Printf("resend verification email failed for user %d: %v", user.ID, issueErr)
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleForgotPassword(w http.ResponseWriter, r *http.Request) {
	var req forgotPasswordRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	email := normalizeEmail(req.Email)
	if email == "" {
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}

	var user struct {
		ID int `db:"id"`
	}
	err := s.db.GetContext(r.Context(), &user, `
		SELECT "Id" AS id
		FROM "Users"
		WHERE "NormalizedEmail" = $1
		  AND "BannedAt" IS NULL
		  AND ("SuspendedUntil" IS NULL OR "SuspendedUntil" < NOW())
	`, email)
	if err == nil {
		if issueErr := s.issueAndDispatchAuthToken(r.Context(), user.ID, email, authTokenKindPasswordReset); issueErr != nil {
			log.Printf("forgot password email failed for user %d: %v", user.ID, issueErr)
		}
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleResetPassword(w http.ResponseWriter, r *http.Request) {
	var req resetPasswordRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if !isValidPassword(req.NewPassword) {
		writeError(w, http.StatusBadRequest, "Password must contain upper, lower case letters and digits")
		return
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 12)
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

	userID, err := s.consumeAuthToken(r.Context(), tx, authTokenKindPasswordReset, req.Token)
	if err != nil {
		writeError(w, http.StatusBadRequest, "Reset token is not valid")
		return
	}

	if _, err := tx.ExecContext(r.Context(), `
		UPDATE "Users"
		SET "PasswordHash" = $2
		WHERE "Id" = $1
	`, userID, string(passwordHash)); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to update password")
		return
	}

	if _, err := tx.ExecContext(r.Context(), `
		UPDATE "UserSessions"
		SET "RevokedAt" = NOW(), "RevocationReason" = 'password_reset'
		WHERE "UserId" = $1 AND "RevokedAt" IS NULL
	`, userID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to revoke sessions")
		return
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save password")
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) issueAndDispatchAuthToken(ctx context.Context, userID int, email, kind string) error {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	token, expiresAt, err := s.createAuthToken(ctx, tx, userID, kind)
	if err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return err
	}

	subject, body := s.authEmailContent(kind, token, expiresAt)
	return s.sendLifecycleEmail(email, subject, body)
}

func (s *Server) createAuthToken(ctx context.Context, tx *sqlx.Tx, userID int, kind string) (string, time.Time, error) {
	if tx == nil {
		return "", time.Time{}, fmt.Errorf("transaction is required")
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE "AuthTokens"
		SET "ConsumedAt" = NOW()
		WHERE "UserId" = $1
		  AND "Kind" = $2
		  AND "ConsumedAt" IS NULL
		  AND "ExpiresAt" > NOW()
	`, userID, kind); err != nil {
		return "", time.Time{}, err
	}

	tokenID := uuid.New()
	rawToken := generateStructuredToken(tokenID)
	expiresAt := time.Now().UTC().Add(tokenTTLForKind(kind))
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO "AuthTokens" (
			"Id", "UserId", "Kind", "TokenHash", "CreatedAt", "ExpiresAt"
		)
		VALUES ($1, $2, $3, $4, NOW(), $5)
	`, tokenID, userID, kind, hashToken(rawToken), expiresAt); err != nil {
		return "", time.Time{}, err
	}

	return rawToken, expiresAt, nil
}

func (s *Server) consumeAuthToken(ctx context.Context, tx *sqlx.Tx, kind, rawToken string) (int, error) {
	tokenID, ok := parseStructuredToken(rawToken)
	if !ok {
		return 0, fmt.Errorf("invalid token")
	}

	var row authTokenRow
	if err := tx.GetContext(ctx, &row, `
		SELECT
			"Id" AS id,
			"UserId" AS user_id,
			"Kind" AS kind,
			"TokenHash" AS token_hash,
			"ExpiresAt" AS expires_at,
			"ConsumedAt" AS consumed_at
		FROM "AuthTokens"
		WHERE "Id" = $1 AND "Kind" = $2
	`, tokenID, kind); err != nil {
		return 0, err
	}

	if row.TokenHash != hashToken(rawToken) || row.ConsumedAt.Valid || row.ExpiresAt.Before(time.Now().UTC()) {
		return 0, fmt.Errorf("expired or invalid token")
	}

	if _, err := tx.ExecContext(ctx, `UPDATE "AuthTokens" SET "ConsumedAt" = NOW() WHERE "Id" = $1`, tokenID); err != nil {
		return 0, err
	}

	return row.UserID, nil
}

func tokenTTLForKind(kind string) time.Duration {
	switch kind {
	case authTokenKindEmailVerification:
		return emailVerificationTTL
	case authTokenKindPasswordReset:
		return passwordResetTTL
	default:
		return passwordResetTTL
	}
}

func (s *Server) authEmailContent(kind, token string, expiresAt time.Time) (string, string) {
	var (
		subject string
		path    string
		label   string
	)

	switch kind {
	case authTokenKindEmailVerification:
		subject = "Verify your Mishon email"
		path = "/verify-email"
		label = "Verify your email"
	default:
		subject = "Reset your Mishon password"
		path = "/reset-password"
		label = "Reset your password"
	}

	link := strings.TrimRight(s.cfg.PublicBaseURL, "/") + path + "?token=" + urlQueryEscape(token)
	body := strings.Join([]string{
		label + ": " + link,
		"",
		"If the link does not open in your client, use this token manually:",
		token,
		"",
		"Expires at: " + expiresAt.UTC().Format(time.RFC3339),
	}, "\n")

	return subject, body
}

func (s *Server) sendLifecycleEmail(to, subject, body string) error {
	trimmedTo := strings.TrimSpace(to)
	if trimmedTo == "" {
		return nil
	}

	if strings.TrimSpace(s.cfg.SMTPHost) == "" || strings.TrimSpace(s.cfg.SMTPFrom) == "" {
		log.Printf("SMTP is not configured; email to %s with subject %q was not sent.\n%s", trimmedTo, subject, body)
		return nil
	}

	from := strings.TrimSpace(s.cfg.SMTPFrom)
	message := strings.Join([]string{
		"From: " + from,
		"To: " + trimmedTo,
		"Subject: " + subject,
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=UTF-8",
		"",
		body,
	}, "\r\n")

	address := fmt.Sprintf("%s:%d", strings.TrimSpace(s.cfg.SMTPHost), s.cfg.SMTPPort)
	var auth smtp.Auth
	if strings.TrimSpace(s.cfg.SMTPUsername) != "" || strings.TrimSpace(s.cfg.SMTPPassword) != "" {
		auth = smtp.PlainAuth("", s.cfg.SMTPUsername, s.cfg.SMTPPassword, strings.TrimSpace(s.cfg.SMTPHost))
	}

	return smtp.SendMail(address, auth, from, []string{trimmedTo}, []byte(message))
}

func urlQueryEscape(value string) string {
	replacer := strings.NewReplacer(
		"%", "%25",
		" ", "%20",
		"+", "%2B",
		"&", "%26",
		"=", "%3D",
		"?", "%3F",
		"#", "%23",
	)
	return replacer.Replace(strings.TrimSpace(value))
}

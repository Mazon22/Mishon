package app

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
)

type reportCreateRequest struct {
	TargetType string  `json:"targetType"`
	TargetID   int     `json:"targetId"`
	Reason     string  `json:"reason"`
	CustomNote *string `json:"customNote"`
}

type assignReportRequest struct {
	ModeratorUserID int `json:"moderatorUserId"`
}

type resolveReportRequest struct {
	Resolution      string     `json:"resolution"`
	ResolutionNote  *string    `json:"resolutionNote"`
	SuspensionUntil *time.Time `json:"suspensionUntil"`
}

type moderationActionRequest struct {
	UserID   int        `json:"userId"`
	Note     string     `json:"note"`
	ReportID *int       `json:"reportId"`
	Until    *time.Time `json:"until"`
}

type reportItemResponse struct {
	ID                      int       `json:"id"`
	Source                  string    `json:"source"`
	TargetType              string    `json:"targetType"`
	TargetID                int       `json:"targetId"`
	TargetUserID            *int      `json:"targetUserId,omitempty"`
	Reason                  string    `json:"reason"`
	Status                  string    `json:"status"`
	CreatedAt               time.Time `json:"createdAt"`
	AssignedModeratorUserID *int      `json:"assignedModeratorUserId,omitempty"`
	AssignedModeratorName   *string   `json:"assignedModeratorUsername,omitempty"`
}

type reportDetailResponse struct {
	ID                      int        `json:"id"`
	Source                  string     `json:"source"`
	TargetType              string     `json:"targetType"`
	TargetID                int        `json:"targetId"`
	TargetUserID            *int       `json:"targetUserId,omitempty"`
	Reason                  string     `json:"reason"`
	CustomNote              *string    `json:"customNote,omitempty"`
	Status                  string     `json:"status"`
	ReporterUserID          *int       `json:"reporterUserId,omitempty"`
	ReporterUsername        *string    `json:"reporterUsername,omitempty"`
	AssignedModeratorUserID *int       `json:"assignedModeratorUserId,omitempty"`
	AssignedModeratorName   *string    `json:"assignedModeratorUsername,omitempty"`
	Resolution              string     `json:"resolution"`
	ResolutionNote          *string    `json:"resolutionNote,omitempty"`
	CreatedAt               time.Time  `json:"createdAt"`
	UpdatedAt               time.Time  `json:"updatedAt"`
	ResolvedAt              *time.Time `json:"resolvedAt,omitempty"`
}

type moderationActionResponse struct {
	ID            int        `json:"id"`
	ActorUserID   int        `json:"actorUserId"`
	ActorUsername string     `json:"actorUsername"`
	TargetUserID  *int       `json:"targetUserId,omitempty"`
	ActionType    string     `json:"actionType"`
	TargetType    *string    `json:"targetType,omitempty"`
	TargetID      *int       `json:"targetId,omitempty"`
	ReportID      *int       `json:"reportId,omitempty"`
	Note          *string    `json:"note,omitempty"`
	CreatedAt     time.Time  `json:"createdAt"`
	ExpiresAt     *time.Time `json:"expiresAt,omitempty"`
}

func (s *Server) handleCreateReport(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	var req reportCreateRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	targetType := normalizeText(req.TargetType)
	reason := normalizeText(req.Reason)
	if req.TargetID <= 0 || reason == "" {
		writeError(w, http.StatusBadRequest, "Invalid report payload")
		return
	}

	targetUserID, err := s.resolveReportTargetUserID(r.Context(), targetType, req.TargetID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Reported target not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to resolve report target")
		return
	}

	var reportID int
	if err := s.db.GetContext(r.Context(), &reportID, `
		INSERT INTO "Reports" (
			"Source", "TargetType", "TargetId", "TargetUserId", "Reason", "CustomNote",
			"Status", "ReporterUserId", "Resolution", "CreatedAt", "UpdatedAt"
		)
		VALUES ($1, $2, $3, $4, $5, NULLIF($6, ''), 'Open', $7, 'None', NOW(), NOW())
		RETURNING "Id"
	`, "user", targetType, req.TargetID, targetUserID, reason, stringValue(req.CustomNote, nil), user.ID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to create report")
		return
	}

	report, err := s.loadReportDetail(r.Context(), reportID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load report")
		return
	}

	s.emitSyncGlobal("moderation.report.created", map[string]any{
		"reportId":     reportID,
		"targetType":   targetType,
		"targetId":     req.TargetID,
		"reporterId":   user.ID,
		"targetUserId": targetUserID,
	})

	writeJSON(w, http.StatusCreated, report)
}

func (s *Server) handleModerationReports(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Moderator") {
		writeError(w, http.StatusForbidden, "Moderator access is required")
		return
	}

	page, pageSize := paginationFromRequest(r)
	items, totalCount, err := s.loadReportsPage(r.Context(), page, pageSize)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to load reports")
		return
	}
	hasMore := page*pageSize < totalCount
	writeJSON(w, http.StatusOK, buildMobilePage(items, page, pageSize, totalCount, hasMore))
}

func (s *Server) handleModerationReportDetail(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Moderator") {
		writeError(w, http.StatusForbidden, "Moderator access is required")
		return
	}

	reportID, err := parseIDParam(r, "reportID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	report, err := s.loadReportDetail(r.Context(), reportID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "Report not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "Failed to load report")
		return
	}

	writeJSON(w, http.StatusOK, report)
}

func (s *Server) handleAssignReport(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Moderator") {
		writeError(w, http.StatusForbidden, "Moderator access is required")
		return
	}

	reportID, err := parseIDParam(r, "reportID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var req assignReportRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.ModeratorUserID <= 0 {
		writeError(w, http.StatusBadRequest, "Moderator user is required")
		return
	}
	if !hasRole(user.Role, "Admin") && req.ModeratorUserID != user.ID {
		writeError(w, http.StatusForbidden, "Only admins can assign reports to other moderators")
		return
	}

	if ok, err := s.userHasMinimumRole(r.Context(), req.ModeratorUserID, 1); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to validate moderator")
		return
	} else if !ok {
		writeError(w, http.StatusBadRequest, "Target user is not a moderator")
		return
	}

	if _, err := s.db.ExecContext(r.Context(), `
		UPDATE "Reports"
		SET "AssignedModeratorUserId" = $2,
		    "Status" = CASE WHEN "ResolvedAt" IS NULL THEN 'Assigned' ELSE "Status" END,
		    "UpdatedAt" = NOW()
		WHERE "Id" = $1
	`, reportID, req.ModeratorUserID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to assign report")
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleResolveReport(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Moderator") {
		writeError(w, http.StatusForbidden, "Moderator access is required")
		return
	}

	reportID, err := parseIDParam(r, "reportID")
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var req resolveReportRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	resolution := normalizeText(req.Resolution)
	if resolution == "" {
		resolution = "Resolved"
	}
	status := "Resolved"
	if strings.EqualFold(resolution, "reject") || strings.EqualFold(resolution, "rejected") {
		status = "Rejected"
	}

	if _, err := s.db.ExecContext(r.Context(), `
		UPDATE "Reports"
		SET "AssignedModeratorUserId" = COALESCE("AssignedModeratorUserId", $2),
		    "Status" = $3,
		    "Resolution" = $4,
		    "ResolutionNote" = NULLIF($5, ''),
		    "ResolvedAt" = NOW(),
		    "UpdatedAt" = NOW()
		WHERE "Id" = $1
	`, reportID, user.ID, status, resolution, stringValue(req.ResolutionNote, nil)); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to resolve report")
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleWarnUser(w http.ResponseWriter, r *http.Request) {
	s.handleModerationAction(w, r, "Warn")
}

func (s *Server) handleSuspendUser(w http.ResponseWriter, r *http.Request) {
	s.handleModerationAction(w, r, "Suspend")
}

func (s *Server) handleBanUser(w http.ResponseWriter, r *http.Request) {
	s.handleModerationAction(w, r, "Ban")
}

func (s *Server) handleUnbanUser(w http.ResponseWriter, r *http.Request) {
	s.handleModerationAction(w, r, "Unban")
}

func (s *Server) handleModerationAction(w http.ResponseWriter, r *http.Request, actionType string) {
	user := authUser(r.Context())
	if !hasRole(user.Role, "Moderator") {
		writeError(w, http.StatusForbidden, "Moderator access is required")
		return
	}

	var req moderationActionRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.UserID <= 0 {
		writeError(w, http.StatusBadRequest, "Target user is required")
		return
	}
	if !hasRole(user.Role, "Admin") && req.UserID == user.ID {
		writeError(w, http.StatusForbidden, "You cannot moderate your own account")
		return
	}

	tx, err := s.db.BeginTxx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to open moderation transaction")
		return
	}
	defer tx.Rollback()

	switch actionType {
	case "Warn":
		// No user row update required for warnings.
	case "Suspend":
		if req.Until == nil {
			writeError(w, http.StatusBadRequest, "Suspension expiry is required")
			return
		}
		if _, err := tx.ExecContext(r.Context(), `UPDATE "Users" SET "SuspendedUntil" = $2 WHERE "Id" = $1`, req.UserID, req.Until.UTC()); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to suspend user")
			return
		}
	case "Ban":
		if _, err := tx.ExecContext(r.Context(), `UPDATE "Users" SET "BannedAt" = NOW() WHERE "Id" = $1`, req.UserID); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to ban user")
			return
		}
	case "Unban":
		if _, err := tx.ExecContext(r.Context(), `UPDATE "Users" SET "BannedAt" = NULL, "SuspendedUntil" = NULL WHERE "Id" = $1`, req.UserID); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to unban user")
			return
		}
	default:
		writeError(w, http.StatusBadRequest, "Unsupported moderation action")
		return
	}

	action, err := s.insertModerationAction(r.Context(), tx, user, req, actionType)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to save moderation action")
		return
	}

	if req.ReportID != nil && *req.ReportID > 0 {
		if _, err := tx.ExecContext(r.Context(), `
			UPDATE "Reports"
			SET "AssignedModeratorUserId" = COALESCE("AssignedModeratorUserId", $2),
			    "Status" = 'Resolved',
			    "Resolution" = $3,
			    "ResolutionNote" = NULLIF($4, ''),
			    "ResolvedAt" = NOW(),
			    "UpdatedAt" = NOW()
			WHERE "Id" = $1
		`, *req.ReportID, user.ID, actionType, strings.TrimSpace(req.Note)); err != nil {
			writeError(w, http.StatusInternalServerError, "Failed to resolve report")
			return
		}
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to commit moderation action")
		return
	}

	s.emitSyncToUsers("profile.updated", []int{req.UserID}, map[string]any{
		"userId": req.UserID,
	})
	writeJSON(w, http.StatusOK, action)
}

func (s *Server) handleAssignModerator(w http.ResponseWriter, r *http.Request) {
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

	if _, err := s.db.ExecContext(r.Context(), `UPDATE "Users" SET "Role" = 1 WHERE "Id" = $1`, targetUserID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to assign moderator role")
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleRemoveModerator(w http.ResponseWriter, r *http.Request) {
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

	if _, err := s.db.ExecContext(r.Context(), `UPDATE "Users" SET "Role" = 0 WHERE "Id" = $1 AND "Role" = 1`, targetUserID); err != nil {
		writeError(w, http.StatusInternalServerError, "Failed to remove moderator role")
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) resolveReportTargetUserID(ctx context.Context, targetType string, targetID int) (*int, error) {
	var userID int
	switch targetType {
	case "user":
		if err := s.db.GetContext(ctx, &userID, `SELECT "Id" FROM "Users" WHERE "Id" = $1`, targetID); err != nil {
			return nil, err
		}
	case "post":
		if err := s.db.GetContext(ctx, &userID, `SELECT "UserId" FROM "Posts" WHERE "Id" = $1`, targetID); err != nil {
			return nil, err
		}
	case "comment":
		if err := s.db.GetContext(ctx, &userID, `SELECT "UserId" FROM "Comments" WHERE "Id" = $1`, targetID); err != nil {
			return nil, err
		}
	case "message":
		if err := s.db.GetContext(ctx, &userID, `SELECT "SenderId" FROM "Messages" WHERE "Id" = $1`, targetID); err != nil {
			return nil, err
		}
	default:
		return nil, errors.New("unsupported report target")
	}
	return &userID, nil
}

func (s *Server) loadReportsPage(ctx context.Context, page, pageSize int) ([]reportItemResponse, int, error) {
	offset := (page - 1) * pageSize
	rows := []struct {
		ID                      int            `db:"id"`
		Source                  string         `db:"source"`
		TargetType              string         `db:"target_type"`
		TargetID                int            `db:"target_id"`
		TargetUserID            sql.NullInt64  `db:"target_user_id"`
		Reason                  string         `db:"reason"`
		Status                  string         `db:"status"`
		CreatedAt               time.Time      `db:"created_at"`
		AssignedModeratorUserID sql.NullInt64  `db:"assigned_moderator_user_id"`
		AssignedModeratorName   sql.NullString `db:"assigned_moderator_username"`
	}{}

	if err := s.db.SelectContext(ctx, &rows, `
		SELECT
			r."Id" AS id,
			r."Source" AS source,
			r."TargetType" AS target_type,
			r."TargetId" AS target_id,
			r."TargetUserId" AS target_user_id,
			r."Reason" AS reason,
			r."Status" AS status,
			r."CreatedAt" AS created_at,
			r."AssignedModeratorUserId" AS assigned_moderator_user_id,
			moderator."Username" AS assigned_moderator_username
		FROM "Reports" r
		LEFT JOIN "Users" moderator ON moderator."Id" = r."AssignedModeratorUserId"
		ORDER BY
			CASE r."Status"
				WHEN 'Open' THEN 0
				WHEN 'Assigned' THEN 1
				ELSE 2
			END,
			r."CreatedAt" DESC
		LIMIT $1 OFFSET $2
	`, pageSize, offset); err != nil {
		return nil, 0, err
	}

	var totalCount int
	if err := s.db.GetContext(ctx, &totalCount, `SELECT COUNT(*) FROM "Reports"`); err != nil {
		return nil, 0, err
	}

	items := make([]reportItemResponse, 0, len(rows))
	for _, row := range rows {
		items = append(items, reportItemResponse{
			ID:                      row.ID,
			Source:                  row.Source,
			TargetType:              row.TargetType,
			TargetID:                row.TargetID,
			TargetUserID:            nullableInt(row.TargetUserID),
			Reason:                  row.Reason,
			Status:                  row.Status,
			CreatedAt:               row.CreatedAt,
			AssignedModeratorUserID: nullableInt(row.AssignedModeratorUserID),
			AssignedModeratorName:   nullableString(row.AssignedModeratorName),
		})
	}

	return items, totalCount, nil
}

func (s *Server) loadReportDetail(ctx context.Context, reportID int) (reportDetailResponse, error) {
	var row struct {
		ID                      int            `db:"id"`
		Source                  string         `db:"source"`
		TargetType              string         `db:"target_type"`
		TargetID                int            `db:"target_id"`
		TargetUserID            sql.NullInt64  `db:"target_user_id"`
		Reason                  string         `db:"reason"`
		CustomNote              sql.NullString `db:"custom_note"`
		Status                  string         `db:"status"`
		ReporterUserID          sql.NullInt64  `db:"reporter_user_id"`
		ReporterUsername        sql.NullString `db:"reporter_username"`
		AssignedModeratorUserID sql.NullInt64  `db:"assigned_moderator_user_id"`
		AssignedModeratorName   sql.NullString `db:"assigned_moderator_username"`
		Resolution              string         `db:"resolution"`
		ResolutionNote          sql.NullString `db:"resolution_note"`
		CreatedAt               time.Time      `db:"created_at"`
		UpdatedAt               time.Time      `db:"updated_at"`
		ResolvedAt              sql.NullTime   `db:"resolved_at"`
	}

	if err := s.db.GetContext(ctx, &row, `
		SELECT
			r."Id" AS id,
			r."Source" AS source,
			r."TargetType" AS target_type,
			r."TargetId" AS target_id,
			r."TargetUserId" AS target_user_id,
			r."Reason" AS reason,
			r."CustomNote" AS custom_note,
			r."Status" AS status,
			r."ReporterUserId" AS reporter_user_id,
			reporter."Username" AS reporter_username,
			r."AssignedModeratorUserId" AS assigned_moderator_user_id,
			moderator."Username" AS assigned_moderator_username,
			r."Resolution" AS resolution,
			r."ResolutionNote" AS resolution_note,
			r."CreatedAt" AS created_at,
			r."UpdatedAt" AS updated_at,
			r."ResolvedAt" AS resolved_at
		FROM "Reports" r
		LEFT JOIN "Users" reporter ON reporter."Id" = r."ReporterUserId"
		LEFT JOIN "Users" moderator ON moderator."Id" = r."AssignedModeratorUserId"
		WHERE r."Id" = $1
	`, reportID); err != nil {
		return reportDetailResponse{}, err
	}

	return reportDetailResponse{
		ID:                      row.ID,
		Source:                  row.Source,
		TargetType:              row.TargetType,
		TargetID:                row.TargetID,
		TargetUserID:            nullableInt(row.TargetUserID),
		Reason:                  row.Reason,
		CustomNote:              nullableString(row.CustomNote),
		Status:                  row.Status,
		ReporterUserID:          nullableInt(row.ReporterUserID),
		ReporterUsername:        nullableString(row.ReporterUsername),
		AssignedModeratorUserID: nullableInt(row.AssignedModeratorUserID),
		AssignedModeratorName:   nullableString(row.AssignedModeratorName),
		Resolution:              row.Resolution,
		ResolutionNote:          nullableString(row.ResolutionNote),
		CreatedAt:               row.CreatedAt,
		UpdatedAt:               row.UpdatedAt,
		ResolvedAt:              nullableTime(row.ResolvedAt),
	}, nil
}

func (s *Server) insertModerationAction(ctx context.Context, tx *sqlx.Tx, actor sessionUser, req moderationActionRequest, actionType string) (moderationActionResponse, error) {
	var id int
	note := strings.TrimSpace(req.Note)
	if err := tx.GetContext(ctx, &id, `
		INSERT INTO "ModerationActions" (
			"ActorUserId", "TargetUserId", "ActionType", "TargetType", "TargetId",
			"ReportId", "Note", "CreatedAt", "ExpiresAt"
		)
		VALUES ($1, $2, $3, 'user', $2, $4, NULLIF($5, ''), NOW(), $6)
		RETURNING "Id"
	`, actor.ID, req.UserID, actionType, req.ReportID, note, req.Until); err != nil {
		return moderationActionResponse{}, err
	}

	targetType := "user"
	return moderationActionResponse{
		ID:            id,
		ActorUserID:   actor.ID,
		ActorUsername: actor.Username,
		TargetUserID:  &req.UserID,
		ActionType:    actionType,
		TargetType:    &targetType,
		TargetID:      &req.UserID,
		ReportID:      req.ReportID,
		Note:          nullableTrimmedString(note),
		CreatedAt:     time.Now().UTC(),
		ExpiresAt:     req.Until,
	}, nil
}

func (s *Server) userHasMinimumRole(ctx context.Context, userID, minimum int) (bool, error) {
	var role int
	if err := s.db.GetContext(ctx, &role, `SELECT "Role" FROM "Users" WHERE "Id" = $1`, userID); err != nil {
		return false, err
	}
	return role >= minimum, nil
}

func hasRole(role, minimum string) bool {
	return roleRank(role) >= roleRank(minimum)
}

func roleRank(role string) int {
	switch strings.TrimSpace(role) {
	case "Admin":
		return 2
	case "Moderator":
		return 1
	default:
		return 0
	}
}

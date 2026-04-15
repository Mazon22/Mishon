package app

import (
	"database/sql"
	"strings"
	"testing"
	"time"
)

func newNullTime(value time.Time) sql.NullTime {
	return sql.NullTime{Time: value, Valid: true}
}

func TestNormalizeAdminUserFilter(t *testing.T) {
	t.Parallel()

	cases := map[string]string{
		"":           adminUserFilterAll,
		"ACTIVE":     adminUserFilterActive,
		"frozen":     adminUserFilterFrozen,
		"Admins":     adminUserFilterAdmins,
		"Moderators": adminUserFilterModerators,
		"unknown":    adminUserFilterAll,
	}

	for input, want := range cases {
		input := input
		want := want
		t.Run(input, func(t *testing.T) {
			t.Parallel()
			if got := normalizeAdminUserFilter(input); got != want {
				t.Fatalf("normalizeAdminUserFilter(%q) = %q, want %q", input, got, want)
			}
		})
	}
}

func TestNormalizeSupportStatusFilter(t *testing.T) {
	t.Parallel()

	cases := map[string]string{
		"":                "",
		"waitingforadmin": supportStatusWaitingForAdmin,
		"WaitingForUser":  supportStatusWaitingForUser,
		"CLOSED":          supportStatusClosed,
		"something-else":  "",
	}

	for input, want := range cases {
		input := input
		want := want
		t.Run(input, func(t *testing.T) {
			t.Parallel()
			if got := normalizeSupportStatusFilter(input); got != want {
				t.Fatalf("normalizeSupportStatusFilter(%q) = %q, want %q", input, got, want)
			}
		})
	}
}

func TestBuildSupportThreadsWhereClauseForAdminQuery(t *testing.T) {
	t.Parallel()

	whereClause, args := buildSupportThreadsWhereClause(true, supportStatusWaitingForAdmin, "mishon", nil)

	if !strings.Contains(whereClause, `t."Status" = $1`) {
		t.Fatalf("expected status predicate, got %q", whereClause)
	}
	if !strings.Contains(whereClause, `LIKE $2`) {
		t.Fatalf("expected search predicate, got %q", whereClause)
	}
	if len(args) != 2 {
		t.Fatalf("expected 2 args, got %d", len(args))
	}
	if status, ok := args[0].(string); !ok || status != supportStatusWaitingForAdmin {
		t.Fatalf("unexpected status arg: %#v", args[0])
	}
	if search, ok := args[1].(string); !ok || search != "%mishon%" {
		t.Fatalf("unexpected search arg: %#v", args[1])
	}
}

func TestAccountStatus(t *testing.T) {
	t.Parallel()

	now := time.Now().UTC().Add(2 * time.Hour)

	cases := []struct {
		name           string
		bannedAt       sql.NullTime
		suspendedUntil sql.NullTime
		want           string
	}{
		{
			name:           "frozen",
			suspendedUntil: newNullTime(now),
			want: "Frozen",
		},
		{
			name:     "banned",
			bannedAt: newNullTime(now),
			want: "Banned",
		},
		{
			name: "active",
			want: "Active",
		},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if got := accountStatus(tc.bannedAt, tc.suspendedUntil); got != tc.want {
				t.Fatalf("accountStatus() = %q, want %q", got, tc.want)
			}
		})
	}
}

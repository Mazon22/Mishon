package app

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

type syncWireEvent struct {
	ID         int64     `json:"id"`
	Type       string    `json:"type"`
	OccurredAt time.Time `json:"occurredAt"`
	Data       any       `json:"data,omitempty"`
}

type syncOutboundEvent struct {
	ID      int64
	Payload []byte
}

type syncHistoryEntry struct {
	Event   syncOutboundEvent
	Targets map[int]struct{}
}

type syncSubscription struct {
	UserID int
	ID     int64
	Events chan syncOutboundEvent
}

type syncBroker struct {
	mu               sync.RWMutex
	nextEventID      int64
	nextSubscription int64
	historyLimit     int
	history          []syncHistoryEntry
	subscribers      map[int]map[int64]chan syncOutboundEvent
}

func newSyncBroker(historyLimit int) *syncBroker {
	if historyLimit < 64 {
		historyLimit = 64
	}

	return &syncBroker{
		historyLimit: historyLimit,
		history:      make([]syncHistoryEntry, 0, historyLimit),
		subscribers:  make(map[int]map[int64]chan syncOutboundEvent),
	}
}

func (b *syncBroker) publishToUsers(userIDs []int, eventType string, data any) syncWireEvent {
	return b.publish(uniqueSyncUserIDs(userIDs), eventType, data)
}

func (b *syncBroker) publishGlobal(eventType string, data any) syncWireEvent {
	return b.publish(nil, eventType, data)
}

func (b *syncBroker) publish(targets []int, eventType string, data any) syncWireEvent {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.nextEventID++
	event := syncWireEvent{
		ID:         b.nextEventID,
		Type:       eventType,
		OccurredAt: time.Now().UTC(),
		Data:       data,
	}

	payload, err := json.Marshal(event)
	if err != nil {
		fallback := fmt.Sprintf(`{"id":%d,"type":"%s","occurredAt":"%s"}`, event.ID, event.Type, event.OccurredAt.Format(time.RFC3339Nano))
		payload = []byte(fallback)
	}

	outbound := syncOutboundEvent{
		ID:      event.ID,
		Payload: payload,
	}

	var targetSet map[int]struct{}
	if len(targets) > 0 {
		targetSet = make(map[int]struct{}, len(targets))
		for _, userID := range targets {
			targetSet[userID] = struct{}{}
		}
	}

	b.history = append(b.history, syncHistoryEntry{Event: outbound, Targets: targetSet})
	if len(b.history) > b.historyLimit {
		b.history = append([]syncHistoryEntry(nil), b.history[len(b.history)-b.historyLimit:]...)
	}

	if targetSet == nil {
		for _, subscriptions := range b.subscribers {
			for _, channel := range subscriptions {
				select {
				case channel <- outbound:
				default:
				}
			}
		}
		return event
	}

	for userID := range targetSet {
		for _, channel := range b.subscribers[userID] {
			select {
			case channel <- outbound:
			default:
			}
		}
	}

	return event
}

func (b *syncBroker) subscribe(userID int, lastEventID int64) ([]syncOutboundEvent, bool, syncSubscription, func()) {
	b.mu.Lock()
	defer b.mu.Unlock()

	overflow := false
	if lastEventID > 0 && len(b.history) > 0 && lastEventID < b.history[0].Event.ID {
		overflow = true
	}

	backlog := make([]syncOutboundEvent, 0)
	for _, entry := range b.history {
		if entry.Event.ID <= lastEventID {
			continue
		}
		if entry.Targets != nil {
			if _, ok := entry.Targets[userID]; !ok {
				continue
			}
		}
		backlog = append(backlog, entry.Event)
	}

	b.nextSubscription++
	subscriptionID := b.nextSubscription
	channel := make(chan syncOutboundEvent, 64)
	subscriptions := b.subscribers[userID]
	if subscriptions == nil {
		subscriptions = make(map[int64]chan syncOutboundEvent)
		b.subscribers[userID] = subscriptions
	}
	subscriptions[subscriptionID] = channel

	cancel := func() {
		b.mu.Lock()
		defer b.mu.Unlock()

		userSubscriptions := b.subscribers[userID]
		if userSubscriptions == nil {
			return
		}
		if existing, ok := userSubscriptions[subscriptionID]; ok {
			delete(userSubscriptions, subscriptionID)
			close(existing)
		}
		if len(userSubscriptions) == 0 {
			delete(b.subscribers, userID)
		}
	}

	return backlog, overflow, syncSubscription{
		UserID: userID,
		ID:     subscriptionID,
		Events: channel,
	}, cancel
}

func uniqueSyncUserIDs(userIDs []int) []int {
	if len(userIDs) == 0 {
		return nil
	}

	seen := make(map[int]struct{}, len(userIDs))
	items := make([]int, 0, len(userIDs))
	for _, userID := range userIDs {
		if userID <= 0 {
			continue
		}
		if _, ok := seen[userID]; ok {
			continue
		}
		seen[userID] = struct{}{}
		items = append(items, userID)
	}
	sort.Ints(items)
	return items
}

func parseSyncLastEventID(r *http.Request) int64 {
	for _, value := range []string{r.Header.Get("Last-Event-ID"), r.URL.Query().Get("lastEventId"), r.URL.Query().Get("lastEventID")} {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		if parsed, err := strconv.ParseInt(trimmed, 10, 64); err == nil && parsed >= 0 {
			return parsed
		}
	}
	return 0
}

func writeSyncSSE(w http.ResponseWriter, eventType string, outbound syncOutboundEvent) error {
	if _, err := fmt.Fprintf(w, "id: %d\n", outbound.ID); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(w, "event: %s\n", eventType); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(w, "data: %s\n\n", outbound.Payload); err != nil {
		return err
	}
	return nil
}

func (s *Server) touchUserPresence(ctx context.Context, userID int) error {
	if userID <= 0 {
		return nil
	}

	if _, err := s.db.ExecContext(ctx, `
		UPDATE "Users"
		SET "LastSeenAt" = NOW()
		WHERE "Id" = $1
	`, userID); err != nil {
		return err
	}

	s.emitSyncGlobal("presence.updated", map[string]any{
		"userId": userID,
	})
	return nil
}

func (s *Server) handleSyncStream(w http.ResponseWriter, r *http.Request) {
	user := authUser(r.Context())
	lastEventID := parseSyncLastEventID(r)

	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, http.StatusInternalServerError, "Streaming is not supported")
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache, no-transform")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	backlog, overflow, subscription, cancel := s.sync.subscribe(user.ID, lastEventID)
	defer cancel()

	lastPresenceTouch := time.Time{}
	touchPresence := func(force bool) {
		now := time.Now().UTC()
		if !force && !lastPresenceTouch.IsZero() && now.Sub(lastPresenceTouch) < time.Minute {
			return
		}
		if err := s.touchUserPresence(r.Context(), user.ID); err == nil {
			lastPresenceTouch = now
		}
	}

	touchPresence(true)

	if overflow {
		overflowPayload, _ := json.Marshal(syncWireEvent{
			ID:         0,
			Type:       "sync.resync",
			OccurredAt: time.Now().UTC(),
			Data: map[string]any{
				"reason": "history_truncated",
			},
		})
		_ = writeSyncSSE(w, "sync", syncOutboundEvent{ID: 0, Payload: overflowPayload})
		flusher.Flush()
	}

	for _, item := range backlog {
		if err := writeSyncSSE(w, "sync", item); err != nil {
			return
		}
		flusher.Flush()
	}

	helloPayload, _ := json.Marshal(syncWireEvent{
		ID:         0,
		Type:       "sync.hello",
		OccurredAt: time.Now().UTC(),
		Data: map[string]any{
			"userId":      user.ID,
			"lastEventId": lastEventID,
			"subscription": subscription.ID,
		},
	})
	if err := writeSyncSSE(w, "sync", syncOutboundEvent{ID: 0, Payload: helloPayload}); err != nil {
		return
	}
	flusher.Flush()

	heartbeat := time.NewTicker(20 * time.Second)
	defer heartbeat.Stop()

	for {
		select {
		case <-r.Context().Done():
			return
		case outbound, ok := <-subscription.Events:
			if !ok {
				return
			}
			if err := writeSyncSSE(w, "sync", outbound); err != nil {
				return
			}
			flusher.Flush()
		case <-heartbeat.C:
			exists, err := s.sessionIsValid(r.Context(), user.SessionID, user.ID)
			if err != nil || !exists {
				return
			}
			touchPresence(false)
			if _, err := w.Write([]byte(": keepalive\n\n")); err != nil {
				return
			}
			flusher.Flush()
		}
	}
}

func (s *Server) emitSyncToUsers(eventType string, userIDs []int, data any) {
	if s.sync == nil {
		return
	}
	s.sync.publishToUsers(userIDs, eventType, data)
}

func (s *Server) emitSyncGlobal(eventType string, data any) {
	if s.sync == nil {
		return
	}
	s.sync.publishGlobal(eventType, data)
}

func (s *Server) emitNotificationSummarySync(ctx context.Context, userIDs ...int) {
	for _, userID := range uniqueSyncUserIDs(userIDs) {
		summary, err := s.loadNotificationSummary(ctx, userID)
		if err != nil {
			continue
		}
		s.emitSyncToUsers("notification.summary.changed", []int{userID}, summary)
	}
}

func (s *Server) loadConversationParticipantIDs(ctx context.Context, conversationID int) ([]int, error) {
	var row struct {
		UserAID int `db:"user_a_id"`
		UserBID int `db:"user_b_id"`
	}

	if err := s.db.GetContext(ctx, &row, `
		SELECT "UserAId" AS user_a_id, "UserBId" AS user_b_id
		FROM "Conversations"
		WHERE "Id" = $1
	`, conversationID); err != nil {
		if err == sql.ErrNoRows {
			return nil, err
		}
		return nil, err
	}

	return uniqueSyncUserIDs([]int{row.UserAID, row.UserBID}), nil
}

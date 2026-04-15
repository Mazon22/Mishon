CREATE INDEX IF NOT EXISTS "idx_users_suspended_until" ON "Users" ("SuspendedUntil");
CREATE INDEX IF NOT EXISTS "idx_users_banned_at" ON "Users" ("BannedAt");

CREATE INDEX IF NOT EXISTS "idx_users_username_trgm"
    ON "Users" USING GIN ("NormalizedUsername" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "idx_users_email_trgm"
    ON "Users" USING GIN ("NormalizedEmail" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "idx_users_display_name_trgm"
    ON "Users" USING GIN (LOWER(COALESCE("DisplayName", '')) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS "idx_support_threads_status_updated"
    ON "SupportThreads" ("Status", "UpdatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_support_threads_user_updated"
    ON "SupportThreads" ("UserId", "UpdatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_support_messages_thread_created"
    ON "SupportMessages" ("ThreadId", "CreatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_support_threads_subject_trgm"
    ON "SupportThreads" USING GIN (LOWER("Subject") gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "idx_support_threads_preview_trgm"
    ON "SupportThreads" USING GIN (LOWER(COALESCE("LastMessagePreview", '')) gin_trgm_ops);

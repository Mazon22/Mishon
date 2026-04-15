CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO $$
DECLARE
    actor_fk_name text;
BEGIN
    SELECT tc.constraint_name
    INTO actor_fk_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema = kcu.table_schema
    WHERE tc.table_schema = current_schema()
      AND tc.table_name = 'ModerationActions'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND kcu.column_name = 'ActorUserId'
    LIMIT 1;

    IF actor_fk_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE "ModerationActions" DROP CONSTRAINT %I', actor_fk_name);
    END IF;
END $$;

ALTER TABLE IF EXISTS "ModerationActions"
    ALTER COLUMN "ActorUserId" DROP NOT NULL;

ALTER TABLE IF EXISTS "ModerationActions"
    ADD CONSTRAINT "ModerationActions_ActorUserId_fkey"
    FOREIGN KEY ("ActorUserId") REFERENCES "Users" ("Id") ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS "SupportThreads" (
    "Id" SERIAL PRIMARY KEY,
    "UserId" INTEGER NOT NULL REFERENCES "Users" ("Id") ON DELETE CASCADE,
    "Subject" TEXT NOT NULL,
    "Status" TEXT NOT NULL DEFAULT 'WaitingForAdmin',
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "LastMessageAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "LastMessagePreview" TEXT NULL,
    "LastMessageAuthorUserId" INTEGER NULL REFERENCES "Users" ("Id") ON DELETE SET NULL,
    "AdminUnreadCount" INTEGER NOT NULL DEFAULT 0,
    "UserUnreadCount" INTEGER NOT NULL DEFAULT 0,
    "ClosedAt" TIMESTAMPTZ NULL,
    "ClosedByUserId" INTEGER NULL REFERENCES "Users" ("Id") ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS "SupportMessages" (
    "Id" SERIAL PRIMARY KEY,
    "ThreadId" INTEGER NOT NULL REFERENCES "SupportThreads" ("Id") ON DELETE CASCADE,
    "AuthorUserId" INTEGER NULL REFERENCES "Users" ("Id") ON DELETE SET NULL,
    "Content" TEXT NOT NULL,
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "ReadAt" TIMESTAMPTZ NULL
);

UPDATE "Users"
SET "Role" = 2
WHERE "NormalizedUsername" = 'mishon'
  AND "Role" < 2;

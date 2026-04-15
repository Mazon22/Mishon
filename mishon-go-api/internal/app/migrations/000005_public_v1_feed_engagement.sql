CREATE TABLE IF NOT EXISTS "CommentLikes" (
    "UserId" INTEGER NOT NULL REFERENCES "Users" ("Id") ON DELETE CASCADE,
    "CommentId" INTEGER NOT NULL REFERENCES "Comments" ("Id") ON DELETE CASCADE,
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY ("UserId", "CommentId")
);

CREATE TABLE IF NOT EXISTS "PostBookmarks" (
    "UserId" INTEGER NOT NULL REFERENCES "Users" ("Id") ON DELETE CASCADE,
    "PostId" INTEGER NOT NULL REFERENCES "Posts" ("Id") ON DELETE CASCADE,
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY ("UserId", "PostId")
);

CREATE INDEX IF NOT EXISTS "idx_comments_post_parent_created_desc"
    ON "Comments" ("PostId", "ParentCommentId", "CreatedAt" DESC);

CREATE INDEX IF NOT EXISTS "idx_comment_likes_comment_id"
    ON "CommentLikes" ("CommentId");

CREATE INDEX IF NOT EXISTS "idx_comment_likes_user_id"
    ON "CommentLikes" ("UserId", "CreatedAt" DESC);

CREATE INDEX IF NOT EXISTS "idx_post_bookmarks_user_created"
    ON "PostBookmarks" ("UserId", "CreatedAt" DESC);

CREATE INDEX IF NOT EXISTS "idx_post_bookmarks_post_id"
    ON "PostBookmarks" ("PostId");

CREATE INDEX IF NOT EXISTS "idx_users_last_seen" ON "Users" ("LastSeenAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_users_role" ON "Users" ("Role");

CREATE INDEX IF NOT EXISTS "idx_user_sessions_user_id" ON "UserSessions" ("UserId");
CREATE INDEX IF NOT EXISTS "idx_user_sessions_expires_at" ON "UserSessions" ("ExpiresAt");

CREATE INDEX IF NOT EXISTS "idx_posts_feed" ON "Posts" ("CreatedAt" DESC, "UserId");
CREATE INDEX IF NOT EXISTS "idx_posts_user_id" ON "Posts" ("UserId", "CreatedAt" DESC);

CREATE INDEX IF NOT EXISTS "idx_comments_post_id" ON "Comments" ("PostId", "CreatedAt" ASC);
CREATE INDEX IF NOT EXISTS "idx_comments_user_id" ON "Comments" ("UserId", "CreatedAt" DESC);

CREATE INDEX IF NOT EXISTS "idx_friend_requests_receiver" ON "FriendRequests" ("ReceiverId", "CreatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_friend_requests_sender" ON "FriendRequests" ("SenderId", "CreatedAt" DESC);

CREATE INDEX IF NOT EXISTS "idx_follows_following" ON "Follows" ("FollowingId", "CreatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_follow_requests_target_status" ON "FollowRequests" ("TargetUserId", "Status", "CreatedAt" DESC);

CREATE INDEX IF NOT EXISTS "idx_conversations_updated_at" ON "Conversations" ("UpdatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_conversations_user_a" ON "Conversations" ("UserAId");
CREATE INDEX IF NOT EXISTS "idx_conversations_user_b" ON "Conversations" ("UserBId");

CREATE INDEX IF NOT EXISTS "idx_messages_conversation_created" ON "Messages" ("ConversationId", "CreatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_messages_sender_id" ON "Messages" ("SenderId", "CreatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_message_attachments_message_id" ON "MessageAttachments" ("MessageId", "Id" ASC);

CREATE INDEX IF NOT EXISTS "idx_notifications_user_created" ON "Notifications" ("UserId", "CreatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_notifications_user_unread" ON "Notifications" ("UserId", "IsRead", "CreatedAt" DESC);

CREATE INDEX IF NOT EXISTS "idx_user_blocks_blocker" ON "UserBlocks" ("BlockerId");
CREATE INDEX IF NOT EXISTS "idx_device_push_tokens_user_id" ON "DevicePushTokens" ("UserId", "RevokedAt");

CREATE INDEX IF NOT EXISTS "idx_media_assets_category_created" ON "MediaAssets" ("Category", "CreatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_auth_tokens_user_kind" ON "AuthTokens" ("UserId", "Kind", "CreatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_auth_tokens_hash" ON "AuthTokens" ("TokenHash");
CREATE INDEX IF NOT EXISTS "idx_reports_status_created" ON "Reports" ("Status", "CreatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_reports_assigned_status" ON "Reports" ("AssignedModeratorUserId", "Status", "CreatedAt" DESC);
CREATE INDEX IF NOT EXISTS "idx_moderation_actions_target_user" ON "ModerationActions" ("TargetUserId", "CreatedAt" DESC);

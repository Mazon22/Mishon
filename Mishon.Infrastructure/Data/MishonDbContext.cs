using Microsoft.EntityFrameworkCore;
using Mishon.Domain.Entities;

namespace Mishon.Infrastructure.Data;

public class MishonDbContext : DbContext
{
    public MishonDbContext(DbContextOptions<MishonDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Post> Posts => Set<Post>();
    public DbSet<Like> Likes => Set<Like>();
    public DbSet<Follow> Follows => Set<Follow>();
    public DbSet<Comment> Comments => Set<Comment>();
    public DbSet<FriendRequest> FriendRequests => Set<FriendRequest>();
    public DbSet<Friendship> Friendships => Set<Friendship>();
    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<MessageAttachment> MessageAttachments => Set<MessageAttachment>();
    public DbSet<UserBlock> UserBlocks => Set<UserBlock>();
    public DbSet<Notification> Notifications => Set<Notification>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Email).IsUnique();
            entity.HasIndex(e => e.Username).IsUnique();
            entity.Property(e => e.Username).IsRequired().HasMaxLength(50);
            entity.Property(e => e.Email).IsRequired().HasMaxLength(100);
            entity.Property(e => e.PasswordHash).IsRequired();
            entity.Property(e => e.AboutMe).HasMaxLength(280);
            entity.Property(e => e.AvatarUrl).HasMaxLength(500);
            entity.Property(e => e.BannerUrl).HasMaxLength(500);
            entity.Property(e => e.AvatarScale).HasDefaultValue(1d);
            entity.Property(e => e.BannerScale).HasDefaultValue(1d);
            entity.Property(e => e.LastSeenAt).HasDefaultValueSql("NOW()");
            entity.Property(e => e.RefreshToken).HasMaxLength(500);
        });

        modelBuilder.Entity<Post>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Content).IsRequired().HasMaxLength(1000);
            entity.HasIndex(e => e.CreatedAt);
            entity.HasIndex(e => e.UserId);
            entity.HasOne(e => e.User)
                  .WithMany(u => u.Posts)
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Like>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.UserId, e.PostId }).IsUnique();
            entity.HasIndex(e => e.PostId);
            entity.HasOne(e => e.User)
                  .WithMany(u => u.Likes)
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Post)
                  .WithMany(p => p.Likes)
                  .HasForeignKey(e => e.PostId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Follow>(entity =>
        {
            entity.HasKey(e => new { e.FollowerId, e.FollowingId });
            entity.HasIndex(e => new { e.FollowerId, e.FollowingId }).IsUnique();
            entity.HasIndex(e => e.FollowingId);
            entity.HasOne(e => e.Follower)
                  .WithMany(u => u.Followings)
                  .HasForeignKey(e => e.FollowerId)
                  .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(e => e.Following)
                  .WithMany(u => u.Followers)
                  .HasForeignKey(e => e.FollowingId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Comment>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Content).IsRequired().HasMaxLength(500);
            entity.HasIndex(e => e.PostId);
            entity.HasIndex(e => e.CreatedAt);
            entity.HasIndex(e => e.ParentCommentId);
            entity.HasOne(e => e.User)
                  .WithMany(u => u.Comments)
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Post)
                  .WithMany(p => p.Comments)
                  .HasForeignKey(e => e.PostId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.ParentComment)
                  .WithMany(c => c.Replies)
                  .HasForeignKey(e => e.ParentCommentId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<FriendRequest>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.SenderId, e.ReceiverId }).IsUnique();
            entity.HasIndex(e => e.CreatedAt);
            entity.HasOne(e => e.Sender)
                  .WithMany(u => u.SentFriendRequests)
                  .HasForeignKey(e => e.SenderId)
                  .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(e => e.Receiver)
                  .WithMany(u => u.ReceivedFriendRequests)
                  .HasForeignKey(e => e.ReceiverId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Friendship>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.UserAId, e.UserBId }).IsUnique();
            entity.HasIndex(e => e.CreatedAt);
            entity.HasOne(e => e.UserA)
                  .WithMany(u => u.FriendshipsA)
                  .HasForeignKey(e => e.UserAId)
                  .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(e => e.UserB)
                  .WithMany(u => u.FriendshipsB)
                  .HasForeignKey(e => e.UserBId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Conversation>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.UserAId, e.UserBId }).IsUnique();
            entity.HasIndex(e => e.UpdatedAt);
            entity.HasIndex(e => new { e.UserAId, e.UserAPinOrder });
            entity.HasIndex(e => new { e.UserBId, e.UserBPinOrder });
            entity.HasOne(e => e.UserA)
                  .WithMany(u => u.ConversationsA)
                  .HasForeignKey(e => e.UserAId)
                  .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(e => e.UserB)
                  .WithMany(u => u.ConversationsB)
                  .HasForeignKey(e => e.UserBId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Message>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Content).IsRequired().HasMaxLength(1000);
            entity.HasIndex(e => new { e.ConversationId, e.CreatedAt });
            entity.HasIndex(e => e.ReplyToMessageId);
            entity.HasOne(e => e.Conversation)
                  .WithMany(c => c.Messages)
                  .HasForeignKey(e => e.ConversationId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Sender)
                  .WithMany(u => u.SentMessages)
                  .HasForeignKey(e => e.SenderId)
                  .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(e => e.ReplyToMessage)
                  .WithMany(m => m.Replies)
                  .HasForeignKey(e => e.ReplyToMessageId)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<MessageAttachment>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.FileName).IsRequired().HasMaxLength(260);
            entity.Property(e => e.FileUrl).IsRequired().HasMaxLength(1000);
            entity.Property(e => e.ContentType).IsRequired().HasMaxLength(200);
            entity.HasIndex(e => e.MessageId);
            entity.HasOne(e => e.Message)
                  .WithMany(m => m.Attachments)
                  .HasForeignKey(e => e.MessageId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<UserBlock>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.BlockerId, e.BlockedUserId }).IsUnique();
            entity.HasIndex(e => new { e.BlockedUserId, e.CreatedAt });
            entity.HasOne(e => e.Blocker)
                  .WithMany(u => u.BlockedUsers)
                  .HasForeignKey(e => e.BlockerId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.BlockedUser)
                  .WithMany(u => u.BlockedByUsers)
                  .HasForeignKey(e => e.BlockedUserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Notification>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Type).IsRequired().HasMaxLength(64);
            entity.Property(e => e.Text).IsRequired().HasMaxLength(280);
            entity.HasIndex(e => new { e.UserId, e.IsRead, e.CreatedAt });
            entity.HasOne(e => e.User)
                  .WithMany(u => u.Notifications)
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.ActorUser)
                  .WithMany(u => u.CreatedNotifications)
                  .HasForeignKey(e => e.ActorUserId)
                  .OnDelete(DeleteBehavior.SetNull);
        });
    }
}

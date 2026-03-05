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
            entity.HasOne(e => e.Follower)
                  .WithMany(u => u.Followings)
                  .HasForeignKey(e => e.FollowerId)
                  .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(e => e.Following)
                  .WithMany(u => u.Followers)
                  .HasForeignKey(e => e.FollowingId)
                  .OnDelete(DeleteBehavior.Restrict);
        });
    }
}

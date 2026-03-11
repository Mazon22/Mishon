namespace Mishon.Domain.Entities;

public class User
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string? AboutMe { get; set; }
    public string? AvatarUrl { get; set; }
    public string? BannerUrl { get; set; }
    public double AvatarScale { get; set; } = 1;
    public double AvatarOffsetX { get; set; }
    public double AvatarOffsetY { get; set; }
    public double BannerScale { get; set; } = 1;
    public double BannerOffsetX { get; set; }
    public double BannerOffsetY { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
    public string? RefreshToken { get; set; }
    public DateTime? RefreshTokenExpiry { get; set; }

    // Навигационные свойства
    public ICollection<Post> Posts { get; set; } = new List<Post>();
    public ICollection<Like> Likes { get; set; } = new List<Like>();
    public ICollection<Comment> Comments { get; set; } = new List<Comment>();
    public ICollection<Follow> Followers { get; set; } = new List<Follow>();
    public ICollection<Follow> Followings { get; set; } = new List<Follow>();
    public ICollection<FriendRequest> SentFriendRequests { get; set; } = new List<FriendRequest>();
    public ICollection<FriendRequest> ReceivedFriendRequests { get; set; } = new List<FriendRequest>();
    public ICollection<Friendship> FriendshipsA { get; set; } = new List<Friendship>();
    public ICollection<Friendship> FriendshipsB { get; set; } = new List<Friendship>();
    public ICollection<Conversation> ConversationsA { get; set; } = new List<Conversation>();
    public ICollection<Conversation> ConversationsB { get; set; } = new List<Conversation>();
    public ICollection<Message> SentMessages { get; set; } = new List<Message>();
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
    public ICollection<Notification> CreatedNotifications { get; set; } = new List<Notification>();
}

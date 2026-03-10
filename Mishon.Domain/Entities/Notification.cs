namespace Mishon.Domain.Entities;

public class Notification
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int? ActorUserId { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Text { get; set; } = string.Empty;
    public bool IsRead { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public int? PostId { get; set; }
    public int? CommentId { get; set; }
    public int? ConversationId { get; set; }
    public int? MessageId { get; set; }
    public int? RelatedUserId { get; set; }

    public User User { get; set; } = null!;
    public User? ActorUser { get; set; }
}

namespace Mishon.Domain.Entities;

public class Conversation
{
    public int Id { get; set; }
    public int UserAId { get; set; }
    public int UserBId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UserAReadAt { get; set; }
    public DateTime? UserBReadAt { get; set; }

    public User UserA { get; set; } = null!;
    public User UserB { get; set; } = null!;
    public ICollection<Message> Messages { get; set; } = new List<Message>();
}

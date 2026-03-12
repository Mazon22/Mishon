namespace Mishon.Domain.Entities;

public class UserBlock
{
    public int Id { get; set; }
    public int BlockerId { get; set; }
    public int BlockedUserId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User Blocker { get; set; } = null!;
    public User BlockedUser { get; set; } = null!;
}

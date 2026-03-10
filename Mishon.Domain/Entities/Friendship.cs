namespace Mishon.Domain.Entities;

public class Friendship
{
    public int Id { get; set; }
    public int UserAId { get; set; }
    public int UserBId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User UserA { get; set; } = null!;
    public User UserB { get; set; } = null!;
}

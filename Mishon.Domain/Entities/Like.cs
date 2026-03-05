namespace Mishon.Domain.Entities;

public class Like
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int PostId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Навигационные свойства
    public User User { get; set; } = null!;
    public Post Post { get; set; } = null!;
}

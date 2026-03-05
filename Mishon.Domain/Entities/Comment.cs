namespace Mishon.Domain.Entities;

public class Comment
{
    public int Id { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    
    // Foreign Keys
    public int UserId { get; set; }
    public int PostId { get; set; }
    
    // Navigation Properties
    public User User { get; set; } = null!;
    public Post Post { get; set; } = null!;
}

namespace Mishon.Domain.Entities;

public class Comment
{
    public int Id { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? EditedAt { get; set; }

    // Foreign Keys
    public int UserId { get; set; }
    public int PostId { get; set; }
    public int? ParentCommentId { get; set; }

    // Navigation Properties
    public User User { get; set; } = null!;
    public Post Post { get; set; } = null!;
    public Comment? ParentComment { get; set; }
    public ICollection<Comment> Replies { get; set; } = new List<Comment>();
}

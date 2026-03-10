namespace Mishon.Domain.Entities;

public class FriendRequest
{
    public int Id { get; set; }
    public int SenderId { get; set; }
    public int ReceiverId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User Sender { get; set; } = null!;
    public User Receiver { get; set; } = null!;
}

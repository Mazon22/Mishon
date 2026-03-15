namespace Mishon.Domain.Entities;

public class Message
{
    public int Id { get; set; }
    public int ConversationId { get; set; }
    public int SenderId { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? EditedAt { get; set; }
    public DateTime? DeliveredToPeerAt { get; set; }
    public int? ReplyToMessageId { get; set; }
    public int? ForwardedFromMessageId { get; set; }
    public int? ForwardedFromUserId { get; set; }
    public bool DeletedForUserA { get; set; }
    public bool DeletedForUserB { get; set; }

    public Conversation Conversation { get; set; } = null!;
    public User Sender { get; set; } = null!;
    public Message? ReplyToMessage { get; set; }
    public Message? ForwardedFromMessage { get; set; }
    public User? ForwardedFromUser { get; set; }
    public ICollection<Message> Replies { get; set; } = new List<Message>();
    public ICollection<MessageAttachment> Attachments { get; set; } = new List<MessageAttachment>();
}

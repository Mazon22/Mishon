using FluentValidation;

namespace Mishon.Application.DTOs;

public record DiscoverUserDto(
    int Id,
    string Username,
    string? AboutMe,
    string? AvatarUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY,
    DateTime LastSeenAt,
    bool IsOnline,
    int FollowersCount,
    int PostsCount,
    int MutualFriendsCount,
    int EngagementScore,
    bool IsFollowing,
    bool IsFriend,
    int? IncomingFriendRequestId,
    int? OutgoingFriendRequestId
);

public record FriendDto(
    int Id,
    string Username,
    string? AboutMe,
    string? AvatarUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY,
    DateTime LastSeenAt,
    bool IsOnline
);

public record BlockedUserDto(
    int Id,
    string Username,
    string? AboutMe,
    string? AvatarUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY,
    DateTime LastSeenAt,
    DateTime BlockedAt
);

public record FriendRequestDto(
    int Id,
    int UserId,
    string Username,
    string? AboutMe,
    string? AvatarUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY,
    DateTime LastSeenAt,
    bool IsOnline,
    bool IsIncoming,
    DateTime CreatedAt
);

public record ConversationDto(
    int Id,
    int PeerId,
    string Username,
    string? AvatarUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY,
    DateTime LastSeenAt,
    bool IsOnline,
    int? PinOrder,
    bool IsPinned,
    bool IsArchived,
    bool IsFavorite,
    bool IsMuted,
    bool IsBlockedByViewer,
    bool HasBlockedViewer,
    string? LastMessage,
    DateTime? LastMessageAt,
    bool LastMessageIsMine,
    bool LastMessageIsDeliveredToPeer,
    bool LastMessageIsReadByPeer,
    int UnreadCount
);

public record DirectConversationDto(
    int Id,
    int PeerId,
    string Username,
    string? AvatarUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY,
    DateTime LastSeenAt,
    bool IsOnline
);

public record MessageDto(
    int Id,
    int ConversationId,
    int SenderId,
    string SenderUsername,
    string Content,
    DateTime CreatedAt,
    DateTime? EditedAt,
    bool IsMine,
    bool IsDeliveredToPeer,
    DateTime? DeliveredToPeerAt,
    bool IsReadByPeer,
    DateTime? ReadByPeerAt,
    int? ReplyToMessageId,
    string? ReplyToSenderUsername,
    string? ReplyToContent,
    int? ForwardedFromMessageId,
    int? ForwardedFromUserId,
    string? ForwardedFromSenderUsername,
    string? ForwardedFromUserAvatarUrl,
    double ForwardedFromUserAvatarScale,
    double ForwardedFromUserAvatarOffsetX,
    double ForwardedFromUserAvatarOffsetY,
    IReadOnlyCollection<MessageAttachmentDto> Attachments
);

public record MessagePageDto(
    IReadOnlyCollection<MessageDto> Items,
    bool HasMore,
    int? NextBeforeMessageId
);

public record TypingIndicatorDto(
    int ConversationId
);

public record ChatTypingEventDto(
    int ConversationId,
    int UserId,
    DateTime SentAt
);

public record MessageReadEventDto(
    int ConversationId,
    int UserId,
    DateTime ReadAt
);

public record MessageDeliveredEventDto(
    int ConversationId,
    int MessageId,
    DateTime DeliveredAt
);

public record ConversationRealtimeContextDto(
    int ConversationId,
    int PeerUserId,
    bool IsBlockedByViewer,
    bool HasBlockedViewer
);

public record PendingMessageDeliveryDto(
    int ConversationId,
    int MessageId,
    int SenderUserId,
    DateTime DeliveredAt
);

public record MessageAttachmentDto(
    int Id,
    string FileName,
    string FileUrl,
    string ContentType,
    long SizeBytes,
    bool IsImage
);

public record CreateMessageAttachmentDto(
    string FileName,
    string FileUrl,
    string ContentType,
    long SizeBytes,
    bool IsImage
);

public record CreateMessageDto(
    string? Content,
    int? ReplyToMessageId,
    IReadOnlyCollection<CreateMessageAttachmentDto>? Attachments
);

public record ForwardMessageDto(
    int MessageId
);

public record UpdateMessageDto(
    string Content
);

public record DeleteMessageResultDto(
    IReadOnlyCollection<string> AttachmentUrls
);

public record DeleteConversationResultDto(
    IReadOnlyCollection<string> AttachmentUrls
);

public record ToggleConversationPinDto(
    int ConversationId,
    bool IsPinned
);

public record ToggleConversationArchiveDto(
    int ConversationId,
    bool IsArchived
);

public record ToggleConversationFavoriteDto(
    int ConversationId,
    bool IsFavorite
);

public record ToggleConversationMuteDto(
    int ConversationId,
    bool IsMuted
);

public record DeleteConversationDto(
    int ConversationId,
    bool DeleteForBoth
);

public record ClearConversationHistoryDto(
    int ConversationId
);

public record DeleteMessageForAllDto(
    int ConversationId,
    int MessageId
);

public record ToggleUserBlockDto(
    int UserId
);

public record UserBlockStatusDto(
    bool IsBlockedByViewer,
    bool HasBlockedViewer
);

public record NotificationDto(
    int Id,
    string Type,
    string Text,
    bool IsRead,
    DateTime CreatedAt,
    int? ActorUserId,
    string? ActorUsername,
    string? ActorAvatarUrl,
    double ActorAvatarScale,
    double ActorAvatarOffsetX,
    double ActorAvatarOffsetY,
    int? PostId,
    int? CommentId,
    int? ConversationId,
    int? MessageId,
    int? RelatedUserId
);

public record CreateNotificationDto(
    int UserId,
    int? ActorUserId,
    string Type,
    string Text,
    int? PostId,
    int? CommentId,
    int? ConversationId,
    int? MessageId,
    int? RelatedUserId
);

public record NotificationSummaryDto(
    int UnreadNotifications,
    int UnreadChats,
    int IncomingFriendRequests
);

public class CreateMessageDtoValidator : AbstractValidator<CreateMessageDto>
{
    public CreateMessageDtoValidator()
    {
        RuleFor(x => x.Content)
            .MaximumLength(1000).WithMessage("Максимум 1000 символов")
            .When(x => !string.IsNullOrWhiteSpace(x.Content));

        RuleFor(x => x)
            .Must(x => !string.IsNullOrWhiteSpace(x.Content) || (x.Attachments?.Count ?? 0) > 0)
            .WithMessage("Сообщение должно содержать текст или вложения");
    }
}

public class UpdateMessageDtoValidator : AbstractValidator<UpdateMessageDto>
{
    public UpdateMessageDtoValidator()
    {
        RuleFor(x => x.Content)
            .NotEmpty().WithMessage("Текст сообщения обязателен")
            .MaximumLength(1000).WithMessage("Максимум 1000 символов");
    }
}

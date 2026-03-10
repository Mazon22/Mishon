using FluentValidation;

namespace Mishon.Application.DTOs;

public record DiscoverUserDto(
    int Id,
    string Username,
    string? AvatarUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY,
    bool IsFollowing,
    bool IsFriend,
    int? IncomingFriendRequestId,
    int? OutgoingFriendRequestId
);

public record FriendDto(
    int Id,
    string Username,
    string? AvatarUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY
);

public record FriendRequestDto(
    int Id,
    int UserId,
    string Username,
    string? AvatarUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY,
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
    string? LastMessage,
    DateTime? LastMessageAt,
    int UnreadCount
);

public record DirectConversationDto(
    int Id,
    int PeerId,
    string Username,
    string? AvatarUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY
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
    int? ReplyToMessageId,
    string? ReplyToSenderUsername,
    string? ReplyToContent
);

public record CreateMessageDto(
    string Content,
    int? ReplyToMessageId
);

public record UpdateMessageDto(
    string Content
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
            .NotEmpty().WithMessage("Текст сообщения обязателен")
            .MaximumLength(1000).WithMessage("Максимум 1000 символов");
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

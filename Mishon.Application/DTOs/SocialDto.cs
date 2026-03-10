using FluentValidation;

namespace Mishon.Application.DTOs;

public record DiscoverUserDto(
    int Id,
    string Username,
    string? AvatarUrl,
    bool IsFollowing,
    bool IsFriend,
    int? IncomingFriendRequestId,
    int? OutgoingFriendRequestId
);

public record FriendDto(
    int Id,
    string Username,
    string? AvatarUrl
);

public record FriendRequestDto(
    int Id,
    int UserId,
    string Username,
    string? AvatarUrl,
    bool IsIncoming,
    DateTime CreatedAt
);

public record ConversationDto(
    int Id,
    int PeerId,
    string Username,
    string? AvatarUrl,
    string? LastMessage,
    DateTime? LastMessageAt,
    int UnreadCount
);

public record DirectConversationDto(
    int Id,
    int PeerId,
    string Username,
    string? AvatarUrl
);

public record MessageDto(
    int Id,
    int ConversationId,
    int SenderId,
    string SenderUsername,
    string Content,
    DateTime CreatedAt,
    bool IsMine
);

public record CreateMessageDto(
    string Content
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

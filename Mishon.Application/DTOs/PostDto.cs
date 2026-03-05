using FluentValidation;

namespace Mishon.Application.DTOs;

public record PostDto(
    int Id,
    int UserId,
    string Username,
    string? UserAvatarUrl,
    string Content,
    string? ImageUrl,
    DateTime CreatedAt,
    int LikesCount,
    bool IsLiked,
    bool IsFollowingAuthor
);

public record FollowDto(
    int Id,
    string Username,
    string? AvatarUrl
);

public record ToggleFollowResponseDto(
    bool IsFollowing,
    int FollowersCount
);

public record UserFollowDto(
    int Id,
    string Username,
    string? AvatarUrl,
    bool IsFollowing
);

public record CreatePostDto(
    string Content,
    string? ImageUrl
);

public record CreateCommentDto(
    string Content
);

public record CommentDto(
    int Id,
    int UserId,
    string Username,
    string? UserAvatarUrl,
    string Content,
    DateTime CreatedAt
);

public class CreatePostDtoValidator : FluentValidation.AbstractValidator<CreatePostDto>
{
    public CreatePostDtoValidator()
    {
        RuleFor(x => x.Content)
            .NotEmpty().WithMessage("Содержимое обязательно")
            .MinimumLength(1).WithMessage("Содержимое не может быть пустым")
            .MaximumLength(1000).WithMessage("Максимум 1000 символов");

        RuleFor(x => x.ImageUrl)
            .MaximumLength(500).WithMessage("Максимум 500 символов")
            .Must(uri => string.IsNullOrEmpty(uri) || Uri.IsWellFormedUriString(uri, UriKind.Absolute))
            .When(x => x.ImageUrl != null)
            .WithMessage("Некорректный URL");
    }
}

public class CreateCommentDtoValidator : FluentValidation.AbstractValidator<CreateCommentDto>
{
    public CreateCommentDtoValidator()
    {
        RuleFor(x => x.Content)
            .NotEmpty().WithMessage("Текст комментария обязателен")
            .MinimumLength(1).WithMessage("Комментарий не может быть пустым")
            .MaximumLength(500).WithMessage("Максимум 500 символов");
    }
}

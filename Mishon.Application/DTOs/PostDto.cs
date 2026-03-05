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
    bool IsLiked
);

public record FollowDto(
    int Id,
    string Username,
    string? AvatarUrl
);

public record CreatePostDto(
    string Content,
    string? ImageUrl
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

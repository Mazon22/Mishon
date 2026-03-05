using FluentValidation;

namespace Mishon.Application.DTOs;

public record RegisterDto(
    string Username,
    string Email,
    string Password
);

public class RegisterDtoValidator : AbstractValidator<RegisterDto>
{
    public RegisterDtoValidator()
    {
        RuleFor(x => x.Username)
            .NotEmpty().WithMessage("Имя пользователя обязательно")
            .MinimumLength(3).WithMessage("Минимум 3 символа")
            .MaximumLength(50).WithMessage("Максимум 50 символов")
            .Matches(@"^[a-zA-Z0-9_]+$").WithMessage("Только буквы, цифры и подчёркивание");

        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email обязателен")
            .MaximumLength(100).WithMessage("Максимум 100 символов")
            .EmailAddress().WithMessage("Некорректный email");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Пароль обязателен")
            .MinimumLength(8).WithMessage("Минимум 8 символов")
            .MaximumLength(100).WithMessage("Максимум 100 символов")
            .Matches(@"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)").WithMessage("Пароль должен содержать заглавные, строчные буквы и цифры");
    }
}

public record LoginDto(
    string Email,
    string Password
);

public class LoginDtoValidator : AbstractValidator<LoginDto>
{
    public LoginDtoValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email обязателен")
            .EmailAddress().WithMessage("Некорректный email");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Пароль обязателен");
    }
}

public record AuthResponseDto(
    int UserId,
    string Username,
    string Email,
    string Token,
    string? RefreshToken = null,
    DateTime? RefreshTokenExpiry = null
);

public record UserProfileDto(
    int Id,
    string Username,
    string Email,
    string? AvatarUrl,
    DateTime CreatedAt,
    int FollowersCount,
    int FollowingCount,
    bool? IsFollowing = null
);

public record UpdateProfileDto(
    string? Username,
    string? AvatarUrl
);

public class UpdateProfileDtoValidator : AbstractValidator<UpdateProfileDto>
{
    public UpdateProfileDtoValidator()
    {
        RuleFor(x => x.Username)
            .MaximumLength(50).WithMessage("Максимум 50 символов")
            .Matches(@"^[a-zA-Z0-9_]+$").When(x => x.Username != null)
            .WithMessage("Только буквы, цифры и подчёркивание");

        RuleFor(x => x.AvatarUrl)
            .MaximumLength(500).WithMessage("Максимум 500 символов")
            .Must(uri => string.IsNullOrEmpty(uri) || Uri.IsWellFormedUriString(uri, UriKind.Absolute))
            .When(x => x.AvatarUrl != null)
            .WithMessage("Некорректный URL");
    }
}

public record RefreshTokenDto(
    string RefreshToken
);

public class RefreshTokenDtoValidator : AbstractValidator<RefreshTokenDto>
{
    public RefreshTokenDtoValidator()
    {
        RuleFor(x => x.RefreshToken)
            .NotEmpty().WithMessage("Refresh token обязателен");
    }
}

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
            .NotEmpty().WithMessage("Username is required")
            .MinimumLength(3).WithMessage("Minimum 3 characters")
            .MaximumLength(50).WithMessage("Maximum 50 characters")
            .Matches(@"^[a-zA-Z0-9_]+$").WithMessage("Only letters, numbers, and underscore are allowed");

        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required")
            .MaximumLength(100).WithMessage("Maximum 100 characters")
            .EmailAddress().WithMessage("Invalid email");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Password is required")
            .MinimumLength(8).WithMessage("Minimum 8 characters")
            .MaximumLength(100).WithMessage("Maximum 100 characters")
            .Matches(@"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)").WithMessage("Use upper, lower case letters and digits");
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
            .NotEmpty().WithMessage("Email is required")
            .EmailAddress().WithMessage("Invalid email");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Password is required");
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
    string? AboutMe,
    string? AvatarUrl,
    string? BannerUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY,
    double BannerScale,
    double BannerOffsetX,
    double BannerOffsetY,
    DateTime CreatedAt,
    DateTime LastSeenAt,
    bool IsOnline,
    int FollowersCount,
    int FollowingCount,
    int PostsCount,
    bool IsBlockedByViewer,
    bool HasBlockedViewer,
    bool? IsFollowing = null
);

public record UpdateProfileDto(
    string? Username,
    string? AboutMe,
    string? AvatarUrl,
    string? BannerUrl,
    double? AvatarScale,
    double? AvatarOffsetX,
    double? AvatarOffsetY,
    double? BannerScale,
    double? BannerOffsetX,
    double? BannerOffsetY,
    bool? RemoveAvatar = null,
    bool? RemoveBanner = null
);

public record UpdateProfileMediaDto(
    string? AvatarUrl,
    string? BannerUrl,
    double AvatarScale,
    double AvatarOffsetX,
    double AvatarOffsetY,
    double BannerScale,
    double BannerOffsetX,
    double BannerOffsetY,
    bool RemoveAvatar,
    bool RemoveBanner
);

public class UpdateProfileDtoValidator : AbstractValidator<UpdateProfileDto>
{
    public UpdateProfileDtoValidator()
    {
        RuleFor(x => x.Username)
            .MaximumLength(50).WithMessage("Maximum 50 characters")
            .Matches(@"^[a-zA-Z0-9_]+$").When(x => x.Username != null)
            .WithMessage("Only letters, numbers, and underscore are allowed");

        RuleFor(x => x.AboutMe)
            .MaximumLength(280).WithMessage("Maximum 280 characters");

        RuleFor(x => x.AvatarUrl)
            .MaximumLength(500).WithMessage("Maximum 500 characters")
            .Must(BeValidUrl).When(x => x.AvatarUrl != null)
            .WithMessage("Invalid avatar URL");

        RuleFor(x => x.BannerUrl)
            .MaximumLength(500).WithMessage("Maximum 500 characters")
            .Must(BeValidUrl).When(x => x.BannerUrl != null)
            .WithMessage("Invalid banner URL");

        RuleFor(x => x.AvatarScale)
            .InclusiveBetween(1, 4).When(x => x.AvatarScale.HasValue)
            .WithMessage("Avatar scale must be between 1 and 4");

        RuleFor(x => x.BannerScale)
            .InclusiveBetween(1, 4).When(x => x.BannerScale.HasValue)
            .WithMessage("Banner scale must be between 1 and 4");

        RuleFor(x => x.AvatarOffsetX)
            .InclusiveBetween(-2, 2).When(x => x.AvatarOffsetX.HasValue)
            .WithMessage("Avatar horizontal offset is out of range");

        RuleFor(x => x.AvatarOffsetY)
            .InclusiveBetween(-2, 2).When(x => x.AvatarOffsetY.HasValue)
            .WithMessage("Avatar vertical offset is out of range");

        RuleFor(x => x.BannerOffsetX)
            .InclusiveBetween(-2, 2).When(x => x.BannerOffsetX.HasValue)
            .WithMessage("Banner horizontal offset is out of range");

        RuleFor(x => x.BannerOffsetY)
            .InclusiveBetween(-2, 2).When(x => x.BannerOffsetY.HasValue)
            .WithMessage("Banner vertical offset is out of range");
    }

    private static bool BeValidUrl(string? value) =>
        string.IsNullOrWhiteSpace(value) || Uri.IsWellFormedUriString(value, UriKind.Absolute);
}

public class UpdateProfileMediaDtoValidator : AbstractValidator<UpdateProfileMediaDto>
{
    public UpdateProfileMediaDtoValidator()
    {
        RuleFor(x => x.AvatarUrl)
            .MaximumLength(500).WithMessage("Maximum 500 characters")
            .Must(BeValidUrl).When(x => x.AvatarUrl != null)
            .WithMessage("Invalid avatar URL");

        RuleFor(x => x.BannerUrl)
            .MaximumLength(500).WithMessage("Maximum 500 characters")
            .Must(BeValidUrl).When(x => x.BannerUrl != null)
            .WithMessage("Invalid banner URL");

        RuleFor(x => x.AvatarScale)
            .InclusiveBetween(1, 4).WithMessage("Avatar scale must be between 1 and 4");

        RuleFor(x => x.BannerScale)
            .InclusiveBetween(1, 4).WithMessage("Banner scale must be between 1 and 4");

        RuleFor(x => x.AvatarOffsetX)
            .InclusiveBetween(-2, 2).WithMessage("Avatar horizontal offset is out of range");

        RuleFor(x => x.AvatarOffsetY)
            .InclusiveBetween(-2, 2).WithMessage("Avatar vertical offset is out of range");

        RuleFor(x => x.BannerOffsetX)
            .InclusiveBetween(-2, 2).WithMessage("Banner horizontal offset is out of range");

        RuleFor(x => x.BannerOffsetY)
            .InclusiveBetween(-2, 2).WithMessage("Banner vertical offset is out of range");
    }

    private static bool BeValidUrl(string? value) =>
        string.IsNullOrWhiteSpace(value) || Uri.IsWellFormedUriString(value, UriKind.Absolute);
}

public record RefreshTokenDto(
    string RefreshToken
);

public class RefreshTokenDtoValidator : AbstractValidator<RefreshTokenDto>
{
    public RefreshTokenDtoValidator()
    {
        RuleFor(x => x.RefreshToken)
            .NotEmpty().WithMessage("Refresh token is required");
    }
}

using System.Security.Claims;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private static readonly string[] AllowedImageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp"];
    private const long MaxProfileImageBytes = 5 * 1024 * 1024;

    private readonly IAuthService _authService;
    private readonly IValidator<RegisterDto> _registerValidator;
    private readonly IValidator<LoginDto> _loginValidator;
    private readonly IValidator<UpdateProfileDto> _updateProfileValidator;
    private readonly IValidator<UpdateProfileMediaDto> _updateProfileMediaValidator;

    public AuthController(
        IAuthService authService,
        IValidator<RegisterDto> registerValidator,
        IValidator<LoginDto> loginValidator,
        IValidator<UpdateProfileDto> updateProfileValidator,
        IValidator<UpdateProfileMediaDto> updateProfileMediaValidator)
    {
        _authService = authService;
        _registerValidator = registerValidator;
        _loginValidator = loginValidator;
        _updateProfileValidator = updateProfileValidator;
        _updateProfileMediaValidator = updateProfileMediaValidator;
    }

    [HttpPost("register")]
    [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<ActionResult<AuthResponseDto>> Register([FromBody] RegisterDto dto)
    {
        var validationResult = await _registerValidator.ValidateAsync(dto);
        if (!validationResult.IsValid)
        {
            return BadRequest(new
            {
                error = "Validation Error",
                message = validationResult.Errors.FirstOrDefault()?.ErrorMessage,
                errors = validationResult.Errors.Select(e => new { e.PropertyName, e.ErrorMessage })
            });
        }

        var result = await _authService.RegisterAsync(dto);
        if (!result.IsSuccess)
        {
            return result.ResultError switch
            {
                ResultError.Conflict => Conflict(new { error = result.Error }),
                ResultError.ValidationError => BadRequest(new { error = result.Error }),
                _ => StatusCode(500, new { error = result.Error })
            };
        }

        return Ok(result.Data);
    }

    [HttpPost("login")]
    [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<AuthResponseDto>> Login([FromBody] LoginDto dto)
    {
        var validationResult = await _loginValidator.ValidateAsync(dto);
        if (!validationResult.IsValid)
        {
            return BadRequest(new
            {
                error = "Validation Error",
                message = validationResult.Errors.FirstOrDefault()?.ErrorMessage
            });
        }

        var result = await _authService.LoginAsync(dto);
        if (!result.IsSuccess)
        {
            return Unauthorized(new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [HttpPost("refresh-token")]
    [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<AuthResponseDto>> RefreshToken([FromBody] RefreshTokenDto dto)
    {
        var result = await _authService.RefreshTokenAsync(dto.RefreshToken);
        if (!result.IsSuccess)
        {
            return Unauthorized(new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [Authorize]
    [HttpGet("profile")]
    [ProducesResponseType(typeof(UserProfileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UserProfileDto>> GetProfile()
    {
        var result = await _authService.GetProfileAsync(GetUserId());
        return FromProfileResult(result);
    }

    [Authorize]
    [HttpGet("profile/{userId:int}")]
    [ProducesResponseType(typeof(UserProfileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UserProfileDto>> GetUserProfile(int userId)
    {
        var result = await _authService.GetProfileForUserAsync(userId, GetUserId());
        return FromProfileResult(result);
    }

    [Authorize]
    [HttpPut("profile")]
    [ProducesResponseType(typeof(UserProfileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<ActionResult<UserProfileDto>> UpdateProfile([FromBody] UpdateProfileDto dto)
    {
        var validationResult = await _updateProfileValidator.ValidateAsync(dto);
        if (!validationResult.IsValid)
        {
            return BadRequest(new
            {
                error = "Validation Error",
                message = validationResult.Errors.FirstOrDefault()?.ErrorMessage,
                errors = validationResult.Errors.Select(e => new { e.PropertyName, e.ErrorMessage })
            });
        }

        var result = await _authService.UpdateProfileAsync(GetUserId(), dto);
        return FromProfileResult(result);
    }

    [Authorize]
    [HttpPut("profile/media")]
    [RequestSizeLimit(12 * 1024 * 1024)]
    [ProducesResponseType(typeof(UserProfileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UserProfileDto>> UpdateProfileMedia(
        [FromForm] IFormFile? avatar,
        [FromForm] IFormFile? banner,
        [FromForm] double avatarScale = 1,
        [FromForm] double avatarOffsetX = 0,
        [FromForm] double avatarOffsetY = 0,
        [FromForm] double bannerScale = 1,
        [FromForm] double bannerOffsetX = 0,
        [FromForm] double bannerOffsetY = 0,
        [FromForm] bool removeAvatar = false,
        [FromForm] bool removeBanner = false,
        CancellationToken cancellationToken = default)
    {
        var userId = GetUserId();
        var previousProfile = await _authService.GetProfileAsync(userId);

        if (avatar != null)
        {
            var avatarValidation = ValidateImageFile(avatar, "avatar");
            if (avatarValidation != null)
            {
                return avatarValidation;
            }
        }

        if (banner != null)
        {
            var bannerValidation = ValidateImageFile(banner, "banner");
            if (bannerValidation != null)
            {
                return bannerValidation;
            }
        }

        string? savedAvatarPath = null;
        string? savedBannerPath = null;
        try
        {
            string? avatarUrl = null;
            string? bannerUrl = null;

            if (avatar != null)
            {
                (savedAvatarPath, avatarUrl) = await SaveImageAsync(avatar, cancellationToken);
            }

            if (banner != null)
            {
                (savedBannerPath, bannerUrl) = await SaveImageAsync(banner, cancellationToken);
            }

            var dto = new UpdateProfileMediaDto(
                avatarUrl,
                bannerUrl,
                avatarScale,
                avatarOffsetX,
                avatarOffsetY,
                bannerScale,
                bannerOffsetX,
                bannerOffsetY,
                removeAvatar,
                removeBanner);

            var validationResult = await _updateProfileMediaValidator.ValidateAsync(dto, cancellationToken);
            if (!validationResult.IsValid)
            {
                DeleteLocalFile(savedAvatarPath);
                DeleteLocalFile(savedBannerPath);

                return BadRequest(new
                {
                    error = "Validation Error",
                    message = validationResult.Errors.FirstOrDefault()?.ErrorMessage,
                    errors = validationResult.Errors.Select(e => new { e.PropertyName, e.ErrorMessage })
                });
            }

            var result = await _authService.UpdateProfileMediaAsync(userId, dto);
            if (!result.IsSuccess)
            {
                DeleteLocalFile(savedAvatarPath);
                DeleteLocalFile(savedBannerPath);
                return FromProfileResult(result);
            }

            if (previousProfile.IsSuccess && previousProfile.Data != null)
            {
                if (avatar != null || removeAvatar)
                {
                    DeleteUploadedFile(previousProfile.Data.AvatarUrl);
                }

                if (banner != null || removeBanner)
                {
                    DeleteUploadedFile(previousProfile.Data.BannerUrl);
                }
            }

            return Ok(result.Data);
        }
        catch
        {
            DeleteLocalFile(savedAvatarPath);
            DeleteLocalFile(savedBannerPath);
            throw;
        }
    }

    [Authorize]
    [HttpPost("logout")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> Logout()
    {
        var result = await _authService.LogoutAsync(GetUserId());
        if (!result.IsSuccess)
        {
            return result.ResultError == ResultError.NotFound
                ? NotFound(new { error = result.Error })
                : StatusCode(500, new { error = result.Error });
        }

        return Ok();
    }

    private ActionResult<UserProfileDto> FromProfileResult(Result<UserProfileDto> result)
    {
        if (result.IsSuccess)
        {
            return Ok(result.Data);
        }

        return result.ResultError switch
        {
            ResultError.NotFound => NotFound(new { error = result.Error }),
            ResultError.Conflict => Conflict(new { error = result.Error }),
            ResultError.ValidationError => BadRequest(new { error = result.Error }),
            _ => StatusCode(500, new { error = result.Error })
        };
    }

    private ActionResult? ValidateImageFile(IFormFile file, string label)
    {
        if (file.Length > MaxProfileImageBytes)
        {
            return BadRequest(new { error = $"{label} must be 5 MB or smaller" });
        }

        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedImageExtensions.Contains(extension))
        {
            return BadRequest(new { error = $"{label} must be JPG, JPEG, PNG, GIF, or WEBP" });
        }

        return null;
    }

    private async Task<(string SavedFilePath, string PublicUrl)> SaveImageAsync(IFormFile file, CancellationToken cancellationToken)
    {
        var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "uploads");
        Directory.CreateDirectory(uploadsFolder);

        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        var uniqueFileName = $"{Guid.NewGuid()}{extension}";
        var savedFilePath = Path.Combine(uploadsFolder, uniqueFileName);

        await using (var stream = new FileStream(savedFilePath, FileMode.Create))
        {
            await file.CopyToAsync(stream, cancellationToken);
        }

        var request = HttpContext.Request;
        var publicUrl = $"{request.Scheme}://{request.Host}/uploads/{uniqueFileName}";
        return (savedFilePath, publicUrl);
    }

    private static void DeleteLocalFile(string? path)
    {
        if (!string.IsNullOrWhiteSpace(path) && System.IO.File.Exists(path))
        {
            System.IO.File.Delete(path);
        }
    }

    private static void DeleteUploadedFile(string? url)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            return;
        }

        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri))
        {
            return;
        }

        var fileName = Path.GetFileName(uri.LocalPath);
        if (string.IsNullOrWhiteSpace(fileName))
        {
            return;
        }

        var fullPath = Path.Combine(Directory.GetCurrentDirectory(), "uploads", fileName);
        DeleteLocalFile(fullPath);
    }

    private int GetUserId() =>
        int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new UnauthorizedAccessException("User ID not found"));
}

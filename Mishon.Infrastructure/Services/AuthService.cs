using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly IUserRepository _userRepository;
    private readonly IConfiguration _config;
    private readonly MishonDbContext _context;
    private readonly IBlockService _blockService;

    public AuthService(
        IUserRepository userRepository,
        IConfiguration config,
        MishonDbContext context,
        IBlockService blockService)
    {
        _userRepository = userRepository;
        _config = config;
        _context = context;
        _blockService = blockService;
    }

    public async Task<Result<AuthResponseDto>> RegisterAsync(RegisterDto dto)
    {
        try
        {
            if (await _userRepository.ExistsByEmailAsync(dto.Email))
            {
                return Result<AuthResponseDto>.Failure("Email already in use", ResultError.Conflict);
            }

            if (await _userRepository.ExistsByUsernameAsync(dto.Username))
            {
                return Result<AuthResponseDto>.Failure("Username already taken", ResultError.Conflict);
            }

            var user = new User
            {
                Username = dto.Username,
                Email = dto.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password, 12),
                LastSeenAt = DateTime.UtcNow
            };

            await _userRepository.CreateAsync(user);

            var tokens = GenerateTokens(user);
            user.LastSeenAt = DateTime.UtcNow;
            user.RefreshToken = tokens.RefreshToken;
            user.RefreshTokenExpiry = tokens.RefreshTokenExpiry;
            await _userRepository.UpdateAsync(user);

            return Result<AuthResponseDto>.Success(new AuthResponseDto(
                user.Id,
                user.Username,
                user.Email,
                tokens.AccessToken,
                tokens.RefreshToken,
                tokens.RefreshTokenExpiry));
        }
        catch (DbUpdateException)
        {
            return Result<AuthResponseDto>.Failure("Database error", ResultError.InternalError);
        }
        catch (Exception ex)
        {
            return Result<AuthResponseDto>.Failure($"Registration error: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<AuthResponseDto>> LoginAsync(LoginDto dto)
    {
        try
        {
            var user = await _userRepository.GetByEmailAsync(dto.Email);
            if (user == null)
            {
                return Result<AuthResponseDto>.Failure("Invalid email or password", ResultError.Unauthorized);
            }

            if (!BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
            {
                return Result<AuthResponseDto>.Failure("Invalid email or password", ResultError.Unauthorized);
            }

            var tokens = GenerateTokens(user);
            user.LastSeenAt = DateTime.UtcNow;
            user.RefreshToken = tokens.RefreshToken;
            user.RefreshTokenExpiry = tokens.RefreshTokenExpiry;
            await _userRepository.UpdateAsync(user);

            return Result<AuthResponseDto>.Success(new AuthResponseDto(
                user.Id,
                user.Username,
                user.Email,
                tokens.AccessToken,
                tokens.RefreshToken,
                tokens.RefreshTokenExpiry));
        }
        catch (Exception ex)
        {
            return Result<AuthResponseDto>.Failure($"Login error: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<AuthResponseDto>> RefreshTokenAsync(string refreshToken)
    {
        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.RefreshToken == refreshToken);
            if (user == null || user.RefreshTokenExpiry <= DateTime.UtcNow)
            {
                return Result<AuthResponseDto>.Failure("Invalid or expired refresh token", ResultError.Unauthorized);
            }

            user.RefreshToken = null;
            user.RefreshTokenExpiry = null;
            await _userRepository.UpdateAsync(user);

            var tokens = GenerateTokens(user);
            user.RefreshToken = tokens.RefreshToken;
            user.RefreshTokenExpiry = tokens.RefreshTokenExpiry;
            await _userRepository.UpdateAsync(user);

            return Result<AuthResponseDto>.Success(new AuthResponseDto(
                user.Id,
                user.Username,
                user.Email,
                tokens.AccessToken,
                tokens.RefreshToken,
                tokens.RefreshTokenExpiry));
        }
        catch (Exception ex)
        {
            return Result<AuthResponseDto>.Failure($"Refresh token error: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<UserProfileDto>> GetProfileAsync(int userId)
    {
        return await GetProfileInternalAsync(userId, currentUserId: null);
    }

    public async Task<Result<UserProfileDto>> GetProfileForUserAsync(int userId, int currentUserId)
    {
        return await GetProfileInternalAsync(userId, currentUserId);
    }

    public async Task<Result<UserProfileDto>> UpdateProfileAsync(int userId, UpdateProfileDto dto)
    {
        try
        {
            var user = await _userRepository.GetByIdWithTokensAsync(userId);
            if (user == null)
            {
                return Result<UserProfileDto>.Failure("User not found", ResultError.NotFound);
            }

            if (!string.IsNullOrWhiteSpace(dto.Username) && dto.Username != user.Username)
            {
                if (await _userRepository.ExistsByUsernameAsync(dto.Username))
                {
                    return Result<UserProfileDto>.Failure("Username already taken", ResultError.Conflict);
                }

                user.Username = dto.Username;
            }

            ApplyProfileUpdate(user, dto);

            await _userRepository.UpdateAsync(user);
            return await GetProfileInternalAsync(userId, currentUserId: null);
        }
        catch (Exception ex)
        {
            return Result<UserProfileDto>.Failure($"Profile update error: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<UserProfileDto>> UpdateProfileMediaAsync(int userId, UpdateProfileMediaDto dto)
    {
        try
        {
            var user = await _userRepository.GetByIdWithTokensAsync(userId);
            if (user == null)
            {
                return Result<UserProfileDto>.Failure("User not found", ResultError.NotFound);
            }

            ApplyProfileUpdate(
                user,
                new UpdateProfileDto(
                    null,
                    null,
                    dto.AvatarUrl,
                    dto.BannerUrl,
                    dto.AvatarScale,
                    dto.AvatarOffsetX,
                    dto.AvatarOffsetY,
                    dto.BannerScale,
                    dto.BannerOffsetX,
                    dto.BannerOffsetY,
                    dto.RemoveAvatar,
                    dto.RemoveBanner));

            await _userRepository.UpdateAsync(user);
            return await GetProfileInternalAsync(userId, currentUserId: null);
        }
        catch (Exception ex)
        {
            return Result<UserProfileDto>.Failure($"Profile media update error: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> LogoutAsync(int userId)
    {
        try
        {
            var user = await _userRepository.GetByIdWithTokensAsync(userId);
            if (user == null)
            {
                return Result.Failure("User not found", ResultError.NotFound);
            }

            user.RefreshToken = null;
            user.RefreshTokenExpiry = null;
            await _userRepository.UpdateAsync(user);

            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Logout error: {ex.Message}", ResultError.InternalError);
        }
    }

    private async Task<Result<UserProfileDto>> GetProfileInternalAsync(int userId, int? currentUserId)
    {
        try
        {
            var user = await _userRepository.GetByIdAsync(userId);
            if (user == null)
            {
                return Result<UserProfileDto>.Failure("User not found", ResultError.NotFound);
            }

            var followersCount = await _context.Follows
                .AsNoTracking()
                .CountAsync(f => f.FollowingId == userId);

            var followingCount = await _context.Follows
                .AsNoTracking()
                .CountAsync(f => f.FollowerId == userId);

            var postsCount = await _context.Posts
                .AsNoTracking()
                .CountAsync(p => p.UserId == userId);

            var isOnline = user.LastSeenAt >= DateTime.UtcNow.AddMinutes(-5);

            var blockStatus = currentUserId.HasValue && currentUserId.Value != userId
                ? await _blockService.GetStatusAsync(currentUserId.Value, userId)
                : new UserBlockStatusDto(false, false);

            var canViewProtectedDetails = !blockStatus.HasBlockedViewer;
            bool? isFollowing = null;
            if (currentUserId.HasValue && canViewProtectedDetails)
            {
                isFollowing = await _context.Follows
                    .AsNoTracking()
                    .AnyAsync(f => f.FollowerId == currentUserId.Value && f.FollowingId == userId);
            }

            return Result<UserProfileDto>.Success(new UserProfileDto(
                user.Id,
                user.Username,
                canViewProtectedDetails ? user.Email : string.Empty,
                canViewProtectedDetails ? user.AboutMe : null,
                user.AvatarUrl,
                user.BannerUrl,
                user.AvatarScale,
                user.AvatarOffsetX,
                user.AvatarOffsetY,
                user.BannerScale,
                user.BannerOffsetX,
                user.BannerOffsetY,
                user.CreatedAt,
                user.LastSeenAt,
                isOnline,
                canViewProtectedDetails ? followersCount : 0,
                canViewProtectedDetails ? followingCount : 0,
                canViewProtectedDetails ? postsCount : 0,
                blockStatus.IsBlockedByViewer,
                blockStatus.HasBlockedViewer,
                isFollowing));
        }
        catch (Exception ex)
        {
            return Result<UserProfileDto>.Failure($"Profile error: {ex.Message}", ResultError.InternalError);
        }
    }

    private static void ApplyProfileUpdate(User user, UpdateProfileDto dto)
    {
        if (dto.AboutMe != null)
        {
            user.AboutMe = string.IsNullOrWhiteSpace(dto.AboutMe) ? null : dto.AboutMe.Trim();
        }

        if (dto.RemoveAvatar == true)
        {
            user.AvatarUrl = null;
            user.AvatarScale = 1;
            user.AvatarOffsetX = 0;
            user.AvatarOffsetY = 0;
        }
        else
        {
            if (dto.AvatarUrl != null)
            {
                user.AvatarUrl = dto.AvatarUrl;
            }

            if (dto.AvatarScale.HasValue)
            {
                user.AvatarScale = dto.AvatarScale.Value;
            }

            if (dto.AvatarOffsetX.HasValue)
            {
                user.AvatarOffsetX = dto.AvatarOffsetX.Value;
            }

            if (dto.AvatarOffsetY.HasValue)
            {
                user.AvatarOffsetY = dto.AvatarOffsetY.Value;
            }
        }

        if (dto.RemoveBanner == true)
        {
            user.BannerUrl = null;
            user.BannerScale = 1;
            user.BannerOffsetX = 0;
            user.BannerOffsetY = 0;
        }
        else
        {
            if (dto.BannerUrl != null)
            {
                user.BannerUrl = dto.BannerUrl;
            }

            if (dto.BannerScale.HasValue)
            {
                user.BannerScale = dto.BannerScale.Value;
            }

            if (dto.BannerOffsetX.HasValue)
            {
                user.BannerOffsetX = dto.BannerOffsetX.Value;
            }

            if (dto.BannerOffsetY.HasValue)
            {
                user.BannerOffsetY = dto.BannerOffsetY.Value;
            }
        }
    }

    private (string AccessToken, string RefreshToken, DateTime RefreshTokenExpiry) GenerateTokens(User user)
    {
        var jwtKey = Environment.GetEnvironmentVariable("JWT_KEY")
            ?? _config["Jwt:Key"]
            ?? throw new Exception("JWT Key not configured");

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var expireMinutes = int.TryParse(_config["Jwt:ExpireMinutes"], out var mins) ? mins : 15;
        var expireDays = int.TryParse(_config["Jwt:RefreshTokenExpireDays"], out var days) ? days : 7;
        var issuer = _config["Jwt:Issuer"] ?? "Mishon";
        var audience = _config["Jwt:Audience"] ?? "MishonUsers";

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim(ClaimTypes.Name, user.Username)
        };

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expireMinutes),
            signingCredentials: credentials);

        return (
            new JwtSecurityTokenHandler().WriteToken(token),
            Convert.ToBase64String(RandomNumberGenerator.GetBytes(64)),
            DateTime.UtcNow.AddDays(expireDays));
    }
}

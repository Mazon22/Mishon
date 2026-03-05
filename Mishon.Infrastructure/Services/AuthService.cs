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

    public AuthService(IUserRepository userRepository, IConfiguration config, MishonDbContext context)
    {
        _userRepository = userRepository;
        _config = config;
        _context = context;
    }

    public async Task<Result<AuthResponseDto>> RegisterAsync(RegisterDto dto)
    {
        try
        {
            if (await _userRepository.ExistsByEmailAsync(dto.Email))
                return Result<AuthResponseDto>.Failure("Email уже используется", ResultError.Conflict);

            if (await _userRepository.ExistsByUsernameAsync(dto.Username))
                return Result<AuthResponseDto>.Failure("Имя пользователя уже занят", ResultError.Conflict);

            var user = new User
            {
                Username = dto.Username,
                Email = dto.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password, 12)
            };

            await _userRepository.CreateAsync(user);
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
                tokens.RefreshTokenExpiry
            ));
        }
        catch (DbUpdateException ex)
        {
            return Result<AuthResponseDto>.Failure("Ошибка базы данных", ResultError.InternalError);
        }
        catch (Exception ex)
        {
            return Result<AuthResponseDto>.Failure($"Ошибка регистрации: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<AuthResponseDto>> LoginAsync(LoginDto dto)
    {
        try
        {
            var user = await _userRepository.GetByEmailAsync(dto.Email);
            if (user == null)
            {
                // To prevent timing attacks, still hash a dummy password
                BCrypt.Net.BCrypt.Verify(dto.Password, "$2a$12$dummyhashforsecurity");
                return Result<AuthResponseDto>.Failure("Неверный email или пароль", ResultError.Unauthorized);
            }

            if (!BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
                return Result<AuthResponseDto>.Failure("Неверный email или пароль", ResultError.Unauthorized);

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
                tokens.RefreshTokenExpiry
            ));
        }
        catch (Exception ex)
        {
            return Result<AuthResponseDto>.Failure($"Ошибка входа: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<AuthResponseDto>> RefreshTokenAsync(string refreshToken)
    {
        try
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.RefreshToken == refreshToken);

            if (user == null || user.RefreshTokenExpiry <= DateTime.UtcNow)
                return Result<AuthResponseDto>.Failure("Неверный или истекший refresh token", ResultError.Unauthorized);

            // Clear the old refresh token to prevent reuse
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
                tokens.RefreshTokenExpiry
            ));
        }
        catch (Exception ex)
        {
            return Result<AuthResponseDto>.Failure($"Ошибка обновления токена: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<UserProfileDto>> GetProfileAsync(int userId)
    {
        try
        {
            var user = await _userRepository.GetByIdAsync(userId);
            if (user == null)
                return Result<UserProfileDto>.Failure("Пользователь не найден", ResultError.NotFound);

            var followersCount = await _context.Follows
                .AsNoTracking()
                .CountAsync(f => f.FollowingId == userId);

            var followingCount = await _context.Follows
                .AsNoTracking()
                .CountAsync(f => f.FollowerId == userId);

            return Result<UserProfileDto>.Success(new UserProfileDto(
                user.Id,
                user.Username,
                user.Email,
                user.AvatarUrl,
                user.CreatedAt,
                followersCount,
                followingCount
            ));
        }
        catch (Exception ex)
        {
            return Result<UserProfileDto>.Failure($"Ошибка получения профиля: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<UserProfileDto>> GetProfileForUserAsync(int userId, int currentUserId)
    {
        try
        {
            var user = await _userRepository.GetByIdAsync(userId);
            if (user == null)
                return Result<UserProfileDto>.Failure("Пользователь не найден", ResultError.NotFound);

            var followersCount = await _context.Follows
                .AsNoTracking()
                .CountAsync(f => f.FollowingId == userId);

            var followingCount = await _context.Follows
                .AsNoTracking()
                .CountAsync(f => f.FollowerId == userId);

            var isFollowing = await _context.Follows
                .AsNoTracking()
                .AnyAsync(f => f.FollowerId == currentUserId && f.FollowingId == userId);

            return Result<UserProfileDto>.Success(new UserProfileDto(
                user.Id,
                user.Username,
                user.Email,
                user.AvatarUrl,
                user.CreatedAt,
                followersCount,
                followingCount,
                isFollowing
            ));
        }
        catch (Exception ex)
        {
            return Result<UserProfileDto>.Failure($"Ошибка получения профиля: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<UserProfileDto>> UpdateProfileAsync(int userId, UpdateProfileDto dto)
    {
        try
        {
            var user = await _userRepository.GetByIdWithTokensAsync(userId);
            if (user == null)
                return Result<UserProfileDto>.Failure("Пользователь не найден", ResultError.NotFound);

            if (dto.Username != null && dto.Username != user.Username)
            {
                if (await _userRepository.ExistsByUsernameAsync(dto.Username))
                    return Result<UserProfileDto>.Failure("Имя пользователя уже занято", ResultError.Conflict);
                user.Username = dto.Username;
            }

            if (dto.AvatarUrl != null)
                user.AvatarUrl = dto.AvatarUrl;

            await _userRepository.UpdateAsync(user);

            var followersCount = await _context.Follows
                .AsNoTracking()
                .CountAsync(f => f.FollowingId == userId);

            var followingCount = await _context.Follows
                .AsNoTracking()
                .CountAsync(f => f.FollowerId == userId);

            return Result<UserProfileDto>.Success(new UserProfileDto(
                user.Id,
                user.Username,
                user.Email,
                user.AvatarUrl,
                user.CreatedAt,
                followersCount,
                followingCount
            ));
        }
        catch (Exception ex)
        {
            return Result<UserProfileDto>.Failure($"Ошибка обновления профиля: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> LogoutAsync(int userId)
    {
        try
        {
            var user = await _userRepository.GetByIdWithTokensAsync(userId);
            if (user == null)
                return Result.Failure("Пользователь не найден", ResultError.NotFound);

            user.RefreshToken = null;
            user.RefreshTokenExpiry = null;
            await _userRepository.UpdateAsync(user);

            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка выхода: {ex.Message}", ResultError.InternalError);
        }
    }

    private (string AccessToken, string RefreshToken, DateTime RefreshTokenExpiry) GenerateTokens(User user)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(
            Environment.GetEnvironmentVariable("JWT_KEY") 
            ?? _config["Jwt:Key"] 
            ?? throw new Exception("JWT Key not configured")
        ));
        
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var expireMinutes = int.TryParse(_config["Jwt:ExpireMinutes"], out var mins) ? mins : 15;
        var expireDays = int.TryParse(_config["Jwt:RefreshTokenExpireDays"], out var days) ? days : 7;

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim(ClaimTypes.Name, user.Username)
        };

        var token = new JwtSecurityToken(
            issuer: _config["Jwt:Issuer"],
            audience: _config["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expireMinutes),
            signingCredentials: credentials
        );

        var refreshToken = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));

        return (
            new JwtSecurityTokenHandler().WriteToken(token),
            refreshToken,
            DateTime.UtcNow.AddDays(expireDays)
        );
    }
}

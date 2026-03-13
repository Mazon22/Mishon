using Microsoft.EntityFrameworkCore;
using System.Text.RegularExpressions;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class UserDiscoveryService : IUserDiscoveryService
{
    private static readonly Regex UsernameRegex = new(
        "^[a-z0-9._]{5,50}$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private readonly MishonDbContext _context;

    public UserDiscoveryService(MishonDbContext context)
    {
        _context = context;
    }

    public async Task<Result<IEnumerable<DiscoverUserDto>>> GetUsersAsync(
        int currentUserId,
        string? query,
        int limit = 24,
        CancellationToken cancellationToken = default)
    {
        try
        {
            limit = Math.Clamp(limit, 1, 50);
            var normalizedQuery = query?.Trim();

            var usersQuery = _context.Users
                .AsNoTracking()
                .Where(u => u.Id != currentUserId);

            if (!string.IsNullOrWhiteSpace(normalizedQuery))
            {
                usersQuery = usersQuery.Where(u => EF.Functions.ILike(u.Username, $"%{normalizedQuery}%"));
            }

            var users = await usersQuery
                .OrderBy(u => u.Username)
                .Take(limit)
                .ToListAsync(cancellationToken);

            if (users.Count == 0)
            {
                return Result<IEnumerable<DiscoverUserDto>>.Success(Array.Empty<DiscoverUserDto>());
            }

            var userIds = users.Select(u => u.Id).ToArray();

            var followingIds = (await _context.Follows
                .AsNoTracking()
                .Where(f => f.FollowerId == currentUserId && userIds.Contains(f.FollowingId))
                .Select(f => f.FollowingId)
                .ToListAsync(cancellationToken))
                .ToHashSet();

            var friendIds = (await _context.Friendships
                .AsNoTracking()
                .Where(f => (f.UserAId == currentUserId && userIds.Contains(f.UserBId))
                    || (f.UserBId == currentUserId && userIds.Contains(f.UserAId)))
                .Select(f => f.UserAId == currentUserId ? f.UserBId : f.UserAId)
                .ToListAsync(cancellationToken))
                .ToHashSet();

            var incomingRequests = await _context.FriendRequests
                .AsNoTracking()
                .Where(r => r.ReceiverId == currentUserId && userIds.Contains(r.SenderId))
                .ToDictionaryAsync(r => r.SenderId, r => (int?)r.Id, cancellationToken);

            var outgoingRequests = await _context.FriendRequests
                .AsNoTracking()
                .Where(r => r.SenderId == currentUserId && userIds.Contains(r.ReceiverId))
                .ToDictionaryAsync(r => r.ReceiverId, r => (int?)r.Id, cancellationToken);

            var result = users.Select(user => new DiscoverUserDto(
                user.Id,
                user.Username,
                user.AvatarUrl,
                user.AvatarScale,
                user.AvatarOffsetX,
                user.AvatarOffsetY,
                followingIds.Contains(user.Id),
                friendIds.Contains(user.Id),
                incomingRequests.GetValueOrDefault(user.Id),
                outgoingRequests.GetValueOrDefault(user.Id)));

            return Result<IEnumerable<DiscoverUserDto>>.Success(result);
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<DiscoverUserDto>>.Failure($"Ошибка получения пользователей: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<UsernameAvailabilityDto>> CheckUsernameAvailabilityAsync(
        int currentUserId,
        string username,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var normalizedUsername = username.Trim().ToLowerInvariant();
            if (!UsernameRegex.IsMatch(normalizedUsername))
            {
                return Result<UsernameAvailabilityDto>.Success(new UsernameAvailabilityDto(false));
            }

            var currentUsername = await _context.Users
                .AsNoTracking()
                .Where(u => u.Id == currentUserId)
                .Select(u => u.Username)
                .FirstOrDefaultAsync(cancellationToken);

            if (currentUsername == null)
            {
                return Result<UsernameAvailabilityDto>.Failure("User not found", ResultError.NotFound);
            }

            if (string.Equals(currentUsername, normalizedUsername, StringComparison.OrdinalIgnoreCase))
            {
                return Result<UsernameAvailabilityDto>.Success(new UsernameAvailabilityDto(true));
            }

            var isTaken = await _context.Users
                .AsNoTracking()
                .AnyAsync(
                    u => u.Id != currentUserId && EF.Functions.ILike(u.Username, normalizedUsername),
                    cancellationToken);

            return Result<UsernameAvailabilityDto>.Success(new UsernameAvailabilityDto(!isTaken));
        }
        catch (Exception ex)
        {
            return Result<UsernameAvailabilityDto>.Failure(
                $"Username availability error: {ex.Message}",
                ResultError.InternalError);
        }
    }
}

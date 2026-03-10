using Microsoft.EntityFrameworkCore;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class UserDiscoveryService : IUserDiscoveryService
{
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
}

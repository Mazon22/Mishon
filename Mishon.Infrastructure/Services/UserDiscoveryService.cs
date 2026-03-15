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
                usersQuery = usersQuery.Where(
                    u => EF.Functions.ILike(u.Username, $"%{normalizedQuery}%")
                        || (u.AboutMe != null && EF.Functions.ILike(u.AboutMe, $"%{normalizedQuery}%")));
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
            var currentFriendIds = await _context.Friendships
                .AsNoTracking()
                .Where(f => f.UserAId == currentUserId || f.UserBId == currentUserId)
                .Select(f => f.UserAId == currentUserId ? f.UserBId : f.UserAId)
                .ToListAsync(cancellationToken);
            var currentFriendIdSet = currentFriendIds.ToHashSet();

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

            var followersCountMap = await _context.Follows
                .AsNoTracking()
                .Where(f => userIds.Contains(f.FollowingId))
                .GroupBy(f => f.FollowingId)
                .ToDictionaryAsync(g => g.Key, g => g.Count(), cancellationToken);

            var postsCountMap = await _context.Posts
                .AsNoTracking()
                .Where(p => userIds.Contains(p.UserId))
                .GroupBy(p => p.UserId)
                .ToDictionaryAsync(g => g.Key, g => g.Count(), cancellationToken);

            var candidateFriendships = await _context.Friendships
                .AsNoTracking()
                .Where(f => userIds.Contains(f.UserAId) || userIds.Contains(f.UserBId))
                .Select(f => new { f.UserAId, f.UserBId })
                .ToListAsync(cancellationToken);

            var mutualFriendsCountMap = new Dictionary<int, int>();
            foreach (var candidateId in userIds)
            {
                mutualFriendsCountMap[candidateId] = candidateFriendships.Count(friendship =>
                {
                    if (friendship.UserAId == candidateId)
                    {
                        return currentFriendIdSet.Contains(friendship.UserBId);
                    }

                    if (friendship.UserBId == candidateId)
                    {
                        return currentFriendIdSet.Contains(friendship.UserAId);
                    }

                    return false;
                });
            }

            var currentUserPostIds = await _context.Posts
                .AsNoTracking()
                .Where(p => p.UserId == currentUserId)
                .Select(p => p.Id)
                .ToListAsync(cancellationToken);

            var incomingLikes = await _context.Likes
                .AsNoTracking()
                .Where(l => l.UserId == currentUserId && userIds.Contains(l.Post.UserId))
                .GroupBy(l => l.Post.UserId)
                .ToDictionaryAsync(g => g.Key, g => g.Count(), cancellationToken);

            var outgoingLikes = currentUserPostIds.Count == 0
                ? new Dictionary<int, int>()
                : await _context.Likes
                    .AsNoTracking()
                    .Where(l => currentUserPostIds.Contains(l.PostId) && userIds.Contains(l.UserId))
                    .GroupBy(l => l.UserId)
                    .ToDictionaryAsync(g => g.Key, g => g.Count(), cancellationToken);

            var incomingComments = await _context.Comments
                .AsNoTracking()
                .Where(c => c.UserId == currentUserId && userIds.Contains(c.Post.UserId))
                .GroupBy(c => c.Post.UserId)
                .ToDictionaryAsync(g => g.Key, g => g.Count(), cancellationToken);

            var outgoingComments = currentUserPostIds.Count == 0
                ? new Dictionary<int, int>()
                : await _context.Comments
                    .AsNoTracking()
                    .Where(c => currentUserPostIds.Contains(c.PostId) && userIds.Contains(c.UserId))
                    .GroupBy(c => c.UserId)
                    .ToDictionaryAsync(g => g.Key, g => g.Count(), cancellationToken);

            var result = users.Select(user => new DiscoverUserDto(
                user.Id,
                user.Username,
                user.AboutMe,
                user.AvatarUrl,
                user.AvatarScale,
                user.AvatarOffsetX,
                user.AvatarOffsetY,
                user.LastSeenAt,
                user.LastSeenAt >= DateTime.UtcNow.AddMinutes(-5),
                followersCountMap.GetValueOrDefault(user.Id),
                postsCountMap.GetValueOrDefault(user.Id),
                mutualFriendsCountMap.GetValueOrDefault(user.Id),
                incomingLikes.GetValueOrDefault(user.Id)
                    + outgoingLikes.GetValueOrDefault(user.Id)
                    + incomingComments.GetValueOrDefault(user.Id)
                    + outgoingComments.GetValueOrDefault(user.Id),
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

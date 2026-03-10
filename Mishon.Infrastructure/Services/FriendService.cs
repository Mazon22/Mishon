using Microsoft.EntityFrameworkCore;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class FriendService : IFriendService
{
    private readonly MishonDbContext _context;
    private readonly INotificationService _notificationService;

    public FriendService(MishonDbContext context, INotificationService notificationService)
    {
        _context = context;
        _notificationService = notificationService;
    }

    public async Task<Result<IEnumerable<FriendDto>>> GetFriendsAsync(int userId, CancellationToken cancellationToken = default)
    {
        try
        {
            var friendships = await _context.Friendships
                .AsNoTracking()
                .Include(f => f.UserA)
                .Include(f => f.UserB)
                .Where(f => f.UserAId == userId || f.UserBId == userId)
                .OrderByDescending(f => f.CreatedAt)
                .ToListAsync(cancellationToken);

            var friends = friendships
                .Select(friendship => friendship.UserAId == userId ? friendship.UserB : friendship.UserA)
                .OrderBy(user => user.Username)
                .Select(user => new FriendDto(
                    user.Id,
                    user.Username,
                    user.AvatarUrl,
                    user.AvatarScale,
                    user.AvatarOffsetX,
                    user.AvatarOffsetY));

            return Result<IEnumerable<FriendDto>>.Success(friends);
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<FriendDto>>.Failure($"Ошибка получения друзей: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<IEnumerable<FriendRequestDto>>> GetIncomingRequestsAsync(int userId, CancellationToken cancellationToken = default)
    {
        try
        {
            var requests = await _context.FriendRequests
                .AsNoTracking()
                .Include(r => r.Sender)
                .Where(r => r.ReceiverId == userId)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync(cancellationToken);

            return Result<IEnumerable<FriendRequestDto>>.Success(
                requests.Select(r => new FriendRequestDto(
                    r.Id,
                    r.SenderId,
                    r.Sender.Username,
                    r.Sender.AvatarUrl,
                    r.Sender.AvatarScale,
                    r.Sender.AvatarOffsetX,
                    r.Sender.AvatarOffsetY,
                    true,
                    r.CreatedAt)));
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<FriendRequestDto>>.Failure($"Ошибка получения входящих заявок: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<IEnumerable<FriendRequestDto>>> GetOutgoingRequestsAsync(int userId, CancellationToken cancellationToken = default)
    {
        try
        {
            var requests = await _context.FriendRequests
                .AsNoTracking()
                .Include(r => r.Receiver)
                .Where(r => r.SenderId == userId)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync(cancellationToken);

            return Result<IEnumerable<FriendRequestDto>>.Success(
                requests.Select(r => new FriendRequestDto(
                    r.Id,
                    r.ReceiverId,
                    r.Receiver.Username,
                    r.Receiver.AvatarUrl,
                    r.Receiver.AvatarScale,
                    r.Receiver.AvatarOffsetX,
                    r.Receiver.AvatarOffsetY,
                    false,
                    r.CreatedAt)));
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<FriendRequestDto>>.Failure($"Ошибка получения исходящих заявок: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> SendRequestAsync(int userId, int targetUserId, CancellationToken cancellationToken = default)
    {
        try
        {
            if (userId == targetUserId)
            {
                return Result.Failure("Нельзя отправить заявку себе", ResultError.BadRequest);
            }

            var targetExists = await _context.Users
                .AsNoTracking()
                .AnyAsync(u => u.Id == targetUserId, cancellationToken);

            if (!targetExists)
            {
                return Result.Failure("Пользователь не найден", ResultError.NotFound);
            }

            if (await AreFriendsAsync(userId, targetUserId, cancellationToken))
            {
                return Result.Failure("Пользователь уже в друзьях", ResultError.Conflict);
            }

            var reverseRequest = await _context.FriendRequests
                .FirstOrDefaultAsync(r => r.SenderId == targetUserId && r.ReceiverId == userId, cancellationToken);

            if (reverseRequest != null)
            {
                _context.FriendRequests.Remove(reverseRequest);
                var normalized = NormalizePair(userId, targetUserId);
                _context.Friendships.Add(new Friendship
                {
                    UserAId = normalized.Item1,
                    UserBId = normalized.Item2
                });
                await _context.SaveChangesAsync(cancellationToken);

                await _notificationService.CreateAsync(new CreateNotificationDto(
                    targetUserId,
                    userId,
                    NotificationTypes.FriendAccepted,
                    "принял(а) вашу заявку в друзья",
                    null,
                    null,
                    null,
                    null,
                    userId), cancellationToken);
                return Result.Success();
            }

            var existingRequest = await _context.FriendRequests
                .AsNoTracking()
                .AnyAsync(r => r.SenderId == userId && r.ReceiverId == targetUserId, cancellationToken);

            if (existingRequest)
            {
                return Result.Failure("Заявка уже отправлена", ResultError.Conflict);
            }

            _context.FriendRequests.Add(new FriendRequest
            {
                SenderId = userId,
                ReceiverId = targetUserId
            });

            await _context.SaveChangesAsync(cancellationToken);

            await _notificationService.CreateAsync(new CreateNotificationDto(
                targetUserId,
                userId,
                NotificationTypes.FriendRequest,
                "отправил(а) вам заявку в друзья",
                null,
                null,
                null,
                null,
                userId), cancellationToken);
            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка отправки заявки: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> AcceptRequestAsync(int userId, int requestId, CancellationToken cancellationToken = default)
    {
        try
        {
            var request = await _context.FriendRequests
                .FirstOrDefaultAsync(r => r.Id == requestId && r.ReceiverId == userId, cancellationToken);

            if (request == null)
            {
                return Result.Failure("Заявка не найдена", ResultError.NotFound);
            }

            if (!await AreFriendsAsync(userId, request.SenderId, cancellationToken))
            {
                var (userAId, userBId) = NormalizePair(userId, request.SenderId);
                _context.Friendships.Add(new Friendship
                {
                    UserAId = userAId,
                    UserBId = userBId
                });
            }

            _context.FriendRequests.Remove(request);
            await _context.SaveChangesAsync(cancellationToken);

            await _notificationService.CreateAsync(new CreateNotificationDto(
                request.SenderId,
                userId,
                NotificationTypes.FriendAccepted,
                "принял(а) вашу заявку в друзья",
                null,
                null,
                null,
                null,
                userId), cancellationToken);

            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка принятия заявки: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> DeleteRequestAsync(int userId, int requestId, CancellationToken cancellationToken = default)
    {
        try
        {
            var request = await _context.FriendRequests
                .FirstOrDefaultAsync(
                    r => r.Id == requestId && (r.SenderId == userId || r.ReceiverId == userId),
                    cancellationToken);

            if (request == null)
            {
                return Result.Failure("Заявка не найдена", ResultError.NotFound);
            }

            _context.FriendRequests.Remove(request);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка удаления заявки: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> RemoveFriendAsync(int userId, int friendId, CancellationToken cancellationToken = default)
    {
        try
        {
            var (userAId, userBId) = NormalizePair(userId, friendId);
            var friendship = await _context.Friendships
                .FirstOrDefaultAsync(f => f.UserAId == userAId && f.UserBId == userBId, cancellationToken);

            if (friendship == null)
            {
                return Result.Failure("Друг не найден", ResultError.NotFound);
            }

            _context.Friendships.Remove(friendship);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка удаления друга: {ex.Message}", ResultError.InternalError);
        }
    }

    private async Task<bool> AreFriendsAsync(int userId, int otherUserId, CancellationToken cancellationToken)
    {
        var (userAId, userBId) = NormalizePair(userId, otherUserId);
        return await _context.Friendships
            .AsNoTracking()
            .AnyAsync(f => f.UserAId == userAId && f.UserBId == userBId, cancellationToken);
    }

    private static (int, int) NormalizePair(int first, int second)
    {
        return first <= second ? (first, second) : (second, first);
    }
}

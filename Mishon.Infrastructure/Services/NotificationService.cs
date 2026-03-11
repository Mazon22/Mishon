using Microsoft.EntityFrameworkCore;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class NotificationService : INotificationService
{
    private static readonly string[] HiddenNotificationTypes =
    [
        NotificationTypes.Message,
        NotificationTypes.MessageReply
    ];

    private readonly MishonDbContext _context;

    public NotificationService(MishonDbContext context)
    {
        _context = context;
    }

    public async Task CreateAsync(CreateNotificationDto notification, CancellationToken cancellationToken = default)
    {
        if (notification.UserId <= 0)
        {
            return;
        }

        if (notification.ActorUserId.HasValue && notification.ActorUserId.Value == notification.UserId)
        {
            return;
        }

        var entity = new Notification
        {
            UserId = notification.UserId,
            ActorUserId = notification.ActorUserId,
            Type = notification.Type,
            Text = notification.Text,
            PostId = notification.PostId,
            CommentId = notification.CommentId,
            ConversationId = notification.ConversationId,
            MessageId = notification.MessageId,
            RelatedUserId = notification.RelatedUserId
        };

        _context.Notifications.Add(entity);
        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task<Result<IEnumerable<NotificationDto>>> GetNotificationsAsync(int userId, CancellationToken cancellationToken = default)
    {
        try
        {
            var notifications = await _context.Notifications
                .AsNoTracking()
                .Include(n => n.ActorUser)
                .Where(n => n.UserId == userId && !HiddenNotificationTypes.Contains(n.Type))
                .OrderByDescending(n => n.CreatedAt)
                .Take(100)
                .ToListAsync(cancellationToken);

            return Result<IEnumerable<NotificationDto>>.Success(notifications.Select(MapToDto));
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<NotificationDto>>.Failure($"Ошибка получения уведомлений: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<NotificationSummaryDto>> GetSummaryAsync(int userId, CancellationToken cancellationToken = default)
    {
        try
        {
            var unreadNotifications = await _context.Notifications
                .AsNoTracking()
                .CountAsync(
                    n => n.UserId == userId &&
                         !n.IsRead &&
                         !HiddenNotificationTypes.Contains(n.Type),
                    cancellationToken);

            var incomingFriendRequests = await _context.FriendRequests
                .AsNoTracking()
                .CountAsync(r => r.ReceiverId == userId, cancellationToken);

            var conversations = await _context.Conversations
                .AsNoTracking()
                .Include(c => c.Messages)
                .Where(c => c.UserAId == userId || c.UserBId == userId)
                .ToListAsync(cancellationToken);

            var unreadChats = conversations.Sum(conversation =>
            {
                var readAt = conversation.UserAId == userId ? conversation.UserAReadAt : conversation.UserBReadAt;
                return conversation.Messages.Count(m => m.SenderId != userId && (!readAt.HasValue || m.CreatedAt > readAt.Value));
            });

            return Result<NotificationSummaryDto>.Success(new NotificationSummaryDto(
                unreadNotifications,
                unreadChats,
                incomingFriendRequests));
        }
        catch (Exception ex)
        {
            return Result<NotificationSummaryDto>.Failure($"Ошибка получения счетчиков уведомлений: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> MarkAsReadAsync(int userId, int notificationId, CancellationToken cancellationToken = default)
    {
        try
        {
            var notification = await _context.Notifications
                .FirstOrDefaultAsync(n => n.Id == notificationId && n.UserId == userId, cancellationToken);

            if (notification == null)
            {
                return Result.Failure("Уведомление не найдено", ResultError.NotFound);
            }

            notification.IsRead = true;
            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка обновления уведомления: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> MarkAllAsReadAsync(int userId, CancellationToken cancellationToken = default)
    {
        try
        {
            var notifications = await _context.Notifications
                .Where(n => n.UserId == userId && !n.IsRead && !HiddenNotificationTypes.Contains(n.Type))
                .ToListAsync(cancellationToken);

            if (notifications.Count == 0)
            {
                return Result.Success();
            }

            foreach (var notification in notifications)
            {
                notification.IsRead = true;
            }

            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка обновления уведомлений: {ex.Message}", ResultError.InternalError);
        }
    }

    private static NotificationDto MapToDto(Notification notification)
    {
        return new NotificationDto(
            notification.Id,
            notification.Type,
            notification.Text,
            notification.IsRead,
            notification.CreatedAt,
            notification.ActorUserId,
            notification.ActorUser?.Username,
            notification.ActorUser?.AvatarUrl,
            notification.ActorUser?.AvatarScale ?? 1d,
            notification.ActorUser?.AvatarOffsetX ?? 0d,
            notification.ActorUser?.AvatarOffsetY ?? 0d,
            notification.PostId,
            notification.CommentId,
            notification.ConversationId,
            notification.MessageId,
            notification.RelatedUserId);
    }
}

using Microsoft.EntityFrameworkCore;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class ConversationService : IConversationService
{
    private readonly MishonDbContext _context;

    public ConversationService(MishonDbContext context)
    {
        _context = context;
    }

    public async Task<Result<IEnumerable<ConversationDto>>> GetConversationsAsync(int userId, CancellationToken cancellationToken = default)
    {
        try
        {
            var conversations = await _context.Conversations
                .AsNoTracking()
                .Include(c => c.UserA)
                .Include(c => c.UserB)
                .Include(c => c.Messages)
                    .ThenInclude(m => m.Attachments)
                .Where(c => c.UserAId == userId || c.UserBId == userId)
                .OrderByDescending(c => c.UpdatedAt)
                .ToListAsync(cancellationToken);

            var result = conversations.Select(conversation =>
            {
                var peer = conversation.UserAId == userId ? conversation.UserB : conversation.UserA;
                var lastMessage = conversation.Messages.OrderByDescending(m => m.CreatedAt).FirstOrDefault();
                var readAt = conversation.UserAId == userId ? conversation.UserAReadAt : conversation.UserBReadAt;
                var unreadCount = conversation.Messages.Count(m => m.SenderId != userId && (!readAt.HasValue || m.CreatedAt > readAt.Value));

                return new ConversationDto(
                    conversation.Id,
                    peer.Id,
                    peer.Username,
                    peer.AvatarUrl,
                    peer.AvatarScale,
                    peer.AvatarOffsetX,
                    peer.AvatarOffsetY,
                    lastMessage != null ? BuildMessagePreview(lastMessage) : null,
                    lastMessage?.CreatedAt,
                    unreadCount);
            });

            return Result<IEnumerable<ConversationDto>>.Success(result);
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<ConversationDto>>.Failure($"Ошибка получения диалогов: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<DirectConversationDto>> GetOrCreateDirectConversationAsync(int userId, int peerUserId, CancellationToken cancellationToken = default)
    {
        try
        {
            if (userId == peerUserId)
            {
                return Result<DirectConversationDto>.Failure("Нельзя создать диалог с собой", ResultError.BadRequest);
            }

            var peer = await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == peerUserId, cancellationToken);

            if (peer == null)
            {
                return Result<DirectConversationDto>.Failure("Пользователь не найден", ResultError.NotFound);
            }

            if (!await AreFriendsAsync(userId, peerUserId, cancellationToken))
            {
                return Result<DirectConversationDto>.Failure("Личные сообщения доступны только друзьям", ResultError.Forbidden);
            }

            var (userAId, userBId) = NormalizePair(userId, peerUserId);

            var conversation = await _context.Conversations
                .FirstOrDefaultAsync(c => c.UserAId == userAId && c.UserBId == userBId, cancellationToken);

            if (conversation == null)
            {
                conversation = new Conversation
                {
                    UserAId = userAId,
                    UserBId = userBId,
                    UserAReadAt = userAId == userId ? DateTime.UtcNow : null,
                    UserBReadAt = userBId == userId ? DateTime.UtcNow : null
                };

                _context.Conversations.Add(conversation);
                await _context.SaveChangesAsync(cancellationToken);
            }

            return Result<DirectConversationDto>.Success(new DirectConversationDto(
                conversation.Id,
                peer.Id,
                peer.Username,
                peer.AvatarUrl,
                peer.AvatarScale,
                peer.AvatarOffsetX,
                peer.AvatarOffsetY));
        }
        catch (Exception ex)
        {
            return Result<DirectConversationDto>.Failure($"Ошибка открытия диалога: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<IEnumerable<MessageDto>>> GetMessagesAsync(int userId, int conversationId, CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .Include(c => c.UserA)
                .Include(c => c.UserB)
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result<IEnumerable<MessageDto>>.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result<IEnumerable<MessageDto>>.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            var messages = await _context.Messages
                .AsNoTracking()
                .Include(m => m.Sender)
                .Include(m => m.Attachments)
                .Include(m => m.ReplyToMessage)
                    .ThenInclude(m => m!.Sender)
                .Include(m => m.ReplyToMessage)
                    .ThenInclude(m => m!.Attachments)
                .Where(m => m.ConversationId == conversationId)
                .OrderBy(m => m.CreatedAt)
                .ToListAsync(cancellationToken);

            MarkAsRead(conversation, userId);
            await _context.SaveChangesAsync(cancellationToken);

            var peerReadAt = conversation.UserAId == userId ? conversation.UserBReadAt : conversation.UserAReadAt;
            return Result<IEnumerable<MessageDto>>.Success(messages.Select(message => MapToDto(message, userId, peerReadAt)));
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<MessageDto>>.Failure($"Ошибка получения сообщений: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<MessageDto>> SendMessageAsync(int userId, int conversationId, CreateMessageDto dto, CancellationToken cancellationToken = default)
    {
        try
        {
            var content = dto.Content?.Trim() ?? string.Empty;
            var attachments = dto.Attachments?.ToList() ?? [];

            if (string.IsNullOrWhiteSpace(content) && attachments.Count == 0)
            {
                return Result<MessageDto>.Failure("Сообщение должно содержать текст или вложения", ResultError.ValidationError);
            }

            var conversation = await _context.Conversations
                .Include(c => c.UserA)
                .Include(c => c.UserB)
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result<MessageDto>.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result<MessageDto>.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            Message? replyToMessage = null;
            if (dto.ReplyToMessageId.HasValue)
            {
                replyToMessage = await _context.Messages
                    .Include(m => m.Sender)
                    .Include(m => m.Attachments)
                    .FirstOrDefaultAsync(
                        m => m.Id == dto.ReplyToMessageId.Value && m.ConversationId == conversationId,
                        cancellationToken);

                if (replyToMessage == null)
                {
                    return Result<MessageDto>.Failure("Сообщение для ответа не найдено", ResultError.NotFound);
                }
            }

            var message = new Message
            {
                ConversationId = conversationId,
                SenderId = userId,
                Content = content,
                ReplyToMessageId = replyToMessage?.Id,
                Attachments = attachments.Select(attachment => new MessageAttachment
                {
                    FileName = attachment.FileName,
                    FileUrl = attachment.FileUrl,
                    ContentType = attachment.ContentType,
                    SizeBytes = attachment.SizeBytes,
                    IsImage = attachment.IsImage
                }).ToList()
            };

            _context.Messages.Add(message);
            conversation.UpdatedAt = DateTime.UtcNow;
            MarkAsRead(conversation, userId);

            await _context.SaveChangesAsync(cancellationToken);

            message.Sender = conversation.UserAId == userId ? conversation.UserA : conversation.UserB;
            message.ReplyToMessage = replyToMessage;

            return Result<MessageDto>.Success(MapToDto(message, userId, null));
        }
        catch (Exception ex)
        {
            return Result<MessageDto>.Failure($"Ошибка отправки сообщения: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<MessageDto>> UpdateMessageAsync(int userId, int conversationId, int messageId, UpdateMessageDto dto, CancellationToken cancellationToken = default)
    {
        try
        {
            var message = await _context.Messages
                .Include(m => m.Sender)
                .Include(m => m.Attachments)
                .Include(m => m.ReplyToMessage)
                    .ThenInclude(m => m!.Sender)
                .Include(m => m.ReplyToMessage)
                    .ThenInclude(m => m!.Attachments)
                .FirstOrDefaultAsync(m => m.Id == messageId && m.ConversationId == conversationId, cancellationToken);

            if (message == null)
            {
                return Result<MessageDto>.Failure("Сообщение не найдено", ResultError.NotFound);
            }

            if (message.SenderId != userId)
            {
                return Result<MessageDto>.Failure("Нет прав для редактирования сообщения", ResultError.Forbidden);
            }

            message.Content = dto.Content.Trim();
            message.EditedAt = DateTime.UtcNow;

            var conversation = await _context.Conversations.FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);
            if (conversation != null)
            {
                conversation.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync(cancellationToken);
            var peerReadAt = conversation == null
                ? null
                : conversation.UserAId == userId ? conversation.UserBReadAt : conversation.UserAReadAt;
            return Result<MessageDto>.Success(MapToDto(message, userId, peerReadAt));
        }
        catch (Exception ex)
        {
            return Result<MessageDto>.Failure($"Ошибка обновления сообщения: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<DeleteMessageResultDto>> DeleteMessageAsync(int userId, int conversationId, int messageId, CancellationToken cancellationToken = default)
    {
        try
        {
            var message = await _context.Messages
                .Include(m => m.Attachments)
                .FirstOrDefaultAsync(m => m.Id == messageId && m.ConversationId == conversationId, cancellationToken);

            if (message == null)
            {
                return Result<DeleteMessageResultDto>.Failure("Сообщение не найдено", ResultError.NotFound);
            }

            if (message.SenderId != userId)
            {
                return Result<DeleteMessageResultDto>.Failure("Нет прав для удаления сообщения", ResultError.Forbidden);
            }

            var attachmentUrls = message.Attachments
                .Select(a => a.FileUrl)
                .Where(url => !string.IsNullOrWhiteSpace(url))
                .ToList();

            _context.Messages.Remove(message);

            var conversation = await _context.Conversations.FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);
            if (conversation != null)
            {
                conversation.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync(cancellationToken);
            return Result<DeleteMessageResultDto>.Success(new DeleteMessageResultDto(attachmentUrls));
        }
        catch (Exception ex)
        {
            return Result<DeleteMessageResultDto>.Failure($"Ошибка удаления сообщения: {ex.Message}", ResultError.InternalError);
        }
    }

    private static MessageDto MapToDto(Message message, int userId, DateTime? peerReadAt)
    {
        return new MessageDto(
            message.Id,
            message.ConversationId,
            message.SenderId,
            message.Sender.Username,
            message.Content,
            message.CreatedAt,
            message.EditedAt,
            message.SenderId == userId,
            message.SenderId == userId && peerReadAt.HasValue && message.CreatedAt <= peerReadAt.Value,
            message.ReplyToMessageId,
            message.ReplyToMessage?.Sender.Username,
            message.ReplyToMessage != null ? BuildMessagePreview(message.ReplyToMessage) : null,
            message.Attachments.Select(MapAttachmentToDto).ToList());
    }

    private static MessageAttachmentDto MapAttachmentToDto(MessageAttachment attachment)
    {
        return new MessageAttachmentDto(
            attachment.Id,
            attachment.FileName,
            attachment.FileUrl,
            attachment.ContentType,
            attachment.SizeBytes,
            attachment.IsImage);
    }

    private static string BuildMessagePreview(Message message)
    {
        if (!string.IsNullOrWhiteSpace(message.Content))
        {
            return message.Content;
        }

        var attachments = message.Attachments.ToList();
        if (attachments.Count == 0)
        {
            return string.Empty;
        }

        var imageCount = attachments.Count(a => a.IsImage);
        var fileCount = attachments.Count - imageCount;

        if (imageCount > 0 && fileCount == 0)
        {
            return imageCount == 1 ? "Фото" : $"Фотографии: {imageCount}";
        }

        if (fileCount > 0 && imageCount == 0)
        {
            return fileCount == 1 ? "Файл" : $"Файлы: {fileCount}";
        }

        return $"Вложения: {attachments.Count}";
    }

    private async Task<bool> AreFriendsAsync(int userId, int otherUserId, CancellationToken cancellationToken)
    {
        var (userAId, userBId) = NormalizePair(userId, otherUserId);
        return await _context.Friendships
            .AsNoTracking()
            .AnyAsync(f => f.UserAId == userAId && f.UserBId == userBId, cancellationToken);
    }

    private static void MarkAsRead(Conversation conversation, int userId)
    {
        var now = DateTime.UtcNow;
        if (conversation.UserAId == userId)
        {
            conversation.UserAReadAt = now;
        }
        else
        {
            conversation.UserBReadAt = now;
        }
    }

    private static bool IsParticipant(Conversation conversation, int userId)
    {
        return conversation.UserAId == userId || conversation.UserBId == userId;
    }

    private static (int, int) NormalizePair(int first, int second)
    {
        return first <= second ? (first, second) : (second, first);
    }
}

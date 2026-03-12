using Microsoft.EntityFrameworkCore;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class ConversationService : IConversationService
{
    private const int MaxPinnedChats = 5;

    private readonly MishonDbContext _context;
    private readonly IBlockService _blockService;
    private readonly IChatConnectionTracker _chatConnectionTracker;
    private readonly IChatRealtimeNotifier _chatRealtimeNotifier;

    public ConversationService(
        MishonDbContext context,
        IBlockService blockService,
        IChatConnectionTracker chatConnectionTracker,
        IChatRealtimeNotifier chatRealtimeNotifier)
    {
        _context = context;
        _blockService = blockService;
        _chatConnectionTracker = chatConnectionTracker;
        _chatRealtimeNotifier = chatRealtimeNotifier;
    }

    public async Task<Result<IEnumerable<ConversationDto>>> GetConversationsAsync(
        int userId,
        CancellationToken cancellationToken = default)
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
                .ToListAsync(cancellationToken);

            conversations = conversations
                .Where(c => !IsConversationDeletedForUser(c, userId))
                .ToList();

            var peerIds = conversations
                .Select(c => GetPeerId(c, userId))
                .Distinct()
                .ToList();

            var blockPairs = await _context.UserBlocks
                .AsNoTracking()
                .Where(x =>
                    (x.BlockerId == userId && peerIds.Contains(x.BlockedUserId)) ||
                    (x.BlockedUserId == userId && peerIds.Contains(x.BlockerId)))
                .Select(x => new { x.BlockerId, x.BlockedUserId })
                .ToListAsync(cancellationToken);

            var blockedByViewer = blockPairs
                .Where(x => x.BlockerId == userId)
                .Select(x => x.BlockedUserId)
                .ToHashSet();

            var blockedViewer = blockPairs
                .Where(x => x.BlockedUserId == userId)
                .Select(x => x.BlockerId)
                .ToHashSet();

            var result = conversations
                .Select(conversation =>
                {
                    var peer = GetPeer(conversation, userId);
                    var pinOrder = GetPinOrder(conversation, userId);
                    var visibleMessages = conversation.Messages
                        .Where(message => !IsMessageDeletedForUser(conversation, userId, message))
                        .OrderByDescending(message => message.CreatedAt)
                        .ToList();

                    var lastMessage = visibleMessages.FirstOrDefault();
                    var readAt = GetReadAt(conversation, userId);
                    var unreadCount = conversation.Messages.Count(message =>
                        message.SenderId != userId &&
                        !IsMessageDeletedForUser(conversation, userId, message) &&
                        (!readAt.HasValue || message.CreatedAt > readAt.Value));

                    var dto = new ConversationDto(
                        conversation.Id,
                        peer.Id,
                        peer.Username,
                        peer.AvatarUrl,
                        peer.AvatarScale,
                        peer.AvatarOffsetX,
                        peer.AvatarOffsetY,
                        peer.LastSeenAt,
                        peer.LastSeenAt >= DateTime.UtcNow.AddMinutes(-5),
                        pinOrder,
                        pinOrder.HasValue,
                        GetArchived(conversation, userId),
                        GetFavorite(conversation, userId),
                        GetMuted(conversation, userId),
                        blockedByViewer.Contains(peer.Id),
                        blockedViewer.Contains(peer.Id),
                        lastMessage != null ? BuildMessagePreview(lastMessage) : null,
                        lastMessage?.CreatedAt,
                        unreadCount);

                    return new
                    {
                        Dto = dto,
                        SortAt = lastMessage?.CreatedAt ?? conversation.UpdatedAt
                    };
                })
                .OrderByDescending(x => x.Dto.IsPinned)
                .ThenBy(x => x.Dto.PinOrder ?? int.MaxValue)
                .ThenByDescending(x => x.SortAt)
                .Select(x => x.Dto)
                .ToList();

            return Result<IEnumerable<ConversationDto>>.Success(result);
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<ConversationDto>>.Failure(
                $"Ошибка получения диалогов: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result<DirectConversationDto>> GetOrCreateDirectConversationAsync(
        int userId,
        int peerUserId,
        CancellationToken cancellationToken = default)
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
                return Result<DirectConversationDto>.Failure(
                    "Личные сообщения доступны только друзьям",
                    ResultError.Forbidden);
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
            else if (IsConversationDeletedForUser(conversation, userId))
            {
                SetConversationDeletedForUser(conversation, userId, false);
                SetArchived(conversation, userId, false);
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
            return Result<DirectConversationDto>.Failure(
                $"Ошибка открытия диалога: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result<MessagePageDto>> GetMessagesAsync(
        int userId,
        int conversationId,
        int limit,
        int? beforeMessageId,
        CancellationToken cancellationToken)
    {
        try
        {
            limit = Math.Clamp(limit, 1, 50);

            var conversation = await _context.Conversations
                .Include(c => c.UserA)
                .Include(c => c.UserB)
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result<MessagePageDto>.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result<MessagePageDto>.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            var peerId = GetPeerId(conversation, userId);
            var previousReadAt = GetReadAt(conversation, userId);

            var messagesQuery = _context.Messages
                .AsNoTracking()
                .Include(m => m.Sender)
                .Include(m => m.Attachments)
                .Include(m => m.ReplyToMessage)
                    .ThenInclude(m => m!.Sender)
                .Include(m => m.ReplyToMessage)
                    .ThenInclude(m => m!.Attachments)
                .Where(m => m.ConversationId == conversationId);

            messagesQuery = conversation.UserAId == userId
                ? messagesQuery.Where(m => !m.DeletedForUserA)
                : messagesQuery.Where(m => !m.DeletedForUserB);

            if (beforeMessageId.HasValue)
            {
                messagesQuery = messagesQuery.Where(m => m.Id < beforeMessageId.Value);
            }

            var messages = await messagesQuery
                .OrderByDescending(m => m.Id)
                .Take(limit + 1)
                .ToListAsync(cancellationToken);

            if (!beforeMessageId.HasValue)
            {
                var deliveredAt = DateTime.UtcNow;
                var hasUnreadIncomingMessages = await _context.Messages
                    .AsNoTracking()
                    .AnyAsync(m =>
                        m.ConversationId == conversationId &&
                        m.SenderId != userId &&
                        (conversation.UserAId == userId ? !m.DeletedForUserA : !m.DeletedForUserB) &&
                        (!previousReadAt.HasValue || m.CreatedAt > previousReadAt.Value),
                        cancellationToken);
                var pendingDeliveryMessages = await _context.Messages
                    .Where(m =>
                        m.ConversationId == conversationId &&
                        m.SenderId != userId &&
                        m.DeliveredToPeerAt == null &&
                        (conversation.UserAId == userId ? !m.DeletedForUserA : !m.DeletedForUserB))
                    .ToListAsync(cancellationToken);

                foreach (var pendingDeliveryMessage in pendingDeliveryMessages)
                {
                    pendingDeliveryMessage.DeliveredToPeerAt = deliveredAt;
                }

                if (hasUnreadIncomingMessages)
                {
                    MarkAsRead(conversation, userId);
                }

                if (hasUnreadIncomingMessages || pendingDeliveryMessages.Count > 0)
                {
                    await _context.SaveChangesAsync(cancellationToken);
                }

                var currentReadAt = GetReadAt(conversation, userId);
                if (hasUnreadIncomingMessages &&
                    currentReadAt != previousReadAt &&
                    currentReadAt.HasValue)
                {
                    await _chatRealtimeNotifier.NotifyMessageReadAsync(
                        peerId,
                        new MessageReadEventDto(conversationId, userId, currentReadAt.Value),
                        cancellationToken);
                }
            }

            var hasMore = messages.Count > limit;
            var pageMessages = messages.Take(limit).ToList();
            var peerReadAt = GetReadAt(conversation, peerId);
            var visibleMessages = pageMessages
                .Select(message => MapToDto(message, conversation, userId, peerReadAt))
                .ToList();

            return Result<MessagePageDto>.Success(new MessagePageDto(
                visibleMessages,
                hasMore,
                visibleMessages.LastOrDefault()?.Id));
        }
        catch (Exception ex)
        {
            return Result<MessagePageDto>.Failure(
                $"Ошибка получения сообщений: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result<ConversationRealtimeContextDto>> GetRealtimeContextAsync(
        int userId,
        int conversationId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .Include(c => c.UserA)
                .Include(c => c.UserB)
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result<ConversationRealtimeContextDto>.Failure("Р”РёР°Р»РѕРі РЅРµ РЅР°Р№РґРµРЅ", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result<ConversationRealtimeContextDto>.Failure("РќРµС‚ РґРѕСЃС‚СѓРїР° Рє РґРёР°Р»РѕРіСѓ", ResultError.Forbidden);
            }

            var peerId = GetPeerId(conversation, userId);
            var blockStatus = await _blockService.GetStatusAsync(userId, peerId, cancellationToken);

            return Result<ConversationRealtimeContextDto>.Success(
                new ConversationRealtimeContextDto(
                    conversation.Id,
                    peerId,
                    blockStatus.IsBlockedByViewer,
                    blockStatus.HasBlockedViewer));
        }
        catch (Exception ex)
        {
            return Result<ConversationRealtimeContextDto>.Failure(
                $"РћС€РёР±РєР° realtime-РєРѕРЅС‚РµРєСЃС‚Р° РґРёР°Р»РѕРіР°: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<IReadOnlyCollection<PendingMessageDeliveryDto>> MarkPendingMessagesDeliveredAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;

        var messages = await _context.Messages
            .Include(m => m.Conversation)
            .Where(m =>
                m.SenderId != userId &&
                m.DeliveredToPeerAt == null &&
                (
                    (m.Conversation.UserAId == userId && !m.DeletedForUserA) ||
                    (m.Conversation.UserBId == userId && !m.DeletedForUserB)
                ))
            .ToListAsync(cancellationToken);

        if (messages.Count == 0)
        {
            return [];
        }

        foreach (var message in messages)
        {
            message.DeliveredToPeerAt = now;
        }

        await _context.SaveChangesAsync(cancellationToken);

        return messages
            .Select(message => new PendingMessageDeliveryDto(
                message.ConversationId,
                message.Id,
                message.SenderId,
                now))
            .ToList();
    }

    public async Task<Result<MessageDto>> SendMessageAsync(
        int userId,
        int conversationId,
        CreateMessageDto dto,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var content = dto.Content?.Trim() ?? string.Empty;
            var attachments = dto.Attachments?.ToList() ?? [];

            if (string.IsNullOrWhiteSpace(content) && attachments.Count == 0)
            {
                return Result<MessageDto>.Failure(
                    "Сообщение должно содержать текст или вложения",
                    ResultError.ValidationError);
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

            var peerId = GetPeerId(conversation, userId);
            if (await _blockService.AreUsersBlockedAsync(userId, peerId, cancellationToken))
            {
                return Result<MessageDto>.Failure(
                    "Отправка сообщений недоступна для этого пользователя",
                    ResultError.Forbidden);
            }

            Message? replyToMessage = null;
            if (dto.ReplyToMessageId.HasValue)
            {
                replyToMessage = await _context.Messages
                    .AsNoTracking()
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
                DeliveredToPeerAt = _chatConnectionTracker.IsUserConnected(peerId)
                    ? DateTime.UtcNow
                    : null,
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
            SetConversationDeletedForUser(conversation, conversation.UserAId, false);
            SetConversationDeletedForUser(conversation, conversation.UserBId, false);
            MarkAsRead(conversation, userId);

            await _context.SaveChangesAsync(cancellationToken);

            message.Sender = conversation.UserAId == userId ? conversation.UserA : conversation.UserB;
            message.ReplyToMessage = replyToMessage;

            var senderDto = MapToDto(
                message,
                conversation,
                userId,
                GetReadAt(conversation, peerId));
            var recipientDto = MapToDto(
                message,
                conversation,
                peerId,
                GetReadAt(conversation, userId));

            await _chatRealtimeNotifier.NotifyMessageSentAsync(peerId, recipientDto, cancellationToken);

            if (senderDto.IsDeliveredToPeer && senderDto.DeliveredToPeerAt.HasValue)
            {
                await _chatRealtimeNotifier.NotifyMessageDeliveredAsync(
                    userId,
                    new MessageDeliveredEventDto(
                        conversationId,
                        message.Id,
                        senderDto.DeliveredToPeerAt.Value),
                    cancellationToken);
            }

            return Result<MessageDto>.Success(senderDto);
        }
        catch (Exception ex)
        {
            return Result<MessageDto>.Failure(
                $"Ошибка отправки сообщения: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result<MessageDto>> UpdateMessageAsync(
        int userId,
        int conversationId,
        int messageId,
        UpdateMessageDto dto,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result<MessageDto>.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result<MessageDto>.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

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
            conversation.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync(cancellationToken);

            return Result<MessageDto>.Success(MapToDto(
                message,
                conversation,
                userId,
                GetReadAt(conversation, GetPeerId(conversation, userId))));
        }
        catch (Exception ex)
        {
            return Result<MessageDto>.Failure(
                $"Ошибка обновления сообщения: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result<DeleteMessageResultDto>> DeleteMessageAsync(
        int userId,
        int conversationId,
        int messageId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .Include(c => c.Messages)
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result<DeleteMessageResultDto>.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result<DeleteMessageResultDto>.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            var message = conversation.Messages.FirstOrDefault(m => m.Id == messageId);
            if (message == null)
            {
                return Result<DeleteMessageResultDto>.Failure("Сообщение не найдено", ResultError.NotFound);
            }

            if (!IsMessageDeletedForUser(conversation, userId, message))
            {
                SetMessageDeletedForUser(conversation, userId, message, true);
                await _context.SaveChangesAsync(cancellationToken);
            }

            return Result<DeleteMessageResultDto>.Success(new DeleteMessageResultDto([]));
        }
        catch (Exception ex)
        {
            return Result<DeleteMessageResultDto>.Failure(
                $"Ошибка удаления сообщения: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result<DeleteMessageResultDto>> DeleteMessageForAllAsync(
        int userId,
        int conversationId,
        int messageId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result<DeleteMessageResultDto>.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result<DeleteMessageResultDto>.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            var message = await _context.Messages
                .Include(m => m.Attachments)
                .FirstOrDefaultAsync(m => m.Id == messageId && m.ConversationId == conversationId, cancellationToken);

            if (message == null)
            {
                return Result<DeleteMessageResultDto>.Failure("Сообщение не найдено", ResultError.NotFound);
            }

            if (message.SenderId != userId)
            {
                return Result<DeleteMessageResultDto>.Failure(
                    "Нет прав для удаления сообщения у всех",
                    ResultError.Forbidden);
            }

            var attachmentUrls = message.Attachments
                .Select(a => a.FileUrl)
                .Where(url => !string.IsNullOrWhiteSpace(url))
                .Distinct()
                .ToList();

            _context.Messages.Remove(message);
            conversation.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync(cancellationToken);

            return Result<DeleteMessageResultDto>.Success(new DeleteMessageResultDto(attachmentUrls));
        }
        catch (Exception ex)
        {
            return Result<DeleteMessageResultDto>.Failure(
                $"Ошибка удаления сообщения: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result> TogglePinAsync(
        int userId,
        int conversationId,
        bool isPinned,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            if (isPinned)
            {
                if (GetPinOrder(conversation, userId).HasValue)
                {
                    return Result.Success();
                }

                int pinnedCount;
                int? maxPinOrder;
                if (conversation.UserAId == userId)
                {
                    pinnedCount = await _context.Conversations
                        .AsNoTracking()
                        .Where(c => c.UserAId == userId && !c.UserADeleted && c.UserAPinOrder.HasValue)
                        .CountAsync(cancellationToken);

                    maxPinOrder = await _context.Conversations
                        .AsNoTracking()
                        .Where(c => c.UserAId == userId && !c.UserADeleted && c.UserAPinOrder.HasValue)
                        .MaxAsync(c => (int?)c.UserAPinOrder, cancellationToken);
                }
                else
                {
                    pinnedCount = await _context.Conversations
                        .AsNoTracking()
                        .Where(c => c.UserBId == userId && !c.UserBDeleted && c.UserBPinOrder.HasValue)
                        .CountAsync(cancellationToken);

                    maxPinOrder = await _context.Conversations
                        .AsNoTracking()
                        .Where(c => c.UserBId == userId && !c.UserBDeleted && c.UserBPinOrder.HasValue)
                        .MaxAsync(c => (int?)c.UserBPinOrder, cancellationToken);
                }

                if (pinnedCount >= MaxPinnedChats)
                {
                    return Result.Failure(
                        $"Можно закрепить не более {MaxPinnedChats} чатов",
                        ResultError.BadRequest);
                }

                SetPinOrder(conversation, userId, (maxPinOrder ?? 0) + 1);
            }
            else
            {
                SetPinOrder(conversation, userId, null);
            }

            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure(
                $"Ошибка изменения закрепления диалога: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result> ToggleArchiveAsync(
        int userId,
        int conversationId,
        bool isArchived,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            SetArchived(conversation, userId, isArchived);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure(
                $"Ошибка изменения архивации диалога: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result> ToggleFavoriteAsync(
        int userId,
        int conversationId,
        bool isFavorite,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            SetFavorite(conversation, userId, isFavorite);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure(
                $"Ошибка изменения избранного диалога: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result> ToggleMuteAsync(
        int userId,
        int conversationId,
        bool isMuted,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            SetMuted(conversation, userId, isMuted);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure(
                $"Ошибка изменения режима уведомлений: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result<DeleteConversationResultDto>> DeleteConversationAsync(
        int userId,
        int conversationId,
        bool deleteForBoth,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .Include(c => c.Messages)
                    .ThenInclude(m => m.Attachments)
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result<DeleteConversationResultDto>.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result<DeleteConversationResultDto>.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            if (deleteForBoth)
            {
                var attachmentUrls = conversation.Messages
                    .SelectMany(message => message.Attachments)
                    .Select(attachment => attachment.FileUrl)
                    .Where(url => !string.IsNullOrWhiteSpace(url))
                    .Distinct()
                    .ToList();

                _context.Conversations.Remove(conversation);
                await _context.SaveChangesAsync(cancellationToken);

                return Result<DeleteConversationResultDto>.Success(new DeleteConversationResultDto(attachmentUrls));
            }

            SetConversationDeletedForUser(conversation, userId, true);
            SetPinOrder(conversation, userId, null);
            SetArchived(conversation, userId, false);
            SetFavorite(conversation, userId, false);

            foreach (var message in conversation.Messages)
            {
                SetMessageDeletedForUser(conversation, userId, message, true);
            }

            await _context.SaveChangesAsync(cancellationToken);
            return Result<DeleteConversationResultDto>.Success(new DeleteConversationResultDto([]));
        }
        catch (Exception ex)
        {
            return Result<DeleteConversationResultDto>.Failure(
                $"Ошибка удаления диалога: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result> ClearHistoryAsync(
        int userId,
        int conversationId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var conversation = await _context.Conversations
                .Include(c => c.Messages)
                .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

            if (conversation == null)
            {
                return Result.Failure("Диалог не найден", ResultError.NotFound);
            }

            if (!IsParticipant(conversation, userId))
            {
                return Result.Failure("Нет доступа к диалогу", ResultError.Forbidden);
            }

            foreach (var message in conversation.Messages)
            {
                SetMessageDeletedForUser(conversation, userId, message, true);
            }

            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure(
                $"Ошибка очистки истории: {ex.Message}",
                ResultError.InternalError);
        }
    }

    private static MessageDto MapToDto(
        Message message,
        Conversation conversation,
        int userId,
        DateTime? peerReadAt)
    {
        var isMine = message.SenderId == userId;
        var replyIsVisible = message.ReplyToMessage != null &&
            !IsMessageDeletedForUser(conversation, userId, message.ReplyToMessage);
        var isReadByPeer = isMine && peerReadAt.HasValue && message.CreatedAt <= peerReadAt.Value;
        var deliveredToPeerAt = isReadByPeer
            ? peerReadAt
            : message.DeliveredToPeerAt;
        var isDeliveredToPeer = isMine && deliveredToPeerAt.HasValue;

        return new MessageDto(
            message.Id,
            message.ConversationId,
            message.SenderId,
            message.Sender.Username,
            message.Content,
            message.CreatedAt,
            message.EditedAt,
            isMine,
            isDeliveredToPeer,
            deliveredToPeerAt,
            isReadByPeer,
            isReadByPeer ? peerReadAt : null,
            message.ReplyToMessageId,
            replyIsVisible ? message.ReplyToMessage?.Sender.Username : null,
            replyIsVisible ? BuildMessagePreview(message.ReplyToMessage!) : null,
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

    private static User GetPeer(Conversation conversation, int userId)
    {
        return conversation.UserAId == userId ? conversation.UserB : conversation.UserA;
    }

    private static int GetPeerId(Conversation conversation, int userId)
    {
        return conversation.UserAId == userId ? conversation.UserBId : conversation.UserAId;
    }

    private static DateTime? GetReadAt(Conversation conversation, int userId)
    {
        return conversation.UserAId == userId ? conversation.UserAReadAt : conversation.UserBReadAt;
    }

    private static bool IsConversationDeletedForUser(Conversation conversation, int userId)
    {
        return conversation.UserAId == userId ? conversation.UserADeleted : conversation.UserBDeleted;
    }

    private static void SetConversationDeletedForUser(Conversation conversation, int userId, bool isDeleted)
    {
        if (conversation.UserAId == userId)
        {
            conversation.UserADeleted = isDeleted;
        }
        else
        {
            conversation.UserBDeleted = isDeleted;
        }
    }

    private static bool IsMessageDeletedForUser(Conversation conversation, int userId, Message message)
    {
        return conversation.UserAId == userId ? message.DeletedForUserA : message.DeletedForUserB;
    }

    private static void SetMessageDeletedForUser(Conversation conversation, int userId, Message message, bool isDeleted)
    {
        if (conversation.UserAId == userId)
        {
            message.DeletedForUserA = isDeleted;
        }
        else
        {
            message.DeletedForUserB = isDeleted;
        }
    }

    private static int? GetPinOrder(Conversation conversation, int userId)
    {
        return conversation.UserAId == userId ? conversation.UserAPinOrder : conversation.UserBPinOrder;
    }

    private static void SetPinOrder(Conversation conversation, int userId, int? value)
    {
        if (conversation.UserAId == userId)
        {
            conversation.UserAPinOrder = value;
        }
        else
        {
            conversation.UserBPinOrder = value;
        }
    }

    private static bool GetArchived(Conversation conversation, int userId)
    {
        return conversation.UserAId == userId ? conversation.UserAArchived : conversation.UserBArchived;
    }

    private static void SetArchived(Conversation conversation, int userId, bool value)
    {
        if (conversation.UserAId == userId)
        {
            conversation.UserAArchived = value;
        }
        else
        {
            conversation.UserBArchived = value;
        }
    }

    private static bool GetFavorite(Conversation conversation, int userId)
    {
        return conversation.UserAId == userId ? conversation.UserAFavorite : conversation.UserBFavorite;
    }

    private static void SetFavorite(Conversation conversation, int userId, bool value)
    {
        if (conversation.UserAId == userId)
        {
            conversation.UserAFavorite = value;
        }
        else
        {
            conversation.UserBFavorite = value;
        }
    }

    private static bool GetMuted(Conversation conversation, int userId)
    {
        return conversation.UserAId == userId ? conversation.UserAMuted : conversation.UserBMuted;
    }

    private static void SetMuted(Conversation conversation, int userId, bool value)
    {
        if (conversation.UserAId == userId)
        {
            conversation.UserAMuted = value;
        }
        else
        {
            conversation.UserBMuted = value;
        }
    }
}

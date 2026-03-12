using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Hubs;

[Authorize]
public class ChatHub : Hub
{
    private readonly IChatConnectionTracker _connectionTracker;
    private readonly IConversationService _conversationService;
    private readonly IChatRealtimeNotifier _realtimeNotifier;

    public ChatHub(
        IChatConnectionTracker connectionTracker,
        IConversationService conversationService,
        IChatRealtimeNotifier realtimeNotifier)
    {
        _connectionTracker = connectionTracker;
        _conversationService = conversationService;
        _realtimeNotifier = realtimeNotifier;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        _connectionTracker.AddConnection(userId, Context.ConnectionId);

        var deliveredMessages = await _conversationService.MarkPendingMessagesDeliveredAsync(
            userId,
            Context.ConnectionAborted);

        foreach (var delivery in deliveredMessages)
        {
            await _realtimeNotifier.NotifyMessageDeliveredAsync(
                delivery.SenderUserId,
                new MessageDeliveredEventDto(
                    delivery.ConversationId,
                    delivery.MessageId,
                    delivery.DeliveredAt),
                Context.ConnectionAborted);
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        _connectionTracker.RemoveConnection(GetUserId(), Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }

    private int GetUserId() =>
        int.Parse(Context.User?.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new HubException("User ID not found"));
}

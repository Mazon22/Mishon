using Microsoft.AspNetCore.SignalR;
using Mishon.API.Hubs;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Realtime;

public class ChatRealtimeNotifier : IChatRealtimeNotifier
{
    private readonly IHubContext<ChatHub> _hubContext;

    public ChatRealtimeNotifier(IHubContext<ChatHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public Task NotifyTypingStartedAsync(
        int targetUserId,
        ChatTypingEventDto dto,
        CancellationToken cancellationToken = default)
    {
        return _hubContext.Clients.User(targetUserId.ToString())
            .SendAsync("typing_started", dto, cancellationToken);
    }

    public Task NotifyTypingStoppedAsync(
        int targetUserId,
        ChatTypingEventDto dto,
        CancellationToken cancellationToken = default)
    {
        return _hubContext.Clients.User(targetUserId.ToString())
            .SendAsync("typing_stopped", dto, cancellationToken);
    }

    public Task NotifyMessageSentAsync(
        int targetUserId,
        MessageDto dto,
        CancellationToken cancellationToken = default)
    {
        return _hubContext.Clients.User(targetUserId.ToString())
            .SendAsync("message_sent", dto, cancellationToken);
    }

    public Task NotifyMessageReadAsync(
        int targetUserId,
        MessageReadEventDto dto,
        CancellationToken cancellationToken = default)
    {
        return _hubContext.Clients.User(targetUserId.ToString())
            .SendAsync("message_read", dto, cancellationToken);
    }

    public Task NotifyMessageDeliveredAsync(
        int targetUserId,
        MessageDeliveredEventDto dto,
        CancellationToken cancellationToken = default)
    {
        return _hubContext.Clients.User(targetUserId.ToString())
            .SendAsync("message_delivered", dto, cancellationToken);
    }
}

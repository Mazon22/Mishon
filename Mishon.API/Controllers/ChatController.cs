using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Controllers;

[Authorize]
[ApiController]
[Route("api/chat")]
public class ChatController : ControllerBase
{
    private readonly IConversationService _conversationService;
    private readonly IBlockService _blockService;
    private readonly IChatRealtimeNotifier _chatRealtimeNotifier;

    public ChatController(
        IConversationService conversationService,
        IBlockService blockService,
        IChatRealtimeNotifier chatRealtimeNotifier)
    {
        _conversationService = conversationService;
        _blockService = blockService;
        _chatRealtimeNotifier = chatRealtimeNotifier;
    }

    [HttpPost("pin")]
    public async Task<ActionResult> TogglePin([FromBody] ToggleConversationPinDto dto, CancellationToken cancellationToken)
    {
        return FromResult(await _conversationService.TogglePinAsync(
            GetUserId(),
            dto.ConversationId,
            dto.IsPinned,
            cancellationToken));
    }

    [HttpPost("archive")]
    public async Task<ActionResult> ToggleArchive([FromBody] ToggleConversationArchiveDto dto, CancellationToken cancellationToken)
    {
        return FromResult(await _conversationService.ToggleArchiveAsync(
            GetUserId(),
            dto.ConversationId,
            dto.IsArchived,
            cancellationToken));
    }

    [HttpPost("favorite")]
    public async Task<ActionResult> ToggleFavorite([FromBody] ToggleConversationFavoriteDto dto, CancellationToken cancellationToken)
    {
        return FromResult(await _conversationService.ToggleFavoriteAsync(
            GetUserId(),
            dto.ConversationId,
            dto.IsFavorite,
            cancellationToken));
    }

    [HttpPost("mute")]
    public async Task<ActionResult> ToggleMute([FromBody] ToggleConversationMuteDto dto, CancellationToken cancellationToken)
    {
        return FromResult(await _conversationService.ToggleMuteAsync(
            GetUserId(),
            dto.ConversationId,
            dto.IsMuted,
            cancellationToken));
    }

    [HttpDelete]
    public async Task<ActionResult> DeleteConversation([FromBody] DeleteConversationDto dto, CancellationToken cancellationToken)
    {
        var result = await _conversationService.DeleteConversationAsync(
            GetUserId(),
            dto.ConversationId,
            dto.DeleteForBoth,
            cancellationToken);

        if (result.IsSuccess)
        {
            DeleteUploadedFiles(result.Data?.AttachmentUrls ?? []);
            return NoContent();
        }

        return FromFailure(result.Error, result.ResultError);
    }

    [HttpPost("clear-history")]
    public async Task<ActionResult> ClearHistory([FromBody] ClearConversationHistoryDto dto, CancellationToken cancellationToken)
    {
        return FromResult(await _conversationService.ClearHistoryAsync(
            GetUserId(),
            dto.ConversationId,
            cancellationToken));
    }

    [HttpPost("block-user")]
    public async Task<ActionResult> BlockUser([FromBody] ToggleUserBlockDto dto, CancellationToken cancellationToken)
    {
        return FromResult(await _blockService.BlockUserAsync(GetUserId(), dto.UserId, cancellationToken));
    }

    [HttpPost("unblock-user")]
    public async Task<ActionResult> UnblockUser([FromBody] ToggleUserBlockDto dto, CancellationToken cancellationToken)
    {
        return FromResult(await _blockService.UnblockUserAsync(GetUserId(), dto.UserId, cancellationToken));
    }

    [HttpPost("typing-start")]
    public async Task<ActionResult> TypingStart([FromBody] TypingIndicatorDto dto, CancellationToken cancellationToken)
    {
        var contextResult = await _conversationService.GetRealtimeContextAsync(
            GetUserId(),
            dto.ConversationId,
            cancellationToken);

        if (!contextResult.IsSuccess)
        {
            return FromFailure(contextResult.Error, contextResult.ResultError);
        }

        var conversationContext = contextResult.Data!;
        if (conversationContext.IsBlockedByViewer || conversationContext.HasBlockedViewer)
        {
            return NoContent();
        }

        await _chatRealtimeNotifier.NotifyTypingStartedAsync(
            conversationContext.PeerUserId,
            new ChatTypingEventDto(dto.ConversationId, GetUserId(), DateTime.UtcNow),
            cancellationToken);

        return NoContent();
    }

    [HttpPost("typing-stop")]
    public async Task<ActionResult> TypingStop([FromBody] TypingIndicatorDto dto, CancellationToken cancellationToken)
    {
        var contextResult = await _conversationService.GetRealtimeContextAsync(
            GetUserId(),
            dto.ConversationId,
            cancellationToken);

        if (!contextResult.IsSuccess)
        {
            return FromFailure(contextResult.Error, contextResult.ResultError);
        }

        var conversationContext = contextResult.Data!;
        if (conversationContext.IsBlockedByViewer || conversationContext.HasBlockedViewer)
        {
            return NoContent();
        }

        await _chatRealtimeNotifier.NotifyTypingStoppedAsync(
            conversationContext.PeerUserId,
            new ChatTypingEventDto(dto.ConversationId, GetUserId(), DateTime.UtcNow),
            cancellationToken);

        return NoContent();
    }

    private ActionResult FromResult(Result result)
    {
        if (result.IsSuccess)
        {
            return NoContent();
        }

        return FromFailure(result.Error, result.ResultError);
    }

    private ActionResult FromFailure(string? error, ResultError? resultError)
    {
        return resultError switch
        {
            ResultError.BadRequest => BadRequest(new { error }),
            ResultError.ValidationError => BadRequest(new { error }),
            ResultError.NotFound => NotFound(new { error }),
            ResultError.Forbidden => StatusCode(403, new { error }),
            _ => StatusCode(500, new { error })
        };
    }

    private int GetUserId() =>
        int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new UnauthorizedAccessException("User ID not found"));

    private static void DeleteUploadedFiles(IEnumerable<string> urls)
    {
        foreach (var url in urls)
        {
            if (string.IsNullOrWhiteSpace(url) || !Uri.TryCreate(url, UriKind.Absolute, out var uri))
            {
                continue;
            }

            var relativePath = uri.LocalPath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
            if (!relativePath.StartsWith($"uploads{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var fullPath = Path.Combine(Directory.GetCurrentDirectory(), relativePath);
            if (System.IO.File.Exists(fullPath))
            {
                System.IO.File.Delete(fullPath);
            }
        }
    }
}

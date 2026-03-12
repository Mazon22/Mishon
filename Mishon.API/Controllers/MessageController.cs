using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Controllers;

[Authorize]
[ApiController]
[Route("api/message")]
public class MessageController : ControllerBase
{
    private readonly IConversationService _conversationService;

    public MessageController(IConversationService conversationService)
    {
        _conversationService = conversationService;
    }

    [HttpPost("delete-for-all")]
    public async Task<ActionResult> DeleteForAll([FromBody] DeleteMessageForAllDto dto, CancellationToken cancellationToken)
    {
        var result = await _conversationService.DeleteMessageForAllAsync(
            GetUserId(),
            dto.ConversationId,
            dto.MessageId,
            cancellationToken);

        if (result.IsSuccess)
        {
            DeleteUploadedFiles(result.Data?.AttachmentUrls ?? []);
            return NoContent();
        }

        return result.ResultError switch
        {
            ResultError.BadRequest => BadRequest(new { error = result.Error }),
            ResultError.ValidationError => BadRequest(new { error = result.Error }),
            ResultError.NotFound => NotFound(new { error = result.Error }),
            ResultError.Forbidden => StatusCode(403, new { error = result.Error }),
            _ => StatusCode(500, new { error = result.Error })
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

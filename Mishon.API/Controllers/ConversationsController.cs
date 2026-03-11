using System.Security.Claims;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ConversationsController : ControllerBase
{
    private static readonly string[] ImageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".heic", ".heif", ".ico"];
    private const long MaxMessageAttachmentsBytes = 15 * 1024 * 1024;

    private readonly IConversationService _conversationService;
    private readonly IValidator<CreateMessageDto> _messageValidator;
    private readonly IValidator<UpdateMessageDto> _updateMessageValidator;

    public ConversationsController(
        IConversationService conversationService,
        IValidator<CreateMessageDto> messageValidator,
        IValidator<UpdateMessageDto> updateMessageValidator)
    {
        _conversationService = conversationService;
        _messageValidator = messageValidator;
        _updateMessageValidator = updateMessageValidator;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<ConversationDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<ConversationDto>>> GetConversations(CancellationToken cancellationToken)
    {
        return FromDataResult(await _conversationService.GetConversationsAsync(GetUserId(), cancellationToken));
    }

    [HttpPost("direct/{userId:int}")]
    [ProducesResponseType(typeof(DirectConversationDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<DirectConversationDto>> GetOrCreateDirectConversation(int userId, CancellationToken cancellationToken)
    {
        return FromDataResult(await _conversationService.GetOrCreateDirectConversationAsync(GetUserId(), userId, cancellationToken));
    }

    [HttpGet("{conversationId:int}/messages")]
    [ProducesResponseType(typeof(IEnumerable<MessageDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<MessageDto>>> GetMessages(int conversationId, CancellationToken cancellationToken)
    {
        return FromDataResult(await _conversationService.GetMessagesAsync(GetUserId(), conversationId, cancellationToken));
    }

    [HttpPost("{conversationId:int}/messages")]
    [RequestSizeLimit(20 * 1024 * 1024)]
    [ProducesResponseType(typeof(MessageDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<MessageDto>> SendMessage(
        int conversationId,
        [FromForm] string? content,
        [FromForm] int? replyToMessageId,
        [FromForm] List<IFormFile>? files,
        [FromForm] List<string>? attachmentKinds,
        CancellationToken cancellationToken)
    {
        var fileList = files?.Where(file => file.Length > 0).ToList() ?? [];
        var totalBytes = fileList.Sum(file => file.Length);
        if (totalBytes > MaxMessageAttachmentsBytes)
        {
            return BadRequest(new
            {
                error = "Validation Error",
                message = "Суммарный размер вложений не должен превышать 15 МБ"
            });
        }

        var savedFilePaths = new List<string>();

        try
        {
            var attachments = new List<CreateMessageAttachmentDto>(fileList.Count);
            for (var index = 0; index < fileList.Count; index++)
            {
                var file = fileList[index];
                var savedAttachment = await SaveAttachmentAsync(file, cancellationToken);
                savedFilePaths.Add(savedAttachment.SavedFilePath);
                var detectedImage = IsImage(file.FileName);
                var requestedKind = attachmentKinds != null && index < attachmentKinds.Count
                    ? attachmentKinds[index]
                    : null;
                var displayAsImage = requestedKind == null
                    ? detectedImage
                    : string.Equals(requestedKind, "image", StringComparison.OrdinalIgnoreCase)
                        && (detectedImage || (!string.IsNullOrWhiteSpace(file.ContentType) && file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)));
                attachments.Add(new CreateMessageAttachmentDto(
                    file.FileName,
                    savedAttachment.PublicUrl,
                    string.IsNullOrWhiteSpace(file.ContentType) ? "application/octet-stream" : file.ContentType,
                    file.Length,
                    displayAsImage));
            }

            var dto = new CreateMessageDto(content, replyToMessageId, attachments);
            var validationResult = await _messageValidator.ValidateAsync(dto, cancellationToken);
            if (!validationResult.IsValid)
            {
                DeleteLocalFiles(savedFilePaths);
                return BadRequest(new
                {
                    error = "Validation Error",
                    message = validationResult.Errors.FirstOrDefault()?.ErrorMessage
                });
            }

            var result = await _conversationService.SendMessageAsync(GetUserId(), conversationId, dto, cancellationToken);
            if (!result.IsSuccess)
            {
                DeleteLocalFiles(savedFilePaths);
            }

            return FromDataResult(result);
        }
        catch
        {
            DeleteLocalFiles(savedFilePaths);
            throw;
        }
    }

    [HttpPut("{conversationId:int}/messages/{messageId:int}")]
    [ProducesResponseType(typeof(MessageDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<MessageDto>> UpdateMessage(
        int conversationId,
        int messageId,
        [FromBody] UpdateMessageDto dto,
        CancellationToken cancellationToken)
    {
        var validationResult = await _updateMessageValidator.ValidateAsync(dto, cancellationToken);
        if (!validationResult.IsValid)
        {
            return BadRequest(new
            {
                error = "Validation Error",
                message = validationResult.Errors.FirstOrDefault()?.ErrorMessage
            });
        }

        return FromDataResult(await _conversationService.UpdateMessageAsync(
            GetUserId(),
            conversationId,
            messageId,
            dto,
            cancellationToken));
    }

    [HttpDelete("{conversationId:int}/messages/{messageId:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> DeleteMessage(int conversationId, int messageId, CancellationToken cancellationToken)
    {
        var result = await _conversationService.DeleteMessageAsync(GetUserId(), conversationId, messageId, cancellationToken);
        if (result.IsSuccess)
        {
            DeleteUploadedFiles(result.Data?.AttachmentUrls ?? []);
            return NoContent();
        }

        return result.ResultError switch
        {
            ResultError.NotFound => NotFound(new { error = result.Error }),
            ResultError.Forbidden => StatusCode(403, new { error = result.Error }),
            _ => StatusCode(500, new { error = result.Error })
        };
    }

    private ActionResult<T> FromDataResult<T>(Result<T> result)
    {
        if (result.IsSuccess)
        {
            return Ok(result.Data);
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

    private async Task<(string SavedFilePath, string PublicUrl)> SaveAttachmentAsync(IFormFile file, CancellationToken cancellationToken)
    {
        var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "uploads", "messages");
        Directory.CreateDirectory(uploadsFolder);

        var extension = Path.GetExtension(file.FileName);
        var uniqueFileName = $"{Guid.NewGuid()}{extension}";
        var savedFilePath = Path.Combine(uploadsFolder, uniqueFileName);

        await using (var stream = new FileStream(savedFilePath, FileMode.Create))
        {
            await file.CopyToAsync(stream, cancellationToken);
        }

        var request = HttpContext.Request;
        return (savedFilePath, $"{request.Scheme}://{request.Host}/uploads/messages/{uniqueFileName}");
    }

    private static bool IsImage(string fileName)
    {
        var extension = Path.GetExtension(fileName).ToLowerInvariant();
        return ImageExtensions.Contains(extension);
    }

    private static void DeleteLocalFiles(IEnumerable<string> paths)
    {
        foreach (var path in paths)
        {
            if (System.IO.File.Exists(path))
            {
                System.IO.File.Delete(path);
            }
        }
    }

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

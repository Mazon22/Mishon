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
    private readonly IConversationService _conversationService;
    private readonly IValidator<CreateMessageDto> _messageValidator;

    public ConversationsController(IConversationService conversationService, IValidator<CreateMessageDto> messageValidator)
    {
        _conversationService = conversationService;
        _messageValidator = messageValidator;
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
    [ProducesResponseType(typeof(MessageDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<MessageDto>> SendMessage(
        int conversationId,
        [FromBody] CreateMessageDto dto,
        CancellationToken cancellationToken)
    {
        var validationResult = await _messageValidator.ValidateAsync(dto, cancellationToken);
        if (!validationResult.IsValid)
        {
            return BadRequest(new
            {
                error = "Validation Error",
                message = validationResult.Errors.FirstOrDefault()?.ErrorMessage
            });
        }

        return FromDataResult(await _conversationService.SendMessageAsync(GetUserId(), conversationId, dto, cancellationToken));
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
}

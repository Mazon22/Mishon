using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _notificationService;

    public NotificationsController(INotificationService notificationService)
    {
        _notificationService = notificationService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<NotificationDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<NotificationDto>>> GetNotifications(CancellationToken cancellationToken)
    {
        return FromDataResult(await _notificationService.GetNotificationsAsync(GetUserId(), cancellationToken));
    }

    [HttpGet("summary")]
    [ProducesResponseType(typeof(NotificationSummaryDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<NotificationSummaryDto>> GetSummary(CancellationToken cancellationToken)
    {
        return FromDataResult(await _notificationService.GetSummaryAsync(GetUserId(), cancellationToken));
    }

    [HttpPost("{notificationId:int}/read")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> MarkAsRead(int notificationId, CancellationToken cancellationToken)
    {
        var result = await _notificationService.MarkAsReadAsync(GetUserId(), notificationId, cancellationToken);
        return FromResult(result);
    }

    [HttpPost("read-all")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> MarkAllAsRead(CancellationToken cancellationToken)
    {
        var result = await _notificationService.MarkAllAsReadAsync(GetUserId(), cancellationToken);
        return FromResult(result);
    }

    private ActionResult<T> FromDataResult<T>(Result<T> result)
    {
        if (result.IsSuccess)
        {
            return Ok(result.Data);
        }

        return result.ResultError switch
        {
            ResultError.NotFound => NotFound(new { error = result.Error }),
            ResultError.Forbidden => StatusCode(403, new { error = result.Error }),
            _ => StatusCode(500, new { error = result.Error })
        };
    }

    private ActionResult FromResult(Result result)
    {
        if (result.IsSuccess)
        {
            return NoContent();
        }

        return result.ResultError switch
        {
            ResultError.NotFound => NotFound(new { error = result.Error }),
            ResultError.Forbidden => StatusCode(403, new { error = result.Error }),
            _ => StatusCode(500, new { error = result.Error })
        };
    }

    private int GetUserId() =>
        int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new UnauthorizedAccessException("User ID not found"));
}

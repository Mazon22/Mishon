using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class FriendsController : ControllerBase
{
    private readonly IFriendService _friendService;

    public FriendsController(IFriendService friendService)
    {
        _friendService = friendService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<FriendDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<FriendDto>>> GetFriends(CancellationToken cancellationToken)
    {
        var result = await _friendService.GetFriendsAsync(GetUserId(), cancellationToken);
        return FromListResult(result);
    }

    [HttpGet("requests/incoming")]
    [ProducesResponseType(typeof(IEnumerable<FriendRequestDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<FriendRequestDto>>> GetIncomingRequests(CancellationToken cancellationToken)
    {
        var result = await _friendService.GetIncomingRequestsAsync(GetUserId(), cancellationToken);
        return FromListResult(result);
    }

    [HttpGet("requests/outgoing")]
    [ProducesResponseType(typeof(IEnumerable<FriendRequestDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<FriendRequestDto>>> GetOutgoingRequests(CancellationToken cancellationToken)
    {
        var result = await _friendService.GetOutgoingRequestsAsync(GetUserId(), cancellationToken);
        return FromListResult(result);
    }

    [HttpPost("requests/{userId:int}")]
    public async Task<IActionResult> SendRequest(int userId, CancellationToken cancellationToken)
    {
        return FromResult(await _friendService.SendRequestAsync(GetUserId(), userId, cancellationToken));
    }

    [HttpPost("requests/{requestId:int}/accept")]
    public async Task<IActionResult> AcceptRequest(int requestId, CancellationToken cancellationToken)
    {
        return FromResult(await _friendService.AcceptRequestAsync(GetUserId(), requestId, cancellationToken));
    }

    [HttpDelete("requests/{requestId:int}")]
    public async Task<IActionResult> DeleteRequest(int requestId, CancellationToken cancellationToken)
    {
        return FromResult(await _friendService.DeleteRequestAsync(GetUserId(), requestId, cancellationToken));
    }

    [HttpDelete("{friendId:int}")]
    public async Task<IActionResult> RemoveFriend(int friendId, CancellationToken cancellationToken)
    {
        return FromResult(await _friendService.RemoveFriendAsync(GetUserId(), friendId, cancellationToken));
    }

    private ActionResult<T> FromListResult<T>(Result<T> result)
    {
        if (result.IsSuccess)
        {
            return Ok(result.Data);
        }

        return StatusCode(500, new { error = result.Error });
    }

    private IActionResult FromResult(Result result)
    {
        if (result.IsSuccess)
        {
            return NoContent();
        }

        return result.ResultError switch
        {
            ResultError.BadRequest => BadRequest(new { error = result.Error }),
            ResultError.NotFound => NotFound(new { error = result.Error }),
            ResultError.Conflict => Conflict(new { error = result.Error }),
            _ => StatusCode(500, new { error = result.Error })
        };
    }

    private int GetUserId() =>
        int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new UnauthorizedAccessException("User ID not found"));
}

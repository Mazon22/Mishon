using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class FollowsController : ControllerBase
{
    private readonly IFollowService _followService;

    public FollowsController(IFollowService followService)
    {
        _followService = followService;
    }

    [HttpPost("{userId:int}")]
    [ProducesResponseType(typeof(FollowDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<FollowDto>> ToggleFollow(int userId)
    {
        var currentUserId = GetUserId();
        var result = await _followService.ToggleFollowAsync(currentUserId, userId);
        
        if (!result.IsSuccess)
        {
            return result.ResultError switch
            {
                ResultError.NotFound => NotFound(new { error = result.Error }),
                ResultError.BadRequest => BadRequest(new { error = result.Error }),
                _ => StatusCode(500, new { error = result.Error })
            };
        }

        return Ok(result.Data);
    }

    [HttpGet("followings")]
    [ProducesResponseType(typeof(IEnumerable<FollowDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<FollowDto>>> GetFollowings()
    {
        var userId = GetUserId();
        var result = await _followService.GetFollowingsAsync(userId);
        
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [HttpGet("followers")]
    [ProducesResponseType(typeof(IEnumerable<FollowDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<FollowDto>>> GetFollowers()
    {
        var userId = GetUserId();
        var result = await _followService.GetFollowersAsync(userId);
        
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [HttpGet("check/{userId:int}")]
    [ProducesResponseType(typeof(bool), StatusCodes.Status200OK)]
    public async Task<ActionResult<bool>> IsFollowing(int userId)
    {
        var currentUserId = GetUserId();
        var result = await _followService.IsFollowingAsync(currentUserId, userId);
        
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    private int GetUserId() =>
        int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new UnauthorizedAccessException("User ID not found"));
}

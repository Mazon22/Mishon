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
    [ProducesResponseType(typeof(ToggleFollowResponseDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<ToggleFollowResponseDto>> ToggleFollow(int userId)
    {
        var result = await _followService.ToggleFollowAsync(GetUserId(), userId);
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

    [HttpGet("{userId:int}/following")]
    [ProducesResponseType(typeof(IEnumerable<UserFollowDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<UserFollowDto>>> GetFollowing(int userId)
    {
        var result = await _followService.GetFollowingsAsync(userId, GetUserId());
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [HttpGet("{userId:int}/followers")]
    [ProducesResponseType(typeof(IEnumerable<UserFollowDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<UserFollowDto>>> GetFollowers(int userId)
    {
        var result = await _followService.GetFollowersAsync(userId, GetUserId());
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [HttpGet("followings")]
    [ProducesResponseType(typeof(IEnumerable<UserFollowDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<UserFollowDto>>> GetMyFollowings()
    {
        var currentUserId = GetUserId();
        var result = await _followService.GetFollowingsAsync(currentUserId, currentUserId);
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [HttpGet("followers")]
    [ProducesResponseType(typeof(IEnumerable<UserFollowDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<UserFollowDto>>> GetMyFollowers()
    {
        var currentUserId = GetUserId();
        var result = await _followService.GetFollowersAsync(currentUserId, currentUserId);
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
        var result = await _followService.IsFollowingAsync(GetUserId(), userId);
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [HttpGet("{userId:int}/followers/count")]
    [ProducesResponseType(typeof(int), StatusCodes.Status200OK)]
    public async Task<ActionResult<int>> GetFollowersCount(int userId)
    {
        var result = await _followService.GetFollowersCountAsync(userId);
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    private int GetUserId() =>
        int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new UnauthorizedAccessException("User ID not found"));
}

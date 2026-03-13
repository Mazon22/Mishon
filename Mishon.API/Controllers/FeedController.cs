using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class FeedController : ControllerBase
{
    private readonly IFeedService _feedService;

    public FeedController(IFeedService feedService)
    {
        _feedService = feedService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<PostDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResult<PostDto>>> GetForYou(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        var result = await _feedService.GetForYouFeedAsync(GetUserId(), page, pageSize, cancellationToken);
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(ToPagedResponse(result.Data!));
    }

    [HttpGet("following")]
    [ProducesResponseType(typeof(PagedResult<PostDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResult<PostDto>>> GetFollowing(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        var result = await _feedService.GetFollowingFeedAsync(GetUserId(), page, pageSize, cancellationToken);
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(ToPagedResponse(result.Data!));
    }

    private static object ToPagedResponse(PagedResult<PostDto> result)
    {
        return new
        {
            items = result.Items,
            page = result.Page,
            pageSize = result.PageSize,
            totalCount = result.TotalCount,
            totalPages = result.TotalPages,
            hasPrevious = result.HasPrevious,
            hasNext = result.HasNext,
        };
    }

    private int GetUserId() =>
        int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new UnauthorizedAccessException("User ID not found"));
}

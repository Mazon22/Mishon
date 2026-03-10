using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IUserDiscoveryService _userDiscoveryService;

    public UsersController(IUserDiscoveryService userDiscoveryService)
    {
        _userDiscoveryService = userDiscoveryService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<DiscoverUserDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<DiscoverUserDto>>> GetUsers(
        [FromQuery] string? query,
        [FromQuery] int limit = 24,
        CancellationToken cancellationToken = default)
    {
        var result = await _userDiscoveryService.GetUsersAsync(GetUserId(), query, limit, cancellationToken);
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    private int GetUserId() =>
        int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new UnauthorizedAccessException("User ID not found"));
}

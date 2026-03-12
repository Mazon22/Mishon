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
public class PostsController : ControllerBase
{
    private readonly IPostService _postService;
    private readonly IValidator<CreatePostDto> _createPostValidator;

    public PostsController(IPostService postService, IValidator<CreatePostDto> createPostValidator)
    {
        _postService = postService;
        _createPostValidator = createPostValidator;
    }

    [HttpPost]
    [ProducesResponseType(typeof(PostDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<ActionResult<PostDto>> Create([FromForm] string content, [FromForm] IFormFile? image)
    {
        var validationResult = await _createPostValidator.ValidateAsync(new CreatePostDto(content, null));
        if (!validationResult.IsValid)
        {
            return BadRequest(new
            {
                error = "Validation Error",
                message = validationResult.Errors.FirstOrDefault()?.ErrorMessage,
                errors = validationResult.Errors.Select(e => new { e.PropertyName, e.ErrorMessage })
            });
        }

        string? imageUrl = null;
        string? savedFilePath = null;

        if (image != null && image.Length > 0)
        {
            if (image.Length > 5 * 1024 * 1024)
            {
                return BadRequest(new { error = "Размер файла не должен превышать 5MB" });
            }

            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
            var fileExtension = Path.GetExtension(image.FileName).ToLowerInvariant();
            if (!allowedExtensions.Contains(fileExtension))
            {
                return BadRequest(new { error = "Допустимы только JPG, JPEG, PNG, GIF и WEBP" });
            }

            var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "uploads");
            Directory.CreateDirectory(uploadsFolder);

            var uniqueFileName = $"{Guid.NewGuid()}{fileExtension}";
            savedFilePath = Path.Combine(uploadsFolder, uniqueFileName);

            await using (var stream = new FileStream(savedFilePath, FileMode.Create))
            {
                await image.CopyToAsync(stream);
            }

            var request = HttpContext.Request;
            imageUrl = $"{request.Scheme}://{request.Host}/uploads/{uniqueFileName}";
        }

        var result = await _postService.CreateAsync(GetUserId(), new CreatePostDto(content, imageUrl));
        if (!result.IsSuccess)
        {
            if (savedFilePath != null && System.IO.File.Exists(savedFilePath))
            {
                System.IO.File.Delete(savedFilePath);
            }

            return result.ResultError switch
            {
                ResultError.ValidationError => BadRequest(new { error = result.Error }),
                _ => StatusCode(500, new { error = result.Error })
            };
        }

        return CreatedAtAction(nameof(GetPost), new { id = result.Data!.Id }, result.Data);
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<PostDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResult<PostDto>>> GetFeed([FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await _postService.GetFeedAsync(GetUserId(), page, pageSize);
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(new
        {
            items = result.Data!.Items,
            page = result.Data.Page,
            pageSize = result.Data.PageSize,
            totalCount = result.Data.TotalCount,
            totalPages = result.Data.TotalPages,
            hasPrevious = result.Data.HasPrevious,
            hasNext = result.Data.HasNext
        });
    }

    [HttpGet("user/{userId:int}")]
    [ProducesResponseType(typeof(IEnumerable<PostDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<PostDto>>> GetUserPosts(
        int userId,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        var result = await _postService.GetUserPostsAsync(GetUserId(), userId, page, pageSize);
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(PostDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<PostDto>> GetPost(int id)
    {
        var result = await _postService.GetPostAsync(id, GetUserId());
        if (!result.IsSuccess)
        {
            return result.ResultError switch
            {
                ResultError.NotFound => NotFound(new { error = result.Error }),
                ResultError.Forbidden => StatusCode(403, new { error = result.Error }),
                _ => StatusCode(500, new { error = result.Error })
            };
        }

        return Ok(result.Data);
    }

    [HttpPost("{id:int}/like")]
    [ProducesResponseType(typeof(PostDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<PostDto>> ToggleLike(int id)
    {
        var result = await _postService.ToggleLikeAsync(GetUserId(), id);
        if (!result.IsSuccess)
        {
            return result.ResultError switch
            {
                ResultError.NotFound => NotFound(new { error = result.Error }),
                ResultError.Forbidden => StatusCode(403, new { error = result.Error }),
                _ => StatusCode(500, new { error = result.Error })
            };
        }

        return Ok(result.Data);
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var result = await _postService.DeleteAsync(GetUserId(), id, cancellationToken);
        if (!result.IsSuccess)
        {
            return result.ResultError switch
            {
                ResultError.NotFound => NotFound(new { error = result.Error }),
                ResultError.Forbidden => StatusCode(403, new { error = result.Error }),
                _ => StatusCode(500, new { error = result.Error })
            };
        }

        return NoContent();
    }

    private int GetUserId() =>
        int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new UnauthorizedAccessException("User ID not found"));
}

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
    [RequestSizeLimit(10 * 1024 * 1024)] // 10 MB limit
    public async Task<ActionResult<PostDto>> Create(
        [FromForm] string content,
        [FromForm] IFormFile? image)
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

        // Загрузка изображения, если есть
        string? imageUrl = null;
        if (image != null && image.Length > 0)
        {
            // Проверяем размер файла (максимум 5MB)
            if (image.Length > 5 * 1024 * 1024)
            {
                return BadRequest(new { error = "Размер файла не должен превышать 5MB" });
            }

            // Проверяем тип файла
            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
            var fileExtension = Path.GetExtension(image.FileName).ToLower();
            if (!allowedExtensions.Contains(fileExtension))
            {
                return BadRequest(new { error = "Недопустимый формат файла. Разрешены: JPG, JPEG, PNG, GIF, WEBP" });
            }

            // Создаём директорию для загрузок, если не существует
            var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "uploads");
            if (!Directory.Exists(uploadsFolder))
            {
                Directory.CreateDirectory(uploadsFolder);
            }

            // Генерируем уникальное имя файла
            var uniqueFileName = $"{Guid.NewGuid()}{fileExtension}";
            var filePath = Path.Combine(uploadsFolder, uniqueFileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await image.CopyToAsync(stream);
            }

            // Формируем полный URL для доступа к изображению
            var request = HttpContext.Request;
            imageUrl = $"{request.Scheme}://{request.Host}/uploads/{uniqueFileName}";
        }

        var userId = GetUserId();
        var dto = new CreatePostDto(content, imageUrl);
        var result = await _postService.CreateAsync(userId, dto);

        if (!result.IsSuccess)
        {
            // Если произошла ошибка, удаляем загруженный файл
            if (imageUrl != null)
            {
                var filePath = Path.Combine(Directory.GetCurrentDirectory(), imageUrl.TrimStart('/'));
                if (System.IO.File.Exists(filePath))
                {
                    System.IO.File.Delete(filePath);
                }
            }

            return result.ResultError switch
            {
                ResultError.ValidationError => BadRequest(new { error = result.Error }),
                _ => StatusCode(500, new { error = result.Error })
            };
        }

        return CreatedAtAction(nameof(GetFeed), new { page = 1, pageSize = 10 }, result.Data);
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<PostDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResult<PostDto>>> GetFeed([FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var userId = GetUserId();
        var result = await _postService.GetFeedAsync(userId, page, pageSize);
        
        if (!result.IsSuccess)
        {
            return StatusCode(500, new { error = result.Error });
        }

        return Ok(new
        {
            items = result.Data.Items,
            page = result.Data.Page,
            pageSize = result.Data.PageSize,
            totalCount = result.Data.TotalCount,
            totalPages = result.Data.TotalPages,
            hasPrevious = result.Data.HasPrevious,
            hasNext = result.Data.HasNext
        });
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(PostDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PostDto>> GetPost(int id)
    {
        var userId = GetUserId();
        var result = await _postService.GetPostAsync(id, userId);
        
        if (!result.IsSuccess)
        {
            return result.ResultError == ResultError.NotFound
                ? NotFound(new { error = result.Error })
                : StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [HttpPost("{id:int}/like")]
    [ProducesResponseType(typeof(PostDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PostDto>> ToggleLike(int id)
    {
        var userId = GetUserId();
        var result = await _postService.ToggleLikeAsync(userId, id);

        if (!result.IsSuccess)
        {
            return result.ResultError == ResultError.NotFound
                ? NotFound(new { error = result.Error })
                : StatusCode(500, new { error = result.Error });
        }

        return Ok(result.Data);
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var userId = GetUserId();
        var result = await _postService.DeleteAsync(userId, id, cancellationToken);

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

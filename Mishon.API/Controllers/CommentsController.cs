using System.Security.Claims;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;

namespace Mishon.API.Controllers;

[Authorize]
[ApiController]
[Route("api/posts/{postId}/[controller]")]
public class CommentsController : ControllerBase
{
    private readonly ICommentService _commentService;
    private readonly IValidator<CreateCommentDto> _createCommentValidator;
    private readonly IValidator<UpdateCommentDto> _updateCommentValidator;

    public CommentsController(
        ICommentService commentService,
        IValidator<CreateCommentDto> createCommentValidator,
        IValidator<UpdateCommentDto> updateCommentValidator)
    {
        _commentService = commentService;
        _createCommentValidator = createCommentValidator;
        _updateCommentValidator = updateCommentValidator;
    }

    /// <summary>
    /// Создать комментарий к посту
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(CommentDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<CommentDto>> Create(int postId, [FromBody] CreateCommentDto dto)
    {
        var validationResult = await _createCommentValidator.ValidateAsync(dto);
        if (!validationResult.IsValid)
        {
            return BadRequest(new
            {
                error = "Validation Error",
                message = validationResult.Errors.FirstOrDefault()?.ErrorMessage,
                errors = validationResult.Errors.Select(e => new { e.PropertyName, e.ErrorMessage })
            });
        }

        var userId = GetUserId();
        var result = await _commentService.CreateAsync(userId, postId, dto);

        if (!result.IsSuccess)
        {
            return result.ResultError switch
            {
                ResultError.NotFound => NotFound(new { error = result.Error }),
                ResultError.Forbidden => StatusCode(403, new { error = result.Error }),
                ResultError.ValidationError => BadRequest(new { error = result.Error }),
                _ => StatusCode(500, new { error = result.Error })
            };
        }

        return Ok(result.Data);
    }

    /// <summary>
    /// Получить все комментарии поста
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<CommentDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IEnumerable<CommentDto>>> GetByPostId(int postId)
    {
        var result = await _commentService.GetByPostIdAsync(GetUserId(), postId);

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

    [HttpPut("{commentId:int}")]
    [ProducesResponseType(typeof(CommentDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<CommentDto>> Update(int postId, int commentId, [FromBody] UpdateCommentDto dto)
    {
        var validationResult = await _updateCommentValidator.ValidateAsync(dto);
        if (!validationResult.IsValid)
        {
            return BadRequest(new
            {
                error = "Validation Error",
                message = validationResult.Errors.FirstOrDefault()?.ErrorMessage
            });
        }

        var result = await _commentService.UpdateAsync(GetUserId(), postId, commentId, dto);
        return FromResult(result);
    }

    [HttpDelete("{commentId:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> Delete(int postId, int commentId)
    {
        var result = await _commentService.DeleteAsync(GetUserId(), postId, commentId);
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

    private ActionResult<CommentDto> FromResult(Result<CommentDto> result)
    {
        if (result.IsSuccess)
        {
            return Ok(result.Data);
        }

        return result.ResultError switch
        {
            ResultError.NotFound => NotFound(new { error = result.Error }),
            ResultError.Forbidden => StatusCode(403, new { error = result.Error }),
            ResultError.ValidationError => BadRequest(new { error = result.Error }),
            _ => StatusCode(500, new { error = result.Error })
        };
    }

    private int GetUserId() =>
        int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new UnauthorizedAccessException("User ID not found"));
}

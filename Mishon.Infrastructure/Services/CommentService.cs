using Microsoft.EntityFrameworkCore;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class CommentService : ICommentService
{
    private readonly ICommentRepository _commentRepository;
    private readonly IPostRepository _postRepository;
    private readonly MishonDbContext _context;

    public CommentService(ICommentRepository commentRepository, IPostRepository postRepository, MishonDbContext context)
    {
        _commentRepository = commentRepository;
        _postRepository = postRepository;
        _context = context;
    }

    public async Task<Result<CommentDto>> CreateAsync(int userId, int postId, CreateCommentDto dto, CancellationToken cancellationToken = default)
    {
        try
        {
            // Проверяем, что пост существует
            var post = await _postRepository.GetByIdAsync(postId);
            if (post == null)
                return Result<CommentDto>.Failure("Пост не найден", ResultError.NotFound);

            var comment = new Comment
            {
                UserId = userId,
                PostId = postId,
                Content = dto.Content
            };

            await _commentRepository.CreateAsync(comment);

            // Загружаем данные пользователя через существующий контекст
            var commentWithUser = await _context.Comments
                .Include(c => c.User)
                .FirstOrDefaultAsync(c => c.Id == comment.Id, cancellationToken);
            
            if (commentWithUser == null)
                return Result<CommentDto>.Failure("Комментарий не найден после создания", ResultError.InternalError);

            return Result<CommentDto>.Success(MapToDto(commentWithUser));
        }
        catch (Exception ex)
        {
            return Result<CommentDto>.Failure($"Ошибка создания комментария: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<IEnumerable<CommentDto>>> GetByPostIdAsync(int postId, CancellationToken cancellationToken = default)
    {
        try
        {
            // Проверяем, что пост существует
            var post = await _postRepository.GetByIdAsync(postId);
            if (post == null)
                return Result<IEnumerable<CommentDto>>.Failure("Пост не найден", ResultError.NotFound);

            var comments = await _commentRepository.GetByPostIdAsync(postId);
            var commentDtos = comments.Select(MapToDto);

            return Result<IEnumerable<CommentDto>>.Success(commentDtos);
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<CommentDto>>.Failure($"Ошибка получения комментариев: {ex.Message}", ResultError.InternalError);
        }
    }

    private CommentDto MapToDto(Comment comment)
    {
        return new CommentDto(
            comment.Id,
            comment.UserId,
            comment.User.Username,
            comment.User.AvatarUrl,
            comment.Content,
            comment.CreatedAt
        );
    }
}

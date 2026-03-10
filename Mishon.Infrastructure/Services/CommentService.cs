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
    private readonly INotificationService _notificationService;

    public CommentService(
        ICommentRepository commentRepository,
        IPostRepository postRepository,
        MishonDbContext context,
        INotificationService notificationService)
    {
        _commentRepository = commentRepository;
        _postRepository = postRepository;
        _context = context;
        _notificationService = notificationService;
    }

    public async Task<Result<CommentDto>> CreateAsync(int userId, int postId, CreateCommentDto dto, CancellationToken cancellationToken = default)
    {
        try
        {
            var post = await _context.Posts
                .AsNoTracking()
                .Include(p => p.User)
                .FirstOrDefaultAsync(p => p.Id == postId, cancellationToken);

            if (post == null)
            {
                return Result<CommentDto>.Failure("Пост не найден", ResultError.NotFound);
            }

            Comment? parentComment = null;
            if (dto.ParentCommentId.HasValue)
            {
                parentComment = await _context.Comments
                    .AsNoTracking()
                    .Include(c => c.User)
                    .FirstOrDefaultAsync(c => c.Id == dto.ParentCommentId.Value, cancellationToken);

                if (parentComment == null || parentComment.PostId != postId)
                {
                    return Result<CommentDto>.Failure("Комментарий для ответа не найден", ResultError.NotFound);
                }
            }

            var comment = new Comment
            {
                UserId = userId,
                PostId = postId,
                Content = dto.Content.Trim(),
                ParentCommentId = parentComment?.Id
            };

            await _commentRepository.CreateAsync(comment);

            var commentWithUser = await _context.Comments
                .Include(c => c.User)
                .Include(c => c.ParentComment)
                    .ThenInclude(c => c!.User)
                .FirstOrDefaultAsync(c => c.Id == comment.Id, cancellationToken);

            if (commentWithUser == null)
            {
                return Result<CommentDto>.Failure("Комментарий не найден после создания", ResultError.InternalError);
            }

            if (parentComment != null)
            {
                await _notificationService.CreateAsync(new CreateNotificationDto(
                    parentComment.UserId,
                    userId,
                    NotificationTypes.CommentReply,
                    "ответил(а) на ваш комментарий",
                    postId,
                    comment.Id,
                    null,
                    null,
                    userId), cancellationToken);

                if (post.UserId != userId && post.UserId != parentComment.UserId)
                {
                    await _notificationService.CreateAsync(new CreateNotificationDto(
                        post.UserId,
                        userId,
                        NotificationTypes.PostComment,
                        "оставил(а) комментарий к вашему посту",
                        postId,
                        comment.Id,
                        null,
                        null,
                        userId), cancellationToken);
                }
            }
            else if (post.UserId != userId)
            {
                await _notificationService.CreateAsync(new CreateNotificationDto(
                    post.UserId,
                    userId,
                    NotificationTypes.PostComment,
                    "оставил(а) комментарий к вашему посту",
                    postId,
                    comment.Id,
                    null,
                    null,
                    userId), cancellationToken);
            }

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
            var post = await _postRepository.GetByIdAsync(postId);
            if (post == null)
            {
                return Result<IEnumerable<CommentDto>>.Failure("Пост не найден", ResultError.NotFound);
            }

            var comments = await _context.Comments
                .AsNoTracking()
                .Include(c => c.User)
                .Include(c => c.ParentComment)
                    .ThenInclude(c => c!.User)
                .Where(c => c.PostId == postId)
                .OrderBy(c => c.CreatedAt)
                .ToListAsync(cancellationToken);

            return Result<IEnumerable<CommentDto>>.Success(BuildOrderedComments(comments).Select(MapToDto));
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<CommentDto>>.Failure($"Ошибка получения комментариев: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<CommentDto>> UpdateAsync(int userId, int postId, int commentId, UpdateCommentDto dto, CancellationToken cancellationToken = default)
    {
        try
        {
            var comment = await _context.Comments
                .Include(c => c.User)
                .Include(c => c.ParentComment)
                    .ThenInclude(c => c!.User)
                .FirstOrDefaultAsync(c => c.Id == commentId && c.PostId == postId, cancellationToken);

            if (comment == null)
            {
                return Result<CommentDto>.Failure("Комментарий не найден", ResultError.NotFound);
            }

            if (comment.UserId != userId)
            {
                return Result<CommentDto>.Failure("Нет прав для редактирования комментария", ResultError.Forbidden);
            }

            comment.Content = dto.Content.Trim();
            comment.EditedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            return Result<CommentDto>.Success(MapToDto(comment));
        }
        catch (Exception ex)
        {
            return Result<CommentDto>.Failure($"Ошибка обновления комментария: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> DeleteAsync(int userId, int postId, int commentId, CancellationToken cancellationToken = default)
    {
        try
        {
            var comment = await _context.Comments
                .FirstOrDefaultAsync(c => c.Id == commentId && c.PostId == postId, cancellationToken);

            if (comment == null)
            {
                return Result.Failure("Комментарий не найден", ResultError.NotFound);
            }

            if (comment.UserId != userId)
            {
                return Result.Failure("Нет прав для удаления комментария", ResultError.Forbidden);
            }

            _context.Comments.Remove(comment);
            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка удаления комментария: {ex.Message}", ResultError.InternalError);
        }
    }

    private static IEnumerable<Comment> BuildOrderedComments(List<Comment> comments)
    {
        var roots = comments
            .Where(comment => comment.ParentCommentId == null)
            .OrderBy(comment => comment.CreatedAt)
            .ToList();
        var byParent = comments
            .Where(comment => comment.ParentCommentId.HasValue)
            .GroupBy(comment => comment.ParentCommentId!.Value)
            .ToDictionary(group => group.Key, group => group.OrderBy(c => c.CreatedAt).ToList());

        var ordered = new List<Comment>();
        var visited = new HashSet<int>();

        foreach (var root in roots)
        {
            AppendWithReplies(root, byParent, ordered, visited);
        }

        foreach (var comment in comments.Where(c => !visited.Contains(c.Id)).OrderBy(c => c.CreatedAt))
        {
            AppendWithReplies(comment, byParent, ordered, visited);
        }

        return ordered;
    }

    private static void AppendWithReplies(
        Comment comment,
        IReadOnlyDictionary<int, List<Comment>> byParent,
        ICollection<Comment> ordered,
        ISet<int> visited)
    {
        if (!visited.Add(comment.Id))
        {
            return;
        }

        ordered.Add(comment);

        if (!byParent.TryGetValue(comment.Id, out var replies))
        {
            return;
        }

        foreach (var reply in replies)
        {
            AppendWithReplies(reply, byParent, ordered, visited);
        }
    }

    private static CommentDto MapToDto(Comment comment)
    {
        return new CommentDto(
            comment.Id,
            comment.UserId,
            comment.User.Username,
            comment.User.AvatarUrl,
            comment.User.AvatarScale,
            comment.User.AvatarOffsetX,
            comment.User.AvatarOffsetY,
            comment.Content,
            comment.CreatedAt,
            comment.EditedAt,
            comment.ParentCommentId,
            comment.ParentComment?.User.Username);
    }
}

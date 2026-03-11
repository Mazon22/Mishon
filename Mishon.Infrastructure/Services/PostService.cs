using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;

namespace Mishon.Infrastructure.Services;

public class PostService : IPostService
{
    private readonly IPostRepository _postRepository;
    private readonly ILikeRepository _likeRepository;
    private readonly IFollowRepository _followRepository;
    private readonly INotificationService _notificationService;

    public PostService(
        IPostRepository postRepository,
        ILikeRepository likeRepository,
        IFollowRepository followRepository,
        INotificationService notificationService)
    {
        _postRepository = postRepository;
        _likeRepository = likeRepository;
        _followRepository = followRepository;
        _notificationService = notificationService;
    }

    public async Task<Result<PostDto>> CreateAsync(int userId, CreatePostDto dto)
    {
        try
        {
            var post = new Post
            {
                UserId = userId,
                Content = dto.Content,
                ImageUrl = dto.ImageUrl
            };

            await _postRepository.CreateAsync(post);

            var postWithUser = await _postRepository.GetByIdWithDetailsAsync(post.Id);
            if (postWithUser == null)
            {
                return Result<PostDto>.Failure("Пост не найден после создания", ResultError.InternalError);
            }

            var isFollowingAuthor = await _followRepository.GetAsync(userId, postWithUser.UserId) != null;
            return Result<PostDto>.Success(MapToDto(postWithUser, postWithUser.Likes.Count, false, isFollowingAuthor));
        }
        catch (Exception ex)
        {
            return Result<PostDto>.Failure($"Ошибка создания поста: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<PagedResult<PostDto>>> GetFeedAsync(int userId, int page, int pageSize)
    {
        try
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 50) pageSize = 10;

            var pagedPosts = await _postRepository.GetFeedAsync(userId, page, pageSize);
            var postIds = pagedPosts.Items.Select(p => p.Id);
            var userLikes = await _likeRepository.GetUserLikesAsync(userId, postIds);
            var followingIds = await _followRepository.GetFollowingIdsAsync(userId);

            var postDtos = pagedPosts.Items.Select(post => MapToDto(
                post,
                post.Likes.Count,
                userLikes.ContainsKey(post.Id),
                followingIds.Contains(post.UserId)))
                .ToList();

            return Result<PagedResult<PostDto>>.Success(new PagedResult<PostDto>(
                postDtos,
                pagedPosts.Page,
                pagedPosts.PageSize,
                pagedPosts.TotalCount));
        }
        catch (Exception ex)
        {
            return Result<PagedResult<PostDto>>.Failure($"Ошибка получения ленты: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<IEnumerable<PostDto>>> GetUserPostsAsync(int currentUserId, int profileUserId, int page, int pageSize)
    {
        try
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 50) pageSize = 20;

            var posts = (await _postRepository.GetUserPostsAsync(profileUserId, page, pageSize)).ToList();
            var userLikes = await _likeRepository.GetUserLikesAsync(currentUserId, posts.Select(p => p.Id));
            var followingIds = await _followRepository.GetFollowingIdsAsync(currentUserId);

            var postDtos = posts.Select(post => MapToDto(
                post,
                post.Likes.Count,
                userLikes.ContainsKey(post.Id),
                followingIds.Contains(post.UserId)))
                .ToList();

            return Result<IEnumerable<PostDto>>.Success(postDtos);
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<PostDto>>.Failure($"Ошибка получения постов пользователя: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<PostDto>> ToggleLikeAsync(int userId, int postId)
    {
        try
        {
            var post = await _postRepository.GetByIdWithDetailsAsync(postId);
            if (post == null)
            {
                return Result<PostDto>.Failure("Пост не найден", ResultError.NotFound);
            }

            var existingLike = await _likeRepository.GetAsync(userId, postId);
            if (existingLike != null)
            {
                await _likeRepository.RemoveAsync(existingLike);
            }
            else
            {
                await _likeRepository.AddAsync(new Like { UserId = userId, PostId = postId });

                if (post.UserId != userId)
                {
                    await _notificationService.CreateAsync(new CreateNotificationDto(
                        post.UserId,
                        userId,
                        NotificationTypes.PostLike,
                        "оценил(а) ваш пост",
                        post.Id,
                        null,
                        null,
                        null,
                        userId));
                }
            }

            var updatedPost = await _postRepository.GetByIdWithDetailsAsync(postId);
            if (updatedPost == null)
            {
                return Result<PostDto>.Failure("Пост не найден", ResultError.NotFound);
            }

            var isLiked = await _likeRepository.GetAsync(userId, postId) != null;
            var isFollowingAuthor = await _followRepository.GetAsync(userId, updatedPost.UserId) != null;

            return Result<PostDto>.Success(MapToDto(updatedPost, updatedPost.Likes.Count, isLiked, isFollowingAuthor));
        }
        catch (Exception ex)
        {
            return Result<PostDto>.Failure($"Ошибка лайка: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<PostDto>> GetPostAsync(int postId, int userId)
    {
        try
        {
            var post = await _postRepository.GetByIdWithDetailsAsync(postId);
            if (post == null)
            {
                return Result<PostDto>.Failure("Пост не найден", ResultError.NotFound);
            }

            var isLiked = await _likeRepository.GetAsync(userId, postId) != null;
            var isFollowingAuthor = await _followRepository.GetAsync(userId, post.UserId) != null;

            return Result<PostDto>.Success(MapToDto(post, post.Likes.Count, isLiked, isFollowingAuthor));
        }
        catch (Exception ex)
        {
            return Result<PostDto>.Failure($"Ошибка получения поста: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> DeleteAsync(int userId, int postId, CancellationToken cancellationToken = default)
    {
        try
        {
            var post = await _postRepository.GetByIdWithUserAsync(postId);
            if (post == null)
            {
                return Result.Failure("Пост не найден", ResultError.NotFound);
            }

            if (post.UserId != userId)
            {
                return Result.Failure("У вас нет прав для удаления этого поста", ResultError.Forbidden);
            }

            await _postRepository.DeleteAsync(post);
            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка удаления поста: {ex.Message}", ResultError.InternalError);
        }
    }

    private static PostDto MapToDto(Post post, int likesCount, bool isLiked, bool isFollowingAuthor)
    {
        return new PostDto(
            post.Id,
            post.UserId,
            post.User.Username,
            post.User.AvatarUrl,
            post.User.AvatarScale,
            post.User.AvatarOffsetX,
            post.User.AvatarOffsetY,
            post.Content,
            post.ImageUrl,
            post.CreatedAt,
            likesCount,
            post.Comments.Count,
            isLiked,
            isFollowingAuthor);
    }
}

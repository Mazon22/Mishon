using Microsoft.EntityFrameworkCore;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class PostService : IPostService
{
    private readonly IPostRepository _postRepository;
    private readonly ILikeRepository _likeRepository;
    private readonly IFollowRepository _followRepository;

    public PostService(IPostRepository postRepository, ILikeRepository likeRepository, IFollowRepository followRepository)
    {
        _postRepository = postRepository;
        _likeRepository = likeRepository;
        _followRepository = followRepository;
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

            // Загружаем данные пользователя
            var postWithUser = await _postRepository.GetByIdWithDetailsAsync(post.Id);
            if (postWithUser == null)
                return Result<PostDto>.Failure("Пост не найден после создания", ResultError.InternalError);

            // Проверяем, подписан ли текущий пользователь на автора
            var isFollowingAuthor = await _followRepository.GetAsync(userId, postWithUser.UserId) != null;
            return Result<PostDto>.Success(MapToDto(postWithUser, userId, 0, false, isFollowingAuthor));
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

            // Получаем лайки пользователя для всех постов одним запросом
            var postIds = pagedPosts.Items.Select(p => p.Id);
            var userLikes = await _likeRepository.GetUserLikesAsync(userId, postIds);

            // Получаем authorIds для проверки подписок
            var authorIds = pagedPosts.Items.Select(p => p.UserId).Distinct();
            var followingIds = await _followRepository.GetFollowingIdsAsync(userId);

            var postDtos = pagedPosts.Items.Select(p =>
            {
                var likesCount = p.Likes.Count;
                var isLiked = userLikes.ContainsKey(p.Id);
                var isFollowingAuthor = followingIds.Contains(p.UserId);
                return MapToDto(p, userId, likesCount, isLiked, isFollowingAuthor);
            }).ToList();

            var pagedResult = new PagedResult<PostDto>(
                postDtos,
                pagedPosts.Page,
                pagedPosts.PageSize,
                pagedPosts.TotalCount
            );

            return Result<PagedResult<PostDto>>.Success(pagedResult);
        }
        catch (Exception ex)
        {
            return Result<PagedResult<PostDto>>.Failure($"Ошибка получения ленты: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<PostDto>> ToggleLikeAsync(int userId, int postId)
    {
        try
        {
            var post = await _postRepository.GetByIdWithDetailsAsync(postId);
            if (post == null)
                return Result<PostDto>.Failure("Пост не найден", ResultError.NotFound);

            var existingLike = await _likeRepository.GetAsync(userId, postId);

            if (existingLike != null)
            {
                // Удаляем лайк
                await _likeRepository.RemoveAsync(existingLike);
            }
            else
            {
                // Добавляем лайк
                await _likeRepository.AddAsync(new Like { UserId = userId, PostId = postId });
            }

            // Перечитываем пост для актуального количества лайков
            var updatedPost = await _postRepository.GetByIdWithDetailsAsync(postId);
            if (updatedPost == null)
                return Result<PostDto>.Failure("Пост не найден", ResultError.NotFound);

            // Проверяем наличие лайка заново
            var isLiked = await _likeRepository.GetAsync(userId, postId) != null;
            
            // Проверяем, подписан ли текущий пользователь на автора
            var isFollowingAuthor = await _followRepository.GetAsync(userId, updatedPost.UserId) != null;

            return Result<PostDto>.Success(MapToDto(updatedPost, userId, updatedPost.Likes.Count, isLiked, isFollowingAuthor));
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
                return Result<PostDto>.Failure("Пост не найден", ResultError.NotFound);

            // Check if current user liked this post
            var isLiked = await _likeRepository.GetAsync(userId, postId) != null;
            
            // Check if current user follows the author
            var isFollowingAuthor = await _followRepository.GetAsync(userId, post.UserId) != null;

            return Result<PostDto>.Success(MapToDto(post, userId, post.Likes.Count, isLiked, isFollowingAuthor));
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
            // Получаем пост с данными пользователя
            var post = await _postRepository.GetByIdWithUserAsync(postId);
            if (post == null)
                return Result.Failure("Пост не найден", ResultError.NotFound);

            // Проверяем владельца поста
            if (post.UserId != userId)
                return Result.Failure("У вас нет прав для удаления этого поста", ResultError.Forbidden);

            // Удаляем пост (CASCADE удалит связанные лайки)
            await _postRepository.DeleteAsync(post);

            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка удаления поста: {ex.Message}", ResultError.InternalError);
        }
    }

    private PostDto MapToDto(Post post, int currentUserId, int likesCount, bool isLiked, bool isFollowingAuthor)
    {
        return new PostDto(
            post.Id,
            post.UserId,
            post.User.Username,
            post.User.AvatarUrl,
            post.Content,
            post.ImageUrl,
            post.CreatedAt,
            likesCount,
            isLiked,
            isFollowingAuthor
        );
    }
}

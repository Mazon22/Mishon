using Mishon.Application.DTOs;

namespace Mishon.Application.Interfaces;

public interface IAuthService
{
    Task<Result<AuthResponseDto>> RegisterAsync(RegisterDto dto);
    Task<Result<AuthResponseDto>> LoginAsync(LoginDto dto);
    Task<Result<AuthResponseDto>> RefreshTokenAsync(string refreshToken);
    Task<Result<UserProfileDto>> GetProfileAsync(int userId);
    Task<Result<UserProfileDto>> GetProfileForUserAsync(int userId, int currentUserId);
    Task<Result<UserProfileDto>> UpdateProfileAsync(int userId, UpdateProfileDto dto);
    Task<Result> LogoutAsync(int userId);
}

public interface IPostService
{
    Task<Result<PostDto>> CreateAsync(int userId, CreatePostDto dto);
    Task<Result<PagedResult<PostDto>>> GetFeedAsync(int userId, int page, int pageSize);
    Task<Result<PostDto>> ToggleLikeAsync(int userId, int postId);
    Task<Result<PostDto>> GetPostAsync(int postId, int userId);
    Task<Result> DeleteAsync(int userId, int postId, CancellationToken cancellationToken = default);
}

public interface IFollowService
{
    Task<Result<ToggleFollowResponseDto>> ToggleFollowAsync(int followerId, int followingId);
    Task<Result<IEnumerable<UserFollowDto>>> GetFollowingsAsync(int userId);
    Task<Result<IEnumerable<UserFollowDto>>> GetFollowersAsync(int userId);
    Task<Result<bool>> IsFollowingAsync(int followerId, int followingId);
    Task<Result<int>> GetFollowersCountAsync(int userId);
}

public interface ICommentService
{
    Task<Result<CommentDto>> CreateAsync(int userId, int postId, CreateCommentDto dto, CancellationToken cancellationToken = default);
    Task<Result<IEnumerable<CommentDto>>> GetByPostIdAsync(int postId, CancellationToken cancellationToken = default);
}

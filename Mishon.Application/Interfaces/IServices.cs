using Mishon.Application.DTOs;

namespace Mishon.Application.Interfaces;

public interface IAuthService
{
    Task<Result<AuthResponseDto>> RegisterAsync(RegisterDto dto);
    Task<Result<AuthResponseDto>> LoginAsync(LoginDto dto);
    Task<Result<AuthResponseDto>> RefreshTokenAsync(string refreshToken);
    Task<Result<UserProfileDto>> GetProfileAsync(int userId);
    Task<Result<UserProfileDto>> UpdateProfileAsync(int userId, UpdateProfileDto dto);
    Task<Result> LogoutAsync(int userId);
}

public interface IPostService
{
    Task<Result<PostDto>> CreateAsync(int userId, CreatePostDto dto);
    Task<Result<PagedResult<PostDto>>> GetFeedAsync(int userId, int page, int pageSize);
    Task<Result<PostDto>> ToggleLikeAsync(int userId, int postId);
    Task<Result<PostDto>> GetPostAsync(int postId, int userId);
}

public interface IFollowService
{
    Task<Result<FollowDto>> ToggleFollowAsync(int followerId, int followingId);
    Task<Result<IEnumerable<FollowDto>>> GetFollowingsAsync(int userId);
    Task<Result<IEnumerable<FollowDto>>> GetFollowersAsync(int userId);
    Task<Result<bool>> IsFollowingAsync(int followerId, int followingId);
}

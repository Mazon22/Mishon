using Mishon.Domain.Entities;
using Mishon.Application.DTOs;

namespace Mishon.Application.Interfaces;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(int id);
    Task<User?> GetByEmailAsync(string email);
    Task<User?> GetByUsernameAsync(string username);
    Task<User?> GetByIdWithTokensAsync(int id);
    Task<User> CreateAsync(User user);
    Task UpdateAsync(User user);
    Task<bool> ExistsByEmailAsync(string email);
    Task<bool> ExistsByUsernameAsync(string username);
}

public interface IPostRepository
{
    Task<Post> CreateAsync(Post post);
    Task<Post?> GetByIdAsync(int id);
    Task<Post?> GetByIdWithDetailsAsync(int id);
    Task<PagedResult<Post>> GetFeedAsync(int userId, int page, int pageSize);
    Task<IEnumerable<Post>> GetUserPostsAsync(int userId, int page, int pageSize);
    Task DeleteAsync(Post post);
    Task<int> GetTotalCountAsync();
}

public interface ILikeRepository
{
    Task<Like?> GetAsync(int userId, int postId);
    Task<Like> AddAsync(Like like);
    Task RemoveAsync(Like like);
    Task<int> GetCountAsync(int postId);
    Task<Dictionary<int, bool>> GetUserLikesAsync(int userId, IEnumerable<int> postIds);
}

public interface IFollowRepository
{
    Task<Follow?> GetAsync(int followerId, int followingId);
    Task<Follow> AddAsync(Follow follow);
    Task RemoveAsync(Follow follow);
    Task<IEnumerable<User>> GetFollowingsAsync(int userId);
    Task<IEnumerable<User>> GetFollowersAsync(int userId);
    Task<bool> IsFollowingAsync(int followerId, int followingId);
}

public interface IPagedResult
{
    int Page { get; }
    int PageSize { get; }
    int TotalCount { get; }
}

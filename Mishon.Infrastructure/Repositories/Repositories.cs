using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Repositories;

public class UserRepository : IUserRepository
{
    private readonly MishonDbContext _context;

    public UserRepository(MishonDbContext context)
    {
        _context = context;
    }

    public async Task<User?> GetByIdAsync(int id) =>
        await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == id);

    public async Task<User?> GetByIdWithTokensAsync(int id) =>
        await _context.Users.FirstOrDefaultAsync(u => u.Id == id);

    public async Task<User?> GetByEmailAsync(string email) =>
        await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Email == email);

    public async Task<User?> GetByUsernameAsync(string username) =>
        await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Username == username);

    public async Task<bool> ExistsByEmailAsync(string email) =>
        await _context.Users.AnyAsync(u => u.Email == email);

    public async Task<bool> ExistsByUsernameAsync(string username) =>
        await _context.Users.AnyAsync(u => u.Username == username);

    public async Task<User> CreateAsync(User user)
    {
        await _context.Users.AddAsync(user);
        await _context.SaveChangesAsync();
        return user;
    }

    public async Task UpdateAsync(User user)
    {
        _context.Entry(user).State = EntityState.Modified;
        await _context.SaveChangesAsync();
    }
}

public class PostRepository : IPostRepository
{
    private readonly MishonDbContext _context;

    public PostRepository(MishonDbContext context)
    {
        _context = context;
    }

    public async Task<Post> CreateAsync(Post post)
    {
        await _context.Posts.AddAsync(post);
        await _context.SaveChangesAsync();
        return post;
    }

    public async Task<Post?> GetByIdAsync(int id) =>
        await _context.Posts
            .AsNoTracking()
            .Include(p => p.User)
            .FirstOrDefaultAsync(p => p.Id == id);

    public async Task<Post?> GetByIdWithDetailsAsync(int id) =>
        await _context.Posts
            .Include(p => p.User)
            .Include(p => p.Likes)
            .FirstOrDefaultAsync(p => p.Id == id);

    public async Task<PagedResult<Post>> GetFeedAsync(int userId, int page, int pageSize)
    {
        var followingIds = await _context.Follows
            .AsNoTracking()
            .Where(f => f.FollowerId == userId)
            .Select(f => f.FollowingId)
            .ToListAsync();

        var query = _context.Posts
            .AsNoTracking()
            .Include(p => p.User)
            .Include(p => p.Likes)
            .Where(p => followingIds.Contains(p.UserId) || p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt);

        var totalCount = await query.CountAsync();

        var posts = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return new PagedResult<Post>(posts, page, pageSize, totalCount);
    }

    public async Task<IEnumerable<Post>> GetUserPostsAsync(int userId, int page, int pageSize) =>
        await _context.Posts
            .AsNoTracking()
            .Include(p => p.User)
            .Include(p => p.Likes)
            .Where(p => p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

    public async Task DeleteAsync(Post post)
    {
        _context.Posts.Remove(post);
        await _context.SaveChangesAsync();
    }

    public async Task<int> GetTotalCountAsync() =>
        await _context.Posts.CountAsync();
}

public class LikeRepository : ILikeRepository
{
    private readonly MishonDbContext _context;

    public LikeRepository(MishonDbContext context)
    {
        _context = context;
    }

    public async Task<Like?> GetAsync(int userId, int postId) =>
        await _context.Likes.FirstOrDefaultAsync(l => l.UserId == userId && l.PostId == postId);

    public async Task<Like> AddAsync(Like like)
    {
        await _context.Likes.AddAsync(like);
        await _context.SaveChangesAsync();
        return like;
    }

    public async Task RemoveAsync(Like like)
    {
        // Находим сущность в контексте и удаляем её
        var existingLike = await _context.Likes.FindAsync(like.Id);
        if (existingLike != null)
        {
            _context.Likes.Remove(existingLike);
            await _context.SaveChangesAsync();
        }
    }

    public async Task<int> GetCountAsync(int postId) =>
        await _context.Likes.AsNoTracking().CountAsync(l => l.PostId == postId);

    public async Task<Dictionary<int, bool>> GetUserLikesAsync(int userId, IEnumerable<int> postIds)
    {
        var likes = await _context.Likes
            .AsNoTracking()
            .Where(l => l.UserId == userId && postIds.Contains(l.PostId))
            .ToListAsync();

        return likes.ToDictionary(l => l.PostId, l => true);
    }
}

public class FollowRepository : IFollowRepository
{
    private readonly MishonDbContext _context;

    public FollowRepository(MishonDbContext context)
    {
        _context = context;
    }

    public async Task<Follow?> GetAsync(int followerId, int followingId) =>
        await _context.Follows.AsNoTracking().FirstOrDefaultAsync(f => f.FollowerId == followerId && f.FollowingId == followingId);

    public async Task<Follow> AddAsync(Follow follow)
    {
        await _context.Follows.AddAsync(follow);
        await _context.SaveChangesAsync();
        return follow;
    }

    public async Task RemoveAsync(Follow follow)
    {
        _context.Follows.Remove(follow);
        await _context.SaveChangesAsync();
    }

    public async Task<IEnumerable<User>> GetFollowingsAsync(int userId) =>
        await _context.Follows
            .AsNoTracking()
            .Where(f => f.FollowerId == userId)
            .Select(f => f.Following)
            .ToListAsync();

    public async Task<IEnumerable<User>> GetFollowersAsync(int userId) =>
        await _context.Follows
            .AsNoTracking()
            .Where(f => f.FollowingId == userId)
            .Select(f => f.Follower)
            .ToListAsync();

    public async Task<bool> IsFollowingAsync(int followerId, int followingId) =>
        await _context.Follows.AnyAsync(f => f.FollowerId == followerId && f.FollowingId == followingId);
}

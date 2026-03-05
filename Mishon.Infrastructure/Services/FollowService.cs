using Microsoft.EntityFrameworkCore;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class FollowService : IFollowService
{
    private readonly IFollowRepository _followRepository;
    private readonly IUserRepository _userRepository;
    private readonly MishonDbContext _context;

    public FollowService(IFollowRepository followRepository, IUserRepository userRepository, MishonDbContext context)
    {
        _followRepository = followRepository;
        _userRepository = userRepository;
        _context = context;
    }

    public async Task<Result<ToggleFollowResponseDto>> ToggleFollowAsync(int followerId, int followingId)
    {
        try
        {
            if (followerId == followingId)
                return Result<ToggleFollowResponseDto>.Failure("Нельзя подписаться на себя", ResultError.BadRequest);

            var targetUser = await _userRepository.GetByIdAsync(followingId);
            if (targetUser == null)
                return Result<ToggleFollowResponseDto>.Failure("Пользователь не найден", ResultError.NotFound);

            var existingFollow = await _followRepository.GetAsync(followerId, followingId);

            bool isFollowing;

            if (existingFollow != null)
            {
                // Unfollow
                await _followRepository.RemoveAsync(existingFollow);
                isFollowing = false;
            }
            else
            {
                // Follow
                await _followRepository.AddAsync(new Follow { FollowerId = followerId, FollowingId = followingId });
                isFollowing = true;
            }

            // Получаем количество подписчиков
            var followersCount = await _context.Follows
                .AsNoTracking()
                .CountAsync(f => f.FollowingId == followingId);

            return Result<ToggleFollowResponseDto>.Success(new ToggleFollowResponseDto(isFollowing, followersCount));
        }
        catch (Exception ex)
        {
            return Result<ToggleFollowResponseDto>.Failure($"Ошибка подписки: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<IEnumerable<UserFollowDto>>> GetFollowingsAsync(int userId)
    {
        try
        {
            var users = await _followRepository.GetFollowingsAsync(userId);
            // Получаем ID тех, на кого подписан текущий пользователь
            var currentUserId = userId; // Для своего профиля
            var myFollowingIds = await _followRepository.GetFollowingIdsAsync(currentUserId);
            
            return Result<IEnumerable<UserFollowDto>>.Success(
                users.Select(u => new UserFollowDto(u.Id, u.Username, u.AvatarUrl, myFollowingIds.Contains(u.Id)))
            );
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<UserFollowDto>>.Failure($"Ошибка получения подписок: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<IEnumerable<UserFollowDto>>> GetFollowersAsync(int userId)
    {
        try
        {
            var users = await _followRepository.GetFollowersAsync(userId);
            // Получаем ID тех, на кого подписан текущий пользователь
            var myFollowingIds = await _followRepository.GetFollowingIdsAsync(userId);
            
            return Result<IEnumerable<UserFollowDto>>.Success(
                users.Select(u => new UserFollowDto(u.Id, u.Username, u.AvatarUrl, myFollowingIds.Contains(u.Id)))
            );
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<UserFollowDto>>.Failure($"Ошибка получения подписчиков: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<bool>> IsFollowingAsync(int followerId, int followingId)
    {
        try
        {
            var isFollowing = await _followRepository.IsFollowingAsync(followerId, followingId);
            return Result<bool>.Success(isFollowing);
        }
        catch (Exception ex)
        {
            return Result<bool>.Failure($"Ошибка проверки подписки: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<int>> GetFollowersCountAsync(int userId)
    {
        try
        {
            var count = await _context.Follows
                .AsNoTracking()
                .CountAsync(f => f.FollowingId == userId);
            return Result<int>.Success(count);
        }
        catch (Exception ex)
        {
            return Result<int>.Failure($"Ошибка получения количества подписчиков: {ex.Message}", ResultError.InternalError);
        }
    }
}

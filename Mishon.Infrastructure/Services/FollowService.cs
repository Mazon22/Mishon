using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;

namespace Mishon.Infrastructure.Services;

public class FollowService : IFollowService
{
    private readonly IFollowRepository _followRepository;
    private readonly IUserRepository _userRepository;

    public FollowService(IFollowRepository followRepository, IUserRepository userRepository)
    {
        _followRepository = followRepository;
        _userRepository = userRepository;
    }

    public async Task<Result<FollowDto>> ToggleFollowAsync(int followerId, int followingId)
    {
        try
        {
            if (followerId == followingId)
                return Result<FollowDto>.Failure("Нельзя подписаться на себя", ResultError.BadRequest);

            var targetUser = await _userRepository.GetByIdAsync(followingId);
            if (targetUser == null)
                return Result<FollowDto>.Failure("Пользователь не найден", ResultError.NotFound);

            var existingFollow = await _followRepository.GetAsync(followerId, followingId);

            if (existingFollow != null)
            {
                await _followRepository.RemoveAsync(existingFollow);
            }
            else
            {
                await _followRepository.AddAsync(new Follow { FollowerId = followerId, FollowingId = followingId });
            }

            return Result<FollowDto>.Success(new FollowDto(
                targetUser.Id,
                targetUser.Username,
                targetUser.AvatarUrl
            ));
        }
        catch (Exception ex)
        {
            return Result<FollowDto>.Failure($"Ошибка подписки: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<IEnumerable<FollowDto>>> GetFollowingsAsync(int userId)
    {
        try
        {
            var users = await _followRepository.GetFollowingsAsync(userId);
            return Result<IEnumerable<FollowDto>>.Success(
                users.Select(u => new FollowDto(u.Id, u.Username, u.AvatarUrl))
            );
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<FollowDto>>.Failure($"Ошибка получения подписок: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result<IEnumerable<FollowDto>>> GetFollowersAsync(int userId)
    {
        try
        {
            var users = await _followRepository.GetFollowersAsync(userId);
            return Result<IEnumerable<FollowDto>>.Success(
                users.Select(u => new FollowDto(u.Id, u.Username, u.AvatarUrl))
            );
        }
        catch (Exception ex)
        {
            return Result<IEnumerable<FollowDto>>.Failure($"Ошибка получения подписчиков: {ex.Message}", ResultError.InternalError);
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
}

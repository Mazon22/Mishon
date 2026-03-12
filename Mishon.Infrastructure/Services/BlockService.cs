using Microsoft.EntityFrameworkCore;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public class BlockService : IBlockService
{
    private readonly MishonDbContext _context;

    public BlockService(MishonDbContext context)
    {
        _context = context;
    }

    public async Task<Result> BlockUserAsync(
        int blockerId,
        int blockedUserId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            if (blockerId == blockedUserId)
            {
                return Result.Failure("Нельзя заблокировать самого себя", ResultError.BadRequest);
            }

            var userExists = await _context.Users
                .AsNoTracking()
                .AnyAsync(u => u.Id == blockedUserId, cancellationToken);
            if (!userExists)
            {
                return Result.Failure("Пользователь не найден", ResultError.NotFound);
            }

            var existingBlock = await _context.UserBlocks
                .FirstOrDefaultAsync(
                    x => x.BlockerId == blockerId && x.BlockedUserId == blockedUserId,
                    cancellationToken);
            if (existingBlock != null)
            {
                return Result.Success();
            }

            _context.UserBlocks.Add(new UserBlock
            {
                BlockerId = blockerId,
                BlockedUserId = blockedUserId
            });

            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка блокировки пользователя: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<Result> UnblockUserAsync(
        int blockerId,
        int blockedUserId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var existingBlock = await _context.UserBlocks
                .FirstOrDefaultAsync(
                    x => x.BlockerId == blockerId && x.BlockedUserId == blockedUserId,
                    cancellationToken);
            if (existingBlock == null)
            {
                return Result.Success();
            }

            _context.UserBlocks.Remove(existingBlock);
            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure($"Ошибка разблокировки пользователя: {ex.Message}", ResultError.InternalError);
        }
    }

    public async Task<UserBlockStatusDto> GetStatusAsync(
        int viewerId,
        int otherUserId,
        CancellationToken cancellationToken = default)
    {
        var blockPairs = await _context.UserBlocks
            .AsNoTracking()
            .Where(x =>
                (x.BlockerId == viewerId && x.BlockedUserId == otherUserId) ||
                (x.BlockerId == otherUserId && x.BlockedUserId == viewerId))
            .Select(x => new { x.BlockerId, x.BlockedUserId })
            .ToListAsync(cancellationToken);

        return new UserBlockStatusDto(
            blockPairs.Any(x => x.BlockerId == viewerId && x.BlockedUserId == otherUserId),
            blockPairs.Any(x => x.BlockerId == otherUserId && x.BlockedUserId == viewerId));
    }

    public async Task<HashSet<int>> GetRestrictedUserIdsAsync(
        int viewerId,
        CancellationToken cancellationToken = default)
    {
        var ids = await _context.UserBlocks
            .AsNoTracking()
            .Where(x => x.BlockerId == viewerId || x.BlockedUserId == viewerId)
            .Select(x => x.BlockerId == viewerId ? x.BlockedUserId : x.BlockerId)
            .ToListAsync(cancellationToken);

        return ids.ToHashSet();
    }

    public async Task<bool> AreUsersBlockedAsync(
        int firstUserId,
        int secondUserId,
        CancellationToken cancellationToken = default)
    {
        return await _context.UserBlocks
            .AsNoTracking()
            .AnyAsync(
                x =>
                    (x.BlockerId == firstUserId && x.BlockedUserId == secondUserId) ||
                    (x.BlockerId == secondUserId && x.BlockedUserId == firstUserId),
                cancellationToken);
    }
}

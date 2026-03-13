using System.Collections.Concurrent;
using Microsoft.Extensions.Caching.Memory;

namespace Mishon.Infrastructure.Services;

public sealed record FeedRankingSnapshot(
    IReadOnlyList<int> OrderedPostIds,
    DateTime GeneratedAtUtc);

public interface IFeedCacheStore
{
    void RegisterUserActivity(int userId);
    bool TryGetForYouSnapshot(int userId, out FeedRankingSnapshot? snapshot);
    void SetForYouSnapshot(int userId, FeedRankingSnapshot snapshot);
    IReadOnlyCollection<int> GetActiveUserIds(TimeSpan activityWindow);
}

public sealed class FeedCacheStore : IFeedCacheStore
{
    private static readonly MemoryCacheEntryOptions CacheOptions = new()
    {
        SlidingExpiration = TimeSpan.FromMinutes(20),
        AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(2),
    };

    private readonly IMemoryCache _memoryCache;
    private readonly ConcurrentDictionary<int, DateTime> _activeUsers = new();

    public FeedCacheStore(IMemoryCache memoryCache)
    {
        _memoryCache = memoryCache;
    }

    public void RegisterUserActivity(int userId)
    {
        _activeUsers[userId] = DateTime.UtcNow;
    }

    public bool TryGetForYouSnapshot(int userId, out FeedRankingSnapshot? snapshot)
    {
        if (_memoryCache.TryGetValue(GetCacheKey(userId), out FeedRankingSnapshot? cached))
        {
            snapshot = cached;
            return snapshot is not null;
        }

        snapshot = null;
        return false;
    }

    public void SetForYouSnapshot(int userId, FeedRankingSnapshot snapshot)
    {
        _memoryCache.Set(GetCacheKey(userId), snapshot, CacheOptions);
    }

    public IReadOnlyCollection<int> GetActiveUserIds(TimeSpan activityWindow)
    {
        var now = DateTime.UtcNow;
        var activeUserIds = new List<int>();

        foreach (var (userId, lastSeenAt) in _activeUsers.ToArray())
        {
            if (now - lastSeenAt <= activityWindow)
            {
                activeUserIds.Add(userId);
                continue;
            }

            _activeUsers.TryRemove(userId, out _);
        }

        return activeUserIds;
    }

    private static string GetCacheKey(int userId) => $"feed:foryou:{userId}";
}

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Mishon.Application.Interfaces;
using Mishon.Infrastructure.Services;

namespace Mishon.API.Background;

public sealed class FeedRefreshBackgroundService : BackgroundService
{
    private static readonly TimeSpan RefreshInterval = TimeSpan.FromMinutes(1);
    private static readonly TimeSpan ActiveUserWindow = TimeSpan.FromMinutes(20);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IFeedCacheStore _feedCacheStore;
    private readonly ILogger<FeedRefreshBackgroundService> _logger;

    public FeedRefreshBackgroundService(
        IServiceScopeFactory scopeFactory,
        IFeedCacheStore feedCacheStore,
        ILogger<FeedRefreshBackgroundService> logger)
    {
        _scopeFactory = scopeFactory;
        _feedCacheStore = feedCacheStore;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(RefreshInterval);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await timer.WaitForNextTickAsync(stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }

            var activeUserIds = _feedCacheStore.GetActiveUserIds(ActiveUserWindow);
            if (activeUserIds.Count == 0)
            {
                continue;
            }

            foreach (var userId in activeUserIds)
            {
                try
                {
                    await using var scope = _scopeFactory.CreateAsyncScope();
                    var feedService = scope.ServiceProvider.GetRequiredService<IFeedService>();
                    await feedService.WarmForYouFeedAsync(userId, stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    throw;
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to refresh cached feed for user {UserId}", userId);
                }
            }
        }
    }
}

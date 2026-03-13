using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Domain.Entities;
using Mishon.Infrastructure.Data;

namespace Mishon.Infrastructure.Services;

public sealed class FeedService : IFeedService
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 50;
    private const int CandidateLimit = 240;
    private const int MinimumCandidatePool = 80;
    private static readonly TimeSpan SnapshotFreshness = TimeSpan.FromSeconds(90);
    private static readonly TimeSpan CandidateWindow = TimeSpan.FromDays(21);
    private static readonly TimeSpan RelationshipWindow = TimeSpan.FromDays(90);
    private static readonly TimeSpan TrendingWindow = TimeSpan.FromDays(3);
    private static readonly Regex HashtagRegex = new(
        @"#([a-zA-Z0-9_\.]+)",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private readonly MishonDbContext _context;
    private readonly IBlockService _blockService;
    private readonly IFeedCacheStore _feedCacheStore;

    public FeedService(
        MishonDbContext context,
        IBlockService blockService,
        IFeedCacheStore feedCacheStore)
    {
        _context = context;
        _blockService = blockService;
        _feedCacheStore = feedCacheStore;
    }

    public async Task<Result<PagedResult<PostDto>>> GetForYouFeedAsync(
        int userId,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        NormalizePaging(ref page, ref pageSize);
        _feedCacheStore.RegisterUserActivity(userId);

        try
        {
            var snapshot = await GetOrBuildSnapshotAsync(userId, cancellationToken);
            var totalCount = snapshot.OrderedPostIds.Count;
            var pageIds = snapshot.OrderedPostIds
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToList();

            if (pageIds.Count == 0)
            {
                return Result<PagedResult<PostDto>>.Success(
                    new PagedResult<PostDto>([], page, pageSize, totalCount));
            }

            var posts = await MaterializePostsAsync(userId, pageIds, cancellationToken);
            return Result<PagedResult<PostDto>>.Success(
                new PagedResult<PostDto>(posts, page, pageSize, totalCount));
        }
        catch (Exception ex)
        {
            return Result<PagedResult<PostDto>>.Failure(
                $"Ошибка получения ленты рекомендаций: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task<Result<PagedResult<PostDto>>> GetFollowingFeedAsync(
        int userId,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        NormalizePaging(ref page, ref pageSize);

        try
        {
            var followingIds = await _context.Follows
                .AsNoTracking()
                .Where(f => f.FollowerId == userId)
                .Select(f => f.FollowingId)
                .ToListAsync(cancellationToken);

            if (followingIds.Count == 0)
            {
                return Result<PagedResult<PostDto>>.Success(
                    new PagedResult<PostDto>([], page, pageSize, 0));
            }

            var restrictedUserIds = (await _blockService.GetRestrictedUserIdsAsync(userId, cancellationToken)).ToList();
            var visibleFollowingIds = followingIds
                .Where(followingId => !restrictedUserIds.Contains(followingId))
                .ToList();

            if (visibleFollowingIds.Count == 0)
            {
                return Result<PagedResult<PostDto>>.Success(
                    new PagedResult<PostDto>([], page, pageSize, 0));
            }

            var query = _context.Posts
                .AsNoTracking()
                .Include(p => p.User)
                .Include(p => p.Likes)
                .Include(p => p.Comments)
                .Where(p => visibleFollowingIds.Contains(p.UserId))
                .OrderByDescending(p => p.CreatedAt);

            var totalCount = await query.CountAsync(cancellationToken);
            var pagePosts = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(cancellationToken);

            var postIds = pagePosts.Select(p => p.Id).ToList();
            var likedPostIds = await _context.Likes
                .AsNoTracking()
                .Where(l => l.UserId == userId && postIds.Contains(l.PostId))
                .Select(l => l.PostId)
                .ToListAsync(cancellationToken);

            var likedPostSet = likedPostIds.ToHashSet();
            var followingIdSet = visibleFollowingIds.ToHashSet();

            var items = pagePosts
                .Select(post => MapToDto(
                    post,
                    likedPostSet.Contains(post.Id),
                    followingIdSet.Contains(post.UserId)))
                .ToList();

            return Result<PagedResult<PostDto>>.Success(
                new PagedResult<PostDto>(items, page, pageSize, totalCount));
        }
        catch (Exception ex)
        {
            return Result<PagedResult<PostDto>>.Failure(
                $"Ошибка получения ленты подписок: {ex.Message}",
                ResultError.InternalError);
        }
    }

    public async Task WarmForYouFeedAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        _feedCacheStore.RegisterUserActivity(userId);

        if (_feedCacheStore.TryGetForYouSnapshot(userId, out var existingSnapshot) &&
            existingSnapshot is not null &&
            DateTime.UtcNow - existingSnapshot.GeneratedAtUtc < SnapshotFreshness)
        {
            return;
        }

        var snapshot = await BuildSnapshotAsync(userId, cancellationToken);
        _feedCacheStore.SetForYouSnapshot(userId, snapshot);
    }

    private async Task<FeedRankingSnapshot> GetOrBuildSnapshotAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        if (_feedCacheStore.TryGetForYouSnapshot(userId, out var cachedSnapshot) &&
            cachedSnapshot is not null &&
            DateTime.UtcNow - cachedSnapshot.GeneratedAtUtc < SnapshotFreshness)
        {
            return cachedSnapshot;
        }

        var snapshot = await BuildSnapshotAsync(userId, cancellationToken);
        _feedCacheStore.SetForYouSnapshot(userId, snapshot);
        return snapshot;
    }

    private async Task<FeedRankingSnapshot> BuildSnapshotAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var candidateCutoff = now - CandidateWindow;
        var relationshipCutoff = now - RelationshipWindow;
        var trendingCutoff = now - TrendingWindow;

        var restrictedUserIds = (await _blockService.GetRestrictedUserIdsAsync(userId, cancellationToken)).ToList();
        var followingIds = await _context.Follows
            .AsNoTracking()
            .Where(f => f.FollowerId == userId)
            .Select(f => f.FollowingId)
            .ToListAsync(cancellationToken);
        var friendIds = await _context.Friendships
            .AsNoTracking()
            .Where(f => f.UserAId == userId || f.UserBId == userId)
            .Select(f => f.UserAId == userId ? f.UserBId : f.UserAId)
            .ToListAsync(cancellationToken);

        var candidates = await _context.Posts
            .AsNoTracking()
            .Where(p => p.UserId != userId)
            .Where(p => !restrictedUserIds.Contains(p.UserId))
            .Where(p => p.CreatedAt >= candidateCutoff || followingIds.Contains(p.UserId))
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => new FeedCandidateProjection(
                p.Id,
                p.UserId,
                p.CreatedAt,
                p.Content,
                p.ImageUrl != null && p.ImageUrl != string.Empty,
                p.Likes.Count,
                p.Comments.Count))
            .Take(CandidateLimit)
            .ToListAsync(cancellationToken);

        if (candidates.Count < MinimumCandidatePool)
        {
            var existingCandidateIds = candidates.Select(candidate => candidate.Id).ToList();
            var fallbackCandidates = await _context.Posts
                .AsNoTracking()
                .Where(p => p.UserId != userId)
                .Where(p => !restrictedUserIds.Contains(p.UserId))
                .Where(p => !existingCandidateIds.Contains(p.Id))
                .OrderByDescending(p => p.CreatedAt)
                .Select(p => new FeedCandidateProjection(
                    p.Id,
                    p.UserId,
                    p.CreatedAt,
                    p.Content,
                    p.ImageUrl != null && p.ImageUrl != string.Empty,
                    p.Likes.Count,
                    p.Comments.Count))
                .Take(MinimumCandidatePool - candidates.Count)
                .ToListAsync(cancellationToken);

            candidates.AddRange(fallbackCandidates);
        }

        if (candidates.Count == 0)
        {
            return new FeedRankingSnapshot([], now);
        }

        var candidateIds = candidates.Select(candidate => candidate.Id).ToList();
        var authorIds = candidates.Select(candidate => candidate.UserId).Distinct().ToList();

        var recentLikesByPost = await _context.Likes
            .AsNoTracking()
            .Where(l => candidateIds.Contains(l.PostId) && l.CreatedAt >= trendingCutoff)
            .GroupBy(l => l.PostId)
            .Select(group => new { PostId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.PostId, item => item.Count, cancellationToken);

        var recentCommentsByPost = await _context.Comments
            .AsNoTracking()
            .Where(c => candidateIds.Contains(c.PostId) && c.CreatedAt >= trendingCutoff)
            .GroupBy(c => c.PostId)
            .Select(group => new { PostId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.PostId, item => item.Count, cancellationToken);

        var messageInteractions = await _context.Conversations
            .AsNoTracking()
            .Where(c =>
                (c.UserAId == userId && authorIds.Contains(c.UserBId)) ||
                (c.UserBId == userId && authorIds.Contains(c.UserAId)))
            .Select(c => new
            {
                AuthorId = c.UserAId == userId ? c.UserBId : c.UserAId,
                Count = c.Messages.Count(m => m.CreatedAt >= relationshipCutoff),
            })
            .ToListAsync(cancellationToken);

        var recentLikesByAuthor = await _context.Likes
            .AsNoTracking()
            .Where(l => l.UserId == userId)
            .Where(l => authorIds.Contains(l.Post.UserId))
            .Where(l => l.CreatedAt >= relationshipCutoff)
            .GroupBy(l => l.Post.UserId)
            .Select(group => new { AuthorId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.AuthorId, item => item.Count, cancellationToken);

        var recentCommentsByAuthor = await _context.Comments
            .AsNoTracking()
            .Where(c => c.UserId == userId)
            .Where(c => authorIds.Contains(c.Post.UserId))
            .Where(c => c.CreatedAt >= relationshipCutoff)
            .GroupBy(c => c.Post.UserId)
            .Select(group => new { AuthorId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.AuthorId, item => item.Count, cancellationToken);

        var relationshipByAuthor = messageInteractions
            .ToDictionary(item => item.AuthorId, item => (double)item.Count);
        var followingIdSet = followingIds.ToHashSet();
        var friendIdSet = friendIds.ToHashSet();

        var interestProfile = await BuildInterestProfileAsync(userId, cancellationToken);

        var maxEngagement = 0d;
        var maxRelationship = 0d;
        var maxTrending = 0d;
        var scoreParts = new Dictionary<int, FeedScoreParts>(capacity: candidates.Count);

        foreach (var candidate in candidates)
        {
            var recentLikes = recentLikesByPost.GetValueOrDefault(candidate.Id);
            var recentComments = recentCommentsByPost.GetValueOrDefault(candidate.Id);
            var engagementRaw =
                candidate.LikesCount +
                (candidate.CommentsCount * 2.4) +
                (recentLikes * 1.4) +
                (recentComments * 2.8);
            maxEngagement = Math.Max(maxEngagement, engagementRaw);

            var relationshipRaw =
                (followingIdSet.Contains(candidate.UserId) ? 3.2 : 0) +
                (friendIdSet.Contains(candidate.UserId) ? 2.1 : 0) +
                (relationshipByAuthor.GetValueOrDefault(candidate.UserId) * 0.08) +
                (recentLikesByAuthor.GetValueOrDefault(candidate.UserId) * 0.9) +
                (recentCommentsByAuthor.GetValueOrDefault(candidate.UserId) * 1.2);
            maxRelationship = Math.Max(maxRelationship, relationshipRaw);

            var trendingRaw =
                (recentLikes * 1.5) +
                (recentComments * 2.5) +
                ((candidate.LikesCount + candidate.CommentsCount) * 0.15);
            maxTrending = Math.Max(maxTrending, trendingRaw);

            scoreParts[candidate.Id] = new FeedScoreParts(
                RecencyScore: ComputeRecencyScore(now, candidate.CreatedAt),
                EngagementRaw: engagementRaw,
                RelationshipRaw: relationshipRaw,
                InterestScore: ComputeInterestScore(candidate, interestProfile),
                TrendingRaw: trendingRaw);
        }

        var scoredCandidates = candidates
            .Select(candidate =>
            {
                var parts = scoreParts[candidate.Id];
                var engagementScore = Normalize(parts.EngagementRaw, maxEngagement);
                var relationshipScore = Normalize(parts.RelationshipRaw, maxRelationship);
                var trendingScore = Normalize(parts.TrendingRaw, maxTrending);
                var score =
                    (0.3 * parts.RecencyScore) +
                    (0.3 * engagementScore) +
                    (0.2 * relationshipScore) +
                    (0.1 * parts.InterestScore) +
                    (0.1 * trendingScore);

                return new ScoredFeedCandidate(candidate.Id, candidate.UserId, score, candidate.CreatedAt);
            })
            .OrderByDescending(candidate => candidate.Score)
            .ThenByDescending(candidate => candidate.CreatedAt)
            .ToList();

        var deDuplicatedPostIds = ApplyAuthorDiversity(scoredCandidates);
        return new FeedRankingSnapshot(deDuplicatedPostIds, now);
    }

    private async Task<List<PostDto>> MaterializePostsAsync(
        int userId,
        IReadOnlyList<int> orderedPostIds,
        CancellationToken cancellationToken)
    {
        if (orderedPostIds.Count == 0)
        {
            return [];
        }

        var restrictedUserIds = (await _blockService.GetRestrictedUserIdsAsync(userId, cancellationToken)).ToList();
        var followingIds = await _context.Follows
            .AsNoTracking()
            .Where(f => f.FollowerId == userId)
            .Select(f => f.FollowingId)
            .ToListAsync(cancellationToken);
        var likedPostIds = await _context.Likes
            .AsNoTracking()
            .Where(l => l.UserId == userId && orderedPostIds.Contains(l.PostId))
            .Select(l => l.PostId)
            .ToListAsync(cancellationToken);

        var posts = await _context.Posts
            .AsNoTracking()
            .Include(p => p.User)
            .Include(p => p.Likes)
            .Include(p => p.Comments)
            .Where(p => orderedPostIds.Contains(p.Id))
            .Where(p => !restrictedUserIds.Contains(p.UserId))
            .ToListAsync(cancellationToken);

        var order = orderedPostIds
            .Select((postId, index) => new { postId, index })
            .ToDictionary(item => item.postId, item => item.index);
        var likedPostSet = likedPostIds.ToHashSet();
        var followingIdSet = followingIds.ToHashSet();

        return posts
            .OrderBy(post => order[post.Id])
            .Select(post => MapToDto(
                post,
                likedPostSet.Contains(post.Id),
                followingIdSet.Contains(post.UserId)))
            .ToList();
    }

    private async Task<InterestProfile> BuildInterestProfileAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        var likedPostIds = await _context.Likes
            .AsNoTracking()
            .Where(l => l.UserId == userId)
            .OrderByDescending(l => l.CreatedAt)
            .Select(l => l.PostId)
            .Take(48)
            .ToListAsync(cancellationToken);

        var commentedPostIds = await _context.Comments
            .AsNoTracking()
            .Where(c => c.UserId == userId)
            .OrderByDescending(c => c.CreatedAt)
            .Select(c => c.PostId)
            .Take(24)
            .ToListAsync(cancellationToken);

        var ownPostIds = await _context.Posts
            .AsNoTracking()
            .Where(p => p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => p.Id)
            .Take(12)
            .ToListAsync(cancellationToken);

        var interestPostIds = likedPostIds
            .Concat(commentedPostIds)
            .Concat(ownPostIds)
            .Distinct()
            .Take(72)
            .ToList();

        if (interestPostIds.Count == 0)
        {
            return InterestProfile.Empty;
        }

        var samples = await _context.Posts
            .AsNoTracking()
            .Where(p => interestPostIds.Contains(p.Id))
            .Select(p => new InterestPostSample(
                p.Content,
                p.ImageUrl != null && p.ImageUrl != string.Empty))
            .ToListAsync(cancellationToken);

        if (samples.Count == 0)
        {
            return InterestProfile.Empty;
        }

        var topicWeights = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var imageSampleCount = 0;

        foreach (var sample in samples)
        {
            if (sample.HasImage)
            {
                imageSampleCount++;
            }

            foreach (var hashtag in ExtractHashtags(sample.Content))
            {
                topicWeights[hashtag] = topicWeights.TryGetValue(hashtag, out var count)
                    ? count + 1
                    : 1;
            }
        }

        var imageAffinity = imageSampleCount / (double)samples.Count;
        var topicNormalizationBase = topicWeights.Count == 0
            ? 1
            : topicWeights.Values.OrderByDescending(value => value).Take(3).Sum();

        return new InterestProfile(
            samples.Count,
            imageAffinity,
            topicWeights,
            topicNormalizationBase);
    }

    private static double ComputeRecencyScore(DateTime now, DateTime createdAtUtc)
    {
        var ageHours = Math.Max((now - createdAtUtc).TotalHours, 0);
        return Math.Clamp(Math.Exp(-ageHours / 18d), 0, 1);
    }

    private static double ComputeInterestScore(
        FeedCandidateProjection candidate,
        InterestProfile profile)
    {
        if (profile.SampleCount == 0)
        {
            return candidate.HasImage ? 0.56 : 0.44;
        }

        var typeScore = candidate.HasImage
            ? profile.ImageAffinity
            : 1 - profile.ImageAffinity;

        var hashtags = ExtractHashtags(candidate.Content);
        var topicWeight = 0d;

        if (hashtags.Count > 0 && profile.TopicWeights.Count > 0)
        {
            topicWeight = hashtags
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Sum(hashtag => profile.TopicWeights.GetValueOrDefault(hashtag));
            topicWeight = Normalize(topicWeight, profile.TopicNormalizationBase);
        }

        return Math.Clamp((typeScore * 0.55) + (topicWeight * 0.45), 0, 1);
    }

    private static IReadOnlyList<int> ApplyAuthorDiversity(IReadOnlyList<ScoredFeedCandidate> candidates)
    {
        const int windowSize = 6;
        const int maxPostsPerAuthorPerWindow = 2;

        var orderedIds = new List<int>(candidates.Count);
        var deferred = new Queue<ScoredFeedCandidate>();
        var recentAuthors = new Queue<int>();
        var recentAuthorCounts = new Dictionary<int, int>();

        void AddCandidate(ScoredFeedCandidate candidate)
        {
            orderedIds.Add(candidate.PostId);
            recentAuthors.Enqueue(candidate.AuthorId);
            recentAuthorCounts[candidate.AuthorId] =
                recentAuthorCounts.GetValueOrDefault(candidate.AuthorId) + 1;

            if (recentAuthors.Count <= windowSize)
            {
                return;
            }

            var removedAuthorId = recentAuthors.Dequeue();
            var currentCount = recentAuthorCounts.GetValueOrDefault(removedAuthorId) - 1;
            if (currentCount <= 0)
            {
                recentAuthorCounts.Remove(removedAuthorId);
            }
            else
            {
                recentAuthorCounts[removedAuthorId] = currentCount;
            }
        }

        foreach (var candidate in candidates)
        {
            var authorCount = recentAuthorCounts.GetValueOrDefault(candidate.AuthorId);
            if (authorCount >= maxPostsPerAuthorPerWindow)
            {
                deferred.Enqueue(candidate);
                continue;
            }

            AddCandidate(candidate);
        }

        while (deferred.Count > 0)
        {
            AddCandidate(deferred.Dequeue());
        }

        return orderedIds;
    }

    private static double Normalize(double value, double maxValue)
    {
        if (maxValue <= 0)
        {
            return 0;
        }

        return Math.Clamp(value / maxValue, 0, 1);
    }

    private static void NormalizePaging(ref int page, ref int pageSize)
    {
        if (page < 1)
        {
            page = 1;
        }

        if (pageSize < 1 || pageSize > MaxPageSize)
        {
            pageSize = DefaultPageSize;
        }
    }

    private static HashSet<string> ExtractHashtags(string? content)
    {
        if (string.IsNullOrWhiteSpace(content))
        {
            return [];
        }

        return HashtagRegex.Matches(content)
            .Select(match => match.Groups[1].Value.ToLowerInvariant())
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
    }

    private static PostDto MapToDto(Post post, bool isLiked, bool isFollowingAuthor)
    {
        return new PostDto(
            post.Id,
            post.UserId,
            post.User.Username,
            post.User.AvatarUrl,
            post.User.AvatarScale,
            post.User.AvatarOffsetX,
            post.User.AvatarOffsetY,
            post.Content,
            post.ImageUrl,
            post.CreatedAt,
            post.Likes.Count,
            post.Comments.Count,
            isLiked,
            isFollowingAuthor);
    }

    private sealed record FeedCandidateProjection(
        int Id,
        int UserId,
        DateTime CreatedAt,
        string Content,
        bool HasImage,
        int LikesCount,
        int CommentsCount);

    private sealed record FeedScoreParts(
        double RecencyScore,
        double EngagementRaw,
        double RelationshipRaw,
        double InterestScore,
        double TrendingRaw);

    private sealed record ScoredFeedCandidate(
        int PostId,
        int AuthorId,
        double Score,
        DateTime CreatedAt);

    private sealed record InterestPostSample(string Content, bool HasImage);

    private sealed record InterestProfile(
        int SampleCount,
        double ImageAffinity,
        IReadOnlyDictionary<string, int> TopicWeights,
        double TopicNormalizationBase)
    {
        public static InterestProfile Empty { get; } = new(
            0,
            0.5,
            new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase),
            1);
    }
}

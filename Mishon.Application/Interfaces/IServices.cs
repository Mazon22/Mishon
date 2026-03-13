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
    Task<Result<UserProfileDto>> UpdateProfileMediaAsync(int userId, UpdateProfileMediaDto dto);
    Task<Result> LogoutAsync(int userId);
}

public interface IPostService
{
    Task<Result<PostDto>> CreateAsync(int userId, CreatePostDto dto);
    Task<Result<PagedResult<PostDto>>> GetFeedAsync(int userId, int page, int pageSize);
    Task<Result<IEnumerable<PostDto>>> GetUserPostsAsync(int currentUserId, int profileUserId, int page, int pageSize);
    Task<Result<PostDto>> ToggleLikeAsync(int userId, int postId);
    Task<Result<PostDto>> GetPostAsync(int postId, int userId);
    Task<Result> DeleteAsync(int userId, int postId, CancellationToken cancellationToken = default);
}

public interface IFeedService
{
    Task<Result<PagedResult<PostDto>>> GetForYouFeedAsync(
        int userId,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);
    Task<Result<PagedResult<PostDto>>> GetFollowingFeedAsync(
        int userId,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);
    Task WarmForYouFeedAsync(int userId, CancellationToken cancellationToken = default);
}

public interface IFollowService
{
    Task<Result<ToggleFollowResponseDto>> ToggleFollowAsync(int followerId, int followingId);
    Task<Result<IEnumerable<UserFollowDto>>> GetFollowingsAsync(int userId, int currentUserId);
    Task<Result<IEnumerable<UserFollowDto>>> GetFollowersAsync(int userId, int currentUserId);
    Task<Result<bool>> IsFollowingAsync(int followerId, int followingId);
    Task<Result<int>> GetFollowersCountAsync(int userId);
}

public interface ICommentService
{
    Task<Result<CommentDto>> CreateAsync(int userId, int postId, CreateCommentDto dto, CancellationToken cancellationToken = default);
    Task<Result<IEnumerable<CommentDto>>> GetByPostIdAsync(int currentUserId, int postId, CancellationToken cancellationToken = default);
    Task<Result<CommentDto>> UpdateAsync(int userId, int postId, int commentId, UpdateCommentDto dto, CancellationToken cancellationToken = default);
    Task<Result> DeleteAsync(int userId, int postId, int commentId, CancellationToken cancellationToken = default);
}

public interface IUserDiscoveryService
{
    Task<Result<IEnumerable<DiscoverUserDto>>> GetUsersAsync(
        int currentUserId,
        string? query,
        int limit = 24,
        CancellationToken cancellationToken = default);
    Task<Result<UsernameAvailabilityDto>> CheckUsernameAvailabilityAsync(
        int currentUserId,
        string username,
        CancellationToken cancellationToken = default);
}

public interface IFriendService
{
    Task<Result<IEnumerable<FriendDto>>> GetFriendsAsync(int userId, CancellationToken cancellationToken = default);
    Task<Result<IEnumerable<FriendRequestDto>>> GetIncomingRequestsAsync(int userId, CancellationToken cancellationToken = default);
    Task<Result<IEnumerable<FriendRequestDto>>> GetOutgoingRequestsAsync(int userId, CancellationToken cancellationToken = default);
    Task<Result> SendRequestAsync(int userId, int targetUserId, CancellationToken cancellationToken = default);
    Task<Result> AcceptRequestAsync(int userId, int requestId, CancellationToken cancellationToken = default);
    Task<Result> DeleteRequestAsync(int userId, int requestId, CancellationToken cancellationToken = default);
    Task<Result> RemoveFriendAsync(int userId, int friendId, CancellationToken cancellationToken = default);
}

public interface IConversationService
{
    Task<Result<IEnumerable<ConversationDto>>> GetConversationsAsync(int userId, CancellationToken cancellationToken = default);
    Task<Result<DirectConversationDto>> GetOrCreateDirectConversationAsync(int userId, int peerUserId, CancellationToken cancellationToken = default);
    Task<Result<MessagePageDto>> GetMessagesAsync(
        int userId,
        int conversationId,
        int limit = 20,
        int? beforeMessageId = null,
        CancellationToken cancellationToken = default);
    Task<Result<ConversationRealtimeContextDto>> GetRealtimeContextAsync(int userId, int conversationId, CancellationToken cancellationToken = default);
    Task<IReadOnlyCollection<PendingMessageDeliveryDto>> MarkPendingMessagesDeliveredAsync(int userId, CancellationToken cancellationToken = default);
    Task<Result<MessageDto>> SendMessageAsync(int userId, int conversationId, CreateMessageDto dto, CancellationToken cancellationToken = default);
    Task<Result<MessageDto>> UpdateMessageAsync(int userId, int conversationId, int messageId, UpdateMessageDto dto, CancellationToken cancellationToken = default);
    Task<Result<DeleteMessageResultDto>> DeleteMessageAsync(int userId, int conversationId, int messageId, CancellationToken cancellationToken = default);
    Task<Result<DeleteMessageResultDto>> DeleteMessageForAllAsync(int userId, int conversationId, int messageId, CancellationToken cancellationToken = default);
    Task<Result> TogglePinAsync(int userId, int conversationId, bool isPinned, CancellationToken cancellationToken = default);
    Task<Result> ToggleArchiveAsync(int userId, int conversationId, bool isArchived, CancellationToken cancellationToken = default);
    Task<Result> ToggleFavoriteAsync(int userId, int conversationId, bool isFavorite, CancellationToken cancellationToken = default);
    Task<Result> ToggleMuteAsync(int userId, int conversationId, bool isMuted, CancellationToken cancellationToken = default);
    Task<Result<DeleteConversationResultDto>> DeleteConversationAsync(int userId, int conversationId, bool deleteForBoth, CancellationToken cancellationToken = default);
    Task<Result> ClearHistoryAsync(int userId, int conversationId, CancellationToken cancellationToken = default);
}

public interface IBlockService
{
    Task<Result> BlockUserAsync(int blockerId, int blockedUserId, CancellationToken cancellationToken = default);
    Task<Result> UnblockUserAsync(int blockerId, int blockedUserId, CancellationToken cancellationToken = default);
    Task<UserBlockStatusDto> GetStatusAsync(int viewerId, int otherUserId, CancellationToken cancellationToken = default);
    Task<HashSet<int>> GetRestrictedUserIdsAsync(int viewerId, CancellationToken cancellationToken = default);
    Task<bool> AreUsersBlockedAsync(int firstUserId, int secondUserId, CancellationToken cancellationToken = default);
}

public interface INotificationService
{
    Task CreateAsync(CreateNotificationDto notification, CancellationToken cancellationToken = default);
    Task<Result<IEnumerable<NotificationDto>>> GetNotificationsAsync(int userId, CancellationToken cancellationToken = default);
    Task<Result<NotificationSummaryDto>> GetSummaryAsync(int userId, CancellationToken cancellationToken = default);
    Task<Result> MarkAsReadAsync(int userId, int notificationId, CancellationToken cancellationToken = default);
    Task<Result> MarkAllAsReadAsync(int userId, CancellationToken cancellationToken = default);
}

public interface IChatRealtimeNotifier
{
    Task NotifyTypingStartedAsync(int targetUserId, ChatTypingEventDto dto, CancellationToken cancellationToken = default);
    Task NotifyTypingStoppedAsync(int targetUserId, ChatTypingEventDto dto, CancellationToken cancellationToken = default);
    Task NotifyMessageSentAsync(int targetUserId, MessageDto dto, CancellationToken cancellationToken = default);
    Task NotifyMessageReadAsync(int targetUserId, MessageReadEventDto dto, CancellationToken cancellationToken = default);
    Task NotifyMessageDeliveredAsync(int targetUserId, MessageDeliveredEventDto dto, CancellationToken cancellationToken = default);
}

public interface IChatConnectionTracker
{
    void AddConnection(int userId, string connectionId);
    void RemoveConnection(int userId, string connectionId);
    bool IsUserConnected(int userId);
}

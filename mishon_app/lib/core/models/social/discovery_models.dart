class DiscoverUser {
  final int id;
  final String username;
  final String? aboutMe;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final DateTime lastSeenAt;
  final bool isOnline;
  final int followersCount;
  final int postsCount;
  final int mutualFriendsCount;
  final int engagementScore;
  final bool isFollowing;
  final bool isFriend;
  final int? incomingFriendRequestId;
  final int? outgoingFriendRequestId;
  final bool isPrivateAccount;
  final String profileVisibility;
  final bool canViewProfile;
  final bool canSendMessages;
  final bool hasPendingFollowRequest;

  const DiscoverUser({
    required this.id,
    required this.username,
    required this.aboutMe,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.lastSeenAt,
    required this.isOnline,
    required this.followersCount,
    required this.postsCount,
    required this.mutualFriendsCount,
    required this.engagementScore,
    required this.isFollowing,
    required this.isFriend,
    required this.incomingFriendRequestId,
    required this.outgoingFriendRequestId,
    this.isPrivateAccount = false,
    this.profileVisibility = 'Public',
    this.canViewProfile = true,
    this.canSendMessages = true,
    this.hasPendingFollowRequest = false,
  });

  DiscoverUser copyWith({
    String? aboutMe,
    String? avatarUrl,
    double? avatarScale,
    double? avatarOffsetX,
    double? avatarOffsetY,
    DateTime? lastSeenAt,
    bool? isOnline,
    int? followersCount,
    int? postsCount,
    int? mutualFriendsCount,
    int? engagementScore,
    bool? isFollowing,
    bool? isFriend,
    int? incomingFriendRequestId,
    int? outgoingFriendRequestId,
    bool? isPrivateAccount,
    String? profileVisibility,
    bool? canViewProfile,
    bool? canSendMessages,
    bool? hasPendingFollowRequest,
    bool clearIncomingFriendRequestId = false,
    bool clearOutgoingFriendRequestId = false,
  }) {
    return DiscoverUser(
      id: id,
      username: username,
      aboutMe: aboutMe ?? this.aboutMe,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarScale: avatarScale ?? this.avatarScale,
      avatarOffsetX: avatarOffsetX ?? this.avatarOffsetX,
      avatarOffsetY: avatarOffsetY ?? this.avatarOffsetY,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline ?? this.isOnline,
      followersCount: followersCount ?? this.followersCount,
      postsCount: postsCount ?? this.postsCount,
      mutualFriendsCount: mutualFriendsCount ?? this.mutualFriendsCount,
      engagementScore: engagementScore ?? this.engagementScore,
      isFollowing: isFollowing ?? this.isFollowing,
      isFriend: isFriend ?? this.isFriend,
      incomingFriendRequestId:
          clearIncomingFriendRequestId
              ? null
              : incomingFriendRequestId ?? this.incomingFriendRequestId,
      outgoingFriendRequestId:
          clearOutgoingFriendRequestId
              ? null
              : outgoingFriendRequestId ?? this.outgoingFriendRequestId,
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      canViewProfile: canViewProfile ?? this.canViewProfile,
      canSendMessages: canSendMessages ?? this.canSendMessages,
      hasPendingFollowRequest:
          hasPendingFollowRequest ?? this.hasPendingFollowRequest,
    );
  }

  factory DiscoverUser.fromJson(Map<String, dynamic> json) {
    return DiscoverUser(
      id: json['id'] as int,
      username: json['username'] as String,
      aboutMe: json['aboutMe'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1,
      avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0,
      avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0,
      lastSeenAt:
          json['lastSeenAt'] != null
              ? DateTime.parse(json['lastSeenAt'] as String)
              : DateTime.fromMillisecondsSinceEpoch(0),
      isOnline: json['isOnline'] as bool? ?? false,
      followersCount: json['followersCount'] as int? ?? 0,
      postsCount: json['postsCount'] as int? ?? 0,
      mutualFriendsCount: json['mutualFriendsCount'] as int? ?? 0,
      engagementScore: json['engagementScore'] as int? ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
      isFriend: json['isFriend'] as bool? ?? false,
      incomingFriendRequestId: json['incomingFriendRequestId'] as int?,
      outgoingFriendRequestId: json['outgoingFriendRequestId'] as int?,
      isPrivateAccount: json['isPrivateAccount'] as bool? ?? false,
      profileVisibility: json['profileVisibility'] as String? ?? 'Public',
      canViewProfile: json['canViewProfile'] as bool? ?? true,
      canSendMessages: json['canSendMessages'] as bool? ?? true,
      hasPendingFollowRequest:
          json['hasPendingFollowRequest'] as bool? ?? false,
    );
  }
}

class FriendUser {
  final int id;
  final String username;
  final String? aboutMe;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final DateTime lastSeenAt;
  final bool isOnline;

  const FriendUser({
    required this.id,
    required this.username,
    required this.aboutMe,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.lastSeenAt,
    required this.isOnline,
  });

  FriendUser copyWith({
    String? aboutMe,
    String? avatarUrl,
    double? avatarScale,
    double? avatarOffsetX,
    double? avatarOffsetY,
    DateTime? lastSeenAt,
    bool? isOnline,
  }) {
    return FriendUser(
      id: id,
      username: username,
      aboutMe: aboutMe ?? this.aboutMe,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarScale: avatarScale ?? this.avatarScale,
      avatarOffsetX: avatarOffsetX ?? this.avatarOffsetX,
      avatarOffsetY: avatarOffsetY ?? this.avatarOffsetY,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'] as int,
      username: json['username'] as String,
      aboutMe: json['aboutMe'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1,
      avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0,
      avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0,
      lastSeenAt:
          json['lastSeenAt'] != null
              ? DateTime.parse(json['lastSeenAt'] as String)
              : DateTime.fromMillisecondsSinceEpoch(0),
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }
}

class BlockedUserModel {
  final int id;
  final String username;
  final String? aboutMe;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final DateTime lastSeenAt;
  final DateTime blockedAt;

  const BlockedUserModel({
    required this.id,
    required this.username,
    required this.aboutMe,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.lastSeenAt,
    required this.blockedAt,
  });

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    return BlockedUserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      aboutMe: json['aboutMe'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1,
      avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0,
      avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0,
      lastSeenAt:
          json['lastSeenAt'] != null
              ? DateTime.parse(json['lastSeenAt'] as String)
              : DateTime.fromMillisecondsSinceEpoch(0),
      blockedAt: DateTime.parse(json['blockedAt'] as String),
    );
  }
}

class FriendRequestModel {
  final int id;
  final int userId;
  final String username;
  final String? aboutMe;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final DateTime lastSeenAt;
  final bool isOnline;
  final bool isIncoming;
  final DateTime createdAt;

  const FriendRequestModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.aboutMe,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.lastSeenAt,
    required this.isOnline,
    required this.isIncoming,
    required this.createdAt,
  });

  FriendRequestModel copyWith({
    String? aboutMe,
    String? avatarUrl,
    double? avatarScale,
    double? avatarOffsetX,
    double? avatarOffsetY,
    DateTime? lastSeenAt,
    bool? isOnline,
    bool? isIncoming,
    DateTime? createdAt,
  }) {
    return FriendRequestModel(
      id: id,
      userId: userId,
      username: username,
      aboutMe: aboutMe ?? this.aboutMe,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarScale: avatarScale ?? this.avatarScale,
      avatarOffsetX: avatarOffsetX ?? this.avatarOffsetX,
      avatarOffsetY: avatarOffsetY ?? this.avatarOffsetY,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline ?? this.isOnline,
      isIncoming: isIncoming ?? this.isIncoming,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      username: json['username'] as String,
      aboutMe: json['aboutMe'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1,
      avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0,
      avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0,
      lastSeenAt:
          json['lastSeenAt'] != null
              ? DateTime.parse(json['lastSeenAt'] as String)
              : DateTime.fromMillisecondsSinceEpoch(0),
      isOnline: json['isOnline'] as bool? ?? false,
      isIncoming: json['isIncoming'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

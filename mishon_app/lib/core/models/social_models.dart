import 'dart:typed_data';

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

class ConversationModel {
  final int id;
  final int peerId;
  final String username;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final DateTime lastSeenAt;
  final bool isOnline;
  final int? pinOrder;
  final bool isPinned;
  final bool isArchived;
  final bool isFavorite;
  final bool isMuted;
  final bool isBlockedByViewer;
  final bool hasBlockedViewer;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageIsMine;
  final bool lastMessageIsDeliveredToPeer;
  final bool lastMessageIsReadByPeer;
  final int unreadCount;
  final bool canSendMessages;

  const ConversationModel({
    required this.id,
    required this.peerId,
    required this.username,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.lastSeenAt,
    required this.isOnline,
    required this.pinOrder,
    required this.isPinned,
    required this.isArchived,
    required this.isFavorite,
    required this.isMuted,
    required this.isBlockedByViewer,
    required this.hasBlockedViewer,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageIsMine,
    required this.lastMessageIsDeliveredToPeer,
    required this.lastMessageIsReadByPeer,
    required this.unreadCount,
    this.canSendMessages = true,
  });

  ConversationModel copyWith({
    int? pinOrder,
    bool? isPinned,
    bool? isArchived,
    bool? isFavorite,
    bool? isMuted,
    bool? isBlockedByViewer,
    bool? hasBlockedViewer,
    String? lastMessage,
    DateTime? lastMessageAt,
    bool? lastMessageIsMine,
    bool? lastMessageIsDeliveredToPeer,
    bool? lastMessageIsReadByPeer,
    int? unreadCount,
    bool? canSendMessages,
  }) {
    return ConversationModel(
      id: id,
      peerId: peerId,
      username: username,
      avatarUrl: avatarUrl,
      avatarScale: avatarScale,
      avatarOffsetX: avatarOffsetX,
      avatarOffsetY: avatarOffsetY,
      lastSeenAt: lastSeenAt,
      isOnline: isOnline,
      pinOrder: pinOrder ?? this.pinOrder,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isFavorite: isFavorite ?? this.isFavorite,
      isMuted: isMuted ?? this.isMuted,
      isBlockedByViewer: isBlockedByViewer ?? this.isBlockedByViewer,
      hasBlockedViewer: hasBlockedViewer ?? this.hasBlockedViewer,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageIsMine: lastMessageIsMine ?? this.lastMessageIsMine,
      lastMessageIsDeliveredToPeer:
          lastMessageIsDeliveredToPeer ?? this.lastMessageIsDeliveredToPeer,
      lastMessageIsReadByPeer:
          lastMessageIsReadByPeer ?? this.lastMessageIsReadByPeer,
      unreadCount: unreadCount ?? this.unreadCount,
      canSendMessages: canSendMessages ?? this.canSendMessages,
    );
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as int,
      peerId: json['peerId'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1,
      avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0,
      avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0,
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
      isOnline: json['isOnline'] as bool? ?? false,
      pinOrder: json['pinOrder'] as int?,
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
      isBlockedByViewer: json['isBlockedByViewer'] as bool? ?? false,
      hasBlockedViewer: json['hasBlockedViewer'] as bool? ?? false,
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt:
          json['lastMessageAt'] != null
              ? DateTime.parse(json['lastMessageAt'] as String)
              : null,
      lastMessageIsMine: json['lastMessageIsMine'] as bool? ?? false,
      lastMessageIsDeliveredToPeer:
          json['lastMessageIsDeliveredToPeer'] as bool? ?? false,
      lastMessageIsReadByPeer:
          json['lastMessageIsReadByPeer'] as bool? ?? false,
      unreadCount: json['unreadCount'] as int? ?? 0,
      canSendMessages: json['canSendMessages'] as bool? ?? true,
    );
  }
}

class DirectConversationModel {
  final int id;
  final int peerId;
  final String username;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final DateTime lastSeenAt;
  final bool isOnline;
  final bool canSendMessages;

  const DirectConversationModel({
    required this.id,
    required this.peerId,
    required this.username,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.lastSeenAt,
    required this.isOnline,
    this.canSendMessages = true,
  });

  factory DirectConversationModel.fromJson(Map<String, dynamic> json) {
    return DirectConversationModel(
      id: json['id'] as int,
      peerId: json['peerId'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1,
      avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0,
      avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0,
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
      isOnline: json['isOnline'] as bool? ?? false,
      canSendMessages: json['canSendMessages'] as bool? ?? true,
    );
  }
}

class ChatMessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderUsername;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isMine;
  final bool isDeliveredToPeer;
  final DateTime? deliveredToPeerAt;
  final bool isReadByPeer;
  final DateTime? readByPeerAt;
  final int? replyToMessageId;
  final String? replyToSenderUsername;
  final String? replyToContent;
  final int? forwardedFromMessageId;
  final int? forwardedFromUserId;
  final String? forwardedFromSenderUsername;
  final String? forwardedFromUserAvatarUrl;
  final double forwardedFromUserAvatarScale;
  final double forwardedFromUserAvatarOffsetX;
  final double forwardedFromUserAvatarOffsetY;
  final List<ChatAttachmentModel> attachments;
  final bool isHidden;
  final bool isRemoved;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderUsername,
    required this.content,
    required this.createdAt,
    required this.editedAt,
    required this.isMine,
    required this.isDeliveredToPeer,
    required this.deliveredToPeerAt,
    required this.isReadByPeer,
    required this.readByPeerAt,
    required this.replyToMessageId,
    required this.replyToSenderUsername,
    required this.replyToContent,
    required this.forwardedFromMessageId,
    required this.forwardedFromUserId,
    required this.forwardedFromSenderUsername,
    required this.forwardedFromUserAvatarUrl,
    this.forwardedFromUserAvatarScale = 1,
    this.forwardedFromUserAvatarOffsetX = 0,
    this.forwardedFromUserAvatarOffsetY = 0,
    required this.attachments,
    this.isHidden = false,
    this.isRemoved = false,
  });

  ChatMessageModel copyWith({
    int? id,
    int? conversationId,
    int? senderId,
    String? senderUsername,
    String? content,
    DateTime? createdAt,
    DateTime? editedAt,
    bool? isMine,
    bool? isDeliveredToPeer,
    DateTime? deliveredToPeerAt,
    bool? isReadByPeer,
    DateTime? readByPeerAt,
    int? replyToMessageId,
    String? replyToSenderUsername,
    String? replyToContent,
    int? forwardedFromMessageId,
    int? forwardedFromUserId,
    String? forwardedFromSenderUsername,
    String? forwardedFromUserAvatarUrl,
    double? forwardedFromUserAvatarScale,
    double? forwardedFromUserAvatarOffsetX,
    double? forwardedFromUserAvatarOffsetY,
    List<ChatAttachmentModel>? attachments,
    bool? isHidden,
    bool? isRemoved,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      isMine: isMine ?? this.isMine,
      isDeliveredToPeer: isDeliveredToPeer ?? this.isDeliveredToPeer,
      deliveredToPeerAt: deliveredToPeerAt ?? this.deliveredToPeerAt,
      isReadByPeer: isReadByPeer ?? this.isReadByPeer,
      readByPeerAt: readByPeerAt ?? this.readByPeerAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderUsername:
          replyToSenderUsername ?? this.replyToSenderUsername,
      replyToContent: replyToContent ?? this.replyToContent,
      forwardedFromMessageId:
          forwardedFromMessageId ?? this.forwardedFromMessageId,
      forwardedFromUserId: forwardedFromUserId ?? this.forwardedFromUserId,
      forwardedFromSenderUsername:
          forwardedFromSenderUsername ?? this.forwardedFromSenderUsername,
      forwardedFromUserAvatarUrl:
          forwardedFromUserAvatarUrl ?? this.forwardedFromUserAvatarUrl,
      forwardedFromUserAvatarScale:
          forwardedFromUserAvatarScale ?? this.forwardedFromUserAvatarScale,
      forwardedFromUserAvatarOffsetX:
          forwardedFromUserAvatarOffsetX ?? this.forwardedFromUserAvatarOffsetX,
      forwardedFromUserAvatarOffsetY:
          forwardedFromUserAvatarOffsetY ?? this.forwardedFromUserAvatarOffsetY,
      attachments: attachments ?? this.attachments,
      isHidden: isHidden ?? this.isHidden,
      isRemoved: isRemoved ?? this.isRemoved,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as int,
      conversationId: json['conversationId'] as int,
      senderId: json['senderId'] as int,
      senderUsername: json['senderUsername'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      editedAt:
          json['editedAt'] != null
              ? DateTime.parse(json['editedAt'] as String)
              : null,
      isMine: json['isMine'] as bool? ?? false,
      isDeliveredToPeer: json['isDeliveredToPeer'] as bool? ?? false,
      deliveredToPeerAt:
          json['deliveredToPeerAt'] != null
              ? DateTime.parse(json['deliveredToPeerAt'] as String)
              : null,
      isReadByPeer: json['isReadByPeer'] as bool? ?? false,
      readByPeerAt:
          json['readByPeerAt'] != null
              ? DateTime.parse(json['readByPeerAt'] as String)
              : null,
      replyToMessageId: json['replyToMessageId'] as int?,
      replyToSenderUsername: json['replyToSenderUsername'] as String?,
      replyToContent: json['replyToContent'] as String?,
      forwardedFromMessageId: json['forwardedFromMessageId'] as int?,
      forwardedFromUserId: json['forwardedFromUserId'] as int?,
      forwardedFromSenderUsername:
          json['forwardedFromSenderUsername'] as String?,
      forwardedFromUserAvatarUrl: json['forwardedFromUserAvatarUrl'] as String?,
      forwardedFromUserAvatarScale:
          (json['forwardedFromUserAvatarScale'] as num?)?.toDouble() ?? 1,
      forwardedFromUserAvatarOffsetX:
          (json['forwardedFromUserAvatarOffsetX'] as num?)?.toDouble() ?? 0,
      forwardedFromUserAvatarOffsetY:
          (json['forwardedFromUserAvatarOffsetY'] as num?)?.toDouble() ?? 0,
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .map((e) => ChatAttachmentModel.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      isHidden: json['isHidden'] as bool? ?? false,
      isRemoved: json['isRemoved'] as bool? ?? false,
    );
  }
}

class ChatTypingEventModel {
  final int conversationId;
  final int userId;
  final DateTime sentAt;

  const ChatTypingEventModel({
    required this.conversationId,
    required this.userId,
    required this.sentAt,
  });

  factory ChatTypingEventModel.fromJson(Map<String, dynamic> json) {
    return ChatTypingEventModel(
      conversationId: json['conversationId'] as int,
      userId: json['userId'] as int,
      sentAt: DateTime.parse(json['sentAt'] as String),
    );
  }
}

class ChatMessageReadEventModel {
  final int conversationId;
  final int userId;
  final DateTime readAt;

  const ChatMessageReadEventModel({
    required this.conversationId,
    required this.userId,
    required this.readAt,
  });

  factory ChatMessageReadEventModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageReadEventModel(
      conversationId: json['conversationId'] as int,
      userId: json['userId'] as int,
      readAt: DateTime.parse(json['readAt'] as String),
    );
  }
}

class ChatMessageDeliveredEventModel {
  final int conversationId;
  final int messageId;
  final DateTime deliveredAt;

  const ChatMessageDeliveredEventModel({
    required this.conversationId,
    required this.messageId,
    required this.deliveredAt,
  });

  factory ChatMessageDeliveredEventModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageDeliveredEventModel(
      conversationId: json['conversationId'] as int,
      messageId: json['messageId'] as int,
      deliveredAt: DateTime.parse(json['deliveredAt'] as String),
    );
  }
}

class ChatMessagePageModel {
  final List<ChatMessageModel> items;
  final bool hasMore;
  final int? nextBeforeMessageId;

  const ChatMessagePageModel({
    required this.items,
    required this.hasMore,
    required this.nextBeforeMessageId,
  });

  factory ChatMessagePageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessagePageModel(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      hasMore: json['hasMore'] as bool? ?? false,
      nextBeforeMessageId: json['nextBeforeMessageId'] as int?,
    );
  }
}

class ChatAttachmentModel {
  final int id;
  final String fileName;
  final String fileUrl;
  final String contentType;
  final int sizeBytes;
  final bool isImage;

  const ChatAttachmentModel({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.contentType,
    required this.sizeBytes,
    required this.isImage,
  });

  bool get isAudio =>
      contentType.toLowerCase().startsWith('audio/') || _hasAudioExtension;

  bool get isVoiceNote => isAudio;

  bool get _hasAudioExtension {
    final extension =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return const {'wav', 'mp3', 'm4a', 'aac', 'ogg', 'webm', 'opus'}
        .contains(extension);
  }

  factory ChatAttachmentModel.fromJson(Map<String, dynamic> json) {
    return ChatAttachmentModel(
      id: json['id'] as int,
      fileName: json['fileName'] as String,
      fileUrl: json['fileUrl'] as String,
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      isImage: json['isImage'] as bool? ?? false,
    );
  }
}

class ChatUploadAttachment {
  final String fileName;
  final Uint8List bytes;
  final String contentType;
  final bool isImage;

  const ChatUploadAttachment({
    required this.fileName,
    required this.bytes,
    required this.contentType,
    required this.isImage,
  });

  int get sizeBytes => bytes.lengthInBytes;

  bool get isAudio =>
      contentType.toLowerCase().startsWith('audio/') ||
      const {'wav', 'mp3', 'm4a', 'aac', 'ogg', 'webm', 'opus'}
          .contains(
            fileName.contains('.')
                ? fileName.split('.').last.toLowerCase()
                : '',
          );

  bool get isVoiceNote => isAudio;
}

class NotificationItemModel {
  final int id;
  final String type;
  final String text;
  final bool isRead;
  final DateTime createdAt;
  final int? actorUserId;
  final String? actorUsername;
  final String? actorAvatarUrl;
  final double actorAvatarScale;
  final double actorAvatarOffsetX;
  final double actorAvatarOffsetY;
  final int? postId;
  final int? commentId;
  final int? conversationId;
  final int? messageId;
  final int? relatedUserId;

  const NotificationItemModel({
    required this.id,
    required this.type,
    required this.text,
    required this.isRead,
    required this.createdAt,
    required this.actorUserId,
    required this.actorUsername,
    required this.actorAvatarUrl,
    this.actorAvatarScale = 1,
    this.actorAvatarOffsetX = 0,
    this.actorAvatarOffsetY = 0,
    required this.postId,
    required this.commentId,
    required this.conversationId,
    required this.messageId,
    required this.relatedUserId,
  });

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: json['id'] as int,
      type: json['type'] as String,
      text: json['text'] as String,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      actorUserId: json['actorUserId'] as int?,
      actorUsername: json['actorUsername'] as String?,
      actorAvatarUrl: json['actorAvatarUrl'] as String?,
      actorAvatarScale: (json['actorAvatarScale'] as num?)?.toDouble() ?? 1,
      actorAvatarOffsetX: (json['actorAvatarOffsetX'] as num?)?.toDouble() ?? 0,
      actorAvatarOffsetY: (json['actorAvatarOffsetY'] as num?)?.toDouble() ?? 0,
      postId: json['postId'] as int?,
      commentId: json['commentId'] as int?,
      conversationId: json['conversationId'] as int?,
      messageId: json['messageId'] as int?,
      relatedUserId: json['relatedUserId'] as int?,
    );
  }
}

class NotificationSummaryModel {
  final int unreadNotifications;
  final int unreadChats;
  final int incomingFriendRequests;
  final int pendingFollowRequests;

  const NotificationSummaryModel({
    required this.unreadNotifications,
    required this.unreadChats,
    required this.incomingFriendRequests,
    this.pendingFollowRequests = 0,
  });

  int get totalBottomBadges =>
      unreadNotifications +
      unreadChats +
      incomingFriendRequests +
      pendingFollowRequests;

  factory NotificationSummaryModel.fromJson(Map<String, dynamic> json) {
    return NotificationSummaryModel(
      unreadNotifications: json['unreadNotifications'] as int? ?? 0,
      unreadChats: json['unreadChats'] as int? ?? 0,
      incomingFriendRequests: json['incomingFriendRequests'] as int? ?? 0,
      pendingFollowRequests: json['pendingFollowRequests'] as int? ?? 0,
    );
  }
}

class ReportItemModel {
  final int id;
  final String source;
  final String targetType;
  final int targetId;
  final int? targetUserId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final int? assignedModeratorUserId;
  final String? assignedModeratorUsername;

  const ReportItemModel({
    required this.id,
    required this.source,
    required this.targetType,
    required this.targetId,
    required this.targetUserId,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.assignedModeratorUserId,
    required this.assignedModeratorUsername,
  });

  factory ReportItemModel.fromJson(Map<String, dynamic> json) {
    return ReportItemModel(
      id: json['id'] as int,
      source: json['source'] as String,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as int,
      targetUserId: json['targetUserId'] as int?,
      reason: json['reason'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      assignedModeratorUserId: json['assignedModeratorUserId'] as int?,
      assignedModeratorUsername: json['assignedModeratorUsername'] as String?,
    );
  }
}

class ReportDetailModel {
  final int id;
  final String source;
  final String targetType;
  final int targetId;
  final int? targetUserId;
  final String reason;
  final String? customNote;
  final String status;
  final int? reporterUserId;
  final String? reporterUsername;
  final int? assignedModeratorUserId;
  final String? assignedModeratorUsername;
  final String resolution;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  const ReportDetailModel({
    required this.id,
    required this.source,
    required this.targetType,
    required this.targetId,
    required this.targetUserId,
    required this.reason,
    required this.customNote,
    required this.status,
    required this.reporterUserId,
    required this.reporterUsername,
    required this.assignedModeratorUserId,
    required this.assignedModeratorUsername,
    required this.resolution,
    required this.resolutionNote,
    required this.createdAt,
    required this.updatedAt,
    required this.resolvedAt,
  });

  factory ReportDetailModel.fromJson(Map<String, dynamic> json) {
    return ReportDetailModel(
      id: json['id'] as int,
      source: json['source'] as String,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as int,
      targetUserId: json['targetUserId'] as int?,
      reason: json['reason'] as String,
      customNote: json['customNote'] as String?,
      status: json['status'] as String,
      reporterUserId: json['reporterUserId'] as int?,
      reporterUsername: json['reporterUsername'] as String?,
      assignedModeratorUserId: json['assignedModeratorUserId'] as int?,
      assignedModeratorUsername: json['assignedModeratorUsername'] as String?,
      resolution: json['resolution'] as String? ?? 'None',
      resolutionNote: json['resolutionNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      resolvedAt:
          json['resolvedAt'] != null
              ? DateTime.parse(json['resolvedAt'] as String)
              : null,
    );
  }
}

class ModerationActionModel {
  final int id;
  final int actorUserId;
  final String actorUsername;
  final int? targetUserId;
  final String actionType;
  final String? targetType;
  final int? targetId;
  final int? reportId;
  final String? note;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const ModerationActionModel({
    required this.id,
    required this.actorUserId,
    required this.actorUsername,
    required this.targetUserId,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.reportId,
    required this.note,
    required this.createdAt,
    required this.expiresAt,
  });

  factory ModerationActionModel.fromJson(Map<String, dynamic> json) {
    return ModerationActionModel(
      id: json['id'] as int,
      actorUserId: json['actorUserId'] as int,
      actorUsername: json['actorUsername'] as String,
      targetUserId: json['targetUserId'] as int?,
      actionType: json['actionType'] as String,
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as int?,
      reportId: json['reportId'] as int?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt:
          json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'] as String)
              : null,
    );
  }
}

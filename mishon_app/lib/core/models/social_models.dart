class DiscoverUser {
  final int id;
  final String username;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final bool isFollowing;
  final bool isFriend;
  final int? incomingFriendRequestId;
  final int? outgoingFriendRequestId;

  const DiscoverUser({
    required this.id,
    required this.username,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.isFollowing,
    required this.isFriend,
    required this.incomingFriendRequestId,
    required this.outgoingFriendRequestId,
  });

  factory DiscoverUser.fromJson(Map<String, dynamic> json) {
    return DiscoverUser(
      id: json['id'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1,
      avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0,
      avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
      isFriend: json['isFriend'] as bool? ?? false,
      incomingFriendRequestId: json['incomingFriendRequestId'] as int?,
      outgoingFriendRequestId: json['outgoingFriendRequestId'] as int?,
    );
  }
}

class FriendUser {
  final int id;
  final String username;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;

  const FriendUser({
    required this.id,
    required this.username,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1,
      avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0,
      avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FriendRequestModel {
  final int id;
  final int userId;
  final String username;
  final String? avatarUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final bool isIncoming;
  final DateTime createdAt;

  const FriendRequestModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.isIncoming,
    required this.createdAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1,
      avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0,
      avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0,
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
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.peerId,
    required this.username,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as int,
      peerId: json['peerId'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1,
      avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0,
      avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0,
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
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

  const DirectConversationModel({
    required this.id,
    required this.peerId,
    required this.username,
    required this.avatarUrl,
    this.avatarScale = 1,
    this.avatarOffsetX = 0,
    this.avatarOffsetY = 0,
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
  final int? replyToMessageId;
  final String? replyToSenderUsername;
  final String? replyToContent;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderUsername,
    required this.content,
    required this.createdAt,
    required this.editedAt,
    required this.isMine,
    required this.replyToMessageId,
    required this.replyToSenderUsername,
    required this.replyToContent,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as int,
      conversationId: json['conversationId'] as int,
      senderId: json['senderId'] as int,
      senderUsername: json['senderUsername'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'] as String)
          : null,
      isMine: json['isMine'] as bool? ?? false,
      replyToMessageId: json['replyToMessageId'] as int?,
      replyToSenderUsername: json['replyToSenderUsername'] as String?,
      replyToContent: json['replyToContent'] as String?,
    );
  }
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

  const NotificationSummaryModel({
    required this.unreadNotifications,
    required this.unreadChats,
    required this.incomingFriendRequests,
  });

  int get totalBottomBadges =>
      unreadNotifications + unreadChats + incomingFriendRequests;

  factory NotificationSummaryModel.fromJson(Map<String, dynamic> json) {
    return NotificationSummaryModel(
      unreadNotifications: json['unreadNotifications'] as int? ?? 0,
      unreadChats: json['unreadChats'] as int? ?? 0,
      incomingFriendRequests: json['incomingFriendRequests'] as int? ?? 0,
    );
  }
}

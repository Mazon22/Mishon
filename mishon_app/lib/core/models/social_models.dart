class DiscoverUser {
  final int id;
  final String username;
  final String? avatarUrl;
  final bool isFollowing;
  final bool isFriend;
  final int? incomingFriendRequestId;
  final int? outgoingFriendRequestId;

  const DiscoverUser({
    required this.id,
    required this.username,
    required this.avatarUrl,
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

  const FriendUser({
    required this.id,
    required this.username,
    required this.avatarUrl,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class FriendRequestModel {
  final int id;
  final int userId;
  final String username;
  final String? avatarUrl;
  final bool isIncoming;
  final DateTime createdAt;

  const FriendRequestModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.isIncoming,
    required this.createdAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
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
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.peerId,
    required this.username,
    required this.avatarUrl,
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

  const DirectConversationModel({
    required this.id,
    required this.peerId,
    required this.username,
    required this.avatarUrl,
  });

  factory DirectConversationModel.fromJson(Map<String, dynamic> json) {
    return DirectConversationModel(
      id: json['id'] as int,
      peerId: json['peerId'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
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
  final bool isMine;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderUsername,
    required this.content,
    required this.createdAt,
    required this.isMine,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as int,
      conversationId: json['conversationId'] as int,
      senderId: json['senderId'] as int,
      senderUsername: json['senderUsername'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isMine: json['isMine'] as bool? ?? false,
    );
  }
}

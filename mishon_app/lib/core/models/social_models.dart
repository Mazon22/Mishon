import 'dart:typed_data';

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
  final int unreadCount;

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
    required this.unreadCount,
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
    int? unreadCount,
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
      unreadCount: unreadCount ?? this.unreadCount,
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
  final bool isDeliveredToPeer;
  final DateTime? deliveredToPeerAt;
  final bool isReadByPeer;
  final DateTime? readByPeerAt;
  final int? replyToMessageId;
  final String? replyToSenderUsername;
  final String? replyToContent;
  final List<ChatAttachmentModel> attachments;

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
    required this.attachments,
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
    List<ChatAttachmentModel>? attachments,
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
      attachments: attachments ?? this.attachments,
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
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .map((e) => ChatAttachmentModel.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
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
  final bool isImage;

  const ChatUploadAttachment({
    required this.fileName,
    required this.bytes,
    required this.isImage,
  });

  int get sizeBytes => bytes.lengthInBytes;
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

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

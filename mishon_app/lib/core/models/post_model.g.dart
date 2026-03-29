// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Post _$PostFromJson(Map<String, dynamic> json) => Post(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  username: json['username'] as String,
  userAvatarUrl: json['userAvatarUrl'] as String?,
  userAvatarScale: (json['userAvatarScale'] as num?)?.toDouble() ?? 1.0,
  userAvatarOffsetX: (json['userAvatarOffsetX'] as num?)?.toDouble() ?? 0.0,
  userAvatarOffsetY: (json['userAvatarOffsetY'] as num?)?.toDouble() ?? 0.0,
  content: json['content'] as String,
  imageUrl: json['imageUrl'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  likesCount: (json['likesCount'] as num).toInt(),
  commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
  isLiked: json['isLiked'] as bool,
  isFollowingAuthor: json['isFollowingAuthor'] as bool,
  canComment: json['canComment'] as bool? ?? true,
  isHidden: json['isHidden'] as bool? ?? false,
  isRemoved: json['isRemoved'] as bool? ?? false,
);

Map<String, dynamic> _$PostToJson(Post instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'username': instance.username,
  'userAvatarUrl': instance.userAvatarUrl,
  'userAvatarScale': instance.userAvatarScale,
  'userAvatarOffsetX': instance.userAvatarOffsetX,
  'userAvatarOffsetY': instance.userAvatarOffsetY,
  'content': instance.content,
  'imageUrl': instance.imageUrl,
  'createdAt': instance.createdAt.toIso8601String(),
  'likesCount': instance.likesCount,
  'commentsCount': instance.commentsCount,
  'isLiked': instance.isLiked,
  'isFollowingAuthor': instance.isFollowingAuthor,
  'canComment': instance.canComment,
  'isHidden': instance.isHidden,
  'isRemoved': instance.isRemoved,
};

Comment _$CommentFromJson(Map<String, dynamic> json) => Comment(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  username: json['username'] as String,
  userAvatarUrl: json['userAvatarUrl'] as String?,
  userAvatarScale: (json['userAvatarScale'] as num?)?.toDouble() ?? 1.0,
  userAvatarOffsetX: (json['userAvatarOffsetX'] as num?)?.toDouble() ?? 0.0,
  userAvatarOffsetY: (json['userAvatarOffsetY'] as num?)?.toDouble() ?? 0.0,
  content: json['content'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  editedAt:
      json['editedAt'] == null
          ? null
          : DateTime.parse(json['editedAt'] as String),
  parentCommentId: (json['parentCommentId'] as num?)?.toInt(),
  replyToUsername: json['replyToUsername'] as String?,
  isHidden: json['isHidden'] as bool? ?? false,
  isRemoved: json['isRemoved'] as bool? ?? false,
);

Map<String, dynamic> _$CommentToJson(Comment instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'username': instance.username,
  'userAvatarUrl': instance.userAvatarUrl,
  'userAvatarScale': instance.userAvatarScale,
  'userAvatarOffsetX': instance.userAvatarOffsetX,
  'userAvatarOffsetY': instance.userAvatarOffsetY,
  'content': instance.content,
  'createdAt': instance.createdAt.toIso8601String(),
  'editedAt': instance.editedAt?.toIso8601String(),
  'parentCommentId': instance.parentCommentId,
  'replyToUsername': instance.replyToUsername,
  'isHidden': instance.isHidden,
  'isRemoved': instance.isRemoved,
};

Follow _$FollowFromJson(Map<String, dynamic> json) => Follow(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  avatarUrl: json['avatarUrl'] as String?,
  avatarScale: (json['avatarScale'] as num?)?.toDouble() ?? 1.0,
  avatarOffsetX: (json['avatarOffsetX'] as num?)?.toDouble() ?? 0.0,
  avatarOffsetY: (json['avatarOffsetY'] as num?)?.toDouble() ?? 0.0,
  isFollowing: json['isFollowing'] as bool? ?? false,
  isPrivateAccount: json['isPrivateAccount'] as bool? ?? false,
);

Map<String, dynamic> _$FollowToJson(Follow instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'avatarUrl': instance.avatarUrl,
  'avatarScale': instance.avatarScale,
  'avatarOffsetX': instance.avatarOffsetX,
  'avatarOffsetY': instance.avatarOffsetY,
  'isFollowing': instance.isFollowing,
  'isPrivateAccount': instance.isPrivateAccount,
};

ToggleFollowResponse _$ToggleFollowResponseFromJson(
  Map<String, dynamic> json,
) => ToggleFollowResponse(
  isFollowing: json['isFollowing'] as bool,
  followersCount: (json['followersCount'] as num).toInt(),
  isRequested: json['isRequested'] as bool? ?? false,
  requestId: (json['requestId'] as num?)?.toInt(),
);

Map<String, dynamic> _$ToggleFollowResponseToJson(
  ToggleFollowResponse instance,
) => <String, dynamic>{
  'isFollowing': instance.isFollowing,
  'followersCount': instance.followersCount,
  'isRequested': instance.isRequested,
  'requestId': instance.requestId,
};

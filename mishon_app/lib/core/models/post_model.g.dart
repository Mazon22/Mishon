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
  content: json['content'] as String,
  imageUrl: json['imageUrl'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  likesCount: (json['likesCount'] as num).toInt(),
  isLiked: json['isLiked'] as bool,
);

Map<String, dynamic> _$PostToJson(Post instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'username': instance.username,
  'userAvatarUrl': instance.userAvatarUrl,
  'content': instance.content,
  'imageUrl': instance.imageUrl,
  'createdAt': instance.createdAt.toIso8601String(),
  'likesCount': instance.likesCount,
  'isLiked': instance.isLiked,
};

Follow _$FollowFromJson(Map<String, dynamic> json) => Follow(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  avatarUrl: json['avatarUrl'] as String?,
);

Map<String, dynamic> _$FollowToJson(Follow instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'avatarUrl': instance.avatarUrl,
};

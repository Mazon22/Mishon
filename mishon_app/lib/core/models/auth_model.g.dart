// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
  userId: (json['userId'] as num).toInt(),
  username: json['username'] as String,
  email: json['email'] as String,
  token: json['token'] as String,
  refreshToken: json['refreshToken'] as String?,
  refreshTokenExpiry:
      json['refreshTokenExpiry'] == null
          ? null
          : DateTime.parse(json['refreshTokenExpiry'] as String),
);

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'email': instance.email,
      'token': instance.token,
      'refreshToken': instance.refreshToken,
      'refreshTokenExpiry': instance.refreshTokenExpiry?.toIso8601String(),
    };

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  email: json['email'] as String,
  aboutMe: json['aboutMe'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  bannerUrl: json['bannerUrl'] as String?,
  avatarScale: (json['avatarScale'] as num).toDouble(),
  avatarOffsetX: (json['avatarOffsetX'] as num).toDouble(),
  avatarOffsetY: (json['avatarOffsetY'] as num).toDouble(),
  bannerScale: (json['bannerScale'] as num).toDouble(),
  bannerOffsetX: (json['bannerOffsetX'] as num).toDouble(),
  bannerOffsetY: (json['bannerOffsetY'] as num).toDouble(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
  isOnline: json['isOnline'] as bool,
  followersCount: (json['followersCount'] as num).toInt(),
  followingCount: (json['followingCount'] as num).toInt(),
  postsCount: (json['postsCount'] as num).toInt(),
  isFollowing: json['isFollowing'] as bool?,
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'aboutMe': instance.aboutMe,
      'avatarUrl': instance.avatarUrl,
      'bannerUrl': instance.bannerUrl,
      'avatarScale': instance.avatarScale,
      'avatarOffsetX': instance.avatarOffsetX,
      'avatarOffsetY': instance.avatarOffsetY,
      'bannerScale': instance.bannerScale,
      'bannerOffsetX': instance.bannerOffsetX,
      'bannerOffsetY': instance.bannerOffsetY,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastSeenAt': instance.lastSeenAt.toIso8601String(),
      'isOnline': instance.isOnline,
      'followersCount': instance.followersCount,
      'followingCount': instance.followingCount,
      'postsCount': instance.postsCount,
      'isFollowing': instance.isFollowing,
    };

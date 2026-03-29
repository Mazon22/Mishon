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
  accessTokenExpiresAt:
      json['accessTokenExpiresAt'] == null
          ? null
          : DateTime.parse(json['accessTokenExpiresAt'] as String),
  refreshToken: json['refreshToken'] as String?,
  refreshTokenExpiry:
      json['refreshTokenExpiry'] == null
          ? null
          : DateTime.parse(json['refreshTokenExpiry'] as String),
  sessionId: json['sessionId'] as String?,
  emailVerified: json['emailVerified'] as bool? ?? false,
  requiresEmailVerification:
      json['requiresEmailVerification'] as bool? ?? false,
  role: json['role'] as String? ?? 'User',
);

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'email': instance.email,
      'token': instance.token,
      'accessTokenExpiresAt': instance.accessTokenExpiresAt?.toIso8601String(),
      'refreshToken': instance.refreshToken,
      'refreshTokenExpiry': instance.refreshTokenExpiry?.toIso8601String(),
      'sessionId': instance.sessionId,
      'emailVerified': instance.emailVerified,
      'requiresEmailVerification': instance.requiresEmailVerification,
      'role': instance.role,
    };

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  email: json['email'] as String,
  displayName: json['displayName'] as String?,
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
  isBlockedByViewer: json['isBlockedByViewer'] as bool,
  hasBlockedViewer: json['hasBlockedViewer'] as bool,
  isFollowing: json['isFollowing'] as bool?,
  emailVerified: json['emailVerified'] as bool? ?? false,
  role: json['role'] as String? ?? 'User',
  isPrivateAccount: json['isPrivateAccount'] as bool? ?? false,
  profileVisibility: json['profileVisibility'] as String? ?? 'Public',
  messagePrivacy: json['messagePrivacy'] as String? ?? 'Friends',
  commentPrivacy: json['commentPrivacy'] as String? ?? 'Everyone',
  presenceVisibility: json['presenceVisibility'] as String? ?? 'Everyone',
  canViewProfile: json['canViewProfile'] as bool? ?? true,
  canViewPosts: json['canViewPosts'] as bool? ?? true,
  canSendMessages: json['canSendMessages'] as bool? ?? true,
  canComment: json['canComment'] as bool? ?? true,
  canViewPresence: json['canViewPresence'] as bool? ?? true,
  hasPendingFollowRequest: json['hasPendingFollowRequest'] as bool? ?? false,
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'displayName': instance.displayName,
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
      'isBlockedByViewer': instance.isBlockedByViewer,
      'hasBlockedViewer': instance.hasBlockedViewer,
      'isFollowing': instance.isFollowing,
      'emailVerified': instance.emailVerified,
      'role': instance.role,
      'isPrivateAccount': instance.isPrivateAccount,
      'profileVisibility': instance.profileVisibility,
      'messagePrivacy': instance.messagePrivacy,
      'commentPrivacy': instance.commentPrivacy,
      'presenceVisibility': instance.presenceVisibility,
      'canViewProfile': instance.canViewProfile,
      'canViewPosts': instance.canViewPosts,
      'canSendMessages': instance.canSendMessages,
      'canComment': instance.canComment,
      'canViewPresence': instance.canViewPresence,
      'hasPendingFollowRequest': instance.hasPendingFollowRequest,
    };

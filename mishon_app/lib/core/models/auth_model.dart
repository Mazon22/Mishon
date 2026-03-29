import 'package:json_annotation/json_annotation.dart';

part 'auth_model.g.dart';

@JsonSerializable()
class AuthResponse {
  final int userId;
  final String username;
  final String email;
  final String token;
  final DateTime? accessTokenExpiresAt;
  final String? refreshToken;
  final DateTime? refreshTokenExpiry;
  final String? sessionId;
  @JsonKey(defaultValue: false)
  final bool emailVerified;
  @JsonKey(defaultValue: false)
  final bool requiresEmailVerification;
  @JsonKey(defaultValue: 'User')
  final String role;

  AuthResponse({
    required this.userId,
    required this.username,
    required this.email,
    required this.token,
    this.accessTokenExpiresAt,
    this.refreshToken,
    this.refreshTokenExpiry,
    this.sessionId,
    this.emailVerified = false,
    this.requiresEmailVerification = false,
    this.role = 'User',
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  bool get isModerator => role == 'Moderator' || role == 'Admin';
  bool get isAdmin => role == 'Admin';
}

@JsonSerializable()
class UserProfile {
  final int id;
  final String username;
  final String email;
  final String? displayName;
  final String? aboutMe;
  final String? avatarUrl;
  final String? bannerUrl;
  final double avatarScale;
  final double avatarOffsetX;
  final double avatarOffsetY;
  final double bannerScale;
  final double bannerOffsetX;
  final double bannerOffsetY;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool isOnline;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool isBlockedByViewer;
  final bool hasBlockedViewer;
  final bool? isFollowing;
  @JsonKey(defaultValue: false)
  final bool emailVerified;
  @JsonKey(defaultValue: 'User')
  final String role;
  @JsonKey(defaultValue: false)
  final bool isPrivateAccount;
  @JsonKey(defaultValue: 'Public')
  final String profileVisibility;
  @JsonKey(defaultValue: 'Friends')
  final String messagePrivacy;
  @JsonKey(defaultValue: 'Everyone')
  final String commentPrivacy;
  @JsonKey(defaultValue: 'Everyone')
  final String presenceVisibility;
  @JsonKey(defaultValue: true)
  final bool canViewProfile;
  @JsonKey(defaultValue: true)
  final bool canViewPosts;
  @JsonKey(defaultValue: true)
  final bool canSendMessages;
  @JsonKey(defaultValue: true)
  final bool canComment;
  @JsonKey(defaultValue: true)
  final bool canViewPresence;
  @JsonKey(defaultValue: false)
  final bool hasPendingFollowRequest;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.aboutMe,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.avatarScale,
    required this.avatarOffsetX,
    required this.avatarOffsetY,
    required this.bannerScale,
    required this.bannerOffsetX,
    required this.bannerOffsetY,
    required this.createdAt,
    required this.lastSeenAt,
    required this.isOnline,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.isBlockedByViewer,
    required this.hasBlockedViewer,
    this.isFollowing,
    this.emailVerified = false,
    this.role = 'User',
    this.isPrivateAccount = false,
    this.profileVisibility = 'Public',
    this.messagePrivacy = 'Friends',
    this.commentPrivacy = 'Everyone',
    this.presenceVisibility = 'Everyone',
    this.canViewProfile = true,
    this.canViewPosts = true,
    this.canSendMessages = true,
    this.canComment = true,
    this.canViewPresence = true,
    this.hasPendingFollowRequest = false,
  });

  UserProfile copyWith({
    String? username,
    String? email,
    String? displayName,
    String? aboutMe,
    String? avatarUrl,
    String? bannerUrl,
    double? avatarScale,
    double? avatarOffsetX,
    double? avatarOffsetY,
    double? bannerScale,
    double? bannerOffsetX,
    double? bannerOffsetY,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    bool? isOnline,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    bool? isBlockedByViewer,
    bool? hasBlockedViewer,
    bool? isFollowing,
    bool? emailVerified,
    String? role,
    bool? isPrivateAccount,
    String? profileVisibility,
    String? messagePrivacy,
    String? commentPrivacy,
    String? presenceVisibility,
    bool? canViewProfile,
    bool? canViewPosts,
    bool? canSendMessages,
    bool? canComment,
    bool? canViewPresence,
    bool? hasPendingFollowRequest,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      aboutMe: aboutMe ?? this.aboutMe,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      avatarScale: avatarScale ?? this.avatarScale,
      avatarOffsetX: avatarOffsetX ?? this.avatarOffsetX,
      avatarOffsetY: avatarOffsetY ?? this.avatarOffsetY,
      bannerScale: bannerScale ?? this.bannerScale,
      bannerOffsetX: bannerOffsetX ?? this.bannerOffsetX,
      bannerOffsetY: bannerOffsetY ?? this.bannerOffsetY,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline ?? this.isOnline,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      isBlockedByViewer: isBlockedByViewer ?? this.isBlockedByViewer,
      hasBlockedViewer: hasBlockedViewer ?? this.hasBlockedViewer,
      isFollowing: isFollowing ?? this.isFollowing,
      emailVerified: emailVerified ?? this.emailVerified,
      role: role ?? this.role,
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      messagePrivacy: messagePrivacy ?? this.messagePrivacy,
      commentPrivacy: commentPrivacy ?? this.commentPrivacy,
      presenceVisibility: presenceVisibility ?? this.presenceVisibility,
      canViewProfile: canViewProfile ?? this.canViewProfile,
      canViewPosts: canViewPosts ?? this.canViewPosts,
      canSendMessages: canSendMessages ?? this.canSendMessages,
      canComment: canComment ?? this.canComment,
      canViewPresence: canViewPresence ?? this.canViewPresence,
      hasPendingFollowRequest:
          hasPendingFollowRequest ?? this.hasPendingFollowRequest,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);

  bool get isModerator => role == 'Moderator' || role == 'Admin';
  bool get isAdmin => role == 'Admin';
}

class SessionModel {
  final String id;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final String? deviceName;
  final String? platform;
  final String? userAgent;
  final String? ipAddress;
  final bool isCurrent;
  final bool isActive;
  final String? revocationReason;

  const SessionModel({
    required this.id,
    required this.createdAt,
    required this.lastUsedAt,
    required this.expiresAt,
    required this.revokedAt,
    required this.deviceName,
    required this.platform,
    required this.userAgent,
    required this.ipAddress,
    required this.isCurrent,
    required this.isActive,
    required this.revocationReason,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      revokedAt:
          json['revokedAt'] != null
              ? DateTime.parse(json['revokedAt'] as String)
              : null,
      deviceName: json['deviceName'] as String?,
      platform: json['platform'] as String?,
      userAgent: json['userAgent'] as String?,
      ipAddress: json['ipAddress'] as String?,
      isCurrent: json['isCurrent'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      revocationReason: json['revocationReason'] as String?,
    );
  }
}

class PrivacySettings {
  final bool isPrivateAccount;
  final String profileVisibility;
  final String messagePrivacy;
  final String commentPrivacy;
  final String presenceVisibility;

  const PrivacySettings({
    required this.isPrivateAccount,
    required this.profileVisibility,
    required this.messagePrivacy,
    required this.commentPrivacy,
    required this.presenceVisibility,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      isPrivateAccount: json['isPrivateAccount'] as bool? ?? false,
      profileVisibility: json['profileVisibility'] as String? ?? 'Public',
      messagePrivacy: json['messagePrivacy'] as String? ?? 'Friends',
      commentPrivacy: json['commentPrivacy'] as String? ?? 'Everyone',
      presenceVisibility: json['presenceVisibility'] as String? ?? 'Everyone',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isPrivateAccount': isPrivateAccount,
      'profileVisibility': profileVisibility,
      'messagePrivacy': messagePrivacy,
      'commentPrivacy': commentPrivacy,
      'presenceVisibility': presenceVisibility,
    };
  }
}

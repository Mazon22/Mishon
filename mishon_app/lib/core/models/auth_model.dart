import 'package:json_annotation/json_annotation.dart';

part 'auth_model.g.dart';

@JsonSerializable()
class AuthResponse {
  final int userId;
  final String username;
  final String email;
  final String token;
  final String? refreshToken;
  final DateTime? refreshTokenExpiry;

  AuthResponse({
    required this.userId,
    required this.username,
    required this.email,
    required this.token,
    this.refreshToken,
    this.refreshTokenExpiry,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

@JsonSerializable()
class UserProfile {
  final int id;
  final String username;
  final String email;
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
  final bool? isFollowing;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
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
    this.isFollowing,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

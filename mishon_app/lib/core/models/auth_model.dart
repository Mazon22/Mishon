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
  final String? avatarUrl;
  final DateTime createdAt;
  final int followersCount;
  final int followingCount;
  final bool? isFollowing;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.createdAt,
    required this.followersCount,
    required this.followingCount,
    this.isFollowing,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'post_model.g.dart';

@JsonSerializable()
class Post {
  final int id;
  final int userId;
  final String username;
  final String? userAvatarUrl;
  @JsonKey(defaultValue: 1.0)
  final double userAvatarScale;
  @JsonKey(defaultValue: 0.0)
  final double userAvatarOffsetX;
  @JsonKey(defaultValue: 0.0)
  final double userAvatarOffsetY;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;
  final bool isFollowingAuthor;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    this.userAvatarScale = 1.0,
    this.userAvatarOffsetX = 0.0,
    this.userAvatarOffsetY = 0.0,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.likesCount,
    required this.isLiked,
    required this.isFollowingAuthor,
  });

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

  Map<String, dynamic> toJson() => _$PostToJson(this);
  
  Post copyWith({
    int? id,
    int? userId,
    String? username,
    String? userAvatarUrl,
    double? userAvatarScale,
    double? userAvatarOffsetX,
    double? userAvatarOffsetY,
    String? content,
    String? imageUrl,
    DateTime? createdAt,
    int? likesCount,
    bool? isLiked,
    bool? isFollowingAuthor,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      userAvatarScale: userAvatarScale ?? this.userAvatarScale,
      userAvatarOffsetX: userAvatarOffsetX ?? this.userAvatarOffsetX,
      userAvatarOffsetY: userAvatarOffsetY ?? this.userAvatarOffsetY,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      isFollowingAuthor: isFollowingAuthor ?? this.isFollowingAuthor,
    );
  }
}

@JsonSerializable()
class Comment {
  final int id;
  final int userId;
  final String username;
  final String? userAvatarUrl;
  @JsonKey(defaultValue: 1.0)
  final double userAvatarScale;
  @JsonKey(defaultValue: 0.0)
  final double userAvatarOffsetX;
  @JsonKey(defaultValue: 0.0)
  final double userAvatarOffsetY;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int? parentCommentId;
  final String? replyToUsername;

  Comment({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    this.userAvatarScale = 1.0,
    this.userAvatarOffsetX = 0.0,
    this.userAvatarOffsetY = 0.0,
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.parentCommentId,
    this.replyToUsername,
  });

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);

  Map<String, dynamic> toJson() => _$CommentToJson(this);
}

@JsonSerializable()
class Follow {
  final int id;
  final String username;
  final String? avatarUrl;
  @JsonKey(defaultValue: 1.0)
  final double avatarScale;
  @JsonKey(defaultValue: 0.0)
  final double avatarOffsetX;
  @JsonKey(defaultValue: 0.0)
  final double avatarOffsetY;
  final bool isFollowing;

  Follow({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.avatarScale = 1.0,
    this.avatarOffsetX = 0.0,
    this.avatarOffsetY = 0.0,
    this.isFollowing = false,
  });

  factory Follow.fromJson(Map<String, dynamic> json) => _$FollowFromJson(json);

  Map<String, dynamic> toJson() => _$FollowToJson(this);
  
  Follow copyWith({
    int? id,
    String? username,
    String? avatarUrl,
    double? avatarScale,
    double? avatarOffsetX,
    double? avatarOffsetY,
    bool? isFollowing,
  }) {
    return Follow(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarScale: avatarScale ?? this.avatarScale,
      avatarOffsetX: avatarOffsetX ?? this.avatarOffsetX,
      avatarOffsetY: avatarOffsetY ?? this.avatarOffsetY,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

@JsonSerializable()
class ToggleFollowResponse {
  final bool isFollowing;
  final int followersCount;

  ToggleFollowResponse({
    required this.isFollowing,
    required this.followersCount,
  });

  factory ToggleFollowResponse.fromJson(Map<String, dynamic> json) =>
      _$ToggleFollowResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ToggleFollowResponseToJson(this);
}

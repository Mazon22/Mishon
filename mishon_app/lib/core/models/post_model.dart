import 'package:json_annotation/json_annotation.dart';

part 'post_model.g.dart';

@JsonSerializable()
class Post {
  final int id;
  final int userId;
  final String username;
  final String? userAvatarUrl;
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
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    required this.content,
    required this.createdAt,
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
  final bool isFollowing;

  Follow({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.isFollowing = false,
  });

  factory Follow.fromJson(Map<String, dynamic> json) => _$FollowFromJson(json);

  Map<String, dynamic> toJson() => _$FollowToJson(this);
  
  Follow copyWith({
    int? id,
    String? username,
    String? avatarUrl,
    bool? isFollowing,
  }) {
    return Follow(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
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

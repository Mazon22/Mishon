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
  @JsonKey(defaultValue: 0)
  final int commentsCount;
  final bool isLiked;
  final bool isFollowingAuthor;
  @JsonKey(defaultValue: true)
  final bool canComment;
  @JsonKey(defaultValue: false)
  final bool isHidden;
  @JsonKey(defaultValue: false)
  final bool isRemoved;

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
    this.commentsCount = 0,
    required this.isLiked,
    required this.isFollowingAuthor,
    this.canComment = true,
    this.isHidden = false,
    this.isRemoved = false,
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
    int? commentsCount,
    bool? isLiked,
    bool? isFollowingAuthor,
    bool? canComment,
    bool? isHidden,
    bool? isRemoved,
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
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isFollowingAuthor: isFollowingAuthor ?? this.isFollowingAuthor,
      canComment: canComment ?? this.canComment,
      isHidden: isHidden ?? this.isHidden,
      isRemoved: isRemoved ?? this.isRemoved,
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
  @JsonKey(defaultValue: false)
  final bool isHidden;
  @JsonKey(defaultValue: false)
  final bool isRemoved;

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
    this.isHidden = false,
    this.isRemoved = false,
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
  @JsonKey(defaultValue: false)
  final bool isPrivateAccount;

  Follow({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.avatarScale = 1.0,
    this.avatarOffsetX = 0.0,
    this.avatarOffsetY = 0.0,
    this.isFollowing = false,
    this.isPrivateAccount = false,
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
    bool? isPrivateAccount,
  }) {
    return Follow(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarScale: avatarScale ?? this.avatarScale,
      avatarOffsetX: avatarOffsetX ?? this.avatarOffsetX,
      avatarOffsetY: avatarOffsetY ?? this.avatarOffsetY,
      isFollowing: isFollowing ?? this.isFollowing,
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
    );
  }
}

@JsonSerializable()
class ToggleFollowResponse {
  final bool isFollowing;
  final int followersCount;
  @JsonKey(defaultValue: false)
  final bool isRequested;
  final int? requestId;

  ToggleFollowResponse({
    required this.isFollowing,
    required this.followersCount,
    this.isRequested = false,
    this.requestId,
  });

  factory ToggleFollowResponse.fromJson(Map<String, dynamic> json) =>
      _$ToggleFollowResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ToggleFollowResponseToJson(this);
}

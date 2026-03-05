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
  });

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

  Map<String, dynamic> toJson() => _$PostToJson(this);
}

@JsonSerializable()
class Follow {
  final int id;
  final String username;
  final String? avatarUrl;

  Follow({
    required this.id,
    required this.username,
    required this.avatarUrl,
  });

  factory Follow.fromJson(Map<String, dynamic> json) =>
      _$FollowFromJson(json);

  Map<String, dynamic> toJson() => _$FollowToJson(this);
}

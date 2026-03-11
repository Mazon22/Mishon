// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_posts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userPostsHash() => r'b8fc0d36ff691ae8ee413e87a27391c256574724';

/// See also [UserPosts].
@ProviderFor(UserPosts)
final userPostsProvider =
    AutoDisposeAsyncNotifierProvider<UserPosts, List<Post>>.internal(
      UserPosts.new,
      name: r'userPostsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$userPostsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserPosts = AutoDisposeAsyncNotifier<List<Post>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

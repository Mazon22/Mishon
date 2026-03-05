// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$followNotifierHash() => r'a2051bfc55ca63b5b3a4b7bc227c2dd60ff7165d';

/// See also [FollowNotifier].
@ProviderFor(FollowNotifier)
final followNotifierProvider = AutoDisposeNotifierProvider<
  FollowNotifier,
  AsyncValue<Map<int, bool>>
>.internal(
  FollowNotifier.new,
  name: r'followNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$followNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FollowNotifier = AutoDisposeNotifier<AsyncValue<Map<int, bool>>>;
String _$userFollowingListHash() => r'172367fbe93b0757d59d2e732a69523949dbf7fd';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$UserFollowingList
    extends BuildlessAutoDisposeNotifier<AsyncValue<List<Follow>>> {
  late final int userId;

  AsyncValue<List<Follow>> build(int userId);
}

/// See also [UserFollowingList].
@ProviderFor(UserFollowingList)
const userFollowingListProvider = UserFollowingListFamily();

/// See also [UserFollowingList].
class UserFollowingListFamily extends Family<AsyncValue<List<Follow>>> {
  /// See also [UserFollowingList].
  const UserFollowingListFamily();

  /// See also [UserFollowingList].
  UserFollowingListProvider call(int userId) {
    return UserFollowingListProvider(userId);
  }

  @override
  UserFollowingListProvider getProviderOverride(
    covariant UserFollowingListProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userFollowingListProvider';
}

/// See also [UserFollowingList].
class UserFollowingListProvider
    extends
        AutoDisposeNotifierProviderImpl<
          UserFollowingList,
          AsyncValue<List<Follow>>
        > {
  /// See also [UserFollowingList].
  UserFollowingListProvider(int userId)
    : this._internal(
        () => UserFollowingList()..userId = userId,
        from: userFollowingListProvider,
        name: r'userFollowingListProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$userFollowingListHash,
        dependencies: UserFollowingListFamily._dependencies,
        allTransitiveDependencies:
            UserFollowingListFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserFollowingListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final int userId;

  @override
  AsyncValue<List<Follow>> runNotifierBuild(
    covariant UserFollowingList notifier,
  ) {
    return notifier.build(userId);
  }

  @override
  Override overrideWith(UserFollowingList Function() create) {
    return ProviderOverride(
      origin: this,
      override: UserFollowingListProvider._internal(
        () => create()..userId = userId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    UserFollowingList,
    AsyncValue<List<Follow>>
  >
  createElement() {
    return _UserFollowingListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserFollowingListProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserFollowingListRef
    on AutoDisposeNotifierProviderRef<AsyncValue<List<Follow>>> {
  /// The parameter `userId` of this provider.
  int get userId;
}

class _UserFollowingListProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          UserFollowingList,
          AsyncValue<List<Follow>>
        >
    with UserFollowingListRef {
  _UserFollowingListProviderElement(super.provider);

  @override
  int get userId => (origin as UserFollowingListProvider).userId;
}

String _$userFollowersListHash() => r'ccc25f6607db64860debdce52dabfc600e1350d2';

abstract class _$UserFollowersList
    extends BuildlessAutoDisposeNotifier<AsyncValue<List<Follow>>> {
  late final int userId;

  AsyncValue<List<Follow>> build(int userId);
}

/// See also [UserFollowersList].
@ProviderFor(UserFollowersList)
const userFollowersListProvider = UserFollowersListFamily();

/// See also [UserFollowersList].
class UserFollowersListFamily extends Family<AsyncValue<List<Follow>>> {
  /// See also [UserFollowersList].
  const UserFollowersListFamily();

  /// See also [UserFollowersList].
  UserFollowersListProvider call(int userId) {
    return UserFollowersListProvider(userId);
  }

  @override
  UserFollowersListProvider getProviderOverride(
    covariant UserFollowersListProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userFollowersListProvider';
}

/// See also [UserFollowersList].
class UserFollowersListProvider
    extends
        AutoDisposeNotifierProviderImpl<
          UserFollowersList,
          AsyncValue<List<Follow>>
        > {
  /// See also [UserFollowersList].
  UserFollowersListProvider(int userId)
    : this._internal(
        () => UserFollowersList()..userId = userId,
        from: userFollowersListProvider,
        name: r'userFollowersListProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$userFollowersListHash,
        dependencies: UserFollowersListFamily._dependencies,
        allTransitiveDependencies:
            UserFollowersListFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserFollowersListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final int userId;

  @override
  AsyncValue<List<Follow>> runNotifierBuild(
    covariant UserFollowersList notifier,
  ) {
    return notifier.build(userId);
  }

  @override
  Override overrideWith(UserFollowersList Function() create) {
    return ProviderOverride(
      origin: this,
      override: UserFollowersListProvider._internal(
        () => create()..userId = userId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    UserFollowersList,
    AsyncValue<List<Follow>>
  >
  createElement() {
    return _UserFollowersListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserFollowersListProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserFollowersListRef
    on AutoDisposeNotifierProviderRef<AsyncValue<List<Follow>>> {
  /// The parameter `userId` of this provider.
  int get userId;
}

class _UserFollowersListProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          UserFollowersList,
          AsyncValue<List<Follow>>
        >
    with UserFollowersListRef {
  _UserFollowersListProviderElement(super.provider);

  @override
  int get userId => (origin as UserFollowersListProvider).userId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

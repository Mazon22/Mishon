// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$feedNotifierHash() => r'd3b935d00828963a20761548df83afd39febda87';

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

abstract class _$FeedNotifier
    extends BuildlessAutoDisposeNotifier<AsyncValue<List<Post>>> {
  late final FeedTabType feedType;

  AsyncValue<List<Post>> build(FeedTabType feedType);
}

/// See also [FeedNotifier].
@ProviderFor(FeedNotifier)
const feedNotifierProvider = FeedNotifierFamily();

/// See also [FeedNotifier].
class FeedNotifierFamily extends Family<AsyncValue<List<Post>>> {
  /// See also [FeedNotifier].
  const FeedNotifierFamily();

  /// See also [FeedNotifier].
  FeedNotifierProvider call(FeedTabType feedType) {
    return FeedNotifierProvider(feedType);
  }

  @override
  FeedNotifierProvider getProviderOverride(
    covariant FeedNotifierProvider provider,
  ) {
    return call(provider.feedType);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'feedNotifierProvider';
}

/// See also [FeedNotifier].
class FeedNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<FeedNotifier, AsyncValue<List<Post>>> {
  /// See also [FeedNotifier].
  FeedNotifierProvider(FeedTabType feedType)
    : this._internal(
        () => FeedNotifier()..feedType = feedType,
        from: feedNotifierProvider,
        name: r'feedNotifierProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$feedNotifierHash,
        dependencies: FeedNotifierFamily._dependencies,
        allTransitiveDependencies:
            FeedNotifierFamily._allTransitiveDependencies,
        feedType: feedType,
      );

  FeedNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.feedType,
  }) : super.internal();

  final FeedTabType feedType;

  @override
  AsyncValue<List<Post>> runNotifierBuild(covariant FeedNotifier notifier) {
    return notifier.build(feedType);
  }

  @override
  Override overrideWith(FeedNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: FeedNotifierProvider._internal(
        () => create()..feedType = feedType,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        feedType: feedType,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<FeedNotifier, AsyncValue<List<Post>>>
  createElement() {
    return _FeedNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FeedNotifierProvider && other.feedType == feedType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, feedType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FeedNotifierRef
    on AutoDisposeNotifierProviderRef<AsyncValue<List<Post>>> {
  /// The parameter `feedType` of this provider.
  FeedTabType get feedType;
}

class _FeedNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<FeedNotifier, AsyncValue<List<Post>>>
    with FeedNotifierRef {
  _FeedNotifierProviderElement(super.provider);

  @override
  FeedTabType get feedType => (origin as FeedNotifierProvider).feedType;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

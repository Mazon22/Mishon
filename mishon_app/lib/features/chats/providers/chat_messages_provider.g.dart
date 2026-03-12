// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_messages_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatMessagesNotifierHash() =>
    r'4c4a9c5fb8f51cf635d712581f0095042c4bf712';

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

abstract class _$ChatMessagesNotifier
    extends BuildlessAutoDisposeNotifier<ChatMessagesState> {
  late final int conversationId;

  ChatMessagesState build(int conversationId);
}

/// See also [ChatMessagesNotifier].
@ProviderFor(ChatMessagesNotifier)
const chatMessagesNotifierProvider = ChatMessagesNotifierFamily();

/// See also [ChatMessagesNotifier].
class ChatMessagesNotifierFamily extends Family<ChatMessagesState> {
  /// See also [ChatMessagesNotifier].
  const ChatMessagesNotifierFamily();

  /// See also [ChatMessagesNotifier].
  ChatMessagesNotifierProvider call(int conversationId) {
    return ChatMessagesNotifierProvider(conversationId);
  }

  @override
  ChatMessagesNotifierProvider getProviderOverride(
    covariant ChatMessagesNotifierProvider provider,
  ) {
    return call(provider.conversationId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chatMessagesNotifierProvider';
}

/// See also [ChatMessagesNotifier].
class ChatMessagesNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<
          ChatMessagesNotifier,
          ChatMessagesState
        > {
  /// See also [ChatMessagesNotifier].
  ChatMessagesNotifierProvider(int conversationId)
    : this._internal(
        () => ChatMessagesNotifier()..conversationId = conversationId,
        from: chatMessagesNotifierProvider,
        name: r'chatMessagesNotifierProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$chatMessagesNotifierHash,
        dependencies: ChatMessagesNotifierFamily._dependencies,
        allTransitiveDependencies:
            ChatMessagesNotifierFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  ChatMessagesNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final int conversationId;

  @override
  ChatMessagesState runNotifierBuild(covariant ChatMessagesNotifier notifier) {
    return notifier.build(conversationId);
  }

  @override
  Override overrideWith(ChatMessagesNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatMessagesNotifierProvider._internal(
        () => create()..conversationId = conversationId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ChatMessagesNotifier, ChatMessagesState>
  createElement() {
    return _ChatMessagesNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessagesNotifierProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatMessagesNotifierRef
    on AutoDisposeNotifierProviderRef<ChatMessagesState> {
  /// The parameter `conversationId` of this provider.
  int get conversationId;
}

class _ChatMessagesNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          ChatMessagesNotifier,
          ChatMessagesState
        >
    with ChatMessagesNotifierRef {
  _ChatMessagesNotifierProviderElement(super.provider);

  @override
  int get conversationId =>
      (origin as ChatMessagesNotifierProvider).conversationId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

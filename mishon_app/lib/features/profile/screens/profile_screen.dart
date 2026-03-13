import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mishon_app/core/constants/api_constants.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/settings/app_settings_provider.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/empty_posts_banner.dart';
import 'package:mishon_app/core/widgets/fullscreen_image_screen.dart';
import 'package:mishon_app/core/widgets/post_card.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/auth/providers/auth_provider.dart';
import 'package:mishon_app/features/chats/screens/chat_screen.dart';
import 'package:mishon_app/features/comments/screens/comments_screen.dart';
import 'package:mishon_app/features/feed/providers/feed_provider.dart';
import 'package:mishon_app/features/profile/providers/profile_provider.dart';
import 'package:mishon_app/features/profile/screens/profile_media_editor_screen.dart';
import 'package:mishon_app/features/profile/screens/profile_settings_screen.dart';
import 'package:mishon_app/features/profile/screens/profile_setup_screen.dart';
import 'package:mishon_app/features/profile/widgets/follow_tab.dart';

const _kProfileMotionDuration = Duration(milliseconds: 240);
const _kProfileTabBarHeight = 56.0;

class ProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  final bool embeddedInNavigationShell;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.embeddedInNavigationShell = false,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _picker = ImagePicker();

  Timer? _poller;
  bool _isLoading = true;
  bool _isActionBusy = false;
  bool _isMediaBusy = false;
  String? _errorMessage;
  UserProfile? _profile;
  List<Post> _posts = const [];
  int? _currentUserId;

  bool get _isOwnProfile => _currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _poller = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (ref.read(appSettingsProvider).profileAutoRefresh) {
          _loadProfile(silent: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final postRepository = ref.read(postRepositoryProvider);
      final currentUserId = await authRepository.getUserId();
      final profile =
          currentUserId == widget.userId
              ? await authRepository.getProfile()
              : await authRepository.getUserProfile(widget.userId);
      final shouldHidePosts =
          currentUserId != widget.userId &&
          (profile.hasBlockedViewer || profile.isBlockedByViewer);
      final posts =
          shouldHidePosts
              ? const <Post>[]
              : await postRepository.getUserPosts(widget.userId);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserId = currentUserId;
        _profile = profile;
        _posts = posts;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.apiError.message;
        _isLoading = false;
      });
    } on OfflineException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = AppStrings.of(context).couldNotLoadProfile;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null ||
        _isOwnProfile ||
        _profile!.hasBlockedViewer ||
        _profile!.isBlockedByViewer) {
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      final response = await ref
          .read(postRepositoryProvider)
          .toggleFollow(widget.userId);
      if (!mounted || _profile == null) {
        return;
      }

      setState(() {
        _profile = _profile!.copyWith(
          followersCount: response.followersCount,
          isFollowing: response.isFollowing,
        );
      });
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        AppStrings.of(context).couldNotUpdateFollowStatus,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _openChat() async {
    if (_profile == null || _isOwnProfile || _isActionBusy) {
      return;
    }

    if (_profile!.hasBlockedViewer) {
      _showSnackBar(AppStrings.of(context).userBlockedYou, isError: true);
      return;
    }

    if (_profile!.isBlockedByViewer) {
      _showSnackBar(AppStrings.of(context).youBlockedUser, isError: true);
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      final conversation = await ref
          .read(socialRepositoryProvider)
          .getOrCreateConversation(widget.userId);
      if (!mounted) {
        return;
      }

      context.push(
        '/chat',
        extra: ChatScreenArgs(
          conversationId: conversation.id,
          peerId: conversation.peerId,
          peerUsername: conversation.username,
          peerAvatarUrl: conversation.avatarUrl,
          peerAvatarScale: conversation.avatarScale,
          peerAvatarOffsetX: conversation.avatarOffsetX,
          peerAvatarOffsetY: conversation.avatarOffsetY,
          initialIsOnline: conversation.isOnline,
          initialLastSeenAt: conversation.lastSeenAt,
        ),
      );
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(AppStrings.of(context).couldNotOpenChat, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _toggleLike(Post post) async {
    try {
      final updatedPost = await ref
          .read(postRepositoryProvider)
          .toggleLike(post.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _posts = _posts
            .map((item) => item.id == post.id ? updatedPost : item)
            .toList(growable: false);
      });
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(AppStrings.of(context).couldNotUpdateLike, isError: true);
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      await ref.read(postRepositoryProvider).deletePost(postId);
      if (!mounted) {
        return;
      }

      setState(() {
        _posts = _posts
            .where((post) => post.id != postId)
            .toList(growable: false);
        _profile =
            _profile?.copyWith(
              postsCount: (_profile!.postsCount - 1).clamp(0, 999999).toInt(),
            );
      });
      _showSnackBar(AppStrings.of(context).postDeleted);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(AppStrings.of(context).couldNotDeletePost, isError: true);
    }
  }

  Future<void> _pickAndEditMedia(ProfileMediaKind kind) async {
    if (_profile == null || _isMediaBusy) {
      return;
    }

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );

      if (image == null || !mounted) {
        return;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) {
        return;
      }

      final result = await Navigator.of(context).push<ProfileMediaEditResult>(
        MaterialPageRoute(
          builder:
              (_) => ProfileMediaEditorScreen(
                imageBytes: bytes,
                kind: kind,
                initialScale:
                    kind == ProfileMediaKind.avatar
                        ? _profile!.avatarScale
                        : _profile!.bannerScale,
                initialOffsetX:
                    kind == ProfileMediaKind.avatar
                        ? _profile!.avatarOffsetX
                        : _profile!.bannerOffsetX,
                initialOffsetY:
                    kind == ProfileMediaKind.avatar
                        ? _profile!.avatarOffsetY
                        : _profile!.bannerOffsetY,
              ),
        ),
      );

      if (result == null) {
        return;
      }

      await _applyProfileMediaUpdate(
        avatarBytes: kind == ProfileMediaKind.avatar ? result.bytes : null,
        bannerBytes: kind == ProfileMediaKind.banner ? result.bytes : null,
        avatarScale: kind == ProfileMediaKind.avatar ? result.scale : null,
        avatarOffsetX: kind == ProfileMediaKind.avatar ? result.offsetX : null,
        avatarOffsetY: kind == ProfileMediaKind.avatar ? result.offsetY : null,
        bannerScale: kind == ProfileMediaKind.banner ? result.scale : null,
        bannerOffsetX: kind == ProfileMediaKind.banner ? result.offsetX : null,
        bannerOffsetY: kind == ProfileMediaKind.banner ? result.offsetY : null,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(AppStrings.of(context).couldNotPrepareImage, isError: true);
    }
  }

  Future<void> _applyProfileMediaUpdate({
    Uint8List? avatarBytes,
    Uint8List? bannerBytes,
    double? avatarScale,
    double? avatarOffsetX,
    double? avatarOffsetY,
    double? bannerScale,
    double? bannerOffsetX,
    double? bannerOffsetY,
    bool removeAvatar = false,
    bool removeBanner = false,
  }) async {
    if (_profile == null) {
      return;
    }

    setState(() => _isMediaBusy = true);
    try {
      final updatedProfile = await ref
          .read(authRepositoryProvider)
          .updateProfileMedia(
            avatarBytes: avatarBytes,
            bannerBytes: bannerBytes,
            avatarScale: avatarScale ?? _profile!.avatarScale,
            avatarOffsetX: avatarOffsetX ?? _profile!.avatarOffsetX,
            avatarOffsetY: avatarOffsetY ?? _profile!.avatarOffsetY,
            bannerScale: bannerScale ?? _profile!.bannerScale,
            bannerOffsetX: bannerOffsetX ?? _profile!.bannerOffsetX,
            bannerOffsetY: bannerOffsetY ?? _profile!.bannerOffsetY,
            removeAvatar: removeAvatar,
            removeBanner: removeBanner,
          );

      if (!mounted) {
        return;
      }

      setState(() => _profile = updatedProfile);
      ref.invalidate(profileNotifierProvider);
      ref.invalidate(feedNotifierProvider);
      _showSnackBar(AppStrings.of(context).profileMediaUpdated);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        AppStrings.of(context).couldNotUpdateProfileMedia,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isMediaBusy = false);
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (!mounted) {
      return;
    }

    context.go('/login');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted || !isError) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF1F8F52),
      ),
    );
  }

  void _sharePost(Post post) {
    _showSnackBar(AppStrings.of(context).shareNotConfigured(post.username));
  }

  List<Post> get _mediaPosts =>
      _posts.where((post) => _hasMedia(post)).toList(growable: false);

  List<Post> get _likedPosts =>
      _posts.where((post) => post.isLiked).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final motionDuration =
        settings.motionEffects ? _kProfileMotionDuration : Duration.zero;

    return AppShell(
      currentSection: AppSection.profile,
      title: '',
      showAppBar: false,
      showSectionNavigation: !widget.embeddedInNavigationShell,
      child: AnimatedSwitcher(
        duration: motionDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _buildModernBody(context),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLegacyBody(BuildContext context) {
    final strings = AppStrings.of(context);
    final profile = _profile!;
    final isFollowing = profile.isFollowing ?? false;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: Colors.white.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF112244).withValues(alpha: 0.09),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ProfileBanner(
                  imageUrl: profile.bannerUrl,
                  height: 220,
                  scale: profile.bannerScale,
                  offsetX: profile.bannerOffsetX,
                  offsetY: profile.bannerOffsetY,
                  foreground: Stack(
                    children: [
                      Positioned(
                        left: 18,
                        top: 18,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 26,
                  bottom: -44,
                  child: _ProfileAvatarFrame(
                    username: profile.username,
                    imageUrl: profile.avatarUrl,
                    scale: profile.avatarScale,
                    offsetX: profile.avatarOffsetX,
                    offsetY: profile.avatarOffsetY,
                    isOnline: profile.isOnline,
                  ),
                ),
                if (!profile.isOnline)
                  Positioned(
                    left: 128,
                    bottom: -34,
                    child: _PresenceLabel(label: _formatPresenceLabel(profile)),
                  ),
                if (_isOwnProfile)
                  Positioned(
                    right: 18,
                    bottom: 16,
                    child: _HeaderGhostButton(
                      icon: Icons.wallpaper_rounded,
                      label: _isMediaBusy ? 'Saving...' : 'Change banner',
                      onTap:
                          _isMediaBusy
                              ? null
                              : () =>
                                  _pickAndEditMedia(ProfileMediaKind.banner),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 58, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.username,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            profile.email,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF596A82)),
                          ),
                          if ((profile.aboutMe ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              strings.about,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF73839B),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              profile.aboutMe!.trim(),
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                                color: const Color(0xFF485A75),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isOwnProfile)
                      FilledButton.tonalIcon(
                        onPressed: _showEditSheet,
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit'),
                      ),
                  ],
                ),
                if (!_isOwnProfile) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _isActionBusy ? null : _openChat,
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Message'),
                      ),
                      FilledButton.icon(
                        onPressed: _isActionBusy ? null : _toggleFollow,
                        icon:
                            _isActionBusy
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Icon(
                                  isFollowing
                                      ? Icons.check_rounded
                                      : Icons.person_add_alt_1_rounded,
                                ),
                        label: Text(isFollowing ? 'Following' : 'Follow'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(label: 'Posts', value: '${profile.postsCount}'),
                    _StatCard(
                      label: 'Followers',
                      value: '${profile.followersCount}',
                      onTap: () => _showFollowBottomSheet(context, true),
                    ),
                    _StatCard(
                      label: 'Following',
                      value: '${profile.followingCount}',
                      onTap: () => _showFollowBottomSheet(context, false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPostsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                'Posts',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${_posts.length} visible now',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_posts.isEmpty)
          EmptyPostsBanner(
            title: 'No posts yet',
            subtitle:
                _isOwnProfile
                    ? 'Set the tone for your profile with the first post.'
                    : 'This profile has not shared anything yet.',
            icon: Icons.collections_bookmark_outlined,
            ctaText: 'Create post',
            onCtaPressed:
                _isOwnProfile ? () => context.go('/create-post') : null,
            showCta: _isOwnProfile,
          )
        else
          ..._posts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PostCard(
                post: post,
                isOwnPost: _isOwnProfile,
                onLike: () => _toggleLike(post),
                onOpenProfile: () => context.push('/profile/${post.userId}'),
                onComment:
                    () => context.push(
                      '/comments',
                      extra: CommentsScreenArgs(
                        postId: post.id,
                        postUserId: post.userId,
                      ),
                    ),
                onDelete:
                    _isOwnProfile ? () => _showDeleteDialog(post.id) : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRestrictedProfileBody(BuildContext context, UserProfile profile) {
    return RefreshIndicator(
      onRefresh: () => _loadProfile(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ProfileBanner(
                imageUrl: profile.bannerUrl,
                height: 220,
                scale: profile.bannerScale,
                offsetX: profile.bannerOffsetX,
                offsetY: profile.bannerOffsetY,
              ),
              Positioned(
                left: 20,
                top: 20,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap:
                        Navigator.of(context).canPop()
                            ? () => context.pop()
                            : null,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                bottom: -44,
                child: _ProfileAvatarFrame(
                  username: profile.username,
                  imageUrl: profile.avatarUrl,
                  scale: profile.avatarScale,
                  offsetX: profile.avatarOffsetX,
                  offsetY: profile.avatarOffsetY,
                  isOnline: profile.isOnline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10203D).withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    profile.hasBlockedViewer
                        ? Icons.block_rounded
                        : Icons.lock_outline_rounded,
                    color: const Color(0xFF2A5BFF),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.username,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  profile.hasBlockedViewer
                      ? AppStrings.of(context).userBlockedYou
                      : AppStrings.of(context).youBlockedUser,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF63748D),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernBody(BuildContext context) {
    final strings = AppStrings.of(context);

    if (_isLoading) {
      return const LoadingState(key: ValueKey('profile-loading'));
    }

    if (_errorMessage != null) {
      return ErrorState(
        key: const ValueKey('profile-error'),
        message: _errorMessage!,
        onRetry: () => _loadProfile(),
      );
    }

    if (_profile == null) {
      return EmptyState(
        key: const ValueKey('profile-missing'),
        icon: Icons.person_outline_rounded,
        title: strings.profileNotFound,
      );
    }

    final isRestrictedView =
        !_isOwnProfile &&
        (_profile!.hasBlockedViewer || _profile!.isBlockedByViewer);

    if (isRestrictedView) {
      return _buildRestrictedProfileBody(context, _profile!);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final hasBottomNavigation = screenWidth < 1040;
    final contentBottomPadding = hasBottomNavigation ? 112.0 : 28.0;
    final hasBio = (_profile?.aboutMe ?? '').trim().isNotEmpty;
    final baseHeaderHeight =
        screenWidth < 700
            ? 496.0
            : screenWidth < 1200
            ? 526.0
            : 544.0;
    final expandedHeaderHeight =
        baseHeaderHeight +
        (hasBio ? 24.0 : 0.0) +
        (_isOwnProfile ? 0.0 : 36.0) +
        12.0;

    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          return RefreshIndicator(
            onRefresh: () => _loadProfile(),
            edgeOffset: 12,
            child: NestedScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              headerSliverBuilder: (context, innerBoxScrolled) {
                return [
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                    sliver: SliverAppBar(
                      pinned: true,
                      stretch: true,
                      automaticallyImplyLeading: false,
                      backgroundColor: Colors.white.withValues(alpha: 0.94),
                      surfaceTintColor: Colors.transparent,
                      scrolledUnderElevation: 0,
                      expandedHeight: expandedHeaderHeight,
                      leading:
                          Navigator.of(context).canPop()
                              ? Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: _TopBarIconButton(
                                  icon: Icons.arrow_back_ios_new_rounded,
                                  onTap: () => context.pop(),
                                ),
                              )
                              : null,
                      leadingWidth: 60,
                      title:
                          innerBoxScrolled
                              ? _CollapsedProfileTitle(profile: _profile!)
                              : null,
                      titleSpacing: 10,
                      actions: _buildTopBarActions(),
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.parallax,
                        stretchModes: const [StretchMode.zoomBackground],
                        background: _ProfileHeader(
                          profile: _profile!,
                          isOwnProfile: _isOwnProfile,
                          isActionBusy: _isActionBusy,
                          isMediaBusy: _isMediaBusy,
                          onEditProfile: _showEditSheet,
                          onChangeAvatar:
                              _isOwnProfile
                                  ? () =>
                                      _pickAndEditMedia(ProfileMediaKind.avatar)
                                  : null,
                          onChangeBanner:
                              _isOwnProfile
                                  ? () =>
                                      _pickAndEditMedia(ProfileMediaKind.banner)
                                  : null,
                          onOpenChat: _isOwnProfile ? null : _openChat,
                          onToggleFollow: _isOwnProfile ? null : _toggleFollow,
                          onPostsTap:
                              () =>
                                  DefaultTabController.of(context).animateTo(0),
                          onFollowersTap:
                              () => _showFollowBottomSheet(context, true),
                          onFollowingTap:
                              () => _showFollowBottomSheet(context, false),
                          presenceLabel: _formatPresenceLabel(_profile!),
                        ),
                      ),
                      bottom: const _ProfileTabBar(),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _ProfilePostsTab(
                    posts: _posts,
                    isOwnProfile: _isOwnProfile,
                    bottomPadding: contentBottomPadding,
                    onLike: _toggleLike,
                    onDelete: _showDeleteDialog,
                    onComment: _openComments,
                    onOpenProfile: _openAuthorProfile,
                    onShare: _sharePost,
                    onCreatePost:
                        _isOwnProfile ? () => context.go('/create-post') : null,
                  ),
                  _ProfileMediaTab(
                    posts: _mediaPosts,
                    bottomPadding: contentBottomPadding,
                    onOpenPostComments: _openComments,
                  ),
                  _ProfileLikesTab(
                    posts: _likedPosts,
                    bottomPadding: contentBottomPadding,
                    onLike: _toggleLike,
                    onComment: _openComments,
                    onOpenProfile: _openAuthorProfile,
                    onShare: _sharePost,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildTopBarActions() {
    final actions = <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _TopBarIconButton(
          icon: Icons.refresh_rounded,
          onTap: () => _loadProfile(),
        ),
      ),
    ];

    if (_isOwnProfile) {
      actions.insertAll(0, [
        _TopBarIconButton(
          icon: Icons.settings_outlined,
          onTap: _showSettingsScreen,
        ),
        _TopBarIconButton(icon: Icons.logout_rounded, onTap: _showLogoutDialog),
      ]);
    }

    return actions;
  }

  void _openAuthorProfile(Post post) {
    context.push('/profile/${post.userId}');
  }

  void _openComments(Post post) {
    context.push(
      '/comments',
      extra: CommentsScreenArgs(postId: post.id, postUserId: post.userId),
    );
  }

  void _showFollowBottomSheet(BuildContext context, bool showFollowers) {
    final strings = AppStrings.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.66,
            minChildSize: 0.42,
            maxChildSize: 0.92,
            expand: false,
            builder:
                (_, __) => DefaultTabController(
                  length: 2,
                  initialIndex: showFollowers ? 0 : 1,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: strings.followers),
                          Tab(text: strings.following),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            FollowTab(
                              userId: widget.userId,
                              isFollowersTab: true,
                            ),
                            FollowTab(
                              userId: widget.userId,
                              isFollowersTab: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _showEditSheet() async {
    if (_profile == null) {
      return;
    }

    final updatedProfile = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProfileSetupScreen(initialProfile: _profile!),
      ),
    );

    if (!mounted || updatedProfile == null) {
      return;
    }

    setState(() => _profile = updatedProfile);
    ref.invalidate(profileNotifierProvider);
    ref.invalidate(feedNotifierProvider);
    return;
  }

  Future<void> _showSettingsScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
    );
  }

  void _showLogoutDialog() {
    final strings = AppStrings.of(context);

    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(strings.logoutQuestion),
            content: Text(strings.logoutContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _logout();
                },
                child: Text(strings.logout),
              ),
            ],
          ),
    );
  }

  void _showDeleteDialog(int postId) {
    final strings = AppStrings.of(context);

    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(strings.deletePostQuestion),
            content: Text(strings.actionCannotBeUndone),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deletePost(postId);
                },
                child: Text(strings.delete),
              ),
            ],
          ),
    );
  }

  String _formatPresenceLabel(UserProfile profile) {
    final strings = AppStrings.of(context);

    if (profile.isOnline) {
      return strings.online;
    }

    final localLastSeen = profile.lastSeenAt.toLocal();
    final timeLabel = strings.formatShortTime(localLastSeen);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final seenDay = DateTime(
      localLastSeen.year,
      localLastSeen.month,
      localLastSeen.day,
    );
    final dayDifference = today.difference(seenDay).inDays;

    if (dayDifference <= 0) {
      return strings.lastSeenAt(timeLabel);
    }

    if (dayDifference == 1) {
      return strings.lastSeenYesterdayAt(timeLabel);
    }

    return strings.lastSeenDaysAgoAt(dayDifference, timeLabel);
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final bool isOwnProfile;
  final bool isActionBusy;
  final bool isMediaBusy;
  final VoidCallback onEditProfile;
  final VoidCallback? onChangeAvatar;
  final VoidCallback? onChangeBanner;
  final VoidCallback? onOpenChat;
  final VoidCallback? onToggleFollow;
  final VoidCallback onPostsTap;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  final String presenceLabel;

  const _ProfileHeader({
    required this.profile,
    required this.isOwnProfile,
    required this.isActionBusy,
    required this.isMediaBusy,
    required this.onEditProfile,
    required this.onChangeAvatar,
    required this.onChangeBanner,
    required this.onOpenChat,
    required this.onToggleFollow,
    required this.onPostsTap,
    required this.onFollowersTap,
    required this.onFollowingTap,
    required this.presenceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isCompactHeader = width < 700;
    final isCompactControls = width < 900;
    final handle = '@${profile.username.toLowerCase().replaceAll(' ', '')}';
    final bio = (profile.aboutMe ?? '').trim();
    final isFollowing = profile.isFollowing ?? false;
    final bannerHeight = isCompactHeader ? 156.0 : 180.0;
    final avatarOverlap = isCompactHeader ? -40.0 : -48.0;
    final contentTopPadding = isCompactHeader ? 52.0 : 60.0;
    final sectionSpacing = isCompactHeader ? 12.0 : 16.0;
    final actionBottomSpacing = isCompactHeader ? 10.0 : 14.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7FAFF), Color(0xFFF3F7FF)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 8),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: _kProfileMotionDuration,
                    curve: Curves.easeOutCubic,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF10203D,
                          ).withValues(alpha: 0.08),
                          blurRadius: 36,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Hero(
                                tag: 'profile-banner-${profile.id}',
                                child: ProfileBanner(
                                  imageUrl: profile.bannerUrl,
                                  height: bannerHeight,
                                  scale: profile.bannerScale,
                                  offsetX: profile.bannerOffsetX,
                                  offsetY: profile.bannerOffsetY,
                                  borderRadius: BorderRadius.circular(28),
                                  foreground: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(28),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          const Color(
                                            0xFF081226,
                                          ).withValues(alpha: 0.28),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 18,
                                bottom: avatarOverlap,
                                child: Hero(
                                  tag: 'profile-avatar-${profile.id}',
                                  child: _HeaderAvatar(
                                    username: profile.username,
                                    imageUrl: profile.avatarUrl,
                                    scale: profile.avatarScale,
                                    offsetX: profile.avatarOffsetX,
                                    offsetY: profile.avatarOffsetY,
                                    isOnline: profile.isOnline,
                                    onTap: onChangeAvatar,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 16,
                                top: 16,
                                child: AnimatedContainer(
                                  duration: _kProfileMotionDuration,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.24,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    presenceLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              if (onChangeBanner != null)
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: _GlassPillButton(
                                    icon: Icons.wallpaper_rounded,
                                    label:
                                        isMediaBusy
                                            ? strings.saving
                                            : strings.changeBanner,
                                    compact: isCompactControls,
                                    onTap: isMediaBusy ? null : onChangeBanner,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              18,
                              contentTopPadding,
                              18,
                              18,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isCompact =
                                        constraints.maxWidth < 430;
                                    final identity = Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.username,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          handle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.copyWith(
                                            color: const Color(0xFF607089),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    );

                                    if (!isOwnProfile || !isCompact) {
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: identity),
                                          if (isOwnProfile) ...[
                                            const SizedBox(width: 12),
                                            _PrimaryProfileButton(
                                              label: strings.editProfile,
                                              icon: Icons.edit_outlined,
                                              compact: isCompactControls,
                                              onTap: onEditProfile,
                                            ),
                                          ],
                                        ],
                                      );
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        identity,
                                        const SizedBox(height: 12),
                                        _PrimaryProfileButton(
                                          label: strings.editProfile,
                                          icon: Icons.edit_outlined,
                                          compact: isCompactControls,
                                          onTap: onEditProfile,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                if (bio.isNotEmpty) ...[
                                  SizedBox(height: sectionSpacing),
                                  Text(
                                    bio,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF2D3C54),
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                                SizedBox(height: sectionSpacing),
                                if (!isOwnProfile) ...[
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: isCompactHeader ? 8 : 10,
                                    children: [
                                      _SecondaryProfileButton(
                                        label: strings.message,
                                        icon: Icons.chat_bubble_outline_rounded,
                                        compact: isCompactControls,
                                        onTap: isActionBusy ? null : onOpenChat,
                                      ),
                                      _PrimaryProfileButton(
                                        label:
                                            isActionBusy
                                                ? strings.working
                                                : isFollowing
                                                ? strings.followingLabel
                                                : strings.follow,
                                        icon:
                                            isActionBusy
                                                ? Icons.autorenew_rounded
                                                : isFollowing
                                                ? Icons.check_rounded
                                                : Icons
                                                    .person_add_alt_1_rounded,
                                        onTap:
                                            isActionBusy
                                                ? null
                                                : onToggleFollow,
                                        active: isFollowing,
                                        compact: isCompactControls,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: actionBottomSpacing),
                                ],
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final spacing =
                                        constraints.maxWidth < 720 ? 8.0 : 10.0;
                                    final scaleFactor = (constraints.maxWidth /
                                            420)
                                        .clamp(0.72, 1.0);

                                    return Row(
                                      children: [
                                        Expanded(
                                          child: _MetricCard(
                                            label: strings.posts,
                                            value: '${profile.postsCount}',
                                            accent: colorScheme.primary,
                                            compact: scaleFactor < 0.94,
                                            scaleFactor: scaleFactor,
                                            onTap: onPostsTap,
                                          ),
                                        ),
                                        SizedBox(width: spacing),
                                        Expanded(
                                          child: _MetricCard(
                                            label: strings.followers,
                                            value: '${profile.followersCount}',
                                            accent: const Color(0xFF1B8D64),
                                            compact: scaleFactor < 0.94,
                                            scaleFactor: scaleFactor,
                                            onTap: onFollowersTap,
                                          ),
                                        ),
                                        SizedBox(width: spacing),
                                        Expanded(
                                          child: _MetricCard(
                                            label: strings.following,
                                            value: '${profile.followingCount}',
                                            accent: const Color(0xFF8B4DFF),
                                            compact: scaleFactor < 0.94,
                                            scaleFactor: scaleFactor,
                                            onTap: onFollowingTap,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePostsTab extends StatelessWidget {
  final List<Post> posts;
  final bool isOwnProfile;
  final double bottomPadding;
  final Future<void> Function(Post post) onLike;
  final void Function(int postId) onDelete;
  final void Function(Post post) onComment;
  final void Function(Post post) onOpenProfile;
  final void Function(Post post) onShare;
  final VoidCallback? onCreatePost;

  const _ProfilePostsTab({
    required this.posts,
    required this.isOwnProfile,
    required this.bottomPadding,
    required this.onLike,
    required this.onDelete,
    required this.onComment,
    required this.onOpenProfile,
    required this.onShare,
    required this.onCreatePost,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return _ProfileSliverTab(
      storageKey: 'profile-posts-tab',
      bottomPadding: bottomPadding,
      emptyChild: _ProfileTabEmptyState(
        icon: Icons.edit_note_rounded,
        title: strings.noPostsYet,
        subtitle:
            isOwnProfile
                ? strings.firstPostPrompt
                : strings.profileHasNoPosts,
        ctaLabel: isOwnProfile ? strings.createPost : null,
        onTap: onCreatePost,
      ),
      sliver:
          posts.isEmpty
              ? null
              : SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = posts[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == posts.length - 1 ? 0 : 14,
                    ),
                    child: _ProfilePostCard(
                      post: post,
                      isOwnPost: isOwnProfile,
                      onLike: () => onLike(post),
                      onComment: () => onComment(post),
                      onShare: () => onShare(post),
                      onOpenProfile: () => onOpenProfile(post),
                      onDelete: isOwnProfile ? () => onDelete(post.id) : null,
                    ),
                  );
                }, childCount: posts.length),
              ),
    );
  }
}

class _ProfileMediaTab extends StatelessWidget {
  final List<Post> posts;
  final double bottomPadding;
  final void Function(Post post) onOpenPostComments;

  const _ProfileMediaTab({
    required this.posts,
    required this.bottomPadding,
    required this.onOpenPostComments,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 840 ? 3 : 2;
    final strings = AppStrings.of(context);

    return _ProfileSliverTab(
      storageKey: 'profile-media-tab',
      bottomPadding: bottomPadding,
      emptyChild: _ProfileTabEmptyState(
        icon: Icons.photo_library_outlined,
        title: strings.noMediaYet,
        subtitle: strings.mediaWillAppearHere,
      ),
      sliver:
          posts.isEmpty
              ? null
              : SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = posts[index];
                  return _MediaPostTile(
                    post: post,
                    onOpenComments: () => onOpenPostComments(post),
                  );
                }, childCount: posts.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
              ),
    );
  }
}

class _ProfileLikesTab extends StatelessWidget {
  final List<Post> posts;
  final double bottomPadding;
  final Future<void> Function(Post post) onLike;
  final void Function(Post post) onComment;
  final void Function(Post post) onOpenProfile;
  final void Function(Post post) onShare;

  const _ProfileLikesTab({
    required this.posts,
    required this.bottomPadding,
    required this.onLike,
    required this.onComment,
    required this.onOpenProfile,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return _ProfileSliverTab(
      storageKey: 'profile-likes-tab',
      bottomPadding: bottomPadding,
      emptyChild: _ProfileTabEmptyState(
        icon: Icons.favorite_outline_rounded,
        title: strings.nothingLikedYet,
        subtitle: strings.likedPostsWillAppearHere,
      ),
      sliver:
          posts.isEmpty
              ? null
              : SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = posts[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == posts.length - 1 ? 0 : 14,
                    ),
                    child: _ProfilePostCard(
                      post: post,
                      isOwnPost: false,
                      onLike: () => onLike(post),
                      onComment: () => onComment(post),
                      onShare: () => onShare(post),
                      onOpenProfile: () => onOpenProfile(post),
                    ),
                  );
                }, childCount: posts.length),
              ),
    );
  }
}

class _ProfileSliverTab extends StatelessWidget {
  final String storageKey;
  final double bottomPadding;
  final Widget emptyChild;
  final Widget? sliver;

  const _ProfileSliverTab({
    required this.storageKey,
    required this.bottomPadding,
    required this.emptyChild,
    required this.sliver,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: PageStorageKey(storageKey),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          sliver: sliver ?? SliverToBoxAdapter(child: emptyChild),
        ),
      ],
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  final Post post;
  final bool isOwnPost;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onOpenProfile;
  final VoidCallback? onDelete;

  const _ProfilePostCard({
    required this.post,
    required this.isOwnPost,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onOpenProfile,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final dateLabel = strings.formatMonthDay(post.createdAt.toLocal());

    return AnimatedContainer(
      duration: _kProfileMotionDuration,
      curve: Curves.easeOutCubic,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        surfaceTintColor: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.92)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF142847).withValues(alpha: 0.07),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'post-avatar-${post.id}',
                      child: AppAvatar(
                        username: post.username,
                        imageUrl: post.userAvatarUrl,
                        size: 48,
                        scale: post.userAvatarScale,
                        offsetX: post.userAvatarOffsetX,
                        offsetY: post.userAvatarOffsetY,
                        onTap: onOpenProfile,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: onOpenProfile,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      post.username,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '@${post.username.toLowerCase().replaceAll(' ', '')}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF7686A0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateLabel,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF97A4B7),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (onDelete != null)
                      Material(
                        color: Colors.transparent,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: onDelete,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.more_horiz_rounded),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  post.content,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.55,
                    color: const Color(0xFF1B283C),
                  ),
                ),
                if (_hasMedia(post)) ...[
                  const SizedBox(height: 16),
                  _PostMediaPreview(post: post),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _PostActionButton(
                        icon:
                            post.isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                        label: '${post.likesCount}',
                        foreground:
                            post.isLiked
                                ? const Color(0xFFE6466F)
                                : const Color(0xFF5F708A),
                        background:
                            post.isLiked
                                ? const Color(0xFFFFE7ED)
                                : const Color(0xFFF3F5F8),
                        onTap: onLike,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PostActionButton(
                        icon: Icons.mode_comment_outlined,
                        label: '${post.commentsCount}',
                        foreground: const Color(0xFF2A5BFF),
                        background: const Color(0xFFEAF0FF),
                        onTap: onComment,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PostActionButton(
                        icon: Icons.share_outlined,
                        label: strings.share,
                        foreground: const Color(0xFF0E7D68),
                        background: const Color(0xFFE7F8F3),
                        onTap: onShare,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostMediaPreview extends StatelessWidget {
  final Post post;

  const _PostMediaPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolvedImageUrl(post.imageUrl);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullscreenImageScreen(imageUrl: imageUrl),
          ),
        );
      },
      child: Hero(
        tag: 'profile-post-image-${post.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1.35,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder:
                  (context, url) => Container(
                    color: const Color(0xFFF2F5FA),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              errorWidget:
                  (context, url, error) => const ColoredBox(
                    color: Color(0xFFF2F5FA),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 36,
                        color: Color(0xFF90A0B6),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaPostTile extends StatelessWidget {
  final Post post;
  final VoidCallback onOpenComments;

  const _MediaPostTile({required this.post, required this.onOpenComments});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final imageUrl = _resolvedImageUrl(post.imageUrl);

    return AnimatedContainer(
      duration: _kProfileMotionDuration,
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenImageScreen(imageUrl: imageUrl),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'profile-media-${post.id}',
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => const ColoredBox(
                        color: Color(0xFFF2F5FA),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => const ColoredBox(
                        color: Color(0xFFF2F5FA),
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF8C9AB0),
                          ),
                        ),
                      ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF081226).withValues(alpha: 0.64),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            post.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.formatMonthDay(post.createdAt.toLocal()),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onOpenComments,
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.mode_comment_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final String username;
  final String? imageUrl;
  final double scale;
  final double offsetX;
  final double offsetY;
  final bool isOnline;
  final VoidCallback? onTap;

  const _HeaderAvatar({
    required this.username,
    required this.imageUrl,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 104,
        height: 104,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10203D).withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppAvatar(
              username: username,
              imageUrl: imageUrl,
              size: 92,
              scale: scale,
              offsetX: offsetX,
              offsetY: offsetY,
            ),
            if (isOnline)
              Positioned(
                right: 1,
                bottom: 5,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ED573),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ED573).withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;
  final bool compact;
  final double scaleFactor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
    this.compact = false,
    this.scaleFactor = 1,
  });

  @override
  Widget build(BuildContext context) {
    final safeScale = scaleFactor.clamp(0.72, 1.0);
    final horizontalPadding = compact ? 10.0 * safeScale : 14.0 * safeScale;
    final verticalPadding = compact ? 10.0 * safeScale : 14.0 * safeScale;
    final valueFontSize = compact ? 18.0 * safeScale : 22.0 * safeScale;
    final labelFontSize = compact ? 12.0 * safeScale : 13.0 * safeScale;
    final borderRadius = BorderRadius.circular(22);

    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return accent.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.hovered)) {
            return accent.withValues(alpha: 0.04);
          }
          return Colors.transparent;
        }),
        child: AnimatedContainer(
          duration: _kProfileMotionDuration,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(borderRadius: borderRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  fontSize: valueFontSize,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5F708A),
                  fontWeight: FontWeight.w700,
                  fontSize: labelFontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _ProfileTabBar();

  @override
  Size get preferredSize => const Size.fromHeight(_kProfileTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final indicatorInset = width < 360 ? 20.0 : 32.0;
    final strings = AppStrings.of(context);
    const horizontalMargin = 16.0;
    const tabBarRadius = BorderRadius.only(
      bottomLeft: Radius.circular(34),
      bottomRight: Radius.circular(34),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: horizontalMargin),
      child: ClipRRect(
        borderRadius: tabBarRadius,
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          child: SizedBox(
            height: preferredSize.height,
            child: TabBar(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              labelPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: UnderlineTabIndicator(
                borderSide: const BorderSide(width: 3, color: Color(0xFF1D4ED8)),
                insets: EdgeInsets.symmetric(horizontal: indicatorInset),
              ),
              labelColor: const Color(0xFF17263D),
              unselectedLabelColor: const Color(0xFF728198),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              splashBorderRadius: BorderRadius.circular(14),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return const Color(0x141D4ED8);
                }
                if (states.contains(WidgetState.hovered)) {
                  return const Color(0x0F1D4ED8);
                }
                return Colors.transparent;
              }),
              tabs: [
                Tab(height: 46, text: strings.posts),
                Tab(height: 46, text: strings.media),
                Tab(height: 46, text: strings.likes),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedProfileTitle extends StatelessWidget {
  final UserProfile profile;

  const _CollapsedProfileTitle({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(
          username: profile.username,
          imageUrl: profile.avatarUrl,
          size: 34,
          scale: profile.avatarScale,
          offsetX: profile.avatarOffsetX,
          offsetY: profile.avatarOffsetY,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B283C),
                ),
              ),
              Text(
                '@${profile.username.toLowerCase().replaceAll(' ', '')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF728198)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBarIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.88),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 18, color: const Color(0xFF17263D)),
          ),
        ),
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compact;

  const _GlassPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 8 : 10,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: compact ? 16 : 18),
                SizedBox(width: compact ? 6 : 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryProfileButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool compact;

  const _PrimaryProfileButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _kProfileMotionDuration,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF17315A) : const Color(0xFF1D4ED8),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (active ? const Color(0xFF17315A) : const Color(0xFF1D4ED8))
                .withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: compact ? 10 : 12,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: compact ? 16 : 18),
                  SizedBox(width: compact ? 6 : 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 14 : 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryProfileButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;

  const _SecondaryProfileButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _kProfileMotionDuration,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: compact ? 10 : 12,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: const Color(0xFF17315A),
                    size: compact ? 16 : 18,
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF17315A),
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 14 : 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onTap;

  const _ProfileTabEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10203D).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: const Color(0xFF2A5BFF), size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6A7890),
              height: 1.45,
            ),
          ),
          if (ctaLabel != null && onTap != null) ...[
            const SizedBox(height: 18),
            _PrimaryProfileButton(
              label: ctaLabel!,
              icon: Icons.add_rounded,
              onTap: onTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF61728B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: content,
    );
  }
}

class _HeaderGhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _HeaderGhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresenceLabel extends StatelessWidget {
  final String label;

  const _PresenceLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF6B7C96),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProfileAvatarFrame extends StatelessWidget {
  final String username;
  final String? imageUrl;
  final double scale;
  final double offsetX;
  final double offsetY;
  final bool isOnline;

  const _ProfileAvatarFrame({
    required this.username,
    required this.imageUrl,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10203D).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppAvatar(
            username: username,
            imageUrl: imageUrl,
            size: 96,
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY,
          ),
          if (isOnline)
            Positioned(
              right: 1,
              bottom: 6,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF2ED573),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2ED573).withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

bool _hasMedia(Post post) {
  final imageUrl = post.imageUrl;
  return imageUrl != null && imageUrl.isNotEmpty;
}

String _resolvedImageUrl(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return '';
  }

  return imageUrl.startsWith('http')
      ? imageUrl
      : '${ApiConstants.baseUrl.replaceFirst('/api', '')}$imageUrl';
}

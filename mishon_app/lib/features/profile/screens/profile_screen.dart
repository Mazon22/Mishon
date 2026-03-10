import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/empty_posts_banner.dart';
import 'package:mishon_app/core/widgets/post_card.dart';
import 'package:mishon_app/core/widgets/profile_media.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/auth/providers/auth_provider.dart';
import 'package:mishon_app/features/comments/screens/comments_screen.dart';
import 'package:mishon_app/features/feed/providers/feed_provider.dart';
import 'package:mishon_app/features/profile/providers/profile_provider.dart';
import 'package:mishon_app/features/profile/screens/profile_media_editor_screen.dart';
import 'package:mishon_app/features/profile/widgets/follow_tab.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final int userId;

  const ProfileScreen({super.key, required this.userId});

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
    _poller = Timer.periodic(const Duration(seconds: 15), (_) => _loadProfile(silent: true));
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
      final profile = currentUserId == widget.userId
          ? await authRepository.getProfile()
          : await authRepository.getUserProfile(widget.userId);
      final posts = await postRepository.getUserPosts(widget.userId);

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
        _errorMessage = 'Could not load the profile';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isOwnProfile) {
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      final response = await ref.read(postRepositoryProvider).toggleFollow(widget.userId);
      if (!mounted || _profile == null) {
        return;
      }

      setState(() {
        _profile = UserProfile(
          id: _profile!.id,
          username: _profile!.username,
          email: _profile!.email,
          avatarUrl: _profile!.avatarUrl,
          bannerUrl: _profile!.bannerUrl,
          avatarScale: _profile!.avatarScale,
          avatarOffsetX: _profile!.avatarOffsetX,
          avatarOffsetY: _profile!.avatarOffsetY,
          bannerScale: _profile!.bannerScale,
          bannerOffsetX: _profile!.bannerOffsetX,
          bannerOffsetY: _profile!.bannerOffsetY,
          createdAt: _profile!.createdAt,
          followersCount: response.followersCount,
          followingCount: _profile!.followingCount,
          postsCount: _profile!.postsCount,
          isFollowing: response.isFollowing,
        );
      });
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Could not update follow status', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _toggleLike(Post post) async {
    try {
      final updatedPost = await ref.read(postRepositoryProvider).toggleLike(post.id);
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
      _showSnackBar('Could not update the like', isError: true);
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      await ref.read(postRepositoryProvider).deletePost(postId);
      if (!mounted) {
        return;
      }

      setState(() {
        _posts = _posts.where((post) => post.id != postId).toList(growable: false);
        _profile = _profile == null
            ? null
            : UserProfile(
                id: _profile!.id,
                username: _profile!.username,
                email: _profile!.email,
                avatarUrl: _profile!.avatarUrl,
                bannerUrl: _profile!.bannerUrl,
                avatarScale: _profile!.avatarScale,
                avatarOffsetX: _profile!.avatarOffsetX,
                avatarOffsetY: _profile!.avatarOffsetY,
                bannerScale: _profile!.bannerScale,
                bannerOffsetX: _profile!.bannerOffsetX,
                bannerOffsetY: _profile!.bannerOffsetY,
                createdAt: _profile!.createdAt,
                followersCount: _profile!.followersCount,
                followingCount: _profile!.followingCount,
                postsCount: (_profile!.postsCount - 1).clamp(0, 999999).toInt(),
                isFollowing: _profile!.isFollowing,
              );
      });
      _showSnackBar('Post deleted');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Could not delete the post', isError: true);
    }
  }

  Future<void> _updateProfile(String username) async {
    try {
      final updatedProfile = await ref.read(authRepositoryProvider).updateProfile(username: username);
      if (!mounted) {
        return;
      }

      setState(() => _profile = updatedProfile);
      ref.invalidate(profileNotifierProvider);
      _showSnackBar('Profile updated');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Could not update the profile', isError: true);
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
          builder: (_) => ProfileMediaEditorScreen(
            imageBytes: bytes,
            kind: kind,
            initialScale: kind == ProfileMediaKind.avatar ? _profile!.avatarScale : _profile!.bannerScale,
            initialOffsetX: kind == ProfileMediaKind.avatar ? _profile!.avatarOffsetX : _profile!.bannerOffsetX,
            initialOffsetY: kind == ProfileMediaKind.avatar ? _profile!.avatarOffsetY : _profile!.bannerOffsetY,
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
      _showSnackBar('Could not prepare the image', isError: true);
    }
  }

  Future<void> _removeAvatar() async {
    await _applyProfileMediaUpdate(removeAvatar: true);
  }

  Future<void> _removeBanner() async {
    await _applyProfileMediaUpdate(removeBanner: true);
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
      final updatedProfile = await ref.read(authRepositoryProvider).updateProfileMedia(
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
      _showSnackBar('Profile media updated');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Could not update profile media', isError: true);
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
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentSection: AppSection.profile,
      title: _isOwnProfile ? 'Profile studio' : 'Profile',
      actions: [
        if (_isOwnProfile && !_isLoading)
          IconButton(
            onPressed: _showEditSheet,
            icon: const Icon(Icons.tune_rounded),
          ),
        if (_isOwnProfile && !_isLoading)
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout_rounded),
          ),
      ],
      child: _isLoading
          ? const LoadingState()
          : _errorMessage != null
              ? ErrorState(
                  message: _errorMessage!,
                  onRetry: () => _loadProfile(),
                )
              : _profile == null
                  ? const EmptyState(
                      icon: Icons.person_outline_rounded,
                      title: 'Profile not found',
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadProfile(),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          _buildProfileHero(context),
                          const SizedBox(height: 18),
                          _buildPostsSection(context),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildProfileHero(BuildContext context) {
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
                        top: 18,
                        right: 18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                          ),
                          child: Text(
                            _isOwnProfile ? 'Your signature look' : 'Profile cover',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
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
                  child: Stack(
                    children: [
                      Container(
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
                        child: AppAvatar(
                          username: profile.username,
                          imageUrl: profile.avatarUrl,
                          size: 96,
                          scale: profile.avatarScale,
                          offsetX: profile.avatarOffsetX,
                          offsetY: profile.avatarOffsetY,
                        ),
                      ),
                      if (_isOwnProfile)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: _MediaIconButton(
                            icon: Icons.photo_camera_outlined,
                            onTap: _isMediaBusy ? null : () => _pickAndEditMedia(ProfileMediaKind.avatar),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isOwnProfile)
                  Positioned(
                    right: 18,
                    bottom: 16,
                    child: _HeaderGhostButton(
                      icon: Icons.wallpaper_rounded,
                      label: _isMediaBusy ? 'Saving...' : 'Change banner',
                      onTap: _isMediaBusy ? null : () => _pickAndEditMedia(ProfileMediaKind.banner),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.username,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            profile.email,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF596A82),
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isOwnProfile
                                ? 'Build your corner of the network with a bold cover, clean avatar, and sharp posts.'
                                : 'A public profile with posts, comments, and a live presence in the feed.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                  color: const Color(0xFF485A75),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (_isOwnProfile)
                      FilledButton.tonalIcon(
                        onPressed: _showEditSheet,
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _isActionBusy ? null : _toggleFollow,
                        icon: _isActionBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded),
                        label: Text(isFollowing ? 'Following' : 'Follow'),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      label: 'Posts',
                      value: '${profile.postsCount}',
                    ),
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
            subtitle: _isOwnProfile
                ? 'Set the tone for your profile with the first post.'
                : 'This profile has not shared anything yet.',
            icon: Icons.collections_bookmark_outlined,
            ctaText: 'Create post',
            onCtaPressed: _isOwnProfile ? () => context.go('/create-post') : null,
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
                onComment: () => context.push(
                  '/comments',
                  extra: CommentsScreenArgs(
                    postId: post.id,
                    postUserId: post.userId,
                  ),
                ),
                onDelete: _isOwnProfile ? () => _showDeleteDialog(post.id) : null,
              ),
            ),
          ),
      ],
    );
  }

  void _showFollowBottomSheet(BuildContext context, bool showFollowers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.66,
        minChildSize: 0.42,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, __) => DefaultTabController(
          length: 2,
          initialIndex: showFollowers ? 0 : 1,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Followers'),
                  Tab(text: 'Following'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    FollowTab(userId: widget.userId, isFollowersTab: true),
                    FollowTab(userId: widget.userId, isFollowersTab: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet() {
    final controller = TextEditingController(text: _profile?.username ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile setup',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Update the public look of your profile and the way your images sit in the frame.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SheetActionButton(
                      icon: Icons.account_circle_outlined,
                      label: 'Change avatar',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndEditMedia(ProfileMediaKind.avatar);
                      },
                    ),
                    _SheetActionButton(
                      icon: Icons.wallpaper_rounded,
                      label: 'Change banner',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndEditMedia(ProfileMediaKind.banner);
                      },
                    ),
                    _SheetActionButton(
                      icon: Icons.hide_image_outlined,
                      label: 'Remove avatar',
                      onTap: _profile?.avatarUrl == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              _removeAvatar();
                            },
                    ),
                    _SheetActionButton(
                      icon: Icons.layers_clear_outlined,
                      label: 'Remove banner',
                      onTap: _profile?.bannerUrl == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              _removeBanner();
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final username = controller.text.trim();
                          Navigator.pop(context);
                          if (username.isNotEmpty && username != _profile?.username) {
                            await _updateProfile(username);
                          }
                        },
                        child: const Text('Save name'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be taken back to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _logout();
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int postId) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePost(postId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    this.onTap,
  });

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

class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SheetActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
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

class _MediaIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _MediaIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF15223B),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

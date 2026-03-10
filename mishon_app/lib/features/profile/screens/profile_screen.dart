import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/models/auth_model.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/repositories/auth_repository.dart';
import 'package:mishon_app/core/repositories/post_repository.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/empty_posts_banner.dart';
import 'package:mishon_app/core/widgets/post_card.dart';
import 'package:mishon_app/core/widgets/states.dart';
import 'package:mishon_app/features/auth/providers/auth_provider.dart';
import 'package:mishon_app/features/comments/screens/comments_screen.dart';
import 'package:mishon_app/features/profile/widgets/follow_tab.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final int userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Timer? _poller;
  bool _isLoading = true;
  bool _isActionBusy = false;
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

      if (!mounted) return;
      setState(() {
        _currentUserId = currentUserId;
        _profile = profile;
        _posts = posts;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.apiError.message;
        _isLoading = false;
      });
    } on OfflineException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Не удалось загрузить профиль';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isOwnProfile) return;

    setState(() => _isActionBusy = true);
    try {
      final response = await ref.read(postRepositoryProvider).toggleFollow(widget.userId);
      if (!mounted || _profile == null) return;

      setState(() {
        _profile = UserProfile(
          id: _profile!.id,
          username: _profile!.username,
          email: _profile!.email,
          avatarUrl: _profile!.avatarUrl,
          createdAt: _profile!.createdAt,
          followersCount: response.followersCount,
          followingCount: _profile!.followingCount,
          isFollowing: response.isFollowing,
        );
      });
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось обновить подписку', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _toggleLike(Post post) async {
    try {
      final updatedPost = await ref.read(postRepositoryProvider).toggleLike(post.id);
      if (!mounted) return;

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
      _showSnackBar('Не удалось обновить лайк', isError: true);
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      await ref.read(postRepositoryProvider).deletePost(postId);
      if (!mounted) return;
      setState(() {
        _posts = _posts.where((post) => post.id != postId).toList(growable: false);
      });
      _showSnackBar('Пост удален');
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } on OfflineException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось удалить пост', isError: true);
    }
  }

  Future<void> _updateProfile(String username) async {
    try {
      await ref.read(authRepositoryProvider).updateProfile(username: username);
      await _loadProfile(silent: true);
    } on ApiException catch (e) {
      _showSnackBar(e.apiError.message, isError: true);
    } catch (_) {
      _showSnackBar('Не удалось обновить профиль', isError: true);
    }
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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
      title: 'Профиль',
      actions: [
        if (_isOwnProfile && !_isLoading)
          IconButton(
            onPressed: _showEditDialog,
            icon: const Icon(Icons.edit_outlined),
          ),
        if (_isOwnProfile && !_isLoading)
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout),
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
                      icon: Icons.person_outline,
                      title: 'Профиль не найден',
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadProfile(),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          _buildProfileCard(context),
                          const SizedBox(height: 16),
                          Text(
                            'Посты',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (_posts.isEmpty)
                            EmptyPostsBanner(
                              title: 'Постов пока нет',
                              subtitle: _isOwnProfile
                                  ? 'Создайте первый пост и он появится здесь.'
                                  : 'Пользователь еще ничего не публиковал.',
                              icon: Icons.collections_bookmark_outlined,
                              ctaText: 'Создать пост',
                              onCtaPressed: _isOwnProfile ? () => context.go('/create-post') : null,
                              showCta: _isOwnProfile,
                            )
                          else
                            ..._posts.map(
                              (post) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: PostCard(
                                  post: post,
                                  isOwnPost: _isOwnProfile,
                                  onLike: () => _toggleLike(post),
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
                      ),
                    ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final profile = _profile!;
    final isFollowing = profile.isFollowing ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: profile.avatarUrl!,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      profile.username.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              profile.username,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(profile.email),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _InfoBadge(
                  label: 'В сети с',
                  value: profile.createdAt.toLocal().toString().split(' ').first,
                ),
                _InfoBadge(
                  label: 'Подписчики',
                  value: '${profile.followersCount}',
                  onTap: () => _showFollowBottomSheet(context, true),
                ),
                _InfoBadge(
                  label: 'Подписки',
                  value: '${profile.followingCount}',
                  onTap: () => _showFollowBottomSheet(context, false),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!_isOwnProfile)
              FilledButton.icon(
                onPressed: _isActionBusy ? null : _toggleFollow,
                icon: _isActionBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isFollowing ? Icons.check : Icons.person_add_alt_1),
                label: Text(isFollowing ? 'Подписка оформлена' : 'Подписаться'),
              ),
          ],
        ),
      ),
    );
  }

  void _showFollowBottomSheet(BuildContext context, bool showFollowers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, __) => DefaultTabController(
          length: 2,
          initialIndex: showFollowers ? 0 : 1,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Подписчики'),
                  Tab(text: 'Подписки'),
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

  void _showEditDialog() {
    final controller = TextEditingController(text: _profile?.username ?? '');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить имя'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Username',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final username = controller.text.trim();
              Navigator.pop(context);
              if (username.isNotEmpty) {
                await _updateProfile(username);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти?'),
        content: const Text('Вы будете перенаправлены на экран входа.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _logout();
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int postId) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пост?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePost(postId);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoBadge({
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: content,
    );
  }
}

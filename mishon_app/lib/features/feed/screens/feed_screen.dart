import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/post_card.dart';
import 'package:mishon_app/features/comments/screens/comments_screen.dart';
import 'package:mishon_app/features/feed/providers/feed_provider.dart';
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';

import '../../auth/providers/auth_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _poller = Timer.periodic(const Duration(seconds: 12), (_) {
      ref.read(feedNotifierProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedNotifierProvider);
    final userIdAsync = ref.watch(userIdProvider);
    final notificationSummary = ref
        .watch(notificationSummaryProvider)
        .maybeWhen(
          data: (value) => value,
          orElse:
              () => const NotificationSummaryModel(
                unreadNotifications: 0,
                unreadChats: 0,
                incomingFriendRequests: 0,
              ),
        );

    final posts = feedState.valueOrNull ?? const <Post>[];
    final isInitialLoading = feedState.isLoading && posts.isEmpty;
    final blockingError = feedState.hasError && posts.isEmpty;
    final inlineError = feedState.hasError && posts.isNotEmpty;

    return AppShell(
      currentSection: AppSection.feed,
      title: 'Feed',
      showAppBar: false,
      maxContentWidth: 760,
      bodyDecoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F8FF), Color(0xFFF0EEFF), Color(0xFFEAF4FF)],
        ),
      ),
      backgroundLayers: const [
        Positioned(
          top: -120,
          left: -80,
          child: _FeedGlowOrb(
            size: 260,
            colors: [Color(0xFFB5D8FF), Color(0x33B5D8FF)],
          ),
        ),
        Positioned(
          bottom: -140,
          right: -60,
          child: _FeedGlowOrb(
            size: 280,
            colors: [Color(0xFFD4C4FF), Color(0x33D4C4FF)],
          ),
        ),
        Positioned(
          top: 120,
          right: -40,
          child: _FeedGlowOrb(
            size: 180,
            colors: [Color(0xFFF4D8FF), Color(0x22F4D8FF)],
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-post'),
        elevation: 10,
        highlightElevation: 14,
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        foregroundColor: const Color(0xFF18243C),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFFDCE5F5))),
        label: Text(
          'Post',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF18243C),
          ),
        ),
        icon: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF4A8DFF), Color(0xFF7468FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
        ),
      ),
      child: RefreshIndicator(
        onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
        edgeOffset: 92,
        color: const Color(0xFF4A8DFF),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: false,
              toolbarHeight: 76,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.74),
                      border: const Border(
                        bottom: BorderSide(color: Color(0xFFE5ECF7)),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F162033),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title:
                  feedState.isRefreshing
                      ? const Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      )
                      : null,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _FeedNotificationButton(
                    count: notificationSummary.unreadNotifications,
                    onTap: () => context.push('/notifications'),
                  ),
                ),
              ],
            ),
            if (isInitialLoading) const _FeedSkeletonSliver(),
            if (blockingError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _FeedMessageState(
                  icon: Icons.wifi_tethering_error_rounded,
                  title: 'Couldn\'t load the feed',
                  subtitle: _getErrorMessage(feedState.error),
                  actionLabel: 'Try again',
                  onAction:
                      () => ref.read(feedNotifierProvider.notifier).refresh(),
                ),
              ),
            if (!isInitialLoading && !blockingError && posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _FeedMessageState(
                  icon: Icons.dynamic_feed_outlined,
                  title: 'Your feed is quiet',
                  subtitle:
                      'Follow people or publish your first post to start the conversation.',
                  actionLabel: 'Create post',
                  onAction: () => context.go('/create-post'),
                ),
              ),
            if (!isInitialLoading && posts.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _FeedSectionHeader(
                    title: 'Latest posts',
                    subtitle:
                        inlineError
                            ? 'Showing your last loaded posts. Pull to try again.'
                            : 'Fresh updates from people in your network.',
                    isError: inlineError,
                  ),
                ),
              ),
              if (inlineError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _FeedInlineErrorBanner(
                      message: _getErrorMessage(feedState.error),
                      onRetry:
                          () =>
                              ref.read(feedNotifierProvider.notifier).refresh(),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final post = posts[index];
                    final currentUserId = userIdAsync.value;
                    final isOwnPost =
                        currentUserId != null && currentUserId == post.userId;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == posts.length - 1 ? 0 : 14,
                      ),
                      child: PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        isOwnPost: isOwnPost,
                        onLike:
                            () => ref
                                .read(feedNotifierProvider.notifier)
                                .toggleLike(post.id),
                        onFollow:
                            isOwnPost
                                ? null
                                : () => ref
                                    .read(feedNotifierProvider.notifier)
                                    .toggleFollow(post.userId),
                        onOpenProfile:
                            () => context.push('/profile/${post.userId}'),
                        onComment:
                            () => context.push(
                              '/comments',
                              extra: CommentsScreenArgs(
                                postId: post.id,
                                postUserId: post.userId,
                              ),
                            ),
                        onShare: () => _showSharePlaceholder(context, post),
                      ),
                    );
                  }, childCount: posts.length),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static void _showSharePlaceholder(BuildContext context, Post post) {
    final handle = _buildHandle(post.username);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share for @$handle is not connected yet.')),
    );
  }

  static String _buildHandle(String username) {
    final handle = username.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]+'),
      '',
    );
    return handle.isEmpty ? 'mishon' : handle;
  }

  static String _getErrorMessage(Object? error) {
    if (error is String) {
      if (error.contains('Р')) {
        return 'Check your connection and try again.';
      }
      return error;
    }
    if (error is OfflineException) {
      return 'No internet connection right now.';
    }
    return 'Something went wrong while loading your feed.';
  }
}

class _FeedGlowOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _FeedGlowOrb({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _FeedNotificationButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FeedNotificationButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE5F5)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: Color(0xFF18243C),
                ),
              ),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A5BFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
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

class _FeedSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isError;

  const _FeedSectionHeader({
    required this.title,
    required this.subtitle,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EBF7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color:
                  isError ? const Color(0xFFFFF1F4) : const Color(0xFFF1F5FF),
            ),
            child: Icon(
              isError ? Icons.sync_problem_rounded : Icons.auto_awesome_rounded,
              size: 18,
              color:
                  isError ? const Color(0xFFD83B67) : const Color(0xFF4A67FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF18243C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedInlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FeedInlineErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDADF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFD83B67),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF9E234A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _FeedMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _FeedMessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE4EBF7)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12162033),
                  blurRadius: 26,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFFF2F6FF),
                  ),
                  child: Icon(icon, size: 28, color: const Color(0xFF4A67FF)),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF18243C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(actionLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF1FF),
                    foregroundColor: const Color(0xFF1F52FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

class _FeedSkeletonSliver extends StatelessWidget {
  const _FeedSkeletonSliver();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: EdgeInsets.only(bottom: index == 3 ? 0 : 14),
            child: const _FeedSkeletonCard(),
          ),
          childCount: 4,
        ),
      ),
    );
  }
}

class _FeedSkeletonCard extends StatefulWidget {
  const _FeedSkeletonCard();

  @override
  State<_FeedSkeletonCard> createState() => _FeedSkeletonCardState();
}

class _FeedSkeletonCardState extends State<_FeedSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color =
            Color.lerp(
              const Color(0xFFE9EEF8),
              const Color(0xFFF4F7FC),
              _controller.value,
            )!;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4EBF7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12162033),
                blurRadius: 22,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SkeletonBox(color: color, width: 48, height: 48, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(
                          color: color,
                          width: double.infinity,
                          height: 12,
                          radius: 8,
                        ),
                        const SizedBox(height: 8),
                        _SkeletonBox(
                          color: color,
                          width: 140,
                          height: 10,
                          radius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SkeletonBox(
                color: color,
                width: double.infinity,
                height: 12,
                radius: 8,
              ),
              const SizedBox(height: 10),
              _SkeletonBox(
                color: color,
                width: double.infinity,
                height: 12,
                radius: 8,
              ),
              const SizedBox(height: 10),
              _SkeletonBox(color: color, width: 220, height: 12, radius: 8),
              const SizedBox(height: 16),
              _SkeletonBox(
                color: color,
                width: double.infinity,
                height: 210,
                radius: 18,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SkeletonBox(
                      color: color,
                      width: double.infinity,
                      height: 18,
                      radius: 8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SkeletonBox(
                      color: color,
                      width: double.infinity,
                      height: 18,
                      radius: 8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SkeletonBox(
                      color: color,
                      width: double.infinity,
                      height: 18,
                      radius: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.color,
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

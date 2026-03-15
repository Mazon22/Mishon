import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/post_card.dart';
import 'package:mishon_app/features/comments/screens/comments_screen.dart';
import 'package:mishon_app/features/feed/providers/feed_provider.dart';
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  final bool embeddedInNavigationShell;

  const FeedScreen({super.key, this.embeddedInNavigationShell = false});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _tabController;

  FeedTabType get _currentFeedType =>
      _tabController.index == 0 ? FeedTabType.forYou : FeedTabType.following;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: FeedTabType.values.length,
      vsync: this,
    )..addListener(() {
      if (_tabController.indexIsChanging) {
        return;
      }

      unawaited(
        ref
            .read(feedNotifierProvider(_currentFeedType).notifier)
            .ensureLoaded(),
      );
    });
    Future<void>.microtask(
      () =>
          ref
              .read(feedNotifierProvider(_currentFeedType).notifier)
              .ensureLoaded(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = AppStrings.of(context);
    final shellBottomInset =
        widget.embeddedInNavigationShell &&
                MediaQuery.sizeOf(context).width < 1040
            ? 92.0
            : 0.0;
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

    return AppShell(
      currentSection: AppSection.feed,
      title: strings.feed,
      showAppBar: false,
      showSectionNavigation: !widget.embeddedInNavigationShell,
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
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: shellBottomInset),
        child: FloatingActionButton.extended(
          onPressed: () => context.go('/create-post'),
          elevation: 10,
          highlightElevation: 14,
          backgroundColor: Colors.white.withValues(alpha: 0.96),
          foregroundColor: const Color(0xFF18243C),
          extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
          shape: const StadiumBorder(
            side: BorderSide(color: Color(0xFFDCE5F5)),
          ),
          label: Text(
            strings.postShort,
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
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _FeedGlassHeader(
              tabController: _tabController,
              notificationCount: notificationSummary.unreadNotifications,
              onOpenNotifications: () => context.push('/notifications'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: const [
                _FeedTimeline(feedType: FeedTabType.forYou),
                _FeedTimeline(feedType: FeedTabType.following),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showSharePlaceholder(BuildContext context, Post post) {
    // Intentionally silent: informational snackbars are disabled.
  }

  static String _getErrorMessage(BuildContext context, Object? error) {
    final strings = AppStrings.of(context);
    if (error is String) {
      if (error == 'feed_load_failed') {
        return strings.feedLoadGenericError;
      }
      if (error.contains('Р ')) {
        return strings.feedCheckConnection;
      }
      return error;
    }
    if (error is OfflineException) {
      return strings.noInternetConnectionRightNow;
    }
    return strings.feedLoadGenericError;
  }
}

class _FeedGlassHeader extends StatelessWidget {
  final TabController tabController;
  final int notificationCount;
  final VoidCallback onOpenNotifications;

  const _FeedGlassHeader({
    required this.tabController,
    required this.notificationCount,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE5ECF7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12162033),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.feed,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF18243C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.feedSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _FeedNotificationButton(
                    count: notificationCount,
                    onTap: onOpenNotifications,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDCE5F5)),
                ),
                child: TabBar(
                  controller: tabController,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A8DFF), Color(0xFF7468FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F4A67FF),
                        blurRadius: 12,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  tabs:
                      FeedTabType.values.map((feedType) {
                        final label =
                            feedType == FeedTabType.forYou
                                ? strings.forYou
                                : strings.following;
                        return Tab(text: label);
                      }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedTimeline extends ConsumerWidget {
  final FeedTabType feedType;

  const _FeedTimeline({required this.feedType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final feedState = ref.watch(feedNotifierProvider(feedType));
    final currentUserId = ref.watch(currentUserIdProvider);

    final posts = feedState.valueOrNull ?? const <Post>[];
    final isInitialLoading = feedState.isLoading && posts.isEmpty;
    final blockingError = feedState.hasError && posts.isEmpty;
    final inlineError = feedState.hasError && posts.isNotEmpty;

    final title =
        feedType == FeedTabType.forYou ? strings.forYou : strings.following;
    final subtitle =
        feedType == FeedTabType.forYou
            ? strings.forYouFeedDescription
            : strings.followingFeedDescription;

    final emptyTitle =
        feedType == FeedTabType.forYou
            ? strings.feedRecommendationsWarmupTitle
            : strings.feedFollowingEmptyTitle;
    final emptySubtitle =
        feedType == FeedTabType.forYou
            ? strings.feedRecommendationsWarmupSubtitle
            : strings.feedFollowingEmptySubtitle;

    return RefreshIndicator(
      onRefresh:
          () => ref.read(feedNotifierProvider(feedType).notifier).refresh(),
      edgeOffset: 16,
      color: const Color(0xFF4A8DFF),
      child: CustomScrollView(
        key: PageStorageKey<String>('feed-${feedType.name}'),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _FeedSectionHeader(
                title: title,
                subtitle:
                    inlineError ? strings.feedShowingCachedPosts : subtitle,
                isError: inlineError,
              ),
            ),
          ),
          if (isInitialLoading) const _FeedSkeletonSliver(),
          if (blockingError)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _FeedMessageState(
                icon: Icons.wifi_tethering_error_rounded,
                title: strings.feedLoadFailedTitle,
                subtitle: _FeedScreenState._getErrorMessage(
                  context,
                  feedState.error,
                ),
                actionLabel: strings.retry,
                onAction:
                    () =>
                        ref
                            .read(feedNotifierProvider(feedType).notifier)
                            .refresh(),
              ),
            ),
          if (!isInitialLoading && !blockingError && posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _FeedMessageState(
                icon:
                    feedType == FeedTabType.forYou
                        ? Icons.auto_awesome_rounded
                        : Icons.people_outline_rounded,
                title: emptyTitle,
                subtitle: emptySubtitle,
                actionLabel: strings.createPost,
                onAction: () => context.go('/create-post'),
              ),
            ),
          if (!isInitialLoading && posts.isNotEmpty) ...[
            if (inlineError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _FeedInlineErrorBanner(
                    message: _FeedScreenState._getErrorMessage(
                      context,
                      feedState.error,
                    ),
                    onRetry:
                        () =>
                            ref
                                .read(feedNotifierProvider(feedType).notifier)
                                .refresh(),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = posts[index];
                  final isOwnPost =
                      currentUserId != null && currentUserId == post.userId;

                  ref
                      .read(feedNotifierProvider(feedType).notifier)
                      .maybePrefetchNextPage(index, posts.length);

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == posts.length - 1 ? 0 : 14,
                    ),
                    child: PostCard(
                      key: ValueKey('${feedType.name}-${post.id}'),
                      post: post,
                      isOwnPost: isOwnPost,
                      onLike:
                          () => ref
                              .read(feedNotifierProvider(feedType).notifier)
                              .toggleLike(post.id),
                      onFollow:
                          isOwnPost
                              ? null
                              : () => ref
                                  .read(feedNotifierProvider(feedType).notifier)
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
                      onShare:
                          () => _FeedScreenState._showSharePlaceholder(
                            context,
                            post,
                          ),
                    ),
                  );
                }, childCount: posts.length),
              ),
            ),
          ],
        ],
      ),
    );
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
    final strings = AppStrings.of(context);
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
          TextButton(onPressed: onRetry, child: Text(strings.retry)),
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

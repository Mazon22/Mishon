import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/post_model.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/network/exceptions.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';
import 'package:mishon_app/core/theme/app_tokens.dart';
import 'package:mishon_app/core/theme/app_theme.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/core/widgets/minimal_components.dart';
import 'package:mishon_app/core/widgets/post_card.dart';
import 'package:mishon_app/core/widgets/report_dialog.dart';
import 'package:mishon_app/features/chats/utils/chat_post_share.dart';
import 'package:mishon_app/features/comments/screens/comments_screen_args.dart';
import 'package:mishon_app/features/feed/providers/feed_provider.dart';
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  final bool embeddedInNavigationShell;

  const FeedScreen({super.key, this.embeddedInNavigationShell = false});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

Future<void> _reportPostFromFeed(
  BuildContext context,
  WidgetRef ref,
  Post post,
) async {
  final strings = AppStrings.of(context);
  final draft = await showReportDialog(
    context,
    title: strings.reportTargetPostTitle,
  );
  if (draft == null) {
    return;
  }

  try {
    await ref
        .read(socialRepositoryProvider)
        .createReport(
          targetType: 'Post',
          targetId: post.id,
          reason: draft.reason,
          customNote: draft.note,
        );
    if (!context.mounted) {
      return;
    }
    showAppToast(context, message: strings.reportSubmitted);
  } on ApiException catch (error) {
    if (!context.mounted) {
      return;
    }
    showAppToast(context, message: error.apiError.message, isError: true);
  } on OfflineException catch (error) {
    if (!context.mounted) {
      return;
    }
    showAppToast(context, message: error.message, isError: true);
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    showAppToast(context, message: strings.operationError, isError: true);
  }
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
      bodyDecoration: const BoxDecoration(color: AppColors.background),
      backgroundLayers: const [],
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

    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      radius: AppRadii.xl,
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
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.feedSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _FeedNotificationButton(
                count: notificationCount,
                onTap: onOpenNotifications,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.divider),
            ),
            child: TabBar(
              controller: tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                gradient: AppGradients.profile,
                boxShadow: AppShadows.soft(color: AppColors.profile),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
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
          if (!blockingError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _FeedDiscoveryPanel(feedType: feedType, posts: posts),
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
                          () => unawaited(
                            sharePostToChat(
                              context: context,
                              ref: ref,
                              post: post,
                            ),
                          ),
                      onReport:
                          isOwnPost
                              ? null
                              : () => _reportPostFromFeed(context, ref, post),
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
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      color: Colors.white.withValues(alpha: 0.92),
      borderColor: AppColors.divider,
      boxShadow: const [],
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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
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
}

class _FeedDiscoveryPanel extends StatelessWidget {
  final FeedTabType feedType;
  final List<Post> posts;

  const _FeedDiscoveryPanel({required this.feedType, required this.posts});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final chipData = _buildFeedDiscoveryChips(posts, strings, feedType);
    final isForYou = feedType == FeedTabType.forYou;
    final title =
        isForYou
            ? (strings.isRu ? 'Подобрано для вас' : 'Picked for you')
            : (strings.isRu ? 'В вашей сети' : 'Inside your circle');
    final subtitle =
        isForYou
            ? (strings.isRu
                ? 'Свежие темы, люди и быстрые входы в то, что сейчас набирает отклик.'
                : 'Fresh topics, people, and quick entries into what is resonating right now.')
            : (strings.isRu
                ? 'Следите за ритмом своих подписок и возвращайтесь к активным обсуждениям.'
                : 'Keep up with your network and jump back into active conversations.');
    final countLabel =
        isForYou
            ? (strings.isRu
                ? '${posts.length} рекомендаций'
                : '${posts.length} recommendations')
            : (strings.isRu
                ? '${posts.length} свежих постов'
                : '${posts.length} fresh posts');

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      color: Colors.white.withValues(alpha: 0.96),
      borderColor: const Color(0xFFE4EBF7),
      boxShadow: AppShadows.soft(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isForYou ? AppColors.feed : AppColors.friends)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isForYou
                      ? Icons.auto_awesome_rounded
                      : Icons.people_alt_rounded,
                  color: isForYou ? AppColors.feed : AppColors.friends,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  countLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isForYou ? AppColors.feed : AppColors.friends,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: chipData
                .map((chip) => _FeedDiscoveryChip(data: chip))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _FeedDiscoveryChip extends StatelessWidget {
  final _FeedDiscoveryChipData data;

  const _FeedDiscoveryChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: data.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 16, color: data.foreground),
          const SizedBox(width: 8),
          Text(
            data.label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: data.foreground),
          ),
        ],
      ),
    );
  }
}

class _FeedDiscoveryChipData {
  final IconData icon;
  final String label;
  final Color background;
  final Color border;
  final Color foreground;

  const _FeedDiscoveryChipData({
    required this.icon,
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });
}

List<_FeedDiscoveryChipData> _buildFeedDiscoveryChips(
  List<Post> posts,
  AppStrings strings,
  FeedTabType feedType,
) {
  final chips = <_FeedDiscoveryChipData>[];
  final seenLabels = <String>{};

  void addChip({
    required IconData icon,
    required String label,
    required Color background,
    required Color border,
    required Color foreground,
  }) {
    final normalized = label.trim().toLowerCase();
    if (normalized.isEmpty ||
        !seenLabels.add(normalized) ||
        chips.length >= 4) {
      return;
    }

    chips.add(
      _FeedDiscoveryChipData(
        icon: icon,
        label: label,
        background: background,
        border: border,
        foreground: foreground,
      ),
    );
  }

  final hashtagPattern = RegExp(r'#([A-Za-z0-9_]+)');
  for (final post in posts) {
    for (final match in hashtagPattern.allMatches(post.content)) {
      if (chips.length >= 4) {
        break;
      }
      final tag = match.group(1);
      if (tag == null || tag.isEmpty) {
        continue;
      }
      addChip(
        icon: Icons.local_fire_department_rounded,
        label: '#$tag',
        background: const Color(0xFFFFF3EC),
        border: const Color(0xFFFFDFC8),
        foreground: const Color(0xFFC56A28),
      );
    }
  }

  for (final post in posts) {
    if (chips.length >= 4) {
      break;
    }
    addChip(
      icon:
          feedType == FeedTabType.forYou
              ? Icons.person_search_rounded
              : Icons.favorite_border_rounded,
      label: '@${post.username}',
      background:
          feedType == FeedTabType.forYou
              ? AppColors.feedSoft
              : AppColors.friendsSoft,
      border:
          feedType == FeedTabType.forYou
              ? const Color(0xFFD6E3FF)
              : const Color(0xFFD7F3E0),
      foreground:
          feedType == FeedTabType.forYou ? AppColors.feed : AppColors.friends,
    );
  }

  if (chips.length < 4) {
    final fallbacks =
        feedType == FeedTabType.forYou
            ? [
              (
                icon: Icons.bolt_rounded,
                label: strings.isRu ? 'Быстрые реакции' : 'Quick reactions',
                background: const Color(0xFFF0EDFF),
                border: const Color(0xFFE0D8FF),
                foreground: AppColors.profile,
              ),
              (
                icon: Icons.trending_up_rounded,
                label: strings.isRu ? 'Рост обсуждений' : 'Trending now',
                background: const Color(0xFFEFF7FF),
                border: const Color(0xFFDCE8FF),
                foreground: AppColors.chats,
              ),
            ]
            : [
              (
                icon: Icons.schedule_rounded,
                label: strings.isRu ? 'Новые публикации' : 'Fresh updates',
                background: const Color(0xFFEFF7FF),
                border: const Color(0xFFDCE8FF),
                foreground: AppColors.chats,
              ),
              (
                icon: Icons.groups_2_rounded,
                label: strings.isRu ? 'Ваш круг' : 'Your people',
                background: const Color(0xFFE9FBF0),
                border: const Color(0xFFD7F3E0),
                foreground: AppColors.friends,
              ),
            ];

    for (final fallback in fallbacks) {
      addChip(
        icon: fallback.icon,
        label: fallback.label,
        background: fallback.background,
        border: fallback.border,
        foreground: fallback.foreground,
      );
    }
  }

  return chips;
}

class _FeedInlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FeedInlineErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: const Color(0xFFFFF8FA),
      borderColor: const Color(0xFFFFDADF),
      boxShadow: const [],
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

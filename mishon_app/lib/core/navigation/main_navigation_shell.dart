import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/features/auth/providers/auth_provider.dart';
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';
import 'package:mishon_app/features/profile/screens/profile_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  final _viewportController = _RootShellViewportController();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currentUserId = ref.watch(userIdProvider).value;
    final summary = ref
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

    final destinations = [
      _RootShellDestination(
        section: AppSection.feed,
        label: strings.feed,
        icon: Icons.newspaper_outlined,
        selectedIcon: Icons.newspaper_rounded,
        badgeCount: summary.unreadNotifications,
      ),
      _RootShellDestination(
        section: AppSection.people,
        label: strings.people,
        icon: Icons.people_outline_rounded,
        selectedIcon: Icons.people_rounded,
      ),
      _RootShellDestination(
        section: AppSection.friends,
        label: strings.friends,
        icon: Icons.favorite_outline_rounded,
        selectedIcon: Icons.favorite_rounded,
        badgeCount: summary.incomingFriendRequests,
      ),
      _RootShellDestination(
        section: AppSection.chats,
        label: strings.chats,
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum_rounded,
        badgeCount: summary.unreadChats,
      ),
      _RootShellDestination(
        section: AppSection.profile,
        label: strings.profile,
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        enabled: currentUserId != null,
      ),
    ];

    return _RootShellViewportScope(
      controller: _viewportController,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1040;
            if (!isWide) {
              return widget.navigationShell;
            }

            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                  child: _RootShellRail(
                    destinations: destinations,
                    currentIndex: widget.navigationShell.currentIndex,
                    onSelect: _goToBranch,
                  ),
                ),
                Expanded(child: widget.navigationShell),
              ],
            );
          },
        ),
        bottomNavigationBar:
            MediaQuery.sizeOf(context).width < 1040
                ? _RootShellBottomNavigation(
                  controller: _viewportController,
                  destinations: destinations,
                  currentIndex: widget.navigationShell.currentIndex,
                  onSelect: _goToBranch,
                )
                : null,
      ),
    );
  }

  void _goToBranch(int index) {
    _viewportController.updatePage(index.toDouble());
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}

class CurrentUserProfileBranchScreen extends ConsumerWidget {
  final bool embeddedInNavigationShell;

  const CurrentUserProfileBranchScreen({
    super.key,
    this.embeddedInNavigationShell = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(userIdProvider).value;
    if (userId == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ProfileScreen(
      userId: userId,
      embeddedInNavigationShell: embeddedInNavigationShell,
    );
  }
}

class _RootShellDestination {
  final AppSection section;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badgeCount;
  final bool enabled;

  const _RootShellDestination({
    required this.section,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
    this.enabled = true,
  });
}

class _RootShellViewportController extends ChangeNotifier {
  double _page = 0;
  bool _hasActivePage = false;

  double get page => _page;

  void attachInitialPage(int pageIndex) {
    if (_hasActivePage) {
      return;
    }

    _hasActivePage = true;
    _page = pageIndex.toDouble();
  }

  void updatePage(double pageValue) {
    _hasActivePage = true;
    if ((_page - pageValue).abs() < 0.0001) {
      return;
    }

    _page = pageValue;
    notifyListeners();
  }
}

class _RootShellViewportScope
    extends InheritedNotifier<_RootShellViewportController> {
  const _RootShellViewportScope({
    required _RootShellViewportController controller,
    required super.child,
  }) : super(notifier: controller);

  static _RootShellViewportController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<
      _RootShellViewportScope
    >();
    assert(scope != null, 'Root shell viewport scope is missing.');
    return scope!.notifier!;
  }
}

Widget mainShellContainerBuilder(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) {
  return _RootShellBranchViewport(
    navigationShell: navigationShell,
    children: children,
  );
}

class _RootShellBranchViewport extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const _RootShellBranchViewport({
    required this.navigationShell,
    required this.children,
  });

  @override
  State<_RootShellBranchViewport> createState() => _RootShellBranchViewportState();
}

class _RootShellBranchViewportState extends State<_RootShellBranchViewport> {
  late final PageController _pageController = PageController(
    initialPage: widget.navigationShell.currentIndex,
  );

  _RootShellViewportController? _viewportController;
  int? _programmaticTargetIndex;
  late int _lastSyncedIndex = widget.navigationShell.currentIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewportController = _RootShellViewportScope.of(context);
    _viewportController?.attachInitialPage(widget.navigationShell.currentIndex);
  }

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_handlePageOffsetChanged);
  }

  @override
  void didUpdateWidget(covariant _RootShellBranchViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.navigationShell.currentIndex;
    if (_lastSyncedIndex != nextIndex) {
      _lastSyncedIndex = nextIndex;
      _animateToBranch(nextIndex);
    }
  }

  @override
  void dispose() {
    _pageController
      ..removeListener(_handlePageOffsetChanged)
      ..dispose();
    super.dispose();
  }

  void _handlePageOffsetChanged() {
    _viewportController?.updatePage(
      _pageController.hasClients
          ? (_pageController.page ?? widget.navigationShell.currentIndex.toDouble())
          : widget.navigationShell.currentIndex.toDouble(),
    );
  }

  void _animateToBranch(int index) {
    if (!_pageController.hasClients) {
      return;
    }

    _programmaticTargetIndex = index;
    _pageController.jumpToPage(index);
    _viewportController?.updatePage(index.toDouble());
    _programmaticTargetIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
      onPageChanged: (index) {
        if (_programmaticTargetIndex != null) {
          if (index == _programmaticTargetIndex) {
            _lastSyncedIndex = index;
            _programmaticTargetIndex = null;
          }
          return;
        }

        if (index != widget.navigationShell.currentIndex) {
          _lastSyncedIndex = index;
          widget.navigationShell.goBranch(index);
        }
      },
      children: widget.children,
    );
  }
}

class _RootShellBottomNavigation extends StatefulWidget {
  final _RootShellViewportController controller;
  final List<_RootShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _RootShellBottomNavigation({
    required this.controller,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  State<_RootShellBottomNavigation> createState() =>
      _RootShellBottomNavigationState();
}

class _RootShellBottomNavigationState extends State<_RootShellBottomNavigation> {
  static const double _indicatorInset = 4;
  static const double _indicatorHeight = 68;

  bool _isDraggingIndicator = false;
  double? _dragPage;
  double? _settlingPage;
  int? _lockedVisualIndex;
  int? _hoveredIndex;
  double _itemWidth = 0;
  double _indicatorTouchOffset = 0;

  double _resolvedProgress(double rawProgress) {
    if (_isDraggingIndicator && _dragPage != null) {
      return _dragPage!;
    }

    if (_settlingPage != null) {
      return _settlingPage!;
    }

    if ((rawProgress - widget.currentIndex).abs() > 1.0) {
      return widget.currentIndex.toDouble();
    }

    return rawProgress;
  }

  @override
  void didUpdateWidget(covariant _RootShellBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_settlingPage != null &&
        widget.currentIndex == _settlingPage!.round()) {
      setState(() {
        _settlingPage = null;
      });
    }
    if (_lockedVisualIndex != null && widget.currentIndex == _lockedVisualIndex) {
      setState(() {
        _lockedVisualIndex = null;
      });
    }
  }

  int _resolveIndexFromIndicatorLeft(double indicatorLeft) {
    if (_itemWidth <= 0) {
      return widget.currentIndex;
    }

    final indicatorCenter =
        indicatorLeft + (_itemWidth - (_indicatorInset * 2)) / 2;
    final rawIndex = (indicatorCenter / _itemWidth).floor();
    return rawIndex.clamp(0, widget.destinations.length - 1);
  }

  void _handleDragStart(DragStartDetails details, double progress) {
    if (_itemWidth <= 0) {
      return;
    }

    final indicatorWidth = _itemWidth - (_indicatorInset * 2);
    final indicatorLeft = progress * _itemWidth + _indicatorInset;
    final localX = details.localPosition.dx;
    final localY = details.localPosition.dy;
    final withinIndicatorX =
        localX >= indicatorLeft && localX <= indicatorLeft + indicatorWidth;
    final withinIndicatorY =
        localY >= _indicatorInset &&
        localY <= _indicatorInset + _indicatorHeight;
    if (!withinIndicatorX || !withinIndicatorY) {
      return;
    }

    setState(() {
      _isDraggingIndicator = true;
      _indicatorTouchOffset = localX - indicatorLeft;
      _dragPage = progress;
      _hoveredIndex = _resolveIndexFromIndicatorLeft(indicatorLeft);
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingIndicator || _itemWidth <= 0) {
      return;
    }

    final indicatorWidth = _itemWidth - (_indicatorInset * 2);
    final maxLeft =
        _itemWidth * widget.destinations.length -
        indicatorWidth -
        _indicatorInset;
    final nextLeft = (details.localPosition.dx - _indicatorTouchOffset).clamp(
      _indicatorInset,
      maxLeft,
    );
    final nextPage = (nextLeft - _indicatorInset) / _itemWidth;
    final nextIndex = _resolveIndexFromIndicatorLeft(nextLeft);

    setState(() {
      _dragPage = nextPage;
      _hoveredIndex = nextIndex;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDraggingIndicator) {
      return;
    }

    final targetIndex =
        (_hoveredIndex ?? _dragPage?.round() ?? widget.currentIndex).clamp(
          0,
          widget.destinations.length - 1,
        );
    final targetPage = targetIndex.toDouble();

    setState(() {
      _isDraggingIndicator = false;
      _dragPage = null;
      _settlingPage = targetPage;
      _lockedVisualIndex = targetIndex;
      _hoveredIndex = null;
      _indicatorTouchOffset = 0;
    });

    if (widget.destinations[targetIndex].enabled) {
      widget.controller.updatePage(targetPage);
      widget.onSelect(targetIndex);
    } else {
      setState(() {
        _settlingPage = widget.currentIndex.toDouble();
        _lockedVisualIndex = widget.currentIndex;
      });
      widget.controller.updatePage(widget.currentIndex.toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final rawProgress = widget.controller.page;
          final progress = _resolvedProgress(rawProgress);
          final visualIndex =
              _lockedVisualIndex ??
              progress.round().clamp(0, widget.destinations.length - 1);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                _itemWidth = constraints.maxWidth / widget.destinations.length;
                final indicatorWidth = _itemWidth - (_indicatorInset * 2);
                final indicatorLeft = progress * _itemWidth + _indicatorInset;
                return SizedBox(
                  height: 76,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart:
                        (details) => _handleDragStart(details, progress),
                    onHorizontalDragUpdate: _handleDragUpdate,
                    onHorizontalDragEnd: _handleDragEnd,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration:
                              _isDraggingIndicator
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          left: indicatorLeft,
                          top: _indicatorInset,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            scale: _isDraggingIndicator ? 1.01 : 1,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 160),
                              opacity: 1,
                              child: Container(
                                width: indicatorWidth,
                                height: _indicatorHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4A8DFF),
                                      Color(0xFF7468FF),
                                    ],
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
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var index = 0;
                                index < widget.destinations.length;
                                index++)
                              Expanded(
                                child: _RootShellNavItem(
                                  destination: widget.destinations[index],
                                  selected: index == visualIndex,
                                  highlighted:
                                      _isDraggingIndicator &&
                                      index == _hoveredIndex,
                                  onTap:
                                      widget.destinations[index].enabled
                                          ? () => widget.onSelect(index)
                                          : null,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RootShellRail extends StatelessWidget {
  final List<_RootShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _RootShellRail({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF15213A).withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: NavigationRail(
          selectedIndex: currentIndex,
          onDestinationSelected: onSelect,
          labelType: NavigationRailLabelType.all,
          minWidth: 96,
          groupAlignment: -0.4,
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFFE8EEFF),
          destinations:
              destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: _RootShellBadgeIcon(
                        icon: item.icon,
                        badgeCount: item.badgeCount,
                        selected: false,
                      ),
                      selectedIcon: _RootShellBadgeIcon(
                        icon: item.selectedIcon,
                        badgeCount: item.badgeCount,
                        selected: true,
                      ),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class _RootShellNavItem extends StatelessWidget {
  final _RootShellDestination destination;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onTap;

  const _RootShellNavItem({
    required this.destination,
    required this.selected,
    this.highlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActiveVisual = selected || highlighted;
    final foregroundColor =
        isActiveVisual ? Colors.white : const Color(0xFF5B687D);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          scale: highlighted && !selected ? 1.04 : 1,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: highlighted && !selected ? 0.92 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 24,
                    child: Center(
                      child: _RootShellBadgeIcon(
                        icon:
                            isActiveVisual
                                ? destination.selectedIcon
                                : destination.icon,
                        badgeCount: destination.badgeCount,
                        selected: isActiveVisual,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 16,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: foregroundColor,
                      ),
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

class _RootShellBadgeIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final bool selected;

  const _RootShellBadgeIcon({
    required this.icon,
    required this.badgeCount,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 22),
        if (badgeCount > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color:
                    selected
                        ? const Color(0xFF2A5BFF)
                        : const Color(0xFF101727),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
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
    );
  }
}

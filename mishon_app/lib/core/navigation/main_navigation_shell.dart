import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/providers/app_bootstrap_provider.dart';
import 'package:mishon_app/core/providers/app_connection_status_provider.dart';
import 'package:mishon_app/core/widgets/app_shell.dart';
import 'package:mishon_app/core/theme/app_theme.dart';
import 'package:mishon_app/features/notifications/providers/notification_summary_provider.dart';
import 'package:mishon_app/features/profile/screens/profile_screen.dart';

const _rootShellTransitionDuration = Duration(milliseconds: 180);
const _rootShellTransitionCurve = Curves.easeInOut;
const _rootShellWideBreakpoint = 1040.0;

void _dismissPrimaryFocus() {
  FocusManager.instance.primaryFocus?.unfocus();
}

class MainNavigationShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  late final _navigationCoordinator = _RootShellNavigationCoordinator(
    initialIndex: widget.navigationShell.currentIndex,
  );
  var _didRedirectToFeedOnEntry = false;
  int? _pendingBranchIndex;

  @override
  void initState() {
    super.initState();
    _redirectToFeedOnEntry();
  }

  @override
  void didUpdateWidget(covariant MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final externalIndex = widget.navigationShell.currentIndex;
      final pendingBranchIndex = _pendingBranchIndex;
      if (pendingBranchIndex != null && pendingBranchIndex != externalIndex) {
        return;
      }

      if (pendingBranchIndex == externalIndex) {
        _pendingBranchIndex = null;
      }

      _navigationCoordinator.syncToExternalIndex(externalIndex);
    });
  }

  @override
  void dispose() {
    _navigationCoordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appConnectionStatusProvider);
    final strings = AppStrings.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
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

    void handleDestinationSelected(int index) {
      final destination = destinations[index];
      if (!destination.enabled) {
        return;
      }

      _requestBranchSelection(index);
    }

    return _RootShellNavigationScope(
      coordinator: _navigationCoordinator,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _rootShellWideBreakpoint;
            if (!isWide) {
              return widget.navigationShell;
            }

            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                  child: _RootShellRail(
                    destinations: destinations,
                    onSelect: handleDestinationSelected,
                  ),
                ),
                Expanded(child: widget.navigationShell),
              ],
            );
          },
        ),
        bottomNavigationBar:
            MediaQuery.sizeOf(context).width < _rootShellWideBreakpoint
                ? _RootShellBottomNavigation(
                  destinations: destinations,
                  routeIndex: widget.navigationShell.currentIndex,
                  onSelect: handleDestinationSelected,
                )
                : null,
      ),
    );
  }

  void _redirectToFeedOnEntry() {
    if (_didRedirectToFeedOnEntry) {
      return;
    }

    _didRedirectToFeedOnEntry = true;
  }

  void _requestBranchSelection(int index) {
    final isCurrentBranch = index == widget.navigationShell.currentIndex;
    _pendingBranchIndex = isCurrentBranch ? null : index;

    _dismissPrimaryFocus();
    unawaited(_navigationCoordinator.animateToIndex(index));
    widget.navigationShell.goBranch(index, initialLocation: isCurrentBranch);
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
    final userId = ref.watch(currentUserIdProvider);
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

class _RootShellNavigationCoordinator {
  _RootShellNavigationCoordinator({required int initialIndex})
    : pageController = PageController(initialPage: initialIndex),
      currentIndex = ValueNotifier<int>(initialIndex),
      _targetIndex = initialIndex {
    pageController.addListener(_handlePageTick);
  }

  final PageController pageController;
  final ValueNotifier<int> currentIndex;

  int _targetIndex;
  int _activityVersion = 0;
  int? _programmaticTargetIndex;
  bool _disposed = false;

  double get page {
    if (pageController.hasClients) {
      return pageController.page ?? currentIndex.value.toDouble();
    }

    return currentIndex.value.toDouble();
  }

  bool shouldSyncBranchForPageChange(int index) {
    final programmaticTargetIndex = _programmaticTargetIndex;
    if (programmaticTargetIndex == null) {
      return true;
    }

    if (index != programmaticTargetIndex) {
      return false;
    }

    _programmaticTargetIndex = null;
    return true;
  }

  void syncToExternalIndex(int index) {
    if (_disposed) {
      return;
    }

    final currentPage = page;
    if ((currentPage - index).abs() < 0.0001) {
      _targetIndex = index;
      if (currentIndex.value != index) {
        currentIndex.value = index;
      }
      return;
    }

    if (_targetIndex == index && pageController.hasClients) {
      return;
    }

    unawaited(animateToIndex(index));
  }

  Future<void> animateToIndex(int index) async {
    if (_disposed) {
      return;
    }

    _targetIndex = index;
    _programmaticTargetIndex = index;
    if (currentIndex.value != index) {
      currentIndex.value = index;
    }

    final currentPage = page;
    if ((currentPage - index).abs() < 0.0001) {
      _programmaticTargetIndex = null;
      return;
    }

    final activityVersion = ++_activityVersion;
    if (!pageController.hasClients) {
      if (_programmaticTargetIndex == index) {
        _programmaticTargetIndex = null;
      }
      return;
    }

    try {
      await pageController.animateToPage(
        index,
        duration: _rootShellTransitionDuration,
        curve: _rootShellTransitionCurve,
      );
    } catch (_) {
      if (!_disposed &&
          activityVersion == _activityVersion &&
          _programmaticTargetIndex == index) {
        _programmaticTargetIndex = null;
      }
      return;
    }

    if (_disposed || activityVersion != _activityVersion) {
      return;
    }

    if (_programmaticTargetIndex == index) {
      _programmaticTargetIndex = null;
    }

    if (currentIndex.value != index) {
      currentIndex.value = index;
    }
  }

  void _handlePageTick() {
    if (_programmaticTargetIndex != null) {
      return;
    }

    final nextIndex = page.round();
    if (nextIndex != currentIndex.value) {
      currentIndex.value = nextIndex;
    }
  }

  void dispose() {
    _disposed = true;
    pageController
      ..removeListener(_handlePageTick)
      ..dispose();
    currentIndex.dispose();
  }
}

class _RootShellNavigationScope extends InheritedWidget {
  final _RootShellNavigationCoordinator coordinator;

  const _RootShellNavigationScope({
    required this.coordinator,
    required super.child,
  });

  static _RootShellNavigationCoordinator of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_RootShellNavigationScope>();
    assert(scope != null, 'Root shell navigation scope is missing.');
    return scope!.coordinator;
  }

  @override
  bool updateShouldNotify(covariant _RootShellNavigationScope oldWidget) {
    return oldWidget.coordinator != coordinator;
  }
}

Widget mainShellContainerBuilder(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) {
  return _RootShellPageViewport(
    navigationShell: navigationShell,
    children: children,
  );
}

class _RootShellPageViewport extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const _RootShellPageViewport({
    required this.navigationShell,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final coordinator = _RootShellNavigationScope.of(context);
    return PageView(
      controller: coordinator.pageController,
      allowImplicitScrolling: true,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (index) {
        if (!coordinator.shouldSyncBranchForPageChange(index)) {
          return;
        }

        if (index == navigationShell.currentIndex) {
          return;
        }

        _dismissPrimaryFocus();
        navigationShell.goBranch(index);
      },
      children: children
          .map((child) => _RootShellKeptAlivePage(child: child))
          .toList(growable: false),
    );
  }
}

class _RootShellBottomNavigation extends StatefulWidget {
  final List<_RootShellDestination> destinations;
  final int routeIndex;
  final ValueChanged<int> onSelect;

  const _RootShellBottomNavigation({
    required this.destinations,
    required this.routeIndex,
    required this.onSelect,
  });

  @override
  State<_RootShellBottomNavigation> createState() =>
      _RootShellBottomNavigationState();
}

class _RootShellBottomNavigationState extends State<_RootShellBottomNavigation>
    with SingleTickerProviderStateMixin {
  static const double _indicatorInset = 4;
  static const double _indicatorHeight = 68;

  final GlobalKey _barKey = GlobalKey();

  late final AnimationController _indicatorSettleController;

  bool _isDraggingIndicator = false;
  Animation<double>? _indicatorSettleAnimation;
  double? _dragPreviewPage;
  double? _lastDragLocalX;
  double _dragTouchOffset = 0;
  double _tabWidth = 0;

  @override
  void initState() {
    super.initState();
    _indicatorSettleController =
        AnimationController(vsync: this, duration: _rootShellTransitionDuration)
          ..addListener(() {
            if (!mounted || _indicatorSettleAnimation == null) {
              return;
            }

            setState(() {});
          })
          ..addStatusListener((status) {
            if (!mounted || status != AnimationStatus.completed) {
              return;
            }

            setState(() {
              _indicatorSettleAnimation = null;
            });
          });
  }

  @override
  void dispose() {
    _indicatorSettleController.dispose();
    super.dispose();
  }

  double _pageForIndicator(_RootShellNavigationCoordinator coordinator) {
    final previewPage = _dragPreviewPage;
    if (_isDraggingIndicator && previewPage != null) {
      return previewPage
          .clamp(0.0, (widget.destinations.length - 1).toDouble())
          .toDouble();
    }

    final settleAnimation = _indicatorSettleAnimation;
    if (settleAnimation != null) {
      return settleAnimation.value
          .clamp(0.0, (widget.destinations.length - 1).toDouble())
          .toDouble();
    }

    return coordinator.page
        .clamp(0.0, (widget.destinations.length - 1).toDouble())
        .toDouble();
  }

  double _indicatorLeft(double page) {
    return _indicatorInset + (page * _tabWidth);
  }

  double _globalToBarLocalX(Offset globalPosition) {
    final renderObject = _barKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return 0;
    }

    return renderObject.globalToLocal(globalPosition).dx;
  }

  double _clampDragLocalX(double localX) {
    if (_tabWidth <= 0) {
      return 0;
    }

    final maxX = (_tabWidth * widget.destinations.length) - 0.001;
    return localX.clamp(0.0, maxX).toDouble();
  }

  double _previewPageForLocalX(double localX) {
    if (_tabWidth <= 0) {
      return widget.routeIndex.toDouble();
    }

    final clampedX = _clampDragLocalX(localX - _dragTouchOffset);
    final centeredPage = (clampedX / _tabWidth) - 0.5;
    return centeredPage
        .clamp(0.0, (widget.destinations.length - 1).toDouble())
        .toDouble();
  }

  void _updateDragPreviewFromLocalX(double localX) {
    if (!_isDraggingIndicator || _tabWidth <= 0) {
      return;
    }

    final nextPage = _previewPageForLocalX(localX);

    final previousPage = _dragPreviewPage;
    final previousLocalX = _lastDragLocalX;
    final pageChanged =
        previousPage == null || (previousPage - nextPage).abs() > 0.0001;
    final pointerChanged =
        previousLocalX == null || (previousLocalX - localX).abs() > 0.5;
    if (!pageChanged && !pointerChanged) {
      return;
    }

    setState(() {
      _dragPreviewPage = nextPage;
      _lastDragLocalX = localX;
    });
  }

  void _handleBarPointerMove(PointerMoveEvent event) {
    if (!_isDraggingIndicator) {
      return;
    }

    _updateDragPreviewFromLocalX(
      _clampDragLocalX(_globalToBarLocalX(event.position)),
    );
  }

  void _handleBarPointerUp(PointerUpEvent event) {
    if (!_isDraggingIndicator) {
      return;
    }

    _updateDragPreviewFromLocalX(
      _clampDragLocalX(_globalToBarLocalX(event.position)),
    );
  }

  void _handleBarPointerCancel(PointerCancelEvent event) {
    if (!_isDraggingIndicator) {
      return;
    }

    setState(() {
      _lastDragLocalX = null;
    });
  }

  void _clearIndicatorSettle() {
    if (!_indicatorSettleController.isAnimating &&
        _indicatorSettleAnimation == null) {
      return;
    }

    _indicatorSettleController.stop();
    _indicatorSettleAnimation = null;
  }

  void _startIndicatorSettle({
    required double fromPage,
    required double toPage,
  }) {
    _indicatorSettleController
      ..stop()
      ..reset();

    _indicatorSettleAnimation = Tween<double>(
      begin: fromPage,
      end: toPage,
    ).animate(
      CurvedAnimation(
        parent: _indicatorSettleController,
        curve: _rootShellTransitionCurve,
      ),
    );

    setState(() {});
    unawaited(
      _indicatorSettleController.forward().orCancel.catchError((_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _indicatorSettleAnimation = null;
        });
      }),
    );
  }

  void _activateIndex(_RootShellNavigationCoordinator coordinator, int index) {
    final destination = widget.destinations[index];
    if (!destination.enabled) {
      return;
    }

    _clearIndicatorSettle();
    widget.onSelect(index);
  }

  void _handleIndicatorDragStart(
    DragStartDetails details,
    _RootShellNavigationCoordinator coordinator,
  ) {
    if (_tabWidth <= 0) {
      return;
    }

    _dismissPrimaryFocus();
    final visualPage = _pageForIndicator(coordinator);
    _clearIndicatorSettle();
    final localX = _clampDragLocalX(_globalToBarLocalX(details.globalPosition));

    setState(() {
      _isDraggingIndicator = true;
      _dragPreviewPage = visualPage;
      _lastDragLocalX = localX;
      _dragTouchOffset = 0;
    });
  }

  void _handleIndicatorDragUpdate(
    DragUpdateDetails details,
    _RootShellNavigationCoordinator coordinator,
  ) {
    if (!_isDraggingIndicator || _tabWidth <= 0) {
      return;
    }

    _updateDragPreviewFromLocalX(
      _clampDragLocalX(_globalToBarLocalX(details.globalPosition)),
    );
  }

  void _handleIndicatorDragEnd(
    DragEndDetails details,
    _RootShellNavigationCoordinator coordinator,
  ) {
    if (!_isDraggingIndicator) {
      return;
    }

    final releasedPage =
        (_dragPreviewPage ?? _pageForIndicator(coordinator))
            .clamp(0.0, (widget.destinations.length - 1).toDouble())
            .toDouble();
    final targetIndex = releasedPage.round().clamp(
      0,
      widget.destinations.length - 1,
    );

    setState(() {
      _isDraggingIndicator = false;
      _dragPreviewPage = null;
      _lastDragLocalX = null;
      _dragTouchOffset = 0;
    });

    if (!widget.destinations[targetIndex].enabled) {
      _startIndicatorSettle(
        fromPage: releasedPage,
        toPage: widget.routeIndex.toDouble(),
      );
      return;
    }

    _startIndicatorSettle(
      fromPage: releasedPage,
      toPage: targetIndex.toDouble(),
    );
    if (targetIndex != widget.routeIndex) {
      widget.onSelect(targetIndex);
      return;
    }

    unawaited(coordinator.animateToIndex(targetIndex));
  }

  void _handleIndicatorDragCancel() {
    if (!_isDraggingIndicator) {
      return;
    }

    final fromPage = _dragPreviewPage;
    setState(() {
      _isDraggingIndicator = false;
      _dragPreviewPage = null;
      _lastDragLocalX = null;
      _dragTouchOffset = 0;
    });

    if (fromPage != null) {
      _startIndicatorSettle(
        fromPage: fromPage,
        toPage: widget.routeIndex.toDouble(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = _RootShellNavigationScope.of(context);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _tabWidth = constraints.maxWidth / widget.destinations.length;
            final indicatorWidth = _tabWidth - (_indicatorInset * 2);

            return Listener(
              onPointerMove: _handleBarPointerMove,
              onPointerUp: _handleBarPointerUp,
              onPointerCancel: _handleBarPointerCancel,
              child: Container(
                key: _barKey,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: coordinator.pageController,
                      builder: (context, child) {
                        final left = _indicatorLeft(
                          _pageForIndicator(coordinator),
                        );
                        return Positioned(
                          left: left,
                          top: _indicatorInset,
                          child: IgnorePointer(
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,
                              scale: _isDraggingIndicator ? 1.02 : 1,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: indicatorWidth,
                        height: _indicatorHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: AppGradients.profile,
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
                    Positioned.fill(
                      child: ValueListenableBuilder<int>(
                        valueListenable: coordinator.currentIndex,
                        builder: (context, currentIndex, _) {
                          return Row(
                            children: [
                              for (
                                var index = 0;
                                index < widget.destinations.length;
                                index++
                              )
                                Expanded(
                                  child: _RootShellNavItem(
                                    destination: widget.destinations[index],
                                    selected: currentIndex == index,
                                    useTapDown: false,
                                    onTap:
                                        widget.destinations[index].enabled
                                            ? () => _activateIndex(
                                              coordinator,
                                              index,
                                            )
                                            : null,
                                    onHorizontalDragStart:
                                        currentIndex == index &&
                                                widget
                                                    .destinations[index]
                                                    .enabled
                                            ? (details) =>
                                                _handleIndicatorDragStart(
                                                  details,
                                                  coordinator,
                                                )
                                            : null,
                                    onHorizontalDragUpdate:
                                        currentIndex == index &&
                                                widget
                                                    .destinations[index]
                                                    .enabled
                                            ? (details) =>
                                                _handleIndicatorDragUpdate(
                                                  details,
                                                  coordinator,
                                                )
                                            : null,
                                    onHorizontalDragEnd:
                                        currentIndex == index &&
                                                widget
                                                    .destinations[index]
                                                    .enabled
                                            ? (details) =>
                                                _handleIndicatorDragEnd(
                                                  details,
                                                  coordinator,
                                                )
                                            : null,
                                    onHorizontalDragCancel:
                                        currentIndex == index
                                            ? _handleIndicatorDragCancel
                                            : null,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RootShellRail extends StatelessWidget {
  final List<_RootShellDestination> destinations;
  final ValueChanged<int> onSelect;

  const _RootShellRail({required this.destinations, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final coordinator = _RootShellNavigationScope.of(context);

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
        child: ValueListenableBuilder<int>(
          valueListenable: coordinator.currentIndex,
          builder: (context, currentIndex, _) {
            return NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                if (!destinations[index].enabled) {
                  return;
                }
                onSelect(index);
              },
              labelType: NavigationRailLabelType.all,
              minWidth: 96,
              groupAlignment: -0.4,
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.profileSoft,
              destinations: destinations
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
                  .toList(growable: false),
            );
          },
        ),
      ),
    );
  }
}

class _RootShellNavItem extends StatelessWidget {
  final _RootShellDestination destination;
  final bool selected;
  final bool useTapDown;
  final VoidCallback? onTap;
  final GestureDragStartCallback? onHorizontalDragStart;
  final GestureDragUpdateCallback? onHorizontalDragUpdate;
  final GestureDragEndCallback? onHorizontalDragEnd;
  final VoidCallback? onHorizontalDragCancel;

  const _RootShellNavItem({
    required this.destination,
    required this.selected,
    required this.useTapDown,
    required this.onTap,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected ? Colors.white : const Color(0xFF5B687D);

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onHorizontalDragStart: onHorizontalDragStart,
          onHorizontalDragUpdate: onHorizontalDragUpdate,
          onHorizontalDragEnd: onHorizontalDragEnd,
          onHorizontalDragCancel: onHorizontalDragCancel,
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
                          selected
                              ? destination.selectedIcon
                              : destination.icon,
                      badgeCount: destination.badgeCount,
                      selected: selected,
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

class _RootShellKeptAlivePage extends StatefulWidget {
  final Widget child;

  const _RootShellKeptAlivePage({required this.child});

  @override
  State<_RootShellKeptAlivePage> createState() =>
      _RootShellKeptAlivePageState();
}

class _RootShellKeptAlivePageState extends State<_RootShellKeptAlivePage>
    with AutomaticKeepAliveClientMixin<_RootShellKeptAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

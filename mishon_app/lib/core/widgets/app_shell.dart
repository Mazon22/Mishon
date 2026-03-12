import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/social_models.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/notifications/providers/notification_summary_provider.dart';

enum AppSection { feed, people, friends, chats, profile }

class AppShell extends ConsumerWidget {
  final AppSection currentSection;
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;
  final double maxContentWidth;
  final bool showNotificationsAction;
  final bool showAppBar;

  const AppShell({
    super.key,
    required this.currentSection,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.maxContentWidth = 960,
    this.showNotificationsAction = false,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final destinations = _buildDestinations(currentUserId, summary);
    final shellActions = <Widget>[
      if (showNotificationsAction)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _BellButton(
            count: summary.unreadNotifications,
            onTap: () => context.push('/notifications'),
          ),
        ),
      ...?actions,
      const SizedBox(width: 8),
    ];

    return Scaffold(
      extendBody: true,
      appBar:
          showAppBar
              ? AppBar(
                titleSpacing: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.88),
                title: Text(title),
                actions: shellActions,
              )
              : null,
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F6FF), Color(0xFFF7FBFF), Color(0xFFFFFBF5)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7DA9FF).withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              top: 120,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFB86A).withValues(alpha: 0.10),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1040;
                  if (!isWide) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: child,
                      ),
                    );
                  }

                  return Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(34),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.82),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF15213A,
                                  ).withValues(alpha: 0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: NavigationRail(
                              selectedIndex: currentSection.index,
                              onDestinationSelected:
                                  (index) =>
                                      _goTo(context, destinations[index].route),
                              labelType: NavigationRailLabelType.all,
                              minWidth: 96,
                              groupAlignment: -0.4,
                              backgroundColor: Colors.transparent,
                              indicatorColor: const Color(0xFFE8EEFF),
                              destinations:
                                  destinations
                                      .map(
                                        (item) => NavigationRailDestination(
                                          icon: _DestinationIcon(
                                            icon: item.icon,
                                            badgeCount: item.badgeCount,
                                            selected: false,
                                          ),
                                          selectedIcon: _DestinationIcon(
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
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
                            ),
                            child: child,
                          ),
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
      bottomNavigationBar:
          MediaQuery.sizeOf(context).width < 1040
              ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DecoratedBox(
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
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      backgroundColor: Colors.transparent,
                      indicatorColor: const Color(0xFFE9EEFF),
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        final isSelected = states.contains(
                          WidgetState.selected,
                        );
                        return TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isSelected
                                  ? const Color(0xFF18243C)
                                  : const Color(0xFF5B687D),
                        );
                      }),
                    ),
                    child: NavigationBar(
                      height: 76,
                      selectedIndex: currentSection.index,
                      onDestinationSelected:
                          (index) => _goTo(context, destinations[index].route),
                      destinations:
                          destinations
                              .map(
                                (item) => NavigationDestination(
                                  icon: _DestinationIcon(
                                    icon: item.icon,
                                    badgeCount: item.badgeCount,
                                    selected: false,
                                  ),
                                  selectedIcon: _DestinationIcon(
                                    icon: item.selectedIcon,
                                    badgeCount: item.badgeCount,
                                    selected: true,
                                  ),
                                  label: item.label,
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ),
              )
              : null,
    );
  }

  List<_ShellDestination> _buildDestinations(
    int? currentUserId,
    NotificationSummaryModel summary,
  ) {
    return [
      _ShellDestination(
        label: 'Лента',
        icon: Icons.newspaper_outlined,
        selectedIcon: Icons.newspaper_rounded,
        route: '/feed',
        badgeCount: summary.unreadNotifications,
      ),
      const _ShellDestination(
        label: 'Люди',
        icon: Icons.people_outline_rounded,
        selectedIcon: Icons.people_rounded,
        route: '/people',
      ),
      _ShellDestination(
        label: 'Друзья',
        icon: Icons.favorite_outline_rounded,
        selectedIcon: Icons.favorite_rounded,
        route: '/friends',
        badgeCount: summary.incomingFriendRequests,
      ),
      _ShellDestination(
        label: 'Чаты',
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum_rounded,
        route: '/chats',
        badgeCount: summary.unreadChats,
      ),
      _ShellDestination(
        label: 'Профиль',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        route: '/profile/${currentUserId ?? 0}',
      ),
    ];
  }

  void _goTo(BuildContext context, String route) {
    if (route.endsWith('/0')) {
      return;
    }
    context.go(route);
  }
}

class _ShellDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final int badgeCount;

  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    this.badgeCount = 0,
  });
}

class _DestinationIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final bool selected;

  const _DestinationIcon({
    required this.icon,
    required this.badgeCount,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
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

class _BellButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _BellButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.notifications_none_rounded),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
    );
  }
}

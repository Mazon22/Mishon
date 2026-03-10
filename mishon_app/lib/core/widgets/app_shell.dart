import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';

enum AppSection { feed, people, friends, chats, profile }

class AppShell extends ConsumerWidget {
  final AppSection currentSection;
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;
  final double maxContentWidth;

  const AppShell({
    super.key,
    required this.currentSection,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.maxContentWidth = 920,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(userIdProvider).value;
    final destinations = _buildDestinations(currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF6F7FB),
              Color(0xFFFDF7F1),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
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
                    borderRadius: BorderRadius.circular(28),
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.86),
                      child: NavigationRail(
                        selectedIndex: currentSection.index,
                        onDestinationSelected: (index) => _goTo(
                          context,
                          destinations[index].route,
                        ),
                        labelType: NavigationRailLabelType.all,
                        minWidth: 88,
                        destinations: destinations
                            .map(
                              (item) => NavigationRailDestination(
                                icon: Icon(item.icon),
                                selectedIcon: Icon(item.selectedIcon),
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
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 960
          ? NavigationBar(
              selectedIndex: currentSection.index,
              onDestinationSelected: (index) => _goTo(
                context,
                destinations[index].route,
              ),
              destinations: destinations
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }

  List<_ShellDestination> _buildDestinations(int? currentUserId) {
    return [
      const _ShellDestination(
        label: 'Лента',
        icon: Icons.newspaper_outlined,
        selectedIcon: Icons.newspaper,
        route: '/feed',
      ),
      const _ShellDestination(
        label: 'Люди',
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        route: '/people',
      ),
      const _ShellDestination(
        label: 'Друзья',
        icon: Icons.favorite_border,
        selectedIcon: Icons.favorite,
        route: '/friends',
      ),
      const _ShellDestination(
        label: 'Чаты',
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum,
        route: '/chats',
      ),
      _ShellDestination(
        label: 'Профиль',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
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

  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}

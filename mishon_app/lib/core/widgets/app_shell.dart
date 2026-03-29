import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/providers/app_connection_status_provider.dart';
import 'package:mishon_app/core/theme/app_theme.dart';

import '../../features/notifications/providers/notification_summary_provider.dart';
import '../models/social_models.dart';

enum AppSection { feed, people, friends, chats, profile }

class AppShell extends ConsumerWidget {
  final AppSection currentSection;
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final double maxContentWidth;
  final bool showNotificationsAction;
  final bool showAppBar;
  final bool showSectionNavigation;
  final BoxDecoration? bodyDecoration;
  final List<Widget>? backgroundLayers;

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
    this.showSectionNavigation = true,
    this.bodyDecoration,
    this.backgroundLayers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(appConnectionStatusProvider);
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
    final destinations = _buildDestinations(context, summary);
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
                toolbarHeight: connectionStatus.isVisible ? 74 : kToolbarHeight,
                titleSpacing: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.88),
                title: _AppShellTitleBlock(
                  title: title,
                  connectionStatus: connectionStatus,
                  accentColor: AppColors.profile,
                ),
                actions: shellActions,
              )
              : null,
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: bodyDecoration ?? _defaultBodyDecoration,
        child: Stack(
          children: [
            ...(backgroundLayers ?? _defaultBackgroundLayers),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1040;
                  if (!isWide || !showSectionNavigation) {
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
                              indicatorColor: AppColors.profileSoft,
                              destinations:
                                  destinations
                                      .map(
                                        (item) => NavigationRailDestination(
                                          icon: _DestinationIcon(
                                            icon: item.icon,
                                            badgeCount: item.badgeCount,
                                            selected: false,
                                            accentColor:
                                                _sectionPaletteFor(
                                                  item.section,
                                                ).accent,
                                          ),
                                          selectedIcon: _DestinationIcon(
                                            icon: item.selectedIcon,
                                            badgeCount: item.badgeCount,
                                            selected: true,
                                            accentColor: _navigationAccent,
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
          showSectionNavigation && MediaQuery.sizeOf(context).width < 1040
              ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(30),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children:
                          destinations.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _BottomNavItem(
                                  destination: item,
                                  isSelected: index == currentSection.index,
                                  onTap: () => _goTo(context, item.route),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              )
              : null,
    );
  }

  List<_ShellDestination> _buildDestinations(
    BuildContext context,
    NotificationSummaryModel summary,
  ) {
    final strings = AppStrings.of(context);
    return [
      _ShellDestination(
        section: AppSection.feed,
        label: strings.feed,
        icon: Icons.newspaper_outlined,
        selectedIcon: Icons.newspaper_rounded,
        route: '/feed',
        badgeCount: summary.unreadNotifications,
      ),
      _ShellDestination(
        section: AppSection.people,
        label: strings.people,
        icon: Icons.people_outline_rounded,
        selectedIcon: Icons.people_rounded,
        route: '/people',
      ),
      _ShellDestination(
        section: AppSection.friends,
        label: strings.friends,
        icon: Icons.favorite_outline_rounded,
        selectedIcon: Icons.favorite_rounded,
        route: '/friends',
        badgeCount: summary.incomingFriendRequests,
      ),
      _ShellDestination(
        section: AppSection.chats,
        label: strings.chats,
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum_rounded,
        route: '/chats',
        badgeCount: summary.unreadChats,
      ),
      _ShellDestination(
        section: AppSection.profile,
        label: strings.profile,
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        route: '/profile',
      ),
    ];
  }

  void _goTo(BuildContext context, String route) {
    context.go(route);
  }
}

class _AppShellTitleBlock extends StatelessWidget {
  final String title;
  final AppConnectionStatus connectionStatus;
  final Color accentColor;

  const _AppShellTitleBlock({
    required this.title,
    required this.connectionStatus,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final label = connectionStatus.label(strings);
    final indicatorColor = switch (connectionStatus.phase) {
      AppConnectionPhase.connecting => const Color(0xFFF08A24),
      AppConnectionPhase.updating => const Color(0xFF2A6BFF),
      AppConnectionPhase.connected => const Color(0xFF1F8F52),
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(title)),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child:
              connectionStatus.isVisible
                  ? Padding(
                    key: ValueKey<AppConnectionPhase>(connectionStatus.phase),
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: indicatorColor,
                          ),
                        ),
                      ],
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

const _defaultBodyDecoration = BoxDecoration(
  gradient: AppGradients.shellBackground,
);

const _defaultBackgroundLayers = [
  Positioned(
    top: -120,
    left: -80,
    child: _ShellGlowOrb(
      size: 260,
      colors: [Color(0xFFB5D8FF), Color(0x33B5D8FF)],
    ),
  ),
  Positioned(
    bottom: -140,
    right: -60,
    child: _ShellGlowOrb(
      size: 280,
      colors: [Color(0xFFD4C4FF), Color(0x33D4C4FF)],
    ),
  ),
  Positioned(
    top: 120,
    right: -40,
    child: _ShellGlowOrb(
      size: 180,
      colors: [Color(0xFFF4D8FF), Color(0x22F4D8FF)],
    ),
  ),
];

class _ShellDestination {
  final AppSection section;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final int badgeCount;

  const _ShellDestination({
    required this.section,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    this.badgeCount = 0,
  });
}

class _SectionPalette {
  final Color accent;
  final Color soft;
  final LinearGradient gradient;

  const _SectionPalette({
    required this.accent,
    required this.soft,
    required this.gradient,
  });
}

const _navigationAccent = AppColors.profile;
const _navigationGradient = AppGradients.profile;

_SectionPalette _sectionPaletteFor(AppSection section) {
  return switch (section) {
    AppSection.feed => const _SectionPalette(
      accent: AppColors.feed,
      soft: AppColors.feedSoft,
      gradient: AppGradients.feed,
    ),
    AppSection.people => const _SectionPalette(
      accent: AppColors.people,
      soft: AppColors.peopleSoft,
      gradient: AppGradients.people,
    ),
    AppSection.friends => const _SectionPalette(
      accent: AppColors.friends,
      soft: AppColors.friendsSoft,
      gradient: AppGradients.friends,
    ),
    AppSection.chats => const _SectionPalette(
      accent: AppColors.chats,
      soft: AppColors.chatsSoft,
      gradient: AppGradients.chats,
    ),
    AppSection.profile => const _SectionPalette(
      accent: AppColors.profile,
      soft: AppColors.profileSoft,
      gradient: AppGradients.profile,
    ),
  };
}

class _ShellGlowOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _ShellGlowOrb({required this.size, required this.colors});

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

class _DestinationIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final bool selected;
  final Color accentColor;

  const _DestinationIcon({
    required this.icon,
    required this.badgeCount,
    required this.selected,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: selected ? accentColor : const Color(0xFF6B7890)),
        if (badgeCount > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: selected ? accentColor : const Color(0xFF101727),
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

class _BottomNavItem extends StatelessWidget {
  final _ShellDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected ? Colors.white : const Color(0xFF5B687D);
    final iconBackgroundColor =
        isSelected
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFFF3F6FC);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: isSelected ? _navigationGradient : null,
        color: isSelected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        boxShadow:
            isSelected
                ? [
                  BoxShadow(
                    color: _navigationAccent.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
                : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: iconBackgroundColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isSelected
                            ? destination.selectedIcon
                            : destination.icon,
                        size: 20,
                        color: iconColor,
                      ),
                    ),
                    if (destination.badgeCount > 0)
                      Positioned(
                        right: -7,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF13203B)
                                    : _navigationAccent,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 1.4),
                          ),
                          child: Text(
                            destination.badgeCount > 99
                                ? '99+'
                                : '${destination.badgeCount}',
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
                const SizedBox(height: 6),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected ? Colors.white : const Color(0xFF5B687D),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
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

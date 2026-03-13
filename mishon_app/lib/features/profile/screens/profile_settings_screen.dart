import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/settings/app_settings_provider.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(strings.settings),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _SettingsCard(
                  title: strings.settings,
                  subtitle: strings.settingsSubtitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.language,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.languageSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7A90),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<AppLanguage>(
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        segments: [
                          ButtonSegment<AppLanguage>(
                            value: AppLanguage.ru,
                            label: Text(strings.russian),
                          ),
                          ButtonSegment<AppLanguage>(
                            value: AppLanguage.en,
                            label: Text(strings.english),
                          ),
                        ],
                        selected: {settings.language},
                        onSelectionChanged: (selection) {
                          notifier.setLanguage(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  title: strings.interfaceSection,
                  subtitle: strings.interfaceSectionSubtitle,
                  child: Column(
                    children: [
                      _SettingsToggleTile(
                        title: strings.profileAutoRefresh,
                        subtitle: strings.profileAutoRefreshSubtitle,
                        value: settings.profileAutoRefresh,
                        onChanged: notifier.setProfileAutoRefresh,
                      ),
                      const Divider(height: 1),
                      _SettingsToggleTile(
                        title: strings.motionEffects,
                        subtitle: strings.motionEffectsSubtitle,
                        value: settings.motionEffects,
                        onChanged: notifier.setMotionEffects,
                      ),
                      const Divider(height: 1),
                      _SettingsToggleTile(
                        title: strings.messagePreviews,
                        subtitle: strings.messagePreviewsSubtitle,
                        value: settings.messagePreviews,
                        onChanged: notifier.setMessagePreviews,
                      ),
                    ],
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

class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13203B).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C2738),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF69788F),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1C2738),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF69788F),
          height: 1.4,
        ),
      ),
    );
  }
}

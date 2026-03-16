import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/settings/app_settings_provider.dart';
import 'package:mishon_app/core/widgets/app_toast.dart';
import 'package:mishon_app/features/profile/providers/profile_provider.dart';
import 'package:mishon_app/features/profile/screens/profile_security_screens.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  Future<void> _handlePasscodeTap(
    AppStrings strings,
    AppSettingsState settings,
  ) async {
    if (!settings.passcodeLockEnabled) {
      await _configurePasscode(strings, isUpdating: false);
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2DAE9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: Text(
                    strings.isRu ? 'Изменить код-пароль' : 'Change passcode',
                  ),
                  onTap: () => Navigator.of(context).pop('change'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.lock_open_rounded,
                    color: Color(0xFFD1465A),
                  ),
                  title: Text(
                    strings.isRu ? 'Выключить код-пароль' : 'Turn off passcode',
                    style: const TextStyle(color: Color(0xFFD1465A)),
                  ),
                  onTap: () => Navigator.of(context).pop('disable'),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'change') {
      await _configurePasscode(strings, isUpdating: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              strings.isRu ? 'Выключить код-пароль?' : 'Turn off passcode?',
            ),
            content: Text(
              strings.isRu
                  ? 'Приложение больше не будет блокироваться после сворачивания.'
                  : 'The app will no longer lock after moving to the background.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(strings.isRu ? 'Выключить' : 'Turn off'),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(appSettingsProvider.notifier).disablePasscode();
    if (!mounted) {
      return;
    }

    showAppToast(
      context,
      message:
          strings.isRu ? 'Код-пароль отключен' : 'Passcode has been disabled',
    );
  }

  Future<void> _configurePasscode(
    AppStrings strings, {
    required bool isUpdating,
  }) async {
    final passcode = await showDialog<String>(
      context: context,
      builder: (context) => _PasscodeSetupDialog(isUpdating: isUpdating),
    );

    if (!mounted || passcode == null) {
      return;
    }

    await ref.read(appSettingsProvider.notifier).enablePasscode(passcode);
    if (!mounted) {
      return;
    }

    showAppToast(
      context,
      message:
          isUpdating
              ? (strings.isRu ? 'Код-пароль обновлён' : 'Passcode updated')
              : (strings.isRu ? 'Код-пароль включен' : 'Passcode enabled'),
    );
  }

  Future<void> _pickAutoLock(
    AppStrings strings,
    AppSettingsState settings,
  ) async {
    if (!settings.passcodeLockEnabled) {
      showAppToast(
        context,
        message:
            strings.isRu
                ? 'Сначала включите код-пароль'
                : 'Enable the passcode first',
        isError: true,
      );
      return;
    }

    final selection = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2DAE9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                for (final option in const [0, 1, 5, 60])
                  ListTile(
                    leading: Icon(
                      settings.autoLockMinutes == option
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      color:
                          settings.autoLockMinutes == option
                              ? const Color(0xFF2F67FF)
                              : const Color(0xFF7A889C),
                    ),
                    title: Text(_autoLockLabel(strings, option)),
                    onTap: () => Navigator.of(context).pop(option),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
    );

    if (selection == null) {
      return;
    }

    await ref.read(appSettingsProvider.notifier).setAutoLockMinutes(selection);
    if (!mounted) {
      return;
    }

    showAppToast(
      context,
      message: strings.isRu ? 'Автоблокировка обновлена' : 'Auto-lock updated',
    );
  }

  Future<void> _openBlockedUsers() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BlockedUsersScreen()));
  }

  Future<void> _openActiveSessions() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ActiveSessionsScreen()),
    );
  }

  Future<void> _copyLoginEmail(String email, AppStrings strings) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) {
      return;
    }

    showAppToast(
      context,
      message: strings.isRu ? 'Почта скопирована' : 'Email copied',
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final profile = ref.watch(profileNotifierProvider).valueOrNull;
    final blockedUsersAsync = ref.watch(blockedUsersProvider);
    final currentSessionAsync = ref.watch(currentSessionInfoProvider);

    final email =
        profile?.email.trim().isNotEmpty == true
            ? profile!.email.trim()
            : currentSessionAsync.valueOrNull?.email;
    final blockedUsersCount = blockedUsersAsync.when(
      data: (users) => users.length.toString(),
      loading: () => '...',
      error: (_, __) => '--',
    );
    final sessionCount = currentSessionAsync.when(
      data: (_) => '1',
      loading: () => '...',
      error: (_, __) => '--',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                _SettingsHero(
                  title:
                      strings.isRu
                          ? 'Настройки и безопасность'
                          : 'Settings and security',
                  subtitle:
                      strings.isRu
                          ? 'Язык интерфейса, защита приложения, активный сеанс и локальные параметры профиля.'
                          : 'Interface language, app protection, active session, and local profile preferences.',
                ),
                const SizedBox(height: 18),
                _SettingsCard(
                  title: strings.language,
                  subtitle:
                      strings.isRu
                          ? 'Выберите язык интерфейса.'
                          : 'Choose the app interface language.',
                  child: SegmentedButton<AppLanguage>(
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
                    onSelectionChanged:
                        (selection) => notifier.setLanguage(selection.first),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  title: strings.isRu ? 'Безопасность' : 'Security',
                  subtitle:
                      strings.isRu
                          ? 'Код-пароль, автоблокировка, почта для входа и управление блокировками.'
                          : 'Passcode, auto-lock, login email, and blocked users management.',
                  child: Column(
                    children: [
                      _SettingsActionTile(
                        icon: Icons.lock_outline_rounded,
                        title: strings.isRu ? 'Код-пароль' : 'Passcode lock',
                        subtitle:
                            strings.isRu
                                ? 'Блокирует приложение после возвращения из фона.'
                                : 'Locks the app when you return from the background.',
                        value:
                            settings.passcodeLockEnabled
                                ? (strings.isRu ? 'Вкл.' : 'On')
                                : (strings.isRu ? 'Выкл.' : 'Off'),
                        onTap: () => _handlePasscodeTap(strings, settings),
                      ),
                      const Divider(height: 18),
                      _SettingsActionTile(
                        icon: Icons.timer_outlined,
                        title: strings.isRu ? 'Автоблокировка' : 'Auto-lock',
                        subtitle:
                            strings.isRu
                                ? 'Через сколько времени снова спрашивать код.'
                                : 'How long to wait before asking for the code again.',
                        value:
                            settings.passcodeLockEnabled
                                ? _autoLockLabel(
                                  strings,
                                  settings.autoLockMinutes,
                                )
                                : (strings.isRu ? 'Выкл.' : 'Off'),
                        onTap: () => _pickAutoLock(strings, settings),
                        enabled: settings.passcodeLockEnabled,
                      ),
                      const Divider(height: 18),
                      _SettingsActionTile(
                        icon: Icons.alternate_email_rounded,
                        title: strings.isRu ? 'Почта для входа' : 'Login email',
                        subtitle:
                            strings.isRu
                                ? 'Нажмите, чтобы скопировать адрес.'
                                : 'Tap to copy the address.',
                        value: email == null ? '...' : _maskEmail(email),
                        onTap:
                            email == null
                                ? null
                                : () => _copyLoginEmail(email, strings),
                        trailingIcon: Icons.copy_rounded,
                        showChevron: false,
                      ),
                      const Divider(height: 18),
                      _SettingsActionTile(
                        icon: Icons.block_rounded,
                        title:
                            strings.isRu
                                ? 'Заблокированные пользователи'
                                : 'Blocked users',
                        subtitle:
                            strings.isRu
                                ? 'Список пользователей, которых вы заблокировали в чатах.'
                                : 'People you have blocked in chats.',
                        value: blockedUsersCount,
                        onTap: _openBlockedUsers,
                      ),
                      const Divider(height: 18),
                      _SettingsActionTile(
                        icon: Icons.devices_rounded,
                        title:
                            strings.isRu
                                ? 'Активные сеансы'
                                : 'Active sessions',
                        subtitle:
                            strings.isRu
                                ? 'Сейчас в Mishon доступен текущий сеанс устройства.'
                                : 'Mishon currently exposes the current device session.',
                        value: sessionCount,
                        onTap: _openActiveSessions,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  title: strings.interfaceSection,
                  subtitle:
                      strings.isRu
                          ? 'Локальные параметры интерфейса и профиля.'
                          : 'Local interface and profile preferences.',
                  child: Column(
                    children: [
                      _SettingsToggleTile(
                        icon: Icons.sync_outlined,
                        title: strings.profileAutoRefresh,
                        subtitle: strings.profileAutoRefreshSubtitle,
                        value: settings.profileAutoRefresh,
                        onChanged: notifier.setProfileAutoRefresh,
                      ),
                      const Divider(height: 18),
                      _SettingsToggleTile(
                        icon: Icons.animation_outlined,
                        title: strings.motionEffects,
                        subtitle: strings.motionEffectsSubtitle,
                        value: settings.motionEffects,
                        onChanged: notifier.setMotionEffects,
                      ),
                      const Divider(height: 18),
                      _SettingsToggleTile(
                        icon: Icons.chat_bubble_outline_rounded,
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

class _SettingsHero extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SettingsHero({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F4DFF), Color(0xFF6A93FF), Color(0xFFEFF5FF)],
          stops: [0, 0.48, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F4DFF).withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDCE4F2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF081226).withValues(alpha: 0.05),
            blurRadius: 26,
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
              fontWeight: FontWeight.w900,
              color: const Color(0xFF18243C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6C7A91),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback? onTap;
  final bool enabled;
  final IconData? trailingIcon;
  final bool showChevron;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.trailingIcon,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFEAF0FF) : const Color(0xFFF2F4F8),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: enabled ? const Color(0xFF2F67FF) : const Color(0xFFA1ADBF),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color:
                      enabled
                          ? const Color(0xFF18243C)
                          : const Color(0xFFA1ADBF),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      enabled
                          ? const Color(0xFF6C7A91)
                          : const Color(0xFFADB8C8),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 126),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color:
                        enabled
                            ? const Color(0xFF4C5D78)
                            : const Color(0xFFA8B3C4),
                  ),
                ),
              ),
              if (trailingIcon != null || showChevron) ...[
                const SizedBox(width: 8),
                Icon(
                  trailingIcon ?? Icons.chevron_right_rounded,
                  color:
                      enabled
                          ? const Color(0xFF8C98AB)
                          : const Color(0xFFC0C8D6),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.74,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: const Color(0xFF2F67FF)),
        ),
        const SizedBox(width: 14),
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
                  color: const Color(0xFF6C7A91),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _PasscodeSetupDialog extends StatefulWidget {
  final bool isUpdating;

  const _PasscodeSetupDialog({required this.isUpdating});

  @override
  State<_PasscodeSetupDialog> createState() => _PasscodeSetupDialogState();
}

class _PasscodeSetupDialogState extends State<_PasscodeSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passcodeController = TextEditingController();
  final _repeatController = TextEditingController();

  @override
  void dispose() {
    _passcodeController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return AlertDialog(
      title: Text(
        widget.isUpdating
            ? (strings.isRu ? 'Изменить код-пароль' : 'Change passcode')
            : (strings.isRu ? 'Включить код-пароль' : 'Enable passcode'),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _passcodeController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: strings.isRu ? 'Новый код-пароль' : 'New passcode',
                counterText: '',
              ),
              validator: (value) {
                if ((value ?? '').length != 4) {
                  return strings.isRu ? 'Введите 4 цифры' : 'Enter 4 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repeatController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: strings.isRu ? 'Повторите код' : 'Repeat passcode',
                counterText: '',
              ),
              validator: (value) {
                if ((value ?? '').length != 4) {
                  return strings.isRu ? 'Введите 4 цифры' : 'Enter 4 digits';
                }
                if (value != _passcodeController.text) {
                  return strings.isRu
                      ? 'Коды не совпадают'
                      : 'Passcodes do not match';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.isUpdating
                ? strings.save
                : (strings.isRu ? 'Включить' : 'Enable'),
          ),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(_passcodeController.text);
  }
}

String _maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2) {
    return email;
  }

  final name = parts.first;
  if (name.length <= 2) {
    return '$name@${parts.last}';
  }

  return '${name.substring(0, 2)}***@${parts.last}';
}

String _autoLockLabel(AppStrings strings, int minutes) {
  if (minutes <= 0) {
    return strings.isRu ? 'Сразу' : 'Immediately';
  }

  if (minutes == 1) {
    return strings.isRu ? '1 мин' : '1 min';
  }

  if (minutes == 60) {
    return strings.isRu ? '1 ч' : '1 h';
  }

  return strings.isRu ? '$minutes мин' : '$minutes min';
}

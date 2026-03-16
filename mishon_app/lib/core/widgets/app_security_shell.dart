import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/settings/app_settings_provider.dart';

class AppSecurityShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppSecurityShell({super.key, required this.child});

  @override
  ConsumerState<AppSecurityShell> createState() => _AppSecurityShellState();
}

class _AppSecurityShellState extends ConsumerState<AppSecurityShell>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(appSettingsProvider);
    if (!settings.passcodeLockEnabled) {
      return;
    }

    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _backgroundedAt ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (_shouldLock(settings, backgroundedAt) && mounted) {
          setState(() => _isLocked = true);
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  bool _shouldLock(AppSettingsState settings, DateTime? backgroundedAt) {
    if (!settings.passcodeLockEnabled || backgroundedAt == null) {
      return false;
    }

    if (settings.autoLockMinutes <= 0) {
      return true;
    }

    return DateTime.now().difference(backgroundedAt) >=
        Duration(minutes: settings.autoLockMinutes);
  }

  Future<void> _handleUnlock(String passcode) async {
    final isValid = await ref
        .read(appSettingsProvider.notifier)
        .verifyPasscode(passcode);
    if (!mounted || !isValid) {
      throw Exception('invalid-passcode');
    }

    setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    if (!settings.passcodeLockEnabled && _isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isLocked = false);
        }
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_isLocked && settings.passcodeLockEnabled)
          _PasscodeLockOverlay(onUnlock: _handleUnlock),
      ],
    );
  }
}

class _PasscodeLockOverlay extends StatefulWidget {
  final Future<void> Function(String passcode) onUnlock;

  const _PasscodeLockOverlay({required this.onUnlock});

  @override
  State<_PasscodeLockOverlay> createState() => _PasscodeLockOverlayState();
}

class _PasscodeLockOverlayState extends State<_PasscodeLockOverlay> {
  static const _digitsCount = 4;

  String _value = '';
  bool _isChecking = false;
  String? _errorMessage;

  Future<void> _addDigit(String digit) async {
    if (_isChecking || _value.length >= _digitsCount) {
      return;
    }

    setState(() {
      _value = '$_value$digit';
      _errorMessage = null;
    });

    if (_value.length != _digitsCount) {
      return;
    }

    setState(() => _isChecking = true);
    try {
      await widget.onUnlock(_value);
      if (!mounted) {
        return;
      }

      setState(() {
        _value = '';
        _isChecking = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _value = '';
        _isChecking = false;
        _errorMessage =
            AppStrings.of(context).isRu
                ? 'Неверный код-пароль'
                : 'Incorrect passcode';
      });
    }
  }

  void _removeDigit() {
    if (_isChecking || _value.isEmpty) {
      return;
    }

    setState(() {
      _value = _value.substring(0, _value.length - 1);
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(color: Color(0xC918213C), dismissible: false),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF081226).withValues(alpha: 0.2),
                          blurRadius: 36,
                          offset: const Offset(0, 24),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2C5BFF), Color(0xFF5A8CFF)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2C5BFF,
                                  ).withValues(alpha: 0.24),
                                  blurRadius: 22,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            strings.isRu
                                ? 'Mishon заблокирован'
                                : 'Mishon is locked',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF18243C),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            strings.isRu
                                ? 'Введите код-пароль, чтобы продолжить.'
                                : 'Enter your passcode to continue.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF66748C),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List<Widget>.generate(
                              _digitsCount,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      index < _value.length
                                          ? const Color(0xFF2C5BFF)
                                          : const Color(0xFFD8E0F0),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 160),
                            opacity: _errorMessage == null ? 0 : 1,
                            child: SizedBox(
                              height: 20,
                              child: Text(
                                _errorMessage ?? '',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFD1465A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final digit in const [
                                '1',
                                '2',
                                '3',
                                '4',
                                '5',
                                '6',
                                '7',
                                '8',
                                '9',
                              ])
                                _PasscodeKey(
                                  label: digit,
                                  onTap: () => _addDigit(digit),
                                ),
                              const SizedBox(width: 74, height: 74),
                              _PasscodeKey(
                                label: '0',
                                onTap: () => _addDigit('0'),
                              ),
                              _PasscodeKey(
                                icon: Icons.backspace_outlined,
                                onTap: _removeDigit,
                              ),
                            ],
                          ),
                          if (_isChecking) ...[
                            const SizedBox(height: 18),
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasscodeKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  const _PasscodeKey({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF3F6FD),
            border: Border.all(color: const Color(0xFFD9E2F2)),
          ),
          child: Center(
            child:
                icon != null
                    ? Icon(icon, color: const Color(0xFF46556F))
                    : Text(
                      label ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF18243C),
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}

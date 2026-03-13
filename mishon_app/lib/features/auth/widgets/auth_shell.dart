import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mishon_app/core/theme/app_theme.dart';

const _authCardRadius = 24.0;
const _authFieldRadius = 18.0;
const _authPrimaryGradient = LinearGradient(
  colors: [Color(0xFF4A8DFF), Color(0xFF7C63FF)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);
const _authDisabledGradient = LinearGradient(
  colors: [Color(0xFFB2BEDF), Color(0xFFB9C4E5)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

class AuthScreenShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardPadding = width < 380 ? 24.0 : 32.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5F8FF), Color(0xFFF0EEFF), Color(0xFFEAF4FF)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: -120,
                left: -80,
                child: _GlowOrb(
                  size: 260,
                  colors: [Color(0xFFB5D8FF), Color(0x33B5D8FF)],
                ),
              ),
              const Positioned(
                bottom: -140,
                right: -60,
                child: _GlowOrb(
                  size: 280,
                  colors: [Color(0xFFD4C4FF), Color(0x33D4C4FF)],
                ),
              ),
              const Positioned(
                top: 120,
                right: -40,
                child: _GlowOrb(
                  size: 180,
                  colors: [Color(0xFFF4D8FF), Color(0x22F4D8FF)],
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0, end: 1),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 24 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_authCardRadius),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  _authCardRadius,
                                ),
                                color: Colors.white.withValues(alpha: 0.82),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x145662C8),
                                    blurRadius: 40,
                                    offset: Offset(0, 24),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(cardPadding),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _AuthLogo(),
                                    const SizedBox(height: 24),
                                    Text(
                                      'MISHON',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium?.copyWith(
                                        letterSpacing: 2.8,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      subtitle,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    ...children,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;
  final bool obscureText;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late final FocusNode _focusNode;
  late bool _obscured;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
    _obscured = widget.obscureText;
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_hasFocus != _focusNode.hasFocus) {
      setState(() => _hasFocus = _focusNode.hasFocus);
    }
  }

  void _handleControllerChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _hasFocus ? AppColors.primary : AppColors.textTertiary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_authFieldRadius),
        boxShadow:
            _hasFocus
                ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ]
                : const [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        textCapitalization: widget.textCapitalization,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          helperText: widget.helperText,
          filled: true,
          fillColor: _hasFocus ? Colors.white : const Color(0xFFF8FAFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 20,
          ),
          prefixIcon: Icon(widget.prefixIcon, size: 20, color: iconColor),
          suffixIcon: _buildSuffixIcon(),
          hintStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
          labelStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          floatingLabelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _hasFocus ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
          helperMaxLines: 2,
          errorMaxLines: 2,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_authFieldRadius),
            borderSide: const BorderSide(color: Color(0xFFD9E2F4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_authFieldRadius),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_authFieldRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_authFieldRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.obscureText) {
      return IconButton(
        splashRadius: 20,
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: _hasFocus ? AppColors.primary : AppColors.textTertiary,
        ),
      );
    }

    if (widget.controller.text.isEmpty) {
      return null;
    }

    return IconButton(
      splashRadius: 20,
      onPressed: widget.controller.clear,
      icon: const Icon(
        Icons.close_rounded,
        size: 18,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class AuthPrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AuthPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return Listener(
      onPointerDown:
          isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isEnabled ? widget.onPressed : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: Colors.white70,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient:
                    isEnabled ? _authPrimaryGradient : _authDisabledGradient,
                boxShadow:
                    isEnabled
                        ? [
                          const BoxShadow(
                            color: Color(0x224A8DFF),
                            blurRadius: 22,
                            offset: Offset(0, 14),
                          ),
                        ]
                        : const [],
              ),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 18),
                child:
                    widget.isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : Text(
                          widget.text,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  final String text;

  const AuthDivider({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFD9E2F4))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFD9E2F4))),
      ],
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;

  const AuthSocialButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.72),
            border: Border.all(color: const Color(0xFFD9E2F4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthFooter extends StatelessWidget {
  final String label;
  final String action;
  final VoidCallback? onTap;

  const AuthFooter({
    super.key,
    required this.label,
    required this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                action,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFFFF5F7),
        border: Border.all(color: const Color(0xFFFFD6DE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFB42553),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GoogleBrandIcon extends StatelessWidget {
  const GoogleBrandIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4285F4),
      ),
    );
  }
}

class AppleBrandIcon extends StatelessWidget {
  const AppleBrandIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.apple_rounded,
      size: 20,
      color: AppColors.textPrimary,
    );
  }
}

void showSocialAuthPlaceholder(BuildContext context, String provider) {
  // Intentionally silent: informational snackbars are disabled.
}

String formatAuthErrorMessage(Object error, {required String fallback}) {
  final message = error.toString().trim();
  if (message.isEmpty || message == 'null') {
    return fallback;
  }

  final lower = message.toLowerCase();
  if (lower.contains('invalid email or password')) {
    return 'Invalid email or password.';
  }
  if (lower.contains('email already in use')) {
    return 'This email is already connected to another account.';
  }
  if (lower.contains('username already taken')) {
    return 'That username is already taken.';
  }
  if (lower.contains('email is required')) {
    return 'Email is required.';
  }
  if (lower.contains('password is required')) {
    return 'Password is required.';
  }
  if (lower.contains('invalid email')) {
    return 'Enter a valid email address.';
  }
  if (lower.contains('offline') || lower.contains('connection')) {
    return 'Check your internet connection and try again.';
  }
  if (message.contains('Р')) {
    return fallback;
  }

  return message;
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GlowOrb({required this.size, required this.colors});

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

class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: _authPrimaryGradient,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F4A8DFF),
              blurRadius: 24,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            Center(
              child: Text(
                'M',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

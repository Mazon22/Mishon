import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/theme/app_theme.dart';
import 'package:mishon_app/features/auth/widgets/mishon_brand_mark.dart';

const _authCardRadius = 28.0;
const _authFieldRadius = 20.0;
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
const _authSheetBarrier = Color(0x260F1728);

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
    final screenSize = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final isWide = screenSize.width >= 980;
    final isCompact = screenSize.width < 600;
    final topLeftOrbSize = isWide ? 300.0 : 180.0;
    final bottomRightOrbSize = isWide ? 280.0 : 170.0;
    final topRightOrbSize = isWide ? 210.0 : 130.0;
    final outerPadding = EdgeInsets.symmetric(
      horizontal: isWide ? 36 : (isCompact ? 18 : 22),
      vertical: isWide ? 28 : (isCompact ? 14 : 18),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFCFDFF), Color(0xFFF5F8FD), Color(0xFFEDF2F8)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: isWide ? -120 : -58,
                left: isWide ? -90 : -54,
                child: _GlowOrb(
                  size: topLeftOrbSize,
                  colors: const [Color(0x33B5D8FF), Color(0x00B5D8FF)],
                ),
              ),
              Positioned(
                bottom: isWide ? -140 : -70,
                right: isWide ? -60 : -36,
                child: _GlowOrb(
                  size: bottomRightOrbSize,
                  colors: const [Color(0x28D4C4FF), Color(0x00D4C4FF)],
                ),
              ),
              Positioned(
                top: isWide ? 90 : 54,
                right: isWide ? -30 : -20,
                child: _GlowOrb(
                  size: topRightOrbSize,
                  colors: const [Color(0x22F4D8FF), Color(0x00F4D8FF)],
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        outerPadding.left,
                        outerPadding.top,
                        outerPadding.right,
                        outerPadding.bottom + viewInsets.bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              constraints.maxHeight - outerPadding.vertical,
                        ),
                        child: Center(
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
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isWide ? 1080 : 460,
                              ),
                              child:
                                  isWide
                                      ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const Expanded(
                                            child: _AuthLandingHero(),
                                          ),
                                          const SizedBox(width: 52),
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: _AuthCardFrame(
                                                title: title,
                                                subtitle: subtitle,
                                                children: children,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                      : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _AuthMobileHero(
                                            title: title,
                                            subtitle: subtitle,
                                          ),
                                          const SizedBox(height: 18),
                                          _AuthCardFrame(
                                            title: title,
                                            subtitle: subtitle,
                                            showHeader: false,
                                            compact: true,
                                            children: children,
                                          ),
                                        ],
                                      ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthMobileHero extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AuthMobileHero({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Center(child: MishonBrandMark(size: 78)),
        const SizedBox(height: 14),
        Text(
          'Mishon',
          textAlign: TextAlign.center,
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.6,
            color: const Color(0xFF101726),
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.displaySmall?.copyWith(
              fontSize: 34,
              height: 1.02,
              letterSpacing: -1.3,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF101726),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 316),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF5C6C81),
              height: 1.46,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthLandingHero extends StatelessWidget {
  const _AuthLandingHero();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 500;
    const headlineSize = 66.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCompact) ...[
          const Center(child: MishonBrandMark(size: 108)),
          const SizedBox(height: 18),
          Column(
            children: [
              Text(
                'Mishon',
                textAlign: TextAlign.center,
                style: textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2.1,
                  color: const Color(0xFF101726),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.isRu ? 'Социальная сеть' : 'Social network',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6D7D91),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ] else ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MishonBrandMark(size: 126),
              const SizedBox(height: 22),
              Text(
                'Mishon',
                style: textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2.2,
                  color: const Color(0xFF101726),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.isRu ? 'Социальная сеть' : 'Social network',
                style: textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF6D7D91),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
        ],
        Text(
          strings.isRu ? 'АККАУНТ MISHON' : 'MISHON ACCOUNT',
          textAlign: isCompact ? TextAlign.center : TextAlign.left,
          style: textTheme.labelMedium?.copyWith(
            color: const Color(0xFF68768A),
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _AuthHeroHeadline(fontSize: headlineSize, centered: isCompact),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isCompact ? 360 : 420),
          child: Text(
            strings.isRu
                ? 'Люди, новости и сообщения рядом на каждом вашем устройстве.'
                : 'People, updates, and messages stay close on every device.',
            textAlign: isCompact ? TextAlign.center : TextAlign.left,
            style: textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF56667B),
              height: 1.52,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthHeroHeadline extends StatelessWidget {
  final double fontSize;
  final bool centered;

  const _AuthHeroHeadline({required this.fontSize, this.centered = false});

  @override
  Widget build(BuildContext context) {
    final lines =
        AppStrings.of(context).isRu
            ? const ['Оставайтесь', 'в ритме', 'Mishon.']
            : const ['Stay in', 'the rhythm', 'of Mishon.'];

    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0)
            SizedBox(height: i == 1 ? fontSize * 0.12 : fontSize * 0.1),
          Text(
            lines[i],
            textAlign: centered ? TextAlign.center : TextAlign.left,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: fontSize,
              height: 0.92,
              letterSpacing: -fontSize * 0.055,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF101726),
            ),
          ),
        ],
      ],
    );
  }
}

class _AuthCardFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showHeader;
  final bool compact;

  const _AuthCardFrame({
    required this.title,
    required this.subtitle,
    required this.children,
    this.showHeader = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardPadding =
        compact ? (width < 380 ? 20.0 : 24.0) : (width < 380 ? 22.0 : 28.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_authCardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: compact ? 14 : 18,
          sigmaY: compact ? 14 : 18,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_authCardRadius),
            color: Colors.white.withValues(alpha: compact ? 0.9 : 0.86),
            border: Border.all(
              color:
                  compact
                      ? const Color(0xFFF0F4FB)
                      : Colors.white.withValues(alpha: 0.78),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x145662C8),
                blurRadius: compact ? 28 : 38,
                offset: Offset(0, compact ? 18 : 24),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showHeader) ...[
                  const Center(
                    child: MishonBrandMark(size: 56, showGlow: false),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'MISHON',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.06,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                ...children,
              ],
            ),
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
    final strings = AppStrings.of(context);
    final iconColor = _hasFocus ? AppColors.primary : AppColors.textTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.labelText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF546378),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_authFieldRadius),
            boxShadow:
                _hasFocus
                    ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 12),
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
              hintText: widget.hintText,
              helperText: widget.helperText,
              filled: true,
              fillColor: _hasFocus ? Colors.white : const Color(0xFFF8FAFF),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon: Icon(widget.prefixIcon, size: 19, color: iconColor),
              suffixIcon: _buildSuffixIcon(strings),
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF95A2B4),
                fontWeight: FontWeight.w500,
              ),
              helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.35,
              ),
              errorStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
              helperMaxLines: 2,
              errorMaxLines: 2,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_authFieldRadius),
                borderSide: const BorderSide(color: Color(0xFFD7E1F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_authFieldRadius),
                borderSide: const BorderSide(
                  color: Color(0xFF7A93FF),
                  width: 1.4,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_authFieldRadius),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 1.2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_authFieldRadius),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon(AppStrings strings) {
    if (widget.obscureText) {
      return IconButton(
        splashRadius: 20,
        tooltip:
            _obscured
                ? (strings.isRu ? 'Показать пароль' : 'Show password')
                : (strings.isRu ? 'Скрыть пароль' : 'Hide password'),
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
      tooltip: strings.isRu ? 'Очистить поле' : 'Clear field',
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
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient:
                    isEnabled ? _authPrimaryGradient : _authDisabledGradient,
                boxShadow:
                    isEnabled
                        ? [
                          const BoxShadow(
                            color: Color(0x204A8DFF),
                            blurRadius: 20,
                            offset: Offset(0, 12),
                          ),
                        ]
                        : const [],
              ),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                            fontWeight: FontWeight.w800,
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
        const Expanded(child: Divider(color: AppColors.divider)),
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
        const Expanded(child: Divider(color: AppColors.divider)),
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.surface.withValues(alpha: 0.94),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: Center(child: icon)),
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
              fontWeight: FontWeight.w600,
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
  final strings = AppStrings.of(context);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: _authSheetBarrier,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF0F4FB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14182740),
                blurRadius: 24,
                offset: Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      provider,
                      style: Theme.of(
                        sheetContext,
                      ).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    tooltip:
                        MaterialLocalizations.of(
                          sheetContext,
                        ).closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      backgroundColor: const Color(0xFFF6F8FD),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                strings.socialProviderComingSoon(provider),
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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

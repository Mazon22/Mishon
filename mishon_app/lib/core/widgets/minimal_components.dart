import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mishon_app/core/theme/app_theme.dart';
import 'package:mishon_app/core/theme/app_tokens.dart';

class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final bool clipContent;

  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.color,
    this.borderColor,
    this.radius = AppRadii.xl,
    this.boxShadow,
    this.onTap,
    this.clipContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppColors.divider),
      boxShadow: boxShadow ?? AppShadows.soft(),
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(
        decoration: decoration,
        child:
            clipContent
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: content,
                )
                : content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child:
              clipContent
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: content,
                  )
                  : content,
        ),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final Color? accentColor;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? AppColors.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted?.call(),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon:
                value.text.isEmpty
                    ? null
                    : IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    ),
          ),
        );
      },
    );
  }
}

class AppMetricCard extends StatelessWidget {
  final String value;
  final String label;
  final Color accentColor;
  final IconData? icon;

  const AppMetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.accentColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      color: accentColor.withValues(alpha: 0.06),
      borderColor: accentColor.withValues(alpha: 0.18),
      boxShadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              if (icon != null) Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AppCompactActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool enabled;
  final Color accentColor;

  const AppCompactActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value,
    this.onTap,
    this.enabled = true,
    this.accentColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color:
                enabled
                    ? accentColor.withValues(alpha: 0.10)
                    : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(
            icon,
            color: enabled ? accentColor : AppColors.textTertiary,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color:
                      enabled ? AppColors.textPrimary : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      enabled
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (value != null) ...[
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value!,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color:
                    enabled ? AppColors.textSecondary : AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Icon(
          Icons.chevron_right_rounded,
          color: enabled ? AppColors.textTertiary : AppColors.surfaceVariant,
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}

class AppVerifiedBadge extends StatelessWidget {
  final double size;

  const AppVerifiedBadge({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final iconSize = (size * 0.66).clamp(10.0, 14.0).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          color: Color(0xFF2F9CFF),
          shape: AppVerifiedBadgeShape(),
        ),
        child: Center(
          child: Icon(Icons.check_rounded, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }
}

class AppVerifiedBadgeShape extends ShapeBorder {
  const AppVerifiedBadgeShape();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    final center = rect.center;
    final outerRadius = math.min(rect.width, rect.height) / 2;
    final innerRadius = outerRadius * 0.82;
    const spikes = 12;

    for (var i = 0; i < spikes * 2; i++) {
      final isOuter = i.isEven;
      final radius = isOuter ? outerRadius : innerRadius;
      final angle = -math.pi / 2 + (math.pi / spikes) * i;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  final String username;
  final String? imageUrl;
  final double size;
  final double scale;
  final double offsetX;
  final double offsetY;
  final bool circle;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final List<Color>? fallbackColors;

  const AppAvatar({
    super.key,
    required this.username,
    required this.imageUrl,
    this.size = 48,
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.circle = true,
    this.borderRadius,
    this.onTap,
    this.fallbackColors,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.32);
    final child = SizedBox(
      width: size,
      height: size,
      child: _MediaViewport(
        imageUrl: imageUrl,
        scale: scale,
        offsetX: offsetX,
        offsetY: offsetY,
        fallback: _AvatarFallback(
          username: username,
          size: size,
          colors: fallbackColors,
          circle: circle,
          borderRadius: radius,
        ),
      ),
    );

    final clipped = circle ? ClipOval(child: child) : ClipRRect(borderRadius: radius, child: child);
    if (onTap == null) {
      return clipped;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: circle ? null : radius,
        customBorder: circle ? const CircleBorder() : null,
        onTap: onTap,
        child: clipped,
      ),
    );
  }
}

class ProfileBanner extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final double scale;
  final double offsetX;
  final double offsetY;
  final BorderRadius borderRadius;
  final Widget? foreground;

  const ProfileBanner({
    super.key,
    required this.imageUrl,
    required this.height,
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.borderRadius = const BorderRadius.all(Radius.circular(32)),
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F2147),
                    Color(0xFF2C5BFF),
                    Color(0xFFFF8B52),
                  ],
                ),
              ),
            ),
            if (imageUrl != null && imageUrl!.isNotEmpty)
              _MediaViewport(
                imageUrl: imageUrl,
                scale: scale,
                offsetX: offsetX,
                offsetY: offsetY,
                fallback: const SizedBox.shrink(),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    const Color(0xFF081226).withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
            if (foreground != null) foreground!,
          ],
        ),
      ),
    );
  }
}

class _MediaViewport extends StatelessWidget {
  final String? imageUrl;
  final double scale;
  final double offsetX;
  final double offsetY;
  final Widget fallback;

  const _MediaViewport({
    required this.imageUrl,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return fallback;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final dx = constraints.maxWidth * 0.35 * offsetX;
        final dy = constraints.maxHeight * 0.35 * offsetY;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => fallback,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String username;
  final double size;
  final List<Color>? colors;
  final bool circle;
  final BorderRadius borderRadius;

  const _AvatarFallback({
    required this.username,
    required this.size,
    required this.colors,
    required this.circle,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ??
              const [
                Color(0xFF1F4BFF),
                Color(0xFF54A8FF),
                Color(0xFFFF9B60),
              ],
        ),
      ),
      child: Center(
        child: Text(
          username.isEmpty ? '?' : username.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }
}

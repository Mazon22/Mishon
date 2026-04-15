import 'package:flutter/material.dart';

class MishonBrandMark extends StatelessWidget {
  final double size;
  final bool showGlow;

  const MishonBrandMark({
    super.key,
    this.size = 88,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.28;
    final letterSize = size * 0.52;
    final dotSize = size * 0.09;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showGlow)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5B7CFF).withValues(alpha: 0.14),
                        blurRadius: size * 0.28,
                        spreadRadius: size * 0.02,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0F1728),
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F1728).withValues(alpha: 0.14),
                  blurRadius: size * 0.18,
                  offset: Offset(0, size * 0.08),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      fontSize: letterSize,
                      height: 0.92,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -letterSize * 0.08,
                      color: const Color(0xFFF8FAFC),
                    ),
                  ),
                ),
                Positioned(
                  top: size * 0.18,
                  right: size * 0.18,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFF5B7CFF),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: dotSize, height: dotSize),
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

import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets page = EdgeInsets.fromLTRB(16, 16, 16, 24);
  static const EdgeInsets pageCompact = EdgeInsets.fromLTRB(12, 12, 12, 18);
  static const EdgeInsets card = EdgeInsets.all(18);
  static const EdgeInsets cardDense = EdgeInsets.all(14);
}

class AppRadii {
  AppRadii._();

  static const double xs = 12;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;
  static const double pill = 999;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft({Color color = const Color(0xFF111827)}) {
    return <BoxShadow>[
      BoxShadow(
        color: color.withValues(alpha: 0.06),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static List<BoxShadow> elevated({Color color = const Color(0xFF111827)}) {
    return <BoxShadow>[
      BoxShadow(
        color: color.withValues(alpha: 0.08),
        blurRadius: 30,
        offset: const Offset(0, 16),
      ),
    ];
  }
}

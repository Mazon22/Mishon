import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _activeToastEntry;
Timer? _activeToastTimer;

void showAppToast(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }

  _activeToastTimer?.cancel();
  _activeToastEntry?.remove();
  _activeToastEntry = null;

  final accentColor =
      isError ? const Color(0xFFD1465A) : const Color(0xFF2A8F6A);
  final surfaceColor =
      isError ? const Color(0xFFFDF1F3) : const Color(0xFFF1FBF6);
  final icon =
      isError ? Icons.error_outline_rounded : Icons.check_circle_rounded;
  final topInset = MediaQuery.viewPaddingOf(context).top + 14;

  final entry = OverlayEntry(
    builder:
        (context) => Positioned(
          top: topInset,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.98),
                      surfaceColor,
                    ],
                  ),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.12),
                        ),
                        child: Icon(icon, size: 18, color: accentColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Color(0xFF18243C),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
  );

  _activeToastEntry = entry;
  overlay.insert(entry);

  _activeToastTimer = Timer(Duration(milliseconds: isError ? 3200 : 2200), () {
    if (identical(_activeToastEntry, entry)) {
      _activeToastEntry?.remove();
      _activeToastEntry = null;
    } else {
      entry.remove();
    }
  });
}

import 'dart:typed_data';

import 'package:flutter/material.dart';

enum ProfileMediaKind { avatar, banner }

class ProfileMediaEditResult {
  final Uint8List bytes;
  final double scale;
  final double offsetX;
  final double offsetY;

  const ProfileMediaEditResult({
    required this.bytes,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });
}

class ProfileMediaEditorScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final ProfileMediaKind kind;
  final double initialScale;
  final double initialOffsetX;
  final double initialOffsetY;

  const ProfileMediaEditorScreen({
    super.key,
    required this.imageBytes,
    required this.kind,
    required this.initialScale,
    required this.initialOffsetX,
    required this.initialOffsetY,
  });

  @override
  State<ProfileMediaEditorScreen> createState() => _ProfileMediaEditorScreenState();
}

class _ProfileMediaEditorScreenState extends State<ProfileMediaEditorScreen> {
  late double _scale = widget.initialScale.clamp(1.0, 4.0);
  late double _offsetX = widget.initialOffsetX;
  late double _offsetY = widget.initialOffsetY;

  double _gestureStartScale = 1;
  double _gestureStartOffsetX = 0;
  double _gestureStartOffsetY = 0;
  Offset _gestureOrigin = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final isAvatar = widget.kind == ProfileMediaKind.avatar;
    final title = isAvatar ? 'Avatar setup' : 'Banner setup';
    final subtitle = isAvatar
        ? 'Drag and zoom to choose how the avatar sits in the frame.'
        : 'Drag and zoom to line up the banner the way you want.';

    return Scaffold(
      backgroundColor: const Color(0xFF081226),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(
                ProfileMediaEditResult(
                  bytes: widget.imageBytes,
                  scale: _scale,
                  offsetX: _offsetX,
                  offsetY: _offsetY,
                ),
              );
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 640,
                      maxHeight: isAvatar ? 420 : 360,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportHeight = isAvatar
                            ? constraints.maxWidth.clamp(240.0, 340.0)
                            : constraints.maxWidth.clamp(220.0, 320.0) * 0.56;
                        final viewportWidth = isAvatar ? viewportHeight : constraints.maxWidth;
                        final viewportSize = Size(viewportWidth, viewportHeight);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onScaleStart: (details) {
                                _gestureStartScale = _scale;
                                _gestureStartOffsetX = _offsetX;
                                _gestureStartOffsetY = _offsetY;
                                _gestureOrigin = details.focalPoint;
                              },
                              onScaleUpdate: (details) {
                                setState(() {
                                  _scale = (_gestureStartScale * details.scale).clamp(1.0, 4.0);
                                  final delta = details.focalPoint - _gestureOrigin;
                                  _offsetX = (_gestureStartOffsetX + (delta.dx / viewportSize.width) * 1.15).clamp(-2.0, 2.0);
                                  _offsetY = (_gestureStartOffsetY + (delta.dy / viewportSize.height) * 1.15).clamp(-2.0, 2.0);
                                });
                              },
                              child: _EditorPreview(
                                bytes: widget.imageBytes,
                                kind: widget.kind,
                                scale: _scale,
                                offsetX: _offsetX,
                                offsetY: _offsetY,
                                width: viewportSize.width,
                                height: viewportSize.height,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.zoom_in_rounded, color: Colors.white70),
                                Expanded(
                                  child: Slider(
                                    value: _scale,
                                    min: 1,
                                    max: 4,
                                    onChanged: (value) => setState(() => _scale = value),
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    _scale.toStringAsFixed(1),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _scale = 1;
                                      _offsetX = 0;
                                      _offsetY = 0;
                                    });
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reset'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isAvatar
                                        ? 'Pinch or drag inside the circle.'
                                        : 'Pinch or drag inside the banner.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.white70,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
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

class _EditorPreview extends StatelessWidget {
  final Uint8List bytes;
  final ProfileMediaKind kind;
  final double scale;
  final double offsetX;
  final double offsetY;
  final double width;
  final double height;

  const _EditorPreview({
    required this.bytes,
    required this.kind,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final child = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: kind == ProfileMediaKind.avatar
                  ? const [
                      Color(0xFF1B4DFF),
                      Color(0xFF6AA4FF),
                      Color(0xFFFF9A62),
                    ]
                  : const [
                      Color(0xFF09152A),
                      Color(0xFF2F67FF),
                      Color(0xFFFF8C54),
                    ],
            ),
          ),
        ),
        _MemoryViewport(
          bytes: bytes,
          scale: scale,
          offsetX: offsetX,
          offsetY: offsetY,
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.12),
              ],
            ),
          ),
        ),
      ],
    );

    if (kind == ProfileMediaKind.avatar) {
      return ClipOval(
        child: SizedBox(width: width, height: width, child: child),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

class _MemoryViewport extends StatelessWidget {
  final Uint8List bytes;
  final double scale;
  final double offsetX;
  final double offsetY;

  const _MemoryViewport({
    required this.bytes,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  Widget build(BuildContext context) {
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
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}

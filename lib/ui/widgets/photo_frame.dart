import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Wraps [child] with a decorative frame.
/// [frame]: null | 'border_amber' | 'border_coral' | 'shimmer' | 'sparkle'
/// [radius]: corner radius of the child (used to match border curves).
class PhotoFrame extends StatefulWidget {
  const PhotoFrame({
    super.key,
    required this.child,
    this.frame,
    this.radius = 0,
  });
  final Widget child;
  final String? frame;
  final double radius;

  @override
  State<PhotoFrame> createState() => _PhotoFrameState();
}

class _PhotoFrameState extends State<PhotoFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  bool get _isAnimated =>
      widget.frame == 'shimmer' || widget.frame == 'sparkle';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.frame == 'sparkle' ? 4 : 2),
    );
    if (_isAnimated) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(PhotoFrame old) {
    super.didUpdateWidget(old);
    final wasAnimated = old.frame == 'shimmer' || old.frame == 'sparkle';
    if (_isAnimated && !wasAnimated) {
      _ctrl.duration =
          Duration(seconds: widget.frame == 'sparkle' ? 4 : 2);
      _ctrl.repeat();
    } else if (!_isAnimated && wasAnimated) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (widget.frame) {
    'border_amber' => CustomPaint(
      foregroundPainter:
          _BorderPainter(color: AppTokens.amber, radius: widget.radius),
      child: widget.child,
    ),
    'border_coral' => CustomPaint(
      foregroundPainter:
          _BorderPainter(color: AppTokens.coral, radius: widget.radius),
      child: widget.child,
    ),
    'shimmer' => AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        foregroundPainter:
            _ShimmerPainter(progress: _ctrl.value, radius: widget.radius),
        child: widget.child,
      ),
    ),
    'sparkle' => AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        foregroundPainter: _SparklePainter(progress: _ctrl.value),
        child: widget.child,
      ),
    ),
    _ => widget.child,
  };
}

// ── Static border ──────────────────────────────────────────────────────────

class _BorderPainter extends CustomPainter {
  const _BorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset rect by half-stroke so the outer edge aligns with the ClipRRect curve.
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(max(0, radius - 2)));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_BorderPainter old) =>
      old.color != color || old.radius != radius;
}

// ── Shimmer arc-en-ciel ────────────────────────────────────────────────────

class _ShimmerPainter extends CustomPainter {
  const _ShimmerPainter({required this.progress, required this.radius});
  final double progress;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(max(0, radius - 2)));
    final shader = SweepGradient(
      transform: GradientRotation(progress * 2 * pi),
      colors: const [
        Color(0xFFFF0000),
        Color(0xFFFF9900),
        Color(0xFFFFFF00),
        Color(0xFF00EE44),
        Color(0xFF0099FF),
        Color(0xFF9900FF),
        Color(0xFFFF0000),
      ],
    ).createShader(rect);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = shader
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// ── Sparkle (12 particules en orbite) ─────────────────────────────────────

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = cx + 10;
    final ry = cy + 10;
    const count = 12;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final angle = (progress + i / count) * 2 * pi;
      final x = cx + rx * cos(angle);
      final y = cy + ry * sin(angle);
      final twinkle = (sin((progress * 3 + i / count) * 2 * pi) + 1) / 2;
      final r = 2.5 + twinkle * 2.5;
      paint.color = Color.lerp(
        AppTokens.amber,
        Colors.white,
        twinkle,
      )!.withValues(alpha: 0.6 + twinkle * 0.4);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.progress != progress;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Verre de bière animé extrait du splash — logo réutilisable à n'importe
/// quelle taille. Toutes les dimensions scalent à partir de [height].
class BeerGlassLogo extends StatefulWidget {
  const BeerGlassLogo({super.key, this.height = 80});
  final double height;

  @override
  State<BeerGlassLogo> createState() => _BeerGlassLogoState();
}

class _BeerGlassLogoState extends State<BeerGlassLogo>
    with TickerProviderStateMixin {
  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final AnimationController _foam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final AnimationController _bubbles = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _wobble.dispose();
    _foam.dispose();
    _bubbles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dimensions de référence identiques au SplashScreen (138 × 188).
    final s = widget.height / 188.0;
    final gW = 138.0 * s;
    final gH = 188.0 * s;
    final b = 6.0 * s;
    final fillH = (gH - b * 2) * 0.82; // verre toujours plein

    return SizedBox(
      width: gW,
      height: gH,
      child: AnimatedBuilder(
        animation: _wobble,
        builder: (_, child) {
          final angle =
              (Curves.easeInOut.transform(_wobble.value) * 2 - 1) *
              3.5 *
              math.pi /
              180;
          return Transform.rotate(
            angle: angle,
            alignment: const Alignment(0, 0.8),
            child: child,
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Corps du verre.
            Container(
              width: gW,
              height: gH,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF2).withValues(alpha: 0.55),
                border: Border.all(color: const Color(0xFF241308), width: b),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14 * s),
                  topRight: Radius.circular(14 * s),
                  bottomLeft: Radius.circular(26 * s),
                  bottomRight: Radius.circular(26 * s),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: fillH,
                      child: _Beer(foam: _foam, bubbles: _bubbles, s: s),
                    ),
                  ),
                ],
              ),
            ),
            // Reflet.
            Positioned(
              top: 10 * s,
              left: 14 * s,
              child: Container(
                width: 14 * s,
                height: 130 * s,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Beer extends StatelessWidget {
  const _Beer({required this.foam, required this.bubbles, required this.s});
  final AnimationController foam;
  final AnimationController bubbles;
  final double s;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFC247), Color(0xFFF4A722), Color(0xFFE8920E)],
              stops: [0, 0.6, 1],
            ),
          ),
        ),
      ),
      // Mousse.
      Positioned(
        top: -13 * s,
        left: -4 * s,
        right: -4 * s,
        child: AnimatedBuilder(
          animation: foam,
          builder: (_, child) => Transform.translate(
            offset: Offset(
              0,
              -3 * Curves.easeInOut.transform(foam.value) * s,
            ),
            child: child,
          ),
          child: Container(
            height: 26 * s,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFFDF7),
                  spreadRadius: -2,
                  offset: Offset(0, -7 * s),
                ),
              ],
            ),
          ),
        ),
      ),
      // Bulles.
      _Bubble(ctrl: bubbles, s: s, leftFraction: 0.26, size: 9, phase: 0.0),
      _Bubble(ctrl: bubbles, s: s, leftFraction: 0.54, size: 7, phase: 0.45),
      _Bubble(ctrl: bubbles, s: s, leftFraction: 0.70, size: 6, phase: 0.75),
    ],
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.ctrl,
    required this.s,
    required this.leftFraction,
    required this.size,
    required this.phase,
  });
  final AnimationController ctrl;
  final double s;
  final double leftFraction;
  final double size;
  final double phase;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ctrl,
    builder: (_, _) {
      final t = (ctrl.value + phase) % 1.0;
      final rise = 110 * t * s;
      final opacity = t < 0.15 ? t / 0.15 * 0.9 : (1 - t) * 0.9;
      return Positioned(
        left: leftFraction * 130 * s,
        bottom: 12 * s + rise,
        child: Opacity(
          opacity: opacity.clamp(0.0, 0.9),
          child: Container(
            width: size * s,
            height: size * s,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB).withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    },
  );
}

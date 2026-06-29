import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Splash de chargement : un verre qui se remplit, se balance, avec mousse,
/// bulles qui montent et points de chargement. Reprend l'animation du handoff
/// (`docs/Pinte App - Animation + Login.html`).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Entrée du verre (glassPop) : joué une fois.
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  // Remplissage (fillUp) : 0 → 78 % de hauteur, joué une fois après un délai.
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  // Balancement (wobble) : oscillation continue.
  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  // Mousse (foamBob) + bulles (bubbleRise) + points (loadDots).
  late final AnimationController _foam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final AnimationController _bubbles = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) _fill.forward();
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    _fill.dispose();
    _wobble.dispose();
    _foam.dispose();
    _bubbles.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.56), // ≈ 50% 22 %
          radius: 1.0,
          colors: [Color(0xFFFFD9A0), Color(0xFFFFB36B), Color(0xFFFF8C4D)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildGlass(),
          const SizedBox(height: 34),
          _buildCaption(),
        ],
      ),
    );
  }

  Widget _buildGlass() {
    return AnimatedBuilder(
      animation: _entry,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_entry.value);
        final scale = 0.5 + 0.5 * t;
        final dy = 30 * (1 - t);
        return Opacity(
          opacity: _entry.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _wobble,
        builder: (context, child) {
          final angle =
              (Curves.easeInOut.transform(_wobble.value) * 2 - 1) *
              3.5 *
              math.pi /
              180;
          return Transform.rotate(
            angle: angle,
            alignment: const Alignment(0, 0.8), // pivot ≈ 50% 90 %
            child: child,
          );
        },
        child: _glassBody(),
      ),
    );
  }

  Widget _glassBody() {
    const glassW = 138.0;
    const glassH = 188.0;
    const border = 6.0;
    const interiorH = glassH - border * 2;
    const fillMax = interiorH * 0.82;

    return SizedBox(
      width: glassW,
      height: glassH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Corps du verre.
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF2).withValues(alpha: 0.55),
              border: Border.all(color: const Color(0xFF241308), width: border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Bière qui monte.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _fill,
                    builder: (context, _) {
                      final h =
                          fillMax * Curves.easeInOut.transform(_fill.value);
                      return SizedBox(
                        height: h,
                        child: _beer(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Reflet du verre.
          Positioned(
            top: 10,
            left: 14,
            child: Container(
              width: 14,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _beer() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Liquide.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFC247),
                  Color(0xFFF4A722),
                  Color(0xFFE8920E),
                ],
                stops: [0, 0.6, 1],
              ),
            ),
          ),
        ),
        // Mousse.
        Positioned(
          top: -13,
          left: -4,
          right: -4,
          child: AnimatedBuilder(
            animation: _foam,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -3 * Curves.easeInOut.transform(_foam.value)),
              child: child,
            ),
            child: Container(
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(50),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFFFFDF7), spreadRadius: -2, blurRadius: 0, offset: Offset(0, -7)),
                ],
              ),
            ),
          ),
        ),
        // Bulles.
        _bubble(leftFraction: 0.26, size: 9, phase: 0.0),
        _bubble(leftFraction: 0.54, size: 7, phase: 0.45),
        _bubble(leftFraction: 0.70, size: 6, phase: 0.75),
      ],
    );
  }

  Widget _bubble({
    required double leftFraction,
    required double size,
    required double phase,
  }) {
    return AnimatedBuilder(
      animation: _bubbles,
      builder: (context, _) {
        final t = (_bubbles.value + phase) % 1.0;
        final rise = 110 * t;
        final opacity = t < 0.15 ? t / 0.15 * 0.9 : (1 - t) * 0.9;
        return Positioned(
          left: leftFraction * 130,
          bottom: 12 + rise,
          child: Opacity(
            opacity: opacity.clamp(0.0, 0.9),
            child: Container(
              width: size,
              height: size,
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

  Widget _buildCaption() {
    return Column(
      children: [
        Text(
          'Tchin.beer',
          style: displayStyle(size: 27).copyWith(color: const Color(0xFF2A1206)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(0.0),
            const SizedBox(width: 6),
            _dot(0.18),
            const SizedBox(width: 6),
            _dot(0.36),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'On remplit ton verre…',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF7A4310),
          ),
        ),
      ],
    );
  }

  Widget _dot(double phase) {
    return AnimatedBuilder(
      animation: _dots,
      builder: (context, _) {
        final t = (_dots.value + phase) % 1.0;
        // 0.25 → 1 → 0.25 (pic au milieu).
        final opacity = 0.25 + 0.75 * (1 - (t - 0.5).abs() * 2);
        return Opacity(
          opacity: opacity.clamp(0.25, 1.0),
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFF2A1206),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Durée minimale d'affichage du splash (le temps que l'animation respire),
/// indépendamment de la vitesse de résolution de la session.
const splashMinDuration = Duration(milliseconds: 2300);

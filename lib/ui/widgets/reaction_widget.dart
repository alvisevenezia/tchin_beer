import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'beer_glass_logo.dart';

const kReactionOrder = ['fire', 'star', 'tchin', 'wave', 'confetti'];

const _reactionLabels = {
  'fire': 'Fire',
  'star': 'Star',
  'tchin': 'Tchin',
  'wave': 'Wave',
  'confetti': 'Confetti',
};

/// Icône animée d'une réaction, identifiée par [type] (fire/star/tchin/wave/confetti).
class ReactionIcon extends StatelessWidget {
  const ReactionIcon({super.key, required this.type, this.size = 22});
  final String type;
  final double size;

  @override
  Widget build(BuildContext context) => switch (type) {
    'fire' => _PulsingHeart(size: size),
    'star' => _SpinningStar(size: size),
    'tchin' => SizedBox(
      width: size,
      height: size,
      child: FittedBox(child: BeerGlassLogo(height: size * 1.3)),
    ),
    'wave' => _Waves(size: size),
    'confetti' => _Confetti(size: size),
    _ => Icon(Icons.emoji_emotions, size: size, color: AppTokens.muted),
  };
}

class _PulsingHeart extends StatefulWidget {
  const _PulsingHeart({required this.size});
  final double size;
  @override
  State<_PulsingHeart> createState() => _PulsingHeartState();
}

class _PulsingHeartState extends State<_PulsingHeart>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, _) => Transform.scale(
      scale: 1 + Curves.easeInOut.transform(_ctrl.value) * 0.22,
      child: Icon(Icons.favorite, size: widget.size, color: AppTokens.coral),
    ),
  );
}

class _SpinningStar extends StatefulWidget {
  const _SpinningStar({required this.size});
  final double size;
  @override
  State<_SpinningStar> createState() => _SpinningStarState();
}

class _SpinningStarState extends State<_SpinningStar>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, _) => Transform.rotate(
      angle: _ctrl.value * 2 * math.pi,
      child: Icon(Icons.star_rounded, size: widget.size, color: AppTokens.amber),
    ),
  );
}

class _Waves extends StatefulWidget {
  const _Waves({required this.size});
  final double size;
  @override
  State<_Waves> createState() => _WavesState();
}

class _WavesState extends State<_Waves> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(painter: _WavePainter(_ctrl.value)),
    ),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    for (final phase in [0.0, 0.5]) {
      final localT = (t + phase) % 1.0;
      final r = maxR * localT;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppTokens.sky.withValues(alpha: (1 - localT).clamp(0.0, 1.0));
      canvas.drawCircle(center, r, paint);
    }
    canvas.drawCircle(
      center,
      maxR * 0.25,
      Paint()..color = AppTokens.sky,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.size});
  final double size;
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  static const _colors = [
    AppTokens.coral,
    AppTokens.amber,
    AppTokens.sky,
    Color(0xFF3A7D44),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_ctrl.value, _colors)),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.t, this.colors);
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    for (var i = 0; i < colors.length; i++) {
      final angle = (i / colors.length) * 2 * math.pi + t * 2 * math.pi;
      final dot = center + Offset(math.cos(angle), math.sin(angle)) * r * 0.75;
      final twinkle = (math.sin((t + i / colors.length) * 2 * math.pi) + 1) / 2;
      canvas.drawCircle(
        dot,
        size.shortestSide * 0.09 * (0.7 + twinkle * 0.5),
        Paint()..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Bottom sheet de sélection d'une super réaction parmi celles débloquées.
class ReactionPicker extends StatelessWidget {
  const ReactionPicker({
    super.key,
    required this.availableReactions,
    required this.onSelect,
  });
  final List<String> availableReactions;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (availableReactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Débloque des super réactions dans la boutique !',
          style: TextStyle(color: AppTokens.muted, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: [
          for (final type in kReactionOrder)
            if (availableReactions.contains(type))
              _PickerButton(
                type: type,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect(type);
                },
              ),
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.type, required this.onTap});
  final String type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTokens.foam,
            shape: BoxShape.circle,
            boxShadow: const [AppTokens.cardShadow],
          ),
          child: Center(child: ReactionIcon(type: type, size: 28)),
        ),
        const SizedBox(height: 6),
        Text(
          _reactionLabels[type] ?? type,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTokens.muted,
          ),
        ),
      ],
    ),
  );
}

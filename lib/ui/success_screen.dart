import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../util/format.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({
    super.key,
    required this.number,
    required this.onSeeFeed,
    required this.onContinue,
  });
  final int number;
  final VoidCallback onSeeFeed;
  final VoidCallback onContinue;

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _beer;
  late final Animation<double> _plus;
  late final Animation<double> _text;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _beer = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
    );
    _plus = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.65, curve: Curves.elasticOut),
    );
    _text = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            colors: [Color(0xFFFFD9A0), Color(0xFFFF8C4D)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _beer,
                  child: const Text('🍺', style: TextStyle(fontSize: 88)),
                ),
                ScaleTransition(
                  scale: _plus,
                  child: Text('+1', style: displayStyle(size: 62)),
                ),
                FadeTransition(
                  opacity: _text,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Pinte n° ${formatCountFr(widget.number)} validée !',
                        style: displayStyle(size: 24),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        child: Text(
                          'Le compteur grimpe, et ta ville gagne +1 dans la guerre des villes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF241308),
                        ),
                        onPressed: widget.onSeeFeed,
                        child: const Text(
                          'Voir le fil',
                          style: TextStyle(color: Color(0xFFFFCB6B)),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onContinue,
                        child: const Text('Continuer'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

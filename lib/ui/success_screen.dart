import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../util/format.dart';

class SuccessScreen extends StatelessWidget {
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
                const Text('🍺', style: TextStyle(fontSize: 88)),
                Text('+1', style: displayStyle(size: 62)),
                const SizedBox(height: 8),
                Text(
                  'Pinte n° ${formatCountFr(number)} validée !',
                  style: displayStyle(size: 24),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Text(
                    'Le compteur grimpe, et ta ville gagne +1.',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF241308),
                  ),
                  onPressed: onSeeFeed,
                  child: const Text(
                    'Voir le fil',
                    style: TextStyle(color: Color(0xFFFFCB6B)),
                  ),
                ),
                TextButton(
                  onPressed: onContinue,
                  child: const Text('Continuer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

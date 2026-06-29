import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_controller.dart';
import 'root_gate.dart';
import 'splash_screen.dart';

/// Affiche le [SplashScreen] par-dessus l'app au démarrage, puis le fait
/// disparaître en fondu une fois que (1) la session est résolue et (2) la durée
/// minimale d'animation s'est écoulée.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key});

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> {
  bool _minElapsed = false;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(splashMinDuration, () {
      if (mounted) setState(() => _minElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final sessionReady = session.hasValue || session.hasError;
    final showSplash = !(_minElapsed && sessionReady);

    return Stack(
      children: [
        const RootGate(),
        if (!_removed)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !showSplash,
              child: AnimatedOpacity(
                opacity: showSplash ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeIn,
                onEnd: () {
                  if (!showSplash && mounted) setState(() => _removed = true);
                },
                child: const SplashScreen(),
              ),
            ),
          ),
      ],
    );
  }
}

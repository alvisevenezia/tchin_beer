import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/counter_controller.dart';
import '../state/session_controller.dart';
import 'app_shell.dart';
import 'onboarding_screen.dart';

class RootGate extends ConsumerWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return session.when(
      // Pendant le chargement, le SplashGate recouvre cet écran : on évite donc
      // un spinner qui « flashe » derrière le splash.
      loading: () => const Scaffold(body: SizedBox.expand()),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
      data: (s) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        child: switch (s) {
          NeedsOnboarding() => const OnboardingScreen(key: ValueKey('onboarding')),
          Authenticated() => const _AuthedApp(key: ValueKey('app')),
        },
      ),
    );
  }
}

class _AuthedApp extends ConsumerStatefulWidget {
  const _AuthedApp({super.key});
  @override
  ConsumerState<_AuthedApp> createState() => _AuthedAppState();
}

class _AuthedAppState extends ConsumerState<_AuthedApp> {
  @override
  void initState() {
    super.initState();
    // Démarre le flux SSE compteur après le 1er frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(counterControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) => const AppShell();
}

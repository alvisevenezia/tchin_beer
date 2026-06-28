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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
      data: (s) => switch (s) {
        NeedsOnboarding() => const OnboardingScreen(),
        Authenticated() => const _AuthedApp(),
      },
    );
  }
}

class _AuthedApp extends ConsumerStatefulWidget {
  const _AuthedApp();
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

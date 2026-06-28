import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pseudo = TextEditingController();
  final _city = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pseudo.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.screenPadH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text('Le Million\nde Pintes', style: displayStyle(size: 36)),
              const SizedBox(height: 24),
              TextField(
                controller: _pseudo,
                decoration: const InputDecoration(labelText: 'Ton pseudo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'Ta ville'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTokens.coral),
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? '...' : 'Rejoindre le mouvement'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_pseudo.text.trim().isEmpty || _city.text.trim().isEmpty) return;
    setState(() => _busy = true);
    await ref
        .read(sessionControllerProvider.notifier)
        .signUp(pseudo: _pseudo.text.trim(), city: _city.text.trim());
    if (mounted) setState(() => _busy = false);
  }
}

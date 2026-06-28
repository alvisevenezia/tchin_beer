import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/counter_controller.dart';
import '../state/profile_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../util/format.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onAddPinte});
  final VoidCallback onAddPinte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.screenPadH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LiveDot(active: !counter.reconnecting),
                const SizedBox(width: 8),
                Text(
                  counter.reconnecting ? 'RECONNEXION…' : 'EN DIRECT',
                  style: const TextStyle(
                    color: AppTokens.coral,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Pintes bues par la communauté',
              style: TextStyle(color: AppTokens.muted),
            ),
            const SizedBox(height: 8),
            Text(formatCountFr(counter.total), style: displayStyle(size: 66)),
            const Text(
              '/ 1 000 000 — l\'objectif',
              style: TextStyle(
                color: Color(0xFFB89A6E),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _Progress(value: counter.total / 1000000),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: '${profile.value?.myCount ?? 0}',
                    label: 'tes pintes',
                    color: AppTokens.amber,
                  ),
                ),
                const SizedBox(width: AppTokens.gapCard),
                Expanded(
                  child: _StatCard(
                    value: '${profile.value?.streak ?? 0} 🔥',
                    label: 'jours d\'affilée',
                    color: AppTokens.coral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.coral,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: onAddPinte,
              child: const Text('🍺 Ajoute ta pinte'),
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '+1 vers le million',
                  style: TextStyle(color: AppTokens.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    width: 11,
    height: 11,
    decoration: BoxDecoration(
      color: active ? AppTokens.live : AppTokens.muted,
      shape: BoxShape.circle,
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(100),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 16,
      backgroundColor: AppTokens.rail,
      color: AppTokens.coral,
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTokens.foam,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: displayStyle(size: 26).copyWith(color: color)),
        Text(label, style: const TextStyle(color: AppTokens.muted)),
      ],
    ),
  );
}

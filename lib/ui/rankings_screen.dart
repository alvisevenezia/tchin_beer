import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ranking.dart';
import '../state/rankings_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../util/format.dart';

const _medal2 = Color(0xFFFF8A3D);

class RankingsScreen extends ConsumerWidget {
  const RankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(rankingsControllerProvider);
    final notifier = ref.read(rankingsControllerProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('La guerre\ndes villes',
                style: displayStyle(size: 30).copyWith(height: 1.05)),
            const SizedBox(height: 16),
            Row(
              children: [
                _PeriodPill(
                  label: 'Aujourd\'hui',
                  active: s.period == 'day',
                  onTap: () => notifier.setPeriod('day'),
                ),
                const SizedBox(width: 8),
                _PeriodPill(
                  label: 'Cette semaine',
                  active: s.period == 'week',
                  onTap: () => notifier.setPeriod('week'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            s.data.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorBox(onRetry: notifier.refresh),
              data: (r) => r.cities.isEmpty
                  ? const _EmptyBox()
                  : _List(rankings: r),
            ),
            const SizedBox(height: 24),
            const _DerbyTeaser(),
          ],
        ),
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppTokens.ink : AppTokens.foam,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: active ? Colors.white : AppTokens.muted,
              )),
        ),
      );
}

class _List extends StatelessWidget {
  const _List({required this.rankings});
  final Rankings rankings;
  @override
  Widget build(BuildContext context) {
    final top = rankings.cities.first.count;
    return Column(
      children: [
        for (final c in rankings.cities) ...[
          _Row(city: c, topCount: top, isMine: c.key == rankings.me?.key),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.city, required this.topCount, required this.isMine});
  final CityRank city;
  final int topCount;
  final bool isMine;

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  Color get _fill => switch (city.rank) {
        1 => AppTokens.amber,
        2 => _medal2,
        3 => AppTokens.coral,
        _ => AppTokens.sky,
      };

  @override
  Widget build(BuildContext context) {
    final isTop3 = city.rank <= 3;
    final label = _medals[city.rank] ?? '${city.rank} ·';
    final headStyle = TextStyle(
      fontWeight: isTop3 ? FontWeight.w700 : FontWeight.w600,
      fontSize: isTop3 ? 17 : 16,
      color: isTop3 ? AppTokens.ink : const Color(0xFF6A573C),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(label, style: headStyle),
                  Text(city.name, style: headStyle),
                  if (isMine)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTokens.coral,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text('ta ville',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            Text(formatCountFr(city.count), style: headStyle),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: topCount == 0 ? 0 : (city.count / topCount).clamp(0.0, 1.0),
            minHeight: isTop3 ? 16 : 14,
            backgroundColor: AppTokens.rail,
            color: _fill,
          ),
        ),
      ],
    );
  }
}

class _DerbyTeaser extends StatelessWidget {
  const _DerbyTeaser();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF241308),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚔️ Derby du week-end',
                style: displayStyle(size: 18).copyWith(color: const Color(0xFFFFCB6B))),
            const SizedBox(height: 4),
            const Text('Bientôt : des duels programmés entre villes.',
                style: TextStyle(color: Color(0xFFFFE3C2), fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Text("Personne n'a encore trinqué. Sois le premier ! 🍺",
            textAlign: TextAlign.center, style: TextStyle(color: AppTokens.muted, fontWeight: FontWeight.w600)),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const Text('Classement indisponible.', style: TextStyle(color: AppTokens.muted)),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      );
}

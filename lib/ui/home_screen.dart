import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/counter_controller.dart';
import '../state/profile_controller.dart';
import '../state/rankings_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../util/format.dart';
import '../util/invite.dart';
import 'widgets/beer_glass_logo.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onAddPinte,
    required this.onGoVilles,
  });
  final VoidCallback onAddPinte;
  final VoidCallback onGoVilles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    final cityRank = ref.watch(myWeekCityRankProvider);
    final city = profile.value?.city;
    final rank = cityRank.maybeWhen(data: (c) => c?.rank, orElse: () => null);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.screenPadH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BeerGlassLogo(height: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'tchin.beer',
                        style: displayStyle(size: 20).copyWith(
                          color: const Color(0xFF2A1206),
                        ),
                      ),
                      Row(
                        children: [
                          _LiveDot(active: !counter.reconnecting),
                          const SizedBox(width: 6),
                          Text(
                            counter.reconnecting ? 'RECONNEXION…' : 'EN DIRECT',
                            style: const TextStyle(
                              color: AppTokens.coral,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => shareInvite(total: counter.total),
                  icon: const Icon(Icons.ios_share, color: AppTokens.coral),
                  tooltip: 'Inviter des potes',
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Pintes bues par la communauté',
              style: TextStyle(color: AppTokens.muted, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(formatCountFr(counter.total), style: displayStyle(size: 66)),
            const Text(
              '/ 1 000 000 — l\'objectif',
              style: TextStyle(
                color: Color(0xFFB89A6E),
                fontWeight: FontWeight.w700,
                fontSize: 17,
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
            if (city != null) ...[
              const SizedBox(height: 12),
              _CityTeaserCard(city: city, rank: rank, onTap: onGoVilles),
            ],
            const SizedBox(height: 24),
            _CtaButton(onPressed: onAddPinte),
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

// ─── Dot « EN DIRECT » avec animation pulse ───────────────────────────────

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.active});
  final bool active;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 1.0, end: 0.25).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: widget.active ? AppTokens.live : AppTokens.muted,
        shape: BoxShape.circle,
      ),
    );
    return widget.active ? FadeTransition(opacity: _opacity, child: dot) : dot;
  }
}

// ─── Barre de progression dégradée ───────────────────────────────────────

class _Progress extends StatelessWidget {
  const _Progress({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => Container(
    height: 16,
    decoration: BoxDecoration(
      color: AppTokens.rail,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
    ),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: value.clamp(0.0, 1.0),
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppTokens.progressGradient,
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusPill)),
        ),
      ),
    ),
  );
}

// ─── Carte stat (pintes / streak) ────────────────────────────────────────

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
      boxShadow: const [AppTokens.cardShadow],
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

// ─── Carte ville teaser ───────────────────────────────────────────────────

class _CityTeaserCard extends StatelessWidget {
  const _CityTeaserCard({
    required this.city,
    required this.rank,
    required this.onTap,
  });
  final String city;
  final int? rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rankLabel = rank != null ? '$rankᵉ' : '—';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTokens.sky,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          boxShadow: const [AppTokens.cardShadow],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TA VILLE CETTE SEMAINE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📍 $city · $rankLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              '›',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bouton CTA avec ombre corail ────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [AppTokens.ctaShadow],
    ),
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppTokens.coral,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: onPressed,
      child: const Text(
        '🍺 Ajoute ta pinte',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/profile_controller.dart';
import '../state/rankings_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    return SafeArea(
      child: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (p) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.screenPadH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 37,
                backgroundColor: AppTokens.coral,
                child: Text(
                  p.pseudo.characters.first,
                  style: const TextStyle(color: Colors.white, fontSize: 28),
                ),
              ),
              const SizedBox(height: 12),
              Text(p.pseudo, style: displayStyle(size: 26)),
              Text(
                '📍 ${p.city}',
                style: const TextStyle(color: AppTokens.muted),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat('${p.myCount}', 'pintes'),
                  _Stat('${p.streak}', 'jours'),
                  Consumer(
                    builder: (context, ref, _) {
                      final me = ref.watch(myWeekCityRankProvider);
                      final label = me.maybeWhen(
                        data: (c) => c == null ? '—' : '${c.rank}ᵉ',
                        orElse: () => '—',
                      );
                      return _Stat(label, 'rang ville');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _TeaserCard(
                title: 'Membre Fondateur',
                subtitle: 'Badge numéroté · réservé aux OG',
                color: Color(0xFF241308),
              ),
              const SizedBox(height: 12),
              const _TeaserCard(
                title: 'Passer à Pinte+',
                subtitle: '2,99 €/mois · stats, badges, avatar',
                color: AppTokens.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: displayStyle(size: 26)),
      Text(label, style: const TextStyle(color: AppTokens.muted)),
    ],
  );
}

class _TeaserCard extends StatelessWidget {
  const _TeaserCard({
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final String title, subtitle;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFFFE3C2),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        Text(subtitle, style: const TextStyle(color: Color(0xFFFFCB6B))),
      ],
    ),
  );
}

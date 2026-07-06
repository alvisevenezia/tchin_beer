import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/profile_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'widgets/photo_frame.dart';
import 'widgets/reaction_widget.dart';

// Catalogue miroir de back/app/routers/shop.py::FRAME_CATALOG.
const _catalog = [
  (id: 'shimmer', label: 'Shimmer', emoji: '🌈', price: '1,49 €', desc: 'Bordure arc-en-ciel animée'),
  (id: 'sparkle', label: 'Sparkle', emoji: '✨', price: '1,99 €', desc: '12 particules dorées en orbite'),
];

// Catalogue miroir de back/app/routers/shop.py::REACTION_PACK_CATALOG.
const _packCatalog = [
  (
    id: 'party_pack',
    label: 'Party',
    reactions: ['fire', 'star', 'tchin', 'wave', 'confetti'],
    price: '1,99 €',
  ),
];

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final Set<String> _buying = {};

  Future<void> _buy(String frameId) async {
    setState(() => _buying.add(frameId));
    try {
      await ref.read(profileControllerProvider.notifier).buyFrame(frameId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadre débloqué ! 🎉'),
            backgroundColor: Color(0xFF3A7D44),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().contains('ALREADY_OWNED')
            ? 'Déjà dans ta collection.'
            : 'Erreur — réessaie.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _buying.remove(frameId));
    }
  }

  Future<void> _buyPack(String packId) async {
    setState(() => _buying.add(packId));
    try {
      await ref.read(profileControllerProvider.notifier).buyPack(packId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pack débloqué ! 🎉'),
            backgroundColor: Color(0xFF3A7D44),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().contains('ALREADY_OWNED')
            ? 'Déjà débloqué.'
            : 'Erreur — réessaie.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _buying.remove(packId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: AppTokens.cream,
      appBar: AppBar(
        backgroundColor: AppTokens.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTokens.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Boutique', style: displayStyle(size: 20).copyWith(color: AppTokens.ink)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (p) => ListView(
            padding: const EdgeInsets.all(AppTokens.screenPadH),
            children: [
              const Text(
                'Cadres',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTokens.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Achat unique · disponible immédiatement',
                style: TextStyle(color: AppTokens.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ..._catalog.map(
                (item) => _FrameCard(
                  item: item,
                  owned: p.ownsFrame(item.id),
                  buying: _buying.contains(item.id),
                  onBuy: () => _buy(item.id),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Super réactions',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTokens.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Débloque des réactions animées en plus du ♥',
                style: TextStyle(color: AppTokens.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTokens.sky.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '🔥⭐ Fire et Star sont gratuites dès le départ !',
                  style: TextStyle(
                    color: AppTokens.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              ..._packCatalog.map(
                (pack) => _PackCard(
                  pack: pack,
                  owned: pack.reactions.every(p.availableReactions.contains),
                  buying: _buying.contains(pack.id),
                  onBuy: () => _buyPack(pack.id),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTokens.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                  border: Border.all(color: AppTokens.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Text('✨', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pinte+ · 2,99 €/mois',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTokens.ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tous les cadres + stats avancées + badge',
                            style: TextStyle(color: AppTokens.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required this.item,
    required this.owned,
    required this.buying,
    required this.onBuy,
  });
  final ({String id, String label, String emoji, String price, String desc}) item;
  final bool owned;
  final bool buying;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.foam,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        boxShadow: const [AppTokens.cardShadow],
        border: owned
            ? Border.all(color: AppTokens.amber.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Prévisualisation du cadre avec l'animation réelle.
          PhotoFrame(
            frame: owned ? item.id : null,
            radius: 28,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFE3C2),
              ),
              child: Center(
                child: Text(item.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTokens.ink,
                  ),
                ),
                Text(
                  item.desc,
                  style: const TextStyle(color: AppTokens.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (owned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3A7D44).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '✓ Acquis',
                style: TextStyle(
                  color: Color(0xFF3A7D44),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.coral,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: buying ? null : onBuy,
              child: buying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      item.price,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
            ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.owned,
    required this.buying,
    required this.onBuy,
  });
  final ({String id, String label, List<String> reactions, String price}) pack;
  final bool owned;
  final bool buying;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.foam,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        boxShadow: const [AppTokens.cardShadow],
        border: owned
            ? Border.all(color: AppTokens.amber.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 32,
            child: Stack(
              children: [
                for (var i = 0; i < pack.reactions.length; i++)
                  Positioned(
                    left: i * 12.0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFE3C2),
                      ),
                      child: Center(
                        child: ReactionIcon(type: pack.reactions[i], size: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTokens.ink,
                  ),
                ),
                Text(
                  '${pack.reactions.length} réactions animées',
                  style: const TextStyle(color: AppTokens.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (owned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3A7D44).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '✓ Acquis',
                style: TextStyle(
                  color: Color(0xFF3A7D44),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.coral,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: buying ? null : onBuy,
              child: buying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      pack.price,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
            ),
        ],
      ),
    );
  }
}

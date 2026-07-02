import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/profile.dart';
import '../state/profile_controller.dart';
import '../state/rankings_controller.dart';
import 'shop_screen.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'widgets/city_picker.dart';
import 'widgets/photo_frame.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _changingCity = false;
  bool _uploadingAvatar = false;

  Future<void> _openPremiumSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTokens.foam,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PremiumSheet(
        onSubscribe: () =>
            ref.read(profileControllerProvider.notifier).activatePremium(),
      ),
    );
  }

  Future<void> _openCityPicker(String currentCity) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTokens.foam,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CityChangeSheet(currentCity: currentCity),
    );
    if (chosen == null || chosen == currentCity || !mounted) return;
    setState(() => _changingCity = true);
    try {
      await ref.read(profileControllerProvider.notifier).changeCity(chosen);
    } finally {
      if (mounted) setState(() => _changingCity = false);
    }
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTokens.foam,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AvatarSourceSheet(),
    );
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      await ref.read(profileControllerProvider.notifier).uploadAvatar(
        bytes: bytes,
        filename: file.name,
        contentType: 'image/jpeg',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Échec de l'upload — réessaie.")),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // ── Avatar ──────────────────────────────────────────────────
              GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    PhotoFrame(
                      frame: p.frame,
                      radius: 37,
                      child: _AvatarCircle(
                        pseudo: p.pseudo,
                        avatarUrl: p.avatarUrl,
                        uploading: _uploadingAvatar,
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTokens.coral,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 13, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(p.pseudo, style: displayStyle(size: 26)),
              if (p.isPremium) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppTokens.amber, AppTokens.coral]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✨ Pinte+',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _changingCity ? null : () => _openCityPicker(p.city),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTokens.foam,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTokens.rail),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_changingCity)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Text('📍', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        p.city,
                        style: const TextStyle(
                          color: AppTokens.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 13, color: AppTokens.muted),
                    ],
                  ),
                ),
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
              const SizedBox(height: 20),
              const _BadgesRow(),
              if (p.isPremium) ...[
                const SizedBox(height: 20),
                _AdvancedStats(),
              ],
              const SizedBox(height: 20),

              // ── Sélecteur de cadre ──────────────────────────────────────
              _FrameSelector(
                currentFrame: p.frame,
                myCount: p.myCount,
                profile: p,
                onSelect: (frame) =>
                    ref.read(profileControllerProvider.notifier).changeFrame(frame),
                onLockedTap: _openPremiumSheet,
                onShopTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                ),
              ),
              const SizedBox(height: 24),

              // ── Carte Fondateur ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppTokens.foundersGradient,
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Membre Fondateur',
                            style: TextStyle(
                              color: Color(0xFFFFE3C2),
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Text(
                          'N° 0457',
                          style: displayStyle(size: 15).copyWith(
                            color: const Color(0xFFFFCB6B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Badge numéroté · réservé aux OG',
                      style: TextStyle(
                        color: Color(0xFFFFCB6B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Carte Pinte+ (si pas encore premium) ───────────────────
              if (!p.isPremium) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _openPremiumSheet,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTokens.amber,
                      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Passer à Pinte+',
                                style: TextStyle(
                                  color: Color(0xFF2A1A0D),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '2,99 €/mois · cadres animés, stats avancées',
                                style: TextStyle(
                                  color: Color(0xFF2A1A0D),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Color(0xFF2A1A0D)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Avatar circle ─────────────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.pseudo,
    this.avatarUrl,
    this.uploading = false,
  });
  final String pseudo;
  final String? avatarUrl;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (uploading) {
      inner = const CircularProgressIndicator(color: Colors.white);
    } else if (avatarUrl != null) {
      inner = ClipOval(
        child: Image.network(
          avatarUrl!,
          width: 74,
          height: 74,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Initial(pseudo: pseudo),
        ),
      );
    } else {
      inner = _Initial(pseudo: pseudo);
    }
    return Container(
      width: 74,
      height: 74,
      decoration: const BoxDecoration(
        gradient: AppTokens.avatarGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.pseudo});
  final String pseudo;

  @override
  Widget build(BuildContext context) => Text(
    pseudo.characters.first,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.w800,
    ),
  );
}

// ── Sélecteur de cadre ────────────────────────────────────────────────────────

class _FrameSelector extends StatelessWidget {
  const _FrameSelector({
    required this.currentFrame,
    required this.myCount,
    required this.profile,
    required this.onSelect,
    required this.onLockedTap,
    required this.onShopTap,
  });
  final String? currentFrame;
  final int myCount;
  final Profile profile;
  final void Function(String?) onSelect;
  final VoidCallback onLockedTap;
  final VoidCallback onShopTap;

  @override
  Widget build(BuildContext context) {
    final frames = [
      (id: null as String?, label: 'Aucun', emoji: '✕', free: true),
      (id: 'border_amber', label: 'Or', emoji: '🟡', free: myCount >= 1),
      (id: 'border_coral', label: 'Corail', emoji: '🟠', free: myCount >= 10),
      (id: 'shimmer', label: 'Shimmer', emoji: '🌈', free: false),
      (id: 'sparkle', label: 'Sparkle', emoji: '✨', free: false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Cadre',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTokens.ink),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onShopTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTokens.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🛍️', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 4),
                    Text('Boutique',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.amber)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: frames.map((f) {
              final owned = f.free || (f.id != null && profile.ownsFrame(f.id!));
              final selected = currentFrame == f.id;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: owned ? () => onSelect(f.id) : onShopTap,
                  child: Opacity(
                    opacity: owned ? 1.0 : 0.45,
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? AppTokens.coral : AppTokens.rail,
                              width: selected ? 3 : 1.5,
                            ),
                            color: AppTokens.foam,
                          ),
                          child: Center(
                            child: owned
                                ? Text(f.emoji, style: const TextStyle(fontSize: 22))
                                : const Icon(Icons.storefront, size: 18, color: AppTokens.muted),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? AppTokens.coral : AppTokens.muted,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Sheet source avatar ───────────────────────────────────────────────────────

class _AvatarSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Choisir une photo',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTokens.ink,
          ),
        ),
        const SizedBox(height: 20),
        _SourceTile(
          icon: Icons.camera_alt,
          label: 'Prendre une photo',
          onTap: () => Navigator.of(context).pop(ImageSource.camera),
        ),
        const SizedBox(height: 10),
        _SourceTile(
          icon: Icons.photo_library,
          label: 'Choisir depuis la galerie',
          onTap: () => Navigator.of(context).pop(ImageSource.gallery),
        ),
      ],
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTokens.foam,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTokens.rail, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTokens.coral),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppTokens.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Widgets partagés ──────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: displayStyle(size: 26)),
      Text(
        label,
        style: const TextStyle(
          color: AppTokens.muted,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ],
  );
}

class _BadgesRow extends StatelessWidget {
  const _BadgesRow();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _Badge(color: AppTokens.amber, label: '🍺'),
      const SizedBox(width: 10),
      _Badge(color: AppTokens.coral, label: '🔥'),
      const SizedBox(width: 10),
      _Badge(color: AppTokens.sky, label: '🏆'),
      const SizedBox(width: 10),
      _Badge(
        color: AppTokens.tabInactive.withValues(alpha: 0.5),
        label: '+8',
        textColor: AppTokens.ink,
      ),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.color,
    required this.label,
    this.textColor = Colors.white,
  });
  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Text(
      label,
      style: TextStyle(
        fontSize: 22,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ── Sheet changement de ville ─────────────────────────────────────────────────

class _CityChangeSheet extends StatefulWidget {
  const _CityChangeSheet({required this.currentCity});
  final String currentCity;

  @override
  State<_CityChangeSheet> createState() => _CityChangeSheetState();
}

class _CityChangeSheetState extends State<_CityChangeSheet> {
  final _ctrl = TextEditingController();
  bool _detecting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    setState(() => _detecting = true);
    try {
      final chosen = await detectAndPickCity(context);
      if (chosen != null && mounted) Navigator.of(context).pop(chosen);
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
        24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Changer de ville',
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 20, color: AppTokens.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'Actuellement : ${widget.currentCity}',
          style: const TextStyle(color: AppTokens.muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _detecting ? null : _detect,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTokens.foam,
              border: Border.all(color: AppTokens.rail, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (_detecting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Text('📍', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Text(
                  _detecting ? 'Détection…' : 'Détecter ma position',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTokens.ink),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Row(children: [
          Expanded(child: Divider(color: AppTokens.rail)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('ou',
                style: TextStyle(color: AppTokens.muted, fontSize: 13)),
          ),
          Expanded(child: Divider(color: AppTokens.rail)),
        ]),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTokens.foam,
            border: Border.all(color: AppTokens.rail, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTokens.ink),
            decoration: const InputDecoration(
              hintText: 'Saisir une ville…',
              hintStyle: TextStyle(color: AppTokens.tabInactive),
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.coral,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              final v = _ctrl.text.trim();
              if (v.isNotEmpty) Navigator.of(context).pop(v);
            },
            child: const Text(
              'Valider',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Sheet Premium ─────────────────────────────────────────────────────────────

class _PremiumSheet extends StatelessWidget {
  const _PremiumSheet({required this.onSubscribe});
  final Future<void> Function() onSubscribe;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppTokens.rail,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Text(
          '✨ Pinte+',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppTokens.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '2,99 € / mois — sans engagement',
          style: TextStyle(
            fontSize: 15,
            color: AppTokens.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        const _PremiumFeature(emoji: '🌈', title: 'Cadre Shimmer', sub: 'Bordure arc-en-ciel animée'),
        const _PremiumFeature(emoji: '✨', title: 'Cadre Sparkle', sub: '12 particules dorées en orbite'),
        const _PremiumFeature(emoji: '📊', title: 'Stats avancées', sub: 'Évolution hebdo, classements complets'),
        const _PremiumFeature(emoji: '🏅', title: 'Badge Pinte+', sub: 'Affiché sur ton profil et dans le feed'),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.coral,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await onSubscribe();
            },
            child: const Text(
              'Activer Pinte+',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Pas maintenant',
            style: TextStyle(color: AppTokens.muted),
          ),
        ),
      ],
    ),
  );
}

// ── Stats avancées (premium only) ─────────────────────────────────────────────

class _AdvancedStats extends ConsumerWidget {
  const _AdvancedStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(premiumStatsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1A0D), Color(0xFF5A3410)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📊', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'Stats Pinte+',
                style: TextStyle(
                  color: Color(0xFFFFE3C2),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          stats.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: Color(0xFFFFCB6B), strokeWidth: 2),
              ),
            ),
            error: (_, _) => const _AdvStat(value: '—', label: 'Erreur'),
            data: (s) {
              if (s == null) return const SizedBox.shrink();
              final changeSign = s.weekChange >= 0 ? '+' : '';
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AdvStat(value: '#${s.globalRank}', label: 'Rang global'),
                  _AdvStat(
                    value: '$changeSign${s.weekChange}',
                    label: 'Cette semaine',
                  ),
                  _AdvStat(value: '${s.bestDay}', label: 'Record / jour'),
                  _AdvStat(value: '${s.likesReceived}', label: 'Likes reçus'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdvStat extends StatelessWidget {
  const _AdvStat({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFFFFCB6B),
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFFE3C2),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _PremiumFeature extends StatelessWidget {
  const _PremiumFeature({
    required this.emoji,
    required this.title,
    required this.sub,
  });
  final String emoji, title, sub;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTokens.ink,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 13, color: AppTokens.muted),
            ),
          ],
        ),
      ],
    ),
  );
}

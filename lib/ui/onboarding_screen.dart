import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'widgets/city_picker.dart';

/// Écran de connexion / inscription. Reprend la maquette du handoff
/// (`docs/Pinte App - Animation + Login.html`) : bandeau illustré en haut,
/// champs stylés, CTA corail. On conserve le champ « ville » (cœur du jeu
/// « guerre des villes ») en plus du pseudo de la maquette.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pseudo = TextEditingController();
  final _city = TextEditingController();
  bool _busy = false;
  bool _detectingCity = false;
  String? _pseudoError; // erreur sous le champ pseudo
  String? _formError; // erreur réseau / serveur (bannière)

  @override
  void initState() {
    super.initState();
    _pseudo.addListener(_onChanged);
    _city.addListener(_onChanged);
  }

  void _onChanged() => setState(() {
    // L'utilisateur corrige : on efface les messages d'erreur.
    _pseudoError = null;
    _formError = null;
  });

  bool get _canSubmit =>
      _pseudo.text.trim().isNotEmpty && _city.text.trim().isNotEmpty && !_busy;

  /// Valide le pseudo côté client (le backend ne le contraint pas).
  String? _validatePseudo(String raw) {
    final p = raw.trim();
    if (p.isEmpty) return 'Choisis un pseudo.';
    if (p.length < 3) return 'Au moins 3 caractères.';
    if (p.length > 20) return '20 caractères maximum.';
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(p)) {
      return 'Lettres, chiffres, « . » et « _ » uniquement.';
    }
    return null;
  }

  Future<void> _detectCity() async {
    setState(() => _detectingCity = true);
    try {
      final chosen = await detectAndPickCity(context);
      if (!mounted) return;
      if (chosen != null) {
        _city.text = chosen;
      } else {
        setState(() => _formError = 'Ville non détectée. Saisis-la manuellement.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Erreur de localisation. Saisis ta ville manuellement.');
      }
    } finally {
      if (mounted) setState(() => _detectingCity = false);
    }
  }

  @override
  void dispose() {
    _pseudo.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.cream,
      body: Column(
        children: [
          _illustrationBand(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 56,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  _fieldLabel('Ton pseudo'),
                  const SizedBox(height: 9),
                  _StyledField(
                    controller: _pseudo,
                    hint: 'ton_pseudo',
                    hasError: _pseudoError != null,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    prefix: const Text(
                      '@',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppTokens.tabInactive,
                      ),
                    ),
                  ),
                  if (_pseudoError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 7, left: 4),
                      child: Text(
                        _pseudoError!,
                        style: const TextStyle(
                          color: AppTokens.coral,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _fieldLabel('Ta ville'),
                  const SizedBox(height: 9),
                  _StyledField(
                    controller: _city,
                    hint: 'Paris, Lyon, Lille…',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    prefix: const Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Text('📍', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _detectingCity ? null : _detectCity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTokens.foam,
                        border:
                            Border.all(color: AppTokens.rail, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_detectingCity)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          else
                            const Text('📍',
                                style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            _detectingCity
                                ? 'Détection…'
                                : 'Détecter ma ville',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTokens.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 16),
                    _errorBanner(_formError!),
                  ],
                  const SizedBox(height: 18),
                  _ctaButton(),
                  const Spacer(),
                  const Text(
                    'Réservé aux +18 ans. L\'abus d\'alcool est dangereux pour '
                    'la santé, à consommer avec modération.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: AppTokens.tabInactive,
                    ),
                  ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _illustrationBand() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.4), // ≈ 50% 30 %
          radius: 1.1,
          colors: [Color(0xFFFFD9A0), Color(0xFFFFB36B), Color(0xFFFF8C4D)],
          stops: [0, 0.6, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF241308),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A1C0A).withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: const Text('🍺', style: TextStyle(fontSize: 38)),
              ),
              const SizedBox(height: 18),
              Text(
                'Lève ton verre\navec toute la France.',
                textAlign: TextAlign.center,
                style: displayStyle(size: 32).copyWith(
                  height: 1.02,
                  letterSpacing: -0.03 * 32,
                  color: const Color(0xFF2A1206),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Chaque pinte = +1 vers le million.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A4310),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.08 * 13,
      color: AppTokens.muted,
    ),
  );

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTokens.coral.withValues(alpha: 0.12),
        border: Border.all(color: AppTokens.coral.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB23A1A),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctaButton() {
    return Opacity(
      opacity: _canSubmit ? 1 : 0.55,
      child: Material(
        color: AppTokens.coral,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _canSubmit ? _submit : null,
          child: Container(
            padding: const EdgeInsets.all(17),
            alignment: Alignment.center,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    '🍺 C\'est parti',
                    style: displayStyle(size: 18).copyWith(color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    final pseudoError = _validatePseudo(_pseudo.text);
    final cityEmpty = _city.text.trim().isEmpty;
    setState(() {
      _pseudoError = pseudoError;
      _formError = cityEmpty ? 'Indique ta ville pour rejoindre.' : null;
    });
    if (pseudoError != null || cityEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .signUp(pseudo: _pseudo.text.trim(), city: _city.text.trim());
      // Succès : le RootGate bascule vers l'app et démonte cet écran.
    } on SignUpException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Une erreur est survenue. Réessaie.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Champ de saisie stylé selon la maquette : fond mousse, bordure rail,
/// rayon 16, avec un préfixe optionnel (@ ou 📍).
class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.hint,
    this.prefix,
    this.hasError = false,
    this.textInputAction,
    this.inputFormatters,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final Widget? prefix;
  final bool hasError;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.foam,
        border: Border.all(
          color: hasError ? AppTokens.coral : AppTokens.rail,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(left: 16, right: 6),
      child: Row(
        children: [
          if (prefix != null) ...[prefix!, const SizedBox(width: 8)],
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: textInputAction,
              inputFormatters: inputFormatters,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTokens.ink,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppTokens.tabInactive,
                  fontWeight: FontWeight.w700,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


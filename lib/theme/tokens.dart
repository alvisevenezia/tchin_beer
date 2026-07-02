import 'package:flutter/material.dart';

class AppTokens {
  // Couleurs (handoff)
  static const cream = Color(0xFFFFF4E0);
  static const foam = Color(0xFFFFFBF2);
  static const ink = Color(0xFF2A1A0D);
  static const amber = Color(0xFFF4A722);
  static const coral = Color(0xFFFF6A3D);
  static const sky = Color(0xFF1AA3D6);
  static const live = Color(0xFFFF3B30);
  static const muted = Color(0xFF6B5230);
  static const rail = Color(0xFFECDCBF);
  static const tabInactive = Color(0xFF8A6A42);

  // Rayons
  static const radiusCard = 18.0;
  static const radiusThumb = 20.0;
  static const radiusPill = 100.0;

  // Espacements
  static const screenPadH = 24.0;
  static const gapCard = 12.0;

  // Ombres
  static const cardShadow = BoxShadow(
    color: Color(0x1A2A1206),
    blurRadius: 44,
    offset: Offset(0, 18),
  );
  static const ctaShadow = BoxShadow(
    color: Color(0x56FF6A3D),
    blurRadius: 26,
    offset: Offset(0, 12),
  );
  static const fabShadow = BoxShadow(
    color: Color(0x66FF6A3D),
    blurRadius: 22,
    offset: Offset(0, 10),
  );

  // Dégradés
  static const progressGradient = LinearGradient(colors: [amber, coral]);

  static const avatarGradient = RadialGradient(
    center: Alignment(-0.2, -0.3),
    colors: [Color(0xFFFFC861), coral],
  );

  static const foundersGradient = LinearGradient(
    begin: Alignment(-0.5, -0.5),
    end: Alignment(0.8, 0.8),
    colors: [Color(0xFF2A1A0D), Color(0xFF5A3410)],
  );

  // Teintes de pinte → couleur d'accent
  static Color toneColor(String tone) => switch (tone) {
    'coral' => coral,
    'sky' => sky,
    _ => amber,
  };

  // Paires de couleurs pour les placeholders rayés (light, dark)
  static ({Color light, Color dark}) toneStripes(String tone) => switch (tone) {
    'coral' => (light: const Color(0xFFFCE7D4), dark: const Color(0xFFF6D9BF)),
    'sky'   => (light: const Color(0xFFE1F0F7), dark: const Color(0xFFCFE6F0)),
    _       => (light: const Color(0xFFF3E6CE), dark: const Color(0xFFE9D8BC)),
  };
}

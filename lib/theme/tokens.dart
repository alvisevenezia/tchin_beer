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
  static const muted = Color(0xFF9A865F);
  static const rail = Color(0xFFECDCBF);
  static const tabInactive = Color(0xFFB6A081);

  // Rayons
  static const radiusCard = 18.0;
  static const radiusThumb = 20.0;
  static const radiusPill = 100.0;

  // Espacements
  static const screenPadH = 24.0;
  static const gapCard = 12.0;

  // Teintes de pinte → couleur d'accent
  static Color toneColor(String tone) => switch (tone) {
    'coral' => coral,
    'sky' => sky,
    _ => amber,
  };
}

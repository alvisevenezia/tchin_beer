import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppTokens.cream,
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppTokens.coral,
      surface: AppTokens.foam,
    ),
    textTheme: GoogleFonts.hankenGroteskTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppTokens.ink, displayColor: AppTokens.ink),
  );
}

// Style des grands chiffres / titres (Bricolage Grotesque).
TextStyle displayStyle({
  double size = 30,
  FontWeight weight = FontWeight.w800,
}) => GoogleFonts.bricolageGrotesque(
  fontSize: size,
  fontWeight: weight,
  letterSpacing: -0.02,
  color: AppTokens.ink,
);

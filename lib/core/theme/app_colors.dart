import 'package:flutter/material.dart';

/// Apple Music–inspired palette: deep black, soft glass, accent pink/red.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF000000);
  static const Color bgElevated = Color(0xFF1C1C1E);
  static const Color bgCard = Color(0xFF2C2C2E);
  static const Color glass = Color(0x33FFFFFF);
  static const Color glassBorder = Color(0x1FFFFFFF);

  static const Color accent = Color(0xFFFA2D48);
  static const Color accentSoft = Color(0xFFFF6482);
  static const Color accentAlt = Color(0xFF5E5CE6);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x66FFFFFF);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFA2D48), Color(0xFFFF6482)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient meshTop = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A0A12), Color(0xFF000000), Color(0xFF0A0A14)],
  );

  // Legacy aliases
  static const Color neonCyan = accentAlt;
  static const Color neonPink = accent;
  static const Color neonPurple = accentAlt;
}

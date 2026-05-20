import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class DynamicPalette {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color glow;

  const DynamicPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.glow,
  });

  static const fallback = DynamicPalette(
    primary: Color(0xFFFA2D48),
    secondary: Color(0xFF5E5CE6),
    tertiary: Color(0xFF7B61FF),
    glow: Color(0x66FA2D48),
  );

  static Future<DynamicPalette> fromImageUrl(String url) async {
    if (url.isEmpty) return fallback;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        maximumColorCount: 16,
      );
      final vibrant = palette.vibrantColor?.color ?? palette.dominantColor?.color;
      final dark = palette.darkVibrantColor?.color ?? palette.darkMutedColor?.color;
      final muted = palette.mutedColor?.color ?? palette.lightMutedColor?.color;
      if (vibrant == null) return fallback;
      return DynamicPalette(
        primary: vibrant,
        secondary: dark ?? vibrant.withValues(alpha: 0.7),
        tertiary: muted ?? vibrant.withValues(alpha: 0.5),
        glow: vibrant.withValues(alpha: 0.45),
      );
    } catch (_) {
      return fallback;
    }
  }
}

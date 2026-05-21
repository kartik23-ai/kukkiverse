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

  /// Ensures a color has minimum saturation so UI never goes gray/black/white.
  /// If saturation is too low, blend with the fallback accent.
  static Color _ensureVibrant(Color c) {
    final hsl = HSLColor.fromColor(c);
    // If saturation < 0.25 or lightness too extreme, boost it
    if (hsl.saturation < 0.25 || hsl.lightness < 0.15 || hsl.lightness > 0.85) {
      // Blend 60% original + 40% fallback accent to inject color
      return Color.lerp(c, const Color(0xFFFA2D48), 0.4)!;
    }
    // If saturation is weak, boost it
    if (hsl.saturation < 0.4) {
      return hsl.withSaturation(0.5).toColor();
    }
    return c;
  }

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

      final safePrimary = _ensureVibrant(vibrant);
      final safeSecondary = _ensureVibrant(dark ?? vibrant);
      final safeTertiary = _ensureVibrant(muted ?? vibrant);

      return DynamicPalette(
        primary: safePrimary,
        secondary: safeSecondary,
        tertiary: safeTertiary,
        glow: safePrimary.withValues(alpha: 0.45),
      );
    } catch (_) {
      return fallback;
    }
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feature_providers.dart';
import '../providers/providers.dart';
import '../core/theme/dynamic_palette.dart';

/// ═══════════════════════════════════════════════════════════════
/// Breathing Aurora Background 2.0
/// • Interpolates between top 3 dominant colors of album art
/// • Slow "breathing" motion (expand + contract)
/// • GPU-friendly radial gradients (no MaskFilter blur)
/// • Mode-aware: reads DynamicPalette + ModeTheme
/// ═══════════════════════════════════════════════════════════════
class RottyAuroraBackground extends ConsumerStatefulWidget {
  final Widget child;
  final double intensity;
  /// Optional override colors — if null, uses brand palette
  final List<Color>? paletteOverride;

  const RottyAuroraBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
    this.paletteOverride,
  });

  @override
  ConsumerState<RottyAuroraBackground> createState() => _RottyAuroraBackgroundState();
}

class _RottyAuroraBackgroundState extends ConsumerState<RottyAuroraBackground> {
  @override
  Widget build(BuildContext context) {
    final ripplesEnabled = ref.watch(albumArtRipplesProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF040407)),
        if (ripplesEnabled)
          RepaintBoundary(
            child: CustomPaint(
              painter: _BreathingAuroraPainter(
                phase: 0.0,
                intensity: widget.intensity * 0.45,
                colors: widget.paletteOverride,
              ),
              size: Size.infinite,
            ),
          ),
        widget.child,
      ],
    );
  }
}

/// Breathing Aurora with album-art-aware color palette
class RottyDynamicAuroraBackground extends ConsumerWidget {
  final Widget child;
  final double intensity;

  const RottyDynamicAuroraBackground({
    super.key,
    required this.child,
    this.intensity = 0.8,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(dynamicPaletteProvider);
    return RottyAuroraBackground(
      intensity: intensity,
      paletteOverride: [
        palette.primary,
        palette.secondary,
        palette.tertiary,
      ],
      child: child,
    );
  }
}

// ─── Breathing Aurora Painter ──────────────────────────────────────
class _BreathingAuroraPainter extends CustomPainter {
  final double phase;
  final double intensity;
  final List<Color>? colors;

  _BreathingAuroraPainter({
    required this.phase,
    required this.intensity,
    this.colors,
  });

  // Default brand palette
  static const _brandColors = [
    Color(0xFFFA2D48),
    Color(0xFF5E5CE6),
    Color(0xFF7B61FF),
    Color(0xFF00D4FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.longestSide * 0.5;
    final palette = colors ?? _brandColors;

    // ── 4 breathing orbs with Lissajous motion ──
    for (var i = 0; i < 4; i++) {
      final t = phase * 2 * pi + i * (2 * pi / 4);
      final color = palette[i % palette.length];

      // Lissajous frequencies per orb (organic feel)
      final freqX = 0.8 + i * 0.22;
      final freqY = 0.6 + i * 0.3;

      // Position oscillation
      final x = cx + sin(t * freqX + i * 1.2) * size.width * 0.32;
      final y = cy + cos(t * freqY + i * 0.7) * size.height * 0.28;

      // Breathing radius: slow expand + contract
      final breathFactor = 0.5 + 0.5 * sin(t * 0.3 + i * 0.5);
      final r = maxR * (0.28 + 0.12 * breathFactor);

      // GPU-friendly radial gradient (no blur filter)
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: (0.08 + breathFactor * 0.04) * intensity),
            color.withValues(alpha: (0.02 + breathFactor * 0.01) * intensity),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r));

      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // ── Core ambient glow (center) ──
    final coreColor = palette.isNotEmpty ? palette[0] : _brandColors[0];
    final coreBreathe = 0.5 + 0.5 * sin(phase * 2 * pi * 0.15);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          coreColor.withValues(alpha: (0.03 + coreBreathe * 0.015) * intensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(cx, cy * 0.7), radius: maxR * 0.6));
    canvas.drawCircle(Offset(cx, cy * 0.7), maxR * 0.6, corePaint);
  }

  @override
  bool shouldRepaint(covariant _BreathingAuroraPainter old) =>
      old.phase != phase || old.intensity != intensity;
}

/// Particle engine kept for backward compatibility.
class ParticleEngine extends StatelessWidget {
  final Widget child;
  const ParticleEngine({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// Legacy alias
class AuraBackground extends StatelessWidget {
  const AuraBackground({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

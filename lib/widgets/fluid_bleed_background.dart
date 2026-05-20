import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// Fluid Audio-Bleed Background — Album art colors melt and
/// ripple on bass hits. Makes the player a living canvas.
/// ═══════════════════════════════════════════════════════════════
class FluidBleedBackground extends StatefulWidget {
  const FluidBleedBackground({
    super.key,
    required this.colors,
    this.bassIntensity = 0.0,
    required this.child,
  });

  /// Dominant colors from album palette (2–4 colors)
  final List<Color> colors;
  /// 0.0 = silence, 1.0 = max bass → max ripple
  final double bassIntensity;
  final Widget child;

  @override
  State<FluidBleedBackground> createState() => _FluidBleedBackgroundState();
}

class _FluidBleedBackgroundState extends State<FluidBleedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors.isEmpty
        ? [const Color(0xFF1A1A2E), const Color(0xFF0D0D2B)]
        : widget.colors;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return CustomPaint(
            painter: _FluidBleedPainter(
              colors: colors,
              phase: _ctrl.value,
              bassIntensity: widget.bassIntensity,
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _FluidBleedPainter extends CustomPainter {
  final List<Color> colors;
  final double phase;
  final double bassIntensity;

  _FluidBleedPainter({
    required this.colors,
    required this.phase,
    required this.bassIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Base dark gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050508), Color(0xFF0A0A14)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Fluid bleed blobs — multiple overlapping organic shapes
    for (var i = 0; i < colors.length && i < 4; i++) {
      _drawFluidBlob(canvas, size, i, colors[i]);
    }

    // Bass ripple rings
    if (bassIntensity > 0.1) {
      _drawBassRipple(canvas, size);
    }
  }

  void _drawFluidBlob(Canvas canvas, Size size, int index, Color color) {
    final t = phase * math.pi * 2;
    final cx = size.width * (0.3 + index * 0.2 + math.sin(t + index * 1.5) * 0.1);
    final cy = size.height * (0.25 + index * 0.12 + math.cos(t + index * 2.0) * 0.05);

    // Blob radius pulsates with bass
    final baseRadius = size.width * (0.35 + index * 0.05);
    final bassBoost = bassIntensity * size.width * 0.15;
    final radius = baseRadius + bassBoost + math.sin(t * 1.5 + index) * 12;

    // Create organic blob shape using multiple bezier arcs
    final path = Path();
    const segments = 8;
    for (var s = 0; s <= segments; s++) {
      final angle = (s / segments) * math.pi * 2;
      final wobble = math.sin(angle * 3 + t + index * 0.7) * (12 + bassIntensity * 20);
      final r = radius + wobble;
      final x = cx + math.cos(angle) * r;
      final y = cy + math.sin(angle) * r * 0.7; // Flatten vertically for "melt" feel
      if (s == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth curve
        final prevAngle = ((s - 1) / segments) * math.pi * 2;
        final prevWobble = math.sin(prevAngle * 3 + t + index * 0.7) * (12 + bassIntensity * 20);
        final prevR = radius + prevWobble;
        final cpx = cx + math.cos((prevAngle + angle) / 2) * (prevR + r) / 2 * 1.1;
        final cpy = cy + math.sin((prevAngle + angle) / 2) * (prevR + r) / 2 * 0.7 * 1.1;
        path.quadraticBezierTo(cpx, cpy, x, y);
      }
    }
    path.close();

    // Gradient fill — fades from color to transparent
    final alpha = (0.06 + index * 0.02 + bassIntensity * 0.06).clamp(0.0, 0.2);
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (cx / size.width) * 2 - 1,
          (cy / size.height) * 2 - 1,
        ),
        radius: 0.8,
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);

    // Downward "drip" extension — liquid melting feel
    final dripPath = Path();
    final dripX = cx;
    final dripTop = cy + radius * 0.5;
    final dripBottom = math.min(size.height, dripTop + size.height * 0.35 + bassIntensity * 50);
    final dripWidth = radius * 0.2 + math.sin(t * 2 + index) * 8;

    dripPath.moveTo(dripX - dripWidth, dripTop);
    dripPath.quadraticBezierTo(
      dripX, dripBottom + math.sin(t * 3) * 15,
      dripX + dripWidth, dripTop,
    );
    dripPath.close();

    final dripPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: alpha * 0.5),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, dripTop, size.width, dripBottom - dripTop));
    canvas.drawPath(dripPath, dripPaint);
  }

  void _drawBassRipple(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.35;
    final maxRadius = size.width * 0.6;

    for (var i = 0; i < 3; i++) {
      final ripplePhase = (phase + i * 0.33) % 1.0;
      final r = maxRadius * ripplePhase;
      final alpha = (bassIntensity * 0.12 * (1.0 - ripplePhase)).clamp(0.0, 0.15);
      if (alpha < 0.01) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + bassIntensity * 2
        ..color = colors.first.withValues(alpha: alpha);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 1.2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FluidBleedPainter old) => true;
}

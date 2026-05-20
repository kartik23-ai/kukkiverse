import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// Neon Soundwave Skeleton — Proprietary Loading UI
/// Replaces generic shimmer with futuristic frequency-scan effect
/// • Holographic neon layout with 0.5px glass borders
/// • Horizontal laser beams tracing left-to-right
/// • Ghost waveform lines oscillating like frequency scan
/// ═══════════════════════════════════════════════════════════════
class NeonSoundwaveSkeleton extends StatefulWidget {
  const NeonSoundwaveSkeleton({super.key, this.height = 220});
  final double height;

  @override
  State<NeonSoundwaveSkeleton> createState() => _NeonSoundwaveSkeletonState();
}

class _NeonSoundwaveSkeletonState extends State<NeonSoundwaveSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return CustomPaint(
            painter: _NeonSkeletonPainter(_ctrl.value),
            size: Size(double.infinity, widget.height),
          );
        },
      ),
    );
  }
}

class _NeonSkeletonPainter extends CustomPainter {
  final double t;
  _NeonSkeletonPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rng = math.Random(42);

    // ─── Obsidian backplane ───
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF060818),
          const Color(0xFF0A0F28),
          const Color(0xFF050712),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(16)),
      bgPaint,
    );

    // ─── 0.5px glass border ───
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x20FFFFFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(16)),
      borderPaint,
    );

    // ─── Skeleton album art box (left side) ───
    final artRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(16, 16, h - 32, h - 32),
      const Radius.circular(12),
    );
    final artBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x15FFFFFF);
    canvas.drawRRect(artRect, artBorderPaint);

    // ─── Skeleton text lines (right side) ───
    final textX = h + 8;
    final textW = w - textX - 16;
    for (var i = 0; i < 3; i++) {
      final lineW = textW * (1.0 - i * 0.2);
      final lineY = 24.0 + i * 22.0;
      final lineRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(textX, lineY, lineW, 10),
        const Radius.circular(5),
      );
      canvas.drawRRect(lineRect, artBorderPaint);
    }

    // ─── Skeleton progress bar ───
    final barY = h - 28.0;
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(textX, barY, textW, 4),
      const Radius.circular(2),
    );
    canvas.drawRRect(barRect, artBorderPaint);

    // ─── Laser beam sweep (left→right) ───
    final laserX = (t * (w + 60)) - 30;
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF06B6D4).withValues(alpha: 0.6),
          const Color(0xFF818CF8).withValues(alpha: 0.8),
          const Color(0xFF06B6D4).withValues(alpha: 0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(laserX - 30, 0, 60, h));
    canvas.drawRect(Rect.fromLTWH(laserX - 1, 0, 2, h), laserPaint);

    // ─── Ghost waveform oscillation ───
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final waveY = h * 0.55;
    final path = Path();
    for (var x = 0.0; x < w; x += 2) {
      final phase = t * math.pi * 4 + x * 0.04;
      final amp = 8.0 + rng.nextDouble() * 6;
      final y = waveY + math.sin(phase) * amp * math.sin(x / w * math.pi);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Cyan wave
    wavePaint.color = const Color(0xFF06B6D4).withValues(alpha: 0.2);
    canvas.drawPath(path, wavePaint);

    // Indigo wave (offset)
    final path2 = Path();
    for (var x = 0.0; x < w; x += 2) {
      final phase = t * math.pi * 3.2 + x * 0.035 + 1.5;
      final amp = 6.0 + rng.nextDouble() * 5;
      final y = waveY + 12 + math.sin(phase) * amp * math.sin(x / w * math.pi);
      if (x == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }
    wavePaint.color = const Color(0xFF818CF8).withValues(alpha: 0.15);
    canvas.drawPath(path2, wavePaint);

    // ─── Neon pulse dots on skeleton ───
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 5; i++) {
      final dx = textX + (i * textW / 5) + t * 20;
      if (dx > w - 16) continue;
      final pulse = (math.sin(t * math.pi * 2 + i * 1.2) + 1) / 2;
      dotPaint.color = const Color(0xFF06B6D4).withValues(alpha: 0.15 + pulse * 0.2);
      canvas.drawCircle(Offset(dx, barY + 2), 2 + pulse, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonSkeletonPainter old) => old.t != t;
}

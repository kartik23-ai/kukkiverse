import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Perspective wireframe floor + starfield — Unreal/engine boot vibe.
class SplashEnginePainter extends CustomPainter {
  SplashEnginePainter({
    required this.phase,
    required this.time,
    required this.glitch,
  });

  final double phase;
  final double time;
  final double glitch;

  @override
  void paint(Canvas canvas, Size size) {
    _drawStarfield(canvas, size);
    _drawGrid(canvas, size);
    _drawHorizonGlow(canvas, size);
    _drawScanlines(canvas, size);
  }

  void _drawStarfield(Canvas canvas, Size size) {
    final rng = Random(42);
    for (var i = 0; i < 120; i++) {
      final bx = rng.nextDouble() * size.width;
      final by = rng.nextDouble() * size.height * 0.65;
      final speed = 0.3 + rng.nextDouble() * 1.2;
      final y = (by + time * speed * 80) % (size.height * 0.7);
      final twinkle = 0.4 + 0.6 * sin(time * 4 + i);
      final paint = Paint()
        ..color = Color.lerp(AppColors.neonCyan, Colors.white, rng.nextDouble())!
            .withValues(alpha: (0.15 + twinkle * 0.5) * phase);
      canvas.drawCircle(Offset(bx, y), 0.5 + rng.nextDouble() * 1.5, paint);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final horizon = size.height * 0.42;
    final vanish = Offset(size.width / 2, horizon);
    final lines = 24;
    final depth = phase.clamp(0.0, 1.0);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Horizontal lines — move toward viewer
    for (var i = 0; i < lines; i++) {
      final t = (i / lines + time * 0.35) % 1.0;
      final spread = pow(t, 1.8).toDouble() * size.height * 0.55;
      final y = horizon + spread;
      if (y > size.height + 20) continue;

      final alpha = (1 - t) * 0.55 * depth;
      final color = Color.lerp(AppColors.neonCyan, AppColors.neonPink, t)!;
      gridPaint.color = color.withValues(alpha: alpha.clamp(0.0, 0.7));

      final halfW = size.width * 0.5 * (0.15 + t * 1.1);
      canvas.drawLine(Offset(vanish.dx - halfW, y), Offset(vanish.dx + halfW, y), gridPaint);
    }

    // Vertical radiating lines
    for (var i = -14; i <= 14; i++) {
      final angle = i / 14 * 0.85;
      final endX = vanish.dx + sin(angle) * size.width * 1.2;
      final endY = size.height + 40;
      gridPaint.color = AppColors.neonCyan.withValues(alpha: 0.12 * depth);
      canvas.drawLine(vanish, Offset(endX, endY), gridPaint);
    }
  }

  void _drawHorizonGlow(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.neonPink.withValues(alpha: 0.35 * phase),
          AppColors.neonCyan.withValues(alpha: 0.15 * phase),
          Colors.transparent,
        ],
        stops: const [0, 0.4, 1],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.6));
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawScanlines(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.06 + glitch * 0.04);
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), paint);
    }
    // Moving scan beam
    final beamY = (time * 120) % size.height;
    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppColors.neonCyan.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, beamY - 40, size.width, 80));
    canvas.drawRect(Rect.fromLTWH(0, beamY - 40, size.width, 80), beam);
  }

  @override
  bool shouldRepaint(covariant SplashEnginePainter old) =>
      old.phase != phase || old.time != time || old.glitch != glitch;
}

/// Rotating HUD rings around the logo core.
class SplashHudRingsPainter extends CustomPainter {
  SplashHudRingsPainter({required this.rotation, required this.pulse});

  final double rotation;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width * 0.38;

    for (var ring = 0; ring < 3; ring++) {
      final r = baseR + ring * 18 + pulse * 8;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring == 0 ? 2.5 : 1.2
        ..color = (ring.isEven ? AppColors.neonCyan : AppColors.neonPink)
            .withValues(alpha: 0.35 - ring * 0.08);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation * (ring.isEven ? 1 : -1.3) + ring * 0.4);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        ring * 0.8,
        pi * 1.2,
        false,
        paint,
      );
      // Tick marks
      for (var t = 0; t < 8; t++) {
        final a = t * pi / 4;
        final p1 = Offset(cos(a) * r, sin(a) * r);
        final p2 = Offset(cos(a) * (r + 6), sin(a) * (r + 6));
        canvas.drawLine(p1, p2, paint..strokeWidth = 2);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SplashHudRingsPainter old) =>
      old.rotation != rotation || old.pulse != pulse;
}

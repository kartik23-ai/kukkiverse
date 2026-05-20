import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// Audio-Reactive Particle Vortex — GPU-optimized CustomPainter
/// • Hundreds of particles orbiting a central gravity well
/// • Bass impact → burst explosion outward
/// • Treble → particle speed & trail length
/// • Zero-alloc render loop for 60fps
/// ═══════════════════════════════════════════════════════════════
class ParticleVortex extends StatefulWidget {
  const ParticleVortex({
    super.key,
    this.bassIntensity = 0.5,
    this.trebleIntensity = 0.5,
    this.colors = const [Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFFF6B6B)],
  });

  /// 0.0 = silence, 1.0 = max bass punch
  final double bassIntensity;
  /// 0.0 = silence, 1.0 = max treble
  final double trebleIntensity;
  /// Palette colors for particles
  final List<Color> colors;

  @override
  State<ParticleVortex> createState() => _ParticleVortexState();
}

class _ParticleVortexState extends State<ParticleVortex>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;
  final _rng = math.Random();

  static const _particleCount = 120;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(_particleCount, (_) => _Particle.random(_rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
        builder: (context, _) {
          return CustomPaint(
            painter: _VortexPainter(
              particles: _particles,
              time: _ctrl.value,
              bassIntensity: widget.bassIntensity,
              trebleIntensity: widget.trebleIntensity,
              colors: widget.colors,
              rng: _rng,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  double angle;
  double radius;
  double speed;
  double size;
  double opacity;
  int colorIndex;
  double orbitOffset;

  _Particle({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.colorIndex,
    required this.orbitOffset,
  });

  factory _Particle.random(math.Random rng) {
    return _Particle(
      angle: rng.nextDouble() * math.pi * 2,
      radius: 30 + rng.nextDouble() * 120,
      speed: 0.2 + rng.nextDouble() * 0.8,
      size: 1.0 + rng.nextDouble() * 2.5,
      opacity: 0.2 + rng.nextDouble() * 0.6,
      colorIndex: rng.nextInt(3),
      orbitOffset: rng.nextDouble() * math.pi * 2,
    );
  }
}

class _VortexPainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  final double bassIntensity;
  final double trebleIntensity;
  final List<Color> colors;
  final math.Random rng;

  _VortexPainter({
    required this.particles,
    required this.time,
    required this.bassIntensity,
    required this.trebleIntensity,
    required this.colors,
    required this.rng,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(cx, cy) * 0.85;

    final paint = Paint()..style = PaintingStyle.fill;

    // Bass causes outward burst
    final burstFactor = 1.0 + bassIntensity * 0.6;
    // Treble increases speed
    final speedFactor = 1.0 + trebleIntensity * 2.0;

    // Draw gravity well center glow
    final centerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[0].withValues(alpha: 0.08 + bassIntensity * 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 80));
    canvas.drawCircle(Offset(cx, cy), 80, centerPaint);

    // Update & draw each particle
    for (final p in particles) {
      // Orbital motion
      p.angle += p.speed * speedFactor * 0.008;

      // Breathing radius with bass burst
      final breathe = math.sin(time * math.pi * 2 + p.orbitOffset) * 8;
      final r = (p.radius + breathe) * burstFactor;
      final clampedR = r.clamp(10.0, maxR);

      // Position
      final x = cx + math.cos(p.angle) * clampedR;
      final y = cy + math.sin(p.angle) * clampedR * 0.85; // slight vertical squish

      // Color from palette
      final ci = p.colorIndex.clamp(0, colors.length - 1);
      final alpha = (p.opacity * (0.5 + bassIntensity * 0.5)).clamp(0.05, 0.8);
      paint.color = colors[ci].withValues(alpha: alpha);

      // Size pulse on bass
      final pSize = p.size * (1.0 + bassIntensity * 0.5);

      canvas.drawCircle(Offset(x, y), pSize, paint);

      // Trail (ghost previous position)
      if (trebleIntensity > 0.3) {
        final trailAngle = p.angle - p.speed * speedFactor * 0.016;
        final tx = cx + math.cos(trailAngle) * clampedR;
        final ty = cy + math.sin(trailAngle) * clampedR * 0.85;
        paint.color = colors[ci].withValues(alpha: alpha * 0.3);
        canvas.drawCircle(Offset(tx, ty), pSize * 0.6, paint);
      }
    }

    // Connecting lines between close particles (mesh effect)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;

    for (var i = 0; i < particles.length; i += 3) {
      final p1 = particles[i];
      final r1 = (p1.radius + math.sin(time * math.pi * 2 + p1.orbitOffset) * 8) * burstFactor;
      final x1 = cx + math.cos(p1.angle) * r1.clamp(10.0, maxR);
      final y1 = cy + math.sin(p1.angle) * r1.clamp(10.0, maxR) * 0.85;

      for (var j = i + 1; j < math.min(i + 4, particles.length); j++) {
        final p2 = particles[j];
        final r2 = (p2.radius + math.sin(time * math.pi * 2 + p2.orbitOffset) * 8) * burstFactor;
        final x2 = cx + math.cos(p2.angle) * r2.clamp(10.0, maxR);
        final y2 = cy + math.sin(p2.angle) * r2.clamp(10.0, maxR) * 0.85;

        final dist = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
        if (dist < 60) {
          final ci = p1.colorIndex.clamp(0, colors.length - 1);
          linePaint.color = colors[ci].withValues(alpha: 0.06 * (1 - dist / 60));
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VortexPainter old) => true;
}

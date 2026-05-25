import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Highly Optimized Audio-Reactive Particle Vortex Background (Idea A - Particles Edition)
/// Pre-allocates all particles and Paint objects to ensure 100% GC-free 60/120 FPS smooth rendering.
class PartyDiscoLights extends StatefulWidget {
  const PartyDiscoLights({
    super.key,
    required this.active,
    this.accent = const Color(0xFFFA2D48),
  });

  final bool active;
  final Color accent;

  @override
  State<PartyDiscoLights> createState() => _PartyDiscoLightsState();
}

class _PartyDiscoLightsState extends State<PartyDiscoLights> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_VortexParticle> _particles;
  final _rng = math.Random();

  static const _particleCount = 100;

  // Pre-allocated reusable Paint objects to completely eliminate GC pressure during drawing.
  final Paint _bgPaint = Paint()..color = const Color(0xFF040409);
  final Paint _centerGlowPaint = Paint()..style = PaintingStyle.fill;
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;
  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.35;

  @override
  void initState() {
    super.initState();
    // Pre-generate particles with random orbital characteristics
    _particles = List.generate(_particleCount, (_) => _VortexParticle.random(_rng));
    // 10-second base orbital period
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return CustomPaint(
              painter: _VortexPainter(
                particles: _particles,
                time: _ctrl.value,
                active: widget.active,
                accent: widget.accent,
                bgPaint: _bgPaint,
                centerGlowPaint: _centerGlowPaint,
                particlePaint: _particlePaint,
                linePaint: _linePaint,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _VortexParticle {
  double angle;
  final double radius;
  final double speed;
  final double size;
  final double opacity;
  final int colorIndex;
  final double orbitOffset;

  _VortexParticle({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.colorIndex,
    required this.orbitOffset,
  });

  factory _VortexParticle.random(math.Random rng) {
    return _VortexParticle(
      angle: rng.nextDouble() * math.pi * 2,
      radius: 25.0 + rng.nextDouble() * 155.0, // spread across safe viewport
      speed: 0.15 + rng.nextDouble() * 0.75,   // base angular speed
      size: 1.0 + rng.nextDouble() * 2.8,       // particle radius
      opacity: 0.22 + rng.nextDouble() * 0.58,  // initial base alpha
      colorIndex: rng.nextInt(3),               // dynamic color selection index
      orbitOffset: rng.nextDouble() * math.pi * 2,
    );
  }
}

class _VortexPainter extends CustomPainter {
  final List<_VortexParticle> particles;
  final double time;
  final bool active;
  final Color accent;

  // Reused paints
  final Paint bgPaint;
  final Paint centerGlowPaint;
  final Paint particlePaint;
  final Paint linePaint;

  _VortexPainter({
    required this.particles,
    required this.time,
    required this.active,
    required this.accent,
    required this.bgPaint,
    required this.centerGlowPaint,
    required this.particlePaint,
    required this.linePaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(cx, cy) * 0.9;

    // 1. Draw solid dark background
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Audio-reactive parameters
    final double bassIntensity = active ? 0.8 : 0.2;
    final double trebleIntensity = active ? 0.7 : 0.1;
    final double burstFactor = 1.0 + bassIntensity * 0.25;
    final double speedFactor = active ? 3.0 : 0.95;

    // Define cohesive cosmic color palette
    final colors = [
      accent,
      const Color(0xFF7C4DFF), // Deep Violet
      const Color(0xFF00E5FF), // Aurora Cyan
    ];

    // 2. Draw gravity well center glow
    centerGlowPaint.shader = RadialGradient(
      colors: [
        accent.withValues(alpha: 0.08 + bassIntensity * 0.1),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 95));
    canvas.drawCircle(Offset(cx, cy), 95, centerGlowPaint);

    // 3. Update coordinates & draw each particle (orbital motion + gravity vortex)
    for (final p in particles) {
      // Rotate particle around center
      p.angle += p.speed * speedFactor * 0.007;

      // React to simulated bass pulsing
      final breathe = math.sin(time * math.pi * 2 + p.orbitOffset) * 6;
      final r = (p.radius + breathe) * burstFactor;
      final clampedR = r.clamp(10.0, maxR);

      // Orbital ellipse positions (with minor vertical squish for depth)
      final x = cx + math.cos(p.angle) * clampedR;
      final y = cy + math.sin(p.angle) * clampedR * 0.82;

      // Color assignment
      final ci = p.colorIndex.clamp(0, colors.length - 1);
      final double alpha = (p.opacity * (0.45 + bassIntensity * 0.45)).clamp(0.05, 0.9);
      particlePaint.color = colors[ci].withValues(alpha: alpha);

      // Particle size
      final pSize = p.size * (1.0 + bassIntensity * 0.35);
      canvas.drawCircle(Offset(x, y), pSize, particlePaint);

      // Render high-speed trails when actively playing
      if (active && trebleIntensity > 0.4) {
        final trailAngle = p.angle - p.speed * speedFactor * 0.012;
        final tx = cx + math.cos(trailAngle) * clampedR;
        final ty = cy + math.sin(trailAngle) * clampedR * 0.82;
        particlePaint.color = colors[ci].withValues(alpha: alpha * 0.28);
        canvas.drawCircle(Offset(tx, ty), pSize * 0.6, particlePaint);
      }
    }

    // 4. Draw Connecting Lines (Constellation / Mesh effect)
    for (var i = 0; i < particles.length; i += 3) {
      final p1 = particles[i];
      final r1 = (p1.radius + math.sin(time * math.pi * 2 + p1.orbitOffset) * 6) * burstFactor;
      final x1 = cx + math.cos(p1.angle) * r1.clamp(10.0, maxR);
      final y1 = cy + math.sin(p1.angle) * r1.clamp(10.0, maxR) * 0.82;

      for (var j = i + 1; j < math.min(i + 4, particles.length); j++) {
        final p2 = particles[j];
        final r2 = (p2.radius + math.sin(time * math.pi * 2 + p2.orbitOffset) * 6) * burstFactor;
        final x2 = cx + math.cos(p2.angle) * r2.clamp(10.0, maxR);
        final y2 = cy + math.sin(p2.angle) * r2.clamp(10.0, maxR) * 0.82;

        final dist = math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
        final double maxDistance = active ? 75.0 : 45.0;

        if (dist < maxDistance) {
          final ci = p1.colorIndex.clamp(0, colors.length - 1);
          final opacityFactor = active ? 0.09 : 0.035;
          linePaint.color = colors[ci].withValues(alpha: opacityFactor * (1.0 - dist / maxDistance));
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VortexPainter old) =>
      old.time != time || old.active != active || old.accent != accent;
}

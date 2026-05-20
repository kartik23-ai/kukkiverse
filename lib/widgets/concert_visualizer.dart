import 'dart:math';
import 'package:flutter/material.dart';

/// Reactive concert visual — intensity follows pseudo beat from playback position.
class ConcertVisualizer extends StatefulWidget {
  const ConcertVisualizer({
    super.key,
    required this.playing,
    required this.accent,
    this.headphonesMode = false,
    this.intensity = 0.7,
  });

  final bool playing;
  final Color accent;
  final bool headphonesMode;
  final double intensity;

  @override
  State<ConcertVisualizer> createState() => _ConcertVisualizerState();
}

class _ConcertVisualizerState extends State<ConcertVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final _particles = <_Particle>[];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    for (var i = 0; i < 55; i++) {
      _particles.add(_Particle.random(_rng));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boost = widget.intensity.clamp(0.15, 1.0);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        if (widget.playing) {
          for (final p in _particles) {
            p.tick((widget.headphonesMode ? 0.75 : 1.15) * boost);
          }
        }
        return CustomPaint(
          painter: _ConcertPainter(
            particles: _particles,
            accent: widget.accent,
            phase: _ctrl.value,
            headphones: widget.headphonesMode,
            intensity: boost,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  double x, y, vy, size, alpha;
  _Particle(this.x, this.y, this.vy, this.size, this.alpha);

  factory _Particle.random(Random r) => _Particle(
        r.nextDouble(),
        r.nextDouble(),
        0.003 + r.nextDouble() * 0.006,
        2 + r.nextDouble() * 5,
        0.35 + r.nextDouble() * 0.55,
      );

  void tick(double speed) {
    y -= vy * speed;
    if (y < 0) {
      y = 1;
      x = Random().nextDouble();
    }
  }
}

class _ConcertPainter extends CustomPainter {
  _ConcertPainter({
    required this.particles,
    required this.accent,
    required this.phase,
    required this.headphones,
    required this.intensity,
  });

  final List<_Particle> particles;
  final Color accent;
  final double phase;
  final bool headphones;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 5; i++) {
      final angle = (phase + i * 0.2) * pi * 2;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: (headphones ? 0.12 : 0.22) * intensity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..blendMode = BlendMode.plus;

      canvas.save();
      canvas.translate(size.width / 2, size.height * 0.28);
      canvas.rotate(angle * 0.22);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 90 + intensity * 40, height: size.height), paint);
      canvas.restore();
    }

    for (final p in particles) {
      final paint = Paint()..color = accent.withValues(alpha: p.alpha * 0.85 * intensity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * (0.8 + intensity * 0.6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConcertPainter old) =>
      old.phase != phase || old.intensity != intensity || old.headphones != headphones;
}

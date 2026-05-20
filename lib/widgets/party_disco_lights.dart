import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Party mode disco beams — stronger than concert visualizer.
class PartyDiscoLights extends StatefulWidget {
  const PartyDiscoLights({super.key, required this.active, this.accent = const Color(0xFFFA2D48)});

  final bool active;
  final Color accent;

  @override
  State<PartyDiscoLights> createState() => _PartyDiscoLightsState();
}

class _PartyDiscoLightsState extends State<PartyDiscoLights> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return CustomPaint(
            painter: _DiscoPainter(
              phase: _ctrl.value,
              active: widget.active,
              accent: widget.accent,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _DiscoPainter extends CustomPainter {
  _DiscoPainter({required this.phase, required this.active, required this.accent});

  final double phase;
  final bool active;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final strength = active ? 1.0 : 0.35;
    final colors = [
      accent,
      const Color(0xFF7C4DFF),
      const Color(0xFF00E5FF),
      const Color(0xFFFFD600),
      const Color(0xFF69F0AE),
    ];

    for (var i = 0; i < 8; i++) {
      final t = phase + i * 0.125;
      final angle = t * math.pi * 2;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i % colors.length].withValues(alpha: (0.22 * strength).clamp(0.06, 0.35)),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(
            size.width * (0.5 + math.cos(angle) * 0.35),
            size.height * (0.35 + math.sin(angle * 1.3) * 0.25),
          ),
          radius: size.width * (0.35 + math.sin(t * 6) * 0.08),
        ))
        ..blendMode = BlendMode.plus;

      canvas.drawCircle(
        Offset(size.width * (0.5 + math.cos(angle) * 0.35), size.height * (0.35 + math.sin(angle * 1.3) * 0.25)),
        size.width * 0.4,
        paint,
      );
    }

    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: angle,
        endAngle: angle + math.pi * 2,
        colors: [
          accent.withValues(alpha: 0.18 * strength),
          Colors.transparent,
          const Color(0xFF7C4DFF).withValues(alpha: 0.14 * strength),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..blendMode = BlendMode.screen;

    canvas.drawRect(Offset.zero & size, sweep);
  }

  double get angle => phase * math.pi * 2;

  @override
  bool shouldRepaint(covariant _DiscoPainter old) => old.phase != phase || old.active != active;
}

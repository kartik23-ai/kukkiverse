import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// 3D Wireframe Mesh Visualizer for EQ Settings
/// • Bass Boost ON → bottom spikes violently jump
/// • Vocal Forward ON → center blindingly glows
/// • Width → mesh expands laterally
/// • Treble → top edge spikes sharpen
/// ═══════════════════════════════════════════════════════════════
class EqMeshVisualizer extends StatefulWidget {
  const EqMeshVisualizer({
    super.key,
    this.bass = 0.5,
    this.treble = 0.5,
    this.vocal = 0.5,
    this.width = 0.5,
    this.is8d = false,
    this.height = 200,
    this.isPlaying = true,
  });

  final double bass;
  final double treble;
  final double vocal;
  final double width;
  final bool is8d;
  final double height;
  final bool isPlaying;

  @override
  State<EqMeshVisualizer> createState() => _EqMeshVisualizerState();
}

class _EqMeshVisualizerState extends State<EqMeshVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant EqMeshVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
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
            painter: _MeshPainter(
              bass: widget.bass,
              treble: widget.treble,
              vocal: widget.vocal,
              width: widget.width,
              is8d: widget.is8d,
              time: _ctrl.value,
            ),
            size: Size(double.infinity, widget.height),
          );
        },
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double bass;
  final double treble;
  final double vocal;
  final double width;
  final bool is8d;
  final double time;

  static const _cols = 16;
  static const _rows = 10;

  _MeshPainter({
    required this.bass,
    required this.treble,
    required this.vocal,
    required this.width,
    required this.is8d,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = time * math.pi * 2;
    final cellW = size.width / (_cols - 1);
    final cellH = size.height / (_rows - 1);

    // Generate grid heights
    final heights = List.generate(_rows, (r) {
      return List.generate(_cols, (c) {
        final nx = c / (_cols - 1);       // 0..1
        final ny = r / (_rows - 1);       // 0..1
        final centerDist = math.sqrt(math.pow(nx - 0.5, 2) + math.pow(ny - 0.5, 2));

        double h = 0;

        // Bass → bottom spikes (ny > 0.6)
        if (ny > 0.5) {
          final bottomFactor = (ny - 0.5) * 2; // 0..1
          h += bass * 30 * bottomFactor * math.sin(t * 3 + c * 0.8);
          if (bass > 0.7) {
            h += (bass - 0.7) * 60 * math.sin(t * 6 + c * 1.2); // Violent jump
          }
        }

        // Treble → top edge sharpness (ny < 0.3)
        if (ny < 0.3) {
          final topFactor = (0.3 - ny) / 0.3;
          h += treble * 15 * topFactor * math.sin(t * 4 + c * 1.5);
        }

        // Vocal → center glow (dome)
        if (centerDist < 0.4) {
          final vocalFactor = 1.0 - (centerDist / 0.4);
          h += vocal * 20 * vocalFactor;
        }

        // Width → lateral stretch wave
        h += width * 8 * math.sin(nx * math.pi * 2 + t);

        // 8D → orbit wobble
        if (is8d) {
          h += 10 * math.sin(t * 2 + nx * 4 + ny * 3);
        }

        // Base wave
        h += 3 * math.sin(t + nx * 3) * math.cos(t * 0.7 + ny * 2);

        return h;
      });
    });

    // Draw horizontal lines
    for (var r = 0; r < _rows; r++) {
      final ny = r / (_rows - 1);
      final path = Path();

      for (var c = 0; c < _cols; c++) {
        final x = c * cellW;
        final y = r * cellH - heights[r][c];
        if (c == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Color based on position
      final alpha = (0.15 + ny * 0.2).clamp(0.05, 0.4);
      final lineColor = _getLineColor(ny, alpha);

      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = lineColor);
    }

    // Draw vertical lines
    for (var c = 0; c < _cols; c++) {
      final nx = c / (_cols - 1);
      final path = Path();

      for (var r = 0; r < _rows; r++) {
        final x = c * cellW;
        final y = r * cellH - heights[r][c];
        if (r == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final alpha = (0.08 + nx * 0.12).clamp(0.03, 0.25);
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = _getLineColor(nx, alpha));
    }

    // Center glow for vocal
    if (vocal > 0.5) {
      final glowAlpha = ((vocal - 0.5) * 0.6).clamp(0.0, 0.3);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFAA00).withValues(alpha: glowAlpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.45),
          radius: size.width * 0.25,
        ));
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        glowPaint,
      );
    }

    // Bottom bass glow
    if (bass > 0.6) {
      final bassGlow = ((bass - 0.6) * 0.5).clamp(0.0, 0.2);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: bassGlow),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  Color _getLineColor(double position, double alpha) {
    if (bass > 0.7 && position > 0.6) {
      return Color.lerp(
        const Color(0xFF8B5CF6),
        const Color(0xFFFF2D95),
        (position - 0.6) * 2.5,
      )!.withValues(alpha: alpha + 0.1);
    }
    if (vocal > 0.7 && position > 0.3 && position < 0.7) {
      return const Color(0xFFFFAA00).withValues(alpha: alpha + 0.05);
    }
    if (is8d) {
      return Color.lerp(
        const Color(0xFF06B6D4),
        const Color(0xFF8B5CF6),
        math.sin(time * math.pi * 2 + position * 3).abs(),
      )!.withValues(alpha: alpha);
    }
    return const Color(0xFF6366F1).withValues(alpha: alpha);
  }

  @override
  bool shouldRepaint(covariant _MeshPainter old) => true;
}

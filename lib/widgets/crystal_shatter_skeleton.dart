import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// Crystal Shatter Skeleton — Frosted glass loading animation.
/// While loading: a glowing crystal block with refraction beams.
/// On load complete: crystal shatters into shards that fly out.
/// ═══════════════════════════════════════════════════════════════
class CrystalShatterSkeleton extends StatefulWidget {
  const CrystalShatterSkeleton({
    super.key,
    this.height = 160,
    this.width,
    this.isLoaded = false,
    this.child,
  });

  final double height;
  final double? width;
  /// When true, triggers the shatter explosion
  final bool isLoaded;
  /// The actual content revealed after shatter
  final Widget? child;

  @override
  State<CrystalShatterSkeleton> createState() => _CrystalShatterSkeletonState();
}

class _CrystalShatterSkeletonState extends State<CrystalShatterSkeleton>
    with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late AnimationController _shatterCtrl;
  late List<_Shard> _shards;
  final _rng = math.Random();
  bool _shattered = false;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _shatterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _shards = List.generate(24, (_) => _Shard.random(_rng));
  }

  @override
  void didUpdateWidget(covariant CrystalShatterSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoaded && !oldWidget.isLoaded && !_shattered) {
      _triggerShatter();
    }
  }

  void _triggerShatter() {
    _shattered = true;
    _glowCtrl.stop();
    _shatterCtrl.forward();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _shatterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shattered && _shatterCtrl.isCompleted) {
      return widget.child ?? const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_glowCtrl, _shatterCtrl]),
      builder: (context, _) {
        return SizedBox(
          width: widget.width ?? double.infinity,
          height: widget.height,
          child: CustomPaint(
            painter: _CrystalPainter(
              glowPhase: _glowCtrl.value,
              shatterPhase: _shatterCtrl.value,
              shards: _shards,
              shattered: _shattered,
            ),
          ),
        );
      },
    );
  }
}

class _Shard {
  final double x, y;          // Origin (0..1 normalized)
  final double angle;          // Fly direction
  final double speed;          // Fly speed multiplier
  final double rotation;       // Spin speed
  final double size;           // Shard size
  final double opacity;

  const _Shard({
    required this.x, required this.y,
    required this.angle, required this.speed,
    required this.rotation, required this.size,
    required this.opacity,
  });

  factory _Shard.random(math.Random rng) {
    return _Shard(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      angle: rng.nextDouble() * math.pi * 2,
      speed: 0.5 + rng.nextDouble() * 1.5,
      rotation: (rng.nextDouble() - 0.5) * 8,
      size: 8 + rng.nextDouble() * 20,
      opacity: 0.4 + rng.nextDouble() * 0.6,
    );
  }
}

class _CrystalPainter extends CustomPainter {
  final double glowPhase;
  final double shatterPhase;
  final List<_Shard> shards;
  final bool shattered;

  _CrystalPainter({
    required this.glowPhase,
    required this.shatterPhase,
    required this.shards,
    required this.shattered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!shattered) {
      _paintCrystal(canvas, size);
    } else {
      _paintShatter(canvas, size);
    }
  }

  void _paintCrystal(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Frosted glass body
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1A1A3E).withValues(alpha: 0.7),
          const Color(0xFF0D0D2B).withValues(alpha: 0.85),
          const Color(0xFF1E1E45).withValues(alpha: 0.6),
        ],
        stops: [0.0, 0.5 + glowPhase * 0.1, 1.0],
      ).createShader(rect);

    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    canvas.drawRRect(rr, bodyPaint);

    // Glass edge border
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.15 + glowPhase * 0.1),
          Colors.white.withValues(alpha: 0.03),
          Colors.white.withValues(alpha: 0.12 + (1 - glowPhase) * 0.08),
        ],
      ).createShader(rect);
    canvas.drawRRect(rr, edgePaint);

    // Refraction beams — diagonal laser lines scanning across
    final beamPaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 3; i++) {
      final phase = (glowPhase + i * 0.33) % 1.0;
      final x = size.width * phase;
      beamPaint.color = Color.lerp(
        const Color(0xFF6366F1),
        const Color(0xFF06B6D4),
        phase,
      )!.withValues(alpha: 0.25 + glowPhase * 0.15);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height * 0.3, size.height),
        beamPaint,
      );
    }

    // Central glow pulse
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF8B5CF6).withValues(alpha: 0.06 + glowPhase * 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width * 0.5,
      ));
    canvas.drawRect(rect, glowPaint);

    // Fake "facet" lines — diamond cut pattern
    final facetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04 + glowPhase * 0.03)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.6),
      facetPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.7, size.height),
      facetPaint,
    );
  }

  void _paintShatter(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(shatterPhase);

    for (final shard in shards) {
      final cx = shard.x * size.width;
      final cy = shard.y * size.height;

      // Fly outward
      final dx = math.cos(shard.angle) * shard.speed * t * size.width * 0.6;
      final dy = math.sin(shard.angle) * shard.speed * t * size.height * 0.6;

      final alpha = (shard.opacity * (1.0 - t)).clamp(0.0, 1.0);
      if (alpha < 0.01) continue;

      canvas.save();
      canvas.translate(cx + dx, cy + dy);
      canvas.rotate(shard.rotation * t);

      // Shard shape — angular polygon
      final s = shard.size * (1.0 - t * 0.3);
      final path = Path()
        ..moveTo(0, -s * 0.5)
        ..lineTo(s * 0.4, s * 0.2)
        ..lineTo(-s * 0.1, s * 0.5)
        ..lineTo(-s * 0.4, -s * 0.1)
        ..close();

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: alpha),
            const Color(0xFF06B6D4).withValues(alpha: alpha * 0.6),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: s));
      canvas.drawPath(path, paint);

      // Edge glow on shard
      final edgePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.white.withValues(alpha: alpha * 0.4);
      canvas.drawPath(path, edgePaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CrystalPainter old) => true;
}

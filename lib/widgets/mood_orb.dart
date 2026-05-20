import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/dynamic_palette.dart';
import '../providers/feature_providers.dart';
import '../providers/providers.dart';
import '../services/ai_dj_service.dart';

/// Signature liquid/glass blob — mood + time + song tint.
class MoodOrb extends ConsumerStatefulWidget {
  const MoodOrb({super.key, this.size = 120, this.compact = false});

  final double size;
  final bool compact;

  @override
  ConsumerState<MoodOrb> createState() => _MoodOrbState();
}

class _MoodOrbState extends ConsumerState<MoodOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(dynamicPaletteProvider);
    final insight = ref.watch(aiInsightProvider);
    final hour = DateTime.now().hour;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        final morph = sin(t * pi * 2) * 0.08;
        return GestureDetector(
          onLongPress: () => ref.read(zenModeProvider.notifier).toggle(),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _OrbPainter(
                primary: palette.primary,
                secondary: palette.secondary,
                morph: morph,
                hourPhase: hour / 24,
                moodIndex: insight.mood.index / AiMood.values.length,
              ),
              child: widget.compact
                  ? null
                  : Center(
                      child: Text(
                        insight.mood.label.substring(0, 1),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w800,
                          fontSize: widget.size * 0.28,
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.primary,
    required this.secondary,
    required this.morph,
    required this.hourPhase,
    required this.moodIndex,
  });

  final Color primary;
  final Color secondary;
  final double morph;
  final double hourPhase;
  final double moodIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * (0.38 + morph);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(primary, secondary, moodIndex)!.withValues(alpha: 0.95),
          primary.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        stops: [0.0, 0.55 + hourPhase * 0.1, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.4))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    final path = Path();
    for (var i = 0; i <= 360; i += 8) {
      final rad = i * pi / 180;
      final wobble = 1 + morph * sin(rad * 3 + moodIndex * pi);
      final pt = center + Offset(cos(rad) * r * wobble, sin(rad) * r * wobble * 0.92);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);

    final gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: 0.35), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawCircle(center.translate(-r * 0.2, -r * 0.25), r * 0.35, gloss);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.morph != morph || old.primary != primary || old.moodIndex != moodIndex;
}

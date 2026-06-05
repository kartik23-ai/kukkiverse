import 'dart:math' as math;
import 'package:flutter/material.dart';

class RottyShimmerButton extends StatefulWidget {
  const RottyShimmerButton({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 14.0,
    this.strokeWidth = 2.0,
    this.borderColors = const [Color(0xFFFA2D48), Color(0xFF7B61FF), Color(0xFF00D4FF), Color(0xFFFA2D48)],
    this.baseColor = const Color(0xFF16162A),
    this.width,
    this.height,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final double strokeWidth;
  final List<Color> borderColors;
  final Color baseColor;
  final double? width;
  final double? height;

  @override
  State<RottyShimmerButton> createState() => _RottyShimmerButtonState();
}

class _RottyShimmerButtonState extends State<RottyShimmerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: widget.borderColors.first.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            // Inner background
            Positioned.fill(
              child: Container(
                color: widget.baseColor,
              ),
            ),
            // White Shimmer Sweep
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _InnerShimmerPainter(
                      progress: _ctrl.value,
                    ),
                  );
                },
              ),
            ),
            // Border Line Sweep
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _BorderLinePainter(
                      progress: _ctrl.value,
                      colors: widget.borderColors,
                      borderRadius: widget.borderRadius,
                      strokeWidth: widget.strokeWidth,
                    ),
                  );
                },
              ),
            ),
            // Tap area + Child
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                splashColor: widget.borderColors.first.withValues(alpha: 0.15),
                highlightColor: widget.borderColors.first.withValues(alpha: 0.05),
                child: Center(
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InnerShimmerPainter extends CustomPainter {
  final double progress;
  _InnerShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Linear gradient sweep from left to right (twice the size range)
    final sweepX = (progress * w * 2.5) - w;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.18), // Crisp white sweep
          Colors.white.withValues(alpha: 0.0),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(sweepX, 0, w * 0.7, h))
      ..blendMode = BlendMode.screen;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
  }

  @override
  bool shouldRepaint(covariant _InnerShimmerPainter old) => old.progress != progress;
}

class _BorderLinePainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final double borderRadius;
  final double strokeWidth;

  _BorderLinePainter({
    required this.progress,
    required this.colors,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rectPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h),
          Radius.circular(borderRadius),
        ),
      );

    final pathMetrics = rectPath.computeMetrics();

    for (final metric in pathMetrics) {
      final totalLength = metric.length;
      final segmentLength = totalLength * 0.22; // Sweep line length is 22% of total perimeter
      
      final start = totalLength * progress;
      final end = start + segmentLength;

      Path segment;
      if (end <= totalLength) {
        segment = metric.extractPath(start, end);
      } else {
        segment = metric.extractPath(start, totalLength);
        segment.addPath(metric.extractPath(0, end - totalLength), Offset.zero);
      }

      final gradientRect = Rect.fromCircle(
        center: Offset(
          w / 2 + (w / 2) * math.cos(progress * math.pi * 2),
          h / 2 + (h / 2) * math.sin(progress * math.pi * 2),
        ),
        radius: math.max(w, h) * 0.5,
      );

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: colors,
          stops: List.generate(colors.length, (i) => i / (colors.length - 1)),
        ).createShader(Rect.fromLTWH(0, 0, w, h));

      canvas.drawPath(segment, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BorderLinePainter old) {
    return old.progress != progress ||
        old.borderRadius != borderRadius ||
        old.strokeWidth != strokeWidth ||
        old.colors != colors;
  }
}

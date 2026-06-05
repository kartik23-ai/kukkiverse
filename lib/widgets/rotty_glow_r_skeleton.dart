import 'dart:math' as math;
import 'package:flutter/material.dart';

enum RottySkeletonType { card, list, chip, searchBar, aiDj, labs }

/// ═══════════════════════════════════════════════════════════════
/// Rotty Glow-R Loading Skeleton System — Branded Loading UI
/// Replaces generic shimmers with a custom, glowing, and pulsing
/// component-accurate skeleton layout with running laser lines
/// around borders and an inner premium white shimmer sweep.
/// ═══════════════════════════════════════════════════════════════
class RottyGlowRSkeleton extends StatefulWidget {
  const RottyGlowRSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 200,
    this.isCard = true,
    this.type = RottySkeletonType.card,
    this.borderRadius = 16.0,
  });

  final double width;
  final double height;
  final bool isCard;
  final RottySkeletonType type;
  final double borderRadius;

  factory RottyGlowRSkeleton.card({double width = 148, double height = 206}) {
    return RottyGlowRSkeleton(width: width, height: height, type: RottySkeletonType.card, isCard: true);
  }

  factory RottyGlowRSkeleton.list({double height = 72}) {
    return RottyGlowRSkeleton(width: double.infinity, height: height, type: RottySkeletonType.list, isCard: false);
  }

  factory RottyGlowRSkeleton.chip({required double width, double height = 40}) {
    return RottyGlowRSkeleton(
      width: width,
      height: height,
      type: RottySkeletonType.chip,
      borderRadius: 20,
      isCard: false,
    );
  }

  factory RottyGlowRSkeleton.searchBar({double height = 50}) {
    return RottyGlowRSkeleton(
      width: double.infinity,
      height: height,
      type: RottySkeletonType.searchBar,
      borderRadius: 12,
      isCard: false,
    );
  }

  factory RottyGlowRSkeleton.aiDj({double height = 140}) {
    return RottyGlowRSkeleton(
      width: double.infinity,
      height: height,
      type: RottySkeletonType.aiDj,
      borderRadius: 20,
      isCard: false,
    );
  }

  factory RottyGlowRSkeleton.labs({double height = 100}) {
    return RottyGlowRSkeleton(
      width: double.infinity,
      height: height,
      type: RottySkeletonType.labs,
      borderRadius: 16,
      isCard: false,
    );
  }

  @override
  State<RottyGlowRSkeleton> createState() => _RottyGlowRSkeletonState();
}

class _RottyGlowRSkeletonState extends State<RottyGlowRSkeleton>
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
    // Map isCard to correct type if it was passed directly instead of enum factories
    final resolvedType = widget.isCard && widget.type == RottySkeletonType.card
        ? RottySkeletonType.card
        : (!widget.isCard && widget.type == RottySkeletonType.card
            ? RottySkeletonType.list
            : widget.type);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return CustomPaint(
            painter: _RottyGlowRPainter(
              t: _ctrl.value,
              type: resolvedType,
              borderRadius: widget.borderRadius,
            ),
            size: Size(widget.width, widget.height),
          );
        },
      ),
    );
  }
}

class _RottyGlowRPainter extends CustomPainter {
  final double t;
  final RottySkeletonType type;
  final double borderRadius;

  _RottyGlowRPainter({
    required this.t,
    required this.type,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;

    // ─── Background Obsidian Panel ───
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF07070F),
          const Color(0xFF0C0D24),
          const Color(0xFF05050A),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(borderRadius));
    canvas.drawRRect(rrect, bgPaint);

    // Save and clip layer to ensure sweep line stays inside the container boundaries
    canvas.save();
    canvas.clipRRect(rrect);

    // ─── Placeholder Components ───
    final placeholderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04 + pulse * 0.02);

    switch (type) {
      case RottySkeletonType.card:
        // Rounded square for Album Art
        final albumW = w - 24;
        final albumH = w - 24;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(12, 12, albumW, albumH), const Radius.circular(12)),
          placeholderPaint,
        );

        // Title line
        final textY = 12 + albumH + 12;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(12, textY, w * 0.75, 12), const Radius.circular(6)),
          placeholderPaint,
        );

        // Artist line
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(12, textY + 20, w * 0.45, 10), const Radius.circular(5)),
          placeholderPaint,
        );
        break;

      case RottySkeletonType.list:
        // Circle avatar or rounded square for list item art on left
        final avatarSize = h - 24;
        final cy = h / 2;
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(12, 12, avatarSize, avatarSize), const Radius.circular(10)),
          placeholderPaint,
        );

        // Title line on right
        final textX = 12 + avatarSize + 12;
        final textW = w - textX - 16;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(textX, cy - 12, textW * 0.7, 12), const Radius.circular(6)),
          placeholderPaint,
        );

        // Artist line on right
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(textX, cy + 8, textW * 0.45, 10), const Radius.circular(5)),
          placeholderPaint,
        );
        break;

      case RottySkeletonType.chip:
        // Small chip, doesn't need internal placeholders, filled slightly
        break;

      case RottySkeletonType.searchBar:
        // Search icon placeholder (left circle)
        final cy = h / 2;
        canvas.drawCircle(Offset(24, cy), 10, placeholderPaint);

        // Search text line placeholder
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(48, cy - 5, w * 0.5, 10), const Radius.circular(5)),
          placeholderPaint,
        );

        // Mic icon placeholder (right circle)
        canvas.drawCircle(Offset(w - 24, cy), 10, placeholderPaint);
        break;

      case RottySkeletonType.aiDj:
        // AI DJ lock/avatar circle
        final cy = h / 2;
        canvas.drawCircle(Offset(44, cy), 24, placeholderPaint);

        // Title text line
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(84, cy - 24, w * 0.4, 12), const Radius.circular(6)),
          placeholderPaint,
        );

        // Subtitle line
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(84, cy - 4, w * 0.55, 10), const Radius.circular(5)),
          placeholderPaint,
        );

        // Progress bar line
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(84, cy + 16, w - 84 - 24, 4), const Radius.circular(2)),
          placeholderPaint,
        );
        break;

      case RottySkeletonType.labs:
        final cy = h / 2;
        // Icon rounded square on left
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(16, cy - 20, 40, 40), const Radius.circular(10)),
          placeholderPaint,
        );

        // Title line
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(72, cy - 14, w * 0.4, 12), const Radius.circular(6)),
          placeholderPaint,
        );

        // Subtitle line
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(72, cy + 6, w * 0.5, 10), const Radius.circular(5)),
          placeholderPaint,
        );
        break;
    }

    // ─── Inner White Shimmer Sweep ───
    final sweepX = (t * w * 2.5) - w;

    final sweepShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.0),
        Colors.white.withValues(alpha: 0.12), // Premium white sweep
        Colors.white.withValues(alpha: 0.0),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
    ).createShader(Rect.fromLTWH(sweepX, 0, w * 0.7, h));

    final sweepPaint = Paint()
      ..shader = sweepShader
      ..blendMode = BlendMode.screen;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sweepPaint);

    canvas.restore();

    // ─── GPU-Accelerated Rotating Border Laser Line ───
    final borderColors = const [
      Color(0xFFFA2D48), // Magenta
      Color(0xFF7B61FF), // Purple
      Color(0xFF00D4FF), // Cyan
      Color(0xFFFA2D48), // Magenta
    ];

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = SweepGradient(
        colors: borderColors,
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRRect(rrect, linePaint);

    // Static subtle backdrop border to fill in gaps
    final staticBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.05);
    canvas.drawRRect(rrect, staticBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _RottyGlowRPainter old) =>
      old.t != t || old.type != type || old.borderRadius != borderRadius;
}

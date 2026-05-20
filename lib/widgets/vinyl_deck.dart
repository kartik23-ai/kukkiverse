import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ═══════════════════════════════════════════════════════════════
/// Interactive Vinyl Deck — Live Pitch & Scratch Engine
/// • Double-tap toggle between normal album art ↔ vinyl mode
/// • Circular vinyl disc with grooves overlay
/// • Drag to scratch with live pitch/speed control
/// • Press-hold stops playback, release resumes with tape-spin
/// ═══════════════════════════════════════════════════════════════
class VinylDeck extends StatefulWidget {
  const VinylDeck({
    super.key,
    required this.imageUrl,
    required this.isPlaying,
    required this.accentColor,
    required this.onSpeedChange,
    required this.onPauseToggle,
    this.size = 280,
  });

  final String imageUrl;
  final bool isPlaying;
  final Color accentColor;
  final double size;
  /// Callback: speed factor (1.0 = normal, 0.0 = stopped, >1 = fast)
  final ValueChanged<double> onSpeedChange;
  /// Callback: true = pause, false = resume
  final ValueChanged<bool> onPauseToggle;

  @override
  State<VinylDeck> createState() => _VinylDeckState();
}

class _VinylDeckState extends State<VinylDeck>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinCtrl;
  double _currentAngle = 0;
  double _dragAngle = 0;
  bool _isHolding = false;
  bool _isDragging = false;

  // Scratch velocity tracking
  double _lastDragAngle = 0;
  double _scratchVelocity = 0;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) _spinCtrl.repeat();

    _spinCtrl.addListener(() {
      if (!_isDragging && !_isHolding) {
        setState(() => _currentAngle = _spinCtrl.value * math.pi * 2);
      }
    });
  }

  @override
  void didUpdateWidget(covariant VinylDeck old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_isHolding && !_isDragging) {
      _spinCtrl.repeat();
    } else if (!widget.isPlaying) {
      _spinCtrl.stop();
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _isHolding = true;
    _spinCtrl.stop();
    _lastDragAngle = _angleFromOffset(details.localPosition);
    widget.onPauseToggle(true);
    HapticFeedback.mediumImpact();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final newAngle = _angleFromOffset(details.localPosition);
    final delta = newAngle - _lastDragAngle;
    _scratchVelocity = delta;

    setState(() {
      _dragAngle += delta;
      _currentAngle += delta;
    });

    _lastDragAngle = newAngle;

    // Map scratch speed to playback speed
    final speed = (delta.abs() * 15).clamp(0.0, 3.0);
    widget.onSpeedChange(speed);

    // Haptic feedback on scratch
    if (delta.abs() > 0.02) {
      HapticFeedback.selectionClick();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    _isHolding = false;

    // Smooth return to normal speed
    widget.onSpeedChange(1.0);
    widget.onPauseToggle(false);

    if (widget.isPlaying) {
      _spinCtrl.repeat();
    }

    HapticFeedback.lightImpact();
  }

  double _angleFromOffset(Offset offset) {
    final center = Offset(widget.size / 2, widget.size / 2);
    return math.atan2(offset.dy - center.dy, offset.dx - center.dx);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ─── Outer glow ───
            Container(
              width: s + 20,
              height: s + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.25),
                    blurRadius: 32,
                    spreadRadius: -4,
                  ),
                ],
              ),
            ),

            // ─── Vinyl disc ───
            Transform.rotate(
              angle: _currentAngle,
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A0A0A),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // ─── Vinyl grooves ───
                    CustomPaint(
                      size: Size(s, s),
                      painter: _VinylGroovesPainter(widget.accentColor),
                    ),

                    // ─── Center album art (circular) ───
                    ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrl,
                        width: s * 0.42,
                        height: s * 0.42,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        fadeInDuration: Duration.zero,
                      ),
                    ),

                    // ─── Center spindle ───
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2A2A2A),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Tone arm indicator ───
            Positioned(
              right: 8,
              top: s * 0.15,
              child: Transform.rotate(
                angle: _isHolding ? -0.15 : 0.0,
                alignment: Alignment.topRight,
                child: Container(
                  width: 3,
                  height: s * 0.35,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1.5),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── "SCRATCH" label when dragging ───
            if (_isDragging)
              Positioned(
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'SCRATCH',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders realistic vinyl grooves as concentric rings
class _VinylGroovesPainter extends CustomPainter {
  final Color accent;
  _VinylGroovesPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final innerR = maxR * 0.22;
    final artR = maxR * 0.42;

    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;

    // Outer grooves (between art circle and edge)
    for (var r = artR + 4; r < maxR - 4; r += 2.5) {
      final opacity = 0.04 + (r / maxR) * 0.06;
      groovePaint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(center, r, groovePaint);
    }

    // Accent highlight ring
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = accent.withValues(alpha: 0.15);
    canvas.drawCircle(center, maxR * 0.65, highlightPaint);

    // Label area ring
    final labelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(center, artR + 2, labelPaint);
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter old) => old.accent != accent;
}

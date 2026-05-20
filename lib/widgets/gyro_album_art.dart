import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// ═══════════════════════════════════════════════════════════════
/// Gyroscope-Driven 3D Album Art — Apple TV Parallax Tilt
/// • Low-pass filtered gyroscope input for smooth motion
/// • 3-layer parallax: background glow → glass frame → foreground art
/// • Matrix4 perspective transform with depth
/// ═══════════════════════════════════════════════════════════════
class GyroAlbumArt extends StatefulWidget {
  const GyroAlbumArt({
    super.key,
    required this.child,
    required this.accentColor,
    this.size = 300,
    this.maxTilt = 0.06,
    this.glowSpread = 15.0,
  });

  final Widget child;
  final Color accentColor;
  final double size;
  /// Maximum tilt angle in radians
  final double maxTilt;
  /// How far the glow shifts on tilt
  final double glowSpread;

  @override
  State<GyroAlbumArt> createState() => _GyroAlbumArtState();
}

class _GyroAlbumArtState extends State<GyroAlbumArt> {
  double _pitch = 0; // X-axis tilt
  double _yaw = 0;   // Y-axis tilt
  StreamSubscription? _gyroSub;

  // Low-pass filter factor (0.0 = no update, 1.0 = instant)
  static const _smoothing = 0.08;

  @override
  void initState() {
    super.initState();
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 16),
    ).listen((event) {
      if (!mounted) return;
      setState(() {
        // Integrate gyro angular velocity → angle (with damping)
        _pitch = (_pitch + event.x * 0.016 * _smoothing)
            .clamp(-widget.maxTilt, widget.maxTilt);
        _yaw = (_yaw + event.y * 0.016 * _smoothing)
            .clamp(-widget.maxTilt, widget.maxTilt);

        // Natural decay back to center
        _pitch *= 0.96;
        _yaw *= 0.96;
      });
    }, onError: (_) {
      // Gyroscope not available — stay flat
    });
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final glowShiftX = _yaw * widget.glowSpread * 250;
    final glowShiftY = _pitch * widget.glowSpread * 250;
    final artShiftX = -_yaw * 10 * 250;
    final artShiftY = -_pitch * 10 * 250;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // ─── Layer 1: Background Neon Glow (shifts OPPOSITE) ───
          Positioned(
            left: -20 - glowShiftX,
            top: -20 - glowShiftY,
            child: Container(
              width: s + 40,
              height: s + 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.35),
                    blurRadius: 48,
                    spreadRadius: -8,
                  ),
                ],
              ),
            ),
          ),

          // ─── Layer 2: Glass Border Frame (LOCKED position) ───
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002) // perspective
              ..rotateX(_pitch)
              ..rotateY(_yaw),
            alignment: FractionalOffset.center,
            child: Container(
              width: s + 4,
              height: s + 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: Offset(glowShiftX * 0.3, glowShiftY * 0.3),
                  ),
                ],
              ),
            ),
          ),

          // ─── Layer 3: Foreground Album Art (shifts WITH tilt) ───
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateX(_pitch)
              ..rotateY(_yaw)
              ..translate(artShiftX, artShiftY),
            alignment: FractionalOffset.center,
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: Offset(glowShiftX * 0.15, 8 + glowShiftY * 0.15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: widget.child,
              ),
            ),
          ),

          // ─── Layer 4: Specular highlight (moves with tilt) ───
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateX(_pitch)
              ..rotateY(_yaw),
            alignment: FractionalOffset.center,
            child: IgnorePointer(
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment(
                      (-0.5 + _yaw * 10).clamp(-1.0, 1.0),
                      (-0.8 + _pitch * 10).clamp(-1.0, 1.0),
                    ),
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.08 + (_pitch.abs() + _yaw.abs()) * 0.5),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

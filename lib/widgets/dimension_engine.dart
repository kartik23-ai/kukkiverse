import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class DimensionEngine extends StatefulWidget {
  final Widget child;
  const DimensionEngine({super.key, required this.child});

  @override
  State<DimensionEngine> createState() => _DimensionEngineState();
}

class _DimensionEngineState extends State<DimensionEngine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // --- 3D NEBULA TUNNEL ---
            CustomPaint(
              painter: TunnelPainter(_controller.value),
              size: Size.infinite,
            ),
            // --- FLOATING 3D BLOCKS ---
            ...List.generate(5, (index) => _buildFloatingBlock(index)),
            
            widget.child,
          ],
        );
      },
    );
  }

  Widget _buildFloatingBlock(int index) {
    final speed = (index + 1) * 0.2;
    final angle = _controller.value * 2 * pi * speed;
    final radius = 150.0 + (index * 30);
    
    return Positioned(
      left: 200 + cos(angle) * radius,
      top: 400 + sin(angle) * radius,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(angle)
          ..rotateY(angle * 0.5),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.neonCyan.withAlpha(20),
            border: Border.all(color: AppColors.neonCyan.withAlpha(50)),
            boxShadow: [
              BoxShadow(color: AppColors.neonCyan.withAlpha(30), blurRadius: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class TunnelPainter extends CustomPainter {
  final double progress;
  TunnelPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 15; i++) {
      final ringProgress = (progress + (i / 15)) % 1.0;
      final radius = ringProgress * size.width * 1.5;
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0);
      
      paint.color = (i % 2 == 0 ? AppColors.neonCyan : AppColors.neonPink).withAlpha((opacity * 100).toInt());
      
      // Draw 3D-like Perspective Rings
      canvas.drawCircle(center, radius, paint);
      
      // Draw connecting lines for tunnel effect
      if (i % 3 == 0) {
        for (int j = 0; j < 8; j++) {
          final angle = (j * pi / 4) + (progress * pi);
          final start = Offset(center.dx + cos(angle) * (radius * 0.8), center.dy + sin(angle) * (radius * 0.8));
          final end = Offset(center.dx + cos(angle) * radius, center.dy + sin(angle) * radius);
          canvas.drawLine(start, end, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

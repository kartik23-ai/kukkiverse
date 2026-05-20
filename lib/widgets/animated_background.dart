import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AnimatedBackground extends StatelessWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // True deep black for professional OLED look
      body: Stack(
        children: [
          // Subtle ambient top gradient (Apple Music style)
          Positioned(
            top: -200,
            left: -100,
            right: -100,
            height: 500,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.neonCyan.withAlpha(30),
                    Colors.black.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

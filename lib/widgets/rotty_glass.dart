import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════
/// RottyGlass 3.0 — REAL Glassmorphism
/// • BackdropFilter blur (actual frosted glass)
/// • 1px inner white light-edge border
/// • Colored glow shadow from album art palette
/// ═══════════════════════════════════════════════════════════════
class RottyGlass extends StatelessWidget {
  const RottyGlass({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.tint,
    this.accentColor,
    this.glowIntensity = 0.15,
    this.blurAmount = 20,
    this.enableBlur = true,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;
  /// Color extracted from album art — drives the glow shadow color.
  final Color? accentColor;
  /// How strong the glow is. 0.0 = none, 0.4 = very strong.
  final double glowIntensity;
  /// Blur sigma for frosted glass effect.
  final double blurAmount;
  /// Set false on low-end devices to skip the expensive blur.
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final glow = accentColor ?? AppColors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            // Colored glow shadow from album art palette
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: glowIntensity),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: enableBlur
                  ? ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  // Semi-transparent tinted surface
                  color: (tint ?? AppColors.bgCard).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(borderRadius),
                  // ✨ 1px inner glass edge-light
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  // Subtle inner highlight for depth
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.02),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight version — no blur, just tinted surface with border.
/// Use this in scrolling lists where BackdropFilter is too expensive.
class RottyGlassLite extends StatelessWidget {
  const RottyGlassLite({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accentColor,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: accentColor != null
                ? [BoxShadow(color: accentColor!.withValues(alpha: 0.12), blurRadius: 16, spreadRadius: -4)]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class NeonSlideUnderline extends StatelessWidget {
  const NeonSlideUnderline({super.key, required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: width,
      height: 2,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
        ],
        color: color,
      ),
    );
  }
}

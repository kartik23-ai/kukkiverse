import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/storage_service.dart';

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
    this.blurAmount = 5,
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
    final performanceMode = StorageService().albumArtRipples;
    final finalEnableBlur = enableBlur && performanceMode;

    Widget container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (tint ?? Colors.white).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.04),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );

    Widget wrappedContent = Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            if (glowIntensity > 0)
              BoxShadow(
                color: glow.withValues(alpha: glowIntensity),
                blurRadius: 30,
                spreadRadius: 2,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: finalEnableBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
                  child: container,
                )
              : container,
        ),
      ),
    );

    if (onTap != null) {
      wrappedContent = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: wrappedContent,
        ),
      );
    }

    return wrappedContent;
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
    Widget container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.09),
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.03),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );

    Widget wrappedContent = Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: accentColor != null
              ? [BoxShadow(color: accentColor!.withValues(alpha: 0.12), blurRadius: 16, spreadRadius: -4)]
              : null,
        ),
        child: container,
      ),
    );

    if (onTap != null) {
      wrappedContent = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: wrappedContent,
        ),
      );
    }

    return wrappedContent;
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

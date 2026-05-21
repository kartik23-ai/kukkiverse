import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// ═══════════════════════════════════════════════════════════════
/// LIQUID GLASS ENGINE — True translucent material with:
///   • High-sigma frosted blur (30, 30)
///   • Dynamic light-catching gradient borders
///   • Inner glow + outer drop shadow for depth
///   • Translucent surface that lets Aurora shine through
/// ═══════════════════════════════════════════════════════════════

class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blur = 30,
    this.surfaceOpacity = 0.08,
    this.borderOpacity = 0.15,
    this.glowColor,
    this.glowIntensity = 0.0,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.width,
    this.height,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final double surfaceOpacity;
  final double borderOpacity;
  final Color? glowColor;
  final double glowIntensity;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            // Translucent surface — NOT opaque black
            color: Colors.white.withValues(alpha: surfaceOpacity),
            // Light-catching gradient border
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 1,
            ),
            // Inner glow for depth
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: surfaceOpacity + 0.04),
                Colors.white.withValues(alpha: surfaceOpacity),
                Colors.white.withValues(alpha: surfaceOpacity - 0.02),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            // Drop shadow for physical depth
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              if (glowColor != null && glowIntensity > 0)
                BoxShadow(
                  color: glowColor!.withValues(alpha: glowIntensity),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: content),
      );
    }

    return Padding(padding: margin, child: content);
  }
}

/// Liquid Glass Card — Interactive with hover glow + scale
class LiquidGlassCard extends StatefulWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.all(16),
    this.accentColor = const Color(0xFFFA2D48),
    this.onTap,
    this.width,
    this.height,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final Color accentColor;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: _hovered ? Matrix4.diagonal3Values(1.02, 1.02, 1.0) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: widget.width,
                height: widget.height,
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: _hovered ? 0.14 : 0.08),
                      Colors.white.withValues(alpha: _hovered ? 0.08 : 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: _hovered
                        ? widget.accentColor.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    if (_hovered)
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass Button — Pill-shaped, neon accent on hover
class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.accentColor = const Color(0xFFFA2D48),
    this.isActive = false,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color accentColor;
  final bool isActive;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: active
                ? widget.accentColor.withValues(alpha: 0.18)
                : _hovered
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: active
                  ? widget.accentColor.withValues(alpha: 0.4)
                  : _hovered
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: active
                ? [BoxShadow(color: widget.accentColor.withValues(alpha: 0.15), blurRadius: 16)]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Liquid Glass Sidebar Panel
class LiquidGlassSidebar extends StatelessWidget {
  const LiquidGlassSidebar({
    super.key,
    required this.child,
    this.width = 240,
    this.accentColor,
  });

  final Widget child;
  final double width;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            // Translucent — NOT opaque
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accentColor != null
                    ? accentColor!.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.07),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border(
              right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Liquid Glass Bottom Bar
class LiquidGlassBottomBar extends StatelessWidget {
  const LiquidGlassBottomBar({
    super.key,
    required this.child,
    this.height = 90,
    this.accentColor,
  });

  final Widget child;
  final double height;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.06),
                if (accentColor != null) accentColor!.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.06),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

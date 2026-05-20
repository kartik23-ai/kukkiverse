import 'package:flutter/material.dart';
import 'rotty_glass.dart';

/// Legacy alias — delegates to Glass 2.0.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RottyGlass(
      borderRadius: borderRadius,
      padding: padding,
      onTap: onTap,
      child: child,
    );
  }
}

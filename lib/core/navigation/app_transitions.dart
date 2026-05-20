import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

CustomTransitionPage<T> rottyPage<T>({
  required Widget child,
  AxisDirection from = AxisDirection.up,
}) {
  return CustomTransitionPage<T>(
    child: child,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    transitionsBuilder: (context, animation, secondary, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final offset = switch (from) {
        AxisDirection.up => const Offset(0, 0.12),
        AxisDirection.down => const Offset(0, -0.12),
        AxisDirection.left => const Offset(0.12, 0),
        AxisDirection.right => const Offset(-0.12, 0),
      };
      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(curve),
        child: SlideTransition(
          position: Tween(begin: offset, end: Offset.zero).animate(curve),
          child: child,
        ),
      );
    },
  );
}

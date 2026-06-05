import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight shell — transparent bg so RottyAuroraBackground shows through.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.body, this.bottomPadding = 0});

  final Widget body;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: body,
      ),
    );
  }
}

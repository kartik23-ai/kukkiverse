import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/feature_providers.dart';
import '../providers/premium_providers.dart';

/// Lightweight shell — transparent bg so RottyAuroraBackground shows through.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.body, this.bottomPadding = 0});

  final Widget body;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: body,
        ),
      ),
    );
  }
}

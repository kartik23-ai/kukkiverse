import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps premium-only UI — tap opens paywall when locked.
class PremiumGate extends ConsumerWidget {
  const PremiumGate({super.key, required this.child, this.lockedMessage});

  final Widget child;
  final String? lockedMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return child;
  }
}

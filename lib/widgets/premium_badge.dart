import 'package:flutter/material.dart';

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.small = false, this.unlocked = true});

  final bool small;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

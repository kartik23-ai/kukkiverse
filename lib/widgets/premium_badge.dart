import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.small = false, this.unlocked = true});

  final bool small;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        gradient: unlocked ? AppColors.accentGradient : null,
        color: unlocked ? null : Colors.white12,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: unlocked ? Colors.transparent : AppColors.glassBorder),
      ),
      child: Text(
        unlocked ? 'PRO' : 'PRO',
        style: GoogleFonts.inter(
          fontSize: small ? 9 : 10,
          fontWeight: FontWeight.w800,
          color: unlocked ? Colors.white : AppColors.textTertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

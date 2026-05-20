import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../providers/premium_providers.dart';

class StreakChip extends ConsumerWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(listeningStreakProvider);
    if (streak.days < 1 && !streak.listenedToday) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_rounded, color: AppColors.accent, size: 18),
          const SizedBox(width: 6),
          Text(
            streak.days > 0 ? '${streak.days} day streak' : 'Start your streak today',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (streak.listenedToday) ...[
            const SizedBox(width: 8),
            Text('✓ today', style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

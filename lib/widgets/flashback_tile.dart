import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../providers/feature_providers.dart';
import '../utils/play_song.dart';

class FlashbackTile extends ConsumerWidget {
  const FlashbackTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastYear = DateTime.now().subtract(const Duration(days: 365));
    final entries = ref.watch(playHistoryProvider).where((e) {
      final d = e.playedAt;
      return d.year == lastYear.year && d.month == lastYear.month && d.day == lastYear.day;
    }).toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    final hit = entries.first.song;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => playSongWithContext(ref, hit),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history_rounded, color: AppColors.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flashback', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                      Text(hit.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                      Text('Is din last year • ${hit.artist}', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

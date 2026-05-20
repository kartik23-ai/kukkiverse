import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/mood_orb.dart';
import '../../widgets/rotty_glass.dart';

class WeeklyWrappedScreen extends ConsumerWidget {
  const WeeklyWrappedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(playHistoryProvider);
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final week = history.where((e) => e.playedAt.isAfter(weekAgo)).toList();

    final minutes = week.fold<int>(0, (sum, e) {
      final d = e.song.duration.inSeconds;
      return sum + (d > 0 ? (d ~/ 60).clamp(1, 8) : 3);
    });
    final artistCounts = <String, int>{};
    for (final e in week) {
      artistCounts[e.song.artist] = (artistCounts[e.song.artist] ?? 0) + 1;
    }
    final topArtist = artistCounts.entries.isEmpty
        ? '—'
        : (artistCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned(top: 60, right: 20, child: MoodOrb(size: 180)),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => context.pop()),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      onPressed: () => Share.share('My ROTTY Wrapped: $minutes min • Top: $topArtist 🎵'),
                    ),
                  ],
                ),
                const Spacer(),
                Text('ROTTY', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 14, letterSpacing: 8, fontWeight: FontWeight.w800)),
                Text('Wrapped', style: GoogleFonts.inter(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
                Text('This week', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                const SizedBox(height: 32),
                RottyGlass(
                  child: Column(
                    children: [
                      _stat('$minutes', 'minutes'),
                      const Divider(color: AppColors.glassBorder),
                      _stat('${week.length}', 'plays'),
                      const Divider(color: AppColors.glassBorder),
                      _stat(topArtist, 'top artist'),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800), textAlign: TextAlign.center, maxLines: 2),
          Text(label, style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}

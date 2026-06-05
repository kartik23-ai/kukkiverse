import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../providers/feature_providers.dart';
import '../providers/providers.dart';
import '../services/ai_dj_service.dart';
import '../utils/ai_queue.dart';
import 'rotty_glass.dart';

class AiDjProPanel extends ConsumerWidget {
  const AiDjProPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(aiInsightProvider);
    final override = ref.watch(aiDjMoodOverrideProvider);
    final song = ref.watch(nowPlayingProvider);
    final reason = ref.read(aiDjServiceProvider).buildReasonLine(
          nowPlaying: song,
          recent: ref.watch(recentSongsProvider),
          override: override,
        );

    return RottyGlass(
      tint: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('ROTTY AI DJ Pro', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(reason, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(ref, 'Ab chill mode', AiMood.chill, Icons.nights_stay_rounded),
              _chip(ref, 'Ab party', AiMood.party, Icons.celebration_rounded),
              _chip(ref, 'Focus', AiMood.focus, Icons.psychology_rounded),
              _chip(ref, 'Romantic', AiMood.romantic, Icons.favorite_rounded),
            ],
          ),
          if (insight.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...insight.reasons.take(2).map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 14, color: AppColors.accent.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(r, style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11))),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _chip(WidgetRef ref, String label, AiMood mood, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.accent),
      label: Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
      backgroundColor: AppColors.bgCard.withValues(alpha: 0.6),
      side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
      onPressed: () async {
        ref.read(aiDjMoodOverrideProvider.notifier).state = mood;
        final handler = ref.read(audioHandlerProvider);
        final current = handler.currentSong;
        final exclude = buildAiExcludeSet(ref, handler);
        final songs = await ref.read(aiDjServiceProvider).applyMoodTransition(
          target: mood,
          nowPlaying: current,
          recent: ref.read(recentSongsProvider),
          favorites: ref.read(favoritesProvider),
          excludeIds: exclude,
          excludeSongs: [
            ...handler.songQueue,
            ...handler.history,
          ],
        );
        if (songs.isNotEmpty) {
          await handler.appendUpcoming(songs);
        }
      },
    );
  }
}

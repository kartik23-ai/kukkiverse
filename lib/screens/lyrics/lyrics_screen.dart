import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../models/lyrics_line.dart';
import '../../providers/providers.dart';
import '../../providers/premium_providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/live_karaoke_lyrics.dart';

class LyricsScreen extends ConsumerWidget {
  const LyricsScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(lyricsProvider(songId));
    final song = ref.watch(nowPlayingProvider);
    final palette = ref.watch(dynamicPaletteProvider);
    final handler = ref.read(audioHandlerProvider);

    return AppScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => context.pop()),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song?.title ?? 'Lyrics', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(song?.artist ?? '', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    ref.watch(hapticLyricsProvider) ? Icons.vibration_rounded : Icons.vibration_outlined,
                    color: AppColors.accent,
                  ),
                  onPressed: () => ref.read(hapticLyricsProvider.notifier).set(!ref.read(hapticLyricsProvider)),
                ),
                IconButton(
                  icon: const Icon(Icons.movie_rounded, color: Colors.white70),
                  onPressed: () => context.push('/cinema/$songId'),
                ),
                IconButton(
                  icon: const Icon(Icons.movie_filter_outlined, color: Colors.white70),
                  onPressed: () => context.push('/lyrics-clip/$songId'),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white70),
                  onPressed: () {
                    lyrics.whenData((l) {
                      if (l != null) Share.share(l);
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: lyrics.when(
              data: (text) {
                if (text == null || text.trim().isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Lyrics are not available for this song.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 14),
                      ),
                    ),
                  );
                }
                final dur = handler.player.duration ?? song?.duration ?? const Duration(minutes: 3, seconds: 30);
                final lines = parseLyricsToLines(text, dur);
                final isSynced = text.contains(RegExp(r'\[\d+:\d{2}'));
                
                return StreamBuilder<Duration>(
                  stream: handler.player.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: LiveKaraokeLyrics(
                        lines: lines,
                        position: pos,
                        accent: palette.primary,
                        dualLanguage: false,
                        maxHeight: MediaQuery.of(context).size.height - 120,
                        isSynced: isSynced,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (_, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load lyrics. Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

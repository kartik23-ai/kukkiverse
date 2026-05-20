import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/live_karaoke_lyrics.dart';
import '../../models/lyrics_line.dart';

/// ═══════════════════════════════════════════════════════════════
/// Desktop Now Playing Panel — Right collapsible panel
/// Album art, live lyrics, song queue
/// ═══════════════════════════════════════════════════════════════
class DesktopNowPlaying extends ConsumerWidget {
  const DesktopNowPlaying({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(nowPlayingProvider);
    final palette = ref.watch(dynamicPaletteProvider);
    final handler = ref.read(audioHandlerProvider);

    if (song == null) {
      return Container(
        width: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0F).withValues(alpha: 0.95),
          border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note_rounded, size: 48, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 12),
              Text('No song playing', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0F).withValues(alpha: 0.95),
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Text(
                  'NOW PLAYING',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white30,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.primary,
                    boxShadow: [BoxShadow(color: palette.primary.withValues(alpha: 0.5), blurRadius: 6)],
                  ),
                ),
              ],
            ),
          ),

          // Album art
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: song.image,
                width: 260, height: 260,
                fit: BoxFit.cover,
                memCacheWidth: 520,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Song info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  style: GoogleFonts.inter(fontSize: 13, color: palette.primary.withValues(alpha: 0.8)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                if (song.album.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    song.album,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white24),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          ),

          // Lyrics section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.lyrics_rounded, size: 14, color: palette.primary.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(
                  'LIVE LYRICS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white30,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Live lyrics
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final lyrics = ref.watch(lyricsProvider(song.id));
                return lyrics.when(
                  data: (text) {
                    if (text == null || text.trim().isEmpty) {
                      return Center(
                        child: Text('No lyrics available',
                            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 12)),
                      );
                    }
                    final lines = parseLyricsToLines(text, song.duration);
                    return StreamBuilder<Duration>(
                      stream: handler.player.positionStream,
                      builder: (context, snap) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: LiveKaraokeLyrics(
                            lines: lines,
                            position: snap.data ?? Duration.zero,
                            accent: palette.primary,
                            maxHeight: 300,
                          ),
                        );
                      },
                    );
                  },
                  loading: () => Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: palette.primary.withValues(alpha: 0.3)),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

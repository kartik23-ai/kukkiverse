import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';

/// ═══════════════════════════════════════════════════════════════
/// Desktop Bottom Play Bar — Full-width Spotify-style
/// Left: Art + Title | Center: Controls + Progress | Right: Volume
/// ═══════════════════════════════════════════════════════════════
class DesktopPlayerBar extends ConsumerWidget {
  const DesktopPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(nowPlayingProvider);
    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    if (song == null) return const SizedBox.shrink();

    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0F).withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Column(
        children: [
          // Progress bar at top (full width, thin)
          StreamBuilder<Duration>(
            stream: handler.player.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = handler.player.duration ?? song.duration;
              final progress = dur.inMilliseconds > 0
                  ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                  : 0.0;
              return GestureDetector(
                onTapDown: (details) {
                  final width = MediaQuery.of(context).size.width;
                  final ratio = (details.localPosition.dx / width).clamp(0.0, 1.0);
                  handler.player.seek(Duration(milliseconds: (dur.inMilliseconds * ratio).round()));
                },
                child: Container(
                  height: 3,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.06),
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: MediaQuery.of(context).size.width * progress,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [palette.primary, palette.primary.withValues(alpha: 0.7)],
                      ),
                      boxShadow: [BoxShadow(color: palette.primary.withValues(alpha: 0.3), blurRadius: 6)],
                    ),
                  ),
                ),
              );
            },
          ),
          // Main bar
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // ─── Left: Album Art + Info ───
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: song.image,
                      width: 52, height: 52,
                      fit: BoxFit.cover,
                      memCacheWidth: 104,
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 180,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Favorite
                  Consumer(
                    builder: (context, ref, _) {
                      final isFav = ref.watch(favoritesProvider.select((f) => f.any((s) => s.id == song.id)));
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? palette.primary : Colors.white24,
                          size: 18,
                        ),
                        onPressed: () => ref.read(favoritesProvider.notifier).toggle(song),
                      );
                    },
                  ),

                  const Spacer(),

                  // ─── Center: Controls ───
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, color: Colors.white30, size: 18),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70, size: 26),
                    onPressed: () => handler.skipToPrevious(),
                  ),
                  const SizedBox(width: 4),
                  // Play/Pause
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 12)],
                    ),
                    child: IconButton(
                      icon: Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
                      onPressed: () => playing ? handler.pause() : handler.play(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 26),
                    onPressed: () => handler.skipToNext(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.repeat_rounded, color: Colors.white30, size: 18),
                    onPressed: () {},
                  ),

                  const Spacer(),

                  // ─── Right: Volume + extras ───
                  const Icon(Icons.volume_up_rounded, color: Colors.white30, size: 18),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 100,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: Colors.white70,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: Colors.white,
                      ),
                      child: StreamBuilder<double>(
                        stream: handler.player.volumeStream,
                        builder: (context, snap) {
                          final vol = snap.data ?? 1.0;
                          return Slider(
                            value: vol,
                            onChanged: (v) => handler.player.setVolume(v),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Lyrics toggle
                  IconButton(
                    icon: const Icon(Icons.lyrics_rounded, color: Colors.white30, size: 18),
                    onPressed: () {},
                    tooltip: 'Lyrics',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

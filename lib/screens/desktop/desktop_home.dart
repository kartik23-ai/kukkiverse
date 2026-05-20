import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/song_model.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/rotty_glass.dart';
import '../../widgets/crystal_shatter_skeleton.dart';
import '../../utils/play_song.dart';


/// ═══════════════════════════════════════════════════════════════
/// Desktop Home — Multi-column masonry grid with hover effects
/// Same data providers, adapted for widescreen
/// ═══════════════════════════════════════════════════════════════
class DesktopHome extends ConsumerWidget {
  const DesktopHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeData = ref.watch(homeDataProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return homeData.when(
      data: (sections) {
        if (sections.isEmpty) {
          return Center(
            child: Text('No content yet', style: GoogleFonts.inter(color: Colors.white38)),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
          children: [
            // Greeting
            Text(
              _greeting(),
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),

            // Quick picks (first 6 songs from first section)
            if (sections.values.first.isNotEmpty) ...[
              _QuickPicksGrid(songs: sections.values.first.take(6).toList(), accent: palette.primary),
              const SizedBox(height: 36),
            ],

            // Sections
            for (final entry in sections.entries) ...[
              Text(
                entry.key,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _SongGrid(songs: entry.value),
              const SizedBox(height: 32),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: CrystalShatterSkeleton(),
      ),
      error: (_, __) => Center(
        child: Text('Failed to load', style: GoogleFonts.inter(color: Colors.white38)),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

/// Quick picks — 2x3 grid of compact cards (Spotify-style)
class _QuickPicksGrid extends ConsumerWidget {
  const _QuickPicksGrid({required this.songs, required this.accent});
  final List<SongModel> songs;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 3.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: songs.length,
      itemBuilder: (context, i) {
        final song = songs[i];
        return _QuickPickCard(song: song);
      },
    );
  }
}

class _QuickPickCard extends ConsumerStatefulWidget {
  const _QuickPickCard({required this.song});
  final SongModel song;

  @override
  ConsumerState<_QuickPickCard> createState() => _QuickPickCardState();
}

class _QuickPickCardState extends ConsumerState<_QuickPickCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => playSongWithContext(ref, widget.song),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hovered
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.song.image,
                  width: 56, height: 56,
                  fit: BoxFit.cover,
                  memCacheWidth: 112,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.song.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hovered)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                      boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Main song grid — 4-5 columns
class _SongGrid extends ConsumerWidget {
  const _SongGrid({required this.songs});
  final List<SongModel> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.78,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: songs.length,
      itemBuilder: (context, i) => _DesktopSongCard(song: songs[i]),
    );
  }
}

class _DesktopSongCard extends ConsumerStatefulWidget {
  const _DesktopSongCard({required this.song});
  final SongModel song;

  @override
  ConsumerState<_DesktopSongCard> createState() => _DesktopSongCardState();
}

class _DesktopSongCardState extends ConsumerState<_DesktopSongCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => playSongWithContext(ref, widget.song),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _hovered
              ? Matrix4.translationValues(0, -4, 0)
              : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album art with hover play button
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: widget.song.image,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                      ),
                    ),
                    // Hover shadow
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _hovered
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))]
                            : [],
                      ),
                    ),
                    // Play button
                    if (_hovered)
                      Positioned(
                        bottom: 8, right: 8,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                            boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 12)],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.song.title,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.song.artist,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

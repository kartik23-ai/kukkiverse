import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/mode_theme.dart';
import '../../core/modes/app_mode.dart';
import '../../models/song_model.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/crystal_shatter_skeleton.dart';
import '../../widgets/liquid_glass.dart';
import '../../core/theme/dynamic_palette.dart';
import '../../utils/play_song.dart';
import '../../widgets/song_options_sheet.dart';

/// ═══════════════════════════════════════════════════════════════
/// Desktop Home 3.0 — Liquid Glass, visible cards, glow effects
/// Quick Picks grid + Continue Listening + Section rows
/// ═══════════════════════════════════════════════════════════════
class DesktopHome extends ConsumerWidget {
  const DesktopHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeData = ref.watch(homeDataProvider);
    final recent = ref.watch(recentSongsProvider);
    final suggestedSongsAsync = ref.watch(suggestedSongsProvider);
    final suggestedSongs = suggestedSongsAsync.value ?? <SongModel>[];
    final palette = ref.watch(dynamicPaletteProvider);
    final mode = ref.watch(appModeProvider);
    final mt = ModeTheme(mode);
    final aiOn = ref.watch(aiDjEnabledProvider);

    return homeData.when(
      data: (sections) {
        if (sections.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 16),
                Text('No songs found', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                LiquidGlassButton(
                  accentColor: mt.accent,
                  onTap: () => ref.invalidate(homeDataProvider),
                  child: Text('Retry', style: GoogleFonts.inter(color: mt.accent, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 100),
          children: [
            // ─── Header with greeting + AI DJ ───
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [palette.primary, const Color(0xFF7B61FF), const Color(0xFF00D4FF)],
                        ).createShader(bounds),
                        child: Text(
                          _greeting(),
                          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your personal music universe',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                LiquidGlassButton(
                  accentColor: palette.primary,
                  isActive: aiOn,
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  onTap: () => ref.read(aiDjEnabledProvider.notifier).state = !aiOn,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 16,
                          color: aiOn ? palette.primary : Colors.white.withValues(alpha: 0.4)),
                      const SizedBox(width: 8),
                      Text(
                        'AI DJ ${aiOn ? 'ON' : 'OFF'}',
                        style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: aiOn ? palette.primary : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Explore Genres & Moods Row (Visual Excellence) ───
            _DesktopGenresRow(accentColor: palette.primary),
            const SizedBox(height: 24),

            // ─── Quick Picks (liquid glass compact cards) ───
            if (sections.values.first.isNotEmpty) ...[
              _QuickPicksGrid(songs: sections.values.first.take(6).toList(), mt: mt, palette: palette),
              const SizedBox(height: 32),
            ],

            // ─── Continue Listening ───
            if (recent.isNotEmpty) ...[
              _SectionHeader(title: 'Continue Listening'),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.take(10).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) => _DesktopSongCard(song: recent[i], playlist: recent, mt: mt),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ─── Recommended for You ───
            if (suggestedSongs.isNotEmpty) ...[
              _SectionHeader(title: 'Recommended for You'),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestedSongs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) => _DesktopSongCard(song: suggestedSongs[i], playlist: suggestedSongs, mt: mt),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ─── All Sections ───
            for (final entry in sections.entries) ...[
              _SectionHeader(title: entry.key),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: entry.value.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) => _DesktopSongCard(song: entry.value[i], playlist: entry.value, mt: mt),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CrystalShatterSkeleton(height: 180),
            SizedBox(height: 16),
            CrystalShatterSkeleton(height: 120),
          ],
        ),
      ),
      error: (_, __) => Center(
        child: Text('Failed to load', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5))),
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

/// Section header — bright, visible
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
    );
  }
}

/// Quick picks — 2x3 liquid glass compact cards
class _QuickPicksGrid extends ConsumerWidget {
  const _QuickPicksGrid({required this.songs, required this.mt, required this.palette});
  final List<SongModel> songs;
  final ModeTheme mt;
  final DynamicPalette palette;

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
      itemBuilder: (context, i) => _QuickPickCard(song: songs[i], mt: mt, palette: palette),
    );
  }
}

class _QuickPickCard extends ConsumerStatefulWidget {
  const _QuickPickCard({required this.song, required this.mt, required this.palette});
  final SongModel song;
  final ModeTheme mt;
  final DynamicPalette palette;

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
        onTap: () async {
          try { await playSongWithContext(ref, widget.song); } catch (_) {}
        },
        onSecondaryTapDown: (_) => showSongOptionsSheet(context, ref, widget.song),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withValues(alpha: _hovered ? 0.14 : 0.08),
                    Colors.white.withValues(alpha: _hovered ? 0.08 : 0.04),
                  ],
                ),
                border: Border.all(
                  color: _hovered
                      ? widget.mt.accent.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                ),
                boxShadow: _hovered
                    ? [BoxShadow(color: widget.mt.accent.withValues(alpha: 0.15), blurRadius: 20)]
                    : null,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(9),
                      bottomLeft: Radius.circular(9),
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
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_hovered)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.mt.accent,
                          boxShadow: [BoxShadow(color: widget.mt.accent.withValues(alpha: 0.5), blurRadius: 12)],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium song card — liquid glass border, glow shadow, hover lift
class _DesktopSongCard extends ConsumerStatefulWidget {
  const _DesktopSongCard({required this.song, required this.playlist, required this.mt});
  final SongModel song;
  final List<SongModel> playlist;
  final ModeTheme mt;

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
        onTap: () async {
          try {
            await playSongWithContext(ref, widget.song, playlist: widget.playlist);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not play ${widget.song.title}')),
              );
            }
          }
        },
        onSecondaryTapDown: (_) => showSongOptionsSheet(context, ref, widget.song),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: _hovered ? Matrix4.translationValues(0, -6, 0) : Matrix4.identity(),
          child: SizedBox(
            width: 165,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Album art with glass border + glow
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _hovered
                          ? widget.mt.accent.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _hovered
                            ? widget.mt.accent.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.3),
                        blurRadius: _hovered ? 28 : 8,
                        offset: const Offset(0, 6),
                        spreadRadius: _hovered ? 2 : -2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: CachedNetworkImage(
                          imageUrl: widget.song.image,
                          width: 165, height: 155,
                          fit: BoxFit.cover,
                          memCacheWidth: 330,
                          fadeInDuration: Duration.zero,
                        ),
                      ),
                      if (_hovered)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              color: Colors.black.withValues(alpha: 0.35),
                            ),
                            child: Center(
                              child: Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.mt.accent,
                                  boxShadow: [BoxShadow(color: widget.mt.accent.withValues(alpha: 0.5), blurRadius: 16)],
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Title + artist
                Text(
                  widget.song.title,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    navigateToArtist(context, ref, widget.song.artist);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      widget.song.artist,
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, height: 1.2),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopGenresRow extends StatelessWidget {
  const _DesktopGenresRow({required this.accentColor});
  final Color accentColor;

  static const _genres = [
    ('Love', LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)])),
    ('Devotional', LinearGradient(colors: [Color(0xFFF12711), Color(0xFFF5AF19)])),
    ('Party', LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)])),
    ('Workout', LinearGradient(colors: [Color(0xFFFC4A1A), Color(0xFFF7B733)])),
    ('Chill', LinearGradient(colors: [Color(0xFF00B4DB), Color(0xFF0083B0)])),
    ('Sad', LinearGradient(colors: [Color(0xFF3A6073), Color(0xFF3A6073)])),
    ('Punjabi', LinearGradient(colors: [Color(0xFF7F00FF), Color(0xFFE100FF)])),
    ('English', LinearGradient(colors: [Color(0xFFED213A), Color(0xFF93291E)])),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore Genres & Moods',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _genres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = _genres[i];
              return LiquidGlassButton(
                accentColor: accentColor,
                onTap: () {
                  context.push('/album/genre_${item.$1}', extra: {
                    'title': '${item.$1} Station',
                  });
                },
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                borderRadius: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: item.$2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.$1,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

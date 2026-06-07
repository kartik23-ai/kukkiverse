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
import '../../widgets/desktop_scroll_wrapper.dart';
import '../../core/theme/dynamic_palette.dart';
import '../../utils/play_song.dart';
import '../../widgets/song_options_sheet.dart';
import '../../services/storage_service.dart';
import '../home/home_screen.dart' show IndianTopHitsBox, NewReleasesBox, PopularAlbumsSection;

/// ═══════════════════════════════════════════════════════════════
/// Desktop Home 4.0 — Full Sections: Trending, New Releases,
/// Artists, Albums — Liquid Glass throughout
/// ═══════════════════════════════════════════════════════════════
class DesktopHome extends ConsumerStatefulWidget {
  const DesktopHome({super.key});

  @override
  ConsumerState<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends ConsumerState<DesktopHome> {
  late final ScrollController _verticalController;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeData = ref.watch(homeDataProvider);
    final recent = ref.watch(recentSongsProvider);
    final suggestedSongsAsync = ref.watch(suggestedSongsProvider);
    final suggestedSongs = suggestedSongsAsync.value ?? <SongModel>[];
    final palette = ref.watch(dynamicPaletteProvider);
    final mode = ref.watch(appModeProvider);
    final mt = ModeTheme(mode);
    final aiOn = ref.watch(aiDjEnabledProvider);
    final homeArtistsAsync = ref.watch(homeArtistsProvider);
    final homeArtists = homeArtistsAsync.valueOrNull ?? [];

    final topArtists = homeArtists.isNotEmpty
        ? homeArtists.take(8).toList()
        : const [
            (name: 'Arijit Singh', img: 'https://c.saavncdn.com/artists/Arijit_Singh_004_20241118063717_150x150.jpg'),
            (name: 'Pritam', img: 'https://c.saavncdn.com/artists/Pritam_Chakraborty-20170711073326_150x150.jpg'),
            (name: 'A.R. Rahman', img: 'https://c.saavncdn.com/artists/AR_Rahman_002_20210120084455_150x150.jpg'),
            (name: 'Shreya Ghoshal', img: 'https://c.saavncdn.com/artists/Shreya_Ghoshal_007_20241101074144_150x150.jpg'),
            (name: 'Jubin Nautiyal', img: 'https://c.saavncdn.com/artists/Jubin_Nautiyal_003_20231130204020_150x150.jpg'),
            (name: 'Anuv Jain', img: 'https://c.saavncdn.com/artists/Anuv_Jain_500x500.jpg'),
            (name: 'Neha Kakkar', img: 'https://c.saavncdn.com/artists/Neha_Kakkar_006_20240603065229_150x150.jpg'),
            (name: 'Badshah', img: 'https://c.saavncdn.com/artists/Badshah_150x150.jpg'),
          ];

    return ListView(
      controller: _verticalController,
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 120),
      children: [
        // ─── Header ───
        _DesktopHomeHeader(palette: palette, aiOn: aiOn, ref: ref),
        const SizedBox(height: 24),

        // ─── Genres Row ───
        _DesktopGenresRow(accentColor: palette.primary, parentController: _verticalController),
        const SizedBox(height: 28),

        // ─── Quick Picks (homeData first section) ───
        homeData.when(
          data: (sections) {
            if (sections.isEmpty) return const SizedBox.shrink();
            final first = sections.values.first;
            if (first.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: 'Quick Picks'),
                const SizedBox(height: 12),
                _QuickPicksGrid(songs: first.take(6).toList(), mt: mt, palette: palette),
                const SizedBox(height: 28),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.only(bottom: 28),
            child: CrystalShatterSkeleton(height: 120),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // ─── Continue Listening ───
        if (recent.isNotEmpty) ...[
          const _SectionHeader(title: 'Continue Listening'),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: DesktopScrollWrapper(
              parentController: _verticalController,
              builder: (context, controller, physics) => ListView.separated(
                controller: controller,
                physics: physics,
                scrollDirection: Axis.horizontal,
                itemCount: recent.take(12).length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) => _DesktopSongCard(song: recent[i], playlist: recent, mt: mt),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],

        // ─── Recommended for You ───
        if (suggestedSongs.isNotEmpty) ...[
          const _SectionHeader(title: 'Recommended for You'),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: DesktopScrollWrapper(
              parentController: _verticalController,
              builder: (context, controller, physics) => ListView.separated(
                controller: controller,
                physics: physics,
                scrollDirection: Axis.horizontal,
                itemCount: suggestedSongs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) => _DesktopSongCard(song: suggestedSongs[i], playlist: suggestedSongs, mt: mt),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],

        // ─── Top Artists ───
        const _SectionHeader(title: 'Top Artists'),
        const SizedBox(height: 14),
        SizedBox(
          height: 130,
          child: DesktopScrollWrapper(
            parentController: _verticalController,
            builder: (context, controller, physics) => ListView.separated(
              controller: controller,
              physics: physics,
              scrollDirection: Axis.horizontal,
              itemCount: topArtists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 20),
              itemBuilder: (context, i) {
                final artist = topArtists[i];
                return _DesktopArtistChip(
                  name: artist.name,
                  img: artist.img,
                  onTap: () => context.push('/artist/${artist.name}', extra: {
                    'name': artist.name,
                    'image': artist.img,
                  }),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ─── Indian Top Hits (reused from Android) ───
        IndianTopHitsBox(mt: mt),
        const SizedBox(height: 28),

        // ─── Home API Sections ───
        homeData.when(
          data: (sections) {
            final filtered = sections.entries.where((e) {
              final key = e.key.toLowerCase();
              return key != 'new releases' && key != 'top hits' && key != 'weekly top songs';
            }).toList();
            if (filtered.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: filtered.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: entry.key),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 230,
                    child: DesktopScrollWrapper(
                      parentController: _verticalController,
                      builder: (context, controller, physics) => ListView.separated(
                        controller: controller,
                        physics: physics,
                        scrollDirection: Axis.horizontal,
                        itemCount: entry.value.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (_, i) => _DesktopSongCard(song: entry.value[i], playlist: entry.value, mt: mt),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              )).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: CrystalShatterSkeleton(height: 140),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // ─── New Releases (reused from Android) ───
        DesktopScrollWrapper(
          parentController: _verticalController,
          builder: (context, controller, physics) => NewReleasesBox(
            mt: mt,
            controller: controller,
            physics: physics,
          ),
        ),
        const SizedBox(height: 28),

        // ─── Popular Albums (reused from Android) ───
        DesktopScrollWrapper(
          parentController: _verticalController,
          builder: (context, controller, physics) => PopularAlbumsSection(
            mt: mt,
            controller: controller,
            physics: physics,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Header ───
class _DesktopHomeHeader extends StatelessWidget {
  const _DesktopHomeHeader({required this.palette, required this.aiOn, required this.ref});
  final DynamicPalette palette;
  final bool aiOn;
  final WidgetRef ref;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = StorageService().profileName;
    return Row(
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
                  name.isNotEmpty ? '${_greeting()}, $name 👋' : _greeting(),
                  style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your personal music universe',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.45), letterSpacing: 0.3),
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
              Icon(Icons.auto_awesome_rounded, size: 15,
                  color: aiOn ? palette.primary : Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 7),
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
    );
  }
}

// ─── Section Header ───
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

// ─── Artist Chip ───
class _DesktopArtistChip extends StatefulWidget {
  const _DesktopArtistChip({required this.name, required this.img, required this.onTap});
  final String name;
  final String img;
  final VoidCallback onTap;

  @override
  State<_DesktopArtistChip> createState() => _DesktopArtistChipState();
}

class _DesktopArtistChipState extends State<_DesktopArtistChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _hovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hovered ? const Color(0xFFFA2D48).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15),
                    width: 2,
                  ),
                  boxShadow: _hovered
                      ? [BoxShadow(color: const Color(0xFFFA2D48).withValues(alpha: 0.3), blurRadius: 16)]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: CachedNetworkImage(
                    imageUrl: widget.img,
                    width: 80, height: 80,
                    fit: BoxFit.cover,
                    memCacheWidth: 160,
                    placeholder: (_, __) => Container(color: Colors.white10),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.white10,
                      child: Center(
                        child: Text(
                          widget.name.isNotEmpty ? widget.name[0] : '?',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                child: Text(
                  widget.name,
                  style: GoogleFonts.inter(
                    color: _hovered ? Colors.white : Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
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
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
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

/// Desktop song card — liquid glass border, glow, hover lift
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
          } catch (_) {}
        },
        onSecondaryTapDown: (_) => showSongOptionsSheet(context, ref, widget.song),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: _hovered ? Matrix4.translationValues(0, -6, 0) : Matrix4.identity(),
          child: SizedBox(
            width: 170,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                          width: 170, height: 160,
                          fit: BoxFit.cover,
                          memCacheWidth: 340,
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
                Text(
                  widget.song.title,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  widget.song.artist,
                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, height: 1.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Genres row
class _DesktopGenresRow extends StatelessWidget {
  const _DesktopGenresRow({required this.accentColor, required this.parentController});
  final Color accentColor;
  final ScrollController parentController;

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
          child: DesktopScrollWrapper(
            parentController: parentController,
            builder: (context, controller, physics) => ListView.separated(
              controller: controller,
              physics: physics,
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
                        width: 10, height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: item.$2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.$1,
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

void navigateToArtist(BuildContext context, WidgetRef ref, String artistName) {
  context.push('/artist/$artistName', extra: {'name': artistName, 'image': ''});
}

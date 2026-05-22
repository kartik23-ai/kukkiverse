import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/song_model.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';
import '../../utils/play_song.dart';
import '../../widgets/song_options_sheet.dart';
import '../../widgets/desktop_song_row.dart';

/// ═══════════════════════════════════════════════════════════════
/// Desktop Search — Wide layout with multi-column results
/// ═══════════════════════════════════════════════════════════════
class DesktopSearch extends ConsumerWidget {
  const DesktopSearch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(debouncedSearchQueryProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: TextField(
                  onChanged: (v) => ref.read(searchInputProvider.notifier).update(v),
                  onSubmitted: (v) => ref.read(searchInputProvider.notifier).submit(v),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'What do you want to listen to?',
                    hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Results
        Expanded(
          child: query.isEmpty
              ? _EmptyState(accent: palette.primary)
              : _SearchResults(query: query),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            'Search for songs, albums, or artists',
            style: GoogleFonts.inter(color: Colors.white30, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(searchSongsProvider(query));
    final albums = ref.watch(searchAlbumsProvider(query));
    final artists = ref.watch(searchArtistsProvider(query));

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
      children: [
        // Songs
        songs.when(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Songs'),
                ...list.take(8).map((song) => DesktopSongRow(song: song, playlist: list)),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: LinearProgressIndicator(color: AppColors.accent, minHeight: 2),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 24),

        // Albums
        albums.when(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Albums'),
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, i) => _AlbumCard(album: list[i]),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 24),

        // Artists
        artists.when(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Artists'),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, i) => _ArtistCard(artist: list[i]),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      );
}

class _AlbumCard extends StatefulWidget {
  const _AlbumCard({required this.album});
  final dynamic album;

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        transform: _hovered ? Matrix4.translationValues(0, -3, 0) : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.album.image ?? '',
                  width: 160, fit: BoxFit.cover,
                  memCacheWidth: 320,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(widget.album.name ?? '',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ArtistCard extends StatefulWidget {
  const _ArtistCard({required this.artist});
  final dynamic artist;

  @override
  State<_ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<_ArtistCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        transform: _hovered ? Matrix4.translationValues(0, -3, 0) : Matrix4.identity(),
        child: Column(
          children: [
            Expanded(
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: widget.artist.image ?? '',
                  width: 120, height: 120,
                  fit: BoxFit.cover,
                  memCacheWidth: 240,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(widget.artist.name ?? '',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Artist',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white30)),
          ],
        ),
      ),
    );
  }
}

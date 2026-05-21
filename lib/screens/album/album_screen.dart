import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../models/song_model.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../utils/play_song.dart';
import '../../widgets/album_stage_3d.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({
    super.key,
    required this.albumId,
    required this.title,
    this.songs,
    this.image,
  });

  final String albumId;
  final String title;
  final List<SongModel>? songs;
  final String? image;

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  bool _playAllWave = false;

  @override
  Widget build(BuildContext context) {
    final cached = widget.songs;
    final asyncSongs = ref.watch(albumSongsProvider(widget.albumId));
    final list = cached ?? asyncSongs.valueOrNull ?? [];
    final img = widget.image ?? (list.isNotEmpty ? list.first.image : '');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (img.isNotEmpty)
                    Hero(
                      tag: 'album_hero_${widget.albumId}',
                      child: CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
                    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.bg.withValues(alpha: 0.98)],
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 56),
                        if (img.isNotEmpty)
                          AlbumStage3D(imageUrl: img, heroTag: 'album_hero_${widget.albumId}', size: 160),
                        const SizedBox(height: 16),
                        Text(widget.title, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .slideY(begin: 0.2, end: 0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text('${list.length} songs', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  const Spacer(),
                  if (list.isNotEmpty)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: () async {
                        setState(() => _playAllWave = true);
                        for (var i = 0; i < list.length && i < 5; i++) {
                          await Future.delayed(const Duration(milliseconds: 120));
                        }
                        await playSongWithContext(ref, list.first, playlist: list);
                        if (mounted) context.push('/player');
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(_playAllWave ? 'Starting…' : 'Play All'),
                    ),
                ],
              ),
            ),
          ),
          if (cached == null && asyncSongs.isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
          else if (list.isEmpty)
            SliverFillRemaining(child: Center(child: Text('No songs found', style: GoogleFonts.inter(color: AppColors.textTertiary))))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final song = list[i];
                  return ListTile(
                    leading: Text('${i + 1}', style: GoogleFonts.inter(color: _playAllWave && i < 3 ? AppColors.accent : AppColors.textTertiary)),
                    title: Text(song.title, style: GoogleFonts.inter(color: Colors.white)),
                    subtitle: Text(song.artist, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                    onTap: () async {
                      await playSongWithContext(ref, song, playlist: list);
                      if (context.mounted) context.push('/player');
                    },
                  )
                      .animate()
                      .fadeIn(delay: (50 * i).ms)
                      .slideX(begin: 0.05, end: 0);
                },
                childCount: list.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

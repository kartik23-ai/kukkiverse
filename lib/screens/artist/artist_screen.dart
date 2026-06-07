import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../utils/play_song.dart';
import '../../widgets/album_stage_3d.dart';
import '../../widgets/rotty_glass.dart';
import '../../widgets/rotty_glow_r_skeleton.dart';
import '../../widgets/elite_background.dart';

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.artistId, this.name, this.image});

  final String artistId;
  final String? name;
  final String? image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(artistDetailProvider(artistId));
    final isWindows = Theme.of(context).platform == TargetPlatform.windows;

    final scaffold = Scaffold(
      backgroundColor: isWindows ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor,
      body: data.when(
        data: (d) {
          final artist = d.artist;
          final title = artist?.name ?? name ?? 'Artist';
          final img = artist?.image ?? image ?? '';
          final similar = d.songs.length > 3 ? d.songs.sublist(1, d.songs.length > 6 ? 6 : d.songs.length) : d.songs;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 300,
                    pinned: true,
                    backgroundColor: isWindows ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (img.isNotEmpty) CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, memCacheWidth: 800),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  isWindows
                                      ? Colors.black.withValues(alpha: 0.75)
                                      : Theme.of(context).scaffoldBackgroundColor
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 48),
                                if (img.isNotEmpty)
                                  AlbumStage3D(imageUrl: img, heroTag: 'artist_$artistId', size: 140)
                                else
                                  const CircleAvatar(radius: 56, child: Icon(Icons.person, size: 48)),
                                const SizedBox(height: 12),
                                Text(title, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                                if (d.listeners != null)
                                  Text('${d.listeners} Monthly Listeners', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500))
                                else
                                  Text('Artist Universe', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 12, letterSpacing: 1)),
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
                      child: Column(
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(52)),
                            onPressed: () async {
                              if (d.songs.isEmpty) return;
                              await playSongWithContext(ref, d.songs.first, playlist: d.songs, isPlayAll: true);
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play like this artist'),
                          ),
                          const SizedBox(height: 12),
                          if (d.bio != null && d.bio!.trim().isNotEmpty) ...[
                            RottyGlass(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('AI BIOGRAPHY', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                  const SizedBox(height: 6),
                                  Text(
                                    _shortenBio(d.bio!),
                                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (similar.isNotEmpty)
                            RottyGlass(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Similar vibe', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Text(similar.map((s) => s.title).take(3).join(' • '), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12), maxLines: 2),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Text('Top Tracks', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final s = d.songs[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(imageUrl: s.image, width: 48, height: 48, fit: BoxFit.cover),
                          ),
                          title: Text(s.title, style: GoogleFonts.inter(color: Colors.white)),
                          subtitle: Text(s.artist, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                          onTap: () async {
                            await playSongWithContext(ref, s, playlist: d.songs);
                          },
                        );
                      },
                      childCount: d.songs.length,
                    ),
                  ),
                  if (d.albums.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Text('Albums', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 196,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: d.albums.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, i) {
                            final a = d.albums[i];
                            return GestureDetector(
                              onTap: () => context.push('/album/${a.id}', extra: {'title': a.name, 'image': a.image}),
                              child: SizedBox(
                                width: 140,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(imageUrl: a.image, width: 140, height: 132, fit: BoxFit.cover),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(a.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.2)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          );
        },
        loading: () => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 48),
                Center(
                  child: RottyGlowRSkeleton(width: 140, height: 140),
                ),
                const SizedBox(height: 24),
                RottyGlowRSkeleton.list(height: 52),
                const SizedBox(height: 20),
                RottyGlowRSkeleton.list(height: 72),
                const SizedBox(height: 20),
                RottyGlowRSkeleton.list(height: 72),
                const SizedBox(height: 20),
                RottyGlowRSkeleton.list(height: 72),
              ],
            ),
          ),
        ),
        error: (_, __) => Center(child: Text('Failed to load artist', style: GoogleFonts.inter(color: AppColors.textTertiary))),
      ),
    );

    if (isWindows) {
      return RottyDynamicAuroraBackground(
        intensity: 0.8,
        child: scaffold,
      );
    }
    return scaffold;
  }
}

String _shortenBio(String bio) {
  var clean = bio.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  clean = clean.replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#039;', "'");
  if (clean.length <= 180) return clean;
  final sentences = clean.split(RegExp(r'(?<=[.!?])\s+'));
  if (sentences.length > 2) {
    final shortBio = '${sentences[0]} ${sentences[1]}';
    if (shortBio.length > 250) {
      return '${shortBio.substring(0, 247).trim()}...';
    }
    return shortBio;
  }
  return clean.length > 250 ? '${clean.substring(0, 247).trim()}...' : clean;
}

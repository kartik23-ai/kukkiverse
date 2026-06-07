import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/feature_providers.dart';
import '../../utils/play_song.dart';
import '../../widgets/rotty_glass.dart';

class ScenesScreen extends ConsumerWidget {
  const ScenesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Scenes', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: DiscoverScene.values.map((scene) {
          final songs = ref.watch(sceneSongsProvider(scene));
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () => context.push('/scene/${scene.name}', extra: scene),
              child: RottyGlass(
                tint: AppColors.accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(scene.icon, color: AppColors.accent, size: 28),
                        const SizedBox(width: 12),
                        Text(scene.title, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    songs.when(
                      data: (list) => SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: list.take(6).length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final s = list[i];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(imageUrl: s.image, width: 100, height: 100, fit: BoxFit.cover),
                            );
                          },
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(color: AppColors.accent),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SceneDetailScreen extends ConsumerWidget {
  const SceneDetailScreen({super.key, required this.scene});

  final DiscoverScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(sceneSongsProvider(scene));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: songs.when(
        data: (list) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(scene.title, style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent.withValues(alpha: 0.4), AppColors.bg],
                    ),
                  ),
                  child: Center(child: Icon(scene.icon, size: 64, color: Colors.white54)),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final s = list[i];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(imageUrl: s.image, width: 48, height: 48, fit: BoxFit.cover),
                    ),
                    title: Text(s.title, style: GoogleFonts.inter(color: Colors.white)),
                    subtitle: Text(s.artist, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                    onTap: () async {
                      await playSongWithContext(ref, s, playlist: list);
                    },
                  );
                },
                childCount: list.length,
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (_, __) => const Center(child: Text('Could not load scene')),
      ),
    );
  }
}

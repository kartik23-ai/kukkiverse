import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../models/song_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../utils/play_song.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key});

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider);
    final favorites = ref.watch(favoritesProvider);
    final recent = ref.watch(recentSongsProvider);

    return AppScaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Library', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: AppColors.accent),
                    onPressed: () => _createPlaylist(),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _chip('Playlists', 0),
                  const SizedBox(width: 8),
                  _chip('Liked', 1),
                  const SizedBox(width: 8),
                  _chip('Recent', 2),
                ],
              ),
            ),
          ),
          if (_tab == 0) ...[
            SliverToBoxAdapter(child: _row(Icons.favorite_rounded, AppColors.accent, 'Liked Songs', '${favorites.length} songs', () => setState(() => _tab = 1))),
            SliverToBoxAdapter(child: _row(Icons.history_rounded, AppColors.accentAlt, 'Recently Played', '${recent.length} songs', () => setState(() => _tab = 2))),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final p = playlists[i];
                  return _row(Icons.queue_music_rounded, AppColors.bgCard, p.name, '${p.songs.length} songs', () => context.push('/album/${p.id}', extra: {'title': p.name, 'songs': p.songs}));
                },
                childCount: playlists.length,
              ),
            ),
          ],
          if (_tab == 1) _songs(favorites),
          if (_tab == 2) _songs(recent),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _chip(String label, int i) {
    final sel = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.accent.withValues(alpha: 0.2) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.inter(color: sel ? AppColors.accent : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _row(IconData icon, Color color, String title, String sub, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
    );
  }

  Widget _songs(List<SongModel> songs) {
    if (songs.isEmpty) {
      return SliverFillRemaining(child: Center(child: Text('Empty', style: GoogleFonts.inter(color: AppColors.textTertiary))));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final s = songs[i];
          return ListTile(
            onTap: () async {
              await playSongWithContext(ref, s, playlist: songs);
              if (context.mounted) context.push('/player');
            },
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(s.image, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 48, color: AppColors.bgCard)),
            ),
            title: Text(s.title, style: GoogleFonts.inter(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(s.artist, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
          );
        },
        childCount: songs.length,
      ),
    );
  }

  Future<void> _createPlaylist() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Name', hintStyle: TextStyle(color: Colors.white38))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await ref.read(playlistsProvider.notifier).create(name);
  }
}

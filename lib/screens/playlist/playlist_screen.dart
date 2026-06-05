import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../models/song_model.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/song_options_sheet.dart';
import '../../utils/play_song.dart';
import '../../services/spotify_service.dart';


class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider).where((p) => !p.isPrivate).toList();
    final favorites = ref.watch(favoritesProvider);
    final recent = ref.watch(recentSongsProvider);
    final downloaded = ref.watch(downloadedSongsProvider);
    final studioCreations = ref.watch(studioCreationsProvider);

    final body = CustomScrollView(
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
                    onPressed: _showAddOptions,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('Playlists', 0),
                    const SizedBox(width: 8),
                    _chip('My Creations', 4),
                    const SizedBox(width: 8),
                    _chip('Liked', 1),
                    const SizedBox(width: 8),
                    _chip('Recent', 2),
                    const SizedBox(width: 8),
                    _chip('Downloaded', 3),
                  ],
                ),
              ),
            ),
          ),
          if (_tab == 0) ...[
            SliverToBoxAdapter(child: _row(Icons.auto_awesome_rounded, Colors.purple, 'My Creations', '${studioCreations.length} tracks', () => setState(() => _tab = 4))),
            SliverToBoxAdapter(child: _row(Icons.favorite_rounded, AppColors.accent, 'Liked Songs', '${favorites.length} songs', () => setState(() => _tab = 1))),
            SliverToBoxAdapter(child: _row(Icons.history_rounded, AppColors.accentAlt, 'Recently Played', '${recent.length} songs', () => setState(() => _tab = 2))),
            SliverToBoxAdapter(child: _row(Icons.download_done_rounded, Colors.green, 'Downloaded Songs', '${downloaded.length} songs', () => setState(() => _tab = 3))),
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
          if (_tab == 3) _songs(downloaded),
          if (_tab == 4) _songs(studioCreations),
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
    );

    if (widget.embedded) {
      return SafeArea(
        bottom: false,
        child: body,
      );
    }
    return AppScaffold(bottomPadding: 150, body: body);
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
    final currentSong = ref.watch(nowPlayingProvider);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final s = songs[i];
          return SongTile(
            song: s,
            isPlaying: currentSong?.id == s.id,
            onTap: () async {
              await playSongWithContext(ref, s, playlist: songs);
              if (context.mounted) context.push('/player');
            },
            onMore: () => showSongOptionsSheet(context, ref, s),
          );
        },
        childCount: songs.length,
      ),
    );
  }

  Future<void> _createPlaylist({bool isPrivate = false}) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(isPrivate ? 'New Secure Vault Playlist' : 'New Playlist', style: const TextStyle(color: Colors.white)),
        content: TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Name', hintStyle: TextStyle(color: Colors.white38))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(playlistsProvider.notifier).create(name, isPrivate: isPrivate);
      if (mounted && isPrivate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.amber,
            content: Text('Secure playlist created and hidden in Vault', style: TextStyle(color: Colors.white)),
          ),
        );
      }
    }
  }

  Future<void> _showAddOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Library Actions',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded, color: AppColors.accent),
                  title: Text('Create Normal Playlist', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Create a blank local playlist', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    _createPlaylist();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_rounded, color: Colors.amber),
                  title: Text('Create Private Vault Playlist', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Hidden and protected behind your PIN', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    _createPlaylist(isPrivate: true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sync_rounded, color: Color(0xFF1DB954)),
                  title: Text('Sync Spotify Playlist', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Import public Spotify playlist tracks', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    _syncSpotifyPlaylist();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _syncSpotifyPlaylist() async {
    final c = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.sync_rounded, color: Color(0xFF1DB954)),
                  const SizedBox(width: 10),
                  Text('Spotify Sync', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Paste a public Spotify playlist URL below. Make sure Client Credentials are configured in Settings.',
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                      ),
                    )
                  else
                    TextField(
                      controller: c,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'https://open.spotify.com/playlist/...',
                        hintStyle: GoogleFonts.inter(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.03),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                if (!isLoading) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final url = c.text.trim();
                      if (url.isEmpty) return;
                      setDialogState(() {
                        isLoading = true;
                      });
                      try {
                        final spotifyService = SpotifyService();
                        final playlist = await spotifyService.syncPlaylist(url);
                        
                        await ref.read(playlistsProvider.notifier).saveSyncedPlaylist(playlist);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Successfully synced "${playlist.name}" (${playlist.songs.length} tracks)'),
                            ),
                          );
                        }
                        Navigator.pop(ctx);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                            ),
                          );
                        }
                        setDialogState(() {
                          isLoading = false;
                        });
                      }
                    },
                    child: Text('Sync', style: GoogleFonts.inter(color: const Color(0xFF1DB954), fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

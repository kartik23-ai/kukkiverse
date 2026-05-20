import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../models/song_model.dart';
import '../providers/providers.dart';

/// Shows a premium bottom sheet with queue management options.
void showSongOptionsSheet(BuildContext context, WidgetRef ref, SongModel song) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _SongOptionsSheet(song: song),
  );
}

class _SongOptionsSheet extends ConsumerWidget {
  const _SongOptionsSheet({required this.song});
  final SongModel song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final playlists = ref.watch(playlistsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0x33FFFFFF), width: 0.5),
          left: BorderSide(color: Color(0x33FFFFFF), width: 0.5),
          right: BorderSide(color: Color(0x33FFFFFF), width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Song info header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: song.image,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      memCacheWidth: 112,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.glassBorder, height: 1),
            // Play Next
            _OptionTile(
              icon: Icons.playlist_play_rounded,
              label: 'Play Next',
              subtitle: 'Add after current song',
              color: AppColors.accent,
              onTap: () {
                handler.addToQueueNext(song);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playing "${song.title}" next'),
                    backgroundColor: const Color(0xFF1A1A2E),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            // Add to Queue
            _OptionTile(
              icon: Icons.queue_music_rounded,
              label: 'Add to Queue',
              subtitle: 'Play after all queued songs',
              color: const Color(0xFF7B61FF),
              onTap: () {
                handler.appendUpcoming([song]);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added "${song.title}" to queue'),
                    backgroundColor: const Color(0xFF1A1A2E),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            // Add to Playlist
            _OptionTile(
              icon: Icons.playlist_add_rounded,
              label: 'Add to Playlist',
              subtitle: '${playlists.length} playlists',
              color: const Color(0xFF00D4FF),
              onTap: () {
                Navigator.pop(context);
                _showPlaylistPicker(context, ref, song);
              },
            ),
            // Add to Favorites
            _OptionTile(
              icon: ref.read(favoritesProvider.notifier).isFavorite(song.id)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: ref.read(favoritesProvider.notifier).isFavorite(song.id)
                  ? 'Remove from Favorites'
                  : 'Add to Favorites',
              subtitle: 'Your liked songs',
              color: const Color(0xFFFF2D95),
              onTap: () {
                ref.read(favoritesProvider.notifier).toggle(song);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showPlaylistPicker(BuildContext context, WidgetRef ref, SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, watchRef, _) {
          final playlists = watchRef.watch(playlistsProvider);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Text('Add to Playlist', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCreatePlaylist(context, ref, song);
                        },
                      ),
                    ],
                  ),
                ),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No playlists yet', style: GoogleFonts.inter(color: AppColors.textTertiary)),
                  )
                else
                  ...playlists.map((p) => ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: AppColors.accentGradient,
                          ),
                          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 22),
                        ),
                        title: Text(p.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text('${p.songs.length} songs', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                        onTap: () async {
                          await watchRef.read(playlistsProvider.notifier).addToPlaylist(p.id, song);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added to "${p.name}"'),
                                backgroundColor: const Color(0xFF1A1A2E),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      )),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreatePlaylist(BuildContext context, WidgetRef ref, SongModel song) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New Playlist', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: GoogleFonts.inter(color: AppColors.textTertiary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.5))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ref.read(playlistsProvider.notifier).create(controller.text.trim());
                final playlists = ref.read(playlistsProvider);
                if (playlists.isNotEmpty) {
                  await ref.read(playlistsProvider.notifier).addToPlaylist(playlists.last.id, song);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text('Create & Add', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

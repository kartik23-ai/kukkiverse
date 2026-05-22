import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../models/song_model.dart';
import '../providers/providers.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Shows a premium bottom sheet with queue management options.
void showSongOptionsSheet(BuildContext context, WidgetRef ref, SongModel song) {
  final p = Theme.of(context).platform;
  final isDesktop = !kIsWeb && (p == TargetPlatform.windows || p == TargetPlatform.macOS || p == TargetPlatform.linux);

  if (isDesktop) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _SongOptionsDialog(song: song),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SongOptionsSheet(song: song),
    );
  }
}

class _SongOptionsSheet extends ConsumerWidget {
  const _SongOptionsSheet({required this.song});
  final SongModel song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final playlists = ref.watch(playlistsProvider).where((p) => !p.isPrivate).toList();

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
          final playlists = watchRef.watch(playlistsProvider).where((p) => !p.isPrivate).toList();
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
                  ...playlists.map((p) {
                    final isPrivate = p.isPrivate;
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: isPrivate
                              ? const LinearGradient(colors: [Colors.amber, Colors.orange])
                              : AppColors.accentGradient,
                        ),
                        child: Icon(
                          isPrivate ? Icons.lock_outline_rounded : Icons.music_note_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(p.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                          if (isPrivate) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.lock_rounded, color: Colors.amber, size: 14),
                          ],
                        ],
                      ),
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
                    );
                  }),
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
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final newId = await ref.read(playlistsProvider.notifier).create(name);
                await ref.read(playlistsProvider.notifier).addToPlaylist(newId, song);
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

class _SongOptionsDialog extends ConsumerWidget {
  const _SongOptionsDialog({required this.song});
  final SongModel song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final playlists = ref.watch(playlistsProvider).where((p) => !p.isPrivate).toList();
    final isFav = ref.watch(favoritesProvider.select((f) => f.any((s) => s.id == song.id)));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16162A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            spreadRadius: 4,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / Song info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: song.image,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    memCacheWidth: 128,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 4),
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
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Options
          _OptionTile(
            icon: Icons.playlist_play_rounded,
            label: 'Play Next',
            subtitle: 'Add after current song',
            color: AppColors.accent,
            onTap: () {
              handler.addToQueueNext(song);
              Navigator.pop(context);
              _showSnackBar(context, 'Playing "${song.title}" next');
            },
          ),
          _OptionTile(
            icon: Icons.queue_music_rounded,
            label: 'Add to Queue',
            subtitle: 'Play after all queued songs',
            color: const Color(0xFF7B61FF),
            onTap: () {
              handler.appendUpcoming([song]);
              Navigator.pop(context);
              _showSnackBar(context, 'Added "${song.title}" to queue');
            },
          ),
          _OptionTile(
            icon: Icons.playlist_add_rounded,
            label: 'Add to Playlist',
            subtitle: '${playlists.length} playlists',
            color: const Color(0xFF00D4FF),
            onTap: () {
              Navigator.pop(context);
              _showDesktopPlaylistPicker(context, ref, song);
            },
          ),
          _OptionTile(
            icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: isFav ? 'Remove from Favorites' : 'Add to Favorites',
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
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF16162A),
        behavior: SnackBarBehavior.floating,
        width: 320,
      ),
    );
  }
}

void _showDesktopPlaylistPicker(BuildContext context, WidgetRef ref, SongModel song) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16162A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Consumer(
            builder: (context, watchRef, _) {
              final playlists = watchRef.watch(playlistsProvider).where((p) => !p.isPrivate).toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
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
                            _showDesktopCreatePlaylist(context, ref, song);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  if (playlists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text('No playlists yet', style: GoogleFonts.inter(color: AppColors.textTertiary)),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: playlists.map((p) {
                          final isPrivate = p.isPrivate;
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: isPrivate
                                    ? const LinearGradient(colors: [Colors.amber, Colors.orange])
                                    : AppColors.accentGradient,
                              ),
                              child: Icon(
                                isPrivate ? Icons.lock_outline_rounded : Icons.music_note_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(p.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                                if (isPrivate) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.lock_rounded, color: Colors.amber, size: 14),
                                ],
                              ],
                            ),
                            subtitle: Text('${p.songs.length} songs', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                            onTap: () async {
                              await watchRef.read(playlistsProvider.notifier).addToPlaylist(p.id, song);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added to "${p.name}"'),
                                    backgroundColor: const Color(0xFF16162A),
                                    behavior: SnackBarBehavior.floating,
                                    width: 320,
                                  ),
                                );
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

void _showDesktopCreatePlaylist(BuildContext context, WidgetRef ref, SongModel song) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF16162A),
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
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              final newId = await ref.read(playlistsProvider.notifier).create(name);
              await ref.read(playlistsProvider.notifier).addToPlaylist(newId, song);
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
          child: Text('Create & Add', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

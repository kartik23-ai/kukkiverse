import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/providers.dart';
import '../../providers/feature_providers.dart';
import '../../widgets/live_karaoke_lyrics.dart';
import '../../models/lyrics_line.dart';
import '../../models/song_model.dart';
import '../../services/audio_handler.dart';

/// ═══════════════════════════════════════════════════════════════
/// Desktop Now Playing Panel 4.0 — Premium Segmented Panel
/// Translucent, dynamic tab switcher: Live Lyrics vs Up Next Queue
/// Reorderable queue, click to play/delete, and hover buttons
/// ═══════════════════════════════════════════════════════════════
class DesktopNowPlaying extends ConsumerStatefulWidget {
  const DesktopNowPlaying({super.key});

  @override
  ConsumerState<DesktopNowPlaying> createState() => _DesktopNowPlayingState();
}

class _DesktopNowPlayingState extends ConsumerState<DesktopNowPlaying> {
  bool _showQueue = false;

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(nowPlayingProvider);
    final palette = ref.watch(dynamicPaletteProvider);
    final handler = ref.read(audioHandlerProvider);

    return ClipRect(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
              border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: song == null ? _emptyState() : _songPanel(song, palette, handler),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_rounded, size: 48, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Text('No song playing', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _songPanel(SongModel song, dynamic palette, RottyAudioHandler handler) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 200) return const SizedBox.shrink();

        final artSize = (constraints.maxWidth - 40).clamp(100.0, 260.0);

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Text(
                    'NOW PLAYING',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.4), letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.primary,
                      boxShadow: [BoxShadow(color: (palette.primary as Color).withValues(alpha: 0.6), blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ),

            // Album art with glow
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (palette.primary as Color).withValues(alpha: 0.25),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: song.image,
                    width: artSize, height: artSize,
                    fit: BoxFit.cover,
                    memCacheWidth: 520,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Song info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artist,
                    style: GoogleFonts.inter(fontSize: 13, color: (palette.primary as Color).withValues(alpha: 0.8)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  if (song.album.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(song.album, style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.white.withValues(alpha: 0.1), Colors.transparent],
                  ),
                ),
              ),
            ),

            // Modern segment bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showQueue = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: !_showQueue
                                ? (palette.primary as Color).withValues(alpha: 0.15)
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              'Lyrics',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: !_showQueue ? FontWeight.w700 : FontWeight.w500,
                                color: !_showQueue ? Colors.white : Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showQueue = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: _showQueue
                                ? (palette.primary as Color).withValues(alpha: 0.15)
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              'Up Next',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: _showQueue ? FontWeight.w700 : FontWeight.w500,
                                color: _showQueue ? Colors.white : Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Lyrics OR Queue list
            Expanded(
              child: _showQueue
                  ? ValueListenableBuilder<int>(
                      valueListenable: handler.queueVersion,
                      builder: (context, _, __) {
                        final queue = handler.songQueue;
                        if (queue.isEmpty) {
                          return Center(
                            child: Text(
                              'Queue is empty',
                              style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                            ),
                          );
                        }
                        return ReorderableListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: queue.length,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex -= 1;
                            handler.reorderQueue(oldIndex, newIndex);
                          },
                          itemBuilder: (context, idx) {
                            final qSong = queue[idx];
                            final isCurrent = idx == handler.currentIndex;
                            return _QueueTile(
                              key: ValueKey('queue_${qSong.id}_$idx'),
                              song: qSong,
                              isCurrent: isCurrent,
                              index: idx,
                              palette: palette,
                              handler: handler,
                            );
                          },
                        );
                      },
                    )
                  : Consumer(
                      builder: (context, ref, _) {
                        final lyrics = ref.watch(lyricsProvider(song.id));
                        return lyrics.when(
                          data: (text) {
                            if (text == null || text.trim().isEmpty) {
                              return Center(
                                child: Text('No lyrics available', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 12)),
                              );
                            }
                            final lines = parseLyricsToLines(text, song.duration);
                            final isSynced = text.contains(RegExp(r'\[\d+:\d{2}'));
                            return StreamBuilder<Duration>(
                              stream: handler.player.positionStream,
                              builder: (context, snap) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: LiveKaraokeLyrics(
                                    lines: lines,
                                    position: snap.data ?? Duration.zero,
                                    accent: palette.primary,
                                    maxHeight: constraints.maxHeight - artSize - 230,
                                    isSynced: isSynced,
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => Center(
                            child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: (palette.primary as Color).withValues(alpha: 0.3))),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _QueueTile extends StatefulWidget {
  const _QueueTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.index,
    required this.palette,
    required this.handler,
  });

  final SongModel song;
  final bool isCurrent;
  final int index;
  final dynamic palette;
  final RottyAudioHandler handler;

  @override
  State<_QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<_QueueTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: widget.isCurrent
              ? (widget.palette.primary as Color).withValues(alpha: 0.15)
              : _hovered
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
          border: Border.all(
            color: widget.isCurrent
                ? (widget.palette.primary as Color).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
            width: widget.isCurrent ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Drag handle / track number
            ReorderableDragStartListener(
              index: widget.index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Cover Art
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: widget.song.image,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                memCacheWidth: 80,
              ),
            ),
            const SizedBox(width: 12),
            // Title & Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      if (widget.isCurrent) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'LIVE',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          widget.song.title,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: widget.isCurrent ? FontWeight.w700 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.song.artist,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Actions
            if (_hovered || widget.isCurrent)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QueueActionIcon(
                    icon: Icons.play_arrow_rounded,
                    tooltip: 'Play Now',
                    onTap: () => widget.handler.playSong(widget.song, index: widget.index),
                  ),
                  _QueueActionIcon(
                    icon: Icons.playlist_add_rounded,
                    tooltip: 'Add Next',
                    onTap: () => widget.handler.addToQueueNext(widget.song),
                  ),
                  _QueueActionIcon(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Remove',
                    color: Colors.red.withValues(alpha: 0.7),
                    onTap: () => widget.handler.removeFromQueue(widget.index),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _QueueActionIcon extends StatelessWidget {
  const _QueueActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(
              icon,
              size: 16,
              color: color ?? Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

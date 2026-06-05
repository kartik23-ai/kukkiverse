import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../models/song_model.dart';
import '../providers/providers.dart';
import '../widgets/song_options_sheet.dart';
import '../utils/play_song.dart';

class DesktopSongRow extends ConsumerStatefulWidget {
  const DesktopSongRow({
    super.key,
    required this.song,
    required this.playlist,
  });

  final SongModel song;
  final List<SongModel> playlist;

  @override
  ConsumerState<DesktopSongRow> createState() => _DesktopSongRowState();
}

class _DesktopSongRowState extends ConsumerState<DesktopSongRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(
      downloadNotifierProvider.select((states) => states[widget.song.id] ?? const DownloadState.none()),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => playSongWithContext(ref, widget.song, playlist: widget.playlist),
        onSecondaryTapDown: (_) => showSongOptionsSheet(context, ref, widget.song),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hovered ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: widget.song.image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.song.image,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        memCacheWidth: 88,
                        errorWidget: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: AppColors.bgElevated,
                          child: const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 20),
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        color: AppColors.bgElevated,
                        child: const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 20),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.song.title,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        navigateToArtist(context, ref, widget.song.artist);
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          widget.song.artist,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDuration(widget.song.duration),
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white24),
              ),
              const SizedBox(width: 12),
              _buildDesktopDownloadIcon(ref, downloadState, isHovered: _hovered),
              if (_hovered) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showSongOptionsSheet(context, ref, widget.song),
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.play_circle_filled_rounded, color: AppColors.accent, size: 22),
              ] else ...[
                const SizedBox(width: 44), // Adjusted: play (30px) + options (32px) - 18px (increased size of download button)
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDownloadIcon(WidgetRef ref, DownloadState state, {required bool isHovered}) {
    Widget iconWidget;
    String tooltipMessage = '';
    VoidCallback? onTapAction;

    switch (state.status) {
      case DownloadStatus.downloading:
        return SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Tooltip(
              message: 'Downloading ${(state.progress * 100).toStringAsFixed(0)}%',
              child: SizedBox(
                width: 18,
                height: 18,
                child: Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: CircularProgressIndicator(
                    value: state.progress,
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    backgroundColor: Colors.white10,
                  ),
                ),
              ),
            ),
          ),
        );
      case DownloadStatus.downloaded:
        iconWidget = const Icon(Icons.download_done_rounded, color: Colors.green, size: 18);
        tooltipMessage = 'Downloaded. Click to delete.';
        onTapAction = () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.bgElevated,
              title: const Text('Delete Download', style: TextStyle(color: Colors.white)),
              content: Text('Do you want to delete "${widget.song.title}" from offline storage?', style: const TextStyle(color: AppColors.textSecondary)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(downloadServiceProvider).deleteSong(widget.song.id);
                    Navigator.pop(context);
                  },
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        };
        break;
      case DownloadStatus.failed:
        iconWidget = const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18);
        tooltipMessage = 'Download failed. Click to retry.';
        onTapAction = () => ref.read(downloadServiceProvider).downloadSong(widget.song);
        break;
      case DownloadStatus.none:
      default:
        iconWidget = Icon(
          Icons.download_for_offline_outlined,
          color: isHovered ? Colors.white70 : Colors.white.withValues(alpha: 0.25),
          size: 18,
        );
        tooltipMessage = 'Download for offline';
        onTapAction = () => ref.read(downloadServiceProvider).downloadSong(widget.song);
        break;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapAction,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Tooltip(
              message: tooltipMessage,
              child: iconWidget,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

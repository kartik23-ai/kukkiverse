import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../utils/play_song.dart';
import '../../models/song_model.dart';
import '../../widgets/rotty_glass.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);

    return ValueListenableBuilder<int>(
      valueListenable: handler.queueVersion,
      builder: (context, _, __) {
        final queue = handler.songQueue;
        final history = handler.history;
        final currentIndex = handler.currentIndex;
        final upcoming = queue.skip(currentIndex + 1).toList();

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
              onPressed: () => context.pop(),
            ),
            title: Text('Queue Timeline', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: () async {
                  await refreshAiQueue(ref);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI refill added')));
                  }
                },
                child: Text('AI Refill', style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          body: queue.isEmpty
              ? Center(child: Text('Queue is empty', style: GoogleFonts.inter(color: AppColors.textTertiary)))
              : CustomScrollView(
                  slivers: [
                    if (history.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                          child: Text('History', style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final song = history[i];
                            return _HistoryRow(song: song);
                          },
                          childCount: history.take(5).length,
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: RottyGlass(
                          tint: AppColors.accent,
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text('AI will refill when queue ends', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Now Playing Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text('Now Playing', style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: handler.currentSong == null
                          ? const SizedBox.shrink()
                          : _QueueTimelineRow(
                              key: ValueKey('now_playing_${handler.currentSong!.id}'),
                              song: handler.currentSong!,
                              index: currentIndex,
                              isNow: true,
                              onTap: () {},
                              onPlayNext: () {},
                              onRemove: () {},
                            ),
                    ),

                    // Next Up (Unified Queue)
                    if (upcoming.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                          child: Text('Next Up', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      SliverReorderableList(
                        itemCount: upcoming.length,
                        onReorder: (oldIdx, newIdx) {
                          final absOld = currentIndex + 1 + oldIdx;
                          final absNew = currentIndex + 1 + newIdx;
                          handler.reorderQueue(absOld, absNew);
                        },
                        itemBuilder: (context, index) {
                          final song = upcoming[index];
                          final absoluteIndex = currentIndex + 1 + index;
                          return _QueueTimelineRow(
                            key: ValueKey('upcoming_${song.id}'),
                            song: song,
                            index: index,
                            isNow: false,
                            onTap: () {
                              handler.playSong(song, index: absoluteIndex);
                            },
                            onPlayNext: () => handler.addToQueueNext(song),
                            onRemove: () => handler.removeFromQueue(absoluteIndex),
                          );
                        },
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.song});
  final SongModel song;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: ListTile(
        leading: Icon(Icons.history_rounded, color: AppColors.textTertiary.withValues(alpha: 0.7)),
        title: Text(song.title, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
        subtitle: Text(song.artist, style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11)),
      ),
    );
  }
}

class _QueueTimelineRow extends StatelessWidget {
  const _QueueTimelineRow({
    required super.key,
    required this.song,
    required this.index,
    required this.isNow,
    required this.onTap,
    required this.onPlayNext,
    required this.onRemove,
  });

  final SongModel song;
  final int index;
  final bool isNow;
  final VoidCallback onTap;
  final VoidCallback onPlayNext;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(
      index: index,
      child: RottyGlassLite(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        accentColor: isNow ? AppColors.accent : null,
        child: Row(
          children: [
            Column(
              children: [
                Container(width: 2, height: 12, color: isNow ? AppColors.accent : AppColors.glassBorder),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isNow ? AppColors.accent : AppColors.bgCard,
                    border: Border.all(color: isNow ? AppColors.accent : AppColors.glassBorder),
                  ),
                ),
                Container(width: 2, height: 12, color: AppColors.glassBorder),
              ],
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(imageUrl: song.image, width: 48, height: 48, fit: BoxFit.cover, memCacheWidth: 96),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: GoogleFonts.inter(color: isNow ? AppColors.accent : Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.artist, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (isNow)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('NOW', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            if (!isNow) ...[
              IconButton(icon: const Icon(Icons.playlist_add_rounded, color: Colors.white54, size: 20), onPressed: onPlayNext),
              IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20), onPressed: onRemove),
            ],
          ],
        ),
      ),
    );
  }
}

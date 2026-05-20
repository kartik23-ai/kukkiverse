import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../models/song_model.dart';
import '../providers/providers.dart';

void showPlayerStorySheet(BuildContext context, WidgetRef ref, SongModel song) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgElevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _StorySheet(song: song),
  );
}

class _StorySheet extends ConsumerWidget {
  const _StorySheet({required this.song});
  final SongModel song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Story', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(song.title, style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(song.artist, style: GoogleFonts.inter(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Text('Album • ${song.album}', style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 13)),
            const SizedBox(height: 16),
            FutureBuilder(
              future: ref.read(musicRepositoryProvider).searchSongs(song.artist, limit: 5),
              builder: (context, snap) {
                final list = snap.data ?? [];
                if (list.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('More like this', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Chip(
                          label: Text(list[i].title, style: const TextStyle(fontSize: 11)),
                          backgroundColor: AppColors.bgCard,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

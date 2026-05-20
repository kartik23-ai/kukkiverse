import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/feature_providers.dart';
import '../../models/song_model.dart';
import '../../utils/play_song.dart';
import '../../widgets/rotty_glass.dart';

class MemoryLaneScreen extends ConsumerWidget {
  const MemoryLaneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(playHistoryProvider);
    final onThisDay = ref.read(playHistoryProvider.notifier).onThisDay(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Memory Lane', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (onThisDay.isNotEmpty) ...[
            RottyGlass(
              tint: AppColors.accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Is din last year tumne ye suna tha', style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  ...onThisDay.take(5).map((e) => _memoryCard(context, ref, e.song, e.playedAt)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text('Recent memories', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 12),
          ...entries.take(30).map((e) => _memoryCard(context, ref, e.song, e.playedAt)),
          if (entries.isEmpty)
            Center(child: Text('Play songs to build memories', style: GoogleFonts.inter(color: AppColors.textTertiary))),
        ],
      ),
    );
  }

  Widget _memoryCard(BuildContext context, WidgetRef ref, SongModel song, DateTime when) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RottyGlass(
        onTap: () async {
          await playSongWithContext(ref, song);
          if (context.mounted) context.push('/player');
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(imageUrl: song.image, width: 56, height: 56, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(DateFormat('MMM d, yyyy • h:mm a').format(when), style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

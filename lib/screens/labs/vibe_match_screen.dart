import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../utils/play_song.dart';

class VibeMatchScreen extends ConsumerWidget {
  const VibeMatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(nowPlayingProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Vibe Match', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Build queue from current energy', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            if (current != null) ...[
              Text(current.title, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              Text(current.artist, style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ] else
              Text('Play a song first', style: GoogleFonts.inter(color: AppColors.textTertiary)),
            const Spacer(),
            FilledButton(
              onPressed: current == null
                  ? null
                  : () async {
                      final q = '${current.artist} ${current.album}';
                      final songs = await ref.read(musicRepositoryProvider).searchSongs(q, limit: 18);
                      if (songs.isEmpty || !context.mounted) return;
                      await playSongWithContext(ref, current, playlist: [current, ...songs.where((s) => s.id != current.id)], runAiDj: false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vibe queue ready')));
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(52)),
              child: const Text('Match vibe'),
            ),
          ],
        ),
      ),
    );
  }
}

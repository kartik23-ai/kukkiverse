import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../utils/play_song.dart';

class TimeMachineScreen extends ConsumerWidget {
  const TimeMachineScreen({super.key});

  static const _stations = [
    ('2016 College', '2016 hindi college romance'),
    ('2018 Party', '2018 party hindi punjabi'),
    ('2020 Lockdown', '2020 chill lofi hindi'),
    ('2022 Bollywood', '2022 bollywood hits'),
    ('Monsoon', 'monsoon hindi romantic'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Time Machine', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _stations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final s = _stations[i];
          return ListTile(
            tileColor: AppColors.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: const Icon(Icons.radio_rounded, color: AppColors.accent),
            title: Text(s.$1, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('Auto station', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
            trailing: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accent, size: 36),
            onTap: () async {
              final songs = await ref.read(musicRepositoryProvider).searchSongs(s.$2, limit: 20);
              if (songs.isEmpty || !context.mounted) return;
              await playSongWithContext(ref, songs.first, playlist: songs, runAiDj: true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.$1} station started')));
              }
            },
          );
        },
      ),
    );
  }
}

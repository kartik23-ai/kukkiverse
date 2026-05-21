import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../utils/play_song.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

class TimeMachineScreen extends ConsumerWidget {
  const TimeMachineScreen({super.key});

  static const _stations = [
    ('2016 College Classics', '2016 hindi college romance', '🎓', 'Nostalgic tracks from your dorm days'),
    ('2018 Dance Party', '2018 party hindi punjabi', '🔥', 'High-energy club bangers & dance anthems'),
    ('2020 Lockdown Chill', '2020 chill lofi hindi', '😷', 'Cozy bedroom beats & soothing melodies'),
    ('2022 Bollywood Hits', '2022 bollywood hits', '🎬', 'Chartbusters & blockbuster romantic tunes'),
    ('Monsoon Romance', 'monsoon hindi romantic', '🌧️', 'Melancholic drops & soft acoustic jams'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Time Machine',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 20),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: LiquidGlass(
              borderRadius: 24,
              surfaceOpacity: 0.08,
              borderOpacity: 0.15,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHOOSE YOUR ERA',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Travel back in time. Select a station to generate a localized stream.',
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _stations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final s = _stations[i];
                        return LiquidGlassCard(
                          accentColor: palette.primary,
                          borderRadius: 14,
                          padding: const EdgeInsets.all(16),
                          onTap: () async {
                            final songs = await ref.read(musicRepositoryProvider).searchSongs(s.$2, limit: 20);
                            if (songs.isEmpty || !context.mounted) return;
                            await playSongWithContext(ref, songs.first, playlist: songs, runAiDj: true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.bgElevated,
                                  content: Text('🎵 Launching ${s.$1} station...', style: const TextStyle(color: Colors.white)),
                                ),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: palette.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: palette.primary.withValues(alpha: 0.15)),
                                ),
                                child: Center(
                                  child: Text(
                                    s.$3,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.$1,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      s.$4,
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withValues(alpha: 0.45),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.play_circle_fill_rounded,
                                color: palette.primary,
                                size: 36,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

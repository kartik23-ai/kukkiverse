import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../utils/play_song.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

class VibeMatchScreen extends ConsumerWidget {
  const VibeMatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(nowPlayingProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Vibe Match',
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'GENERATE VIBE MIX',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Build a highly curated queue based on your current song\'s energetic signature.',
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                  const SizedBox(height: 36),
                  
                  Expanded(
                    child: Center(
                      child: current != null
                          ? _songActiveView(current, palette.primary)
                          : _noSongView(palette.primary),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  LiquidGlassButton(
                    accentColor: palette.primary,
                    isActive: current != null,
                    onTap: current == null
                        ? null
                        : () async {
                            final q = '${current.artist} ${current.album}';
                            final songs = await ref.read(musicRepositoryProvider).searchSongs(q, limit: 18);
                            if (songs.isEmpty || !context.mounted) return;
                            await playSongWithContext(
                              ref,
                              current,
                              playlist: [current, ...songs.where((s) => s.id != current.id)],
                              runAiDj: false,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.bgElevated,
                                  content: Text('⚡ Vibe mix populated with ${songs.length} similar tracks!', style: const TextStyle(color: Colors.white)),
                                ),
                              );
                            }
                          },
                    child: Center(
                      child: Text(
                        'MATCH VIBE INSTANTLY',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: current == null ? Colors.white24 : Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
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

  Widget _songActiveView(dynamic current, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing active aura art
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: DecorationImage(image: NetworkImage(current.image), fit: BoxFit.cover),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          current.title,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          current.artist,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, color: accent, size: 14),
              const SizedBox(width: 4),
              Text(
                'AURA SIGNATURE MATCH',
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noSongView(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Icon(Icons.music_off_rounded, color: Colors.white30, size: 28),
        ),
        const SizedBox(height: 18),
        Text(
          'Queue is Idle',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Start playing any song first to unlock high-fidelity Vibe Matching.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

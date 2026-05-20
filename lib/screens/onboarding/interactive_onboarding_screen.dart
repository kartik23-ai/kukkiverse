import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../services/storage_service.dart';
import '../../widgets/mood_orb.dart';
import '../../widgets/rotty_glass.dart';
import '../../widgets/album_stage_3d.dart';
import '../../widgets/live_karaoke_lyrics.dart';
import '../../models/lyrics_line.dart';
import '../../models/song_model.dart';
import '../../utils/play_song.dart';

/// ~90 sec interactive story — AI DJ, play, gestures, live lyrics.
class InteractiveOnboardingScreen extends ConsumerStatefulWidget {
  const InteractiveOnboardingScreen({super.key});

  @override
  ConsumerState<InteractiveOnboardingScreen> createState() => _InteractiveOnboardingScreenState();
}

class _InteractiveOnboardingScreenState extends ConsumerState<InteractiveOnboardingScreen> {
  int _step = 0;
  final _demoLines = const [
    LyricsLine(start: Duration.zero, text: 'Feel the beat drop'),
    LyricsLine(start: Duration(seconds: 3), text: 'ROTTY lights the night'),
    LyricsLine(start: Duration(seconds: 6), text: 'Your vibe, your queue'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              LinearProgressIndicator(value: (_step + 1) / 4, color: AppColors.accent, backgroundColor: Colors.white12),
              const SizedBox(height: 32),
              Expanded(child: _buildStep()),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                  onPressed: _next,
                  child: Text(_step < 3 ? 'Next' : 'Enter ROTTY', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MoodOrb(size: 140),
            const SizedBox(height: 24),
            Text('ROTTY AI DJ', style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            Text('Mood + time + taste = your queue', style: GoogleFonts.inter(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            RottyGlass(child: const Text('Tap Next to turn AI DJ on', style: TextStyle(color: Colors.white70))),
          ],
        );
      case 1:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Play a vibe', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final home = await ref.read(homeDataProvider.future);
                SongModel? first;
                for (final list in home.values) {
                  if (list.isNotEmpty) {
                    first = list.first;
                    break;
                  }
                }
                if (first != null) await playSongWithContext(ref, first);
              },
              child: const Text('Play demo track'),
            ),
            const SizedBox(height: 16),
            Text('Circle on art = repeat • Double tap = like', style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 12), textAlign: TextAlign.center),
          ],
        );
      case 2:
        final song = ref.watch(nowPlayingProvider);
        return Column(
          children: [
            Text('Gestures', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (song != null)
              AlbumStage3D(imageUrl: song.image, heroTag: 'onboard_${song.id}', size: 200)
            else
              const Icon(Icons.touch_app_rounded, size: 80, color: Colors.white38),
            const SizedBox(height: 12),
            Text('Swipe down art → mini player', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ],
        );
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Live lyrics', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            LiveKaraokeLyrics(
              lines: _demoLines,
              position: Duration(seconds: _step == 3 ? 4 : 0),
              accent: AppColors.accent,
            ),
          ],
        );
    }
  }

  Future<void> _next() async {
    if (_step == 0) ref.read(aiDjEnabledProvider.notifier).state = true;
    if (_step < 3) {
      setState(() => _step++);
    } else {
      await StorageService().setInteractiveOnboardingDone();
      await StorageService().setOnboardingDone();
      if (mounted) context.go('/home');
    }
  }
}

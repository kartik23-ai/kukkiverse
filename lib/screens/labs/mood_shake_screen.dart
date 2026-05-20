import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/haptics/music_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../utils/play_song.dart';

class MoodShakeScreen extends ConsumerStatefulWidget {
  const MoodShakeScreen({super.key});

  @override
  ConsumerState<MoodShakeScreen> createState() => _MoodShakeScreenState();
}

class _MoodShakeScreenState extends ConsumerState<MoodShakeScreen> {
  StreamSubscription<UserAccelerometerEvent>? _sub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;

  final _queries = ['party hindi', 'sad hindi', 'workout punjabi', 'chill lofi', 'romantic bollywood'];

  @override
  void initState() {
    super.initState();
    _sub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(_onAccel);
  }

  void _onAccel(UserAccelerometerEvent e) {
    final force = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (force < 18) return;
    final now = DateTime.now();
    if (now.difference(_lastShake).inMilliseconds < 1500) return;
    _lastShake = now;
    _surprise();
  }

  Future<void> _surprise() async {
    if (_busy) return;
    _busy = true;
    MusicHaptics.skip();
    HapticFeedback.heavyImpact();
    try {
      final q = _queries[Random().nextInt(_queries.length)];
      final songs = await ref.read(musicRepositoryProvider).searchSongs(q, limit: 15, page: 1 + Random().nextInt(3));
      if (songs.isEmpty || !mounted) return;
      final pick = songs[Random().nextInt(songs.length)];
      await playSongWithContext(ref, pick, playlist: songs, runAiDj: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎵 ${pick.title}')));
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Mood Shake', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.vibration_rounded, size: 80, color: AppColors.accent.withValues(alpha: 0.85)),
              const SizedBox(height: 24),
              Text('Shake your phone', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Random vibe song starts instantly', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _surprise,
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size(200, 48)),
                child: const Text('Surprise me'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/haptics/music_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../utils/play_song.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

class MoodShakeScreen extends ConsumerStatefulWidget {
  const MoodShakeScreen({super.key});

  @override
  ConsumerState<MoodShakeScreen> createState() => _MoodShakeScreenState();
}

class _MoodShakeScreenState extends ConsumerState<MoodShakeScreen> with SingleTickerProviderStateMixin {
  StreamSubscription<UserAccelerometerEvent>? _sub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;
  late AnimationController _pulseController;

  final _queries = ['party hindi', 'sad hindi', 'workout punjabi', 'chill lofi', 'romantic bollywood'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _sub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(_onAccel);
      } catch (_) {
        // Accelerometers not supported on this platform/desktop — ignore gracefully
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bgElevated,
            content: Text('⚡ Vibe Shuffled! Playing: ${pick.title}', style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Mood Shake',
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
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SHAKE & SURPRISE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shake your physical phone or click the trigger below to instantly match a random energetic vibration!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 48),
                  
                  // Interactive breathing device accelerometer visualization card
                  Center(
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1.03).animate(
                        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                      ),
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.primary.withValues(alpha: 0.06),
                          border: Border.all(color: palette.primary.withValues(alpha: 0.2), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primary.withValues(alpha: 0.25),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.vibration_rounded,
                            size: 48,
                            color: palette.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Trigger Button
                  LiquidGlassButton(
                    accentColor: palette.primary,
                    isActive: true,
                    onTap: _surprise,
                    child: Center(
                      child: Text(
                        'TRIGGER VIBE SHUFFLE',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.white,
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
}

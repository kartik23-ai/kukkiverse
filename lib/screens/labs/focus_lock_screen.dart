import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/feature_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

class FocusLockScreen extends ConsumerStatefulWidget {
  const FocusLockScreen({super.key});

  @override
  ConsumerState<FocusLockScreen> createState() => _FocusLockScreenState();
}

class _FocusLockScreenState extends ConsumerState<FocusLockScreen> {
  Timer? _timer;
  int _remaining = 0;
  bool _active = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start(int minutes) {
    _timer?.cancel();
    setState(() {
      _active = true;
      _remaining = minutes * 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _active = false;
          _remaining = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Focus session complete')));
        }
        return;
      }
      setState(() => _remaining--);
    });
  }

  String get _timeLabel {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final minutes = ref.watch(focusTimerMinutesProvider);
    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return PopScope(
      canPop: !_active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _active) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End focus to leave')));
        }
      },
      child: RottyDynamicAuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('Focus Lock', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'FLOW STATE TIMER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: palette.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Locks your screen and streams focus-forward playlists to block distractions.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                    const SizedBox(height: 32),
                    
                    if (_active)
                      Text(
                        _timeLabel,
                        style: GoogleFonts.inter(
                          color: palette.primary,
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          shadows: [
                            BoxShadow(color: palette.primary.withValues(alpha: 0.4), blurRadius: 30),
                          ],
                        ),
                      )
                    else
                      Text(
                        '$minutes min',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Simple Slider to change duration if inactive
                    if (!_active) ...[
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: palette.primary,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                          thumbColor: Colors.white,
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: minutes.toDouble(),
                          min: 5,
                          max: 60,
                          divisions: 11,
                          onChanged: (v) => ref.read(focusTimerMinutesProvider.notifier).state = v.round(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    Text(
                      'Stay inside the zone • Back button locked during session',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                    ),
                    const SizedBox(height: 36),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 56,
                          icon: Icon(
                            playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            playing ? handler.pause() : handler.play();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    
                    if (!_active)
                      LiquidGlassButton(
                        accentColor: palette.primary,
                        onTap: () => _start(minutes),
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Start Flow Session',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )
                    else
                      OutlinedButton(
                        onPressed: () {
                          _timer?.cancel();
                          setState(() {
                            _active = false;
                            _remaining = 0;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Cancel Session', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

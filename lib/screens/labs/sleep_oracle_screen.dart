import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../services/audio_effects.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

class SleepOracleScreen extends ConsumerStatefulWidget {
  const SleepOracleScreen({super.key});

  @override
  ConsumerState<SleepOracleScreen> createState() => _SleepOracleScreenState();
}

class _SleepOracleScreenState extends ConsumerState<SleepOracleScreen> {
  int _minutes = 30;
  bool _rain = true;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    final handler = ref.read(audioHandlerProvider);
    _timer = Timer(Duration(minutes: _minutes), () async {
      await RottyAudioEffects.fadeVolume(handler.player, to: 0, ms: 8000);
      await handler.pause();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sleep fade in $_minutes min${_rain ? ' • rain mood' : ''}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Sleep Oracle', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
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
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  Text(
                    'AMBIENT SLEEP FADE CONTROLLER',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gently fades out playback after a scheduled time so you can sleep restfully.',
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  
                  Text(
                    '$_minutes min',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1),
                  ),
                  const SizedBox(height: 10),
                  
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: palette.primary,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                      thumbColor: Colors.white,
                      trackHeight: 4.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      value: _minutes.toDouble(),
                      min: 5,
                      max: 90,
                      divisions: 17,
                      onChanged: (v) => setState(() => _minutes = v.round()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: SwitchListTile(
                      value: _rain,
                      activeColor: palette.primary,
                      activeThumbColor: Colors.white,
                      title: Text('Rain mood (visual)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('Displays ambient rain UI over your playing window', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                      onChanged: (v) => setState(() => _rain = v),
                    ),
                  ),
                  const SizedBox(height: 36),
                  
                  LiquidGlassButton(
                    accentColor: palette.primary,
                    onTap: _start,
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Start Sleep Timer',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
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

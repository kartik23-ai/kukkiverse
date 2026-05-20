import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../services/audio_effects.dart';

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Sleep Oracle', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fade out music gently', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Text('$_minutes min', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800)),
            Slider(
              value: _minutes.toDouble(),
              min: 5,
              max: 90,
              divisions: 17,
              activeColor: AppColors.accent,
              onChanged: (v) => setState(() => _minutes = v.round()),
            ),
            SwitchListTile(
              value: _rain,
              activeColor: AppColors.accent,
              title: Text('Rain mood (visual)', style: GoogleFonts.inter(color: Colors.white)),
              subtitle: Text('Ambient layer UI — stream continues', style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11)),
              onChanged: (v) => setState(() => _rain = v),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _start,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(52)),
              child: const Text('Start sleep fade'),
            ),
          ],
        ),
      ),
    );
  }
}

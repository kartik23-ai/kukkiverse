import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/premium/premium_models.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/premium_providers.dart';
import '../../providers/providers.dart';
import '../../services/audio_effects.dart';

class StudioLabScreen extends ConsumerWidget {
  const StudioLabScreen({super.key});

  void _applyToPlayer(WidgetRef ref, StudioEqState s) {
    ref.read(studioEqProvider.notifier).update(s);
    final player = ref.read(audioHandlerProvider).player;
    RottyAudioEffects.applyToPlayer(player);
    RottyAudioEffects.stopOrbit();
    RottyAudioEffects.startOrbit(player);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(studioEqProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Studio Lab', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Changes apply live to now playing', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _preset('Flat', () async {
                await ref.read(studioEqProvider.notifier).applyPreset('flat');
                _applyToPlayer(ref, ref.read(studioEqProvider));
              }),
              _preset('Bass', () async {
                await ref.read(studioEqProvider.notifier).applyPreset('bass');
                _applyToPlayer(ref, ref.read(studioEqProvider));
              }),
              _preset('Vocal', () async {
                await ref.read(studioEqProvider.notifier).applyPreset('vocal');
                _applyToPlayer(ref, ref.read(studioEqProvider));
              }),
              _preset('8D', () async {
                await ref.read(studioEqProvider.notifier).applyPreset('8d');
                _applyToPlayer(ref, ref.read(studioEqProvider));
              }),
            ],
          ),
          const SizedBox(height: 24),
          _slider('Bass', eq.bass, (v) => _applyToPlayer(ref, eq.copyWith(bass: v))),
          _slider('Treble', eq.treble, (v) => _applyToPlayer(ref, eq.copyWith(treble: v))),
          _slider('Vocal', eq.vocal, (v) => _applyToPlayer(ref, eq.copyWith(vocal: v))),
          _slider('Width', eq.width, (v) => _applyToPlayer(ref, eq.copyWith(width: v))),
          _slider('8D speed', eq.orbitSpeed, (v) => _applyToPlayer(ref, eq.copyWith(orbitSpeed: v))),
          SwitchListTile(
            value: eq.orbit8d,
            title: Text('8D orbit (volume pulse)', style: GoogleFonts.inter(color: Colors.white)),
            activeThumbColor: AppColors.accent,
            onChanged: (v) => _applyToPlayer(ref, eq.copyWith(orbit8d: v)),
          ),
        ],
      ),
    );
  }

  Widget _preset(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.bgElevated,
      side: const BorderSide(color: AppColors.glassBorder),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        Slider(value: value, activeColor: AppColors.accent, onChanged: onChanged),
      ],
    );
  }
}

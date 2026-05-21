import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/premium/premium_models.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/premium_providers.dart';
import '../../providers/providers.dart';
import '../../services/audio_effects.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

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
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Studio Lab', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
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
                physics: const BouncingScrollPhysics(),
                children: [
                  Text(
                    'FINE-TUNE YOUR SOUND ENGINE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Changes apply instantly to live playback stream.',
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  
                  // Presets
                  Text(
                    'PRESETS',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _preset('Flat 🎵', () async {
                        await ref.read(studioEqProvider.notifier).applyPreset('flat');
                        _applyToPlayer(ref, ref.read(studioEqProvider));
                      }, palette.primary),
                      _preset('Bass Boost 🔊', () async {
                        await ref.read(studioEqProvider.notifier).applyPreset('bass');
                        _applyToPlayer(ref, ref.read(studioEqProvider));
                      }, palette.primary),
                      _preset('Vocal Forward 🎤', () async {
                        await ref.read(studioEqProvider.notifier).applyPreset('vocal');
                        _applyToPlayer(ref, ref.read(studioEqProvider));
                      }, palette.primary),
                      _preset('8D Cinema 🎧', () async {
                        await ref.read(studioEqProvider.notifier).applyPreset('8d');
                        _applyToPlayer(ref, ref.read(studioEqProvider));
                      }, palette.primary),
                    ],
                  ),
                  const SizedBox(height: 28),
                  
                  // Sliders
                  _slider('Bass Boost', eq.bass, (v) => _applyToPlayer(ref, eq.copyWith(bass: v)), palette.primary),
                  _slider('Treble Details', eq.treble, (v) => _applyToPlayer(ref, eq.copyWith(treble: v)), palette.primary),
                  _slider('Vocal Clarity', eq.vocal, (v) => _applyToPlayer(ref, eq.copyWith(vocal: v)), palette.primary),
                  _slider('Stereo Width', eq.width, (v) => _applyToPlayer(ref, eq.copyWith(width: v)), palette.primary),
                  _slider('8D Orbit Speed', eq.orbitSpeed, (v) => _applyToPlayer(ref, eq.copyWith(orbitSpeed: v)), palette.primary),
                  
                  const SizedBox(height: 16),
                  
                  // Toggle list tile
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: SwitchListTile(
                      value: eq.orbit8d,
                      title: Text('8D Orbit Mode', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('Slow cyclical stereo volume pulse', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                      activeThumbColor: Colors.white,
                      activeTrackColor: palette.primary,
                      onChanged: (v) => _applyToPlayer(ref, eq.copyWith(orbit8d: v)),
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

  Widget _preset(String label, VoidCallback onTap, Color accent) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      onPressed: onTap,
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600, fontSize: 13)),
            Text('${(value * 100).round()}%', style: GoogleFonts.inter(color: accent, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: Colors.white,
            trackHeight: 3.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(value: value, onChanged: onChanged),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

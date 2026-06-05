import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/premium_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

class InfiniteBlendScreen extends ConsumerWidget {
  const InfiniteBlendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(infiniteBlendProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Infinite Blend', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DJ-GRADE CROSSFADE CONTROLLER',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Smoothes transitions when skipping or ending tracks by active volume crossfading.',
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: SwitchListTile(
                      value: on,
                      activeColor: palette.primary,
                      activeThumbColor: Colors.white,
                      title: Text('Enable Infinite Blend', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('Fades volume ~2s before skipping to next track', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                      onChanged: (v) => ref.read(infiniteBlendProvider.notifier).set(v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: SwitchListTile(
                      value: ref.watch(mixFadeEnabledProvider),
                      activeColor: palette.primary,
                      activeThumbColor: Colors.white,
                      title: Text('AI Mix Fade (Beat-Sync)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('Beat-matches, phase-aligns, and cross-blends tracks smoothly over ~6s', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                      onChanged: (v) => ref.read(mixFadeEnabledProvider.notifier).toggle(v),
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

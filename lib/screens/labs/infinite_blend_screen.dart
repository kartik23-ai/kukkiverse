import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/premium_providers.dart';

class InfiniteBlendScreen extends ConsumerWidget {
  const InfiniteBlendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(infiniteBlendProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Infinite Blend', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Long crossfade when skipping tracks — smoother DJ feel.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            SwitchListTile(
              value: on,
              activeColor: AppColors.accent,
              title: Text('Infinite Blend', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text('Fade out ~2s before next song', style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11)),
              onChanged: (v) => ref.read(infiniteBlendProvider.notifier).set(v),
            ),
          ],
        ),
      ),
    );
  }
}

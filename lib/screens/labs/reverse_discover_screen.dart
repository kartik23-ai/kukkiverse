import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/premium_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

class ReverseDiscoverScreen extends ConsumerWidget {
  const ReverseDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dislikes = ref.watch(dislikedIdsProvider);
    final recent = ref.watch(recentSongsProvider);
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Reverse Discover',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI EXCLUSION ENGINE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Songs marked "not for me". The AI Sound Engine will actively bypass these tracks during smart queue generation.',
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: recent.isEmpty
                        ? Center(
                            child: Text(
                              'Play some tracks first. Skipped/disliked songs will appear here.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: recent.take(12).length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final s = recent[i];
                              final disliked = dislikes.contains(s.id);
                              return LiquidGlassCard(
                                accentColor: disliked ? Colors.redAccent : Colors.white12,
                                borderRadius: 14,
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        s.image,
                                        width: 42,
                                        height: 42,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 42,
                                          height: 42,
                                          color: Colors.white10,
                                          child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 18),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.title,
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            s.artist,
                                            style: GoogleFonts.inter(
                                              color: Colors.white.withValues(alpha: 0.45),
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        disliked ? Icons.thumb_down_rounded : Icons.thumb_down_off_alt_rounded,
                                        color: disliked ? Colors.redAccent : Colors.white30,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        if (disliked) {
                                          ref.read(dislikedIdsProvider.notifier).undo(s.id);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: AppColors.bgElevated,
                                              content: Text('Removed "${s.title}" from blacklists', style: const TextStyle(color: Colors.white)),
                                            ),
                                          );
                                        } else {
                                          ref.read(dislikedIdsProvider.notifier).dislike(s.id);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: Colors.redAccent,
                                              content: Text('Blacklisted "${s.title}" from smart cues', style: const TextStyle(color: Colors.white)),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/premium_providers.dart';
import '../../providers/providers.dart';

class ReverseDiscoverScreen extends ConsumerWidget {
  const ReverseDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dislikes = ref.watch(dislikedIdsProvider);
    final recent = ref.watch(recentSongsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Reverse Discover', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Songs you marked “not for me” — AI queue avoids them.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ...recent.take(12).map((s) {
            final disliked = dislikes.contains(s.id);
            return ListTile(
              tileColor: AppColors.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(s.title, style: GoogleFonts.inter(color: Colors.white)),
              subtitle: Text(s.artist, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
              trailing: IconButton(
                icon: Icon(disliked ? Icons.thumb_down_rounded : Icons.thumb_down_off_alt_rounded, color: disliked ? AppColors.accent : Colors.white38),
                onPressed: () {
                  if (disliked) {
                    ref.read(dislikedIdsProvider.notifier).undo(s.id);
                  } else {
                    ref.read(dislikedIdsProvider.notifier).dislike(s.id);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

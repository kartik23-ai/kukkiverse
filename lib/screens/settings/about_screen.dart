import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: Stack(
        children: [
          // Elegant Aurora Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.meshTop,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Navigation Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ABOUT ROTTY',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // App Identity Glass Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.accentGradient,
                              ),
                              child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Rotty Music',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Version 1.2.0',
                              style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Created with ❤️ by Kartik',
                              style: GoogleFonts.outfit(
                                color: AppColors.accentSoft,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Our Philosophy Card
                      _buildPhilosophyCard(
                        icon: Icons.favorite_rounded,
                        title: '100% Ad-Free Experience',
                        subtitle: 'Aapke aur aapke music ke beech me koi commercial ad nahi aayega, ever. Pure listening without breaks.',
                        color: Colors.pinkAccent,
                      ),
                      const SizedBox(height: 12),
                      _buildPhilosophyCard(
                        icon: Icons.shield_rounded,
                        title: 'Pure Privacy, No Tracking',
                        subtitle: 'Hum commercial apps ki tarah aapka data, search inputs, ya listening history track nahi karte. Jo bhi data hai, wo completely aapke device par localized hai.',
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(height: 12),
                      _buildPhilosophyCard(
                        icon: Icons.palette_rounded,
                        title: 'Crafted for Aesthetics',
                        subtitle: 'Fluid dynamic backgrounds aur rich glassmorphic elements jo music ko utna hi sundar banate hain jitna wo sunne me lagta hai.',
                        color: Colors.amberAccent,
                      ),
                      const SizedBox(height: 32),
                      // Safe-harbor Copyright disclaimer
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.02),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Legal & Safe-Harbor Disclaimer',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rotty Music is a personal, non-commercial media client built strictly for educational and personal entertainment purposes. We do not host, store, or index any audio media on our servers. All streams are generated dynamically via public metadata wrappers on the fly.\n\nIf you are the copyright owner of any streamed metadata and wish to request its removal, please write to us directly at kartikchauhan0509@gmail.com. All valid requests will be respected and processed immediately.',
                              style: GoogleFonts.inter(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhilosophyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;

  static const _slides = [
    _Slide('Welcome to ROTTY', 'Stream Hindi & English hits — no ads, pure sound.', Icons.music_note_rounded),
    _Slide('ROTTY AI DJ', 'Smart queue learns your mood and time of day.', Icons.auto_awesome_rounded),
    _Slide('Lyrics & background', 'Synced lyrics + lock screen controls.', Icons.subtitles_rounded),
    _Slide('ROTTY Labs', 'Aura colors, Cinema lyrics, Concert mode & more.', Icons.science_rounded),
    _Slide('Your account', 'Favorites & streak sync with Firebase cloud.', Icons.cloud_done_rounded),
    _Slide('Let\'s listen', 'Your next favorite song is one tap away.', Icons.play_circle_filled_rounded),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Skip', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (_, index) {
                  final s = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: AppColors.accentGradient,
                            boxShadow: [
                              BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Icon(s.icon, size: 52, color: Colors.white),
                        )
                            .animate(key: ValueKey(index))
                            .fadeIn(duration: 400.ms)
                            .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
                        const SizedBox(height: 40),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary, height: 1.55),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (j) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: _i == j ? 28 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _i == j ? AppColors.accent : Colors.white24,
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (_i < _slides.length - 1) {
                      _page.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
                    } else {
                      _finish();
                    }
                  },
                  child: Text(
                    _i == _slides.length - 1 ? 'Get Started' : 'Continue',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    await StorageService().setOnboardingDone();
    await StorageService().setInteractiveOnboardingDone();
    if (mounted) context.go('/home');
  }
}

class _Slide {
  const _Slide(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

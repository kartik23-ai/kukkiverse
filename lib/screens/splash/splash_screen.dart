import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/elite_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logo;
  bool _killed = false;
  String _killMessage = '';

  @override
  void initState() {
    super.initState();
    _logo = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    // Check kill switch first
    final status = await FirebaseService.instance.checkKillSwitch();
    if (status['enabled'] == false) {
      if (!mounted) return;
      setState(() {
        _killed = true;
        _killMessage = status['message'] as String? ?? 'App is under maintenance.';
      });
      return; // Don't navigate — show maintenance screen
    }

    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    _goNext();
  }

  void _goNext() {
    final storage = StorageService();
    if (!storage.authSessionDone) {
      context.go('/auth');
      return;
    }
    if (!storage.isOnboardingDone) {
      context.go('/onboarding');
      return;
    }
    context.go('/home');
  }

  @override
  void dispose() {
    _logo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: RottyAuroraBackground(
        intensity: 1.2,
        child: Center(
          child: _killed ? _maintenanceView() : _splashView(),
        ),
      ),
    );
  }

  Widget _splashView() {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _logo, curve: Curves.easeOutBack),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFFA2D48), Color(0xFF7B61FF), Color(0xFF00D4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 4),
                BoxShadow(color: const Color(0xFF7B61FF).withValues(alpha: 0.3), blurRadius: 60, spreadRadius: 8),
              ],
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 52),
          ).animate().shimmer(duration: 1200.ms, delay: 400.ms),
          const SizedBox(height: 32),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFA2D48), Color(0xFF7B61FF), Color(0xFF00D4FF)],
            ).createShader(bounds),
            child: Text(
              'ROTTY',
              style: GoogleFonts.inter(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 10),
            ),
          ),
          const SizedBox(height: 8),
          Text('MUSIC', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent, letterSpacing: 14)),
          const SizedBox(height: 24),
          Text('Feel The Future', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, letterSpacing: 2)),
          const SizedBox(height: 40),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accent.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _maintenanceView() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.accent.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.construction_rounded, color: AppColors.accent, size: 40),
          ),
          const SizedBox(height: 32),
          Text('Under Maintenance', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          Text(
            _killMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              setState(() => _killed = false);
              _checkAndNavigate();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text('Try Again', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

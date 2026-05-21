import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
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
  bool _isUpdateRequired = false;
  String _killMessage = '';

  @override
  void initState() {
    super.initState();
    _logo = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _checkAndNavigate();
  }

  bool _isVersionOutdated(String current, String? min) {
    if (min == null || min.isEmpty) return false;
    try {
      final curClean = current.split('+').first;
      final minClean = min.split('+').first;

      final curParts = curClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final minParts = minClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < max(curParts.length, minParts.length); i++) {
        final curVal = i < curParts.length ? curParts[i] : 0;
        final minVal = i < minParts.length ? minParts[i] : 0;

        if (curVal < minVal) return true;
        if (curVal > minVal) return false;
      }

      // Check build version if semantic versions are identical
      final curBuildStr = current.contains('+') ? current.split('+').last : '';
      final minBuildStr = min.contains('+') ? min.split('+').last : '';
      if (curBuildStr.isNotEmpty && minBuildStr.isNotEmpty) {
        final curBuild = int.tryParse(curBuildStr) ?? 0;
        final minBuild = int.tryParse(minBuildStr) ?? 0;
        if (curBuild < minBuild) return true;
      }
    } catch (e) {
      debugPrint('Error comparing versions: $e');
    }
    return false;
  }

  Future<void> _checkAndNavigate() async {
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    final status = await FirebaseService.instance.checkKillSwitch();
    final minVersion = status['minVersion'] as String?;
    final isOutdated = _isVersionOutdated(AppConstants.version, minVersion);

    if (status['enabled'] == false || isOutdated) {
      if (!mounted) return;
      setState(() {
        _killed = true;
        _isUpdateRequired = isOutdated;
        _killMessage = isOutdated
            ? 'A newer version ($minVersion) of Rotty Music is available. Please update to continue.'
            : (status['message'] as String? ?? 'App is under maintenance.');
      });
      return;
    }

    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    _goNext(isDesktop);
  }

  void _goNext([bool isDesktop = false]) {
    // On desktop, skip auth/onboarding — go straight to home
    if (isDesktop) {
      context.go('/home');
      return;
    }
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
    final title = _isUpdateRequired ? 'Update Required' : 'Under Maintenance';
    final iconData = _isUpdateRequired ? Icons.system_update_rounded : Icons.construction_rounded;
    final btnText = _isUpdateRequired ? 'Retry Check' : 'Try Again';

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.accent, const Color(0xFF7B61FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(iconData, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _killMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: AppColors.accent.withValues(alpha: 0.4),
                ),
                onPressed: () {
                  setState(() {
                    _killed = false;
                  });
                  _checkAndNavigate();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  btnText,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

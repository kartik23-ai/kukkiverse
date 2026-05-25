import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../services/storage_service.dart';

class FirstLaunchSupportOverlay extends StatefulWidget {
  const FirstLaunchSupportOverlay({super.key, required this.onDismissed});
  final VoidCallback onDismissed;

  @override
  State<FirstLaunchSupportOverlay> createState() => _FirstLaunchSupportOverlayState();
}

class _FirstLaunchSupportOverlayState extends State<FirstLaunchSupportOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _heartCtrl;

  @override
  void initState() {
    super.initState();
    // Heartbeat pulsing micro-animation
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.9,
      upperBound: 1.15,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _claimFree() async {
    final storage = StorageService();
    await storage.setHasSeenSupportOverlay(true);
    await storage.setLastSeenVersion('1.1.0');
    widget.onDismissed();
  }

  Future<void> _goToSupport() async {
    final storage = StorageService();
    await storage.setHasSeenSupportOverlay(true);
    await storage.setLastSeenVersion('1.1.0');
    widget.onDismissed();
    // Redirect directly to settings support screen
    // Delay slightly to allow modal closing animation to complete smoothly
    Future.delayed(const Duration(milliseconds: 150), () {
      context.push('/support');
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Ensure they must choose an action
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.75),
        body: Stack(
          children: [
            // High intensity backdrop blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Dialog content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pinkAccent.withValues(alpha: 0.25),
                        blurRadius: 32,
                        spreadRadius: -4,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsating custom neon heart icon
                      ScaleTransition(
                        scale: _heartCtrl,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.pink.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.pinkAccent.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.pinkAccent,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Outfit Bold Title
                      Text(
                        'A GIFT FOR YOU! 🎧',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '100% Free & Ad-Free Music',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.pinkAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Persuasive message
                      Text(
                        'Hey! I’m Kartik, the developer behind Rotty. I built this app because I believe great music should be free, extremely beautiful, and completely private—without annoying corporate ads tracking your life.\n\nBut maintaining fast stream servers, domains, and coding new updates takes real effort and hosting costs. If you love this clean experience, consider sending a small one-time support contribution of ₹99 to keep Rotty alive and ad-free forever. Even a tiny gesture means the world to me!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Support Button
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: AppColors.accentGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: FilledButton(
                          onPressed: _goToSupport,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Support Kartik & Gift ₹99 💖',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Cancel Button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: _claimFree,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Enjoy Free Music 🎵',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
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

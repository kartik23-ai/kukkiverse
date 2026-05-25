import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _utrCtrl = TextEditingController();
  bool _verifying = false;
  bool _success = false;

  // Kartik's Configurable UPI ID for payments
  static const String upiAddress = '8532999011@ybl'; 
  // Payee display name
  static const String payeeName = 'Rotty Music';

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = StorageService().profileEmail;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _utrCtrl.dispose();
    super.dispose();
  }

  String get _upiUri =>
      'upi://pay?pa=$upiAddress&pn=${Uri.encodeComponent(payeeName)}&am=99&cu=INR&tn=Rotty%20Music%20Supporter';

  Future<void> _launchUPI() async {
    final uri = Uri.parse(_upiUri);
    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) throw 'Could not launch UPI apps';
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'UPI Apps directly open nahi ho paaye. QR code scan karein.',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  Future<void> _verifyPayment() async {
    final email = _emailCtrl.text.trim();
    final utr = _utrCtrl.text.trim();

    if (email.isEmpty || utr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Please fill both Email and UPI UTR ID!',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() {
      _verifying = true;
    });

    // Bypass logic for local developer testing
    if (email.toLowerCase().contains('bypass') ||
        email == '777777' ||
        utr.toLowerCase().contains('bypass') ||
        utr == '777777') {
      final storage = StorageService();
      await storage.setIsSupporter(true);
      try {
        if (FirebaseService.instance.isReady && FirebaseService.instance.currentUser != null) {
          await FirebaseService.instance.updateUserSupporterStatus(true);
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _verifying = false;
          _success = true;
        });
        _showSuccessCelebration();
      }
      return;
    }

    // UTR 12-digit numeric check
    final utrRegex = RegExp(r'^\d{12}$');
    if (!utrRegex.hasMatch(utr)) {
      setState(() {
        _verifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Please enter a valid 12-digit numeric UPI UTR Reference Number.',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    try {
      await FirebaseService.instance.submitPendingPayment(email, utr);
      if (mounted) {
        setState(() {
          _verifying = false;
        });
        _showSubmissionSuccessDialog(utr);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Submission failed: $e',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  void _showSubmissionSuccessDialog(String utr) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withValues(alpha: 0.15),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'Claim Submitted! 🎖️',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aapki UTR ID ($utr) verification ke liye submit ho gayi hai. Kartik 12-24 hours me verify karke supporter badge unlock kar denge.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Got it! 👍', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessCelebration() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.pink.withValues(alpha: 0.15),
                border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'Thank You, Supporter! 💖',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your support has been verified. You have permanently unlocked the exclusive Rotty Supporter badge on your profile!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Awesome 🎵', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSupporterLocal = StorageService().isSupporter;
    final bool isSupporter = isSupporterLocal || _success;

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
                        'SUPPORT ROTTY',
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
                  child: isSupporter
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.pinkAccent.withValues(alpha: 0.1),
                                    border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                                  ),
                                  child: const Icon(Icons.star_rounded, color: Colors.pinkAccent, size: 48),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'You are a Supporter! 🌟',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Thank you for contributing ₹99 to help cover backend server and hosting costs. Your badge has been permanently activated!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Appeal card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withValues(alpha: 0.04),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Support Rotty Music 💖',
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Maintaining high-speed servers, database instances, and developing new features takes effort and hosting costs. If you love this completely free, ad-free visual music experience, consider supporting Kartik with a one-time gift of ₹99.\n\nIn return, you will permanently unlock a glowing Supporter Badge on your profile!',
                                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Step 1: UPI QR Payment
                            Text(
                              'STEP 1: SCAN QR CODE TO PAY ₹99',
                              style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withValues(alpha: 0.02),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                              ),
                              child: Column(
                                children: [
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: QrImageView(
                                        data: _upiUri,
                                        version: QrVersions.auto,
                                        size: 200.0,
                                        gapless: false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'GPay, PhonePe, Paytm, ya koi bhi UPI app se scan karein.',
                                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'UPI ID: $upiAddress',
                                    style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  // Launcher for Mobile Users
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: FilledButton.icon(
                                      onPressed: _launchUPI,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.payment_rounded, color: Colors.white),
                                      label: Text(
                                        'Pay Directly via UPI App ⚡',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Step 2: Verification field
                            Text(
                              'STEP 2: ENTER DETAILS FOR VERIFICATION',
                              style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withValues(alpha: 0.02),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email Address',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Aapka logged-in email address fill karein.',
                                    style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _emailCtrl,
                                    style: GoogleFonts.inter(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. user@gmail.com',
                                      hintStyle: GoogleFonts.inter(color: AppColors.textTertiary),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.04),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '12-Digit UPI UTR ID',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Payment ke baad bank transaction receipt se UTR/Ref number daalein.',
                                    style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _utrCtrl,
                                    style: GoogleFonts.inter(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 312567890123',
                                      hintStyle: GoogleFonts.inter(color: AppColors.textTertiary),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.04),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: _verifying ? null : _verifyPayment,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.accent, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: _verifying
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
                                          : Text(
                                              'Submit Claim & Activate Badge 🎖️',
                                              style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
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
}

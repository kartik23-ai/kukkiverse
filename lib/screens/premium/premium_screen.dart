import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/premium_providers.dart';
import '../../services/premium_payment_service.dart';
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/rotty_glass.dart';
import '../../widgets/elite_background.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  List<UpiAppInfo> _apps = [];
  bool _loadingApps = true;
  bool _paying = false;
  String? _txnRef;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await PremiumPaymentService.instance.getInstalledUpiApps();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loadingApps = false;
    });
  }

  Future<void> _pay(UpiAppInfo app) async {
    if (_paying) return;
    final refId = PremiumPaymentService.instance.newTransactionRef();
    setState(() {
      _paying = true;
      _txnRef = refId;
      _status = 'Complete ₹99 payment in ${app.name}…';
    });

    final result = await PremiumPaymentService.instance.payWithApp(
      app: app,
      transactionRefId: refId,
    );

    if (!mounted) return;

    if (result.success) {
      // Only activate on confirmed UPI success
      final txn = (result.rawResponse ?? refId);
      final safeId = txn.length > 120 ? refId : txn;
      await StorageService().activatePremiumMonth(txnId: safeId);
      await FirebaseService.instance.syncUserData();
      await ref.read(premiumInfoProvider.notifier).refresh();
      setState(() => _status = '✅ Payment successful — PRO unlocked!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ROTTY PRO active for 30 days')),
      );
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) context.pop();
      });
    } else if (result.status == 'submitted') {
      setState(() => _status = '⏳ Payment submitted but not confirmed yet. PRO will unlock only when your bank confirms success. Try again if needed.');
    } else if (result.status == 'cancelled') {
      setState(() => _status = '❌ Payment cancelled. PRO not activated.');
    } else {
      setState(() => _status = '❌ Payment not completed. PRO stays locked. Try again.');
    }

    if (mounted) setState(() => _paying = false);
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(premiumInfoProvider);
    final payUri = PremiumPaymentService.instance.upiPayUri(
      _txnRef ?? PremiumPaymentService.instance.newTransactionRef(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: RottyAuroraBackground(
        intensity: 0.5,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFA2D48), Color(0xFF7B61FF)],
                        ).createShader(bounds),
                        child: Text('ROTTY PRO', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFA2D48), Color(0xFF7B61FF)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 16),
                          ],
                        ),
                        child: Text(
                          info.active ? '✨ ACTIVE' : '₹99 / month',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        info.active ? 'You have PRO' : 'Unlock the full ROTTY experience',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      if (info.active && info.expiresAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Valid until ${_formatDate(info.expiresAt!)}',
                            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _benefit(Icons.auto_awesome_rounded, 'ROTTY AI DJ Pro', const Color(0xFFFA2D48)),
                      _benefit(Icons.palette_rounded, 'Aura — album colors everywhere', const Color(0xFF7B61FF)),
                      _benefit(Icons.tune_rounded, 'Studio Lab • Bass • 8D', const Color(0xFF00D4FF)),
                      _benefit(Icons.movie_rounded, 'Lyrics Cinema & PRO Labs', const Color(0xFFF97316)),
                      const SizedBox(height: 28),
                      if (!info.active) ...[
                        RottyGlass(
                          child: Column(
                            children: [
                              Text('Scan to pay ₹99', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                child: QrImageView(data: payUri, size: 200, backgroundColor: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              Text(PremiumPaymentService.upiId, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 8),
                              Text(
                                'PRO unlocks ONLY when UPI payment is successful',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Or pay directly with your UPI app', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        if (_loadingApps)
                          const CircularProgressIndicator(color: AppColors.accent)
                        else if (_apps.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No UPI apps found.\nInstall Google Pay, PhonePe or Paytm.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 13),
                            ),
                          )
                        else
                          ..._apps.take(8).map((app) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                      ),
                                    ),
                                    onPressed: _paying ? null : () => _pay(app),
                                    icon: app.icon != null && app.icon!.isNotEmpty
                                        ? Image.memory(app.icon!, width: 28, height: 28, errorBuilder: (_, __, ___) => const Icon(Icons.payment_rounded, color: AppColors.accent))
                                        : const Icon(Icons.payment_rounded, color: AppColors.accent),
                                    label: Text('Pay with ${app.name}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              )),
                        if (_status != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                            ),
                            child: Text(_status!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.accent, fontSize: 13)),
                          ),
                        ],
                        if (_paying)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: CircularProgressIndicator(color: AppColors.accent),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

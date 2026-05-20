import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../providers/premium_providers.dart';

/// Wraps premium-only UI — tap opens paywall when locked.
class PremiumGate extends ConsumerWidget {
  const PremiumGate({super.key, required this.child, this.lockedMessage});

  final Widget child;
  final String? lockedMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(rottyPremiumProvider);
    if (premium) return child;

    return Stack(
      children: [
        Opacity(opacity: 0.35, child: IgnorePointer(child: child)),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/premium'),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, color: AppColors.accent, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        lockedMessage ?? 'ROTTY PRO required',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('₹99/month via UPI', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

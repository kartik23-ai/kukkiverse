import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/feature_providers.dart';
import '../core/theme/app_colors.dart';
import 'liquid_glass.dart';

class PartyLockOverlay extends ConsumerWidget {
  const PartyLockOverlay({
    super.key,
    required this.roomCode,
    required this.isHost,
  });

  final String roomCode;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF7B61FF).withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B61FF).withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Crown or music node icon with neon circular backdrop
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7B61FF).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFF7B61FF).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Color(0xFF7B61FF),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'PARTY SYNC ACTIVE',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF7B61FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    roomCode,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isHost
                        ? 'Aap is party room ke Host 👑 hain. Playback controls aur queue synchronization pure group ke sath live synced hain.'
                        : 'Aap is party room me connected hain. Independent music play/pause block rahega taaki aapki device group ke sath synced rahe.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Primary Action: Open Party Sync
                  LiquidGlassButton(
                    accentColor: const Color(0xFF7B61FF),
                    isActive: true,
                    onTap: () => context.push('/party'),
                    child: Center(
                      child: Text(
                        'OPEN PARTY SCREEN',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Secondary Action: Leave Party
                  TextButton(
                    onPressed: () => ref.read(partyRoomProvider.notifier).leaveRoom(),
                    child: Text(
                      'Leave Party & Unlock App',
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../providers/rotty_connect_providers.dart';
import '../services/rotty_connect_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// Connect Device Sheet — Bottom sheet showing available devices
/// Tap to transfer playback between phone ↔ PC
/// ═══════════════════════════════════════════════════════════════
class ConnectDeviceSheet extends ConsumerWidget {
  const ConnectDeviceSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const ConnectDeviceSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(connectedDevicesProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Icon(Icons.devices_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Text(
                'Connect to a Device',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Devices list
          devicesAsync.when(
            data: (devices) {
              if (devices.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No devices found.\nOpen Rotty Music on another device.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                  ),
                );
              }
              return Column(
                children: devices.map((device) => _DeviceTile(device: device)).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (_, __) => Text(
              'Failed to load devices',
              style: GoogleFonts.inter(color: Colors.white30),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device});
  final ConnectedDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = device.type == DeviceType.desktop;
    final service = ref.read(rottyConnectProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            // Transfer playback to this device
            ref.read(activeRemoteDeviceProvider.notifier).state = device.id;
            ref.read(isRemotePlaybackProvider.notifier).state = true;
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                // Device icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: (isDesktop ? const Color(0xFF7B61FF) : AppColors.accent).withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    isDesktop ? Icons.laptop_windows_rounded : Icons.phone_android_rounded,
                    color: isDesktop ? const Color(0xFF7B61FF) : AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDesktop ? 'Windows PC' : 'Mobile',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                // Online status
                if (device.online)
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1DB954),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF1DB954).withValues(alpha: 0.5), blurRadius: 8),
                      ],
                    ),
                  )
                else
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

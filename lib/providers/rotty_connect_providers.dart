import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rotty_connect_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// Rotty Connect Providers — Riverpod state for device sync
/// ═══════════════════════════════════════════════════════════════

/// Service instance
final rottyConnectProvider = Provider<RottyConnectService>((ref) {
  return RottyConnectService.instance;
});

/// Stream of connected devices
final connectedDevicesProvider = StreamProvider<List<ConnectedDevice>>((ref) {
  final service = ref.read(rottyConnectProvider);
  if (!service.isInitialized) return Stream.value([]);
  return service.watchDevices();
});

/// Stream of remote playback state
final remotePlaybackProvider = StreamProvider<RemotePlaybackState?>((ref) {
  final service = ref.read(rottyConnectProvider);
  if (!service.isInitialized) return Stream.value(null);
  return service.watchPlayback();
});

/// Whether we're currently controlling a remote device
final isRemotePlaybackProvider = StateProvider<bool>((ref) => false);

/// The currently selected remote device ID
final activeRemoteDeviceProvider = StateProvider<String?>((ref) => null);

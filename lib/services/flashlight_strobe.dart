import 'dart:async';
import 'package:flutter/services.dart';

/// ═══════════════════════════════════════════════════════════════
/// Flashlight Strobe Controller
/// Uses native MethodChannel to control the camera LED flashlight.
/// Synchronized to beat frequency for concert mode immersion.
/// ═══════════════════════════════════════════════════════════════
class FlashlightStrobe {
  static const _channel = MethodChannel('com.rottymusic.rotty_music/flashlight');
  static bool _available = true;
  static bool _strobing = false;
  static Timer? _strobeTimer;

  /// Check if flashlight is available
  static Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      _available = result ?? false;
      return _available;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  /// Turn flashlight ON
  static Future<void> turnOn() async {
    if (!_available) return;
    try {
      await _channel.invokeMethod('turnOn');
    } catch (_) {}
  }

  /// Turn flashlight OFF
  static Future<void> turnOff() async {
    try {
      await _channel.invokeMethod('turnOff');
    } catch (_) {}
  }

  /// Start strobing at given BPM (beats per minute)
  /// e.g., 120 BPM = flash every 500ms
  static void startStrobe({int bpm = 120, int flashDurationMs = 50}) {
    if (!_available || _strobing) return;
    _strobing = true;
    final interval = (60000 / bpm).round();

    _strobeTimer = Timer.periodic(Duration(milliseconds: interval), (_) async {
      if (!_strobing) return;
      await turnOn();
      await Future.delayed(Duration(milliseconds: flashDurationMs));
      await turnOff();
    });
  }

  /// Bass-synced flash — call this on every detected bass peak
  static Future<void> flashOnce({int durationMs = 60}) async {
    if (!_available) return;
    await turnOn();
    Future.delayed(Duration(milliseconds: durationMs), () => turnOff());
  }

  /// Stop strobing
  static void stopStrobe() {
    _strobing = false;
    _strobeTimer?.cancel();
    _strobeTimer = null;
    turnOff();
  }

  /// Cleanup
  static void dispose() {
    stopStrobe();
  }
}

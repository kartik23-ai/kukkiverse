import 'dart:async';
import 'package:flutter/services.dart';

/// ═══════════════════════════════════════════════════════════════
/// Tactile Symphony — Haptic Audio Instrument Mapping
/// Maps different audio frequencies to distinct haptic patterns:
/// • Bass/Kicks (Low) → Heavy motor thump
/// • Snares/Vocals (Mid) → Soft selection clicks
/// • Hi-hats/Transitions (High) → Micro click bursts
/// ═══════════════════════════════════════════════════════════════
class MusicHaptics {
  MusicHaptics._();

  static Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  // ─── Standard control haptics ───
  static void playPause() => _safe(() => HapticFeedback.mediumImpact());
  static void seek() => _safe(() => HapticFeedback.selectionClick());
  static void skip() => _safe(() => HapticFeedback.lightImpact());
  static void like() => _safe(() => HapticFeedback.heavyImpact());
  static void queueAdd() => _safe(() => HapticFeedback.mediumImpact());
  static void modeSwitch() => _safe(() => HapticFeedback.lightImpact());
  static void crossfade() => _safe(() => HapticFeedback.selectionClick());

  // ─── Instrument-mapped haptic patterns ───

  /// Bass drum / kick — deep, heavy thump (0.2s feel)
  /// Use for low frequencies (20–150 Hz peaks)
  static Future<void> bassKick() async {
    await _safe(() async {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    });
  }

  /// Snare / clap — crisp medium tap
  /// Use for mid frequencies (150–2000 Hz peaks)
  static void snareHit() => _safe(() => HapticFeedback.mediumImpact());

  /// Hi-hat / cymbal — light selection click burst
  /// Use for high frequencies (2000+ Hz peaks)
  static Future<void> hiHatTick() async {
    await _safe(() async {
      await HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 30));
      await HapticFeedback.selectionClick();
    });
  }

  /// Sub-bass rumble — multiple rapid heavy impacts (concert subwoofer feel)
  static Future<void> subBassRumble() async {
    await _safe(() async {
      for (var i = 0; i < 3; i++) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 50));
      }
    });
  }

  /// Drop impact — the "oh shit" moment in EDM drops
  /// Triple heavy impact with spacing for maximum punch
  static Future<void> dropImpact() async {
    await _safe(() async {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 60));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 60));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 40));
      await HapticFeedback.mediumImpact();
    });
  }

  /// Vinyl scratch haptic — rapid alternating clicks
  static Future<void> scratchFeel() async {
    await _safe(() async {
      for (var i = 0; i < 4; i++) {
        await HapticFeedback.selectionClick();
        await Future.delayed(const Duration(milliseconds: 25));
      }
    });
  }

  /// Song transition — soft fade-out haptic
  static Future<void> songTransition() async {
    await _safe(() async {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.selectionClick();
    });
  }

  /// Auto-detect frequency range and fire appropriate haptic
  /// [normalizedAmplitude]: 0.0–1.0 from audio analysis
  /// [frequencyBand]: 'low', 'mid', 'high'
  static void fireForFrequency(String frequencyBand, double normalizedAmplitude) {
    if (normalizedAmplitude < 0.3) return; // Below threshold

    switch (frequencyBand) {
      case 'low':
        if (normalizedAmplitude > 0.8) {
          subBassRumble();
        } else {
          bassKick();
        }
        break;
      case 'mid':
        snareHit();
        break;
      case 'high':
        hiHatTick();
        break;
    }
  }
}

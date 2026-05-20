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

  // ─── Standard control haptics ───
  static void playPause() => HapticFeedback.mediumImpact();
  static void seek() => HapticFeedback.selectionClick();
  static void skip() => HapticFeedback.lightImpact();
  static void like() => HapticFeedback.heavyImpact();
  static void queueAdd() => HapticFeedback.mediumImpact();
  static void modeSwitch() => HapticFeedback.lightImpact();
  static void crossfade() => HapticFeedback.selectionClick();

  // ─── Instrument-mapped haptic patterns ───

  /// Bass drum / kick — deep, heavy thump (0.2s feel)
  /// Use for low frequencies (20–150 Hz peaks)
  static Future<void> bassKick() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.heavyImpact();
  }

  /// Snare / clap — crisp medium tap
  /// Use for mid frequencies (150–2000 Hz peaks)
  static void snareHit() => HapticFeedback.mediumImpact();

  /// Hi-hat / cymbal — light selection click burst
  /// Use for high frequencies (2000+ Hz peaks)
  static Future<void> hiHatTick() async {
    HapticFeedback.selectionClick();
    await Future.delayed(const Duration(milliseconds: 30));
    HapticFeedback.selectionClick();
  }

  /// Sub-bass rumble — multiple rapid heavy impacts (concert subwoofer feel)
  static Future<void> subBassRumble() async {
    for (var i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Drop impact — the "oh shit" moment in EDM drops
  /// Triple heavy impact with spacing for maximum punch
  static Future<void> dropImpact() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 40));
    HapticFeedback.mediumImpact();
  }

  /// Vinyl scratch haptic — rapid alternating clicks
  static Future<void> scratchFeel() async {
    for (var i = 0; i < 4; i++) {
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 25));
    }
  }

  /// Song transition — soft fade-out haptic
  static Future<void> songTransition() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.selectionClick();
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

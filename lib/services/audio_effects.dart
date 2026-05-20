import 'dart:async';
import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';
import '../core/sound/sound_space.dart';

/// Playback effects — volume shaping + 8D orbit pulse + Android EQ integration.
class RottyAudioEffects {
  RottyAudioEffects._();

  static double bass = 0.5;
  static double treble = 0.5;
  static double vocal = 0.5;
  static double width = 0.5;
  static double orbitSpeed = 0.5;
  static bool orbit8d = false;
  static bool infiniteBlend = false;
  static SoundSpace activeSpace = SoundSpace.normal;

  static Timer? _orbitTimer;
  static double _orbitPhase = 0;
  static AndroidEqualizer? _equalizer;

  /// Initialize the equalizer and attach it to the player's audio pipeline.
  /// Must be called once during player setup.
  static AndroidEqualizer createEqualizer() {
    _equalizer = AndroidEqualizer();
    return _equalizer!;
  }

  static void applySoundSpace(SoundSpace space) {
    activeSpace = space;
    switch (space) {
      case SoundSpace.normal:
        bass = 0.5;
        treble = 0.5;
        vocal = 0.5;
        width = 0.5;
        orbit8d = false;
      case SoundSpace.wide:
        bass = 0.55;
        treble = 0.62;
        vocal = 0.48;
        width = 0.88;
        orbit8d = false;
      case SoundSpace.bass:
        bass = 0.98;
        treble = 0.28;
        vocal = 0.42;
        width = 0.55;
        orbit8d = false;
      case SoundSpace.vocal:
        bass = 0.38;
        treble = 0.58;
        vocal = 0.95;
        width = 0.45;
        orbit8d = false;
      case SoundSpace.eightD:
        bass = 0.52;
        treble = 0.5;
        vocal = 0.5;
        width = 0.92;
        orbit8d = true;
        orbitSpeed = 0.78;
    }
  }

  /// Apply EQ settings to the Android Equalizer bands.
  /// Maps bass/treble/vocal to actual frequency bands.
  static Future<void> _applyEqualizer() async {
    if (_equalizer == null) return;
    try {
      await _equalizer!.setEnabled(true);
      final params = await _equalizer!.parameters;
      final bands = params.bands;
      if (bands.isEmpty) return;

      // Typical 5-band EQ: 60Hz, 230Hz, 910Hz, 3600Hz, 14000Hz
      final bandCount = bands.length;
      final minGain = params.minDecibels;
      final maxGain = params.maxDecibels;
      final range = maxGain - minGain;

      for (int i = 0; i < bandCount; i++) {
        double gain;
        final ratio = i / (bandCount - 1).clamp(1, 100);
        
        if (ratio <= 0.25) {
          // Low freq bands → bass control
          gain = minGain + (bass * range);
        } else if (ratio <= 0.5) {
          // Low-mid → blend of bass and vocal
          gain = minGain + ((bass * 0.4 + vocal * 0.6) * range);
        } else if (ratio <= 0.75) {
          // Mid → vocal control
          gain = minGain + (vocal * range);
        } else {
          // High freq bands → treble control
          gain = minGain + (treble * range);
        }

        // Width boost: slightly boost stereo perception on high bands
        if (width > 0.6 && ratio > 0.5) {
          gain += (width - 0.5) * range * 0.15;
        }

        await bands[i].setGain(gain.clamp(minGain, maxGain));
      }
    } catch (_) {
      // EQ not available on this device — fall back to volume shaping
    }
  }

  static void applyToPlayer(AudioPlayer player) {
    // Volume shaping (always works)
    final bassBoost = switch (activeSpace) {
      SoundSpace.bass => 0.88 + bass * 0.42,
      SoundSpace.vocal => 0.72 + bass * 0.28,
      SoundSpace.eightD => 0.78 + bass * 0.32,
      _ => 0.68 + bass * 0.38,
    };
    final trebleAdj = 0.72 + treble * 0.38;
    final vocalAdj = 0.88 + vocal * 0.22;
    final widthBoost = 1.0 + width * 0.08;
    player.setVolume((bassBoost * trebleAdj * vocalAdj * widthBoost).clamp(0.42, 1.0));

    // Apply hardware EQ (Android only)
    _applyEqualizer();
  }

  static void startOrbit(AudioPlayer player) {
    _orbitTimer?.cancel();
    if (!orbit8d) return;
    final base = switch (activeSpace) {
      SoundSpace.bass => 0.92 + bass * 0.18,
      SoundSpace.eightD => 0.82 + bass * 0.28,
      _ => 0.85 + bass * 0.3,
    };
    _orbitTimer = Timer.periodic(const Duration(milliseconds: 85), (_) {
      _orbitPhase += 0.045 + orbitSpeed * 0.14;
      final wobble = math.sin(_orbitPhase) * (0.12 + width * 0.16);
      player.setVolume((base + wobble).clamp(0.42, 1.0));
    });
  }

  static void stopOrbit() {
    _orbitTimer?.cancel();
    _orbitTimer = null;
  }

  static Future<void> fadeVolume(AudioPlayer player, {required double to, int ms = 1200}) async {
    final from = player.volume;
    const steps = 12;
    final stepMs = ms ~/ steps;
    for (var i = 1; i <= steps; i++) {
      if (!player.playing && to < from) break;
      await player.setVolume(from + (to - from) * (i / steps));
      await Future<void>.delayed(Duration(milliseconds: stepMs));
    }
  }
}

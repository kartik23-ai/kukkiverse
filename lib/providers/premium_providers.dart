import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/premium/premium_models.dart';
import '../core/premium/rotty_premium.dart';
import '../services/audio_effects.dart';
import '../services/storage_service.dart';
import 'providers.dart';

class PremiumInfo {
  const PremiumInfo({required this.active, this.expiresAt});
  final bool active;
  final DateTime? expiresAt;
}

final premiumInfoProvider = StateNotifierProvider<PremiumInfoNotifier, PremiumInfo>((ref) {
  return PremiumInfoNotifier();
});

class PremiumInfoNotifier extends StateNotifier<PremiumInfo> {
  PremiumInfoNotifier() : super(_fromStorage());

  static PremiumInfo _fromStorage() {
    final s = StorageService();
    return PremiumInfo(active: RottyPremium.isPremiumActive(s), expiresAt: s.premiumExpiresAt);
  }

  Future<void> refresh() async {
    state = _fromStorage();
  }
}

final rottyPremiumProvider = Provider<bool>((ref) {
  if (RottyPremium.devUnlockAll) return true;
  return ref.watch(premiumInfoProvider).active;
});

final auraFullAppProvider = StateNotifierProvider<AuraNotifier, bool>((ref) {
  return AuraNotifier(ref.read(storageServiceProvider), ref);
});

class AuraNotifier extends StateNotifier<bool> {
  AuraNotifier(this._storage, this._ref) : super(_storage.auraFullApp);
  final StorageService _storage;
  final Ref _ref;

  Future<void> set(bool v) async {
    if (!_ref.read(rottyPremiumProvider) && v) return;
    state = v;
    await _storage.setAuraFullApp(v);
  }
}

final hapticLyricsProvider = StateNotifierProvider<HapticLyricsNotifier, bool>((ref) {
  return HapticLyricsNotifier(ref.read(storageServiceProvider));
});

class HapticLyricsNotifier extends StateNotifier<bool> {
  HapticLyricsNotifier(this._storage) : super(_storage.hapticLyrics);
  final StorageService _storage;

  Future<void> set(bool v) async {
    state = v;
    await _storage.setHapticLyrics(v);
  }
}

final studioEqProvider = StateNotifierProvider<StudioEqNotifier, StudioEqState>((ref) {
  return StudioEqNotifier(ref.read(storageServiceProvider));
});

class StudioEqNotifier extends StateNotifier<StudioEqState> {
  StudioEqNotifier(this._storage) : super(_storage.loadStudioEq());
  final StorageService _storage;

  Future<void> update(StudioEqState s) async {
    state = s;
    RottyAudioEffects.bass = s.bass;
    RottyAudioEffects.treble = s.treble;
    RottyAudioEffects.vocal = s.vocal;
    RottyAudioEffects.width = s.width;
    RottyAudioEffects.orbitSpeed = s.orbitSpeed;
    RottyAudioEffects.orbit8d = s.orbit8d;
    await _storage.saveStudioEq(s);
  }

  Future<void> applyPreset(String id) async {
    final s = switch (id) {
      'bass' => const StudioEqState(bass: 0.95, treble: 0.3, width: 0.35, orbit8d: false),
      'vocal' => const StudioEqState(vocal: 0.92, bass: 0.35, treble: 0.6, orbit8d: false),
      '8d' => const StudioEqState(orbit8d: true, width: 0.9, orbitSpeed: 0.75, bass: 0.5),
      _ => const StudioEqState(orbit8d: false),
    };
    await update(s);
  }
}

final infiniteBlendProvider = StateNotifierProvider<FlagNotifier, bool>((ref) {
  return FlagNotifier(ref.read(storageServiceProvider), 'infinite_blend');
});

final dislikedIdsProvider = StateNotifierProvider<DislikedIdsNotifier, Set<String>>((ref) {
  return DislikedIdsNotifier(ref.read(storageServiceProvider));
});

class DislikedIdsNotifier extends StateNotifier<Set<String>> {
  DislikedIdsNotifier(this._storage) : super(_storage.dislikedSongIds);
  final StorageService _storage;

  Future<void> dislike(String id) async {
    state = {...state, id};
    await _storage.setDislikedSongIds(state);
  }

  Future<void> undo(String id) async {
    state = {...state}..remove(id);
    await _storage.setDislikedSongIds(state);
  }
}

final listeningStreakProvider = Provider<ListeningStreak>((ref) {
  return ref.read(storageServiceProvider).listeningStreak;
});

final vaultUnlockedProvider = StateProvider<bool>((ref) => false);

class FlagNotifier extends StateNotifier<bool> {
  FlagNotifier(this._storage, this._key) : super(_storage.getBoolFlag(_key));
  final StorageService _storage;
  final String _key;

  Future<void> set(bool v) async {
    state = v;
    await _storage.setBoolFlag(_key, v);
    if (_key == 'infinite_blend') RottyAudioEffects.infiniteBlend = v;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/modes/app_mode.dart';
import '../core/sound/sound_space.dart';
import '../core/theme/dynamic_palette.dart';
import '../models/song_model.dart';
import '../models/play_history_entry.dart';
import '../repositories/music_repository.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/audio_effects.dart';
import '../services/ai_dj_service.dart';
import 'providers.dart';

final appModeProvider = StateNotifierProvider<AppModeNotifier, RottyAppMode>((ref) {
  return AppModeNotifier(ref.read(storageServiceProvider));
});

class AppModeNotifier extends StateNotifier<RottyAppMode> {
  AppModeNotifier(this._storage) : super(_storage.appMode);
  final StorageService _storage;
  Future<void> set(RottyAppMode mode) async {
    state = mode;
    await _storage.setAppMode(mode);
  }
}

final soundSpaceProvider = StateNotifierProvider<SoundSpaceNotifier, SoundSpace>((ref) {
  return SoundSpaceNotifier(ref.read(storageServiceProvider), ref);
});

class SoundSpaceNotifier extends StateNotifier<SoundSpace> {
  SoundSpaceNotifier(this._storage, this._ref) : super(_storage.soundSpace) {
    RottyAudioEffects.applySoundSpace(state);
  }
  final StorageService _storage;
  final Ref _ref;

  Future<void> set(SoundSpace space) async {
    state = space;
    await _storage.setSoundSpace(space);
    RottyAudioEffects.applySoundSpace(space);
    try {
      final player = _ref.read(audioHandlerProvider).player;
      RottyAudioEffects.applyToPlayer(player);
      RottyAudioEffects.stopOrbit();
      RottyAudioEffects.startOrbit(player);
    } catch (_) {}
  }
}

final zenModeProvider = StateNotifierProvider<ZenModeNotifier, bool>((ref) {
  return ZenModeNotifier(ref.read(storageServiceProvider));
});

class ZenModeNotifier extends StateNotifier<bool> {
  ZenModeNotifier(this._storage) : super(_storage.zenMode);
  final StorageService _storage;
  Future<void> toggle() async {
    state = !state;
    await _storage.setZenMode(state);
  }
}

final dynamicPaletteProvider = StateNotifierProvider<DynamicPaletteNotifier, DynamicPalette>((ref) {
  return DynamicPaletteNotifier();
});

class DynamicPaletteNotifier extends StateNotifier<DynamicPalette> {
  DynamicPaletteNotifier() : super(DynamicPalette.fallback);

  Future<void> updateFromSong(SongModel? song) async {
    if (song == null || song.image.isEmpty) {
      state = DynamicPalette.fallback;
      return;
    }
    state = await DynamicPalette.fromImageUrl(song.image);
  }
}

final playHistoryProvider = StateNotifierProvider<PlayHistoryNotifier, List<PlayHistoryEntry>>((ref) {
  return PlayHistoryNotifier(ref.read(storageServiceProvider));
});

class PlayHistoryNotifier extends StateNotifier<List<PlayHistoryEntry>> {
  PlayHistoryNotifier(this._storage) : super(_storage.getPlayHistory());
  final StorageService _storage;

  Future<void> record(SongModel song) async {
    await _storage.addPlayHistory(song);
    state = _storage.getPlayHistory();
  }

  List<PlayHistoryEntry> onThisDay(DateTime now) {
    final lastYear = DateTime(now.year - 1, now.month, now.day);
    return state.where((e) {
      final d = e.playedAt;
      return d.year == lastYear.year && d.month == lastYear.month && d.day == lastYear.day;
    }).toList();
  }
}

final aiDjMoodOverrideProvider = StateProvider<AiMood?>((ref) => null);

class PartyRoomState {
  const PartyRoomState({
    this.code,
    this.queue = const [],
    this.nowPlaying,
    this.isPlaying = false,
  });
  final String? code;
  final List<SongModel> queue;
  final SongModel? nowPlaying;
  final bool isPlaying;
}

final partyRoomProvider = StateNotifierProvider<PartyRoomNotifier, PartyRoomState>((ref) {
  return PartyRoomNotifier(ref.read(storageServiceProvider), ref);
});

class PartyRoomNotifier extends StateNotifier<PartyRoomState> {
  PartyRoomNotifier(this._storage, this._ref) : super(PartyRoomState(code: _storage.activePartyRoom, queue: _queueFor(_storage.activePartyRoom))) {
    final code = _storage.activePartyRoom;
    if (code != null) _listenCloud(code);
  }

  final StorageService _storage;
  final Ref _ref;
  StreamSubscription<FirebasePartyRoom>? _partySub;

  static List<SongModel> _queueFor(String? code) =>
      code == null ? const [] : StorageService().getPartyQueue(code);

  @override
  void dispose() {
    _partySub?.cancel();
    super.dispose();
  }

  void _listenCloud(String code) {
    _partySub?.cancel();
    if (!FirebaseService.instance.isReady) return;
    _partySub = FirebaseService.instance.watchPartyRoom(code).listen((room) {
      _storage.savePartyQueue(code, room.queue);
      state = PartyRoomState(
        code: code,
        queue: room.queue,
        nowPlaying: room.nowPlaying,
        isPlaying: room.isPlaying,
      );
      if (room.nowPlaying != null) {
        _syncPlaybackLocally(room.nowPlaying!);
      }
    });
  }

  void _syncPlaybackLocally(SongModel remoteSong) async {
    try {
      final handler = _ref.read(audioHandlerProvider);
      final currentLocal = handler.currentSong;
      if (currentLocal?.id == remoteSong.id) return;

      final repo = _ref.read(musicRepositoryProvider);
      final track = await repo.resolveSong(remoteSong);
      if (track.hasPlayableUrl) {
        await handler.playSong(track, playlist: state.queue);
        _ref.read(dynamicPaletteProvider.notifier).updateFromSong(track);
      }
    } catch (e) {
      debugPrint('Party Sync: local playback sync failed: $e');
    }
  }

  Future<String> createRoom() async {
    final code = FirebaseService.instance.isReady
        ? await FirebaseService.instance.createPartyRoom()
        : 'ROTTY-${DateTime.now().millisecondsSinceEpoch % 100000}';
    await _storage.setActivePartyRoom(code);
    await _storage.savePartyQueue(code, []);
    state = PartyRoomState(code: code, queue: []);
    _listenCloud(code);
    return code;
  }

  Future<void> joinRoom(String code) async {
    if (FirebaseService.instance.isReady) {
      await FirebaseService.instance.joinPartyRoom(code);
      _listenCloud(code);
    }
    await _storage.setActivePartyRoom(code);
    state = PartyRoomState(code: code, queue: _queueFor(code));
  }

  Future<void> leaveRoom() async {
    _partySub?.cancel();
    await _storage.setActivePartyRoom(null);
    state = const PartyRoomState();
  }

  Future<void> addSong(SongModel song) async {
    final code = state.code;
    if (code == null) return;
    await _storage.addToPartyQueue(code, song);
    final q = _storage.getPartyQueue(code);
    state = PartyRoomState(code: code, queue: q, nowPlaying: state.nowPlaying, isPlaying: state.isPlaying);
    if (FirebaseService.instance.isReady) {
      await FirebaseService.instance.pushPartyQueue(code, q);
    }
  }

  Future<void> updatePlayback(SongModel song, bool isPlaying) async {
    final code = state.code;
    if (code == null) return;
    if (FirebaseService.instance.isReady) {
      await FirebaseService.instance.updatePartyPlayback(code, song, isPlaying);
    }
  }
}

final focusTimerMinutesProvider = StateProvider<int>((ref) => 25);
final sleepFadeMinutesProvider = StateProvider<int>((ref) => 30);
final lyricsTranslateEnabledProvider = StateProvider<bool>((ref) => true);
final concertHeadphonesPresetProvider = StateProvider<bool>((ref) => false);

/// Scene discovery presets
enum DiscoverScene {
  lateNight('Late Night', 'lofi night hindi', Icons.nightlight_round),
  highway('Highway', 'road trip hindi english', Icons.directions_car_rounded),
  gym('Gym Beast', 'workout gym hindi punjabi', Icons.fitness_center_rounded),
  heartbreak('Heartbreak', 'sad breakup hindi songs', Icons.favorite_border_rounded);

  const DiscoverScene(this.title, this.query, this.icon);
  final String title;
  final String query;
  final IconData icon;
}

final sceneSongsProvider = FutureProvider.family<List<SongModel>, DiscoverScene>((ref, scene) async {
  return ref.read(musicRepositoryProvider).searchSongs(scene.query);
});

/// Offline mood packs
class OfflineMoodPack {
  final String id;
  final String title;
  final String emoji;
  final String query;
  final int targetCount;

  const OfflineMoodPack({
    required this.id,
    required this.title,
    required this.emoji,
    required this.query,
    required this.targetCount,
  });
}

const offlineMoodPacks = [
  OfflineMoodPack(id: 'train', title: 'Train Trip', emoji: '🚆', query: 'travel chill hindi', targetCount: 25),
  OfflineMoodPack(id: 'gym', title: 'Gym', emoji: '💪', query: 'workout punjabi hindi', targetCount: 25),
  OfflineMoodPack(id: 'rain', title: 'Rain Night', emoji: '🌧️', query: 'rain sad lofi hindi', targetCount: 25),
];

final offlinePackIdsProvider = StateNotifierProvider.family<OfflinePackNotifier, List<String>, String>((ref, packId) {
  return OfflinePackNotifier(ref.read(storageServiceProvider), ref.read(musicRepositoryProvider), packId);
});

class OfflinePackNotifier extends StateNotifier<List<String>> {
  OfflinePackNotifier(this._storage, this._repo, this.packId) : super(_storage.getOfflinePackIds(packId));
  final StorageService _storage;
  final MusicRepository _repo;
  final String packId;

  Future<void> cachePack(OfflineMoodPack pack) async {
    final songs = await _repo.searchSongs(pack.query);
    final ids = songs.take(pack.targetCount).map((s) => s.id).toList();
    await _storage.setOfflinePackIds(packId, ids);
    state = ids;
  }
}

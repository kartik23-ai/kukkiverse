import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/groq_ai_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/modes/app_mode.dart';
import '../core/sound/sound_space.dart';
import '../core/theme/dynamic_palette.dart';
import '../models/song_model.dart';
import '../models/play_history_entry.dart';
import '../repositories/music_repository.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/supabase_service.dart';
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
    this.hostId,
    this.kicked = false,
  });
  final String? code;
  final List<SongModel> queue;
  final SongModel? nowPlaying;
  final bool isPlaying;
  final String? hostId;
  final bool kicked;

  bool get isHost => hostId != null && hostId == FirebaseService.instance.userId;
}

final partyRoomProvider = StateNotifierProvider<PartyRoomNotifier, PartyRoomState>((ref) {
  final notifier = PartyRoomNotifier(ref.read(storageServiceProvider), ref);
  
  ref.listen<SongModel?>(nowPlayingProvider, (previous, next) {
    notifier.onLocalSongChange(next);
  });
  
  ref.listen<bool>(isPlayingProvider, (previous, next) {
    notifier.onLocalPlayingChange(next);
  });
  
  return notifier;
});

final partySearchActiveProvider = StateProvider.autoDispose<bool>((ref) => false);

class PartyRoomNotifier extends StateNotifier<PartyRoomState> {
  PartyRoomNotifier(this._storage, this._ref) : super(PartyRoomState(code: _storage.activePartyRoom, queue: _queueFor(_storage.activePartyRoom))) {
    final code = _storage.activePartyRoom;
    if (code != null) _listenCloud(code);
  }

  final StorageService _storage;
  final Ref _ref;
  StreamSubscription<FirebasePartyRoom>? _partySub;
  StreamSubscription<bool>? _selfStatusSub;
  DateTime? _lastLocalActionTime;
  bool _hasVerifiedMembership = false;
  DateTime? _subStartTime;
  Future<void>? _syncChain; // Sequential sync event execution chain to prevent parallel just_audio overlap issues

  static List<SongModel> _queueFor(String? code) =>
      code == null ? const [] : StorageService().getPartyQueue(code);

  @override
  void dispose() {
    _partySub?.cancel();
    _selfStatusSub?.cancel();
    super.dispose();
  }

  void clearKicked() {
    state = const PartyRoomState();
  }

  void _listenCloud(String code) {
    _partySub?.cancel();
    _selfStatusSub?.cancel();
    _hasVerifiedMembership = false;
    _subStartTime = DateTime.now();
    
    _partySub = SupabaseService.instance.watchPartyRoom(code).listen(
      (room) {
        _storage.savePartyQueue(code, room.queue);
        state = PartyRoomState(
          code: code,
          queue: room.queue,
          nowPlaying: room.nowPlaying,
          isPlaying: room.isPlaying,
          hostId: room.hostId,
          kicked: false,
        );
        if (!state.isHost && room.nowPlaying != null) {
          _syncPlaybackLocally(room.nowPlaying!, room.isPlaying);
        }
      },
      onError: (err) {
        debugPrint('PartyRoomNotifier watchPartyRoom error: $err');
      },
    );

    // Listen to self member status. If deleted by host, auto-kick.
    _selfStatusSub = SupabaseService.instance.watchSelfMemberStatus(code).listen(
      (exists) {
        if (exists) {
          _hasVerifiedMembership = true;
        }
        if (state.code != null && !state.isHost && !exists) {
          final elapsed = _subStartTime != null ? DateTime.now().difference(_subStartTime!) : Duration.zero;
          if (_hasVerifiedMembership || elapsed > const Duration(seconds: 4)) {
            _partySub?.cancel();
            _selfStatusSub?.cancel();
            _storage.setActivePartyRoom(null);
            state = const PartyRoomState(kicked: true);
          }
        }
      },
      onError: (err) {
        debugPrint('PartyRoomNotifier watchSelfMemberStatus error: $err');
      },
    );
  }

  void _syncPlaybackLocally(SongModel remoteSong, bool remotePlaying) {
    Future<void> nextSync() async {
      if (_lastLocalActionTime != null &&
          DateTime.now().difference(_lastLocalActionTime!) < const Duration(seconds: 5)) {
        debugPrint('Party Sync: Ignoring remote sync event within 5s of local action to prevent race condition');
        return;
      }
      try {
        final handler = _ref.read(audioHandlerProvider);
        final currentLocal = handler.currentSong;
        
        if (currentLocal?.id != remoteSong.id) {
          final repo = _ref.read(musicRepositoryProvider);
          final track = await repo.resolveSong(remoteSong);
          if (track.hasPlayableUrl) {
            await handler.playSong(track, playlist: state.queue);
            _ref.read(dynamicPaletteProvider.notifier).updateFromSong(track);
          }
        }

        final localPlaying = handler.playbackState.value.playing;
        if (localPlaying != remotePlaying) {
          if (remotePlaying) {
            await handler.play();
          } else {
            await handler.pause();
          }
        }
      } catch (e) {
        debugPrint('Party Sync: local playback sync failed: $e');
      }
    };

    _syncChain = (_syncChain ?? Future.value()).then((_) => nextSync());
  }

  void onLocalSongChange(SongModel? next) {
    final code = state.code;
    if (code == null || next == null) return;
    if (!state.isHost) return; // Only host updates playback state in Firestore
    if (next.id == state.nowPlaying?.id) return;
    
    _lastLocalActionTime = DateTime.now();
    final isPlaying = _ref.read(isPlayingProvider);
    updatePlayback(next, isPlaying);
  }

  void onLocalPlayingChange(bool next) {
    final code = state.code;
    if (code == null) return;
    if (!state.isHost) return; // Only host updates playback state in Firestore
    if (next == state.isPlaying) return;
    
    _lastLocalActionTime = DateTime.now();
    final currentSong = _ref.read(audioHandlerProvider).currentSong;
    if (currentSong != null) {
      updatePlayback(currentSong, next);
    }
  }

  Future<String> createRoom() async {
    _lastLocalActionTime = DateTime.now();
    final code = await SupabaseService.instance.createPartyRoom();
    await _storage.setActivePartyRoom(code);
    await _storage.savePartyQueue(code, []);
    state = PartyRoomState(code: code, queue: [], hostId: FirebaseService.instance.userId);
    _listenCloud(code);
    return code;
  }

  Future<void> joinRoom(String code) async {
    _lastLocalActionTime = DateTime.now();
    await SupabaseService.instance.joinPartyRoom(code);
    _listenCloud(code);
    await _storage.setActivePartyRoom(code);
    state = PartyRoomState(code: code, queue: _queueFor(code));
  }

  Future<void> leaveRoom() async {
    _lastLocalActionTime = DateTime.now();
    final code = state.code;
    if (code != null) {
      try {
        await SupabaseService.instance.removeMemberFromPartyRoom(code);
      } catch (_) {}
    }
    _partySub?.cancel();
    _selfStatusSub?.cancel();
    await _storage.setActivePartyRoom(null);
    state = const PartyRoomState();
  }

  Future<void> addSong(SongModel song) async {
    final code = state.code;
    if (code == null) return;
    _lastLocalActionTime = DateTime.now();
    await _storage.addToPartyQueue(code, song);
    final q = _storage.getPartyQueue(code);
    state = PartyRoomState(code: code, queue: q, nowPlaying: state.nowPlaying, isPlaying: state.isPlaying, hostId: state.hostId);
    await SupabaseService.instance.pushPartyQueue(code, q);
  }

  Future<void> setQueue(List<SongModel> songs) async {
    final code = state.code;
    if (code == null) return;
    _lastLocalActionTime = DateTime.now();
    await _storage.savePartyQueue(code, songs);
    state = PartyRoomState(
      code: code,
      queue: songs,
      nowPlaying: state.nowPlaying,
      isPlaying: state.isPlaying,
      hostId: state.hostId,
    );
    await SupabaseService.instance.pushPartyQueue(code, songs);
  }

  Future<void> addSongs(List<SongModel> songs) async {
    final code = state.code;
    if (code == null) return;
    _lastLocalActionTime = DateTime.now();
    final q = List<SongModel>.from(state.queue);
    for (final song in songs) {
      if (!q.any((s) => s.id == song.id)) {
        q.add(song);
      }
    }
    await _storage.savePartyQueue(code, q);
    state = PartyRoomState(
      code: code,
      queue: q,
      nowPlaying: state.nowPlaying,
      isPlaying: state.isPlaying,
      hostId: state.hostId,
    );
    await SupabaseService.instance.pushPartyQueue(code, q);
  }

  Future<void> removeSong(SongModel song) async {
    final code = state.code;
    if (code == null || !state.isHost) return;
    _lastLocalActionTime = DateTime.now();
    final q = List<SongModel>.from(state.queue)..removeWhere((s) => s.id == song.id);
    _storage.savePartyQueue(code, q);
    state = PartyRoomState(code: code, queue: q, nowPlaying: state.nowPlaying, isPlaying: state.isPlaying, hostId: state.hostId);
    await SupabaseService.instance.pushPartyQueue(code, q);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final code = state.code;
    if (code == null || !state.isHost) return;
    _lastLocalActionTime = DateTime.now();
    
    final q = List<SongModel>.from(state.queue);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = q.removeAt(oldIndex);
    q.insert(newIndex, item);
    
    _storage.savePartyQueue(code, q);
    state = PartyRoomState(code: code, queue: q, nowPlaying: state.nowPlaying, isPlaying: state.isPlaying, hostId: state.hostId);
    await SupabaseService.instance.pushPartyQueue(code, q);
  }

  Future<void> kickMember(String targetUid) async {
    final code = state.code;
    if (code == null || !state.isHost) return;
    try {
      debugPrint('ROTTY PARTY: Attempting to kick member $targetUid from room $code');
      await SupabaseService.instance.kickMemberFromPartyRoom(code, targetUid);
      debugPrint('ROTTY PARTY: Kicked member $targetUid successfully');
    } catch (e) {
      debugPrint('ROTTY PARTY ERROR: Failed to kick member: $e');
      rethrow;
    }
  }

  Future<void> updatePlayback(SongModel song, bool isPlaying) async {
    final code = state.code;
    if (code == null || !state.isHost) return;
    _lastLocalActionTime = DateTime.now();
    await SupabaseService.instance.updatePartyPlayback(code, song, isPlaying);
  }
}

final focusTimerMinutesProvider = StateProvider<int>((ref) => 25);
final sleepFadeMinutesProvider = StateProvider<int>((ref) => 30);
final lyricsTranslateEnabledProvider = StateProvider<bool>((ref) => true);
final concertHeadphonesPresetProvider = StateProvider<bool>((ref) => false);
final concertFlashlightEnabledProvider = StateProvider<bool>((ref) => true);
final globalShakeToSkipProvider = StateProvider<bool>((ref) => false);

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

final supportOverlayVisibilityProvider = StateNotifierProvider<SupportOverlayVisibilityNotifier, bool>((ref) {
  return SupportOverlayVisibilityNotifier();
});

class SupportOverlayVisibilityNotifier extends StateNotifier<bool> {
  SupportOverlayVisibilityNotifier() : super(false) {
    _init();
  }

  void _init() {
    final storage = StorageService();
    // 1. Absolute Suppressing for Verified Supporters
    if (storage.isSupporter) {
      storage.setHasSeenSupportOverlay(true);
      storage.setLastSeenVersion('1.2.0');
      state = false;
      return;
    }

    // 2. Fresh Install / Version Update reset
    if (storage.lastSeenVersion != '1.2.0') {
      storage.setHasSeenSupportOverlay(false);
      state = true;
      return;
    }

    // 3. Normal launch seen check
    state = !storage.hasSeenSupportOverlay;
  }

  void dismiss() {
    state = false;
  }
}

final albumArtRipplesProvider = StateNotifierProvider<AlbumArtRipplesNotifier, bool>((ref) {
  return AlbumArtRipplesNotifier(ref.read(storageServiceProvider));
});

class AlbumArtRipplesNotifier extends StateNotifier<bool> {
  AlbumArtRipplesNotifier(this._storage) : super(_storage.albumArtRipples);
  final StorageService _storage;

  Future<void> toggle(bool val) async {
    state = val;
    await _storage.setAlbumArtRipples(val);
  }
}

final eqMeshVisualizerEnabledProvider = StateNotifierProvider<EqMeshVisualizerEnabledNotifier, bool>((ref) {
  return EqMeshVisualizerEnabledNotifier(ref.read(storageServiceProvider));
});

class EqMeshVisualizerEnabledNotifier extends StateNotifier<bool> {
  EqMeshVisualizerEnabledNotifier(this._storage) : super(_storage.eqMeshVisualizer);
  final StorageService _storage;

  Future<void> toggle(bool val) async {
    state = val;
    await _storage.setEqMeshVisualizer(val);
  }
}

class AiRadioState {
  final String title;
  final String description;
  final List<SongModel> songs;
  final bool isUnlocked;
  final bool isLoading;

  const AiRadioState({
    required this.title,
    required this.description,
    required this.songs,
    required this.isUnlocked,
    required this.isLoading,
  });

  factory AiRadioState.locked() {
    return const AiRadioState(
      title: 'AI Taste Radio',
      description: 'Play at least 10 songs to unlock your personalized AI Radio.',
      songs: [],
      isUnlocked: false,
      isLoading: false,
    );
  }

  factory AiRadioState.loading() {
    return const AiRadioState(
      title: 'AI Taste Radio',
      description: 'Synthesizing your listening DNA...',
      songs: [],
      isUnlocked: true,
      isLoading: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'songs': songs.map((s) => s.toJson()).toList(),
    };
  }

  factory AiRadioState.fromJson(Map<String, dynamic> json) {
    final songsList = json['songs'] as List? ?? [];
    return AiRadioState(
      title: json['title']?.toString() ?? 'AI Taste Radio',
      description: json['description']?.toString() ?? '',
      songs: songsList.map((e) => SongModel.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      isUnlocked: true,
      isLoading: false,
    );
  }
}

class AiTasteRadioNotifier extends StateNotifier<AiRadioState> {
  AiTasteRadioNotifier(this._ref) : super(AiRadioState.locked()) {
    _init();
  }

  final Ref _ref;

  void _init() {
    final history = _ref.read(playHistoryProvider);
    final storage = _ref.read(storageServiceProvider);

    if (history.length < 10) {
      state = AiRadioState.locked();
      return;
    }

    final cache = storage.aiRadioCache;
    if (cache.isNotEmpty) {
      try {
        final decoded = json.decode(cache);
        state = AiRadioState.fromJson(decoded);
        return;
      } catch (_) {}
    }

    // Unlocked but not loaded yet
    state = const AiRadioState(
      title: 'AI Taste Radio',
      description: 'Your personalized radio is ready to synthesize.',
      songs: [],
      isUnlocked: true,
      isLoading: false,
    );
  }

  void checkStatus() {
    final history = _ref.read(playHistoryProvider);
    if (history.length >= 10 && !state.isUnlocked) {
      state = const AiRadioState(
        title: 'AI Taste Radio',
        description: 'Your personalized radio is ready to synthesize.',
        songs: [],
        isUnlocked: true,
        isLoading: false,
      );
    } else if (history.length < 10 && state.isUnlocked) {
      state = AiRadioState.locked();
    }
  }

  Future<void> generateRadio() async {
    final history = _ref.read(playHistoryProvider);
    if (history.length < 10) return;

    state = AiRadioState.loading();

    try {
      final storage = _ref.read(storageServiceProvider);
      final groq = GroqAiService();
      final favorites = _ref.read(favoritesProvider);

      final listenedTitles = history.map((e) => e.song.title).toList();
      final listenedArtists = history.map((e) => e.song.artist).toList();
      final favoriteTitles = favorites.map((e) => e.title).toList();
      final favoriteArtists = favorites.map((e) => e.artist).toList();

      final res = await groq.generateAiRadio(
        listenedTitles: listenedTitles,
        listenedArtists: listenedArtists,
        favoriteTitles: favoriteTitles,
        favoriteArtists: favoriteArtists,
      );

      if (res != null) {
        final title = res['radioTitle']?.toString() ?? 'AI Taste Radio';
        final description = res['vibeDescription']?.toString() ?? 'A custom synthesized blend of your favorite frequencies.';
        final recommendedQueries = (res['recommendedQueries'] as List? ?? []).cast<String>();

        final songs = <SongModel>[];
        final api = _ref.read(apiServiceProvider);

        // Fetch recommendations in parallel
        final searchFutures = recommendedQueries.take(8).map((query) async {
          try {
            final results = await api.searchSongs(query, limit: 1);
            if (results.isNotEmpty) {
              return results.first;
            }
          } catch (_) {}
          return null;
        });

        final results = await Future.wait(searchFutures);
        for (final song in results) {
          if (song != null && !songs.any((s) => s.id == song.id)) {
            songs.add(song);
          }
        }

        final newState = AiRadioState(
          title: title,
          description: description,
          songs: songs,
          isUnlocked: true,
          isLoading: false,
        );

        state = newState;
        await storage.setAiRadioCache(json.encode(newState.toJson()));
      } else {
        state = const AiRadioState(
          title: 'AI Taste Radio',
          description: 'Failed to synthesize radio. Try again later.',
          songs: [],
          isUnlocked: true,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('Error generating AI Radio: $e');
      state = const AiRadioState(
        title: 'AI Taste Radio',
        description: 'Failed to synthesize radio. Try again later.',
        songs: [],
        isUnlocked: true,
        isLoading: false,
      );
    }
  }
}

final aiTasteRadioProvider = StateNotifierProvider<AiTasteRadioNotifier, AiRadioState>((ref) {
  final notifier = AiTasteRadioNotifier(ref);
  ref.listen<List<PlayHistoryEntry>>(playHistoryProvider, (prev, next) {
    notifier.checkStatus();
  });
  return notifier;
});

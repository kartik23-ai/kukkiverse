import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import 'api_service.dart';
import 'audio_effects.dart';
import 'ai_dj_service.dart';
import 'storage_service.dart';

class RottyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // Android-only equalizer — skip on desktop to avoid MissingPluginException
  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  final AndroidEqualizer? _eq = _isMobile ? RottyAudioEffects.createEqualizer() : null;
  late final AudioPlayer _player = _isMobile
      ? AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [_eq!]))
      : AudioPlayer();
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  late final AiDjService _aiDj = AiDjService(_api);
  final List<SongModel> _queue = [];
  final List<SongModel> _history = [];

  /// Bumps when queue structure changes — UI listens for reorder/remove.
  final ValueNotifier<int> queueVersion = ValueNotifier(0);

  int _currentIndex = -1;
  bool _isShuffleOn = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  double _speed = 1.0;

  AudioPlayer get player => _player;
  List<SongModel> get songQueue => List.unmodifiable(_queue);
  List<SongModel> get history => List.unmodifiable(_history);
  int get currentIndex => _currentIndex;
  SongModel? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;

  RottyAudioHandler() {
    _init();
  }

  void _bumpQueue() {
    queueVersion.value++;
    queue.add(_queue.map(_songToMediaItem).toList());
  }

  Future<void> _init() async {
    // AudioSession may not be supported on desktop
    if (_isMobile) {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      } catch (_) {}
    }

    playbackState.add(PlaybackState(
      controls: [MediaControl.play],
      systemActions: const {
        MediaAction.seek,
        MediaAction.playPause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      processingState: AudioProcessingState.idle,
      playing: false,
    ));

    _player.playbackEventStream.listen((event) => _broadcastState());
    _player.playingStream.listen((_) => _broadcastState());
    _player.processingStateStream.listen((state) {
      _broadcastState();
      if (state == ProcessingState.completed) _handleCompletion();
    });
  }

  Future<SongModel> _resolveSongUrl(SongModel song) async {
    if (song.hasPlayableUrl) return song;
    final details = await _api.getSongDetails(song.id);
    if (details != null && details.hasPlayableUrl) return details;
    return song;
  }

  Future<void> playSong(SongModel song, {List<SongModel>? playlist, int? index}) async {
    try {
      if (playlist != null && playlist.isNotEmpty) {
        _queue
          ..clear()
          ..addAll(playlist);
        _currentIndex = index ?? _queue.indexWhere((s) => s.id == song.id);
        if (_currentIndex < 0) {
          _queue.insert(0, song);
          _currentIndex = 0;
        }
      } else if (!_queue.any((s) => s.id == song.id)) {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
      } else {
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      }

      var activeSong = await _resolveSongUrl(_queue[_currentIndex]);
      _queue[_currentIndex] = activeSong;

      if (!activeSong.hasPlayableUrl) {
        debugPrint('ROTTY: No playable URL for ${activeSong.title} (${activeSong.id})');
        return;
      }

      if (_history.isEmpty || _history.first.id != activeSong.id) {
        _history.insert(0, activeSong);
        if (_history.length > 80) _history.removeLast();
      }

      mediaItem.add(_songToMediaItem(activeSong));
      _bumpQueue();

      final Map<String, String>? httpHeaders = Platform.isWindows ? null : const {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Referer': 'https://www.jiosaavn.com/',
      };

      // Release any active stream resources on Windows before loading to avoid resource locks
      try {
        await _player.stop();
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {}

      // Robust loading with timeout and re-resolve retry for Windows stability
      try {
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(activeSong.url),
            headers: httpHeaders,
            tag: _songToMediaItem(activeSong),
          ),
          preload: !Platform.isWindows, // Do not preload on Windows to prevent WinRT thread hang
        ).timeout(const Duration(milliseconds: 1800));
      } catch (e) {
        debugPrint('ROTTY PLAYBACK: Initial load failed/timed out ($e). Fetching fresh URL and retrying...');
        try {
          await _player.stop();
          await Future.delayed(const Duration(milliseconds: 150));
          
          // Re-resolve from API to handle expired links
          final freshSong = await _api.getSongDetails(activeSong.id);
          if (freshSong != null && freshSong.hasPlayableUrl) {
            activeSong = freshSong;
            _queue[_currentIndex] = activeSong;
            mediaItem.add(_songToMediaItem(activeSong));
            _bumpQueue();
          }

          // Retry setAudioSource
          await _player.setAudioSource(
            AudioSource.uri(
              Uri.parse(activeSong.url),
              headers: httpHeaders,
              tag: _songToMediaItem(activeSong),
            ),
            preload: !Platform.isWindows, // Do not preload on Windows to prevent WinRT thread hang
          ).timeout(const Duration(seconds: 3));
        } catch (retryError) {
          debugPrint('ROTTY PLAYBACK: Retry load failed: $retryError');
          return;
        }
      }

      await _player.setSpeed(_speed);
      await _player.play();
      RottyAudioEffects.applyToPlayer(_player);
      RottyAudioEffects.stopOrbit();
      RottyAudioEffects.startOrbit(_player);
    } catch (e, st) {
      debugPrint('Playback Error: $e\n$st');
    }
  }

  /// Adds unique songs after current track without wiping existing queue.
  Future<int> appendUpcoming(List<SongModel> songs) async {
    if (_currentIndex < 0 || songs.isEmpty) return 0;
    final existing = _queue.map((s) => s.id).toSet();
    var added = 0;
    for (final s in songs) {
      if (existing.add(s.id)) {
        _queue.add(s);
        added++;
      }
    }
    if (added > 0) _bumpQueue();
    return added;
  }

  Future<void> replaceUpcoming(List<SongModel> songs, {bool keepCurrent = true}) async {
    if (songs.isEmpty) return;
    final current = keepCurrent && _currentIndex >= 0 && _currentIndex < _queue.length
        ? _queue[_currentIndex]
        : null;

    _queue.clear();
    if (current != null) {
      _queue.add(current);
      _currentIndex = 0;
      for (final s in songs) {
        if (s.id != current.id) _queue.add(s);
      }
    } else {
      _queue.addAll(songs);
      _currentIndex = 0;
    }
    _bumpQueue();
  }

  void addToQueueNext(SongModel song) {
    if (_currentIndex < 0) {
      _queue.add(song);
    } else {
      _queue.insert(_currentIndex + 1, song);
    }
    _bumpQueue();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    final wasCurrent = index == _currentIndex;
    _queue.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
    if (wasCurrent) {
      if (_queue.isEmpty) {
        _currentIndex = -1;
        _player.stop();
      } else {
        _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
        playSong(_queue[_currentIndex], index: _currentIndex);
      }
    } else {
      _bumpQueue();
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (oldIndex == newIndex) return;

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    _bumpQueue();
  }

  @override
  Future<void> play() async {
    final song = currentSong;
    if (_player.processingState == ProcessingState.idle && song != null) {
      debugPrint('ROTTY PLAYBACK: Player idle on play. Reloading current song: ${song.title}');
      await playSong(song, index: _currentIndex);
    } else {
      await _player.play();
      RottyAudioEffects.applyToPlayer(_player);
      RottyAudioEffects.stopOrbit();
      if (RottyAudioEffects.orbit8d) {
        RottyAudioEffects.startOrbit(_player);
      }
    }
  }

  @override
  Future<void> pause() async {
    RottyAudioEffects.stopOrbit();
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    RottyAudioEffects.stopOrbit();
    await _player.stop();
    return super.stop();
  }


  Future<void> triggerAutoplayIfNeeded() async {
    if (!_storage.aiDjEnabled) return;
    if (_currentIndex < 0 || _queue.isEmpty) return;
    
    // Trigger autoplay when reaching the last song in repeat-off mode
    if (_currentIndex == _queue.length - 1 && _repeatMode == AudioServiceRepeatMode.none) {
      debugPrint('ROTTY SMART AUTOPLAY: Reached end of queue. Generating smart recommendations...');
      try {
        final current = currentSong;
        final recent = _storage.getRecentSongs();
        final favorites = _storage.getFavorites();
        final excludeIds = _queue.map((s) => s.id).toSet();
        
        // Exclude disliked songs
        excludeIds.addAll(_storage.dislikedSongIds);
        
        // Exclude history
        for (final s in _history) {
          excludeIds.add(s.id);
        }
        
        final recommended = await _aiDj.buildSmartQueue(
          nowPlaying: current,
          recent: recent,
          favorites: favorites,
          excludeIds: excludeIds,
          limit: 10,
        );
        
        if (recommended.isNotEmpty) {
          debugPrint('ROTTY SMART AUTOPLAY: Successfully recommended ${recommended.length} songs');
          await appendUpcoming(recommended);
        } else {
          debugPrint('ROTTY SMART AUTOPLAY: No recommended songs returned.');
        }
      } catch (e) {
        debugPrint('ROTTY SMART AUTOPLAY ERROR: $e');
      }
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    if (_currentIndex == _queue.length - 1 && _repeatMode == AudioServiceRepeatMode.none) {
      // Reached the end. Autoplay first so the queue expands, then go next
      await triggerAutoplayIfNeeded();
    }

    var next = _currentIndex + 1;
    if (next >= _queue.length) next = 0;
    if (RottyAudioEffects.infiniteBlend && _player.playing) {
      await RottyAudioEffects.fadeVolume(_player, to: 0.08, ms: 2200);
    }
    await playSong(_queue[next], index: next);
    if (RottyAudioEffects.infiniteBlend) {
      await RottyAudioEffects.fadeVolume(_player, to: 1.0, ms: 800);
      RottyAudioEffects.applyToPlayer(_player);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    var prev = _currentIndex - 1;
    if (prev < 0) prev = _queue.length - 1;
    await playSong(_queue[prev], index: prev);
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _player.setSpeed(speed);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    await _player.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      _ => LoopMode.off,
    });
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _isShuffleOn = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(_isShuffleOn);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  void _handleCompletion() {
    if (_repeatMode == AudioServiceRepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      if (_currentIndex == _queue.length - 1 && _repeatMode == AudioServiceRepeatMode.none) {
        triggerAutoplayIfNeeded().then((_) {
          skipToNext();
        });
      } else {
        skipToNext();
      }
    }
  }

  MediaItem _songToMediaItem(SongModel song) {
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      artUri: song.image.isNotEmpty ? Uri.parse(song.image) : null,
      duration: song.duration.inSeconds > 0 ? song.duration : null,
    );
  }

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      repeatMode: _repeatMode,
      shuffleMode: _isShuffleOn ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    ));
  }
}

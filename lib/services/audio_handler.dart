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
  final List<SongModel> _originalContextQueue = [];
  final List<SongModel> _contextQueue = [];
  final List<SongModel> _userQueue = [];
  SongModel? _currentUserSong;
  final List<SongModel> _history = [];

  /// Bumps when queue structure changes — UI listens for reorder/remove.
  final ValueNotifier<int> queueVersion = ValueNotifier(0);

  int _currentIndex = -1;
  bool _isShuffleOn = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  double _speed = 1.0;

  AudioPlayer get player => _player;

  List<SongModel> get songQueue {
    final list = <SongModel>[];
    if (_currentIndex >= 0 && _currentIndex < _contextQueue.length) {
      list.addAll(_contextQueue.sublist(0, _currentIndex + 1));
    } else if (_currentIndex >= 0) {
      list.addAll(_contextQueue);
    }
    if (_currentUserSong != null) {
      list.add(_currentUserSong!);
    }
    list.addAll(_userQueue);
    if (_currentIndex >= -1 && _currentIndex + 1 < _contextQueue.length) {
      list.addAll(_contextQueue.sublist(_currentIndex + 1));
    }
    return list;
  }

  List<SongModel> get userQueue => List.unmodifiable(_userQueue);
  List<SongModel> get contextQueue => List.unmodifiable(_contextQueue);
  List<SongModel> get originalContextQueue => List.unmodifiable(_originalContextQueue);
  List<SongModel> get history => List.unmodifiable(_history);

  int get currentIndex {
    if (songQueue.isEmpty) return -1;
    if (_currentUserSong != null) {
      return _currentIndex + 1;
    }
    return _currentIndex;
  }

  SongModel? get currentSong =>
      _currentUserSong ??
      (_currentIndex >= 0 && _currentIndex < _contextQueue.length
          ? _contextQueue[_currentIndex]
          : null);

  RottyAudioHandler() {
    _init();
  }

  void _bumpQueue() {
    queueVersion.value++;
    queue.add(songQueue.map(_songToMediaItem).toList());
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
    if (song.id.startsWith('spotify_track_') || song.url.isEmpty) {
      final query = '${song.title} ${song.artist}';
      try {
        final results = await _api.searchSongs(query, limit: 1);
        if (results.isNotEmpty) {
          final saavnSong = results.first;
          final details = await _api.getSongDetails(saavnSong.id);
          if (details != null && details.hasPlayableUrl) {
            return song.copyWith(url: details.url);
          }
        }
      } catch (e) {
        debugPrint('ROTTY: Error resolving Spotify track: $e');
      }
      return song;
    }

    if (song.hasPlayableUrl) return song;
    final details = await _api.getSongDetails(song.id);
    if (details != null && details.hasPlayableUrl) return details;
    return song;
  }

  Future<void> _playActiveSong(SongModel song) async {
    try {
      var activeSong = await _resolveSongUrl(song);
      
      // Update the active song reference in the corresponding queue
      if (_currentUserSong != null && _currentUserSong!.id == activeSong.id) {
        _currentUserSong = activeSong;
      } else if (_currentIndex >= 0 && _currentIndex < _contextQueue.length && _contextQueue[_currentIndex].id == activeSong.id) {
        _contextQueue[_currentIndex] = activeSong;
      }

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

      try {
        await _player.stop();
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {}

      try {
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(activeSong.url),
            headers: httpHeaders,
            tag: _songToMediaItem(activeSong),
          ),
          preload: !Platform.isWindows,
        ).timeout(const Duration(milliseconds: 1800));
      } catch (e) {
        debugPrint('ROTTY PLAYBACK: Initial load failed/timed out ($e). Fetching fresh URL and retrying...');
        try {
          await _player.stop();
          await Future.delayed(const Duration(milliseconds: 150));
          
          final freshSong = await _api.getSongDetails(activeSong.id);
          if (freshSong != null && freshSong.hasPlayableUrl) {
            activeSong = freshSong;
            if (_currentUserSong != null && _currentUserSong!.id == activeSong.id) {
              _currentUserSong = activeSong;
            } else if (_currentIndex >= 0 && _currentIndex < _contextQueue.length && _contextQueue[_currentIndex].id == activeSong.id) {
              _contextQueue[_currentIndex] = activeSong;
            }
            mediaItem.add(_songToMediaItem(activeSong));
            _bumpQueue();
          }

          await _player.setAudioSource(
            AudioSource.uri(
              Uri.parse(activeSong.url),
              headers: httpHeaders,
              tag: _songToMediaItem(activeSong),
            ),
            preload: !Platform.isWindows,
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

  Future<void> playSong(SongModel song, {List<SongModel>? playlist, int? index}) async {
    if (playlist != null && playlist.isNotEmpty) {
      _originalContextQueue.clear();
      _originalContextQueue.addAll(playlist);
      
      _contextQueue.clear();
      _contextQueue.addAll(playlist);
      
      _userQueue.clear();
      _currentUserSong = null;
      
      _currentIndex = index ?? _contextQueue.indexWhere((s) => s.id == song.id);
      if (_currentIndex < 0) {
        _contextQueue.insert(0, song);
        _originalContextQueue.insert(0, song);
        _currentIndex = 0;
      }
      
      if (_isShuffleOn && _contextQueue.length > 1) {
        final current = _contextQueue[_currentIndex];
        final remaining = _contextQueue.sublist(_currentIndex + 1);
        remaining.shuffle();
        _contextQueue.removeRange(_currentIndex + 1, _contextQueue.length);
        _contextQueue.addAll(remaining);
      }
    } else if (index != null) {
      final loc = _locateIndex(index);
      if (loc.section == QueueSection.pastContext) {
        _currentIndex = loc.index;
        _currentUserSong = null;
      } else if (loc.section == QueueSection.current) {
        // Tapping current song -> no-op or replay
      } else if (loc.section == QueueSection.userQueue) {
        _currentUserSong = _userQueue.removeAt(loc.index);
      } else if (loc.section == QueueSection.upcomingContext) {
        _currentIndex = loc.index;
        _currentUserSong = null;
      }
    } else {
      final userIdx = _userQueue.indexWhere((s) => s.id == song.id);
      final contextIdx = _contextQueue.indexWhere((s) => s.id == song.id);
      
      if (userIdx >= 0) {
        _currentUserSong = _userQueue.removeAt(userIdx);
      } else if (contextIdx >= 0) {
        _currentIndex = contextIdx;
        _currentUserSong = null;
      } else {
        _originalContextQueue.add(song);
        _contextQueue.add(song);
        _currentIndex = _contextQueue.length - 1;
        _currentUserSong = null;
      }
    }
    
    await _playActiveSong(_currentUserSong ?? _contextQueue[_currentIndex]);
  }

  Future<int> appendUpcoming(List<SongModel> songs, {bool isUserQueue = false}) async {
    if (songs.isEmpty) return 0;
    final existing = songQueue.map((s) => s.id).toSet();
    var added = 0;
    if (isUserQueue) {
      for (final s in songs) {
        if (existing.add(s.id)) {
          _userQueue.add(s);
          added++;
        }
      }
    } else {
      for (final s in songs) {
        if (existing.add(s.id)) {
          _contextQueue.add(s);
          _originalContextQueue.add(s);
          added++;
        }
      }
    }
    if (added > 0) _bumpQueue();
    return added;
  }

  Future<void> replaceUpcoming(List<SongModel> songs, {bool keepCurrent = true}) async {
    if (songs.isEmpty) return;
    final current = keepCurrent ? currentSong : null;

    _contextQueue.clear();
    _originalContextQueue.clear();
    _currentIndex = 0;

    if (current != null) {
      _contextQueue.add(current);
      _originalContextQueue.add(current);
      for (final s in songs) {
        if (s.id != current.id) {
          _contextQueue.add(s);
          _originalContextQueue.add(s);
        }
      }
    } else {
      _contextQueue.addAll(songs);
      _originalContextQueue.addAll(songs);
    }
    _bumpQueue();
  }

  void addToQueueNext(SongModel song) {
    _userQueue.insert(0, song);
    _bumpQueue();
  }

  QueueItemLocation _locateIndex(int index) {
    final int activeIndex = currentIndex;
    if (index < activeIndex) {
      return QueueItemLocation(QueueSection.pastContext, index);
    } else if (index == activeIndex) {
      return QueueItemLocation(QueueSection.current, -1);
    } else if (index < activeIndex + 1 + _userQueue.length) {
      return QueueItemLocation(QueueSection.userQueue, index - (activeIndex + 1));
    } else {
      final offset = index - (activeIndex + 1 + _userQueue.length);
      return QueueItemLocation(QueueSection.upcomingContext, _currentIndex + 1 + offset);
    }
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= songQueue.length) return;
    
    final loc = _locateIndex(index);
    switch (loc.section) {
      case QueueSection.pastContext:
        final removedSong = _contextQueue.removeAt(loc.index);
        _originalContextQueue.removeWhere((s) => s.id == removedSong.id);
        _currentIndex--;
        _bumpQueue();
        break;
        
      case QueueSection.current:
        if (_currentUserSong != null) {
          _currentUserSong = null;
          skipToNext();
        } else {
          final removedSong = _contextQueue.removeAt(_currentIndex);
          _originalContextQueue.removeWhere((s) => s.id == removedSong.id);
          if (_contextQueue.isEmpty) {
            _currentIndex = -1;
            _player.stop();
            _bumpQueue();
          } else {
            _currentIndex = _currentIndex.clamp(0, _contextQueue.length - 1);
            playSong(_contextQueue[_currentIndex]);
          }
        }
        break;
        
      case QueueSection.userQueue:
        _userQueue.removeAt(loc.index);
        _bumpQueue();
        break;
        
      case QueueSection.upcomingContext:
        final removedSong = _contextQueue.removeAt(loc.index);
        _originalContextQueue.removeWhere((s) => s.id == removedSong.id);
        _bumpQueue();
        break;
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= songQueue.length) return;
    if (newIndex < 0 || newIndex > songQueue.length) return;
    if (oldIndex == newIndex || oldIndex == newIndex - 1) return;

    final int targetIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    final oldLoc = _locateIndex(oldIndex);
    
    final songToMove = songQueue[oldIndex];

    // Remove from original queue
    if (oldLoc.section == QueueSection.pastContext || oldLoc.section == QueueSection.upcomingContext) {
      _contextQueue.removeAt(oldLoc.index);
      _originalContextQueue.removeWhere((s) => s.id == songToMove.id);
      if (oldLoc.index <= _currentIndex) {
        _currentIndex--;
      }
    } else if (oldLoc.section == QueueSection.userQueue) {
      _userQueue.removeAt(oldLoc.index);
    } else if (oldLoc.section == QueueSection.current) {
      if (_currentUserSong != null) {
        _currentUserSong = null;
      } else {
        _contextQueue.removeAt(_currentIndex);
        _originalContextQueue.removeWhere((s) => s.id == songToMove.id);
        _currentIndex = _currentIndex.clamp(0, _contextQueue.length - 1);
      }
    }

    // Recalculate target location in the modified queue structure
    final newLoc = _locateIndex(targetIndex);

    // Insert into target queue
    if (newLoc.section == QueueSection.pastContext) {
      _contextQueue.insert(newLoc.index, songToMove);
      _originalContextQueue.add(songToMove);
      _currentIndex++;
    } else if (newLoc.section == QueueSection.current) {
      _userQueue.insert(0, songToMove);
    } else if (newLoc.section == QueueSection.userQueue) {
      _userQueue.insert(newLoc.index, songToMove);
    } else {
      _contextQueue.insert(newLoc.index, songToMove);
      _originalContextQueue.add(songToMove);
    }

    _bumpQueue();
  }

  @override
  Future<void> play() async {
    final song = currentSong;
    if (_player.processingState == ProcessingState.idle && song != null) {
      await playSong(song);
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
    if (_currentIndex < 0 || _contextQueue.isEmpty) return;
    
    if (_currentIndex == _contextQueue.length - 1 && _repeatMode == AudioServiceRepeatMode.none) {
      debugPrint('ROTTY SMART AUTOPLAY: Reached end of queue. Generating smart recommendations...');
      try {
        final current = currentSong;
        final recent = _storage.getRecentSongs();
        final favorites = _storage.getFavorites();
        
        final excludeIds = <String>{};
        excludeIds.addAll(_contextQueue.map((s) => s.id));
        excludeIds.addAll(_userQueue.map((s) => s.id));
        excludeIds.addAll(_storage.dislikedSongIds);
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
          await appendUpcoming(recommended, isUserQueue: false);
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
    if (songQueue.isEmpty) return;

    if (RottyAudioEffects.infiniteBlend && _player.playing) {
      await RottyAudioEffects.fadeVolume(_player, to: 0.08, ms: 2200);
    }

    SongModel nextSong;
    if (_userQueue.isNotEmpty) {
      nextSong = _userQueue.removeAt(0);
      _currentUserSong = nextSong;
    } else {
      _currentUserSong = null;

      if (_currentIndex == _contextQueue.length - 1 && _repeatMode == AudioServiceRepeatMode.none) {
        await triggerAutoplayIfNeeded();
      }

      int nextIndex = _currentIndex + 1;
      if (nextIndex >= _contextQueue.length) {
        if (_repeatMode == AudioServiceRepeatMode.all) {
          nextIndex = 0;
        } else {
          await stop();
          return;
        }
      }
      _currentIndex = nextIndex;
      nextSong = _contextQueue[_currentIndex];
    }

    await _playActiveSong(nextSong);

    if (RottyAudioEffects.infiniteBlend) {
      await RottyAudioEffects.fadeVolume(_player, to: 1.0, ms: 800);
      RottyAudioEffects.applyToPlayer(_player);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (songQueue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_currentUserSong != null) {
      _currentUserSong = null;
      if (_currentIndex >= 0 && _currentIndex < _contextQueue.length) {
        await _playActiveSong(_contextQueue[_currentIndex]);
      } else {
        await _player.seek(Duration.zero);
      }
    } else {
      var prev = _currentIndex - 1;
      if (prev < 0) {
        if (_repeatMode == AudioServiceRepeatMode.all) {
          prev = _contextQueue.length - 1;
        } else {
          prev = 0;
        }
      }
      _currentIndex = prev;
      if (_currentIndex >= 0 && _currentIndex < _contextQueue.length) {
        await _playActiveSong(_contextQueue[_currentIndex]);
      } else {
        await _player.seek(Duration.zero);
      }
    }
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
    if (_isShuffleOn) {
      if (_currentIndex + 1 < _contextQueue.length) {
        final remaining = _contextQueue.sublist(_currentIndex + 1);
        remaining.shuffle();
        _contextQueue.removeRange(_currentIndex + 1, _contextQueue.length);
        _contextQueue.addAll(remaining);
      }
    } else {
      if (_currentIndex + 1 < _contextQueue.length) {
        final upcoming = _contextQueue.sublist(_currentIndex + 1);
        upcoming.sort((a, b) {
          final idxA = _originalContextQueue.indexWhere((s) => s.id == a.id);
          final idxB = _originalContextQueue.indexWhere((s) => s.id == b.id);
          return idxA.compareTo(idxB);
        });
        _contextQueue.removeRange(_currentIndex + 1, _contextQueue.length);
        _contextQueue.addAll(upcoming);
      }
    }
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
    _bumpQueue();
  }

  void _handleCompletion() {
    if (_repeatMode == AudioServiceRepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      skipToNext();
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

enum QueueSection { pastContext, current, userQueue, upcomingContext }

class QueueItemLocation {
  final QueueSection section;
  final int index;
  QueueItemLocation(this.section, this.index);
}

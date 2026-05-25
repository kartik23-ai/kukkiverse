import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import 'api_service.dart';
import 'audio_effects.dart';
import 'ai_dj_service.dart';
import 'storage_service.dart';
import 'local_audio_server.dart';

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
  bool _isCrossfading = false;
  bool _isPreResolving = false;
  String? _preResolvedSongId;
  SongModel? _preResolvedSong;
  String? _lastPreResolvedForSongId;

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

    // Safe auto-resume recovery guard for Windows Media Foundation play command ignore bug
    if (Platform.isWindows) {
      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.ready && _player.playing) {
          debugPrint('ROTTY PLAYBACK GUARD: Windows player is ready and state is playing. Re-triggering play to bypass WinRT ignore bug.');
          _player.play();
        }
      });
    }

    // Listen to position updates to trigger natural DJ crossfading early and pre-resolve next track
    _player.positionStream.listen((position) {
      final duration = _player.duration;
      if (duration != null && duration.inSeconds > 5 && _player.playing) {
        final remaining = duration - position;
        final currentId = currentSong?.id;

        // Trigger early queue refill check when we get closer to the end of the song
        if (remaining.inSeconds <= 45) {
          triggerAutoplayIfNeeded();
        }

        // 1. Pre-resolve the next song in the queue 15 seconds before the current song ends
        if (currentId != null &&
            remaining.inSeconds <= 15 &&
            _lastPreResolvedForSongId != currentId &&
            !_isPreResolving) {
          _lastPreResolvedForSongId = currentId;
          _preResolveNextSong();
        }

        // 2. Trigger natural DJ crossfade at 2.2 seconds remaining
        if (RottyAudioEffects.infiniteBlend && !_isCrossfading) {
          if (remaining.inMilliseconds <= 2200 && remaining.inMilliseconds > 0) {
            _isCrossfading = true;
            _triggerNaturalCrossfade();
          }
        }
      }
    });
  }

  Future<SongModel> _resolveSongUrl(SongModel song) async {
    // 1. Check if the song has been downloaded offline
    if (_storage.isSongDownloaded(song.id)) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        for (final ext in ['.mp4', '.m4a', '.mp3']) {
          final localFile = File('${docDir.path}/downloads/${song.id}$ext');
          if (await localFile.exists()) {
            debugPrint('ROTTY PLAYBACK: Using downloaded offline file for ${song.title} at: ${localFile.path}');
            if (Platform.isWindows) {
              final server = LocalAudioServer();
              await server.start();
              final localUrl = 'http://127.0.0.1:${server.port}/downloads/${song.id}$ext';
              debugPrint('ROTTY PLAYBACK: Windows Local Server URL: $localUrl');
              return song.copyWith(url: localUrl);
            }
            return song.copyWith(url: Uri.file(localFile.path).toString());
          }
        }
      } catch (e) {
        debugPrint('ROTTY PLAYBACK: Offline file check failed: $e');
      }
    }

    if (song.id.startsWith('spotify_track_')) {
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

    // If the song already has a playable URL, return it instantly to avoid pre-playback delay!
    if (song.hasPlayableUrl) {
      debugPrint('ROTTY PLAYBACK: Using existing playable URL for ${song.title} to minimize latency');
      return song;
    }

    // 3. For any network song, always fetch a fresh, unexpired URL right before playback
    try {
      debugPrint('ROTTY PLAYBACK: Fetching fresh unexpired URL for ${song.title} (${song.id})');
      final details = await _api.getSongDetails(song.id);
      if (details != null && details.hasPlayableUrl) {
        return details;
      }
    } catch (e) {
      debugPrint('ROTTY PLAYBACK: Failed to fetch fresh URL: $e');
    }

    return song;
  }

  Future<void> _playActiveSong(SongModel song) async {
    try {
      SongModel activeSong;
      if (_preResolvedSong != null && _preResolvedSong!.id == song.id) {
        debugPrint('ROTTY PLAYBACK: Using pre-resolved song URL for ${song.title}');
        activeSong = _preResolvedSong!;
      } else {
        activeSong = await _resolveSongUrl(song);
      }
      
      // Always reset pre-resolved cache after playing to ensure clean state
      _preResolvedSong = null;
      _preResolvedSongId = null;
      _lastPreResolvedForSongId = null;
      
      // Update the active song reference in the corresponding queue
      if (_currentUserSong != null && _currentUserSong!.id == activeSong.id) {
        _currentUserSong = activeSong;
      } else if (_currentIndex >= 0 && _currentIndex < _contextQueue.length && _contextQueue[_currentIndex].id == activeSong.id) {
        _contextQueue[_currentIndex] = activeSong;
      }

      if (!activeSong.hasPlayableUrl) {
        debugPrint('ROTTY: No playable URL for ${activeSong.title} (${activeSong.id})');
        _isCrossfading = false;
        _handlePlaybackFailure(song);
        return;
      }

      if (_history.isEmpty || _history.first.id != activeSong.id) {
        _history.insert(0, activeSong);
        if (_history.length > 80) _history.removeLast();
      }

      mediaItem.add(_songToMediaItem(activeSong));
      _bumpQueue();

      final isLocal = activeSong.url.startsWith('file:') || activeSong.url.startsWith('file://');

      if (isLocal) {
        try {
          final filePath = Uri.parse(activeSong.url).toFilePath();
          debugPrint('ROTTY PLAYBACK: Loading local downloaded file: $filePath');
          await _player.setAudioSource(
            AudioSource.file(
              filePath,
              tag: _songToMediaItem(activeSong),
            ),
          );
        } catch (e) {
          debugPrint('ROTTY PLAYBACK: Error loading local file: $e');
          _isCrossfading = false;
          _handlePlaybackFailure(song);
          return;
        }
      } else {
        final Map<String, String>? httpHeaders = Platform.isWindows ? null : const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
          'Referer': 'https://www.jiosaavn.com/',
        };

        try {
          var playUrl = activeSong.url;
          if (Platform.isWindows && playUrl.startsWith('https://')) {
            playUrl = playUrl.replaceFirst('https://', 'http://');
            debugPrint('ROTTY PLAYBACK: Forced HTTP stream URL for Windows: $playUrl');
          }

          await _player.setAudioSource(
            AudioSource.uri(
              Uri.parse(playUrl),
              headers: httpHeaders,
              tag: _songToMediaItem(activeSong),
            ),
            preload: !Platform.isWindows,
          ).timeout(const Duration(seconds: 12));
        } catch (e) {
          debugPrint('ROTTY PLAYBACK: Initial online load failed/timed out ($e). Fetching fresh URL and retrying...');
          try {
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
 
            var retryUrl = activeSong.url;
            if (Platform.isWindows && retryUrl.startsWith('https://')) {
              retryUrl = retryUrl.replaceFirst('https://', 'http://');
              debugPrint('ROTTY PLAYBACK: Forced HTTP retry stream URL for Windows: $retryUrl');
            }

            await _player.setAudioSource(
              AudioSource.uri(
                Uri.parse(retryUrl),
                headers: httpHeaders,
                tag: _songToMediaItem(activeSong),
              ),
              preload: !Platform.isWindows,
            ).timeout(const Duration(seconds: 15));
          } catch (retryError) {
            debugPrint('ROTTY PLAYBACK: Retry load failed: $retryError');
            _isCrossfading = false;
            _handlePlaybackFailure(song);
            return;
          }
        }
      }

      _isCrossfading = false;
      await _player.setVolume(RottyAudioEffects.getTargetVolume());
      await _player.setSpeed(_speed);

      if (RottyAudioEffects.infiniteBlend) {
        await _player.setVolume(0.0);
        _player.play();
        if (Platform.isWindows) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (_player.playing && _player.processingState != ProcessingState.idle) _player.play();
          });
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (_player.playing && _player.processingState != ProcessingState.idle) _player.play();
          });
          Future.delayed(const Duration(milliseconds: 3000), () {
            if (_player.playing && _player.processingState != ProcessingState.idle) _player.play();
          });
        }
        RottyAudioEffects.stopOrbit();
        // Smoothly fade in to the correct target volume
        final target = RottyAudioEffects.getTargetVolume();
        await RottyAudioEffects.fadeVolume(_player, to: target, ms: 800);
        
        // Start the 8D orbit timer only AFTER the fade-in has fully completed
        RottyAudioEffects.startOrbit(_player);
      } else {
        _player.play();
        if (Platform.isWindows) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (_player.playing && _player.processingState != ProcessingState.idle) _player.play();
          });
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (_player.playing && _player.processingState != ProcessingState.idle) _player.play();
          });
          Future.delayed(const Duration(milliseconds: 3000), () {
            if (_player.playing && _player.processingState != ProcessingState.idle) _player.play();
          });
        }
        RottyAudioEffects.applyToPlayer(_player);
        RottyAudioEffects.stopOrbit();
        RottyAudioEffects.startOrbit(_player);
      }
    } catch (e, st) {
      _isCrossfading = false;
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
      _player.play();
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
    _isCrossfading = false;
    RottyAudioEffects.stopOrbit();
    await _player.stop();
    return super.stop();
  }

  Future<void> _handlePlaybackFailure(SongModel failedSong) async {
    debugPrint('ROTTY PROTECTION: Playback failed for "${failedSong.title}". Triggering auto-skip recovery...');
    await Future.delayed(const Duration(milliseconds: 1500));
    if (currentSong?.id == failedSong.id) {
      await skipToNext();
    }
  }

  Future<void> triggerAutoplayIfNeeded() async {
    if (!_storage.aiDjEnabled) return;
    if (_currentIndex < 0 || _contextQueue.isEmpty) return;
    
    // Refill early! Trigger when we have 2 or fewer tracks remaining in the queue to ensure uninterrupted streaming
    final remainingCount = _contextQueue.length - 1 - _currentIndex;
    if (remainingCount <= 1 && _repeatMode == AudioServiceRepeatMode.none) {
      debugPrint('ROTTY SMART AUTOPLAY: Queue reaches end buffer limit. Generating 15 smart taste recommendations...');
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
          limit: 15,
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
      // If we are already crossfading naturally, we don't need a double fade.
      // But if this was a manual skip, we do a very quick 300ms fade-out.
      if (!_isCrossfading) {
        _isCrossfading = true; // prevent position listener from firing during manual transition
        
        // Stop the orbit timer so it doesn't fight with the volume fade-out
        RottyAudioEffects.stopOrbit();
        
        await RottyAudioEffects.fadeVolume(_player, to: 0.0, ms: 300);
      }
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
        if (_repeatMode == AudioServiceRepeatMode.all && _contextQueue.isNotEmpty) {
          nextIndex = 0;
        } else {
          await stop();
          return;
        }
      }
      _currentIndex = nextIndex;
      if (_currentIndex < 0 || _currentIndex >= _contextQueue.length) {
        await stop();
        return;
      }
      nextSong = _contextQueue[_currentIndex];
    }

    await _playActiveSong(nextSong);
  }

  @override
  Future<void> skipToPrevious() async {
    if (songQueue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (RottyAudioEffects.infiniteBlend && _player.playing) {
      _isCrossfading = true;
      
      // Stop the orbit timer so it doesn't fight with the volume fade-out
      RottyAudioEffects.stopOrbit();
      
      await RottyAudioEffects.fadeVolume(_player, to: 0.0, ms: 300);
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

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _player.setSpeed(speed);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    await _player.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.off, // LoopMode.off so that it completes naturally and goes to the next song!
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
    if (_isCrossfading) {
      debugPrint('ROTTY AUDIOPLAYER: Natural completion event ignored because we are already crossfading/skipping.');
      return;
    }
    if (_repeatMode == AudioServiceRepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      skipToNext();
    }
  }

  MediaItem _songToMediaItem(SongModel song) {
    final displayArtist = song.artist.isNotEmpty ? song.artist : 'ROTTY MUSIC';
    final displayAlbum = song.album.isNotEmpty ? song.album : 'ROTTY Single';
    final artLink = song.image.isNotEmpty 
        ? song.image 
        : 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=500&auto=format&fit=crop';

    return MediaItem(
      id: song.id,
      title: song.title,
      artist: displayArtist,
      album: displayAlbum,
      artUri: Uri.parse(artLink),
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

  void _preResolveNextSong() async {
    if (_isPreResolving) return;

    SongModel? nextSong;
    if (_userQueue.isNotEmpty) {
      nextSong = _userQueue.first;
    } else {
      int nextIndex = _currentIndex + 1;
      if (nextIndex >= _contextQueue.length) {
        if (_repeatMode == AudioServiceRepeatMode.all) {
          nextIndex = 0;
        } else {
          return;
        }
      }
      if (nextIndex >= 0 && nextIndex < _contextQueue.length) {
        nextSong = _contextQueue[nextIndex];
      }
    }

    if (nextSong == null) return;
    if (_preResolvedSongId == nextSong.id) return;

    _isPreResolving = true;
    _preResolvedSongId = nextSong.id;
    debugPrint('ROTTY PRE-RESOLVER: Pre-resolving next song: ${nextSong.title} (${nextSong.id})');

    try {
      final resolved = await _resolveSongUrl(nextSong);
      _preResolvedSong = resolved;
      debugPrint('ROTTY PRE-RESOLVER: Successfully pre-resolved next song: ${resolved.title}');
    } catch (e) {
      debugPrint('ROTTY PRE-RESOLVER: Error pre-resolving: $e');
    } finally {
      _isPreResolving = false;
    }
  }

  Future<void> _triggerNaturalCrossfade() async {
    final fadeFromSongId = currentSong?.id;
    if (fadeFromSongId == null) return;

    debugPrint('ROTTY CROSSFADER: Triggering natural crossfade');
    
    // Stop the 8D orbit timer so it doesn't fight with our volume fade-out
    RottyAudioEffects.stopOrbit();
    
    await RottyAudioEffects.fadeVolume(_player, to: 0.0, ms: 2000);
    
    // Verify that the user has not manually skipped or changed the song during the 2-second fade-out
    if (currentSong?.id == fadeFromSongId) {
      await skipToNext();
    } else {
      debugPrint('ROTTY CROSSFADER: Song changed during fade-out (likely due to manual skip). Aborting auto-skip.');
    }
  }
}

enum QueueSection { pastContext, current, userQueue, upcomingContext }

class QueueItemLocation {
  final QueueSection section;
  final int index;
  QueueItemLocation(this.section, this.index);
}

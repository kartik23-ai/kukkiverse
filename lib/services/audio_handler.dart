import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';
import 'api_service.dart';
import 'audio_effects.dart';
import 'ai_dj_service.dart';
import 'storage_service.dart';
import 'dart:math' as math;
import 'local_audio_server.dart';
import 'ghost_proxy_client.dart';
import '../core/constants/api_constants.dart';

class RottyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // Android-only equalizer — disabled to prevent native platform channel deadlocks on Android
  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  final AndroidEqualizer? _eq = null;
  late final AudioPlayer _player = AudioPlayer();
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
  bool _isMixFading = false;

  final AndroidEqualizer? _eqAux = null;
  late final AudioPlayer _auxPlayer = AudioPlayer();

  bool _isPreResolving = false;
  String? _preResolvedSongId;
  SongModel? _preResolvedSong;
  String? _lastPreResolvedForSongId;
  String _lastFilterA = '';
  String _lastFilterB = '';
  List<dynamic> _vocalIntervalsA = [];
  List<dynamic> _vocalIntervalsB = [];

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

  int get rawContextIndex => _currentIndex;
  bool get isUserSongPlaying => _currentUserSong != null;

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
    // Start local server to proxy streams
    try {
      final server = LocalAudioServer();
      await server.start();
      debugPrint('ROTTY LOCAL SERVER: Initialized on startup, port = ${server.port}');
    } catch (e) {
      debugPrint('ROTTY LOCAL SERVER: Failed to start on startup: $e');
    }

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

        // 1. Pre-resolve the next song in the queue dynamically based on blend length (blend length + 8s, clamped between 15s and 30s)
        final int blendLengthSeconds = _storage.mixBlendLength;
        final int preResolveTriggerSeconds = (blendLengthSeconds + 8).clamp(15, 30);
        if (currentId != null &&
            remaining.inSeconds <= preResolveTriggerSeconds &&
            _lastPreResolvedForSongId != currentId &&
            !_isPreResolving) {
          _lastPreResolvedForSongId = currentId;
          _preResolveNextSong();
        }

        // 2. Trigger Mix Fade or natural DJ crossfade (only if not in Repeat One mode!)
        if (_repeatMode != AudioServiceRepeatMode.one) {
          if (_storage.mixFadeEnabled && !_isMixFading) {
            final int triggerMs = blendLengthSeconds * 1000;
            if (remaining.inMilliseconds <= triggerMs && remaining.inMilliseconds > 0) {
              _triggerMixFade();
            }
          } else if (RottyAudioEffects.infiniteBlend && !_isCrossfading && !_isMixFading) {
            if (remaining.inMilliseconds <= 2200 && remaining.inMilliseconds > 0) {
              _isCrossfading = true;
              _triggerNaturalCrossfade();
            }
          }
        }
      }
    });
  }

  Future<String?> _resolvePipedStream(String videoId) async {
    final pipedInstances = [
      'https://pipedapi.kavin.rocks',
      'https://api.piped.projectsegfau.lt',
      'https://piped-api.lunar.icu',
      'https://pipedapi.colt.es',
      'https://pipedapi.nosebs.ru',
      'https://pipedapi.priv.au',
      'https://pipedapi.leptons.xyz',
      'https://pipedapi.drgns.space',
    ];

    for (final instance in pipedInstances) {
      try {
        debugPrint('ROTTY PLAYBACK: Trying Piped instance $instance for videoId: $videoId');
        final response = await http.get(
          Uri.parse('$instance/streams/$videoId'),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final audioStreams = data['audioStreams'];
          if (audioStreams is List && audioStreams.isNotEmpty) {
            var bestStream = audioStreams.first;
            var maxBitrate = -1;
            for (final stream in audioStreams) {
              final bitrate = stream['bitrate'] ?? 0;
              if (bitrate is num && bitrate > maxBitrate) {
                maxBitrate = bitrate.toInt();
                bestStream = stream;
              }
            }
            final url = bestStream['url'] as String?;
            if (url != null && url.isNotEmpty) {
              debugPrint('ROTTY PLAYBACK: Resolved stream via Piped: $instance');
              return url;
            }
          }
        }
      } catch (e) {
        debugPrint('ROTTY PLAYBACK: Piped instance $instance failed: $e');
      }
    }
    return null;
  }

  Future<String?> _resolveInvidiousStream(String videoId) async {
    final invidiousInstances = [
      'https://invidious.projectsegfau.lt',
      'https://inv.tux.pizza',
      'https://yewtu.be',
      'https://invidious.no-logs.com',
      'https://invidious.nerdvpn.de',
      'https://iv.melmac.space',
      'https://invidious.privacydev.net',
    ];

    for (final instance in invidiousInstances) {
      try {
        debugPrint('ROTTY PLAYBACK: Trying Invidious instance $instance for videoId: $videoId');
        final response = await http.get(
          Uri.parse('$instance/api/v1/videos/$videoId?local=true'),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final adaptiveFormats = data['adaptiveFormats'];
          if (adaptiveFormats is List && adaptiveFormats.isNotEmpty) {
            for (final format in adaptiveFormats) {
              final type = format['type']?.toString() ?? '';
              if (type.startsWith('audio/')) {
                var url = format['url'] as String?;
                if (url != null && url.isNotEmpty) {
                  if (url.startsWith('/')) {
                    url = '$instance$url';
                  }
                  debugPrint('ROTTY PLAYBACK: Resolved stream via Invidious: $instance');
                  return url;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('ROTTY PLAYBACK: Invidious instance $instance failed: $e');
      }
    }
    return null;
  }

  Future<SongModel> _resolveSongUrl(SongModel song) async {
    if (song.id.startsWith('youtube_')) {
      final videoId = song.id.replaceFirst('youtube_', '');
      String? streamUrl;

      // 1. Try youtube_explode_dart first
      try {
        final yt = YoutubeExplode();
        final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 6));
        final audioOnly = manifest.audioOnly;
        if (audioOnly.isNotEmpty) {
          final bestAudio = audioOnly.withHighestBitrate();
          streamUrl = bestAudio.url.toString();
          debugPrint('ROTTY PLAYBACK: Resolved YouTube stream URL via YoutubeExplode for ${song.title}');
        }
        yt.close();
      } catch (e) {
        debugPrint('ROTTY PLAYBACK: YoutubeExplode stream resolution failed/timed out: $e');
      }

      // 2. Try Piped API fallback if YoutubeExplode failed
      if (streamUrl == null) {
        debugPrint('ROTTY PLAYBACK: Falling back to Piped APIs for videoId: $videoId');
        streamUrl = await _resolvePipedStream(videoId);
      }

      // 3. Try Invidious API fallback if Piped failed
      if (streamUrl == null) {
        debugPrint('ROTTY PLAYBACK: Falling back to Invidious APIs for videoId: $videoId');
        streamUrl = await _resolveInvidiousStream(videoId);
      }

      if (streamUrl != null) {
        debugPrint('ROTTY PLAYBACK: Resolved YouTube stream URL: $streamUrl');
        final server = LocalAudioServer();
        await server.start();
        if (server.port != null) {
          final proxyUrl = 'http://127.0.0.1:${server.port}/proxy?url=${Uri.encodeComponent(streamUrl)}';
          debugPrint('ROTTY PLAYBACK: Routed YouTube stream URL via local proxy: $proxyUrl');
          return song.copyWith(url: proxyUrl);
        }
        return song.copyWith(url: streamUrl);
      }
      return song;
    }

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
      var playUrl = song.url;
      final isYt = song.id.startsWith('youtube_') || playUrl.contains('googlevideo.com') || playUrl.contains('youtube.com') || playUrl.contains('youtu.be');
      if (isYt && !playUrl.contains('127.0.0.1')) {
        final server = LocalAudioServer();
        await server.start();
        if (server.port != null) {
          playUrl = 'http://127.0.0.1:${server.port}/proxy?url=${Uri.encodeComponent(playUrl)}';
          debugPrint('ROTTY PLAYBACK: Routed existing YouTube stream through local proxy: $playUrl');
        }
      } else if (!isYt && GhostProxyClient.isEnabled && playUrl.startsWith('http') && !playUrl.contains('/api/media') && !playUrl.contains('/renders/')) {
        playUrl = '${ApiConstants.backendUrl}/api/media?url=${Uri.encodeComponent(playUrl)}';
        debugPrint('ROTTY PLAYBACK: Routed existing playable stream through media proxy: $playUrl');
      }
      return song.copyWith(url: playUrl);
    }

    // 3. For any network song, always fetch a fresh, unexpired URL right before playback
    SongModel? resolvedSong;
    try {
      debugPrint('ROTTY PLAYBACK: Fetching fresh unexpired URL for ${song.title} (${song.id})');
      final details = await _api.getSongDetails(song.id);
      if (details != null && details.hasPlayableUrl) {
        var playUrl = details.url;
        final isYt = details.id.startsWith('youtube_') || playUrl.contains('googlevideo.com') || playUrl.contains('youtube.com') || playUrl.contains('youtu.be');
        if (isYt && !playUrl.contains('127.0.0.1')) {
          final server = LocalAudioServer();
          await server.start();
          if (server.port != null) {
            playUrl = 'http://127.0.0.1:${server.port}/proxy?url=${Uri.encodeComponent(playUrl)}';
            debugPrint('ROTTY PLAYBACK: Routed fresh YouTube stream through local proxy: $playUrl');
          }
        } else if (!isYt && GhostProxyClient.isEnabled && playUrl.startsWith('http') && !playUrl.contains('/api/media') && !playUrl.contains('/renders/')) {
          playUrl = '${ApiConstants.backendUrl}/api/media?url=${Uri.encodeComponent(playUrl)}';
          debugPrint('ROTTY PLAYBACK: Routed fresh network stream through media proxy: $playUrl');
        }
        resolvedSong = details.copyWith(url: playUrl);
      }
    } catch (e) {
      debugPrint('ROTTY PLAYBACK: Failed to fetch fresh URL: $e');
    }

    if (resolvedSong != null) {
      return resolvedSong;
    }

    // Self-healing fallback: if JioSaavn loading fails or URL is empty, search YouTube and stream!
    debugPrint('ROTTY PLAYBACK: JioSaavn URL is empty/unplayable. Triggering YouTube self-healing fallback for "${song.title} ${song.artist}"...');
    try {
      final query = '${song.title} ${song.artist}';
      final yt = YoutubeExplode();
      final searchList = await yt.search.search(query).timeout(const Duration(seconds: 5));
      if (searchList.isNotEmpty) {
        final video = searchList.first;
        final videoId = video.id.value;
        String? streamUrl;
        
        try {
          final manifest = await yt.videos.streamsClient.getManifest(video.id).timeout(const Duration(seconds: 5));
          final audioOnly = manifest.audioOnly;
          if (audioOnly.isNotEmpty) {
            streamUrl = audioOnly.withHighestBitrate().url.toString();
          }
        } catch (_) {}

        if (streamUrl == null) {
          streamUrl = await _resolvePipedStream(videoId);
        }
        if (streamUrl == null) {
          streamUrl = await _resolveInvidiousStream(videoId);
        }

        if (streamUrl != null) {
          yt.close();
          final server = LocalAudioServer();
          await server.start();
          var playUrl = streamUrl;
          if (server.port != null) {
            playUrl = 'http://127.0.0.1:${server.port}/proxy?url=${Uri.encodeComponent(streamUrl)}';
          }
          debugPrint('ROTTY PLAYBACK: Self-healing resolved song via YouTube: $playUrl');
          return song.copyWith(
            id: 'youtube_$videoId',
            url: playUrl,
            album: 'YouTube Fallback',
          );
        }
      }
      yt.close();
    } catch (e) {
      debugPrint('ROTTY PLAYBACK: Self-healing YouTube fallback failed: $e');
    }

    return song;
  }

  Future<SongModel?> _resolveYoutubeFallback(SongModel song) async {
    debugPrint('ROTTY PLAYBACK: JioSaavn load failed. Resolving YouTube fallback for: ${song.title} - ${song.artist}');
    try {
      final query = '${song.title} ${song.artist}';
      final yt = YoutubeExplode();
      final searchList = await yt.search.search(query).timeout(const Duration(seconds: 5));
      if (searchList.isNotEmpty) {
        final video = searchList.first;
        final videoId = video.id.value;
        String? streamUrl;
        
        try {
          final manifest = await yt.videos.streamsClient.getManifest(video.id).timeout(const Duration(seconds: 5));
          final audioOnly = manifest.audioOnly;
          if (audioOnly.isNotEmpty) {
            streamUrl = audioOnly.withHighestBitrate().url.toString();
          }
        } catch (_) {}

        if (streamUrl == null) {
          streamUrl = await _resolvePipedStream(videoId);
        }
        if (streamUrl == null) {
          streamUrl = await _resolveInvidiousStream(videoId);
        }

        if (streamUrl != null) {
          yt.close();
          final server = LocalAudioServer();
          await server.start();
          var playUrl = streamUrl;
          if (server.port != null) {
            playUrl = 'http://127.0.0.1:${server.port}/proxy?url=${Uri.encodeComponent(streamUrl)}';
          }
          debugPrint('ROTTY PLAYBACK: YouTube fallback resolved: $playUrl');
          return song.copyWith(url: playUrl);
        }
      }
      yt.close();
    } catch (e) {
      debugPrint('ROTTY PLAYBACK: YouTube fallback resolution failed: $e');
    }
    return null;
  }

  Future<void> _applyFilterToEqualizer(AndroidEqualizer eq, String filterType) async {
    try {
      await eq.setEnabled(true);
      final params = await eq.parameters;
      final bands = params.bands;
      if (bands.isEmpty) return;

      final minDecibels = params.minDecibels;
      final maxDecibels = params.maxDecibels;
      const center = 0.0;

      final bandCount = bands.length;
      debugPrint('ROTTY EQ FILTER: Applying "$filterType" across $bandCount bands.');

      for (int i = 0; i < bandCount; i++) {
        final ratio = i / (bandCount - 1).clamp(1, 100);
        double gain = center; // default to flat

        switch (filterType.toLowerCase()) {
          case 'low-pass (beat isolate)':
          case 'low-pass':
          case 'beat isolate':
            if (ratio <= 0.3) {
              gain = maxDecibels;
            } else if (ratio <= 0.5) {
              gain = minDecibels + 0.25 * (maxDecibels - minDecibels);
            } else {
              gain = minDecibels;
            }
            break;

          case 'high-pass (vocal background)':
          case 'high-pass':
          case 'vocal extract':
          case 'vocal background':
            if (ratio <= 0.3) {
              gain = minDecibels;
            } else if (ratio > 0.3 && ratio <= 0.8) {
              gain = maxDecibels;
            } else {
              gain = center;
            }
            break;

          case 'bass boost':
            if (ratio <= 0.3) {
              gain = maxDecibels * 0.85;
            } else {
              gain = center;
            }
            break;

          case 'treble cut':
            if (ratio >= 0.75) {
              gain = minDecibels;
            } else {
              gain = center;
            }
            break;

          case 'mute':
            gain = minDecibels;
            break;

          case 'none':
          default:
            gain = center;
            break;
        }

        await bands[i].setGain(gain.clamp(minDecibels, maxDecibels));
      }
    } catch (e) {
      debugPrint('ROTTY EQ FILTER ERROR: Failed to apply EQ filter: $e');
    }
  }

  Future<void> _resetEqualizersToFlat() async {
    if (_isMobile) {
      debugPrint('ROTTY EQ RESET: Resetting equalizers to flat response.');
      if (_eq != null) await _applyFilterToEqualizer(_eq!, 'none');
      if (_eqAux != null) await _applyFilterToEqualizer(_eqAux!, 'none');
    }
  }

  Future<void> _playActiveSong(SongModel song) async {
    _isCrossfading = false;
    _isMixFading = false;
    await _playActiveSongNormal(song);
  }

  Future<void> _playActiveSongNormal(SongModel song) async {
    // Failsafe: stop auxiliary players immediately to prevent dual-playback leaks!
    await _auxPlayer.stop();
    await _resetEqualizersToFlat();

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
        try {
          var playUrl = activeSong.url;
          final bool isYt = activeSong.id.startsWith('youtube_') || playUrl.contains('googlevideo.com') || playUrl.contains('youtube.com') || playUrl.contains('youtu.be');
          if (isYt && !playUrl.contains('127.0.0.1')) {
            final server = LocalAudioServer();
            await server.start();
            if (server.port != null) {
              playUrl = 'http://127.0.0.1:${server.port}/proxy?url=${Uri.encodeComponent(playUrl)}';
              activeSong = activeSong.copyWith(url: playUrl);
              debugPrint('ROTTY PLAYBACK: Playback URL routed through local proxy: $playUrl');
            }
          } else if (!isYt && GhostProxyClient.isEnabled && playUrl.startsWith('http') && !playUrl.contains('/api/media') && !playUrl.contains('/renders/')) {
            playUrl = '${ApiConstants.backendUrl}/api/media?url=${Uri.encodeComponent(playUrl)}';
            activeSong = activeSong.copyWith(url: playUrl);
            debugPrint('ROTTY PLAYBACK: Routed through local media proxy: $playUrl');
          } else if (!isYt && Platform.isWindows && playUrl.startsWith('https://')) {
            playUrl = playUrl.replaceFirst('https://', 'http://');
            debugPrint('ROTTY PLAYBACK: Forced HTTP stream URL for Windows: $playUrl');
          }

          final Map<String, String>? httpHeaders = isYt
              ? const {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                }
              : (Platform.isWindows ? null : const {
                  'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
                  'Referer': 'https://www.jiosaavn.com/',
                });

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
            final bool isYtRetry = activeSong.id.startsWith('youtube_') || retryUrl.contains('googlevideo.com') || retryUrl.contains('youtube.com') || retryUrl.contains('youtu.be');
            if (isYtRetry && !retryUrl.contains('127.0.0.1')) {
              final server = LocalAudioServer();
              await server.start();
              if (server.port != null) {
                retryUrl = 'http://127.0.0.1:${server.port}/proxy?url=${Uri.encodeComponent(retryUrl)}';
                activeSong = activeSong.copyWith(url: retryUrl);
                debugPrint('ROTTY PLAYBACK: Retry routed through local proxy: $retryUrl');
              }
            } else if (!isYtRetry && GhostProxyClient.isEnabled && retryUrl.startsWith('http') && !retryUrl.contains('/api/media') && !retryUrl.contains('/renders/')) {
              retryUrl = '${ApiConstants.backendUrl}/api/media?url=${Uri.encodeComponent(retryUrl)}';
              activeSong = activeSong.copyWith(url: retryUrl);
              debugPrint('ROTTY PLAYBACK: Retry routed through local media proxy: $retryUrl');
            } else if (!isYtRetry && Platform.isWindows && retryUrl.startsWith('https://')) {
              retryUrl = retryUrl.replaceFirst('https://', 'http://');
              debugPrint('ROTTY PLAYBACK: Forced HTTP retry stream URL for Windows: $retryUrl');
            }

            final Map<String, String>? retryHeaders = isYtRetry
                ? const {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  }
                : (Platform.isWindows ? null : const {
                    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
                    'Referer': 'https://www.jiosaavn.com/',
                  });

            await _player.setAudioSource(
              AudioSource.uri(
                Uri.parse(retryUrl),
                headers: retryHeaders,
                tag: _songToMediaItem(activeSong),
              ),
              preload: !Platform.isWindows,
            ).timeout(const Duration(seconds: 15));
          } catch (retryError) {
            debugPrint('ROTTY PLAYBACK: JioSaavn retry failed: $retryError. Trying YouTube fallback self-healing...');
            try {
              final fallbackSong = await _resolveYoutubeFallback(activeSong);
              if (fallbackSong != null && fallbackSong.hasPlayableUrl) {
                activeSong = fallbackSong;
                if (_currentUserSong != null && _currentUserSong!.id == activeSong.id) {
                  _currentUserSong = activeSong;
                } else if (_currentIndex >= 0 && _currentIndex < _contextQueue.length && _contextQueue[_currentIndex].id == activeSong.id) {
                  _contextQueue[_currentIndex] = activeSong;
                }
                mediaItem.add(_songToMediaItem(activeSong));
                _bumpQueue();

                final Map<String, String>? ytHeaders = const {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                };
                await _player.setAudioSource(
                  AudioSource.uri(
                    Uri.parse(activeSong.url),
                    headers: ytHeaders,
                    tag: _songToMediaItem(activeSong),
                  ),
                  preload: !Platform.isWindows,
                ).timeout(const Duration(seconds: 15));
                debugPrint('ROTTY PLAYBACK: Successfully self-healed using YouTube fallback stream!');
              } else {
                throw Exception('YouTube fallback returned null');
              }
            } catch (fallbackError) {
              debugPrint('ROTTY PLAYBACK: All playback recovery options failed: $fallbackError');
              _isCrossfading = false;
              _handlePlaybackFailure(song);
              return;
            }
          }
        }
      }

      _isCrossfading = false;
      await _player.setLoopMode(_repeatMode == AudioServiceRepeatMode.one ? LoopMode.one : LoopMode.off);
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

  @override
  Future<void> playMediaItem(MediaItem item) async {
    debugPrint('ROTTY PLAYBACK: playMediaItem called for "${item.title}" (${item.id})');
    final song = SongModel(
      id: item.id,
      title: item.title,
      artist: item.artist ?? 'ROTTY AI Studio',
      album: item.album ?? '',
      image: item.artUri?.toString() ?? '',
      duration: item.duration ?? Duration.zero,
      url: item.extras?['url']?.toString() ?? '',
    );
    await playSong(song);
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
    try {
      if (index < 0 || index >= songQueue.length) return;
      
      final loc = _locateIndex(index);
      switch (loc.section) {
        case QueueSection.pastContext:
          if (loc.index >= 0 && loc.index < _contextQueue.length) {
            final removedSong = _contextQueue.removeAt(loc.index);
            _originalContextQueue.removeWhere((s) => s.id == removedSong.id);
            _currentIndex--;
            _bumpQueue();
          }
          break;
          
        case QueueSection.current:
          if (_currentUserSong != null) {
            _currentUserSong = null;
            skipToNext();
          } else {
            if (_currentIndex >= 0 && _currentIndex < _contextQueue.length) {
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
          }
          break;
          
        case QueueSection.userQueue:
          if (loc.index >= 0 && loc.index < _userQueue.length) {
            _userQueue.removeAt(loc.index);
            _bumpQueue();
          }
          break;
          
        case QueueSection.upcomingContext:
          if (loc.index >= 0 && loc.index < _contextQueue.length) {
            final removedSong = _contextQueue.removeAt(loc.index);
            _originalContextQueue.removeWhere((s) => s.id == removedSong.id);
            _bumpQueue();
          }
          break;
      }
    } catch (e) {
      print("Error in removeFromQueue: $e");
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    try {
      final int activeIndex = currentIndex;
      // Reordering is only allowed for upcoming tracks
      if (oldIndex < activeIndex + 1 || newIndex < activeIndex + 1) return;

      final upcoming = <SongModel>[..._userQueue, ...(_currentIndex + 1 < _contextQueue.length ? _contextQueue.sublist(_currentIndex + 1) : <SongModel>[])];
      
      final int relativeOld = oldIndex - (activeIndex + 1);
      final int relativeNew = newIndex - (activeIndex + 1);

      if (relativeOld < 0 || relativeOld >= upcoming.length) return;
      if (relativeNew < 0 || relativeNew > upcoming.length) return;

      final songToMove = upcoming.removeAt(relativeOld);
      final adjustedNew = relativeNew > relativeOld ? relativeNew - 1 : relativeNew;
      upcoming.insert(adjustedNew.clamp(0, upcoming.length), songToMove);

      // Save the entire reordered list back to the userQueue and clear the upcoming context queue
      _userQueue.clear();
      _userQueue.addAll(upcoming);
      
      if (_currentIndex + 1 < _contextQueue.length) {
        _contextQueue.removeRange(_currentIndex + 1, _contextQueue.length);
      }

      _bumpQueue();
      debugPrint('ROTTY QUEUE: Successfully reordered upcoming queue. Total upcoming size: ${_userQueue.length}');
    } catch (e) {
      print("Error in reorderQueue: $e");
    }
  }

  void clearQueue() {
    try {
      _userQueue.clear();
      if (_currentIndex + 1 < _contextQueue.length) {
        _contextQueue.removeRange(_currentIndex + 1, _contextQueue.length);
      }
      _bumpQueue();
      debugPrint('ROTTY QUEUE: Cleared upcoming queue.');
    } catch (e) {
      print("Error in clearQueue: $e");
    }
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
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> stop() async {
    _isCrossfading = false;
    _isMixFading = false;
    RottyAudioEffects.stopOrbit();
    await _player.stop();
    await _auxPlayer.stop();
    await _resetEqualizersToFlat();
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
          excludeSongs: [
            ..._contextQueue,
            ..._userQueue,
            ..._history,
          ],
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
    if (_isCrossfading || _isMixFading) {
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
        MediaAction.play,
        MediaAction.pause,
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

  Future<void> _triggerMixFade() async {
    final fadeFromSongId = currentSong?.id;
    if (fadeFromSongId == null) return;
    if (_isMixFading) return;
    _isMixFading = true;

    debugPrint('ROTTY MIX FADE: Starting beat-matched mix transition...');

    // Find the next song
    SongModel? nextSong;
    if (_userQueue.isNotEmpty) {
      nextSong = _userQueue.first;
    } else {
      int nextIndex = _currentIndex + 1;
      if (nextIndex < _contextQueue.length) {
        nextSong = _contextQueue[nextIndex];
      } else if (_repeatMode == AudioServiceRepeatMode.all && _contextQueue.isNotEmpty) {
        nextSong = _contextQueue.first;
      }
    }

    if (nextSong == null) {
      _isMixFading = false;
      return;
    }

    // Stop 8D effects during transition
    RottyAudioEffects.stopOrbit();

    try {
      // Resolve next song URL (fast-path: use pre-resolved song details if matching)
      final SongModel resolvedNextSong = (_preResolvedSong != null && _preResolvedSong!.id == nextSong.id)
          ? _preResolvedSong!
          : await _resolveSongUrl(nextSong);

      if (!resolvedNextSong.hasPlayableUrl) {
        _isMixFading = false;
        await skipToNext();
        return;
      }

      // Load next song in auxiliary player (if not already pre-buffered!)
      final bool alreadyBuffered = _preResolvedSong != null && _preResolvedSong!.id == nextSong.id && _auxPlayer.duration != null;
      if (alreadyBuffered) {
        debugPrint('ROTTY MIX FADE: Using pre-buffered track in aux player for instant transition!');
      } else {
        debugPrint('ROTTY MIX FADE: Track not pre-buffered. Loading now...');
        final isLocal = resolvedNextSong.url.startsWith('file:') || resolvedNextSong.url.startsWith('file://');
        if (isLocal) {
          final filePath = Uri.parse(resolvedNextSong.url).toFilePath();
          await _auxPlayer.setAudioSource(AudioSource.file(filePath));
        } else {
          final isYt = resolvedNextSong.id.startsWith('youtube_') ||
              resolvedNextSong.url.contains('googlevideo.com') ||
              resolvedNextSong.url.contains('youtube.com') ||
              resolvedNextSong.url.contains('youtu.be');
          final Map<String, String>? httpHeaders = isYt
              ? const {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                }
              : (Platform.isWindows ? null : const {
                  'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
                  'Referer': 'https://www.jiosaavn.com/',
                });
          await _auxPlayer.setAudioSource(
            AudioSource.uri(Uri.parse(resolvedNextSong.url), headers: httpHeaders),
            preload: true,
          );
        }
      }

      // Simulate beat-matching tempo adjustment
      final double bpmA = 90.0 + (songQueue.indexOf(currentSong!) % 5) * 8.0; 
      final double bpmB = 90.0 + (songQueue.indexOf(resolvedNextSong) % 5) * 8.0;
      double speedRatio = bpmA / bpmB;
      speedRatio = speedRatio.clamp(0.92, 1.08); // Clamp to prevent cartoonish pitch shifts

      // Always reset aux player position to start of the song for a perfect mix alignment
      await _auxPlayer.seek(Duration.zero);
      await _auxPlayer.setSpeed(speedRatio);
      await _auxPlayer.setVolume(0.0);
      
      // Start playing aux player
      await _auxPlayer.play();

      debugPrint('ROTTY MIX FADE: Aux player started with speed $speedRatio (matching BPM $bpmB to $bpmA)');

      // Dynamic Crossfade based on preferred blend style and duration
      final int totalBlendDurationMs = _storage.mixBlendLength * 1000;
      final int steps = 25;
      final int stepDelayMs = totalBlendDurationMs ~/ steps;
      final double targetVol = RottyAudioEffects.getTargetVolume();
      const String style = 'Smooth'; // default blend style

      debugPrint('ROTTY MIX FADE: Executing blend style "$style" over ${totalBlendDurationMs}ms');

      for (int i = 0; i <= steps; i++) {
        // Guard if song was changed manually during transition
        if (currentSong?.id != fadeFromSongId || !_player.playing) {
          break;
        }
        final double t = i / steps; // 0.0 to 1.0
        
        double volumeRatioA = math.pow(1.0 - t, 2.2).toDouble();
        double volumeRatioB = math.pow(t, 2.2).toDouble();

        await _player.setVolume(volumeRatioA * targetVol);
        await _auxPlayer.setVolume(volumeRatioB * targetVol);

        await Future.delayed(Duration(milliseconds: stepDelayMs.toInt()));
      }

      // Check if we didn't interrupt
      if (currentSong?.id == fadeFromSongId) {
        final Duration transitionPosition = _auxPlayer.position;
        debugPrint('ROTTY MIX FADE: Seamless transition complete. Swapping aux position: $transitionPosition');

        // Update active indices
        if (_userQueue.isNotEmpty) {
          _userQueue.removeAt(0);
          _currentUserSong = resolvedNextSong;
        } else {
          _currentUserSong = null;
          int nextIndex = _currentIndex + 1;
          if (nextIndex >= _contextQueue.length && _repeatMode == AudioServiceRepeatMode.all) {
            nextIndex = 0;
          }
          _currentIndex = nextIndex;
        }

        // Update media item
        mediaItem.add(_songToMediaItem(resolvedNextSong));
        _bumpQueue();

        // Now load this song on primary player in background, and play BEFORE stopping aux player to ensure 100% gapless handoff!
        final isLocal = resolvedNextSong.url.startsWith('file:') || resolvedNextSong.url.startsWith('file://');
        if (isLocal) {
          final filePath = Uri.parse(resolvedNextSong.url).toFilePath();
          await _player.setAudioSource(AudioSource.file(filePath));
        } else {
          final isYt = resolvedNextSong.id.startsWith('youtube_') ||
              resolvedNextSong.url.contains('googlevideo.com') ||
              resolvedNextSong.url.contains('youtube.com') ||
              resolvedNextSong.url.contains('youtu.be');
          final Map<String, String>? httpHeaders = isYt
              ? const {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                }
              : (Platform.isWindows ? null : const {
                  'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
                  'Referer': 'https://www.jiosaavn.com/',
                });
          await _player.setAudioSource(AudioSource.uri(Uri.parse(resolvedNextSong.url), headers: httpHeaders));
        }

        // Account for setAudioSource initialization latency by starting primary player slightly ahead of transitionPosition
        final Duration takeOverPos = _auxPlayer.position + const Duration(milliseconds: 200);
        await _player.setSpeed(1.0); // Reset primary player speed
        await _player.seek(takeOverPos);
        await _player.setVolume(targetVol);
        await _player.play();

        // Now safely stop auxiliary player!
        await _auxPlayer.stop();

        // Restart 8D effects on primary
        RottyAudioEffects.startOrbit(_player);
      } else {
        // Safe guard: if interrupted (e.g. user skipped during mix fade), stop auxiliary immediately!
        await _auxPlayer.stop();
      }
    } catch (e) {
      debugPrint('ROTTY MIX FADE ERROR: $e. Falling back to normal skip.');
      await _auxPlayer.stop();
      if (currentSong?.id == fadeFromSongId) {
        await skipToNext();
      }
    } finally {
      _isMixFading = false;
    }
  }
}

enum QueueSection { pastContext, current, userQueue, upcomingContext }

class QueueItemLocation {
  final QueueSection section;
  final int index;
  QueueItemLocation(this.section, this.index);
}

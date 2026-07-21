import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song_model.dart';
import '../models/media_item.dart';

String upgradeYoutubeThumbnail(String url) {
  if (url.isEmpty) return url;
  
  if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
    final regExp = RegExp(r'=[wh]\d+-[wh]\d+');
    if (url.contains(regExp)) {
      return url.replaceAll(regExp, '=w500-h500');
    }
    final regExpSingle = RegExp(r'=s\d+');
    if (url.contains(regExpSingle)) {
      return url.replaceAll(regExpSingle, '=s500');
    }
    if (!url.contains('=')) {
      return '$url=w500-h500';
    }
  }
  
  if (url.contains('ytimg.com') || url.contains('youtube.com')) {
    if (url.contains('default.jpg')) {
      return url.replaceAll('default.jpg', 'hqdefault.jpg');
    }
    if (url.contains('sddefault.jpg')) {
      return url.replaceAll('sddefault.jpg', 'hqdefault.jpg');
    }
  }
  
  return url;
}

class InvidiousService {
  InvidiousService._internal();
  static final InvidiousService instance = InvidiousService._internal();
  factory InvidiousService() => instance;

  final http.Client _client = http.Client();

  // Pre-configured public Invidious instances with high uptime
  List<String> _instances = [
    'inv.thepixora.com',
    'inv.nadeko.net',
    'invidious.nerdvpn.de',
    'invidious.f5.si',
    'yt.chocolatemoo53.com',
    'yewtu.be',
  ];

  String _currentInstance = 'inv.thepixora.com';
  bool _initialized = false;

  // In-memory cache for resolved stream URLs to load them instantly on replay
  final Map<String, String> _resolvedAudioCache = {};
  final Map<String, String> _resolvedVideoCache = {};

  String get currentInstance => _currentInstance;

  /// Ping all instances and sort them by response time to ensure we always use the fastest node
  Future<void> initFastestInstance() async {
    if (_initialized) return;
    debugPrint('[InvidiousService] Initializing latency ping checks...');

    final List<MapEntry<String, int>> results = [];

    await Future.wait(
      _instances.map((domain) async {
        final stopwatch = Stopwatch()..start();
        try {
          final url = Uri.parse('https://$domain/api/v1/trending?type=music');
          final response = await _client.get(url).timeout(const Duration(milliseconds: 1500));
          stopwatch.stop();

          if (response.statusCode == 200) {
            results.add(MapEntry(domain, stopwatch.elapsedMilliseconds));
            debugPrint('[InvidiousService] Domain $domain pinged in ${stopwatch.elapsedMilliseconds}ms');
          }
        } catch (e) {
          stopwatch.stop();
          debugPrint('[InvidiousService] Domain $domain failed check: $e');
        }
      }),
    );

    if (results.isNotEmpty) {
      results.sort((a, b) => a.value.compareTo(b.value));
      _instances = results.map((e) => e.key).toList();
      _currentInstance = _instances.first;
      debugPrint('[InvidiousService] Fastest Instance selected: $_currentInstance');
    } else {
      debugPrint('[InvidiousService] All pings failed. Defaulting to: $_currentInstance');
    }

    _initialized = true;
  }

  /// Helper to send GET request with auto-failover to backup instances
  Future<http.Response> _getWithFailover(String path) async {
    // Ensure initialized
    if (!_initialized) {
      await initFastestInstance();
    }

    List<String> triedInstances = [];
    String activeInstance = _currentInstance;

    for (int attempt = 0; attempt < _instances.length; attempt++) {
      triedInstances.add(activeInstance);
      final url = Uri.parse('https://$activeInstance$path');
      try {
        debugPrint('[InvidiousService] GET request to: $url');
        final response = await _client.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          // Verify response body is valid JSON before accepting it
          try {
            final decoded = json.decode(response.body);
            if (decoded != null) {
              // If a background instance worked, mark it as active
              if (activeInstance != _currentInstance) {
                _currentInstance = activeInstance;
              }
              return response;
            }
          } catch (jsonErr) {
            debugPrint('[InvidiousService] Response from $activeInstance was not valid JSON: $jsonErr');
          }
        } else {
          debugPrint('[InvidiousService] Server $activeInstance returned status: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('[InvidiousService] Request to $activeInstance failed: $e');
      }

      // Rotate to next instance
      activeInstance = _instances[(attempt + 1) % _instances.length];
    }

    throw StateError('All Invidious instances failed or returned invalid JSON. Tried: ${triedInstances.join(", ")}');
  }

  Future<bool> _isUrlPlayable(String url) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      request.headers['Range'] = 'bytes=0-10';
      final response = await _client.send(request).timeout(const Duration(milliseconds: 1500));
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return true;
      }
      debugPrint('[InvidiousService] GET Range check failed with status: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[InvidiousService] GET Range check failed: $e');
      return false;
    }
  }

  Future<String> resolveStreamUrl(String videoId, {bool isVideo = false}) async {
    final cacheMap = isVideo ? _resolvedVideoCache : _resolvedAudioCache;
    if (cacheMap.containsKey(videoId)) {
      debugPrint('[InvidiousService] Cache HIT for videoId: $videoId');
      final cachedUrl = cacheMap[videoId]!;
      // Quick validation check on cached URL
      final ok = await _isUrlPlayable(cachedUrl);
      if (ok) return cachedUrl;
      debugPrint('[InvidiousService] Cached URL failed validation. Re-resolving...');
      cacheMap.remove(videoId);
    }

    // Attempt direct YouTube Explode resolution first (fastest and most reliable)
    try {
      debugPrint('[InvidiousService] Resolving $videoId with YoutubeExplode (isVideo=$isVideo)...');
      final yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(videoId);

      String? streamUrl;
      if (isVideo) {
        final muxedStreams = manifest.muxed.sortByVideoQuality();
        if (muxedStreams.isNotEmpty) {
          // Select 360p or 480p first
          final stream = muxedStreams.firstWhere(
            (s) => s.videoQuality == VideoQuality.medium360 || s.videoQuality == VideoQuality.medium480,
            orElse: () => muxedStreams.first,
          );
          streamUrl = stream.url.toString();
        }
      } else {
        final stream = manifest.audioOnly.withHighestBitrate();
        streamUrl = stream.url.toString();
      }

      yt.close();
      if (streamUrl != null && streamUrl.isNotEmpty) {
        final ok = await _isUrlPlayable(streamUrl);
        if (ok) {
          debugPrint('[InvidiousService] YoutubeExplode successfully resolved & validated stream URL');
          cacheMap[videoId] = streamUrl;
          return streamUrl;
        } else {
          debugPrint('[InvidiousService] YoutubeExplode stream URL failed validation, trying Invidious...');
        }
      }
    } catch (e) {
      debugPrint('[InvidiousService] YoutubeExplode resolution failed, falling back to Invidious: $e');
    }

    // Fallback: Resolve via Invidious instances
    try {
      final response = await _getWithFailover('/api/v1/videos/$videoId');
      final data = json.decode(response.body);

      if (data != null && data['adaptiveFormats'] is List) {
        final formats = data['adaptiveFormats'] as List;

        if (isVideo) {
          // First pass: try to find an mp4 video format of 360p or 480p
          for (final f in formats) {
            final mime = f['type'] as String? ?? '';
            final url = f['url'] as String? ?? '';
            final qualityLabel = f['qualityLabel'] as String? ?? '';
            final height = f['height']?.toString() ?? '';
            if (mime.startsWith('video/mp4') && url.isNotEmpty) {
              if (qualityLabel.contains('360p') || qualityLabel.contains('480p') || height == '360' || height == '480') {
                final ok = await _isUrlPlayable(url);
                if (ok) {
                  cacheMap[videoId] = url;
                  return url;
                }
              }
            }
          }
          // Second pass: any mp4 video format
          for (final f in formats) {
            final mime = f['type'] as String? ?? '';
            final url = f['url'] as String? ?? '';
            if (mime.startsWith('video/mp4') && url.isNotEmpty) {
              final ok = await _isUrlPlayable(url);
              if (ok) {
                cacheMap[videoId] = url;
                return url;
              }
            }
          }
          // Third pass: any video format
          for (final f in formats) {
            final mime = f['type'] as String? ?? '';
            final url = f['url'] as String? ?? '';
            if (mime.startsWith('video/') && url.isNotEmpty) {
              final ok = await _isUrlPlayable(url);
              if (ok) {
                cacheMap[videoId] = url;
                return url;
              }
            }
          }
        } else {
          String bestUrl = '';
          int highestBitrate = 0;

          for (final f in formats) {
            final mime = f['type'] as String? ?? '';
            final url = f['url'] as String? ?? '';
            final bitrateStr = f['bitrate'] as String? ?? '0';
            final bitrate = int.tryParse(bitrateStr) ?? 0;

            if (mime.startsWith('audio/') && url.isNotEmpty) {
              if (bitrate > highestBitrate) {
                highestBitrate = bitrate;
                bestUrl = url;
              }
            }
          }

          if (bestUrl.isNotEmpty) {
            final ok = await _isUrlPlayable(bestUrl);
            if (ok) {
              cacheMap[videoId] = bestUrl;
              return bestUrl;
            }
          }
        }
      }

      if (data != null && data['formatStreams'] is List) {
        final streams = data['formatStreams'] as List;
        if (streams.isNotEmpty) {
          final url = streams.first['url'] as String? ?? '';
          if (url.isNotEmpty) {
            final ok = await _isUrlPlayable(url);
            if (ok) {
              cacheMap[videoId] = url;
              return url;
            }
          }
        }
      }

      throw StateError('No playable audio/video stream found');
    } catch (e) {
      debugPrint('[InvidiousService] Invidious resolution failed too for $videoId: $e');
      rethrow;
    }
  }

  String decodeHtmlEntities(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  Duration parseDuration(String? durStr) {
    if (durStr == null || durStr.isEmpty || durStr == 'LIVE' || durStr == 'SHORTS') {
      return Duration.zero;
    }
    final parts = durStr.trim().split(':');
    try {
      if (parts.length == 1) {
        return Duration(seconds: int.parse(parts.first));
      }
      if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      }
      if (parts.length == 3) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2]),
        );
      }
    } catch (_) {}
    return Duration.zero;
  }

  /// Performs music-only YouTube searches, filtering out vlogs, reviews, and non-music content
  Future<List<SongModel>> searchSongs(String query, {int limit = 15}) async {
    final cleanQuery = decodeHtmlEntities(query);
    String enhancedQuery = cleanQuery;
    if (!cleanQuery.toLowerCase().contains('youtube music') && !cleanQuery.toLowerCase().contains('topic')) {
      enhancedQuery = '$cleanQuery YouTube Music';
    } else {
      enhancedQuery = '$cleanQuery song music';
    }

    // 1. Try YoutubeExplode search first (fastest and most reliable)
    try {
      debugPrint('[InvidiousService] Searching YouTube directly with YoutubeExplode: "$enhancedQuery"');
      final yt = YoutubeExplode();
      final searchResults = await yt.search.searchContent(enhancedQuery, filter: TypeFilters.video);
      
      final List<SongModel> songs = [];
      for (final item in searchResults) {
        if (item is SearchVideo) {
          final videoId = item.id.value;
          final title = item.title;
          final author = item.author;
          final duration = parseDuration(item.duration);
          final lengthSeconds = duration.inSeconds;

          // Skip extremely long videos (like 1-hour playlists or compilations) and short clips
          if (lengthSeconds > 600 || lengthSeconds < 30) continue;

          // Use upgraded high quality thumbnail
          final rawThumbnail = item.thumbnails.isNotEmpty ? item.thumbnails.first.url.toString() : '';
          final thumbnail = upgradeYoutubeThumbnail(rawThumbnail);

          songs.add(SongModel(
            id: 'youtube_$videoId',
            title: title,
            artist: author,
            album: 'Official Release',
            image: thumbnail,
            duration: duration,
            url: '', // Will resolve URL dynamically when played
          ));
        }

        if (songs.length >= limit) break;
      }

      yt.close();
      if (songs.isNotEmpty) {
        debugPrint('[InvidiousService] YoutubeExplode search returned ${songs.length} results');
        return songs;
      }
    } catch (e) {
      debugPrint('[InvidiousService] YoutubeExplode search failed: $e, falling back to Invidious API...');
    }

    // 2. Fallback to Invidious search
    try {
      final encodedQuery = Uri.encodeComponent(enhancedQuery);
      final response = await _getWithFailover('/api/v1/search?q=$encodedQuery&type=video&limit=$limit');
      final data = json.decode(response.body);

      if (data is List) {
        final List<SongModel> songs = [];
        for (final item in data) {
          final type = item['type'] as String? ?? '';
          if (type != 'video') continue;

          final title = item['title'] as String? ?? '';
          final videoId = item['videoId'] as String? ?? '';
          final author = item['author'] as String? ?? '';
          final lengthSeconds = item['lengthSeconds'] as int? ?? 0;

          // Skip extremely long videos (like 1-hour playlists or compilations) and short clips
          if (lengthSeconds > 600 || lengthSeconds < 30) continue;

          // Extract thumbnail
          String thumbnail = '';
          if (item['videoThumbnails'] is List && (item['videoThumbnails'] as List).isNotEmpty) {
            final rawThumbnail = item['videoThumbnails'][0]['url'] as String? ?? '';
            thumbnail = upgradeYoutubeThumbnail(rawThumbnail);
          }

          songs.add(SongModel(
            id: 'youtube_$videoId',
            title: title,
            artist: author,
            album: 'Official Release',
            image: thumbnail,
            duration: Duration(seconds: lengthSeconds),
            url: '', // Will resolve URL dynamically when played
          ));
        }
        return songs;
      }
      return [];
    } catch (e) {
      debugPrint('[InvidiousService] Invidious fallback search failed too for "$query": $e');
      return [];
    }
  }

  /// Retrieves recommendations for a given YouTube Video ID
  Future<List<SongModel>> getRecommendations(String videoId, {int limit = 12}) async {
    // 1. Try YoutubeExplode first
    try {
      debugPrint('[InvidiousService] Fetching related videos from YoutubeExplode for: $videoId');
      final yt = YoutubeExplode();
      final video = await yt.videos.get(videoId);
      final relatedVideos = await yt.videos.getRelatedVideos(video);

      if (relatedVideos != null) {
        final List<SongModel> recs = [];
        for (final video in relatedVideos) {
          final title = video.title;
          final vId = video.id.value;
          final author = video.author;
          final duration = video.duration ?? Duration.zero;
          final lengthSeconds = duration.inSeconds;

          // Filter out vlogs/compilations
          if (lengthSeconds > 600 || lengthSeconds < 30) continue;

          final thumbnail = upgradeYoutubeThumbnail(video.thumbnails.mediumResUrl);

          recs.add(SongModel(
            id: 'youtube_$vId',
            title: title,
            artist: author,
            album: 'Premium Stream',
            image: thumbnail,
            duration: duration,
            url: '',
          ));

          if (recs.length >= limit) break;
        }

        yt.close();
        if (recs.isNotEmpty) {
          debugPrint('[InvidiousService] YoutubeExplode returned ${recs.length} recommended videos');
          return recs;
        }
      }
      yt.close();
    } catch (e) {
      debugPrint('[InvidiousService] YoutubeExplode recommended videos failed: $e, falling back to Invidious API...');
    }

    // 2. Fallback to Invidious recommendedVideos
    try {
      final response = await _getWithFailover('/api/v1/videos/$videoId');
      final data = json.decode(response.body);

      if (data != null && data['recommendedVideos'] is List) {
        final List<SongModel> recs = [];
        final items = data['recommendedVideos'] as List;

        for (final item in items) {
          final type = item['type'] as String? ?? '';
          if (type != 'video') continue;

          final title = item['title'] as String? ?? '';
          final vId = item['videoId'] as String? ?? '';
          final author = item['author'] as String? ?? '';
          final lengthSeconds = item['lengthSeconds'] as int? ?? 0;

          // Filter out vlogs/compilations
          if (lengthSeconds > 600 || lengthSeconds < 30) continue;

          String thumbnail = '';
          if (item['videoThumbnails'] is List && (item['videoThumbnails'] as List).isNotEmpty) {
            final rawThumbnail = item['videoThumbnails'][0]['url'] as String? ?? '';
            thumbnail = upgradeYoutubeThumbnail(rawThumbnail);
          }

          recs.add(SongModel(
            id: 'youtube_$vId',
            title: title,
            artist: author,
            album: 'Premium Stream',
            image: thumbnail,
            duration: Duration(seconds: lengthSeconds),
            url: '',
          ));

          if (recs.length >= limit) break;
        }
        return recs;
      }
    } catch (e) {
      debugPrint('[InvidiousService] Invidious fallback recommendations failed: $e');
    }
    return [];
  }

  Future<List<SongModel>> getPlaylistSongs(String playlistId, {int limit = 15}) async {
    try {
      debugPrint('[InvidiousService] Fetching playlist tracks for playlistId: $playlistId');
      final yt = YoutubeExplode();
      final List<SongModel> songs = [];

      // Fetch playlist videos
      final videos = await yt.playlists.getVideos(playlistId).take(limit).toList().timeout(const Duration(seconds: 4));

      if (videos.isEmpty) {
        throw StateError('youtube_explode parsed 0 videos for playlist $playlistId');
      }

      for (final video in videos) {
        final videoId = video.id.value;
        final title = video.title;
        final author = video.author;
        final duration = video.duration ?? Duration.zero;
        final thumbnail = upgradeYoutubeThumbnail(video.thumbnails.mediumResUrl);

        songs.add(SongModel(
          id: 'youtube_$videoId',
          title: title,
          artist: author,
          album: 'Premium Playlist',
          image: thumbnail,
          duration: duration,
          url: '', // Will resolve stream URL dynamically when played
        ));
      }

      yt.close();
      return songs;
    } catch (e) {
      debugPrint('[InvidiousService] YoutubeExplode error fetching playlist tracks for $playlistId: $e, trying self-healing search fallback...');
      try {
        final yt = YoutubeExplode();
        final playlistMeta = await yt.playlists.get(playlistId);
        final playlistTitle = playlistMeta.title;
        yt.close();
        if (playlistTitle.isNotEmpty) {
          debugPrint('[InvidiousService] Self-healing fallback: Searching YouTube for playlist title "$playlistTitle"');
          return await searchSongs(playlistTitle, limit: limit);
        }
      } catch (metaErr) {
        debugPrint('[InvidiousService] Self-healing playlist metadata fetch failed: $metaErr');
      }

      // Fallback to Invidious API
      try {
        final response = await _getWithFailover('/api/v1/playlists/$playlistId');
        final data = json.decode(response.body);
        if (data != null && data['videos'] is List) {
          final List<SongModel> songs = [];
          final items = data['videos'] as List;
          for (final item in items) {
            final title = item['title'] as String? ?? '';
            final vId = item['videoId'] as String? ?? '';
            final author = item['author'] as String? ?? '';
            final lengthSeconds = item['lengthSeconds'] as int? ?? 0;
            
            String thumbnail = '';
            if (item['videoThumbnails'] is List && (item['videoThumbnails'] as List).isNotEmpty) {
              final rawThumbnail = item['videoThumbnails'][0]['url'] as String? ?? '';
              thumbnail = upgradeYoutubeThumbnail(rawThumbnail);
            }
            
            songs.add(SongModel(
              id: 'youtube_$vId',
              title: title,
              artist: author,
              album: 'Premium Playlist',
              image: thumbnail,
              duration: Duration(seconds: lengthSeconds),
              url: '',
            ));
            if (songs.length >= limit) break;
          }
          return songs;
        }
      } catch (invidiousErr) {
        debugPrint('[InvidiousService] Invidious fallback playlist fetch failed too: $invidiousErr');
      }
      return [];
    }
  }

  Future<List<AlbumItem>> searchPlaylists(String query, {int limit = 15}) async {
    final cleanQuery = decodeHtmlEntities(query);
    
    // 1. Try YoutubeExplode search first
    try {
      debugPrint('[InvidiousService] Searching playlists with YoutubeExplode: "$cleanQuery"');
      final yt = YoutubeExplode();
      final searchResults = await yt.search.searchContent(cleanQuery, filter: TypeFilters.playlist);
      
      final List<AlbumItem> playlists = [];
      for (final item in searchResults) {
        if (item is SearchPlaylist) {
          final plId = item.id.value;
          final title = item.title;
          final rawThumbnail = item.thumbnails.isNotEmpty ? item.thumbnails.first.url.toString() : '';
          final thumbnail = upgradeYoutubeThumbnail(rawThumbnail);
          
          playlists.add(AlbumItem(
            id: 'youtube_playlist_$plId',
            name: title,
            image: thumbnail,
            year: 'YouTube',
            language: '${item.videoCount} videos',
          ));
        }
        
        if (playlists.length >= limit) break;
      }
      
      yt.close();
      if (playlists.isNotEmpty) return playlists;
    } catch (e) {
      debugPrint('[InvidiousService] YoutubeExplode playlist search failed: $e, falling back to Invidious API...');
    }

    // 2. Fallback to Invidious search
    try {
      final encodedQuery = Uri.encodeComponent(cleanQuery);
      final response = await _getWithFailover('/api/v1/search?q=$encodedQuery&type=playlist&limit=$limit');
      final data = json.decode(response.body);
      
      if (data is List) {
        final List<AlbumItem> playlists = [];
        for (final item in data) {
          final type = item['type'] as String? ?? '';
          if (type != 'playlist') continue;
          
          final title = item['title'] as String? ?? '';
          final plId = item['playlistId'] as String? ?? '';
          final author = item['author'] as String? ?? '';
          final videoCount = item['videoCount'] as int? ?? 0;
          
          String thumbnail = '';
          if (item['playlistThumbnail'] is String) {
            thumbnail = upgradeYoutubeThumbnail(item['playlistThumbnail'] as String);
          } else if (item['videos'] is List && (item['videos'] as List).isNotEmpty) {
            final firstVideo = item['videos'][0];
            if (firstVideo['videoThumbnails'] is List && (firstVideo['videoThumbnails'] as List).isNotEmpty) {
              final rawThumbnail = firstVideo['videoThumbnails'][0]['url'] as String? ?? '';
              thumbnail = upgradeYoutubeThumbnail(rawThumbnail);
            }
          }
          
          playlists.add(AlbumItem(
            id: 'youtube_playlist_$plId',
            name: title,
            image: thumbnail,
            year: author,
            language: '$videoCount videos',
          ));
        }
        return playlists;
      }
    } catch (e) {
      debugPrint('[InvidiousService] Invidious fallback playlist search failed: $e');
    }
    return [];
  }
}

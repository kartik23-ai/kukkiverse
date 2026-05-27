import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../core/constants/api_constants.dart';
import '../models/media_item.dart';
import '../models/song_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  final http.Client _client = http.Client();
  ApiService._internal();

  String _quality = '320kbps';
  void setQuality(String quality) => _quality = quality;

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
    'Accept': 'application/json',
    'Referer': 'https://www.jiosaavn.com',
  };

  Uri _web(String call, Map<String, String> params) {
    return Uri.parse('https://www.jiosaavn.com/api.php').replace(
      queryParameters: {
        '__call': call,
        '_format': 'json',
        '_marker': '0',
        'ctx': 'web6dot0',
        ...params,
      },
    );
  }

  Future<http.Response?> _get(Uri uri) async {
    try {
      final r = await _client.get(uri, headers: _headers).timeout(ApiConstants.timeout);
      if (r.statusCode == 200) return r;
    } catch (_) {}
    return null;
  }

  Future<List<SongModel>> searchSongs(String query, {int limit = 25, int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final r = await _get(_web('search.getResults', {
      'q': query.trim(),
      'p': '$page',
      'n': '$limit',
      'type': 'song',
    }));
    if (r != null) return _parseWebSongs(r.body);
    return _fallbackSumitSearch(query, limit);
  }

  Future<List<AlbumItem>> searchAlbums(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final r = await _get(_web('search.getResults', {
      'q': query.trim(),
      'p': '1',
      'n': '$limit',
      'type': 'album',
    }));
    if (r != null) {
      try {
        final body = json.decode(r.body);
        final results = body is Map ? body['results'] : null;
        if (results is List) {
          return results.whereType<Map>().map((e) {
            final m = Map<String, dynamic>.from(e);
            return AlbumItem(
              id: m['albumid']?.toString() ?? m['id']?.toString() ?? '',
              name: m['title']?.toString() ?? m['album']?.toString() ?? 'Album',
              image: SongModel.hiResImage(m['image']?.toString() ?? ''),
              year: m['year']?.toString() ?? '',
              language: m['language']?.toString() ?? '',
            );
          }).where((a) => a.id.isNotEmpty).toList();
        }
      } catch (_) {}
    }
    return _fallbackSumitAlbums(query, limit);
  }

  Future<List<ArtistItem>> searchArtists(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final r = await _get(_web('search.getArtistResults', {
      'q': query.trim(),
      'p': '1',
      'n': '$limit',
    }));
    if (r != null) {
      try {
        final body = json.decode(r.body);
        final results = body is Map ? body['results'] : null;
        if (results is List) {
          return results.whereType<Map>().map((e) {
            final m = Map<String, dynamic>.from(e);
            return ArtistItem(
              id: m['artistid']?.toString() ?? m['id']?.toString() ?? '',
              name: m['title']?.toString() ?? m['name']?.toString() ?? 'Artist',
              image: SongModel.hiResImage(m['image']?.toString() ?? ''),
            );
          }).where((a) => a.id.isNotEmpty).toList();
        }
      } catch (_) {}
    }
    return _fallbackSumitArtists(query, limit);
  }

  Future<List<SongModel>> getAlbumSongs(String albumId) async {
    if (albumId.isEmpty) return [];
    final r = await _get(_web('content.getAlbumDetails', {'albumid': albumId}));
    if (r != null) {
      try {
        final body = json.decode(r.body);
        if (body is Map && body['songs'] is List) {
          return _mapsToSongs(body['songs'] as List);
        }
      } catch (_) {}
    }
    return _fallbackSumitAlbum(albumId);
  }

  Future<({ArtistItem? artist, List<SongModel> songs, List<AlbumItem> albums})> getArtist(String artistId) async {
    if (artistId.isEmpty) return (artist: null, songs: <SongModel>[], albums: <AlbumItem>[]);
    
    final bool isAlphanumeric = RegExp(r'[a-zA-Z]').hasMatch(artistId);
    if (!isAlphanumeric) {
      final r = await _get(_web('artist.getArtistPageDetails', {
        'artistId': artistId,
        'page': '1',
      }));
      if (r != null) {
        try {
          final body = json.decode(r.body);
          if (body is Map) {
            final name = body['name']?.toString() ?? body['title']?.toString() ?? 'Artist';
            final image = SongModel.hiResImage(body['image']?.toString() ?? '');
            final artist = ArtistItem(id: artistId, name: name, image: image);
            final songs = body['topSongs'] is List
                ? _mapsToSongs(body['topSongs'] as List)
                : body['songs'] is List
                    ? _mapsToSongs(body['songs'] as List)
                    : <SongModel>[];
            final albums = body['topAlbums'] is List
                ? (body['topAlbums'] as List).whereType<Map>().map((e) {
                    final m = Map<String, dynamic>.from(e);
                    return AlbumItem(
                      id: m['albumid']?.toString() ?? m['id']?.toString() ?? '',
                      name: m['title']?.toString() ?? m['name']?.toString() ?? '',
                      image: SongModel.hiResImage(m['image']?.toString() ?? ''),
                    );
                  }).toList()
                : <AlbumItem>[];
            if (songs.isNotEmpty || albums.isNotEmpty) return (artist: artist, songs: songs, albums: albums);
          }
        } catch (_) {}
      }
    }
    return _fallbackSumitArtist(artistId);
  }

  Future<Map<String, List<SongModel>>> getHomeData() async {
    final sections = <String, List<SongModel>>{};
    final entries = ApiConstants.homeQueries.entries.take(4).toList();
    for (final e in entries) {
      final songs = await searchSongs(e.value, limit: 12);
      if (songs.isNotEmpty) sections[e.key] = songs;
    }
    if (sections.isEmpty) {
      final trending = await searchSongs('hindi trending', limit: 15);
      if (trending.isNotEmpty) sections['Trending'] = trending;
    }
    return sections;
  }

  Future<SongModel?> getSongDetails(String id) async {
    if (id.isEmpty) return null;
    final r = await _get(_web('song.getDetails', {'pids': id}));
    if (r != null) {
      try {
        final body = json.decode(r.body);
        if (body is List && body.isNotEmpty) {
          return SongModel.fromSaavnWeb(Map<String, dynamic>.from(body.first as Map), quality: _quality);
        }
        if (body is Map && body['songs'] is List && (body['songs'] as List).isNotEmpty) {
          return SongModel.fromSaavnWeb(
            Map<String, dynamic>.from((body['songs'] as List).first as Map),
            quality: _quality,
          );
        }
      } catch (_) {}
    }
    return _fallbackSumitSong(id);
  }

  /// Get lyrics — LRCLIB (synced) first, then JioSaavn fallback
  Future<String?> getLyrics(String songId, {String? title, String? artist, int? durationSec}) async {
    if (songId.isEmpty) return null;

    // 1. Try LRCLIB (time-synced karaoke lyrics) — best quality
    if (title != null && title.isNotEmpty) {
      final lrclib = await _fetchLrclibLyrics(title, artist ?? '', durationSec ?? 0);
      if (lrclib != null && lrclib.trim().isNotEmpty) return lrclib;
    }

    // 2. Fallback: Backend proxy (bypasses rate limit and ISP block of lrclib.net)
    if (title != null && title.isNotEmpty) {
      final backendLyrics = await _fetchBackendLyrics(title, artist ?? '', durationSec ?? 0);
      if (backendLyrics != null && backendLyrics.trim().isNotEmpty) return backendLyrics;
    }

    // 3. Fallback: JioSaavn direct
    final direct = await _fetchSaavnLyrics(songId);
    if (direct != null && direct.trim().isNotEmpty) return direct;

    // 4. Fallback: Sumit mirror
    return _fetchMirrorLyrics(songId);
  }

  String _cleanSearchTerm(String term) {
    return term
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\b(from|feat|featuring|remix|lofi|version|edit|cover|audio|video|lyrics|lyric|full video|original|soundtrack|ost|mp3|download|karaoke|with lyrics)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanArtist(String artist) {
    String mainArtist = artist.split(RegExp(r'[,&]')).first.trim();
    mainArtist = mainArtist.split(RegExp(r'\b(feat|featuring|ft)\b', caseSensitive: false)).first.trim();
    return mainArtist;
  }

  /// LRCLIB — free, open-source synced lyrics database
  Future<String?> _fetchLrclibLyrics(String title, String artist, int durationSec) async {
    if (title.isEmpty) return null;

    // Clean soundtrack suffix (e.g. Hawayein - Jab Harry Met Sejal -> Hawayein)
    final mainTitle = title.split(' - ').first.trim();
    final cleanedTitle = _cleanSearchTerm(mainTitle);

    // Detect and bypass "Various Artists" filters
    final bool isVarious = artist.toLowerCase().contains('various artists') || artist.toLowerCase().contains('various');
    final cleanedArtist = isVarious ? '' : _cleanArtist(artist);

    // 1. Try LRCLIB's official high-precision /api/get endpoint first
    try {
      final getUrl = 'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(cleanedTitle)}&artist_name=${Uri.encodeComponent(cleanedArtist)}${durationSec > 0 ? '&duration=$durationSec' : ''}';
      final response = await _client.get(
        Uri.parse(getUrl),
        headers: {
          'User-Agent': 'RottyMusic/1.0',
          'Lrclib-Client': 'RottyMusic v1.0',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map) {
          final synced = data['syncedLyrics']?.toString();
          if (synced != null && synced.trim().isNotEmpty) return synced;
          final plain = data['plainLyrics']?.toString();
          if (plain != null && plain.trim().isNotEmpty) return plain;
        }
      }
    } catch (_) {}

    // 2. Fallback to /api/search with strict multi-criteria scoring
    try {
      final q = Uri.encodeComponent(cleanedTitle);
      final a = Uri.encodeComponent(cleanedArtist);
      final url = 'https://lrclib.net/api/search?q=$q&artist_name=$a';

      final r = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'RottyMusic/1.0',
          'Lrclib-Client': 'RottyMusic v1.0',
        },
      ).timeout(const Duration(seconds: 5));

      if (r.statusCode != 200) return null;

      final results = json.decode(r.body);
      if (results is! List || results.isEmpty) return null;

      Map? best;
      int bestScore = 999999;

      final lowerSearchTitle = cleanedTitle.toLowerCase();
      final lowerSearchArtist = cleanedArtist.toLowerCase();

      for (final item in results) {
        if (item is! Map) continue;
        final synced = item['syncedLyrics']?.toString();
        final plain = item['plainLyrics']?.toString();
        if ((synced == null || synced.isEmpty) && (plain == null || plain.isEmpty)) continue;

        final itemTitle = _cleanSearchTerm(item['trackName']?.toString() ?? '');
        final itemArtist = _cleanArtist(item['artistName']?.toString() ?? '').toLowerCase();

        if (itemTitle.isEmpty) continue;

        // Strict title validation: check word overlap
        bool isTitleMatch = false;
        final titleWords = lowerSearchTitle.split(' ').where((w) => w.length > 2).toList();
        if (titleWords.isEmpty) {
          isTitleMatch = itemTitle.contains(lowerSearchTitle) || lowerSearchTitle.contains(itemTitle);
        } else {
          int matchCount = 0;
          for (final word in titleWords) {
            if (itemTitle.contains(word)) matchCount++;
          }
          isTitleMatch = matchCount >= (titleWords.length / 2).ceil();
        }

        if (!isTitleMatch) continue; // Discard completely different songs

        final isArtistMatch = lowerSearchArtist.isEmpty || itemArtist.contains(lowerSearchArtist) || lowerSearchArtist.contains(itemArtist);

        // Discard completely different artist unless looking for various/empty artist
        if (lowerSearchArtist.isNotEmpty && !isArtistMatch) continue;

        final itemDur = item['duration'] is num ? (item['duration'] as num).toInt() : 0;
        final durDiff = durationSec > 0 ? (itemDur - durationSec).abs() : 0;

        if (durationSec > 0 && durDiff > 35) continue; // Discard completely different lengths

        int score = durDiff;
        if (lowerSearchArtist.isNotEmpty && !itemArtist.contains(lowerSearchArtist) && !lowerSearchArtist.contains(itemArtist)) {
          score += 100; // Small penalty for imperfect artist matching
        }
        if (synced == null || synced.isEmpty) {
          score += 300; // Heavy penalty for unsynced lyrics
        }

        if (score < bestScore) {
          bestScore = score;
          best = item;
        }
      }

      if (best == null) return null;

      final synced = best['syncedLyrics']?.toString();
      if (synced != null && synced.isNotEmpty) return synced;
      return best['plainLyrics']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Backend proxy for LRCLIB lyrics (bypass blocks)
  Future<String?> _fetchBackendLyrics(String title, String artist, int durationSec) async {
    if (title.isEmpty) return null;

    final mainTitle = title.split(' - ').first.trim();
    final cleanedTitle = _cleanSearchTerm(mainTitle);

    final bool isVarious = artist.toLowerCase().contains('various artists') || artist.toLowerCase().contains('various');
    final cleanedArtist = isVarious ? '' : _cleanArtist(artist);

    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.backendUrl}/api/lyrics'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': cleanedTitle,
          'artist': cleanedArtist,
          'duration': durationSec,
          'raw': true,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map) {
          final lyrics = data['lyrics']?.toString();
          if (lyrics != null && lyrics.trim().isNotEmpty) return lyrics;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Search YouTube Music/YouTube for songs
  Future<List<SongModel>> searchYouTube(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final yt = YoutubeExplode();
      final searchList = await yt.search.search(query).timeout(const Duration(seconds: 8));
      final List<SongModel> songs = [];
      
      for (final video in searchList) {
        songs.add(SongModel(
          id: 'youtube_${video.id.value}',
          title: video.title,
          artist: video.author,
          album: 'YouTube',
          image: video.thumbnails.highResUrl,
          duration: video.duration ?? const Duration(minutes: 3),
          url: '',
        ));
      }
      yt.close();
      return songs;
    } catch (e) {
      print('YouTube search error: $e');
      return [];
    }
  }

  Future<String?> _fetchSaavnLyrics(String songId) async {
    final r = await _get(_web('lyrics.getLyrics', {
      'lyrics_id': songId,
      'api_version': '4',
    }));
    if (r == null) return null;
    try {
      final body = json.decode(r.body);
      if (body is Map && body['lyrics'] != null) {
        return _cleanLyricsHtml(body['lyrics'].toString());
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _fetchMirrorLyrics(String songId) async {
    try {
      final r = await _client
          .get(Uri.parse('${ApiConstants.lyricsMirrorUrl}?id=$songId'), headers: _headers)
          .timeout(ApiConstants.timeout);
      if (r.statusCode == 200) {
        final body = json.decode(r.body);
        if (body is Map && body['lyrics'] != null) {
          return _cleanLyricsHtml(body['lyrics'].toString());
        }
      }
    } catch (_) {}
    return null;
  }

  String _cleanLyricsHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&quot;', '"')
        .trim();
  }

  List<SongModel> _parseWebSongs(String body) {
    try {
      final decoded = json.decode(body);
      final results = decoded is Map ? decoded['results'] : null;
      if (results is! List) return [];
      return _mapsToSongs(results);
    } catch (_) {
      return [];
    }
  }

  List<SongModel> _mapsToSongs(List list) => list
      .whereType<Map>()
      .map((s) => SongModel.fromSaavnWeb(Map<String, dynamic>.from(s), quality: _quality))
      .where((s) => s.id.isNotEmpty)
      .toList();

  Future<List<SongModel>> _fallbackSumitSearch(String query, int limit) async {
    try {
      final url = '${ApiConstants.fallbackBaseUrl}/search/songs?query=${Uri.encodeComponent(query)}&page=1&limit=$limit';
      final r = await _client.get(Uri.parse(url), headers: _headers).timeout(ApiConstants.timeout);
      if (r.statusCode == 200) return _parseSumitSongs(json.decode(r.body));
    } catch (_) {}
    return [];
  }

  Future<List<AlbumItem>> _fallbackSumitAlbums(String query, int limit) async {
    try {
      final url = '${ApiConstants.fallbackBaseUrl}/search/albums?query=${Uri.encodeComponent(query)}&page=1&limit=$limit';
      final r = await _client.get(Uri.parse(url), headers: _headers).timeout(ApiConstants.timeout);
      if (r.statusCode == 200) {
        return _parseList(json.decode(r.body), AlbumItem.fromJson);
      }
    } catch (_) {}
    return [];
  }

  Future<List<ArtistItem>> _fallbackSumitArtists(String query, int limit) async {
    try {
      final url = '${ApiConstants.fallbackBaseUrl}/search/artists?query=${Uri.encodeComponent(query)}&page=1&limit=$limit';
      final r = await _client.get(Uri.parse(url), headers: _headers).timeout(ApiConstants.timeout);
      if (r.statusCode == 200) {
        return _parseList(json.decode(r.body), ArtistItem.fromJson);
      }
    } catch (_) {}
    return [];
  }

  Future<List<SongModel>> _fallbackSumitAlbum(String albumId) async {
    try {
      final r = await _client
          .get(Uri.parse('${ApiConstants.fallbackBaseUrl}/albums?id=$albumId'), headers: _headers)
          .timeout(ApiConstants.timeout);
      if (r.statusCode == 200) {
        final body = json.decode(r.body);
        final data = body is Map ? body['data'] : null;
        if (data is Map && data['songs'] is List) return _parseSumitSongs(data['songs']);
      }
    } catch (_) {}
    return [];
  }

  Future<({ArtistItem? artist, List<SongModel> songs, List<AlbumItem> albums})> _fallbackSumitArtist(String id) async {
    try {
      final bool isAlphanumeric = RegExp(r'[a-zA-Z]').hasMatch(id);
      final String url;
      if (isAlphanumeric) {
        final link = 'https://www.jiosaavn.com/artist/a-songs/$id';
        url = '${ApiConstants.fallbackBaseUrl}/artists?link=${Uri.encodeComponent(link)}';
      } else {
        url = '${ApiConstants.fallbackBaseUrl}/artists?id=$id';
      }

      final r = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(ApiConstants.timeout);
      if (r.statusCode == 200) {
        final body = json.decode(r.body);
        final data = body is Map ? body['data'] : null;
        if (data is Map) {
          final artist = ArtistItem.fromJson(Map<String, dynamic>.from(data));
          
          var songs = data['topSongs'] is List
              ? _parseSumitSongs(data['topSongs'])
              : data['songs'] is List
                  ? _parseSumitSongs(data['songs'])
                  : <SongModel>[];

          final albums = data['topAlbums'] is List
              ? (data['topAlbums'] as List).whereType<Map>().map((e) => AlbumItem.fromJson(Map<String, dynamic>.from(e))).toList()
              : <AlbumItem>[];

          // If we got fewer than 15 songs, let's fetch more songs from the artist songs endpoint!
          if (songs.length < 15) {
            try {
              final String numericId = isAlphanumeric ? (data['id']?.toString() ?? id) : id;
              final songsResponse = await _client
                  .get(Uri.parse('${ApiConstants.fallbackBaseUrl}/artists/$numericId/songs?limit=25'), headers: _headers)
                  .timeout(ApiConstants.timeout);
              if (songsResponse.statusCode == 200) {
                final sBody = json.decode(songsResponse.body);
                final sData = sBody is Map ? sBody['data'] : null;
                if (sData != null) {
                  final list = sData is List ? sData : (sData is Map ? sData['songs'] : null);
                  if (list is List) {
                    final sumitSongs = _parseSumitSongs(list);
                    if (sumitSongs.isNotEmpty) {
                      songs = sumitSongs;
                    }
                  }
                }
              }
            } catch (_) {}
          }
          return (artist: artist, songs: songs, albums: albums);
        }
      }
    } catch (_) {}
    return (artist: null, songs: <SongModel>[], albums: <AlbumItem>[]);
  }

  Future<SongModel?> _fallbackSumitSong(String id) async {
    try {
      final r = await _client.get(Uri.parse('${ApiConstants.fallbackBaseUrl}/songs/$id'), headers: _headers).timeout(ApiConstants.timeout);
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final songJson = data is Map ? (data['data'] ?? data) : null;
        if (songJson is Map<String, dynamic>) return SongModel.fromJson(songJson, preferredQuality: _quality);
      }
    } catch (_) {}
    return null;
  }

  List<T> _parseList<T>(dynamic body, T Function(Map<String, dynamic>) fromJson) {
    final data = body is Map ? body['data'] : null;
    final results = data is Map ? data['results'] : null;
    if (results is! List) return [];
    return results.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
  }

  List<SongModel> _parseSumitSongs(dynamic body) {
    try {
      final data = body is Map ? body['data'] : null;
      final results = data is Map ? data['results'] : (body is List ? body : null);
      if (results is! List) return [];
      return results
          .whereType<Map>()
          .map((s) => SongModel.fromJson(Map<String, dynamic>.from(s), preferredQuality: _quality))
          .where((s) => s.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<SongModel>> getRecommendations(String songId) async {
    if (songId.isEmpty) return [];
    try {
      final uri = Uri.parse('https://www.jiosaavn.com/api.php?__call=reco.getreco&pid=$songId&_format=json&ctx=android&api_version=4');
      final r = await _get(uri);
      if (r != null) {
        final data = json.decode(r.body);
        if (data is Map && data[songId] is List) {
          return (data[songId] as List)
              .whereType<Map>()
              .map((e) => SongModel.fromSaavnReco(Map<String, dynamic>.from(e), quality: _quality))
              .where((s) => s.id.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }
}

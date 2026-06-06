import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../core/constants/api_constants.dart';
import '../core/config/app_secrets.dart';
import '../models/media_item.dart';
import '../models/song_model.dart';
import 'ghost_proxy_client.dart';
import 'storage_service.dart';
import 'dart:math' as math;

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
    List<SongModel> list = [];
    
    try {
      // Prioritize direct local search (using user's Indian IP to avoid geo-blocks)
      try {
        final r = await _get(_web('search.getResults', {
          'q': query.trim(),
          'p': '$page',
          'n': '$limit',
          'type': 'song',
        }));
        if (r != null) {
          list = _parseWebSongs(r.body);
        }
      } catch (e) {
        print("ApiService: Direct local search failed: $e");
      }

      // Fallback to proxy search if local search failed or returned nothing
      if (list.isEmpty && GhostProxyClient.isEnabled) {
        try {
          final proxyClient = GhostProxyClient();
          final results = await proxyClient.search(query.trim(), limit: limit);
          if (results != null) {
            list = results.map((e) => SongModel.fromJson(e, preferredQuality: _quality)).toList();
          }
        } catch (e) {
          print("ApiService: Search through proxy failed: $e");
        }
      }

      // Final fallback to Sumit API directly
      if (list.isEmpty) {
        try {
          list = await _fallbackSumitSearch(query, limit);
        } catch (e) {
          print("ApiService: Fallback Sumit search failed: $e");
        }
      }
    } catch (e) {
      print("ApiService: Global search error: $e");
    }

    _sortSearchSongs(list);
    return list;
  }

  Future<List<AlbumItem>> searchAlbums(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    if (GhostProxyClient.isEnabled) {
      try {
        final proxyClient = GhostProxyClient();
        final results = await proxyClient.searchAlbums(query.trim(), limit: limit);
        if (results != null) {
          return results.map((e) => AlbumItem(
            id: e['id']?.toString() ?? '',
            name: e['name']?.toString() ?? 'Album',
            image: SongModel.hiResImage(e['image']?.toString() ?? ''),
            year: e['year']?.toString() ?? '',
            language: e['language']?.toString() ?? '',
          )).where((a) => a.id.isNotEmpty).toList();
        }
      } catch (e) {
        print("ApiService: searchAlbums through proxy failed: $e");
      }
    }
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
    if (GhostProxyClient.isEnabled) {
      try {
        final proxyClient = GhostProxyClient();
        final results = await proxyClient.searchArtists(query.trim(), limit: limit);
        if (results != null) {
          return results.map((e) => ArtistItem.fromJson(e)).toList();
        }
      } catch (e) {
        print("ApiService: Search artists through proxy failed: $e");
      }
    }
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
    
    if (albumId.startsWith('name_')) {
      final albumName = albumId.replaceFirst('name_', '').trim();
      try {
        final results = await searchAlbums(albumName, limit: 1);
        if (results.isNotEmpty) {
          final realId = results.first.id;
          final songs = await getAlbumSongs(realId);
          if (songs.isNotEmpty) return songs;
        }
      } catch (_) {}
      try {
        final songs = await searchSongs(albumName, limit: 30);
        if (songs.isNotEmpty) return songs;
      } catch (_) {}
      return [];
    }

    if (GhostProxyClient.isEnabled) {
      try {
        final proxyClient = GhostProxyClient();
        final results = await proxyClient.getAlbumDetails(albumId);
        if (results != null) {
          return results.map((e) => SongModel.fromJson(e, preferredQuality: _quality)).toList();
        }
      } catch (e) {
        print("ApiService: getAlbumSongs through proxy failed: $e");
      }
    }

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
    
    // Auto-resolve search queries/names to numeric artist IDs (e.g. "Arijit Singh" or "Pritam" -> "459320")
    final bool isSearchQuery = !RegExp(r'^\d+$').hasMatch(artistId.trim());
    String resolvedId = artistId.trim();
    if (isSearchQuery) {
      try {
        final searchResults = await searchArtists(resolvedId);
        if (searchResults.isNotEmpty) {
          resolvedId = searchResults.first.id;
        }
      } catch (_) {}
    }

    if (GhostProxyClient.isEnabled) {
      try {
        final proxyClient = GhostProxyClient();
        final result = await proxyClient.getArtistDetails(resolvedId);
        if (result != null) {
          final artMap = result['artist'] as Map<String, dynamic>?;
          final songsList = result['songs'] as List?;
          final albumsList = result['albums'] as List?;
          
          String? listenersText = artMap?['follower_count']?.toString() ?? artMap?['listeners']?.toString();
          if (listenersText != null) {
            final numFollowers = int.tryParse(listenersText.replaceAll(RegExp(r'[^\d]'), ''));
            if (numFollowers != null) {
              if (numFollowers >= 1000000) {
                listenersText = '${(numFollowers / 1000000).toStringAsFixed(1)}M';
              } else if (numFollowers >= 1000) {
                listenersText = '${(numFollowers / 1000).toStringAsFixed(1)}K';
              } else {
                listenersText = '$numFollowers';
              }
            }
          }

          final artist = artMap != null ? ArtistItem(
            id: artMap['id']?.toString() ?? resolvedId,
            name: artMap['name']?.toString() ?? 'Artist',
            image: SongModel.hiResImage(artMap['image']?.toString() ?? ''),
            bio: artMap['bio']?.toString(),
            listeners: listenersText,
          ) : null;

          final songs = songsList != null
              ? songsList.map((e) => SongModel.fromJson(Map<String, dynamic>.from(e), preferredQuality: _quality)).toList()
              : <SongModel>[];
              
          final albums = albumsList != null
              ? albumsList.map((e) => AlbumItem(
                  id: e['id']?.toString() ?? '',
                  name: e['name']?.toString() ?? '',
                  image: SongModel.hiResImage(e['image']?.toString() ?? ''),
                )).toList()
              : <AlbumItem>[];
          
          if (songs.isNotEmpty || albums.isNotEmpty) {
            return (artist: artist, songs: songs, albums: albums);
          }
        }
      } catch (e) {
        print("ApiService: getArtist through proxy failed: $e");
      }
    }

    final bool isAlphanumeric = RegExp(r'[a-zA-Z]').hasMatch(resolvedId);
    if (!isAlphanumeric) {
      final r = await _get(_web('artist.getArtistPageDetails', {
        'artistId': resolvedId,
        'page': '1',
      }));
      if (r != null) {
        try {
          final body = json.decode(r.body);
          if (body is Map) {
            final name = body['name']?.toString() ?? body['title']?.toString() ?? 'Artist';
            final image = SongModel.hiResImage(body['image']?.toString() ?? '');
            
            String? bioText;
            if (body['bio'] != null) {
              if (body['bio'] is List) {
                bioText = (body['bio'] as List).join(' ');
              } else {
                bioText = body['bio'].toString();
              }
            }
            
            String? followersText;
            final rawFollowers = body['follower_count'] ?? body['fan_count'] ?? body['followerCount'] ?? body['fanCount'];
            if (rawFollowers != null) {
              final numFollowers = int.tryParse(rawFollowers.toString());
              if (numFollowers != null) {
                if (numFollowers >= 1000000) {
                  followersText = '${(numFollowers / 1000000).toStringAsFixed(1)}M';
                } else if (numFollowers >= 1000) {
                  followersText = '${(numFollowers / 1000).toStringAsFixed(1)}K';
                } else {
                  followersText = '$numFollowers';
                }
              } else {
                followersText = rawFollowers.toString();
              }
            }

            final artist = ArtistItem(
              id: resolvedId,
              name: name,
              image: image,
              bio: bioText,
              listeners: followersText,
            );
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
    return _fallbackSumitArtist(resolvedId);
  }

  Future<Map<String, List<SongModel>>> getHomeData({bool refresh = false}) async {
    final favArtists = StorageService().favoriteArtists;
    final Map<String, List<SongModel>> favoriteSections = {};

    if (favArtists.isNotEmpty) {
      try {
        for (final artist in favArtists.take(3)) {
          final songs = await searchSongs('$artist top hits', limit: 12);
          if (songs.isNotEmpty) {
            favoriteSections['Best of $artist'] = songs;
          }
        }
      } catch (e) {
        print("ApiService: Error fetching favorite artists for homepage: $e");
      }
    }

    if (GhostProxyClient.isEnabled) {
      try {
        final proxyClient = GhostProxyClient();
        final homeJson = await proxyClient.getHome(refresh: refresh);
        if (homeJson != null) {
          final sections = <String, List<SongModel>>{};
          sections.addAll(favoriteSections);
          
          int nonFavCount = 0;
          homeJson.forEach((key, value) {
            if (value is List) {
              final parsed = value
                  .map((e) => SongModel.fromJson(Map<String, dynamic>.from(e as Map), preferredQuality: _quality))
                  .toList();
              if (parsed.isNotEmpty) {
                sections[key] = _deduplicate(parsed);
                if (!key.startsWith('Best of ')) {
                  nonFavCount += parsed.length;
                }
              }
            }
          });
          
          if (nonFavCount > 0) {
            return sections;
          }
        }
      } catch (e) {
        print("ApiService: getHomeData through proxy failed: $e");
      }
    }

    final dayIndex = DateTime.now().day % 7;

    const trendingPool = [
      'latest hindi songs',
      'trending bollywood hits',
      'latest chartbusters hindi',
      'top popular hindi',
      'trending hits hindi',
      'latest songs bollywood',
      'new popular hindi hits',
    ];
    
    const bollywoodPool = [
      'bollywood hits new',
      'latest romantic hindi',
      'bollywood new romantic',
      'new hindi songs popular',
      'blockbuster hindi songs',
      'classic melodies hindi',
      'love songs hindi new',
    ];

    const punjabiPool = [
      'latest punjabi pop',
      'punjabi hits dance',
      'trending punjabi songs',
      'punjabi new releases',
      'punjabi pop hits',
      'punjabi hit tracks',
      'viral punjabi hits',
    ];

    const topHitsPool = [
      'top popular hindi songs',
      'latest international pop',
      'trending hit songs',
      'popular english hits',
      'global chartbuster songs',
      'spotify top hits hindi',
      'billboard hot english',
    ];

    const viralPool = [
      'trending viral hindi',
      'latest popular songs',
      'viral hit songs',
      'tiktok trending hindi',
      'viral hit list hindi',
      'popular viral track',
      'social media hit songs',
    ];

    const newReleasesPool = [
      'new release songs',
      'latest hindi tracks',
      'latest romantic songs',
      'fresh music global',
      'new bollywood releases',
      'latest pop singles',
      'fresh releases hindi',
    ];

    const editorsPicksPool = [
      'best of bollywood romantic',
      'top hits hindi melodies',
      'latest romantic hindi',
      'melody hits hindi',
      'curated romantic songs',
      'editors choice hindi',
      'melodic hits bollywood',
    ];

    final Map<String, String> targetQueries = {};

    if (favArtists.isNotEmpty) {
      for (final artist in favArtists.take(3)) {
        targetQueries['Best of $artist'] = '$artist top hits';
      }
    }

    targetQueries.addAll({
      'Trending': trendingPool[dayIndex],
      'Top Hits': topHitsPool[dayIndex],
      'Bollywood': bollywoodPool[dayIndex],
      'Punjabi': punjabiPool[dayIndex],
      'Viral Songs': viralPool[dayIndex],
      'New Releases': newReleasesPool[dayIndex],
      'Editor\'s Picks': editorsPicksPool[dayIndex],
      'Weekly Top Songs': topHitsPool[(dayIndex + 3) % 7], // Offset slightly for variety
    });

    final keys = targetQueries.keys.toList();
    final futures = keys.map((key) async {
      try {
        return await searchSongs(targetQueries[key]!, limit: 12);
      } catch (e) {
        print("ApiService: Error loading home section fallback for $key: $e");
        return <SongModel>[];
      }
    });
    final resultsList = await Future.wait(futures);

    final sections = <String, List<SongModel>>{};
    for (int i = 0; i < keys.length; i++) {
      final songs = resultsList[i];
      if (songs.isNotEmpty) {
        // Slightly shuffle to give fresh placement order
        final temp = List<SongModel>.from(songs);
        if (temp.length > 3) {
          final rng = math.Random();
          // Shuffle sublist elements to keep top elements relevant but dynamic
          for (int j = temp.length - 1; j > 0; j--) {
            final idx = rng.nextInt(j + 1);
            final val = temp[j];
            temp[j] = temp[idx];
            temp[idx] = val;
          }
        }
        sections[keys[i]] = temp;
      }
    }

    return sections;
  }

  Future<List<SongModel>> getGenreSongs(String genre) async {
    List<SongModel> list = [];
    try {
      final queries = _getGenreQueries(genre);
      final futures = queries.map((q) => searchSongs(q, limit: 20));
      final results = await Future.wait(futures);
      final merged = <SongModel>[];
      for (final songs in results) {
        merged.addAll(songs);
      }
      list = _deduplicate(merged);
      _sortSearchSongs(list);
    } catch (e) {
      print("ApiService: Direct local genre search failed: $e");
    }

    if (list.isEmpty && GhostProxyClient.isEnabled) {
      try {
        final proxyClient = GhostProxyClient();
        final results = await proxyClient.getGenreSongs(genre);
        if (results != null) {
          list = results.map((e) => SongModel.fromJson(e, preferredQuality: _quality)).toList();
          _sortSearchSongs(list);
        }
      } catch (e) {
        print("ApiService: getGenreSongs through proxy failed: $e");
      }
    }

    return list;
  }

  List<String> _getGenreQueries(String genre) {
    return switch (genre.toLowerCase()) {
      'love' || 'romantic' => [
          'Latest Hindi Romance',
          'Hindi Love Songs',
          'Hindi Romantic Hits',
        ],
      'devotional' => [
          'Hindi Bhakti Bhajans',
          'Aarti Bhakti Sangrah',
          'Krishna Bhajans popular',
        ],
      'party' => [
          'Latest Bollywood Dance',
          'Hindi Party Hits',
          'Punjabi Dance Club',
        ],
      'workout' => [
          'Gym Workout Beats',
          'High Energy Workout EDM',
        ],
      'chill' => [
          'lofi hindi',
          'hindi lofi hits',
          'bollywood lofi',
          'lofi chill hindi',
          'acoustic hindi songs',
        ],
      'sad' => [
          'Sad Hindi Dard',
          'Breakup Sad Hindi',
          'Mellow Sad Hindi',
        ],
      'punjabi' => [
          'Latest Punjabi Pop',
          'Punjabi Hits dance',
          'Trending Punjabi Songs',
        ],
      'english' => [
          'popular english pop hits 2026',
          'trending english pop hits',
        ],
      _ => ['$genre Hits'],
    };
  }

  Future<SongModel?> getSongDetails(String id) async {
    if (id.isEmpty) return null;
    if (GhostProxyClient.isEnabled) {
      try {
        final proxyClient = GhostProxyClient();
        final detailsJson = await proxyClient.getSongDetails(id);
        if (detailsJson != null) {
          return SongModel.fromJson(detailsJson, preferredQuality: _quality);
        }
      } catch (e) {
        print("ApiService: getSongDetails through proxy failed: $e");
      }
    }
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

    // 1. Try Backend proxy (bypasses rate limit and ISP block of lrclib.net instantly)
    if (title != null && title.isNotEmpty) {
      final backendLyrics = await _fetchBackendLyrics(title, artist ?? '', durationSec ?? 0);
      if (backendLyrics != null && backendLyrics.trim().isNotEmpty) return backendLyrics;
    }

    // 2. Try LRCLIB (time-synced karaoke lyrics) direct
    if (title != null && title.isNotEmpty) {
      final lrclib = await _fetchLrclibLyrics(title, artist ?? '', durationSec ?? 0);
      if (lrclib != null && lrclib.trim().isNotEmpty) return lrclib;
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
      ).timeout(const Duration(seconds: 10));

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
      final queryStr = '$cleanedTitle $cleanedArtist'.trim();
      final q = Uri.encodeComponent(queryStr);
      final url = 'https://lrclib.net/api/search?q=$q';

      final r = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'RottyMusic/1.0',
          'Lrclib-Client': 'RottyMusic v1.0',
        },
      ).timeout(const Duration(seconds: 10));

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

        if (durationSec > 0 && durDiff > 80) continue; // Discard completely different lengths

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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map) {
          final lyrics = data['lyrics']?.toString();
          if (lyrics != null && lyrics.trim().isNotEmpty) return lyrics;
        }
      }
    } catch (e) {
      print('Backend lyrics proxy error: $e');
    }
    return null;
  }



  /// Generates dynamic AI lyrics using the backend server.
  Future<String?> generateLyrics({
    required String prompt,
    required String genre,
  }) async {
    final proxyClient = GhostProxyClient();
    if (GhostProxyClient.isEnabled) {
      final res = await proxyClient.generateLyrics(
        prompt: prompt,
        genre: genre,
      );
      if (res != null) return res;
    }

    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.backendUrl}/api/generate-lyrics'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'prompt': prompt,
          'genre': genre,
          'groq_api_key': AppSecrets.groqApiKey,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        return body['lyrics']?.toString();
      }
    } catch (e) {
      print('Standard AI lyrics request failed: $e');
    }
    return null;
  }

  /// Generates a premium AI song on the server side securely.
  Future<Map<String, dynamic>?> generateSong({
    required String prompt,
    required String genre,
    required String vocalGender,
    required String vocalExpression,
    required bool isInstrumental,
    required String customLyrics,
    bool forceBackup = false,
  }) async {
    // Attempt secure GhostProxyClient execution first
    final proxyClient = GhostProxyClient();
    if (GhostProxyClient.isEnabled) {
      final res = await proxyClient.generateSong(
        prompt: prompt,
        genre: genre,
        vocalGender: vocalGender,
        vocalExpression: vocalExpression,
        isInstrumental: isInstrumental,
        customLyrics: customLyrics,
        forceBackup: forceBackup,
      );
      if (res != null) return res;
    }

    // Standard raw JSON fallback for dev ease
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.backendUrl}/api/generate-song'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'prompt': prompt,
          'genre': genre,
          'vocal_gender': vocalGender,
          'vocal_expression': vocalExpression,
          'is_instrumental': isInstrumental,
          'custom_lyrics': customLyrics,
          'force_backup': forceBackup,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Standard AI song generation request failed: $e');
    }
    return null;
  }

  /// Secure status polling method for asynchronous music composition
  Future<Map<String, dynamic>?> getGenerationStatus(String taskId) async {
    final proxyClient = GhostProxyClient();
    if (GhostProxyClient.isEnabled) {
      final res = await proxyClient.getGenerationStatus(taskId);
      if (res != null) return res;
    }

    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.backendUrl}/api/generation-status'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'taskId': taskId}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Standard generation status polling failed: $e');
    }
    return null;
  }

  /// Search YouTube Music/YouTube for songs
  Future<List<SongModel>> searchYouTube(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final yt = YoutubeExplode();
      
      // Refine query to bias search results towards music/song
      String targetQuery = query.trim();
      final lowerQ = targetQuery.toLowerCase();
      if (!lowerQ.contains('song') && 
          !lowerQ.contains('music') && 
          !lowerQ.contains('audio') && 
          !lowerQ.contains('video') && 
          !lowerQ.contains('lyrics') && 
          !lowerQ.contains('lyric') && 
          !lowerQ.contains('lofi') && 
          !lowerQ.contains('remix')) {
        targetQuery = '$targetQuery song';
      }

      final searchList = await yt.search.search(targetQuery).timeout(const Duration(seconds: 8));
      final List<SongModel> songs = [];
      
      for (final video in searchList) {
        // Filter out short clips (like shorts) and very long compilation/playlist videos
        final duration = video.duration;
        if (duration != null) {
          if (duration.inSeconds < 60 || duration.inSeconds > 600) {
            continue;
          }
        }

        // Filter out non-music video titles
        final lowerTitle = video.title.toLowerCase();
        final ignoreKeywords = [
          'vlog', 'reaction', 'review', 'interview', 'gaming', 'unboxing', 
          'full episode', 'promo', 'tutorial', 'how to', 'compilation', 
          'season', 'podcast', 'gameplay', 'talk show', 'reaction video', 'blog'
        ];
        bool shouldIgnore = false;
        for (final kw in ignoreKeywords) {
          if (lowerTitle.contains(kw)) {
            shouldIgnore = true;
            break;
          }
        }
        if (shouldIgnore) continue;

        songs.add(SongModel(
          id: 'youtube_${video.id.value}',
          title: video.title,
          artist: video.author,
          album: 'YouTube',
          image: video.thumbnails.highResUrl,
          duration: duration ?? const Duration(minutes: 3),
          url: '',
        ));
      }
      yt.close();
      return _deduplicate(songs);
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

  List<SongModel> _mapsToSongs(List list) {
    final parsed = list
        .whereType<Map>()
        .map((s) => SongModel.fromSaavnWeb(Map<String, dynamic>.from(s), quality: _quality))
        .where((s) => s.id.isNotEmpty)
        .toList();
    return _deduplicate(parsed);
  }

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
      final parsed = results
          .whereType<Map>()
          .map((s) => SongModel.fromJson(Map<String, dynamic>.from(s), preferredQuality: _quality))
          .where((s) => s.id.isNotEmpty)
          .toList();
      return _deduplicate(parsed);
    } catch (_) {
      return [];
    }
  }

  Future<List<SongModel>> getRecommendations(
    String songId, {
    String? title,
    String? artist,
    int limit = 15,
  }) async {
    if (songId.isEmpty) return [];
    if (GhostProxyClient.isEnabled) {
      try {
        final proxyClient = GhostProxyClient();
        final list = await proxyClient.getRecommendations(
          songId,
          limit: limit,
          title: title,
          artist: artist,
        );
        if (list != null) {
          final parsed = list
              .map((e) => SongModel.fromJson(e, preferredQuality: _quality))
              .toList();
          return _deduplicate(parsed);
        }
      } catch (e) {
        print("ApiService: getRecommendations through proxy failed: $e");
      }
    }
    try {
      final uri = Uri.parse('https://www.jiosaavn.com/api.php?__call=reco.getreco&pid=$songId&_format=json&ctx=android&api_version=4');
      final r = await _get(uri);
      if (r != null) {
        final data = json.decode(r.body);
        if (data is Map && data[songId] is List) {
          final parsed = (data[songId] as List)
              .whereType<Map>()
              .map((e) => SongModel.fromSaavnReco(Map<String, dynamic>.from(e), quality: _quality))
              .where((s) => s.id.isNotEmpty)
              .toList();
          return _deduplicate(parsed);
        }
      }
    } catch (_) {}

    // Fallback: search for songs by primary artist or title
    if (artist != null && artist.isNotEmpty && !_isGenericArtist(artist)) {
      final cleanArtist = artist.split(RegExp(r'[,&]')).first.trim();
      if (cleanArtist.isNotEmpty) {
        try {
          return await searchSongs(cleanArtist, limit: limit);
        } catch (_) {}
      }
    }
    if (title != null && title.isNotEmpty) {
      try {
        return await searchSongs(title, limit: limit);
      } catch (_) {}
    }
    return [];
  }

  bool _isGenericArtist(String artist) {
    final lower = artist.trim().toLowerCase();
    return lower.isEmpty ||
        lower == 'various artists' ||
        lower == 'various' ||
        lower == 'unknown' ||
        lower == 'artist' ||
        lower == 'singers' ||
        lower == 'unknown artist' ||
        lower == 'various artist' ||
        lower == 'multi-artist' ||
        lower == 'multi artist';
  }

  List<SongModel> _deduplicate(List<SongModel> songs) {
    final seen = <String>{};
    final List<SongModel> result = [];
    for (final s in songs) {
      if (s.id.isEmpty) continue;
      final title = s.title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final primaryArtist = s.artist.split(RegExp(r'[,&]')).first.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      
      if (_isGenericArtist(primaryArtist)) {
        result.add(s);
        continue;
      }

      final key = '$title|$primaryArtist';
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(s);
      }
    }
    return result;
  }

  void _sortSearchSongs(List<SongModel> list) {
    list.sort((a, b) {
      final aOrig = _isOriginalSongLocal(a);
      final bOrig = _isOriginalSongLocal(b);
      if (aOrig && !bOrig) return -1;
      if (!aOrig && bOrig) return 1;
      return 0;
    });
  }

  bool _isOriginalSongLocal(SongModel song) {
    final title = song.title.toLowerCase();
    final album = song.album.toLowerCase();
    if (title.contains('remix') || title.contains('re-mix') || title.contains('mashup') || title.contains('mash-up') ||
        title.contains('lofi') || title.contains('lo-fi') || title.contains('slowed') ||
        title.contains('reverb') || title.contains('sped up') || title.contains('cover') ||
        title.contains('tribute') || title.contains('instrumental') || title.contains('karaoke') ||
        title.contains('sad version') || title.contains('female version') || title.contains('male version') ||
        title.contains('ringtone') || title.contains('bgm') || title.contains('acoustic') ||
        title.contains('dj ') || title.contains(' dj') || title.contains('trap mix') ||
        title.contains('non stop') || title.contains('non-stop') || title.contains('unplugged') ||
        title.contains('lullaby') || title.contains('slow ') || title.contains('sped-up') ||
        title.contains('reverbed') || title.contains('chillout') || title.contains('extended mix') ||
        title.contains('radio edit') || title.contains('club mix') || title.contains('remixed') ||
        title.contains('synthwave') || title.contains('piano version') || title.contains('violin version') ||
        title.contains('re-created') || title.contains('recreated') ||
        album.contains('remix') || album.contains('lofi') || album.contains('covers')) {
      return false;
    }
    return true;
  }
}

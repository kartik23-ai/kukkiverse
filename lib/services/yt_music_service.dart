import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';
import '../models/media_item.dart';
import 'invidious_service.dart'; // For upgradeYoutubeThumbnail helper

class YtMusicService {
  YtMusicService._internal();
  static final YtMusicService instance = YtMusicService._internal();
  factory YtMusicService() => instance;

  final http.Client _client = http.Client();

  static const String _apiKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  static const String _endpoint = 'https://music.youtube.com/youtubei/v1/browse?key=$_apiKey&prettyPrint=false';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
    'X-Goog-Api-Format-Version': '1',
    'X-YouTube-Client-Name': '66',
    'X-YouTube-Client-Version': '1.20250310.01.00',
    'Origin': 'https://music.youtube.com',
    'Referer': 'https://music.youtube.com/',
  };

  /// Fetch the official YouTube Music home feed and parse sections
  Future<Map<String, List<dynamic>>> getHomeSections({bool refresh = false}) async {
    try {
      debugPrint('[YtMusicService] Fetching official YouTube Music homepage...');
      final Map<String, dynamic> body = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20250310.01.00',
            'hl': 'en',
            'gl': 'IN',
            'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
          }
        },
        'browseId': 'FEmusic_home'
      };

      final response = await _client.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw StateError('YouTube Music API returned status: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final sections = <String, List<dynamic>>{};

      final contents = data['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
      if (contents is List) {
        for (final section in contents) {
          final shelf = section['musicCarouselShelfRenderer'];
          if (shelf == null) continue;

          // Extract category title
          final titleRuns = shelf['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']?['runs'];
          if (titleRuns == null || titleRuns.isEmpty) continue;
          final title = titleRuns[0]['text'] as String? ?? 'Featured';

          final List<dynamic> items = [];
          final shelfContents = shelf['contents'];
          if (shelfContents is List) {
            for (final item in shelfContents) {
              final twoRow = item['musicTwoRowItemRenderer'];
              final listItem = item['musicResponsiveListItemRenderer'];

              if (twoRow != null) {
                final parsed = _parseTwoRowRenderer(twoRow);
                if (parsed != null) items.add(parsed);
              } else if (listItem != null) {
                final parsed = _parseResponsiveListItemRenderer(listItem);
                if (parsed != null) items.add(parsed);
              }
            }
          }

          if (items.isNotEmpty) {
            sections[title] = items;
          }
        }
      }

      debugPrint('[YtMusicService] Parsed ${sections.length} homepage sections successfully.');
      return sections;
    } catch (e) {
      debugPrint('[YtMusicService] Error loading home sections: $e');
      return {};
    }
  }

  /// Parse a two-row carousel item renderer (Grid style)
  dynamic _parseTwoRowRenderer(Map<String, dynamic> json) {
    try {
      final titleRuns = json['title']?['runs'];
      if (titleRuns == null || titleRuns.isEmpty) return null;
      final title = titleRuns[0]['text'] as String? ?? 'Unknown';

      // Thumbnail
      final thumbnails = json['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
      var imageUrl = '';
      if (thumbnails is List && thumbnails.isNotEmpty) {
        imageUrl = thumbnails.last['url']?.toString() ?? '';
      }
      imageUrl = upgradeYoutubeThumbnail(imageUrl);

      // Endpoint
      final navigationEndpoint = json['navigationEndpoint'];
      final watchEndpoint = navigationEndpoint?['watchEndpoint'];
      final browseEndpoint = navigationEndpoint?['browseEndpoint'];

      final subtitleRuns = json['subtitle']?['runs'];
      final subtitle = _parseSubtitleRuns(subtitleRuns);

      if (watchEndpoint != null) {
        // Playable Song
        final videoId = watchEndpoint['videoId'] as String? ?? '';
        if (videoId.isEmpty) return null;

        return SongModel(
          id: 'youtube_$videoId',
          title: title,
          artist: subtitle.artist.isNotEmpty ? subtitle.artist : 'Various Artists',
          album: subtitle.type.isNotEmpty ? subtitle.type : 'Single',
          image: imageUrl,
          duration: subtitle.duration,
          url: '',
        );
      } else if (browseEndpoint != null) {
        // Playlist or Album
        final browseId = browseEndpoint['browseId'] as String? ?? '';
        if (browseId.isEmpty) return null;

        // If it starts with MPRE or is an album, keep ID, otherwise mark as playlist prefix
        final cleanId = browseId.startsWith('MPRE') || browseId.startsWith('FEmusic_album')
            ? browseId
            : 'youtube_playlist_$browseId';

        return AlbumItem(
          id: cleanId,
          name: title,
          image: imageUrl,
          year: subtitle.type.isNotEmpty ? subtitle.type : 'YouTube',
          language: subtitle.artist.isNotEmpty ? subtitle.artist : 'Official Release',
        );
      }
    } catch (e) {
      debugPrint('[YtMusicService] Error parsing two-row renderer: $e');
    }
    return null;
  }

  /// Parse a list item renderer (List style)
  dynamic _parseResponsiveListItemRenderer(Map<String, dynamic> json) {
    try {
      // Title
      final flexColumns = json['flexColumns'];
      if (flexColumns is! List || flexColumns.isEmpty) return null;

      final titleCol = flexColumns[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
      if (titleCol == null || titleCol.isEmpty) return null;
      final title = titleCol[0]['text'] as String? ?? 'Unknown';

      // Thumbnail
      final thumbnails = json['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
      var imageUrl = '';
      if (thumbnails is List && thumbnails.isNotEmpty) {
        imageUrl = thumbnails.last['url']?.toString() ?? '';
      }
      imageUrl = upgradeYoutubeThumbnail(imageUrl);

      // Endpoint
      final navigationEndpoint = titleCol[0]['navigationEndpoint'];
      final watchEndpoint = navigationEndpoint?['watchEndpoint'];
      final browseEndpoint = navigationEndpoint?['browseEndpoint'];

      // Subtitle (second flex column contains description runs)
      dynamic subtitleRuns;
      if (flexColumns.length > 1) {
        subtitleRuns = flexColumns[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
      }
      final subtitle = _parseSubtitleRuns(subtitleRuns);

      if (watchEndpoint != null) {
        final videoId = watchEndpoint['videoId'] as String? ?? '';
        if (videoId.isEmpty) return null;

        return SongModel(
          id: 'youtube_$videoId',
          title: title,
          artist: subtitle.artist.isNotEmpty ? subtitle.artist : 'Various Artists',
          album: subtitle.type.isNotEmpty ? subtitle.type : 'Single',
          image: imageUrl,
          duration: subtitle.duration,
          url: '',
        );
      } else if (browseEndpoint != null) {
        final browseId = browseEndpoint['browseId'] as String? ?? '';
        if (browseId.isEmpty) return null;

        final cleanId = browseId.startsWith('MPRE') || browseId.startsWith('FEmusic_album')
            ? browseId
            : 'youtube_playlist_$browseId';

        return AlbumItem(
          id: cleanId,
          name: title,
          image: imageUrl,
          year: subtitle.type.isNotEmpty ? subtitle.type : 'YouTube',
          language: subtitle.artist.isNotEmpty ? subtitle.artist : 'Official Release',
        );
      }
    } catch (e) {
      debugPrint('[YtMusicService] Error parsing responsive list renderer: $e');
    }
    return null;
  }

  /// Helper to extract artist, type, and duration from subtitle runs
  _SubtitleData _parseSubtitleRuns(dynamic runs) {
    var artist = '';
    var type = '';
    var duration = const Duration(seconds: 0);

    if (runs is List) {
      final List<String> parts = [];
      for (final run in runs) {
        final text = run['text']?.toString().trim() ?? '';
        if (text.isEmpty || text == '•') continue;
        parts.add(text);
      }

      for (final part in parts) {
        if (part.toLowerCase() == 'song' || part.toLowerCase() == 'video' || part.toLowerCase() == 'album' || part.toLowerCase() == 'playlist') {
          type = part;
        } else if (RegExp(r'^\d+:\d+$').hasMatch(part)) {
          // Duration format (e.g. 3:45)
          final split = part.split(':');
          final m = int.tryParse(split[0]) ?? 0;
          final s = int.tryParse(split[1]) ?? 0;
          duration = Duration(minutes: m, seconds: s);
        } else {
          // Likely artist name
          if (artist.isEmpty) {
            artist = part;
          } else {
            artist += ', $part';
          }
        }
      }
    }

    return _SubtitleData(artist, type, duration);
  }

  /// Recursively find all nested nodes with a given key name in a parsed JSON structure
  List<Map<String, dynamic>> findNodes(dynamic json, String key) {
    final List<Map<String, dynamic>> results = [];
    void search(dynamic val) {
      if (val is Map) {
        if (val.containsKey(key)) {
          final node = val[key];
          if (node is Map) {
            results.add(Map<String, dynamic>.from(node));
          }
        }
        for (final v in val.values) {
          search(v);
        }
      } else if (val is List) {
        for (final v in val) {
          search(v);
        }
      }
    }
    search(json);
    return results;
  }

  /// Parses a responsive list item renderer into a SongModel
  SongModel? parseSongFromResponsiveListItem(Map<String, dynamic> json) {
    try {
      String? videoId;

      if (json['playlistItemData'] != null) {
        videoId = json['playlistItemData']['videoId']?.toString();
      }

      final flexColumns = json['flexColumns'];
      if (videoId == null && flexColumns is List && flexColumns.isNotEmpty) {
        final titleRuns = flexColumns[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
        if (titleRuns is List && titleRuns.isNotEmpty) {
          final endpoint = titleRuns[0]['navigationEndpoint'];
          if (endpoint != null && endpoint['watchEndpoint'] != null) {
            videoId = endpoint['watchEndpoint']['videoId']?.toString();
          }
        }
      }

      if (videoId == null && json['overlay'] != null) {
        final playEndpoint = json['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint'];
        if (playEndpoint != null) {
          videoId = playEndpoint['videoId']?.toString();
        }
      }

      if (videoId == null || videoId.isEmpty) return null;

      String title = 'Unknown';
      if (flexColumns is List && flexColumns.isNotEmpty) {
        final titleRuns = flexColumns[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
        if (titleRuns is List && titleRuns.isNotEmpty) {
          title = titleRuns[0]['text']?.toString() ?? 'Unknown';
        }
      }

      String artist = 'Various Artists';
      String album = 'Single';
      Duration duration = const Duration(seconds: 0);

      if (flexColumns is List && flexColumns.length > 1) {
        final subtitleRuns = flexColumns[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
        if (subtitleRuns is List) {
          final parsed = _parseSubtitleRuns(subtitleRuns);
          artist = parsed.artist.isNotEmpty ? parsed.artist : artist;
          album = parsed.type.isNotEmpty ? parsed.type : album;
          duration = parsed.duration;
        }
      }

      var imageUrl = '';
      final thumbnails = json['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
      if (thumbnails is List && thumbnails.isNotEmpty) {
        imageUrl = thumbnails.last['url']?.toString() ?? '';
      }
      imageUrl = upgradeYoutubeThumbnail(imageUrl);

      return SongModel(
        id: 'youtube_$videoId',
        title: title,
        artist: artist,
        album: album,
        image: imageUrl,
        duration: duration,
        url: '',
      );
    } catch (e) {
      debugPrint('[YtMusicService] Error parsing responsive list item: $e');
    }
    return null;
  }

  /// Search for songs on YouTube Music using Innertube
  Future<List<SongModel>> searchSongs(String query, {int limit = 15}) async {
    try {
      debugPrint('[YtMusicService] Searching songs directly on YouTube Music for: "$query"');
      final Map<String, dynamic> body = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20250310.01.00',
            'hl': 'en',
            'gl': 'IN',
            'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
          }
        },
        'query': query,
        'params': 'EgWKAQIIAWoKEAkQBRAKEAMQHg%3D%3D' // Filter for songs only
      };

      final response = await _client.post(
        Uri.parse('https://music.youtube.com/youtubei/v1/search?key=$_apiKey&prettyPrint=false'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw StateError('Search API returned status: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List<SongModel> songs = [];

      final listItems = findNodes(data, 'musicResponsiveListItemRenderer');
      for (final item in listItems) {
        final parsed = parseSongFromResponsiveListItem(item);
        if (parsed != null) {
          songs.add(parsed);
          if (songs.length >= limit) break;
        }
      }
      debugPrint('[YtMusicService] Search found ${songs.length} songs');
      return songs;
    } catch (e) {
      debugPrint('[YtMusicService] Error searching songs: $e');
      return [];
    }
  }

  /// Search for playlists/albums on YouTube Music using Innertube
  Future<List<AlbumItem>> searchPlaylists(String query, {int limit = 10}) async {
    try {
      debugPrint('[YtMusicService] Searching playlists directly on YouTube Music for: "$query"');
      final Map<String, dynamic> body = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20250310.01.00',
            'hl': 'en',
            'gl': 'IN',
            'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
          }
        },
        'query': query,
        'params': 'EgWKAQIIAWoKEAkQChAFEAMQHg%3D%3D' // Filter for playlists only
      };

      final response = await _client.post(
        Uri.parse('https://music.youtube.com/youtubei/v1/search?key=$_apiKey&prettyPrint=false'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw StateError('Search API returned status: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List<AlbumItem> playlists = [];

      final listItems = findNodes(data, 'musicResponsiveListItemRenderer');
      for (final item in listItems) {
        final titleRuns = item['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
        if (titleRuns == null || titleRuns.isEmpty) continue;
        final title = titleRuns[0]['text'] as String? ?? 'Unknown';

        final browseEndpoint = titleRuns[0]['navigationEndpoint']?['browseEndpoint'] ?? item['navigationEndpoint']?['browseEndpoint'];
        if (browseEndpoint == null) continue;
        final browseId = browseEndpoint['browseId'] as String? ?? '';
        if (browseId.isEmpty) continue;

        var imageUrl = '';
        final thumbnails = item['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
        if (thumbnails is List && thumbnails.isNotEmpty) {
          imageUrl = thumbnails.last['url']?.toString() ?? '';
        }
        imageUrl = upgradeYoutubeThumbnail(imageUrl);

        // Subtitle containing author/song count
        String author = 'YouTube';
        final subtitleRuns = item['flexColumns']?[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
        if (subtitleRuns is List && subtitleRuns.isNotEmpty) {
          author = subtitleRuns[0]['text']?.toString() ?? author;
        }

        playlists.add(AlbumItem(
          id: 'youtube_playlist_$browseId',
          name: title,
          image: imageUrl,
          year: author,
          language: 'Playlist',
        ));
        if (playlists.length >= limit) break;
      }
      debugPrint('[YtMusicService] Search found ${playlists.length} playlists');
      return playlists;
    } catch (e) {
      debugPrint('[YtMusicService] Error searching playlists: $e');
      return [];
    }
  }

  /// Resolve an artist name to their official YouTube Music browse ID
  Future<String?> searchArtistBrowseId(String query) async {
    try {
      final Map<String, dynamic> body = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20250310.01.00',
            'hl': 'en',
            'gl': 'IN',
            'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
          }
        },
        'query': query,
      };

      final response = await _client.post(
        Uri.parse('https://music.youtube.com/youtubei/v1/search?key=$_apiKey&prettyPrint=false'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final listItems = findNodes(data, 'musicResponsiveListItemRenderer');
      for (final item in listItems) {
        final flexColumns = item['flexColumns'];
        if (flexColumns is List && flexColumns.isNotEmpty) {
          final titleRuns = flexColumns[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
          if (titleRuns is List && titleRuns.isNotEmpty) {
            final browseId = titleRuns[0]['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString();
            if (browseId != null && (browseId.startsWith('UC') || browseId.startsWith('FEmusic_library_priv_artist'))) {
              return browseId;
            }
          }
        }
        final navigationEndpoint = item['navigationEndpoint'];
        if (navigationEndpoint != null) {
          final browseId = navigationEndpoint['browseEndpoint']?['browseId']?.toString();
          if (browseId != null && (browseId.startsWith('UC') || browseId.startsWith('FEmusic_library_priv_artist'))) {
            return browseId;
          }
        }
      }
    } catch (e) {
      debugPrint('[YtMusicService] Error searching artist browse ID: $e');
    }
    return null;
  }

  /// Get playlist songs directly from Innertube
  Future<List<SongModel>> getPlaylistSongs(String playlistId, {int limit = 40}) async {
    try {
      final cleanId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
      debugPrint('[YtMusicService] Fetching playlist songs directly for: $cleanId');
      final Map<String, dynamic> body = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20250310.01.00',
            'hl': 'en',
            'gl': 'IN',
            'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
          }
        },
        'browseId': cleanId
      };

      final response = await _client.post(
        Uri.parse('https://music.youtube.com/youtubei/v1/browse?key=$_apiKey&prettyPrint=false'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw StateError('Playlist API returned status: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List<SongModel> songs = [];

      final listItems = findNodes(data, 'musicResponsiveListItemRenderer');
      for (final item in listItems) {
        final parsed = parseSongFromResponsiveListItem(item);
        if (parsed != null) {
          songs.add(parsed);
          if (songs.length >= limit) break;
        }
      }
      debugPrint('[YtMusicService] Playlist loaded ${songs.length} songs');
      return songs;
    } catch (e) {
      debugPrint('[YtMusicService] Error getting playlist songs: $e');
      return [];
    }
  }

  /// Fetch artist details page and parse metadata, top tracks, and albums
  Future<({ArtistItem? artist, List<SongModel> songs, List<AlbumItem> albums})> getArtistDetails(String artistIdOrName, {int songsLimit = 15}) async {
    try {
      var artistId = artistIdOrName;
      if (!artistId.startsWith('UC') && !artistId.startsWith('FEmusic_')) {
        debugPrint('[YtMusicService] Artist ID is a name. Resolving browse ID for: "$artistIdOrName"');
        final resolved = await searchArtistBrowseId(artistIdOrName);
        if (resolved != null) {
          artistId = resolved;
        } else {
          debugPrint('[YtMusicService] Could not resolve artist browse ID. Falling back to song search.');
          final songs = await searchSongs(artistIdOrName);
          final artist = ArtistItem(
            id: artistIdOrName,
            name: artistIdOrName,
            image: songs.isNotEmpty ? songs.first.image : '',
            bio: 'Official YouTube Artist Profile for $artistIdOrName',
            listeners: '100K+',
          );
          return (artist: artist, songs: songs, albums: <AlbumItem>[]);
        }
      }

      debugPrint('[YtMusicService] Browsing artist details directly for browseId: $artistId');
      final Map<String, dynamic> body = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20250310.01.00',
            'hl': 'en',
            'gl': 'IN',
            'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
          }
        },
        'browseId': artistId
      };

      final response = await _client.post(
        Uri.parse('https://music.youtube.com/youtubei/v1/browse?key=$_apiKey&prettyPrint=false'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw StateError('Artist API returned status: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      // Parse metadata
      String name = artistIdOrName;
      String imageUrl = '';
      String bio = 'YouTube Official Channel';
      
      final header = data['header']?['musicVisualHeaderRenderer'] ?? data['header']?['musicHeaderRenderer'];
      if (header != null) {
        final runs = header['title']?['runs'];
        if (runs is List && runs.isNotEmpty) {
          name = runs[0]['text']?.toString() ?? name;
        }
        final thumbnails = header['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ?? header['foregroundThumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
        if (thumbnails is List && thumbnails.isNotEmpty) {
          imageUrl = thumbnails.last['url']?.toString() ?? '';
        }
      }

      final artist = ArtistItem(
        id: artistId,
        name: name,
        image: upgradeYoutubeThumbnail(imageUrl),
        bio: bio,
        listeners: '250K+',
      );

      final List<SongModel> songs = [];
      final List<AlbumItem> albums = [];

      // Parse songs
      final listItems = findNodes(data, 'musicResponsiveListItemRenderer');
      for (final item in listItems) {
        final parsed = parseSongFromResponsiveListItem(item);
        if (parsed != null) {
          songs.add(parsed);
          if (songs.length >= songsLimit) break;
        }
      }

      // Parse albums / playlists
      final gridItems = findNodes(data, 'musicTwoRowItemRenderer');
      for (final item in gridItems) {
        final titleRuns = item['title']?['runs'];
        if (titleRuns == null || titleRuns.isEmpty) continue;
        final title = titleRuns[0]['text'] as String? ?? 'Unknown';

        final browseEndpoint = item['navigationEndpoint']?['browseEndpoint'];
        if (browseEndpoint == null) continue;
        final browseId = browseEndpoint['browseId'] as String? ?? '';
        if (browseId.isEmpty) continue;

        var img = '';
        final thumbnails = item['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
        if (thumbnails is List && thumbnails.isNotEmpty) {
          img = thumbnails.last['url']?.toString() ?? '';
        }
        img = upgradeYoutubeThumbnail(img);

        albums.add(AlbumItem(
          id: browseId.startsWith('MPRE') || browseId.startsWith('FEmusic_album') ? browseId : 'youtube_playlist_$browseId',
          name: title,
          image: img,
          year: 'YouTube',
          language: 'Release',
        ));
      }

      // Fallback search if page returned 0 songs
      if (songs.isEmpty) {
        songs.addAll(await searchSongs(name, limit: songsLimit));
      }

      debugPrint('[YtMusicService] Artist parsed successfully: "${artist.name}" with ${songs.length} songs and ${albums.length} albums.');
      return (artist: artist, songs: songs, albums: albums);
    } catch (e) {
      debugPrint('[YtMusicService] Error loading artist details: $e, falling back to search');
      final songs = await searchSongs(artistIdOrName, limit: songsLimit);
      final artist = ArtistItem(
        id: artistIdOrName,
        name: artistIdOrName,
        image: songs.isNotEmpty ? songs.first.image : '',
        bio: 'Artist profile',
        listeners: '10K+',
      );
      return (artist: artist, songs: songs, albums: <AlbumItem>[]);
    }
  }
}

class _SubtitleData {
  final String artist;
  final String type;
  final Duration duration;

  _SubtitleData(this.artist, this.type, this.duration);
}

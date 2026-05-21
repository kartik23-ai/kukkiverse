import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_secrets.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';

class SpotifyService {
  static final SpotifyService _instance = SpotifyService._internal();
  factory SpotifyService() => _instance;
  SpotifyService._internal();

  final http.Client _client = http.Client();

  /// Parse the 22-character playlist ID from a Spotify URL or URI
  String? extractPlaylistId(String url) {
    url = url.trim();
    if (url.startsWith('spotify:playlist:')) {
      return url.substring('spotify:playlist:'.length);
    }
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final idx = segments.indexOf('playlist');
      if (idx != -1 && idx + 1 < segments.length) {
        return segments[idx + 1];
      }
    } catch (_) {}

    final match = RegExp(r'playlist/([a-zA-Z0-9]{22})').firstMatch(url);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  /// Get Spotify bearer access token using Client Credentials Flow
  Future<String> _getAccessToken() async {
    final clientId = AppSecrets.spotifyClientId;
    final clientSecret = AppSecrets.spotifyClientSecret;

    if (clientId.isEmpty || clientSecret.isEmpty) {
      throw Exception('Spotify Client ID or Secret is not configured. Please add them in Settings or compile them in secrets.local.dart.');
    }

    final tokenUrl = Uri.parse('https://accounts.spotify.com/api/token');
    final authHeader = 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}';

    final response = await _client.post(
      tokenUrl,
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to authenticate with Spotify API (Status: ${response.statusCode}). Please verify your Client ID & Secret.');
    }

    final data = json.decode(response.body);
    final token = data['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found in Spotify auth response.');
    }

    return token;
  }

  /// Fetch playlist tracks (up to 100) and construct a PlaylistModel
  Future<PlaylistModel> syncPlaylist(String playlistUrl) async {
    final playlistId = extractPlaylistId(playlistUrl);
    if (playlistId == null || playlistId.isEmpty) {
      throw Exception('Invalid Spotify playlist URL. Make sure it contains a valid playlist ID.');
    }

    // 1. Try public embed page first (requires no authentication and bypasses Client Credentials limitations)
    try {
      final embedUrl = Uri.parse('https://open.spotify.com/embed/playlist/$playlistId');
      final embedResponse = await _client.get(
        embedUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (embedResponse.statusCode == 200) {
        final html = embedResponse.body;
        final scriptMatch = RegExp(r'<script\s+id="resource"\s+type="application/json">(.*?)</script>', dotAll: true).firstMatch(html)
            ?? RegExp(r'<script\s+id="initial-state"\s+type="application/json">(.*?)</script>', dotAll: true).firstMatch(html)
            ?? RegExp(r'<script\s+id="__NEXT_DATA__"\s+type="application/json">(.*?)</script>', dotAll: true).firstMatch(html);

        if (scriptMatch != null) {
          final jsonStr = scriptMatch.group(1)?.trim() ?? '';
          final decoded = json.decode(jsonStr);
          final state = decoded['props']?['pageProps']?['state'] ?? decoded['state'];
          final entity = state?['data']?['entity'];
          if (entity != null) {
            final name = entity['name']?.toString() ?? 'Spotify Sync';
            final desc = entity['subtitle']?.toString() ?? '';
            final images = entity['coverArt']?['sources'] as List?;
            final imageUrl = (images != null && images.isNotEmpty) ? images[0]['url']?.toString() ?? '' : '';

            final trackList = entity['trackList'] as List?;
            final List<SongModel> songs = [];

            if (trackList != null) {
              for (final item in trackList) {
                final uri = item['uri']?.toString() ?? '';
                final trackId = uri.split(':').last;
                if (trackId.isEmpty) continue;

                final trackName = item['title']?.toString() ?? 'Unknown Track';
                final artistNames = item['subtitle']?.toString() ?? 'Unknown Artist';
                final durationMs = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;

                songs.add(
                  SongModel(
                    id: 'spotify_track_$trackId',
                    title: trackName,
                    artist: artistNames,
                    album: 'Spotify Playlist',
                    image: imageUrl,
                    duration: Duration(milliseconds: durationMs),
                    url: '',
                  ),
                );
              }
            }

            if (songs.isNotEmpty) {
              return PlaylistModel(
                id: 'spotify_playlist_$playlistId',
                name: name,
                description: desc,
                image: imageUrl,
                songs: songs,
              );
            }
          }
        }
      }
    } catch (e) {
      // Log or print warning, then proceed to official API fallback
      print('Spotify Embed sync failed: $e. Falling back to official API...');
    }

    // 2. Fallback to official Spotify API (using user's credentials)
    final token = await _getAccessToken();

    // Fetch playlist details and tracks
    final url = Uri.parse('https://api.spotify.com/v1/playlists/$playlistId');
    final response = await _client.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch Spotify playlist (Status: ${response.statusCode}). Make sure it is public.');
    }

    final data = json.decode(response.body);
    final name = data['name']?.toString() ?? 'Spotify Sync';
    final desc = data['description']?.toString() ?? '';
    final images = data['images'] as List?;
    final imageUrl = (images != null && images.isNotEmpty) ? images[0]['url']?.toString() ?? '' : '';

    final tracksData = data['tracks']?['items'] as List?;
    final List<SongModel> songs = [];

    if (tracksData != null) {
      for (final item in tracksData) {
        final track = item['track'];
        if (track == null) continue;

        final trackId = track['id']?.toString();
        if (trackId == null || trackId.isEmpty) continue;

        final trackName = track['name']?.toString() ?? 'Unknown Track';
        
        final artistsList = track['artists'] as List?;
        final artistNames = (artistsList != null)
            ? artistsList.map((a) => a['name']?.toString() ?? '').where((n) => n.isNotEmpty).join(', ')
            : 'Various Artists';

        final albumData = track['album'];
        final albumName = albumData?['name']?.toString() ?? 'Single';
        final albumImages = albumData?['images'] as List?;
        final trackImage = (albumImages != null && albumImages.isNotEmpty)
            ? albumImages[0]['url']?.toString() ?? imageUrl
            : imageUrl;

        final durationMs = int.tryParse(track['duration_ms']?.toString() ?? '0') ?? 0;

        songs.add(
          SongModel(
            id: 'spotify_track_$trackId',
            title: trackName,
            artist: artistNames.isNotEmpty ? artistNames : 'Unknown Artist',
            album: albumName,
            image: trackImage,
            duration: Duration(milliseconds: durationMs),
            url: '', // Will be dynamically resolved on play
          ),
        );
      }
    }

    return PlaylistModel(
      id: 'spotify_playlist_$playlistId',
      name: name,
      description: desc,
      image: imageUrl,
      songs: songs,
    );
  }
}

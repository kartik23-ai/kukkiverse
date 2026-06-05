import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as enc;

import '../core/constants/api_constants.dart';
import '../core/config/app_secrets.dart';

/// ═══════════════════════════════════════════════════════════════
/// Ghost Proxy Client v2.0 — AES-256-CBC decryption.
/// All API calls routed through encrypted relay.
/// No JioSaavn/YouTube URLs ever appear in the binary.
/// ═══════════════════════════════════════════════════════════════
class GhostProxyClient {
  static String get _baseUrl {
    const fromEnv = String.fromEnvironment('GHOST_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return ApiConstants.backendUrl;
  }

  static bool get isEnabled => _baseUrl.isNotEmpty;

  static const _secretKey = String.fromEnvironment(
    'GHOST_KEY',
    defaultValue: 'rotty-ghost-key-32chars-xxxxxxxx',
  );

  final http.Client _client = http.Client();

  /// Decrypt AES-256-CBC payload: "iv_base64:ciphertext_base64"
  String _decrypt(String encrypted) {
    try {
      final parts = encrypted.split(':');
      if (parts.length != 2) return '';

      final iv = enc.IV.fromBase64(parts[0]);
      final key = enc.Key.fromUtf8(_secretKey.padRight(32, '0').substring(0, 32));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      
      return encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
    } catch (e) {
      print("🔒 ROTTY SYSTEM SECURITY: Client decryption failed: $e");
      return '';
    }
  }

  /// Encrypt plaintext using AES-256-CBC: "iv_base64:ciphertext_base64"
  String _encrypt(String plainText) {
    try {
      final iv = enc.IV.fromSecureRandom(16);
      final key = enc.Key.fromUtf8(_secretKey.padRight(32, '0').substring(0, 32));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      print("🔒 ROTTY SYSTEM SECURITY: Client encryption failed: $e");
      return '';
    }
  }

  /// Common POST helper with App Check header
  Future<Map<String, dynamic>?> _post(String endpoint, Map<String, dynamic> body) async {
    if (!isEnabled) return null;
    try {
      final r = await _client.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          // Firebase App Check token would be injected here:
          // 'X-Firebase-AppCheck': await FirebaseAppCheck.instance.getToken() ?? '',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (r.statusCode == 429) {
        // Rate limited — wait and retry
        await Future.delayed(const Duration(seconds: 2));
        return null;
      }
      if (r.statusCode != 200) return null;
      return json.decode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Search songs through the ghost proxy
  Future<List<Map<String, dynamic>>?> search(String query, {int limit = 25}) async {
    final resp = await _post('/api/search', {'query': query, 'limit': limit});
    if (resp == null || resp['d'] == null) return null;
    try {
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      final list = json.decode(decrypted) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Search artists through the ghost proxy
  Future<List<Map<String, dynamic>>?> searchArtists(String query, {int limit = 20}) async {
    final resp = await _post('/api/search-artists', {'query': query, 'limit': limit});
    if (resp == null || resp['d'] == null) return null;
    try {
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      final list = json.decode(decrypted) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Get encrypted stream URL (decrypted in-memory only)
  Future<String?> getStreamUrl(String songId, {String? title, String? artist}) async {
    final resp = await _post('/api/stream', {
      'id': songId,
      'title': title ?? '',
      'artist': artist ?? '',
    });
    if (resp == null || resp['d'] == null) return null;
    try {
      final url = _decrypt(resp['d'] as String);
      return url.isNotEmpty ? url : null;
    } catch (_) {
      return null;
    }
  }

  /// Get synced lyrics through proxy
  Future<String?> getLyrics(String title, String artist, {int duration = 0}) async {
    final resp = await _post('/api/lyrics', {
      'title': title,
      'artist': artist,
      'duration': duration,
    });
    if (resp == null || resp['d'] == null) return null;
    try {
      final lyrics = _decrypt(resp['d'] as String);
      return lyrics.isNotEmpty ? lyrics : null;
    } catch (_) {
      return null;
    }
  }

  /// Get song details through proxy
  Future<Map<String, dynamic>?> getSongDetails(String songId) async {
    final resp = await _post('/api/details', {'id': songId});
    if (resp == null || resp['d'] == null) return null;
    try {
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      return json.decode(decrypted) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Get home sections through proxy
  Future<Map<String, dynamic>?> getHome() async {
    final resp = await _post('/api/home', {});
    if (resp == null || resp['d'] == null) return null;
    try {
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      return json.decode(decrypted) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Get song recommendations through proxy
  Future<List<Map<String, dynamic>>?> getRecommendations(String songId, {int limit = 15}) async {
    final resp = await _post('/api/recommendations', {'id': songId, 'limit': limit});
    if (resp == null || resp['d'] == null) return null;
    try {
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      final list = json.decode(decrypted) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Get genre/category playlist songs through proxy
  Future<List<Map<String, dynamic>>?> getGenreSongs(String genre) async {
    final resp = await _post('/api/genre', {'genre': genre});
    if (resp == null || resp['d'] == null) return null;
    try {
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      final list = json.decode(decrypted) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Search albums through proxy
  Future<List<Map<String, dynamic>>?> searchAlbums(String query, {int limit = 20}) async {
    final resp = await _post('/api/search-albums', {'query': query, 'limit': limit});
    if (resp == null || resp['d'] == null) return null;
    try {
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      final list = json.decode(decrypted) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Get album details through proxy
  Future<List<Map<String, dynamic>>?> getAlbumDetails(String albumId) async {
    final resp = await _post('/api/album-details', {'id': albumId});
    if (resp == null || resp['d'] == null) return null;
    try {
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      final list = json.decode(decrypted) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Get artist details through proxy
  Future<Map<String, dynamic>?> getArtistDetails(String artistId) async {
    final resp = await _post('/api/artist-details', {'id': artistId});
    if (resp == null || resp['d'] == null) return null;
    try {
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      return json.decode(decrypted) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }



  /// Generates dynamic AI lyrics using the backend server securely.
  Future<String?> generateLyrics({
    required String prompt,
    required String genre,
  }) async {
    if (!isEnabled) return null;
    try {
      final payload = json.encode({
        'prompt': prompt,
        'genre': genre,
        'groq_api_key': AppSecrets.groqApiKey,
      });
      final encrypted = _encrypt(payload);
      if (encrypted.isEmpty) return null;

      final r = await _client.post(
        Uri.parse('$_baseUrl/api/generate-lyrics'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'d': encrypted}),
      ).timeout(const Duration(seconds: 45));

      if (r.statusCode != 200) return null;
      
      final resp = json.decode(r.body) as Map<String, dynamic>;
      if (resp['d'] == null) return null;
      
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      
      final result = json.decode(decrypted) as Map<String, dynamic>;
      return result['lyrics']?.toString();
    } catch (e) {
      print('Secure AI lyrics proxy request failed: $e');
    }
    return null;
  }

  /// Generate a premium AI song on the server side securely
  Future<Map<String, dynamic>?> generateSong({
    required String prompt,
    required String genre,
    required String vocalGender,
    required String vocalExpression,
    required bool isInstrumental,
    required String customLyrics,
    bool forceBackup = false,
  }) async {
    if (!isEnabled) return null;
    try {
      final payload = json.encode({
        'prompt': prompt,
        'genre': genre,
        'vocal_gender': vocalGender,
        'vocal_expression': vocalExpression,
        'is_instrumental': isInstrumental,
        'custom_lyrics': customLyrics,
        'force_backup': forceBackup,
      });
      final encrypted = _encrypt(payload);
      if (encrypted.isEmpty) return null;

      final r = await _client.post(
        Uri.parse('$_baseUrl/api/generate-song'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'d': encrypted}),
      ).timeout(const Duration(seconds: 120));

      if (r.statusCode != 200) {
        try {
          final map = json.decode(r.body) as Map<String, dynamic>;
          return map;
        } catch (_) {
          return {
            'error': r.statusCode == 401 ? 'auth_failed' : 'failed',
            'message': 'Server returned status code ${r.statusCode}',
          };
        }
      }
      
      final resp = json.decode(r.body) as Map<String, dynamic>;
      if (resp['d'] == null) {
        // Fallback for unencrypted status/failed/captcha_required responses
        return resp;
      }
      
      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;
      
      return json.decode(decrypted) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Get status of background composition task securely
  Future<Map<String, dynamic>?> getGenerationStatus(String taskId) async {
    if (!isEnabled) return null;
    try {
      final payload = json.encode({'taskId': taskId});
      final encrypted = _encrypt(payload);
      if (encrypted.isEmpty) return null;

      final r = await _client.post(
        Uri.parse('$_baseUrl/api/generation-status'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'d': encrypted}),
      ).timeout(const Duration(seconds: 15));

      if (r.statusCode != 200) {
        try {
          final map = json.decode(r.body) as Map<String, dynamic>;
          return map;
        } catch (_) {
          return {
            'status': 'failed',
            'error': r.statusCode == 401 ? 'auth_failed' : 'failed',
            'message': 'Server status code: ${r.statusCode}',
          };
        }
      }

      final resp = json.decode(r.body) as Map<String, dynamic>;
      if (resp['d'] == null) return resp;

      final decrypted = _decrypt(resp['d'] as String);
      if (decrypted.isEmpty) return null;

      return json.decode(decrypted) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

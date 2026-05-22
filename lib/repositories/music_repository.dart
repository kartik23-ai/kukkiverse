import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/media_item.dart';
import '../models/song_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/local_audio_server.dart';

class MusicRepository {
  final ApiService _api;
  final StorageService _storage;

  MusicRepository(this._api, this._storage) {
    _api.setQuality(_storage.audioQuality);
  }

  Future<Map<String, List<SongModel>>> getHomeSections() => _api.getHomeData();
  Future<List<SongModel>> searchSongs(String q, {int limit = 25, int page = 1}) =>
      _api.searchSongs(q, limit: limit, page: page);
  Future<List<AlbumItem>> searchAlbums(String q) => _api.searchAlbums(q);
  Future<List<ArtistItem>> searchArtists(String q) => _api.searchArtists(q);
  Future<List<SongModel>> getAlbumSongs(String id) => _api.getAlbumSongs(id);
  Future<({ArtistItem? artist, List<SongModel> songs, List<AlbumItem> albums})> getArtist(String id) => _api.getArtist(id);

  Future<SongModel> resolveSong(SongModel song) async {
    if (_storage.isSongDownloaded(song.id)) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        for (final ext in ['.mp4', '.m4a', '.mp3']) {
          final localFile = File('${docDir.path}/downloads/${song.id}$ext');
          if (await localFile.exists()) {
            if (Platform.isWindows) {
              final server = LocalAudioServer();
              await server.start();
              return song.copyWith(url: 'http://127.0.0.1:${server.port}/downloads/${song.id}$ext');
            }
            return song.copyWith(url: Uri.file(localFile.path).toString());
          }
        }
      } catch (_) {}
    }

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
      } catch (_) {}
      return song;
    }

    final details = await _api.getSongDetails(song.id);
    if (details != null && details.hasPlayableUrl) return details;
    if (song.hasPlayableUrl) return song;
    return details ?? song;
  }
  Future<String?> getLyrics(String id, {String? title, String? artist, int? durationSec}) =>
      _api.getLyrics(id, title: title, artist: artist, durationSec: durationSec);
  void updateAudioQuality(String q) {
    _storage.setAudioQuality(q);
    _api.setQuality(q);
  }
}

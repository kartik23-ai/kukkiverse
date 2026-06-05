import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/media_item.dart';
import '../models/song_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/local_audio_server.dart';
import '../services/update_service.dart';

class MusicRepository {
  final ApiService _api;
  final StorageService _storage;

  MusicRepository(this._api, this._storage) {
    _api.setQuality(_storage.audioQuality);
  }

  Future<Map<String, List<SongModel>>> getHomeSections() {
    UpdateService.instance.checkForUpdates();
    return _api.getHomeData();
  }

  Future<List<SongModel>> searchSongs(String q, {int limit = 25, int page = 1}) {
    UpdateService.instance.checkForUpdates();
    return _api.searchSongs(q, limit: limit, page: page);
  }

  Future<List<AlbumItem>> searchAlbums(String q) => _api.searchAlbums(q);
  Future<List<ArtistItem>> searchArtists(String q) => _api.searchArtists(q);
  Future<List<SongModel>> getAlbumSongs(String id) => _api.getAlbumSongs(id);
  Future<List<SongModel>> getGenreSongs(String genre) {
    UpdateService.instance.checkForUpdates();
    return _api.getGenreSongs(genre);
  }
  Future<({ArtistItem? artist, List<SongModel> songs, List<AlbumItem> albums})> getArtist(String id) => _api.getArtist(id);

  Future<SongModel> resolveSong(SongModel song) async {
    UpdateService.instance.checkForUpdates();
    if (song.id.startsWith('youtube_')) {
      try {
        final videoId = song.id.replaceFirst('youtube_', '');
        final yt = YoutubeExplode();
        final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 8));
        final audioOnly = manifest.audioOnly;
        if (audioOnly.isNotEmpty) {
          final bestAudio = audioOnly.withHighestBitrate();
          final streamUrl = bestAudio.url.toString();
          yt.close();
          return song.copyWith(url: streamUrl);
        }
        yt.close();
      } catch (e) {
        print('YouTube stream resolution failed: $e');
      }
      return song;
    }
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

    // Self-healing: if JioSaavn loading fails or URL is empty, search YouTube and stream!
    try {
      final query = '${song.title} ${song.artist}';
      final yt = YoutubeExplode();
      final searchList = await yt.search.search(query).timeout(const Duration(seconds: 5));
      if (searchList.isNotEmpty) {
        final video = searchList.first;
        final manifest = await yt.videos.streamsClient.getManifest(video.id).timeout(const Duration(seconds: 5));
        final audioOnly = manifest.audioOnly;
        if (audioOnly.isNotEmpty) {
          final bestAudio = audioOnly.withHighestBitrate();
          final streamUrl = bestAudio.url.toString();
          yt.close();
          return song.copyWith(url: streamUrl);
        }
      }
      yt.close();
    } catch (e) {
      print('Self-healing YouTube fallback failed: $e');
    }

    return details ?? song;
  }
  Future<String?> getLyrics(String id, {String? title, String? artist, int? durationSec}) =>
      _api.getLyrics(id, title: title, artist: artist, durationSec: durationSec);
  void updateAudioQuality(String q) {
    _storage.setAudioQuality(q);
    _api.setQuality(q);
  }
}

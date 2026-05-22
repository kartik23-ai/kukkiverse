import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';
import '../models/song_model.dart';
import 'api_service.dart';

enum DownloadStatus { none, downloading, downloaded, failed }

class DownloadState {
  final DownloadStatus status;
  final double progress;

  const DownloadState({
    required this.status,
    required this.progress,
  });

  const DownloadState.none() : this(status: DownloadStatus.none, progress: 0.0);
  const DownloadState.downloading(double progress) : this(status: DownloadStatus.downloading, progress: progress);
  const DownloadState.downloaded() : this(status: DownloadStatus.downloaded, progress: 1.0);
  const DownloadState.failed() : this(status: DownloadStatus.failed, progress: 0.0);
}

class DownloadNotifier extends StateNotifier<Map<String, DownloadState>> {
  final StorageService _storage;

  DownloadNotifier(this._storage) : super({}) {
    _init();
  }

  Map<String, DownloadState> get currentStates => state;

  void _init() {
    final downloaded = _storage.getDownloadedSongs();
    final initialMap = <String, DownloadState>{};
    for (final s in downloaded) {
      initialMap[s.id] = const DownloadState.downloaded();
    }
    state = initialMap;
  }

  void updateProgress(String id, double progress) {
    state = {
      ...state,
      id: DownloadState.downloading(progress),
    };
  }

  void setDownloaded(String id) {
    state = {
      ...state,
      id: const DownloadState.downloaded(),
    };
  }

  void setFailed(String id) {
    state = {
      ...state,
      id: const DownloadState.failed(),
    };
  }

  void setRemoved(String id) {
    final copy = Map<String, DownloadState>.from(state);
    copy.remove(id);
    state = copy;
  }
}

class DownloadService {
  final StorageService _storage;
  final DownloadNotifier _notifier;
  final ApiService _api = ApiService();

  DownloadService(this._storage, this._notifier);

  String _getExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      if (path.endsWith('.mp3')) return '.mp3';
      if (path.endsWith('.m4a')) return '.m4a';
      if (path.endsWith('.mp4')) return '.mp4';
      if (path.contains('.mp4?')) return '.mp4';
      if (path.contains('.m4a?')) return '.m4a';
      if (path.contains('.mp3?')) return '.mp3';
      
      // Default to .mp4 for JioSaavn AAC streams since they're AAC in MP4
      if (url.contains('aac') || url.contains('jiosaavn') || url.contains('saavn')) {
        return '.mp4';
      }
    } catch (_) {}
    return '.mp3';
  }

  Future<String> getDownloadedPath(String id) async {
    final docDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${docDir.path}/downloads');
    for (final ext in ['.mp4', '.m4a', '.mp3']) {
      final file = File('${downloadsDir.path}/$id$ext');
      if (await file.exists()) {
        return file.path;
      }
    }
    return '${downloadsDir.path}/$id.mp4';
  }

  Future<void> downloadSong(SongModel song) async {
    debugPrint('ROTTY DOWNLOAD: downloadSong requested for "${song.title}" (id: ${song.id})');
    final currentState = _notifier.currentStates[song.id];
    if (currentState?.status == DownloadStatus.downloading || currentState?.status == DownloadStatus.downloaded) {
      debugPrint('ROTTY DOWNLOAD: Song is already downloading or downloaded (status: ${currentState?.status})');
      return;
    }

    var songUrl = '';
    try {
      debugPrint('ROTTY DOWNLOAD: Resolving fresh song details from api for id: ${song.id}...');
      final details = await _api.getSongDetails(song.id);
      if (details != null && details.hasPlayableUrl) {
        songUrl = details.url;
        debugPrint('ROTTY DOWNLOAD: Resolved fresh song details URL = "$songUrl"');
      } else {
        debugPrint('ROTTY DOWNLOAD: Resolved details details is null or has no playable URL');
      }
    } catch (e) {
      debugPrint('ROTTY DOWNLOAD: Error resolving fresh song details: $e');
    }

    if (songUrl.isEmpty) {
      songUrl = song.url;
      debugPrint('ROTTY DOWNLOAD: Fresh resolution failed. Falling back to song.url = "$songUrl"');
    }

    if (songUrl.isEmpty) {
      debugPrint('ROTTY DOWNLOAD: Song URL is still empty. Failing download.');
      _notifier.setFailed(song.id);
      return;
    }

    debugPrint('ROTTY DOWNLOAD: Setting progress to 0.0 for ${song.id}');
    _notifier.updateProgress(song.id, 0.0);

    final client = http.Client();
    IOSink? sink;
    File? file;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${docDir.path}/downloads');
      debugPrint('ROTTY DOWNLOAD: Local downloads directory path = "${downloadsDir.path}"');
      if (!await downloadsDir.exists()) {
        debugPrint('ROTTY DOWNLOAD: Creating downloads directory...');
        await downloadsDir.create(recursive: true);
      }

      final ext = _getExtension(songUrl);
      file = File('${downloadsDir.path}/${song.id}$ext');
      debugPrint('ROTTY DOWNLOAD: Target file path = "${file.path}" (extension: $ext)');
      if (await file.exists()) {
        debugPrint('ROTTY DOWNLOAD: Target file already exists. Deleting it...');
        await file.delete();
      }

      final request = http.Request('GET', Uri.parse(songUrl));
      request.headers.addAll({
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Referer': 'https://www.jiosaavn.com/',
      });

      debugPrint('ROTTY DOWNLOAD: Sending HTTP GET request to: $songUrl');
      final response = await client.send(request);
      debugPrint('ROTTY DOWNLOAD: HTTP Response status code = ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      debugPrint('ROTTY DOWNLOAD: HTTP Content length = $contentLength');
      var downloadedBytes = 0;
      
      sink = file.openWrite();

      debugPrint('ROTTY DOWNLOAD: Starting stream read...');
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0) {
          final progress = (downloadedBytes / contentLength).clamp(0.0, 1.0);
          _notifier.updateProgress(song.id, progress);
        }
      }
      
      debugPrint('ROTTY DOWNLOAD: Stream finished for ${song.id}. Received $downloadedBytes bytes.');
      await sink.flush();
      await sink.close();
      sink = null;

      debugPrint('ROTTY DOWNLOAD: Saving downloaded song metadata to storage...');
      await _storage.saveDownloadedSong(song);
      debugPrint('ROTTY DOWNLOAD: Metadata saved successfully. Marking status as downloaded.');
      _notifier.setDownloaded(song.id);
    } catch (e) {
      debugPrint('ROTTY DOWNLOAD: Error downloading song ${song.id}: $e');
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (file != null && await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      _notifier.setFailed(song.id);
    } finally {
      client.close();
    }
  }

  Future<void> deleteSong(String songId) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      for (final ext in ['.mp4', '.m4a', '.mp3']) {
        final file = File('${docDir.path}/downloads/$songId$ext');
        if (await file.exists()) {
          debugPrint('ROTTY DOWNLOAD: Deleting local file: ${file.path}');
          await file.delete();
        }
      }
      await _storage.deleteDownloadedSong(songId);
      _notifier.setRemoved(songId);
    } catch (e) {
      debugPrint('ROTTY DOWNLOAD: Delete error for song $songId: $e');
    }
  }
}

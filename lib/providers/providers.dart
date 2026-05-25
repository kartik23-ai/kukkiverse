import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_handler.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/ai_dj_service.dart';
import '../repositories/music_repository.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/media_item.dart';

import '../services/download_service.dart';

export 'feature_providers.dart';
export '../services/download_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final aiDjServiceProvider = Provider<AiDjService>((ref) => AiDjService(ref.read(apiServiceProvider)));

final downloadNotifierProvider = StateNotifierProvider<DownloadNotifier, Map<String, DownloadState>>((ref) {
  return DownloadNotifier(ref.read(storageServiceProvider));
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(
    ref.read(storageServiceProvider),
    ref.read(downloadNotifierProvider.notifier),
  );
});

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return MusicRepository(ref.read(apiServiceProvider), ref.read(storageServiceProvider));
});

final audioHandlerProvider = Provider<RottyAudioHandler>((ref) {
  throw UnimplementedError('Override at startup');
});

final mainTabIndexProvider = StateProvider<int>((ref) => 0);
final aiDjEnabledProvider = StateProvider<bool>((ref) {
  final storage = ref.read(storageServiceProvider);
  final isEnabled = storage.aiDjEnabled;
  ref.listenSelf((previous, next) {
    storage.setAiDjEnabled(next);
  });
  return isEnabled;
});

final homeDataProvider = FutureProvider<Map<String, List<SongModel>>>((ref) async {
  return ref.read(musicRepositoryProvider).getHomeSections();
});

/// Debounced query used for API calls.
final debouncedSearchQueryProvider = StateProvider<String>((ref) => '');

final searchInputProvider = StateNotifierProvider<SearchInputNotifier, String>((ref) {
  return SearchInputNotifier(ref);
});

class SearchInputNotifier extends StateNotifier<String> {
  SearchInputNotifier(this._ref) : super('');
  final Ref _ref;
  Timer? _timer;

  void update(String value) {
    state = value;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 450), () {
      _ref.read(debouncedSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void submit(String value) {
    _timer?.cancel();
    state = value;
    _ref.read(debouncedSearchQueryProvider.notifier).state = value.trim();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final searchSongsProvider = FutureProvider.family<List<SongModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.read(musicRepositoryProvider).searchSongs(query);
});

final searchAlbumsProvider = FutureProvider.family<List<AlbumItem>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.read(musicRepositoryProvider).searchAlbums(query);
});

final searchArtistsProvider = FutureProvider.family<List<ArtistItem>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.read(musicRepositoryProvider).searchArtists(query);
});

final albumSongsProvider = FutureProvider.family<List<SongModel>, String>((ref, albumId) async {
  if (albumId.startsWith('genre_')) {
    final genreName = albumId.replaceFirst('genre_', '').trim();
    final query = switch (genreName.toLowerCase()) {
      'love' || 'romantic' => 'Hindi Romantic',
      'devotional' => 'Hindi Bhajans',
      'party' => 'Hindi Party',
      'workout' => 'Workout Hindi',
      'chill' => 'Hindi Lofi Chill',
      'sad' => 'Sad Hindi',
      'punjabi' => 'Punjabi Hits',
      'english' => 'English Pop Hits',
      _ => '$genreName Hits',
    };
    return ref.read(musicRepositoryProvider).searchSongs(query, limit: 30);
  }
  return ref.read(musicRepositoryProvider).getAlbumSongs(albumId);
});

final artistDetailProvider = FutureProvider.family<({ArtistItem? artist, List<SongModel> songs, List<AlbumItem> albums}), String>((ref, id) async {
  return ref.read(musicRepositoryProvider).getArtist(id);
});

final lyricsProvider = FutureProvider.family<String?, String>((ref, id) async {
  // 1. Check if the now playing song matches this ID
  var song = ref.read(nowPlayingProvider);
  if (song?.id != id) {
    // 2. Not the now playing song. Try to resolve correct details from API to search LRCLIB accurately.
    try {
      song = await ref.read(apiServiceProvider).getSongDetails(id);
    } catch (_) {
      song = null;
    }
  }

  // 3. Query lyrics using the correct title, artist, and duration
  return ref.read(musicRepositoryProvider).getLyrics(
    id,
    title: song?.title,
    artist: song?.artist,
    durationSec: song?.duration.inSeconds,
  );
});

/// Lightweight playback state — only updates when song id or play state changes.
final nowPlayingProvider = StateNotifierProvider<NowPlayingNotifier, SongModel?>((ref) {
  return NowPlayingNotifier(ref.read(audioHandlerProvider));
});

class NowPlayingNotifier extends StateNotifier<SongModel?> {
  NowPlayingNotifier(this._handler) : super(_handler.currentSong) {
    _subs.add(_handler.mediaItem.listen((_) {
      final song = _handler.currentSong;
      if (song?.id != state?.id) state = song;
    }));
  }

  final RottyAudioHandler _handler;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

final isPlayingProvider = StateNotifierProvider<IsPlayingNotifier, bool>((ref) {
  return IsPlayingNotifier(ref.read(audioHandlerProvider));
});

class IsPlayingNotifier extends StateNotifier<bool> {
  IsPlayingNotifier(this._handler) : super(false) {
    _subs.add(_handler.playbackState.listen((s) {
      if (s.playing != state) state = s.playing;
    }));
  }

  final RottyAudioHandler _handler;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

final aiInsightProvider = Provider((ref) {
  final song = ref.watch(nowPlayingProvider);
  final recent = ref.watch(recentSongsProvider);
  final favorites = ref.watch(favoritesProvider);
  return ref.read(aiDjServiceProvider).analyze(
        nowPlaying: song,
        recent: recent,
        favorites: favorites,
        hour: DateTime.now().hour,
      );
});

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<SongModel>>((ref) {
  return FavoritesNotifier(ref.read(storageServiceProvider));
});

class FavoritesNotifier extends StateNotifier<List<SongModel>> {
  final StorageService _storage;
  FavoritesNotifier(this._storage) : super(_storage.getFavorites());
  bool isFavorite(String id) => state.any((s) => s.id == id);
  Future<void> toggle(SongModel song) async {
    await _storage.toggleFavorite(song);
    state = _storage.getFavorites();
  }
}

final recentSongsProvider = StateNotifierProvider<RecentSongsNotifier, List<SongModel>>((ref) {
  return RecentSongsNotifier(ref.read(storageServiceProvider));
});

class RecentSongsNotifier extends StateNotifier<List<SongModel>> {
  final StorageService _storage;
  RecentSongsNotifier(this._storage) : super(_storage.getRecentSongs());
  Future<void> add(SongModel song) async {
    await _storage.addRecentSong(song);
    state = _storage.getRecentSongs();
  }
  Future<void> remove(String songId) async {
    await _storage.removeRecentSong(songId);
    state = _storage.getRecentSongs();
  }
}

final downloadedSongsProvider = Provider<List<SongModel>>((ref) {
  ref.watch(downloadNotifierProvider);
  return ref.read(storageServiceProvider).getDownloadedSongs();
});

final playlistsProvider = StateNotifierProvider<PlaylistNotifier, List<PlaylistModel>>((ref) {
  return PlaylistNotifier(ref.read(storageServiceProvider));
});

class PlaylistNotifier extends StateNotifier<List<PlaylistModel>> {
  final StorageService _storage;
  PlaylistNotifier(this._storage) : super(_storage.getPlaylists());

  void refresh() {
    state = _storage.getPlaylists();
  }

  Future<String> create(String name, {bool isPrivate = false}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.savePlaylist(PlaylistModel(
      id: id,
      name: name,
      isPrivate: isPrivate,
    ));
    state = _storage.getPlaylists();
    return id;
  }

  Future<void> togglePrivacy(String id) async {
    final playlists = _storage.getPlaylists();
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1) return;
    await _storage.savePlaylist(playlists[index].copyWith(isPrivate: !playlists[index].isPrivate));
    state = _storage.getPlaylists();
  }

  Future<void> addToPlaylist(String playlistId, SongModel song) async {
    final playlists = _storage.getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    if (playlists[index].songs.any((s) => s.id == song.id)) return;
    await _storage.savePlaylist(playlists[index].copyWith(songs: [...playlists[index].songs, song]));
    state = _storage.getPlaylists();
  }

  Future<void> saveSyncedPlaylist(PlaylistModel playlist) async {
    await _storage.savePlaylist(playlist);
    state = _storage.getPlaylists();
  }

  Future<void> delete(String id) async {
    await _storage.deletePlaylist(id);
    state = _storage.getPlaylists();
  }
}

final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier(ref.read(storageServiceProvider));
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  final StorageService _storage;
  SearchHistoryNotifier(this._storage) : super(_storage.getSearchHistory());
  Future<void> add(String query) async {
    await _storage.addSearchHistory(query);
    state = _storage.getSearchHistory();
  }
  Future<void> clear() async {
    await _storage.clearSearchHistory();
    state = [];
  }
  Future<void> remove(String query) async {
    await _storage.deleteSearchHistory(query);
    state = _storage.getSearchHistory();
  }
}

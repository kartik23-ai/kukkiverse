import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_handler.dart';
import '../services/api_service.dart';
import '../services/ghost_proxy_client.dart';
import '../services/storage_service.dart';
import '../services/ai_dj_service.dart';
import '../repositories/music_repository.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/media_item.dart';
import '../services/groq_ai_service.dart';
import '../services/download_service.dart';
import '../services/ai_image_service.dart';

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

final searchYouTubeSongsProvider = FutureProvider.family<List<SongModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.read(apiServiceProvider).searchYouTube(query);
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
  if (albumId == 'daily_mix') {
    final favorites = ref.watch(favoritesProvider);
    final recent = ref.watch(recentSongsProvider);
    final List<SongModel> dailyQueue = [];
    dailyQueue.addAll(favorites);
    dailyQueue.addAll(recent);
    
    // Shuffle the songs to make the mix dynamic every time!
    final shuffled = List<SongModel>.from(dailyQueue)..shuffle();
    
    if (shuffled.isEmpty) {
      final trending = await ref.read(musicRepositoryProvider).searchSongs('trending hindi lofi', limit: 30);
      return (List<SongModel>.from(trending)..shuffle()).take(15).toList();
    }
    return shuffled.take(20).toList();
  }
  if (albumId == 'weekly_top') {
    final query = switch (DateTime.now().weekday % 2) {
      0 => 'weekly top hindi hits',
      _ => 'latest trending bollywood songs',
    };
    final songs = await ref.read(musicRepositoryProvider).searchSongs(query, limit: 30);
    return (List<SongModel>.from(songs)..shuffle()).take(15).toList();
  }
  if (albumId.startsWith('genre_')) {
    final genreName = albumId.replaceFirst('genre_', '').trim();
    return ref.read(musicRepositoryProvider).getGenreSongs(genreName);
  }
  return ref.read(musicRepositoryProvider).getAlbumSongs(albumId);
});

bool _isOriginalSong(SongModel song) {
  final title = song.title.toLowerCase();
  final album = song.album.toLowerCase();
  if (title.contains('remix') || title.contains('re-mix') || title.contains('mashup') || title.contains('mash-up') ||
      title.contains('lofi') || title.contains('lo-fi') || title.contains('slowed') ||
      title.contains('reverb') || title.contains('sped up') || title.contains('cover') ||
      title.contains('tribute') || title.contains('instrumental') || title.contains('karaoke') ||
      title.contains('sad version') || title.contains('female version') || title.contains('male version') ||
      title.contains('ringtone') || title.contains('bgm') || title.contains('acoustic') ||
      title.contains('gunshot') || title.contains('dj ') || title.contains(' dj') ||
      title.contains('trap mix') || title.contains('non stop') || title.contains('non-stop') ||
      title.contains('unplugged') || title.contains('lullaby') || title.contains('slow ') ||
      title.contains('mix') || title.contains('release') || title.contains('releases') ||
      title.contains('sped-up') || title.contains('reverbed') || title.contains('chillout') ||
      title.contains('extended mix') || title.contains('radio edit') || title.contains('club mix') ||
      title.contains('remixed') || title.contains('synthwave') || title.contains('piano version') ||
      title.contains('violin version') || title.contains('re-created') || title.contains('recreated') ||
      album.contains('remix') || album.contains('lofi') || album.contains('mix') || album.contains('covers')) {
    return false;
  }
  return true;
}

String _normalizeSongTitleForDeduplication(String title) {
  var clean = title.toLowerCase();
  clean = clean.replaceAll(RegExp(r'\(.*?\)'), '');
  clean = clean.replaceAll(RegExp(r'\[.*?\]'), '');
  clean = clean.replaceAll('from', '');
  clean = clean.replaceAll('theme', '');
  clean = clean.replaceAll('soundtrack', '');
  clean = clean.replaceAll(RegExp(r"[^\w\s']"), ' ');
  clean = RegExp(r'\s+').allMatches(clean).fold(clean, (s, _) => s.replaceAll('  ', ' '));
  return clean.trim();
}

List<String> _extractSearchTitles(String html) {
  final titles = <String>[];
  final matches = RegExp(r'<h3[^>]*>(.*?)</h3>').allMatches(html);
  for (final m in matches) {
    var text = m.group(1) ?? '';
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.trim();
    if (text.isNotEmpty && text.length < 100) {
      titles.add(text);
    }
  }
  return titles;
}

List<String> _extractDdgTitles(String html) {
  final titles = <String>[];
  final matches = RegExp(r'class="result__a"[^>]*>(.*?)</a>', caseSensitive: false).allMatches(html);
  for (final m in matches) {
    var text = m.group(1) ?? '';
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.trim();
    if (text.isNotEmpty && text.length < 120) {
      titles.add(text);
    }
  }
  return titles;
}

String _cleanGoogleTitle(String title) {
  var clean = title.toLowerCase();
  clean = clean.replaceAll('youtube', '');
  clean = clean.replaceAll('jiosaavn', '');
  clean = clean.replaceAll('spotify', '');
  clean = clean.replaceAll('gaana', '');
  clean = clean.replaceAll('wynk', '');
  clean = clean.replaceAll('hungama', '');
  clean = clean.replaceAll('official video', '');
  clean = clean.replaceAll('official audio', '');
  clean = clean.replaceAll('lyrical video', '');
  clean = clean.replaceAll('full song', '');
  clean = clean.replaceAll('music video', '');
  clean = clean.replaceAll('video song', '');
  clean = clean.replaceAll('lyrics', '');

  final parts = clean.split(RegExp(r'[\-|:|\|]'));
  if (parts.isNotEmpty) {
    clean = parts[0];
  }

  clean = clean.replaceAll(RegExp(r'\(.*?\)'), '');
  clean = clean.replaceAll(RegExp(r'\[.*?\]'), '');
  clean = clean.replaceAll(RegExp(r"[^\w\s']"), ' ');
  clean = RegExp(r'\s+').allMatches(clean).fold(clean, (s, _) => s.replaceAll('  ', ' '));
  return clean.trim();
}

Future<List<SongModel>> _fetchFromGoogle(Ref ref, String searchQuery, String fallbackQuery) async {
  if (GhostProxyClient.isEnabled) {
    try {
      final proxyClient = GhostProxyClient();
      final results = await proxyClient.getScrapedSongs(searchQuery, fallbackQuery, limit: 20);
      if (results != null && results.isNotEmpty) {
        final qual = StorageService().preferredQuality;
        return results.map((e) => SongModel.fromJson(e, preferredQuality: qual)).toList();
      }
    } catch (e) {
      debugPrint('ROTTY GOOGLE QUERY: getScrapedSongs through proxy failed: $e');
    }
  }

  final repo = ref.read(musicRepositoryProvider);
  final songs = <SongModel>[];
  final titleRegistry = <String, bool>{};
  final albumCounts = <String, int>{};

  List<String> searchTitles = [];

  // Try DuckDuckGo first
  try {
    debugPrint('ROTTY GOOGLE QUERY: Searching DuckDuckGo for "$searchQuery"...');
    final ddgUrl = 'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(searchQuery)}';
    final response = await http.get(
      Uri.parse(ddgUrl),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      searchTitles = _extractDdgTitles(response.body);
      debugPrint('ROTTY GOOGLE QUERY: Found ${searchTitles.length} titles from DuckDuckGo.');
    }
  } catch (e) {
    debugPrint('ROTTY GOOGLE QUERY: DuckDuckGo fetch failed/timed out: $e');
  }

  // Try Google if DDG failed or returned empty
  if (searchTitles.isEmpty) {
    try {
      debugPrint('ROTTY GOOGLE QUERY: Searching Google for "$searchQuery"...');
      final response = await http.get(
        Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(searchQuery)}'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        searchTitles = _extractSearchTitles(response.body);
        debugPrint('ROTTY GOOGLE QUERY: Found ${searchTitles.length} titles from Google.');
      }
    } catch (e) {
      debugPrint('ROTTY GOOGLE QUERY: Google fetch failed/timed out: $e');
    }
  }

  // Process search titles
  if (searchTitles.isNotEmpty) {
    for (final title in searchTitles) {
      final cleaned = _cleanGoogleTitle(title);
      if (cleaned.length < 3) continue;
      try {
        final results = await repo.searchSongs(cleaned, limit: 3);
        for (final s in results) {
          if (!_isOriginalSong(s)) continue;
          final normTitle = _normalizeSongTitleForDeduplication(s.title);
          if (titleRegistry.containsKey(normTitle)) continue;

          final album = s.album.toLowerCase().trim();
          if (album.isNotEmpty) {
            final count = albumCounts[album] ?? 0;
            if (count >= 2) continue;
            albumCounts[album] = count + 1;
          }

          titleRegistry[normTitle] = true;
          songs.add(s);
          break;
        }
      } catch (_) {}
      if (songs.length >= 20) break;
    }
  }

  // Fallback if we have fewer than 15 songs
  if (songs.length < 15) {
    debugPrint('ROTTY GOOGLE QUERY: Fetched only ${songs.length} songs from search results. Triggering fallback search for "$fallbackQuery"...');
    try {
      final list = await repo.searchSongs(fallbackQuery, limit: 40);
      for (final s in list) {
        if (!_isOriginalSong(s)) continue;
        final normTitle = _normalizeSongTitleForDeduplication(s.title);
        if (titleRegistry.containsKey(normTitle)) continue;

        final album = s.album.toLowerCase().trim();
        if (album.isNotEmpty) {
          final count = albumCounts[album] ?? 0;
          if (count >= 2) continue;
          albumCounts[album] = count + 1;
        }

        titleRegistry[normTitle] = true;
        songs.add(s);
        if (songs.length >= 20) break;
      }
    } catch (_) {}
  }
  return songs.take(20).toList();
}

final bollywoodNewReleasesProvider = FutureProvider<List<SongModel>>((ref) async {
  return _fetchFromGoogle(ref, 'latest hindi songs official music video site:youtube.com', 'latest hindi songs');
});

final hollywoodNewReleasesProvider = FutureProvider<List<SongModel>>((ref) async {
  return _fetchFromGoogle(ref, 'latest english songs official music video site:youtube.com', 'latest english songs');
});

final indianTopHitsProvider = FutureProvider<List<SongModel>>((ref) async {
  return _fetchFromGoogle(ref, 'top bollywood songs 2026 site:youtube.com', 'top bollywood songs');
});



final artistDetailProvider = FutureProvider.family<({ArtistItem? artist, List<SongModel> songs, List<AlbumItem> albums, String? bio, String? listeners}), String>((ref, id) async {
  final result = await ref.read(musicRepositoryProvider).getArtist(id);
  if (result.artist != null && result.songs.isNotEmpty) {
    return (artist: result.artist, songs: result.songs, albums: result.albums, bio: result.artist?.bio, listeners: result.artist?.listeners);
  }
  
  // Fallback: AI synthesize the profile for custom/AI creator name
  try {
    final profile = await GroqAiService().generateArtistProfile(id);
    if (profile != null) {
      final bio = profile['bio']?.toString() ?? 'A custom ROTTY AI artist.';
      final listeners = profile['listeners']?.toString() ?? '15,000';
      final List<String> mockSongs = (profile['songs'] as List? ?? []).cast<String>();
      final List<String> mockAlbums = (profile['albums'] as List? ?? []).cast<String>();
      
      final api = ref.read(apiServiceProvider);
      final List<SongModel> realSongs = [];
      final searchFutures = mockSongs.take(5).map((q) async {
        try {
          final list = await api.searchSongs(q, limit: 1);
          if (list.isNotEmpty) return list.first;
        } catch (_) {}
        return null;
      });
      
      final songsResults = await Future.wait(searchFutures);
      for (final s in songsResults) {
        if (s != null && !realSongs.any((e) => e.id == s.id)) {
          realSongs.add(s);
        }
      }
      
      final List<AlbumItem> realAlbums = [];
      for (int idx = 0; idx < mockAlbums.length; idx++) {
        realAlbums.add(AlbumItem(
          id: 'mock_album_${id}_$idx',
          name: mockAlbums[idx],
          image: realSongs.isNotEmpty ? realSongs.first.image : 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=500&auto=format&fit=crop',
          year: '${DateTime.now().year}',
          language: 'Hindi/English',
        ));
      }

      final artist = ArtistItem(
        id: id,
        name: id,
        image: realSongs.isNotEmpty ? realSongs.first.image : 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=500&auto=format&fit=crop',
      );

      return (artist: artist, songs: realSongs, albums: realAlbums, bio: bio, listeners: listeners);
    }
  } catch (_) {}

  return (artist: result.artist, songs: result.songs, albums: result.albums, bio: null, listeners: null);
});

final lyricsProvider = FutureProvider.family<String?, String>((ref, id) async {
  // Check local cache first
  final cached = StorageService().getCachedLyrics(id);
  if (cached != null && cached.isNotEmpty) {
    return cached;
  }

  // 1. Check if it's an AI creation in our local list first
  final creations = ref.read(studioCreationsProvider);
  try {
    final creation = creations.firstWhere((s) => s.id == id);
    if (creation.lyrics != null && creation.lyrics!.isNotEmpty) {
      await StorageService().saveCachedLyrics(id, creation.lyrics!);
      return creation.lyrics;
    }
  } catch (_) {}

  // 2. Check if the now playing song matches this ID and has lyrics
  var song = ref.read(nowPlayingProvider);
  if (song?.id == id && song?.lyrics != null && song!.lyrics!.isNotEmpty) {
    await StorageService().saveCachedLyrics(id, song.lyrics!);
    return song.lyrics;
  }

  if (song?.id != id) {
    // 3. Not the now playing song. Try to resolve correct details from API to search LRCLIB accurately.
    try {
      song = await ref.read(apiServiceProvider).getSongDetails(id);
    } catch (_) {
      song = null;
    }
  }

  // 4. Query lyrics using the correct title, artist, and duration
  final lyrics = await ref.read(musicRepositoryProvider).getLyrics(
    id,
    title: song?.title,
    artist: song?.artist,
    durationSec: song?.duration.inSeconds,
  );

  if (lyrics != null && lyrics.isNotEmpty) {
    await StorageService().saveCachedLyrics(id, lyrics);
  }

  return lyrics;
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

final favoriteArtistsProvider = StateNotifierProvider<FavoriteArtistsNotifier, List<String>>((ref) {
  return FavoriteArtistsNotifier(ref.read(storageServiceProvider));
});

class FavoriteArtistsNotifier extends StateNotifier<List<String>> {
  final StorageService _storage;
  FavoriteArtistsNotifier(this._storage) : super(_storage.favoriteArtists);

  Future<void> updateArtists(List<String> artists) async {
    await _storage.setFavoriteArtists(artists);
    state = _storage.favoriteArtists;
  }
}

final hasSelectedFavoritesProvider = StateNotifierProvider<HasSelectedFavoritesNotifier, bool>((ref) {
  return HasSelectedFavoritesNotifier(ref.read(storageServiceProvider));
});

class HasSelectedFavoritesNotifier extends StateNotifier<bool> {
  final StorageService _storage;
  HasSelectedFavoritesNotifier(this._storage) : super(_storage.hasSelectedFavorites);

  Future<void> setDone(bool val) async {
    await _storage.setHasSelectedFavorites(val);
    state = val;
  }
}

final suggestedSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  final artists = ref.watch(favoriteArtistsProvider);
  if (artists.isEmpty) return [];

  final api = ref.read(apiServiceProvider);
  final List<SongModel> suggested = [];
  
  // Fetch from the top 3 chosen artists to keep it fast
  final targetArtists = artists.take(3).toList();
  final futures = targetArtists.map((artist) => api.searchSongs('$artist hits', limit: 8));
  final results = await Future.wait(futures);

  int maxLen = 0;
  for (final list in results) {
    if (list.length > maxLen) maxLen = list.length;
  }

  for (int i = 0; i < maxLen; i++) {
    for (final list in results) {
      if (i < list.length) {
        final song = list[i];
        if (!suggested.any((s) => s.id == song.id)) {
          suggested.add(song);
        }
      }
    }
  }
  return suggested;
});

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

// ─── AI Studio Creations & Mix Fade State Providers ───
final mixFadeEnabledProvider = StateNotifierProvider<MixFadeNotifier, bool>((ref) {
  return MixFadeNotifier(ref.read(storageServiceProvider));
});

class MixFadeNotifier extends StateNotifier<bool> {
  final StorageService _storage;
  MixFadeNotifier(this._storage) : super(_storage.mixFadeEnabled);

  Future<void> toggle(bool value) async {
    await _storage.setMixFadeEnabled(value);
    state = value;
  }
}

final studioCreationsProvider = StateNotifierProvider<StudioCreationsNotifier, List<SongModel>>((ref) {
  return StudioCreationsNotifier(ref.read(storageServiceProvider));
});

class StudioCreationsNotifier extends StateNotifier<List<SongModel>> {
  final StorageService _storage;
  StudioCreationsNotifier(this._storage) : super(_storage.getStudioCreations());

  void refresh() {
    state = _storage.getStudioCreations();
  }

  Future<void> addCreation(SongModel song) async {
    await _storage.saveStudioCreation(song);
    state = _storage.getStudioCreations();
  }

  Future<void> removeCreation(String id) async {
    await _storage.deleteStudioCreation(id);
    state = _storage.getStudioCreations();
  }
}

final mixBlendStyleProvider = StateNotifierProvider<MixBlendStyleNotifier, String>((ref) {
  return MixBlendStyleNotifier(ref.read(storageServiceProvider));
});

class MixBlendStyleNotifier extends StateNotifier<String> {
  final StorageService _storage;
  MixBlendStyleNotifier(this._storage) : super(_storage.mixBlendStyle);

  Future<void> setStyle(String value) async {
    await _storage.setMixBlendStyle(value);
    state = value;
  }
}

final mixBlendLengthProvider = StateNotifierProvider<MixBlendLengthNotifier, int>((ref) {
  return MixBlendLengthNotifier(ref.read(storageServiceProvider));
});

class MixBlendLengthNotifier extends StateNotifier<int> {
  final StorageService _storage;
  MixBlendLengthNotifier(this._storage) : super(_storage.mixBlendLength);

  Future<void> setLength(int value) async {
    await _storage.setMixBlendLength(value);
    state = value;
  }
}

final homeArtistsProvider = FutureProvider<List<({String name, String img})>>((ref) async {
  final repo = ref.read(musicRepositoryProvider);
  final artistNames = [
    'Arijit Singh',
    'Pritam',
    'A.R. Rahman',
    'Shreya Ghoshal',
    'Jubin Nautiyal',
    'Anuv Jain',
    'AP Dhillon',
    'Darshan Raval',
    'Diljit Dosanjh',
    'Karan Aujla',
    'Badshah'
  ];
  
  final List<({String name, String img})> resolved = [];
  
  final futures = artistNames.map((name) async {
    try {
      final results = await repo.searchArtists(name);
      if (results.isNotEmpty && results.first.image.isNotEmpty && !results.first.image.contains('default')) {
        return (name: name, img: results.first.image);
      }
    } catch (_) {}
    return (name: name, img: '');
  });
  
  final results = await Future.wait(futures);
  for (final r in results) {
    if (r.img.isNotEmpty) {
      resolved.add(r);
    } else {
      final fallbackUrl = AiImageService.getCoverUrl(
        prompt: 'professional studio portrait of Indian music artist ${r.name}, photorealistic face close-up profile photo, premium 4k concert lighting',
        seed: r.name,
      );
      resolved.add((name: r.name, img: fallbackUrl));
    }
  }
  return resolved;
});


import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/modes/app_mode.dart';
import '../core/sound/sound_space.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/play_history_entry.dart';
import '../core/premium/premium_models.dart';
import 'firebase_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;
  late Box _recentBox;
  late Box _favoritesBox;
  late Box _playlistBox;
  late Box _searchBox;
  late Box _historyBox;
  late Box _partyBox;
  late Box _downloadedBox;
  late Box _mashupsBox;
  late Box _lyricsBox;

  Future<void> init() async {
    try {
      await Hive.initFlutter();
    } catch (e) {
      debugPrint('Hive initFlutter error: $e');
    }
    _prefs = await SharedPreferences.getInstance();

    Future<Box> openBoxSafely(String name) async {
      try {
        return await Hive.openBox(name);
      } catch (e) {
        debugPrint('Failed to open hive box $name: $e. Re-creating box...');
        try {
          await Hive.deleteBoxFromDisk(name);
          return await Hive.openBox(name);
        } catch (ex) {
          debugPrint('Fatal error opening box $name: $ex');
          rethrow;
        }
      }
    }

    _recentBox = await openBoxSafely(AppConstants.recentBox);
    _favoritesBox = await openBoxSafely(AppConstants.favoritesBox);
    _playlistBox = await openBoxSafely(AppConstants.playlistBox);
    _searchBox = await openBoxSafely(AppConstants.searchHistoryBox);
    _historyBox = await openBoxSafely(AppConstants.playHistoryBox);
    _partyBox = await openBoxSafely(AppConstants.partyRoomBox);
    _downloadedBox = await openBoxSafely(AppConstants.downloadedSongsBox);
    _mashupsBox = await openBoxSafely('mashup_songs');
    _lyricsBox = await openBoxSafely('cached_lyrics');
  }

  Box get recentBox => _recentBox;

  // ─── Onboarding ───
  bool get isOnboardingDone => _prefs.getBool(AppConstants.onboardingDone) ?? false;
  Future<void> setOnboardingDone() => _prefs.setBool(AppConstants.onboardingDone, true);

  bool get authSessionDone => _prefs.getBool(AppConstants.authSessionDone) ?? false;
  Future<void> setAuthSessionDone() => _prefs.setBool(AppConstants.authSessionDone, true);
  Future<void> clearAuthSession() => _prefs.setBool(AppConstants.authSessionDone, false);

  DateTime? get premiumExpiresAt {
    final raw = _prefs.getString(AppConstants.premiumExpiresAt);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool get isPremiumActive {
    final exp = premiumExpiresAt;
    return exp != null && exp.isAfter(DateTime.now());
  }

  Future<void> activatePremiumMonth({required String txnId}) async {
    final now = DateTime.now();
    final current = premiumExpiresAt;
    final base = (current != null && current.isAfter(now)) ? current : now;
    await _prefs.setString(AppConstants.premiumExpiresAt, base.add(const Duration(days: 30)).toIso8601String());
    await _prefs.setString(AppConstants.premiumTxnId, txnId);
  }

  Future<void> clearPremium() async {
    await _prefs.remove(AppConstants.premiumExpiresAt);
    await _prefs.remove(AppConstants.premiumTxnId);
  }

  // ─── Audio Quality ───
  String get audioQuality => _prefs.getString(AppConstants.audioQuality) ?? '320kbps';
  Future<void> setAudioQuality(String q) => _prefs.setString(AppConstants.audioQuality, q);

  // ─── Recent Songs ───
  List<SongModel> getRecentSongs() {
    final list = _recentBox.values.toList();
    return list.map<SongModel>((e) => SongModel.fromHive(Map<String, dynamic>.from(e))).toList().reversed.toList();
  }

  Future<void> addRecentSong(SongModel song) async {
    // Remove if exists
    final existing = _recentBox.keys.where((k) => _recentBox.get(k)?['id'] == song.id);
    for (final k in existing) {
      await _recentBox.delete(k);
    }
    await _recentBox.add(song.toJson());
    // Keep only last 50
    if (_recentBox.length > 50) {
      await _recentBox.deleteAt(0);
    }
  }

  Future<void> removeRecentSong(String songId) async {
    final targetKeys = _recentBox.keys.where((k) => _recentBox.get(k)?['id'] == songId).toList();
    for (final k in targetKeys) {
      await _recentBox.delete(k);
    }
  }

  // ─── Favorites ───
  List<SongModel> getFavorites() {
    return _favoritesBox.values
        .map<SongModel>((e) => SongModel.fromHive(Map<String, dynamic>.from(e)))
        .toList()
        .reversed
        .toList();
  }

  bool isFavorite(String songId) {
    return _favoritesBox.values.any((e) => e['id'] == songId);
  }

  Future<void> toggleFavorite(SongModel song) async {
    if (isFavorite(song.id)) {
      final key = _favoritesBox.keys.firstWhere(
        (k) => _favoritesBox.get(k)?['id'] == song.id,
        orElse: () => null,
      );
      if (key != null) await _favoritesBox.delete(key);
    } else {
      await _favoritesBox.add(song.toJson());
    }
  }

  // ─── Playlists ───
  List<PlaylistModel> getPlaylists() {
    return _playlistBox.values
        .map((e) => PlaylistModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> savePlaylist(PlaylistModel playlist, {bool syncToCloud = true}) async {
    await _playlistBox.put(playlist.id, playlist.toJson());
    if (syncToCloud) {
      try {
        if (FirebaseService.instance.isReady) {
          FirebaseService.instance.syncPlaylist(playlist.toJson(), playlist.id);
        }
      } catch (_) {}
    }
  }

  Future<void> deletePlaylist(String id) async {
    await _playlistBox.delete(id);
    try {
      if (FirebaseService.instance.isReady) {
        FirebaseService.instance.deleteCloudPlaylist(id);
      }
    } catch (_) {}
  }

  // ─── Search History ───
  List<String> getSearchHistory() {
    return _searchBox.values.cast<String>().toList().reversed.toList();
  }

  Future<void> addSearchHistory(String query) async {
    final existing = _searchBox.values.cast<String>().toList();
    if (existing.contains(query)) {
      final idx = existing.indexOf(query);
      await _searchBox.deleteAt(idx);
    }
    await _searchBox.add(query);
    if (_searchBox.length > 20) await _searchBox.deleteAt(0);
  }

  Future<void> clearSearchHistory() async {
    await _searchBox.clear();
  }

  Future<void> deleteSearchHistory(String query) async {
    final existing = _searchBox.values.cast<String>().toList();
    if (existing.contains(query)) {
      final idx = existing.indexOf(query);
      await _searchBox.deleteAt(idx);
    }
  }

  // ─── App mode & sound ───
  RottyAppMode get appMode {
    final v = _prefs.getString(AppConstants.appMode);
    return RottyAppMode.values.firstWhere((m) => m.name == v, orElse: () => RottyAppMode.normal);
  }

  Future<void> setAppMode(RottyAppMode mode) => _prefs.setString(AppConstants.appMode, mode.name);

  SoundSpace get soundSpace {
    final v = _prefs.getString(AppConstants.soundSpace);
    return SoundSpace.values.firstWhere((s) => s.name == v, orElse: () => SoundSpace.normal);
  }

  Future<void> setSoundSpace(SoundSpace space) => _prefs.setString(AppConstants.soundSpace, space.name);

  bool get zenMode => _prefs.getBool(AppConstants.zenMode) ?? false;
  Future<void> setZenMode(bool v) => _prefs.setBool(AppConstants.zenMode, v);

  bool get interactiveOnboardingDone => _prefs.getBool(AppConstants.interactiveOnboardingDone) ?? false;
  Future<void> setInteractiveOnboardingDone() => _prefs.setBool(AppConstants.interactiveOnboardingDone, true);

  // ─── Play history (memory lane + wrapped) ───
  List<PlayHistoryEntry> getPlayHistory() {
    return _historyBox.values
        .map((e) => PlayHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
        .reversed
        .toList();
  }

  Future<void> addPlayHistory(SongModel song) async {
    await _historyBox.add(PlayHistoryEntry(song: song, playedAt: DateTime.now()).toJson());
    while (_historyBox.length > 500) {
      await _historyBox.deleteAt(0);
    }
  }

  List<PlayHistoryEntry> memoryLaneFor(DateTime day) {
    return getPlayHistory().where((e) {
      final d = e.playedAt;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  // ─── Party room (local shared queue) ───
  String? get activePartyRoom => _prefs.getString('active_party_room');

  Future<void> setActivePartyRoom(String? code) async {
    if (code == null) {
      await _prefs.remove('active_party_room');
    } else {
      await _prefs.setString('active_party_room', code);
    }
  }

  List<SongModel> getPartyQueue(String roomCode) {
    final raw = _partyBox.get(roomCode);
    if (raw is! List) return [];
    return raw.map((e) => SongModel.fromHive(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> savePartyQueue(String roomCode, List<SongModel> songs) async {
    await _partyBox.put(roomCode, songs.map((s) => s.toJson()).toList());
  }

  Future<void> addToPartyQueue(String roomCode, SongModel song) async {
    final q = getPartyQueue(roomCode);
    if (!q.any((s) => s.id == song.id)) {
      q.add(song);
      await savePartyQueue(roomCode, q);
    }
  }

  // ─── Offline mood packs (song id cache list) ───
  List<String> getOfflinePackIds(String packId) {
    final raw = _prefs.getStringList('offline_$packId');
    return raw ?? [];
  }

  Future<void> setOfflinePackIds(String packId, List<String> ids) async {
    await _prefs.setStringList('offline_$packId', ids);
  }

  // ─── Premium / labs ───
  bool get auraFullApp => _prefs.getBool(AppConstants.auraFullApp) ?? true;
  Future<void> setAuraFullApp(bool v) => _prefs.setBool(AppConstants.auraFullApp, v);

  bool get hapticLyrics => _prefs.getBool(AppConstants.hapticLyrics) ?? false;
  Future<void> setHapticLyrics(bool v) => _prefs.setBool(AppConstants.hapticLyrics, v);

  bool getBoolFlag(String key) => _prefs.getBool(key) ?? false;
  Future<void> setBoolFlag(String key, bool v) => _prefs.setBool(key, v);

  StudioEqState loadStudioEq() {
    final raw = _prefs.getString(AppConstants.studioEqJson);
    if (raw == null) return const StudioEqState();
    try {
      final p = raw.split(',');
      if (p.length < 6) return const StudioEqState();
      return StudioEqState(
        bass: double.tryParse(p[0]) ?? 0.5,
        treble: double.tryParse(p[1]) ?? 0.5,
        vocal: double.tryParse(p[2]) ?? 0.5,
        width: double.tryParse(p[3]) ?? 0.5,
        orbitSpeed: double.tryParse(p[4]) ?? 0.5,
        orbit8d: p[5] == '1',
      );
    } catch (_) {
      return const StudioEqState();
    }
  }

  Future<void> saveStudioEq(StudioEqState s) => _prefs.setString(
        AppConstants.studioEqJson,
        '${s.bass},${s.treble},${s.vocal},${s.width},${s.orbitSpeed},${s.orbit8d ? 1 : 0}',
      );

  Set<String> get dislikedSongIds {
    final list = _prefs.getStringList(AppConstants.dislikedSongs);
    return list?.toSet() ?? {};
  }

  Future<void> setDislikedSongIds(Set<String> ids) =>
      _prefs.setStringList(AppConstants.dislikedSongs, ids.toList());

  String? get vaultPin => _prefs.getString(AppConstants.vaultPin);
  Future<void> setVaultPin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await _prefs.remove(AppConstants.vaultPin);
    } else {
      await _prefs.setString(AppConstants.vaultPin, pin);
    }
  }

  String? get vaultQuestion => _prefs.getString('vault_security_question');
  Future<void> setVaultQuestion(String? q) async {
    if (q == null || q.isEmpty) {
      await _prefs.remove('vault_security_question');
    } else {
      await _prefs.setString('vault_security_question', q);
    }
  }

  String? get vaultAnswer => _prefs.getString('vault_security_answer');
  Future<void> setVaultAnswer(String? a) async {
    if (a == null || a.isEmpty) {
      await _prefs.remove('vault_security_answer');
    } else {
      await _prefs.setString('vault_security_answer', a.toLowerCase().trim());
    }
  }

  ListeningStreak get listeningStreak {
    final count = _prefs.getInt(AppConstants.streakCount) ?? 0;
    final last = _prefs.getString(AppConstants.streakLastDate);
    final today = _dateKey(DateTime.now());
    final listenedToday = last == today;
    return ListeningStreak(days: count, listenedToday: listenedToday);
  }

  Future<void> recordListenStreak() async {
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final last = _prefs.getString(AppConstants.streakLastDate);
    var count = _prefs.getInt(AppConstants.streakCount) ?? 0;
    if (last == todayKey) return;
    if (last == _dateKey(today.subtract(const Duration(days: 1)))) {
      count += 1;
    } else {
      count = 1;
    }
    await _prefs.setString(AppConstants.streakLastDate, todayKey);
    await _prefs.setInt(AppConstants.streakCount, count);
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get groqApiKey => _prefs.getString('groq_api_key') ?? '';
  Future<void> setGroqApiKey(String key) => _prefs.setString('groq_api_key', key.trim());

  String get openaiApiKey => _prefs.getString('openai_api_key') ?? '';
  Future<void> setOpenaiApiKey(String key) => _prefs.setString('openai_api_key', key.trim());

  String get spotifyClientId => _prefs.getString('spotify_client_id') ?? '';
  Future<void> setSpotifyClientId(String val) => _prefs.setString('spotify_client_id', val.trim());

  String get spotifyClientSecret => _prefs.getString('spotify_client_secret') ?? '';
  Future<void> setSpotifyClientSecret(String val) => _prefs.setString('spotify_client_secret', val.trim());

  String get customSyncId => _prefs.getString('rotty_custom_sync_id') ?? '';
  Future<void> setCustomSyncId(String val) => _prefs.setString('rotty_custom_sync_id', val.trim());

  String get installationId {
    var id = _prefs.getString('installation_id');
    if (id == null || id.isEmpty) {
      final rand = 100000 + (DateTime.now().millisecondsSinceEpoch % 900000);
      id = 'user_${(!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ? 'windows' : 'mobile'}_$rand';
      _prefs.setString('installation_id', id);
    }
    return id;
  }

  bool get aiDjEnabled => _prefs.getBool('ai_dj_enabled') ?? false;
  Future<void> setAiDjEnabled(bool value) => _prefs.setBool('ai_dj_enabled', value);

  String? get cloudSyncUrl {
    final v = _prefs.getString('cloud_sync_url');
    return v != null && v.isNotEmpty ? v : null;
  }

  Future<void> setCloudSyncUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _prefs.remove('cloud_sync_url');
    } else {
      await _prefs.setString('cloud_sync_url', url.trim());
    }
  }

  // ─── Downloaded Songs ───
  List<SongModel> getDownloadedSongs() {
    return _downloadedBox.values
        .map<SongModel>((e) => SongModel.fromHive(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  bool isSongDownloaded(String songId) {
    return _downloadedBox.containsKey(songId);
  }

  Future<void> saveDownloadedSong(SongModel song) async {
    await _downloadedBox.put(song.id, song.toJson());
  }

  Future<void> deleteDownloadedSong(String songId) async {
    await _downloadedBox.delete(songId);
  }

  // ─── Cache ───
  Future<void> clearCache() async {
    await _recentBox.clear();
    await _searchBox.clear();
  }

  // ─── Supporter & Version Tracking ───
  bool get hasSeenSupportOverlay => _prefs.getBool('has_seen_support_overlay') ?? false;
  Future<void> setHasSeenSupportOverlay(bool v) => _prefs.setBool('has_seen_support_overlay', v);

  String get lastSeenVersion => _prefs.getString('last_seen_version') ?? '';
  Future<void> setLastSeenVersion(String version) => _prefs.setString('last_seen_version', version);

  bool get isSupporter => _prefs.getBool('is_supporter_local') ?? false;
  Future<void> setIsSupporter(bool v) => _prefs.setBool('is_supporter_local', v);

  List<String> get favoriteArtists => _prefs.getStringList('favorite_artists') ?? [];
  Future<void> setFavoriteArtists(List<String> artists) => _prefs.setStringList('favorite_artists', artists);

  bool get hasSelectedFavorites => _prefs.getBool('has_selected_favorites') ?? false;
  Future<void> setHasSelectedFavorites(bool val) => _prefs.setBool('has_selected_favorites', val);

  String get profileName => _prefs.getString('profile_name') ?? '';
  Future<void> setProfileName(String name) => _prefs.setString('profile_name', name.trim());

  String get profileEmail => _prefs.getString('profile_email') ?? '';
  Future<void> setProfileEmail(String email) => _prefs.setString('profile_email', email.trim());

  bool get albumArtRipples => _prefs.getBool('album_art_ripples') ?? true;
  Future<void> setAlbumArtRipples(bool v) => _prefs.setBool('album_art_ripples', v);

  bool get eqMeshVisualizer => _prefs.getBool('eq_mesh_visualizer') ?? true;
  Future<void> setEqMeshVisualizer(bool v) => _prefs.setBool('eq_mesh_visualizer', v);

  String get customBackendIp => _prefs.getString('custom_backend_ip') ?? '';
  Future<void> setCustomBackendIp(String ip) => _prefs.setString('custom_backend_ip', ip.trim());

  // ─── Private AI Studio Creations ───
  List<SongModel> getStudioCreations() {
    return _mashupsBox.values
        .map<SongModel>((e) => SongModel.fromHive(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveStudioCreation(SongModel song) async {
    await _mashupsBox.put(song.id, song.toJson());
  }

  Future<void> deleteStudioCreation(String id) async {
    final songData = _mashupsBox.get(id);
    if (songData != null) {
      final url = songData['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        try {
          String path = url;
          if (path.startsWith('file://')) {
            path = Uri.parse(url).toFilePath();
          }
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting local creation file: $e');
        }
      }
    }
    await _mashupsBox.delete(id);
  }

  bool get mixFadeEnabled => _prefs.getBool('mix_fade_enabled') ?? false;
  Future<void> setMixFadeEnabled(bool value) => _prefs.setBool('mix_fade_enabled', value);

  String get mixBlendStyle => _prefs.getString('mix_blend_style') ?? 'Smooth';
  Future<void> setMixBlendStyle(String value) => _prefs.setString('mix_blend_style', value);

  int get mixBlendLength => _prefs.getInt('mix_blend_length') ?? 6;
  Future<void> setMixBlendLength(int value) => _prefs.setInt('mix_blend_length', value);

  String get aiRadioCache => _prefs.getString('ai_radio_cache') ?? '';
  Future<void> setAiRadioCache(String value) => _prefs.setString('ai_radio_cache', value);

  String get lastNotificationId => _prefs.getString('last_notification_id') ?? '';
  Future<void> setLastNotificationId(String id) => _prefs.setString('last_notification_id', id);

  // ─── Lyrics Cache ───
  String? getCachedLyrics(String songId) {
    return _lyricsBox.get(songId) as String?;
  }

  Future<void> saveCachedLyrics(String songId, String lyrics) async {
    await _lyricsBox.put(songId, lyrics);
  }
}

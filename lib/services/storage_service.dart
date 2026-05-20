
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/modes/app_mode.dart';
import '../core/sound/sound_space.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/play_history_entry.dart';
import '../core/premium/premium_models.dart';

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

  Future<void> init() async {
    await Hive.initFlutter();
    _prefs = await SharedPreferences.getInstance();
    _recentBox = await Hive.openBox(AppConstants.recentBox);
    _favoritesBox = await Hive.openBox(AppConstants.favoritesBox);
    _playlistBox = await Hive.openBox(AppConstants.playlistBox);
    _searchBox = await Hive.openBox(AppConstants.searchHistoryBox);
    _historyBox = await Hive.openBox(AppConstants.playHistoryBox);
    _partyBox = await Hive.openBox(AppConstants.partyRoomBox);
  }

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

  Future<void> savePlaylist(PlaylistModel playlist) async {
    await _playlistBox.put(playlist.id, playlist.toJson());
  }

  Future<void> deletePlaylist(String id) async {
    await _playlistBox.delete(id);
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

  // ─── Cache ───
  Future<void> clearCache() async {
    await _recentBox.clear();
    await _searchBox.clear();
  }
}

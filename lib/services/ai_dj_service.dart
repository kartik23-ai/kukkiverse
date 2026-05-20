import 'dart:math';
import '../models/song_model.dart';
import 'api_service.dart';
import 'groq_ai_service.dart';

enum AiMood {
  energetic('Energetic', 'workout party hindi english hits'),
  chill('Chill', 'lofi chill hindi acoustic'),
  romantic('Romantic', 'romantic hindi love songs'),
  focus('Focus', 'instrumental focus study'),
  party('Party', 'party dance bollywood punjabi'),
  night('Night', 'late night sad hindi songs');

  const AiMood(this.label, this.searchQuery);
  final String label;
  final String searchQuery;
}

class AiDjInsight {
  final AiMood mood;
  final String message;
  final List<String> reasons;

  const AiDjInsight({
    required this.mood,
    required this.message,
    required this.reasons,
  });
}

class AiDjService {
  AiDjService(this._api, [GroqAiService? groq]) : _groq = groq ?? GroqAiService();
  final ApiService _api;
  final GroqAiService _groq;
  final _rng = Random();

  /// Track title+artist fingerprint to prevent near-duplicates (remixes etc)
  String _fingerprint(SongModel s) =>
      '${s.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}|${s.artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';

  AiDjInsight analyze({
    required SongModel? nowPlaying,
    required List<SongModel> recent,
    required List<SongModel> favorites,
    required int hour,
  }) {
    final reasons = <String>[];
    var mood = AiMood.chill;

    if (hour >= 5 && hour < 11) {
      mood = AiMood.energetic;
      reasons.add('Morning boost');
    } else if (hour >= 11 && hour < 17) {
      mood = AiMood.focus;
      reasons.add('Afternoon focus');
    } else if (hour >= 17 && hour < 22) {
      mood = AiMood.party;
      reasons.add('Evening energy');
    } else {
      mood = AiMood.night;
      reasons.add('Late night vibes');
    }

    final seed = nowPlaying ?? (recent.isNotEmpty ? recent.first : null);
    if (seed != null) {
      final t = '${seed.title} ${seed.artist}'.toLowerCase();
      if (_hasAny(t, ['love', 'dil', 'romantic', 'heart', 'mohabbat'])) {
        mood = AiMood.romantic;
        reasons.add('Romantic track detected');
      } else if (_hasAny(t, ['party', 'dance', 'dj', 'remix', 'club'])) {
        mood = AiMood.party;
        reasons.add('Party vibe from now playing');
      } else if (_hasAny(t, ['sad', 'raat', 'akh', 'tear', 'dard'])) {
        mood = AiMood.night;
        reasons.add('Mellow mood from lyrics vibe');
      } else {
        reasons.add('Based on "${seed.title}"');
      }
    }

    if (favorites.length > 5) {
      reasons.add('${favorites.length} favorites considered');
    }

    return AiDjInsight(
      mood: mood,
      message: 'ROTTY AI picked ${mood.label} for you',
      reasons: reasons,
    );
  }

  Future<List<SongModel>> buildSmartQueue({
    required SongModel? nowPlaying,
    required List<SongModel> recent,
    required List<SongModel> favorites,
    required Set<String> excludeIds,
    int limit = 25,
  }) async {
    final hour = DateTime.now().hour;
    final insight = analyze(
      nowPlaying: nowPlaying,
      recent: recent,
      favorites: favorites,
      hour: hour,
    );

    // Build aggressive exclude set — IDs AND fingerprints
    final excludeIdSet = Set<String>.from(excludeIds);
    final excludeFingerprints = <String>{};

    for (final s in recent) {
      excludeIdSet.add(s.id);
      excludeFingerprints.add(_fingerprint(s));
    }
    for (final s in favorites) {
      excludeFingerprints.add(_fingerprint(s));
    }

    final queries = <String>[];

    // 1. Groq for smart contextual queries
    if (nowPlaying != null) {
      try {
        final groqQ = await _groq.suggestSearchQueries(
          nowPlayingTitle: nowPlaying.title,
          nowPlayingArtist: nowPlaying.artist,
          moodLabel: insight.mood.label,
          recentTitles: recent.map((s) => s.title).toList(),
        );
        if (groqQ.isNotEmpty) queries.addAll(groqQ);
      } catch (_) {}

      // Artist and album seeds
      queries.add('${nowPlaying.artist} best songs');
      if (nowPlaying.album.isNotEmpty && nowPlaying.album != 'Single') {
        queries.add(nowPlaying.album);
      }
      excludeIdSet.add(nowPlaying.id);
      excludeFingerprints.add(_fingerprint(nowPlaying));
    }

    // 2. Mood queries — pick DIFFERENT moods for variety
    final moodPool = AiMood.values.where((m) => m != insight.mood).toList()..shuffle(_rng);
    queries.add(insight.mood.searchQuery);
    for (final m in moodPool.take(1)) {
      queries.add(m.searchQuery);
    }

    // 3. Favorites-based artist queries (different from now playing)
    if (favorites.isNotEmpty) {
      final favArtists = favorites
          .map((s) => s.artist)
          .where((a) => nowPlaying == null || a != nowPlaying.artist)
          .toSet()
          .toList()
        ..shuffle(_rng);
      for (final a in favArtists.take(2)) {
        queries.add('$a popular songs');
      }
    }

    // 4. General variety fallbacks
    queries.addAll([
      'trending hindi songs ${DateTime.now().year}',
      'latest bollywood hits',
      'new indie hindi songs',
    ]);

    final result = <SongModel>[];
    final usedQueries = <String>{};
    final addedFingerprints = <String>{};

    for (final rawQ in queries) {
      if (result.length >= limit) break;
      final q = rawQ.trim().toLowerCase();
      if (q.isEmpty || q.length < 3 || usedQueries.contains(q)) continue;
      usedQueries.add(q);

      try {
        final songs = await _api.searchSongs(rawQ.trim(), limit: 15, page: 1);
        if (songs.isEmpty) continue;

        final shuffled = List<SongModel>.from(songs)..shuffle(_rng);
        
        for (final s in shuffled) {
          if (result.length >= limit) break;
          if (s.id.isEmpty) continue;
          
          // Skip by ID
          if (excludeIdSet.contains(s.id)) continue;
          
          // Skip by fingerprint (prevents duplicates/remixes)
          final fp = _fingerprint(s);
          if (excludeFingerprints.contains(fp)) continue;
          if (addedFingerprints.contains(fp)) continue;
          
          excludeIdSet.add(s.id);
          addedFingerprints.add(fp);
          result.add(s);
        }
      } catch (_) {
        continue;
      }
    }

    result.shuffle(_rng);
    return result.take(limit).toList();
  }

  String buildReasonLine({
    required SongModel? nowPlaying,
    required List<SongModel> recent,
    required AiMood? override,
  }) {
    final insight = analyze(
      nowPlaying: nowPlaying,
      recent: recent,
      favorites: const [],
      hour: DateTime.now().hour,
    );
    final mood = override ?? insight.mood;
    if (nowPlaying != null) {
      return 'Kyunki tumne "${nowPlaying.title}" suna, ab ${mood.label} vibe';
    }
    return insight.message;
  }

  Future<List<SongModel>> applyMoodTransition({
    required AiMood target,
    required SongModel? nowPlaying,
    required List<SongModel> recent,
    required List<SongModel> favorites,
    required Set<String> excludeIds,
    int limit = 20,
  }) async {
    final exclude = Set<String>.from(excludeIds);
    final excludeFp = <String>{};
    if (nowPlaying != null) {
      exclude.add(nowPlaying.id);
      excludeFp.add(_fingerprint(nowPlaying));
    }
    for (final s in recent) {
      exclude.add(s.id);
      excludeFp.add(_fingerprint(s));
    }

    final songs = await _api.searchSongs(target.searchQuery, limit: limit + 10, page: 1);
    return songs
        .where((s) => !exclude.contains(s.id) && !excludeFp.contains(_fingerprint(s)))
        .take(limit)
        .toList();
  }

  bool _hasAny(String text, List<String> keys) =>
      keys.any((k) => text.contains(k));
}

import 'dart:math';
import 'package:flutter/foundation.dart';
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

  bool _isIndianVibe(SongModel song) {
    final titleLower = song.title.toLowerCase();
    final artistLower = song.artist.toLowerCase();
    
    // Check Indic scripts (Devanagari, Gurmukhi, etc.)
    if (RegExp(r'[\u0900-\u097F\u0A00-\u0A7F]').hasMatch(song.title) || 
        RegExp(r'[\u0900-\u097F\u0A00-\u0A7F]').hasMatch(song.artist)) {
      return true;
    }
    
    // Prominent Indian artists keywords
    final indianArtists = [
      'arijit', 'neha kakkar', 'jubin', 'pritam', 'badshah', 'shreya ghoshal', 
      'diljit', 'dhillon', 'randhawa', 'praak', 'moose wala', 'aujla', 'honey singh', 
      'divine', 'mc stan', 'king', 'raftaar', 'anuv jain', 'darshan raval', 'sonu nigam', 
      'sunidhi', 'atif aslam', 'rahat fateh', 'lata mangeshkar', 'kishore kumar', 
      'rafi', 'burman', 'asha bhosle', 'udit narayan', 'alka yagnik', 'kumar sanu',
      'vishal-shekhar', 'sachin-jigar', 'shankar-ehsaan-loy', 'amit trivedi', 
      'rahman', 'mithoon', 'tanishk', 'salim-sulaiman', 'sachet-parampara', 'jasleen royal'
    ];
    if (indianArtists.any((a) => artistLower.contains(a))) {
      return true;
    }
    
    // Common romanized Hindi/Punjabi keywords
    final indianWords = [
      'dil', 'pyar', 'ishq', 'mohabbat', 'jiya', 'jaan', 'rabba', 'yaara', 'heeriye', 'soniye',
      'tera', 'tere', 'meri', 'mere', 'tum', 'tujhe', 'tumhe', 'apna', 'apne', 'hum', 'humein',
      'kya', 'kyun', 'kabhi', 'kaise', 'sab', 'ek', 'do', 'teen', 'char', 'sath', 'saath',
      'chal', 'chale', 'aaja', 'jaana', 'raat', 'din', 'subah', 'shyam', 'zindagi', 'duniya',
      'munda', 'kudi', 'gabru', 'naal', 'billo', 'suit', 'patola', 'gaddi', 'pind', 'gallan',
      'raaste', 'musafir', 'safar', 'khoya', 'naseeb', 'akh', 'ankhein', 'soche', 'dosti', 'haal'
    ];
    final words = titleLower.split(RegExp(r'[^a-z0-9]'));
    if (words.any((w) => indianWords.contains(w))) {
      return true;
    }
    
    return false;
  }

  Future<List<SongModel>> buildSmartQueue({
    required SongModel? nowPlaying,
    required List<SongModel> recent,
    required List<SongModel> favorites,
    required Set<String> excludeIds,
    int limit = 25,
  }) async {
    final hour = DateTime.now().hour;
    
    // Evaluate active session mood override (from last 10 tracks)
    var activeVibeMood = analyze(
      nowPlaying: nowPlaying,
      recent: recent,
      favorites: favorites,
      hour: hour,
    ).mood;

    if (recent.isNotEmpty) {
      final sessionCount = min(10, recent.length);
      final sessionSample = recent.take(sessionCount).toList();
      var romanticCount = 0;
      var energeticCount = 0;
      var chillCount = 0;
      var sadCount = 0;
      for (final s in sessionSample) {
        final lower = '${s.title} ${s.artist}'.toLowerCase();
        if (_hasAny(lower, ['love', 'dil', 'romantic', 'heart', 'mohabbat', 'pyar', 'ishq'])) romanticCount++;
        if (_hasAny(lower, ['party', 'dance', 'dj', 'remix', 'club', 'hits', 'punjabi', 'gabru'])) energeticCount++;
        if (_hasAny(lower, ['lofi', 'chill', 'acoustic', 'ambient', 'peaceful'])) chillCount++;
        if (_hasAny(lower, ['sad', 'raat', 'akh', 'tear', 'dard', 'alone', 'broken'])) sadCount++;
      }
      
      final maxVibe = [romanticCount, energeticCount, chillCount, sadCount].reduce(max);
      if (maxVibe >= 2) {
        if (maxVibe == romanticCount) activeVibeMood = AiMood.romantic;
        else if (maxVibe == energeticCount) activeVibeMood = AiMood.energetic;
        else if (maxVibe == chillCount) activeVibeMood = AiMood.chill;
        else if (maxVibe == sadCount) activeVibeMood = AiMood.night;
      }
    }

    final excludeIdSet = Set<String>.from(excludeIds);
    final excludeFingerprints = <String>{};

    for (final s in recent) {
      excludeIdSet.add(s.id);
      excludeFingerprints.add(_fingerprint(s));
    }
    for (final s in favorites) {
      excludeFingerprints.add(_fingerprint(s));
    }

    final result = <SongModel>[];
    final isIndian = nowPlaying != null ? _isIndianVibe(nowPlaying) : true;

    // A. Native V4 Collaborative Recommendations (Primary Source)
    if (nowPlaying != null) {
      try {
        debugPrint('ROTTY SMART RECO ENGINE: Pulling V4 Android recommendations for "${nowPlaying.title}"...');
        final nativeRecommended = await _api.getRecommendations(nowPlaying.id);
        if (nativeRecommended.isNotEmpty) {
          for (final s in nativeRecommended) {
            if (result.length >= limit) break;
            if (s.id.isEmpty || excludeIdSet.contains(s.id)) continue;
            if (_isIndianVibe(s) != isIndian) continue;
            final fp = _fingerprint(s);
            if (excludeFingerprints.contains(fp)) continue;
            
            excludeIdSet.add(s.id);
            excludeFingerprints.add(fp);
            result.add(s);
          }
        }
      } catch (e) {
        debugPrint('ROTTY SMART RECO ENGINE: Native Mobile Recommendations failed ($e)');
      }
      
      excludeIdSet.add(nowPlaying.id);
      excludeFingerprints.add(_fingerprint(nowPlaying));
    }

    // B. Smart Queries & Fallbacks
    final queries = <String>[];
    bool useLocalFallback = true;

    if (nowPlaying != null && result.length < limit) {
      try {
        final groqQ = await _groq.suggestSearchQueries(
          nowPlayingTitle: nowPlaying.title,
          nowPlayingArtist: nowPlaying.artist,
          moodLabel: activeVibeMood.label,
          recentTitles: recent.map((s) => s.title).toList(),
        );
        if (groqQ.isNotEmpty) {
          queries.addAll(groqQ);
          useLocalFallback = false;
        }
      } catch (_) {}

      if (useLocalFallback) {
        final primaryArtist = nowPlaying.artist.split(RegExp(r'[,&]')).first.trim();
        queries.add('$primaryArtist popular');
        queries.add('$primaryArtist hits');
        if (nowPlaying.album.isNotEmpty && nowPlaying.album != 'Single') {
          queries.add(nowPlaying.album);
        }
      }
    }

    // Mood query based on dynamic session vibe evaluation
    String moodQuery = activeVibeMood.searchQuery;
    if (!isIndian) {
      moodQuery = switch (activeVibeMood) {
        AiMood.energetic => 'workout dance pop hits english',
        AiMood.chill => 'lofi study chill acoustic english',
        AiMood.romantic => 'romantic pop love songs english',
        AiMood.focus => 'ambient focus study post-rock lofi',
        AiMood.party => 'edm party club dance hits billboard',
        AiMood.night => 'mellow sad late night indie pop',
      };
    }
    queries.add(moodQuery);

    // Add popular songs from user's absolute favorite artists
    if (favorites.isNotEmpty) {
      final favArtists = favorites
          .map((s) => s.artist)
          .where((a) => nowPlaying == null || a != nowPlaying.artist)
          .toSet()
          .toList()
        ..shuffle(_rng);
      for (final a in favArtists.take(3)) {
        final primary = a.split(RegExp(r'[,&]')).first.trim();
        queries.add('$primary hits');
      }
    }

    // Language-locked diversity filters
    if (isIndian) {
      queries.addAll([
        'trending hindi songs',
        'latest bollywood hits',
        'punjabi popular hits',
      ]);
    } else {
      queries.addAll([
        'billboard top hits',
        'trending pop songs',
        'viral hits english',
      ]);
    }

    final usedQueries = <String>{};
    final addedFingerprints = <String>{};

    for (final rawQ in queries) {
      if (result.length >= limit) break;
      final q = rawQ.trim().toLowerCase();
      if (q.isEmpty || q.length < 3 || usedQueries.contains(q)) continue;
      usedQueries.add(q);

      try {
        final songs = await _api.searchSongs(rawQ.trim(), limit: 12, page: 1);
        if (songs.isEmpty) continue;

        final shuffled = List<SongModel>.from(songs)..shuffle(_rng);
        
        for (final s in shuffled) {
          if (result.length >= limit) break;
          if (s.id.isEmpty || excludeIdSet.contains(s.id)) continue;
          if (nowPlaying != null && _isIndianVibe(s) != isIndian) continue;

          final fp = _fingerprint(s);
          if (excludeFingerprints.contains(fp)) continue;
          if (addedFingerprints.contains(fp)) continue;
          
          excludeIdSet.add(s.id);
          addedFingerprints.add(fp);
          result.add(s);
        }
      } catch (_) {}
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

    final isIndian = nowPlaying != null ? _isIndianVibe(nowPlaying) : true;
    String targetQuery = target.searchQuery;
    if (!isIndian) {
      targetQuery = switch (target) {
        AiMood.energetic => 'workout dance pop hits workout',
        AiMood.chill => 'lofi study chill acoustic english',
        AiMood.romantic => 'romantic pop love songs english',
        AiMood.focus => 'ambient focus study post-rock lofi',
        AiMood.party => 'edm party club dance hits billboard',
        AiMood.night => 'mellow sad late night indie pop',
      };
    }

    final songs = await _api.searchSongs(targetQuery, limit: limit + 15, page: 1);
    return songs
        .where((s) => 
            !exclude.contains(s.id) && 
            !excludeFp.contains(_fingerprint(s)) &&
            (nowPlaying == null || _isIndianVibe(s) == isIndian))
        .take(limit)
        .toList();
  }

  bool _hasAny(String text, List<String> keys) =>
      keys.any((k) => text.contains(k));
}

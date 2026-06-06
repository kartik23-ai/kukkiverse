import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import 'api_service.dart';

enum AiMood {
  energetic('Energetic', 'workout party hindi english hits'),
  chill('Chill', 'lofi chill hindi acoustic'),
  romantic('Romantic', 'romantic hindi love songs'),
  focus('Focus', 'instrumental focus study'),
  party('Party', 'party dance bollywood punjabi'),
  night('Night', 'late night sad hindi songs'),
  devotional('Devotional', 'devotional bhajan aarti bhakti krishna ram');

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
  AiDjService(this._api);
  final ApiService _api;
  final _rng = Random();

  String _cleanTitle(String title) {
    var cleaned = title.toLowerCase();
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    final splitIndex = cleaned.indexOf(RegExp(r'[-|:]'));
    if (splitIndex != -1) {
      cleaned = cleaned.substring(0, splitIndex);
    }
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Track title+artist fingerprint to prevent near-duplicates (remixes etc)
  String _fingerprint(SongModel s) {
    final t = _cleanTitle(s.title);
    final a = s.artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$t|$a';
  }

  bool _isCopyOrRemix(SongModel song) {
    final title = song.title.toLowerCase();
    final copyKeywords = [
      'remix', 're-mix', 'cover', 'lofi', 'lo-fi', 'instrumental', 'karaoke', 
      'acoustic', 'slowed', 'reverb', 'tribute', 'mashup', 'reprise', 
      'female version', 'male version', 'sad version', 'revisited', 're-vibe',
      'speed up', 'sped up', 'slowed down', 'instrumental version', 'unplugged',
      'version', 'remake', 'r&b version', 'cover version', 'edit', 'mix', 'blend'
    ];
    
    return copyKeywords.any((keyword) {
      if (keyword == 'mix' || keyword == 'edit') {
        return title.split(RegExp(r'[^a-zA-Z0-9]')).contains(keyword);
      }
      return title.contains(keyword);
    });
  }


  bool _isNearDuplicate(SongModel s, List<SongModel> currentList) {
    final titleSimp = _cleanTitle(s.title);
    if (titleSimp.isEmpty) return true;
    
    final artistSimp = s.artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final words1 = s.artist.toLowerCase().split(RegExp(r'[^a-z0-9]')).where((w) => w.length >= 4).toSet();

    for (final existing in currentList) {
      final existingTitleSimp = _cleanTitle(existing.title);
      if (existingTitleSimp == titleSimp) {
        final existingArtistSimp = existing.artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (existingArtistSimp == artistSimp || 
            existingArtistSimp.contains(artistSimp) || 
            artistSimp.contains(existingArtistSimp)) {
          return true;
        }
        final words2 = existing.artist.toLowerCase().split(RegExp(r'[^a-z0-9]')).where((w) => w.length >= 4).toSet();
        if (words1.intersection(words2).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }


  AiMood? _detectVibe(SongModel song) {
    final t = '${song.title} ${song.artist} ${song.album}'.toLowerCase();
    
    // 1. Devotional
    if (_hasAny(t, [
      'bhajan', 'aarti', 'shiva', 'krishna', 'ram', 'hanuman', 'devotional', 
      'ganesha', 'ganpati', 'shree', 'chalisa', 'stotra', 'mantra', 'om', 
      'sai', 'mahadev', 'durga', 'bhakti', 'bhojpuri bhajan', 'kirtan', 
      'gospel', 'worship', 'jesus', 'spiritual', 'prayer', 'stotram', 'shlok', 
      'shloka', 'stuti', 'krishan', 'hanuman chalisa'
    ])) {
      return AiMood.devotional;
    }
    
    // 2. Sad / Night
    if (_hasAny(t, [
      'sad', 'dard', 'alone', 'broken', 'gham', 'tear', 'judai', 
      'faasle', 'tanhai', 'rua', 'roye', 'khamoshi', 'judaa', 
      'maut', 'wafa', 'bewafa', 'cry', 'crying', 'dhoke'
    ])) {
      return AiMood.night;
    }
    
    // 3. Romantic
    if (_hasAny(t, [
      'love', 'dil', 'romantic', 'heart', 'mohabbat', 'pyar', 'ishq', 
      'sanam', 'humsafar', 'dhadkan', 'ashq', 'pyaar', 'shiddat', 'khuda'
    ])) {
      return AiMood.romantic;
    }
    
    // 4. Party / Energetic
    if (_hasAny(t, [
      'party', 'dance', 'dj', 'remix', 'club', 'punjabi', 'gabru', 
      'billo', 'dhol', 'bhangra', 'club mix'
    ])) {
      return AiMood.party;
    }
    
    // 5. Chill
    if (_hasAny(t, [
      'lofi', 'chill', 'acoustic', 'ambient', 'peaceful', 'unplugged'
    ])) {
      return AiMood.chill;
    }
    
    // 6. Focus
    if (_hasAny(t, [
      'instrumental', 'focus', 'study', 'meditation'
    ])) {
      return AiMood.focus;
    }
    
    return null;
  }


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

    if (nowPlaying != null) {
      final detected = _detectVibe(nowPlaying);
      if (detected != null) {
        mood = detected;
        reasons.add('${detected.label} vibe from playing track');
        return AiDjInsight(mood: mood, message: 'ROTTY AI locked ${mood.label} vibe', reasons: reasons);
      }
    }

    if (recent.isNotEmpty) {
      final sessionCount = min(10, recent.length);
      final sessionSample = recent.take(sessionCount).toList();
      final moodCounts = <AiMood, int>{};
      for (final s in sessionSample) {
        final det = _detectVibe(s);
        if (det != null) {
          moodCounts[det] = (moodCounts[det] ?? 0) + 1;
        }
      }
      if (moodCounts.isNotEmpty) {
        var bestMood = mood;
        var maxCount = 0;
        moodCounts.forEach((m, c) {
          if (c > maxCount) {
            maxCount = c;
            bestMood = m;
          }
        });
        if (maxCount >= 2) {
          mood = bestMood;
          reasons.add('Based on recent session vibe');
          return AiDjInsight(mood: mood, message: 'ROTTY AI selected ${mood.label} from session history', reasons: reasons);
        }
      }
    }

    if (nowPlaying != null) {
      reasons.add('Defaulting for "${nowPlaying.title}"');
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
    
    if (RegExp(r'[\u0900-\u097F\u0A00-\u0A7F]').hasMatch(song.title) || 
        RegExp(r'[\u0900-\u097F\u0A00-\u0A7F]').hasMatch(song.artist)) {
      return true;
    }
    
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

  String _getSongFingerprint(SongModel s) {
    if (s.title.isEmpty) return '';
    var title = s.title.toLowerCase();
    title = title.replaceAll(RegExp(r'\([^)]*\)'), '').replaceAll(RegExp(r'\[[^\]]*\]'), '');
    title = title.replaceAll(RegExp(r'\b(lofi|remix|acoustic|reprise|cover|radio|edit|slowed|reverb|version|mix|original)\b'), '');
    final cleanTitle = title.replaceAll(RegExp(r'[^a-z0-9]'), '');

    var artist = s.artist.toLowerCase()
      .split(',')[0]
      .trim()
      .replaceAll(RegExp(r'\b(feat|ft|featuring)\b.*'), '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$cleanTitle|$artist';
  }

  String _getLanguageFallbackQuery(SongModel seed, {bool isSecondary = false}) {
    final isIndian = _isIndianVibe(seed);
    final artist = seed.artist.split(RegExp(r'[,&]')).first.trim();

    if (isSecondary) {
      if (!isIndian) return 'trending english';
      final artistLower = seed.artist.toLowerCase();
      if (artistLower.contains('diljit') || artistLower.contains('dhillon') || artistLower.contains('aujla') || artistLower.contains('moose wala')) {
        return 'trending punjabi';
      }
      return 'trending hindi';
    }

    if (artist.isNotEmpty && artist != 'Artist') {
      return '$artist songs';
    }

    if (!isIndian) return 'trending english';
    final artistLower = seed.artist.toLowerCase();
    if (artistLower.contains('diljit') || artistLower.contains('dhillon') || artistLower.contains('aujla') || artistLower.contains('moose wala')) {
      return 'trending punjabi';
    }
    return 'trending hindi';
  }

  Future<List<SongModel>> buildSmartQueue({
    required SongModel? nowPlaying,
    required List<SongModel> recent,
    required List<SongModel> favorites,
    required Set<String> excludeIds,
    List<SongModel> excludeSongs = const [],
    int limit = 25,
  }) async {
    final songToMatch = nowPlaying ?? (recent.isNotEmpty ? recent.first : (favorites.isNotEmpty ? favorites.first : null));
    if (songToMatch == null) return [];

    try {
      debugPrint('[AiDjService] Building smart queue based on vibe seed: ${songToMatch.title}');

      // Fetch primary recommendations for seed song
      final primaryRecs = await _api.getRecommendations(
        songToMatch.id,
        title: songToMatch.title,
        artist: songToMatch.artist,
        limit: 12,
      );

      // Fetch recommendations for a random recently played song to personalize the experience
      List<SongModel> personalizedRecs = [];
      final recentsFiltered = recent.where((s) => s.id != songToMatch.id).toList();
      if (recentsFiltered.isNotEmpty) {
        final randomSeed = recentsFiltered[_rng.nextInt(min(5, recentsFiltered.length))];
        personalizedRecs = await _api.getRecommendations(
          randomSeed.id,
          title: randomSeed.title,
          artist: randomSeed.artist,
          limit: 8,
        );
      }

      // Interleave/Blend recommendations
      final combined = <SongModel>[...primaryRecs];
      for (int i = 0; i < personalizedRecs.length; i++) {
        final targetIndex = min(combined.length, (i * 2) + 1);
        combined.insert(targetIndex, personalizedRecs[i]);
      }

      // Setup duplicate & fingerprint filters (already in queue or playing)
      final existingIds = Set<String>.from(excludeIds);
      final existingFingerprints = <String>{};

      for (final s in excludeSongs) {
        existingFingerprints.add(_getSongFingerprint(s));
      }
      if (nowPlaying != null) {
        existingIds.add(nowPlaying.id);
        existingFingerprints.add(_getSongFingerprint(nowPlaying));
      }

      final newSongs = <SongModel>[];
      for (final s in combined) {
        if (s.id.isEmpty) continue;
        if (s.id.startsWith('youtube_')) continue;
        if (existingIds.contains(s.id)) continue;
        final fp = _getSongFingerprint(s);
        if (fp.isEmpty || existingFingerprints.contains(fp)) continue;

        existingIds.add(s.id);
        existingFingerprints.add(fp);
        newSongs.add(s);
      }

      // Robust multi-level fallback if suggestions are empty
      if (newSongs.isEmpty) {
        debugPrint('[AiDjService] Smart queue empty. Executing robust fallbacks...');
        final fallbackQuery = _getLanguageFallbackQuery(songToMatch, isSecondary: false);
        final fallbackSongs = await _api.searchSongs(fallbackQuery, limit: 12);
        
        for (final s in fallbackSongs) {
          if (s.id.isEmpty) continue;
          if (s.id.startsWith('youtube_')) continue;
          if (existingIds.contains(s.id)) continue;
          final fp = _getSongFingerprint(s);
          if (fp.isEmpty || existingFingerprints.contains(fp)) continue;

          existingIds.add(s.id);
          existingFingerprints.add(fp);
          newSongs.add(s);
        }

        if (newSongs.isEmpty) {
          final secondaryQuery = _getLanguageFallbackQuery(songToMatch, isSecondary: true);
          final trendingSongs = await _api.searchSongs(secondaryQuery, limit: 12);
          for (final s in trendingSongs) {
            if (s.id.isEmpty) continue;
            if (s.id.startsWith('youtube_')) continue;
            if (existingIds.contains(s.id)) continue;
            final fp = _getSongFingerprint(s);
            if (fp.isEmpty || existingFingerprints.contains(fp)) continue;

            existingIds.add(s.id);
            existingFingerprints.add(fp);
            newSongs.add(s);
          }
        }
      }

      return newSongs.take(limit).toList();
    } catch (e) {
      debugPrint('[AiDjService] Smart Queue generation failed: $e');
      return [];
    }
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
    List<SongModel> excludeSongs = const [],
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
    for (final s in excludeSongs) {
      exclude.add(s.id);
      excludeFp.add(_fingerprint(s));
    }

    final isIndian = nowPlaying != null ? _isIndianVibe(nowPlaying) : true;
    final bool seedIsCopy = nowPlaying != null && _isCopyOrRemix(nowPlaying);
    final bool excludeCopies = !seedIsCopy;
    String targetQuery = target.searchQuery;
    if (!isIndian) {
      targetQuery = switch (target) {
        AiMood.energetic => 'workout dance pop hits workout',
        AiMood.chill => 'lofi study chill acoustic english',
        AiMood.romantic => 'romantic pop love songs english',
        AiMood.focus => 'ambient focus study post-rock lofi',
        AiMood.party => 'edm party club dance hits billboard',
        AiMood.night => 'mellow sad late night indie pop',
        AiMood.devotional => 'christian worship gospel spiritual meditation healing music',
      };
    }

    final List<SongModel> seenSongs = [];
    if (nowPlaying != null) seenSongs.add(nowPlaying);
    seenSongs.addAll(recent);
    seenSongs.addAll(favorites);
    seenSongs.addAll(excludeSongs);

    final songs = await _api.searchSongs(targetQuery, limit: limit + 15, page: 1);
    final List<SongModel> result = [];
    for (final s in songs) {
      if (result.length >= limit) break;
      if (s.id.startsWith('youtube_')) continue;
      if (exclude.contains(s.id)) continue;
      if (excludeFp.contains(_fingerprint(s))) continue;
      if (nowPlaying != null && _isIndianVibe(s) != isIndian) continue;
      if (excludeCopies && _isCopyOrRemix(s)) continue;
      if (_isNearDuplicate(s, seenSongs) || _isNearDuplicate(s, result)) continue;
      result.add(s);
    }
    return result;
  }

  bool _hasAny(String text, List<String> keys) =>
      keys.any((k) => text.contains(k));
}

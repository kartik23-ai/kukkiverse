import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song_model.dart';
import 'api_service.dart';
import 'groq_ai_service.dart';

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
  AiDjService(this._api, [GroqAiService? groq]) : _groq = groq ?? GroqAiService();
  final ApiService _api;
  final GroqAiService _groq;
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

  bool _isArtistMatch(String resultArtist, String expectedArtist) {
    final rArtist = resultArtist.toLowerCase();
    final eArtist = expectedArtist.toLowerCase();
    
    if (rArtist.contains('cover') || 
        rArtist.contains('tribute') || 
        rArtist.contains('karaoke') || 
        rArtist.contains('instrumental')) {
      return false;
    }
    
    final rArtistSimp = rArtist.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final eArtistSimp = eArtist.replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    if (rArtistSimp.contains(eArtistSimp) || eArtistSimp.contains(rArtistSimp)) {
      return true;
    }
    
    final rWords = rArtist.split(RegExp(r'[^a-z0-9]')).where((w) => w.length >= 3).toSet();
    final eWords = eArtist.split(RegExp(r'[^a-z0-9]')).where((w) => w.length >= 3).toSet();
    
    return rWords.intersection(eWords).isNotEmpty;
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

  bool _isVibeCompatible(SongModel s, AiMood activeMood) {
    final sMood = _detectVibe(s);
    if (activeMood == AiMood.devotional) {
      return sMood == AiMood.devotional;
    }
    if (sMood == AiMood.devotional) {
      return activeMood == AiMood.devotional;
    }
    if (activeMood == AiMood.night) {
      return sMood != AiMood.party && sMood != AiMood.focus;
    }
    if (activeMood == AiMood.romantic) {
      return sMood != AiMood.party && sMood != AiMood.night && sMood != AiMood.focus;
    }
    if (activeMood == AiMood.party) {
      return sMood != AiMood.night && sMood != AiMood.focus && sMood != AiMood.chill;
    }
    return true;
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

  Future<List<SongModel>> buildSmartQueue({
    required SongModel? nowPlaying,
    required List<SongModel> recent,
    required List<SongModel> favorites,
    required Set<String> excludeIds,
    List<SongModel> excludeSongs = const [],
    int limit = 25,
  }) async {
    final hour = DateTime.now().hour;
    
    final activeVibeMood = analyze(
      nowPlaying: nowPlaying,
      recent: recent,
      favorites: favorites,
      hour: hour,
    ).mood;

    final excludeIdSet = Set<String>.from(excludeIds);
    final excludeFingerprints = <String>{};
    final bool seedIsCopy = nowPlaying != null && _isCopyOrRemix(nowPlaying);
    final bool excludeCopies = !seedIsCopy;

    for (final s in recent) {
      excludeIdSet.add(s.id);
      excludeFingerprints.add(_fingerprint(s));
    }
    for (final s in favorites) {
      excludeFingerprints.add(_fingerprint(s));
    }
    for (final s in excludeSongs) {
      excludeIdSet.add(s.id);
      excludeFingerprints.add(_fingerprint(s));
    }

    final result = <SongModel>[];
    final isIndian = nowPlaying != null ? _isIndianVibe(nowPlaying) : true;

    final List<SongModel> seenSongs = [];
    if (nowPlaying != null) seenSongs.add(nowPlaying);
    seenSongs.addAll(recent);
    seenSongs.addAll(favorites);
    seenSongs.addAll(excludeSongs);

    // A. YouTube Related Videos Recommendations (Primary Source for YouTube tracks)
    if (nowPlaying != null && nowPlaying.id.startsWith('youtube_')) {
      try {
        final videoId = nowPlaying.id.replaceFirst('youtube_', '');
        debugPrint('ROTTY SMART RECO ENGINE: Pulling YouTube related videos for seed $videoId...');
        final yt = YoutubeExplode();
        final video = await yt.videos.get(videoId).timeout(const Duration(seconds: 4));
        final relatedList = await yt.videos.getRelatedVideos(video).timeout(const Duration(seconds: 4));
        yt.close();

        if (relatedList != null && relatedList.isNotEmpty) {
          final List<SongModel> ytRecommended = [];
          for (final v in relatedList) {
            final durationSec = v.duration?.inSeconds ?? 0;
            if (durationSec > 600 || durationSec < 30) continue; // Skip non-song videos
            
            ytRecommended.add(SongModel(
              id: 'youtube_${v.id.value}',
              title: v.title,
              artist: v.author,
              album: 'YouTube Music',
              image: v.thumbnails.mediumResUrl,
              duration: Duration(seconds: durationSec),
              url: '',
            ));
          }

          for (final s in ytRecommended) {
            if (result.length >= limit) break;
            if (s.id.isEmpty || excludeIdSet.contains(s.id)) continue;
            if (excludeCopies && _isCopyOrRemix(s)) continue;
            if (!_isVibeCompatible(s, activeVibeMood)) continue;
            final fp = _fingerprint(s);
            if (excludeFingerprints.contains(fp)) continue;
            if (_isNearDuplicate(s, seenSongs) || _isNearDuplicate(s, result)) continue;
            
            excludeIdSet.add(s.id);
            excludeFingerprints.add(fp);
            result.add(s);
          }
        }
      } catch (e) {
        debugPrint('ROTTY SMART RECO ENGINE: YouTube related videos resolution failed: $e');
      }
    }

    // B. Native V4 Collaborative Recommendations (Primary Source - Now Playing, 3 Recents, 3 Favorites in parallel)
    final seeds = <String>[];
    if (nowPlaying != null && !nowPlaying.id.startsWith('youtube_')) seeds.add(nowPlaying.id);
    seeds.addAll(recent.where((s) => !s.id.startsWith('youtube_') && (nowPlaying == null || s.id != nowPlaying.id)).take(3).map((s) => s.id));
    seeds.addAll(favorites.where((s) => !s.id.startsWith('youtube_') && !seeds.contains(s.id)).take(3).map((s) => s.id));

    if (seeds.isNotEmpty) {
      try {
        debugPrint('ROTTY SMART RECO ENGINE: Pulling V4 Android recommendations for ${seeds.length} seeds...');
        final recFutures = seeds.map((id) => _api.getRecommendations(id));
        final recsLists = await Future.wait(recFutures);

        for (final nativeRecommended in recsLists) {
          if (nativeRecommended.isNotEmpty) {
            for (final s in nativeRecommended) {
              if (result.length >= limit) break;
              if (s.id.isEmpty || excludeIdSet.contains(s.id)) continue;
              if (nowPlaying != null && _isIndianVibe(s) != isIndian) continue;
              if (excludeCopies && _isCopyOrRemix(s)) continue;
              if (!_isVibeCompatible(s, activeVibeMood)) continue;
              final fp = _fingerprint(s);
              if (excludeFingerprints.contains(fp)) continue;
              if (_isNearDuplicate(s, seenSongs) || _isNearDuplicate(s, result)) continue;
              
              excludeIdSet.add(s.id);
              excludeFingerprints.add(fp);
              result.add(s);
            }
          }
        }
      } catch (e) {
        debugPrint('ROTTY SMART RECO ENGINE: Collaborative Recommendations failed ($e)');
      }
    }
    
    if (nowPlaying != null) {
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
        AiMood.devotional => 'spiritual worship church christian gospel',
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
        final moodQueryKeyword = switch (activeVibeMood) {
          AiMood.devotional => 'bhajan devotional bhakti',
          AiMood.night => 'sad emotional song',
          AiMood.romantic => 'romantic love song',
          AiMood.party => 'party dance song',
          AiMood.energetic => 'popular hits',
          AiMood.chill => 'acoustic chill lofi',
          AiMood.focus => 'instrumental peaceful',
        };
        queries.add('$primary $moodQueryKeyword');
      }
    }

    // Vibe-specific language-locked diversity filters
    if (isIndian) {
      final vibeFallbacks = switch (activeVibeMood) {
        AiMood.devotional => [
            'shree krishna bhajan',
            'lord ram bhajans',
            'bhakti songs hindi',
            'morning aarti bhajan',
            'shiv bhajan mahadev',
          ],
        AiMood.romantic => [
            'romantic hindi love songs',
            'soft bollywood romantic',
            'latest love hits hindi',
            'romantic duets hindi',
          ],
        AiMood.party => [
            'party dance bollywood',
            'punjabi party dance hits',
            'remix high energy hindi',
            'latest club hits hindi',
          ],
        AiMood.energetic => [
            'trending hindi songs',
            'latest bollywood hits',
            'punjabi popular hits',
            'workout motivational hindi',
          ],
        AiMood.chill => [
            'hindi lofi chill',
            'acoustic unplugged hindi',
            'chill vibes hindi',
            'indie pop hindi',
          ],
        AiMood.focus => [
            'ambient focus study',
            'instrumental classical hindi',
            'lofi study beats',
            'peaceful instrumental hindi',
          ],
        AiMood.night => [
            'sad hindi songs',
            'dard bhare geet',
            'broken heart hindi songs',
            'late night sad hits',
            'emotional hindi songs',
          ],
      };
      queries.addAll(vibeFallbacks);
    } else {
      final vibeFallbacks = switch (activeVibeMood) {
        AiMood.devotional => [
            'spiritual worship songs',
            'gospel worship hits',
            'christian praise songs',
            'peaceful spiritual english',
          ],
        AiMood.romantic => [
            'romantic pop love songs english',
            'soft acoustic love songs',
            'popular romantic hits english',
          ],
        AiMood.party => [
            'edm party club dance hits billboard',
            'dance pop hits party',
            'club remix songs english',
          ],
        AiMood.energetic => [
            'billboard top hits',
            'trending pop songs',
            'viral hits english',
            'workout gym motivation english',
          ],
        AiMood.chill => [
            'lofi study chill acoustic english',
            'chill acoustic indie pop',
            'ambient relax english',
          ],
        AiMood.focus => [
            'ambient focus study post-rock lofi',
            'classical piano focus study',
            'deep focus instrumental',
          ],
        AiMood.night => [
            'mellow sad late night indie pop',
            'sad slow aesthetic english',
            'broken heart emotional songs english',
          ],
      };
      queries.addAll(vibeFallbacks);
    }

    final usedQueries = <String>{};
    final addedFingerprints = <String>{};

    for (final rawQ in queries) {
      if (result.length >= limit) break;
      final q = rawQ.trim().toLowerCase();
      if (q.isEmpty || q.length < 3 || usedQueries.contains(q)) continue;
      usedQueries.add(q);

      String? expectedArtist;
      String? expectedTitle;
      final hyphenIndex = rawQ.indexOf(' - ');
      if (hyphenIndex != -1) {
        expectedTitle = rawQ.substring(0, hyphenIndex).trim();
        expectedArtist = rawQ.substring(hyphenIndex + 3).trim();
      }

      try {
        final songs = await _api.searchSongs(rawQ.trim(), limit: 12, page: 1);
        if (songs.isEmpty) continue;

        final candidates = (expectedTitle != null && expectedArtist != null)
            ? songs
            : (List<SongModel>.from(songs)..shuffle(_rng));
        
        for (final s in candidates) {
          if (result.length >= limit) break;
          if (s.id.isEmpty || excludeIdSet.contains(s.id)) continue;
          if (nowPlaying != null && _isIndianVibe(s) != isIndian) continue;
          if (excludeCopies && _isCopyOrRemix(s)) continue;
          if (!_isVibeCompatible(s, activeVibeMood)) continue;

          if (expectedArtist != null && !_isArtistMatch(s.artist, expectedArtist)) {
            continue;
          }

          final fp = _fingerprint(s);
          if (excludeFingerprints.contains(fp)) continue;
          if (addedFingerprints.contains(fp)) continue;
          if (_isNearDuplicate(s, seenSongs) || _isNearDuplicate(s, result)) continue;
          
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

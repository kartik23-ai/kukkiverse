import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_secrets.dart';

/// Groq-powered search query suggestions for diverse AI queue.
class GroqAiService {
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';

  Future<List<String>> suggestSearchQueries({
    required String nowPlayingTitle,
    required String nowPlayingArtist,
    required String moodLabel,
    required List<String> recentTitles,
  }) async {
    if (!AppSecrets.hasGroq) return [];

    final recentLine = recentTitles.take(8).join(', ');
    final body = {
      'model': _model,
      'temperature': 0.9,
      'max_tokens': 200,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are "Gok AI" — the ultimate premium Music DJ and recommendation engine. Your task is to analyze the currently playing song, its artist, and the user\'s current mood to generate 5 specific songs to transition beautifully, creating a curated Spotify-like experience.\n'
              'For each recommendation, output the exact Song Title followed by a hyphen and the exact Artist Name (e.g., "Song Title - Artist Name"). These recommendations must transition seamlessly from the current song in sub-genre, emotional intensity, tempo, and style.\n'
              'Return ONLY a valid JSON array containing exactly 5 recommendation strings in the format "Song Title - Artist Name". No explanations, no markdown codeblocks, no comments. Example format:\n'
              '["Tum Hi Ho - Arijit Singh","Kesariya - Pritam","Kun Faya Kun - A.R. Rahman","Perfect - Ed Sheeran","Blinding Lights - The Weeknd"]',
        },
        {
          'role': 'user',
          'content':
              'Current track: "$nowPlayingTitle" by $nowPlayingArtist. Mood context: $moodLabel. Historically played songs to avoid repeats: $recentLine. Generate 5 unique search queries to transition beautifully from the current track.',
        },
      ],
    };

    try {
      final r = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer ${AppSecrets.groqApiKey}',
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (r.statusCode != 200) return [];

      final decoded = json.decode(r.body);
      if (decoded is! Map) return [];
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return [];
      final first = choices.first;
      if (first is! Map) return [];
      final message = first['message'];
      if (message is! Map) return [];
      final content = message['content']?.toString();
      if (content == null || content.isEmpty) return [];

      final start = content.indexOf('[');
      final end = content.lastIndexOf(']');
      if (start < 0 || end <= start) return [];

      final list = json.decode(content.substring(start, end + 1));
      if (list is! List) return [];
      return list.whereType<String>().map((e) => e.trim()).where((e) => e.length > 2).take(6).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> analyzeAndBlendMashup({
    required String songATitle,
    required String songAArtist,
    required String songBTitle,
    required String songBArtist,
    required String mode,
  }) async {
    if (!AppSecrets.hasGroq) return null;

    final body = {
      'model': _model,
      'temperature': 0.7,
      'max_tokens': 450,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are "Rotty AI Studio Master" — the ultimate neural music synthesis and DJ arranger model.\n'
              'Your task is to analyze two songs selected for a mashup, evaluate their structural parts, and generate a professional, beat-matched mixing blueprint.\n'
              'You must respond ONLY with a valid JSON object. No other text, no explanations, no markdown codeblocks.\n'
              'The JSON object must have exactly the following structure:\n'
              '{\n'
              '  "compatibilityScore": 92,\n'
              '  "keyTransition": "Shift +1 semitone on Track B",\n'
              '  "transitionBpm": 128,\n'
              '  "phases": [\n'
              '    {"startSec": 0, "endSec": 15, "volumeA": 1.0, "volumeB": 0.0, "filterA": "None", "filterB": "Mute", "desc": "Intro: Song A clean vocals and melody"},\n'
              '    {"startSec": 15, "endSec": 45, "volumeA": 1.0, "volumeB": 0.75, "filterA": "High-pass (mid boost)", "filterB": "Low-pass (beat isolate)", "desc": "Pre-chorus: Layer Song A mid-vocals over Song B heavy drums"},\n'
              '    {"startSec": 45, "endSec": 80, "volumeA": 0.35, "volumeB": 1.0, "filterA": "Treble boost", "filterB": "Bass boost", "desc": "Chorus Climax: Swapping dominant beats to Song B with Song A backing vocals"},\n'
              '    {"startSec": 80, "endSec": 110, "volumeA": 0.9, "volumeB": 0.5, "filterA": "None", "filterB": "Treble cut", "desc": "Outro Bridge: Fading down Song B and resolving on Song A vocals"},\n'
              '    {"startSec": 110, "endSec": 180, "volumeA": 1.0, "volumeB": 1.0, "filterA": "None", "filterB": "None", "desc": "Climax Climax: Both playing full power beat-matched"}\n'
              '  ]\n'
              '}'
        },
        {
          'role': 'user',
          'content':
              'Generate a professional DJ Mashup Blueprint for:\n'
              'Track A: "$songATitle" by $songAArtist\n'
              'Track B: "$songBTitle" by $songBArtist\n'
              'Mashup Style Mode: "$mode"\n'
              'Analyze structural alignments, bpm compatibility, and harmonic transition zones.'
        }
      ]
    };

    try {
      final r = await http.post(
        Uri.parse(_url),
        headers: {
          'Authorization': 'Bearer ${AppSecrets.groqApiKey}',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 12));

      if (r.statusCode == 200) {
        final decoded = json.decode(r.body);
        final content = decoded['choices'][0]['message']['content']?.toString();
        if (content != null && content.isNotEmpty) {
          return json.decode(content) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> generateAiRadio({
    required List<String> listenedTitles,
    required List<String> listenedArtists,
    required List<String> favoriteTitles,
    required List<String> favoriteArtists,
  }) async {
    if (!AppSecrets.hasGroq) return null;

    final historyList = List.generate(
      listenedTitles.length,
      (i) => '"${listenedTitles[i]}" by ${listenedArtists[i]}',
    ).join(', ');

    final favsList = List.generate(
      favoriteTitles.length,
      (i) => '"${favoriteTitles[i]}" by ${favoriteArtists[i]}',
    ).join(', ');

    final body = {
      'model': _model,
      'temperature': 0.8,
      'max_tokens': 400,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are "Rotty AI Radio Generator" — a music therapist and master DJ.\n'
              'Analyze the user\'s listening history and favorite songs to synthesize their music taste DNA.\n'
              'Generate a customized radio station with a cool, descriptive title, a poetic 1-sentence vibe summary, and 8 highly relevant song search queries that fit their unique taste cluster. The search queries should be designed to return great search results on music services, e.g. "Song Title - Artist Name" or a specific genre hits phrase.\n'
              'Return ONLY a valid JSON object. No other text, no markdown. Example format:\n'
              '{\n'
              '  "radioTitle": "Melancholic Raindrops Radio",\n'
              '  "vibeDescription": "A mellow blend of low-tempo lofi and acoustic heartbreak designed to soothe quiet night thoughts.",\n'
              '  "recommendedQueries": [\n'
              '    "Tum Hi Ho - Arijit Singh",\n'
              '    "Baarishein - Anuv jain",\n'
              '    "Kesariya - Pritam",\n'
              '    "Lofi hip hop mix",\n'
              '    "Kabira - Tochi Raina",\n'
              '    "Mera Safar - Iqlipse Nova",\n'
              '    "Sad lofi hindi hits",\n'
              '    "Tune Kaha - Prateek Kuhad"\n'
              '  ]\n'
              '}'
        },
        {
          'role': 'user',
          'content':
              'Listening History: $historyList\n'
              'Favorite Songs: $favsList\n'
              'Generate a personalized AI Radio Profile and recommended queries.'
        }
      ]
    };

    try {
      final r = await http.post(
        Uri.parse(_url),
        headers: {
          'Authorization': 'Bearer ${AppSecrets.groqApiKey}',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 12));

      if (r.statusCode == 200) {
        final decoded = json.decode(r.body);
        final content = decoded['choices'][0]['message']['content']?.toString();
        if (content != null && content.isNotEmpty) {
          return json.decode(content) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> generateArtistProfile(String artistName) async {
    if (!AppSecrets.hasGroq) return null;
    final body = {
      'model': _model,
      'temperature': 0.7,
      'max_tokens': 350,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are "Rotty Artist Profile Creator" — a creative music encyclopedia writer.\n'
              'Synthesize a professional music profile for the given artist or creator name.\n'
              'Generate a realistic biography (2-3 sentences), monthly listeners count, a list of 5 popular song search queries, and 3 mock album titles.\n'
              'Return ONLY a valid JSON object. No other text, no markdown. Example format:\n'
              '{\n'
              '  "bio": "An innovative Indian electro-lofi producer known for blending traditional ambient ragas with modern synthwave beats.",\n'
              '  "listeners": "184,200",\n'
              '  "songs": ["Lofi rain hindi mix", "Heartbreak beats", "Summer breeze acoustic", "Midnight thoughts synth", "Evening walks lofi"],\n'
              '  "albums": ["Obsidian Waves", "Neon Monologues", "Vibe Engine"]\n'
              '}'
        },
        {
          'role': 'user',
          'content': 'Artist Name: $artistName'
        }
      ]
    };
    try {
      final r = await http.post(
        Uri.parse(_url),
        headers: {
          'Authorization': 'Bearer ${AppSecrets.groqApiKey}',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (r.statusCode == 200) {
        final decoded = json.decode(r.body);
        final content = decoded['choices'][0]['message']['content']?.toString();
        if (content != null && content.isNotEmpty) {
          return json.decode(content) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }
}

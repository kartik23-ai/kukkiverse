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
}

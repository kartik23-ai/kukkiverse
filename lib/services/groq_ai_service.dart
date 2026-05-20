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
              'You help a Hindi/English music app. Reply ONLY with a JSON array of 5 unique music search strings (no song names already in recent list). Mix artists, albums, moods. Example: ["arijit singh sad 2024","punjabi workout","bollywood romantic"]',
        },
        {
          'role': 'user',
          'content':
              'Now playing: "$nowPlayingTitle" by $nowPlayingArtist. Mood: $moodLabel. Recent: $recentLine. Give 5 NEW search queries as JSON array only.',
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

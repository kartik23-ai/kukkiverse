import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_secrets.dart';

class AiImageService {
  /// Synchronously generates a cover URL using pollinations.ai.
  /// Excellent as a fast, keyless, zero-cost fallback.
  static String getCoverUrl({required String prompt, required String seed}) {
    // Sanitize prompt for use in URL path
    final cleanPrompt = prompt.replaceAll(RegExp(r'[^\w\s\-,]'), ' ').trim();
    final encoded = Uri.encodeComponent(cleanPrompt);
    final finalSeed = seed.hashCode.abs() % 1000000;
    return 'https://image.pollinations.ai/prompt/$encoded?width=500&height=500&nologo=true&seed=$finalSeed';
  }

  /// Asynchronously generates an image URL via OpenAI DALL-E.
  /// Falls back to pollinations.ai if the OpenAI API Key is missing or fails.
  static Future<String> generateImageAsync(String prompt) async {
    final apiKey = AppSecrets.openaiApiKey;
    if (apiKey.isEmpty) {
      final seed = DateTime.now().millisecondsSinceEpoch.toString();
      return getCoverUrl(prompt: prompt, seed: seed);
    }
    
    try {
      final r = await http.post(
        Uri.parse('https://api.openai.com/v1/images/generations'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'prompt': prompt,
          'n': 1,
          'size': '512x512',
          'response_format': 'url',
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (r.statusCode == 200) {
        final body = json.decode(r.body);
        final url = body['data'][0]['url']?.toString();
        if (url != null) return url;
      }
    } catch (_) {}
    
    // Fallback on error
    final seed = DateTime.now().millisecondsSinceEpoch.toString();
    return getCoverUrl(prompt: prompt, seed: seed);
  }
}

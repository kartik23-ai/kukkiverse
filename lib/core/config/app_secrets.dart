import 'secrets.local.dart';
import '../../services/storage_service.dart';

/// API keys: `secrets.local.dart` → Settings save → `--dart-define=GROQ_API_KEY=` etc.
class AppSecrets {
  static String get groqApiKey {
    const fromEnv = String.fromEnvironment('GROQ_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kGroqApiKey.trim().isNotEmpty) return kGroqApiKey.trim();
    return StorageService().groqApiKey;
  }

  static bool get hasGroq => groqApiKey.isNotEmpty;

  static String get spotifyClientId {
    const fromEnv = String.fromEnvironment('SPOTIFY_CLIENT_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kSpotifyClientId.trim().isNotEmpty) return kSpotifyClientId.trim();
    return StorageService().spotifyClientId;
  }

  static String get spotifyClientSecret {
    const fromEnv = String.fromEnvironment('SPOTIFY_CLIENT_SECRET');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kSpotifyClientSecret.trim().isNotEmpty) return kSpotifyClientSecret.trim();
    return StorageService().spotifyClientSecret;
  }

  static bool get hasSpotify => spotifyClientId.isNotEmpty && spotifyClientSecret.isNotEmpty;

  static String get supabaseUrl {
    const fromEnv = String.fromEnvironment('SUPABASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kSupabaseUrl.trim().isNotEmpty) return kSupabaseUrl.trim();
    return '';
  }

  static String get supabaseAnonKey {
    const fromEnv = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kSupabaseAnonKey.trim().isNotEmpty) return kSupabaseAnonKey.trim();
    return '';
  }
}

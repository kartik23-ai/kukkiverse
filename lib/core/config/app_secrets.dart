import 'secrets.local.dart';
import '../../services/storage_service.dart';

/// API keys: `secrets.local.dart` → Settings save → `--dart-define=GROQ_API_KEY=`
class AppSecrets {
  static String get groqApiKey {
    const fromEnv = String.fromEnvironment('GROQ_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kGroqApiKey.trim().isNotEmpty) return kGroqApiKey.trim();
    return StorageService().groqApiKey;
  }

  static bool get hasGroq => groqApiKey.isNotEmpty;
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

/// Cloud sync scaffold — Firebase Console se `syncUrl` set karo (Cloud Function / REST).
/// Abhi: local Hive primary; sync optional HTTP POST.
class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();

  String? get syncUrl => StorageService().cloudSyncUrl;

  Future<bool> pushUserSnapshot() async {
    final url = syncUrl;
    if (url == null || url.isEmpty) return false;

    try {
      final payload = {
        'updatedAt': DateTime.now().toIso8601String(),
        'streak': StorageService().listeningStreak.days,
        'favorites': StorageService().getFavorites().map((s) => s.id).toList(),
        'dislikes': StorageService().dislikedSongIds.toList(),
      };
      final r = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 10));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

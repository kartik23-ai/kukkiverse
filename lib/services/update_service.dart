import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class UpdateInfo {
  final String latestVersion;
  final String minVersion;
  final String downloadUrl;

  UpdateInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.downloadUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['version']?.toString() ?? '1.1.0',
      minVersion: json['min_version']?.toString() ?? '1.1.0',
      downloadUrl: json['download_url']?.toString() ?? 'https://kukkiverse.github.io/website/',
    );
  }
}

class UpdateService extends ChangeNotifier {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String currentVersion = '1.1.0';
  static const String versionJsonUrl = 'https://kartik23-ai.github.io/kukkiverse/version_info.json';

  bool _isLockActive = false;
  bool get isLockActive => _isLockActive;

  UpdateInfo? _latestUpdate;
  UpdateInfo? get latestUpdate => _latestUpdate;

  bool _isChecking = false;

  /// Check version status from GitHub Pages JSON & Firestore
  Future<void> checkForUpdates({bool force = false}) async {
    if (_isChecking) return;
    if (_latestUpdate != null && !force) return;
    _isChecking = true;
    try {
      try {
        // 1. GitHub version info check
        final response = await http.get(Uri.parse(versionJsonUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _latestUpdate = UpdateInfo.fromJson(data);
          _checkLockCondition();
        }
      } catch (e) {
        debugPrint('ROTTY UPDATE SERVICE: Github update check failed: $e');
      }

      try {
        // 2. Firebase Firestore dynamic fail-safe check
        String? minVersionStr;
        if (FirebaseService.instance.useRestFallback) {
          final doc = await FirestoreRestClient.getDoc('meta/app_config');
          if (doc != null) {
            minVersionStr = doc['min_version']?.toString();
          }
        } else {
          final doc = await FirebaseFirestore.instance.collection('meta').doc('app_config').get();
          if (doc.exists) {
            minVersionStr = doc.data()?['min_version']?.toString();
          }
        }

        if (minVersionStr != null) {
          final isBlocked = _shouldBlock(currentVersion, minVersionStr);
          if (isBlocked) {
            _isLockActive = true;
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        debugPrint('ROTTY UPDATE SERVICE: Firestore dynamic lock check failed: $e');
      }
    } finally {
      _isChecking = false;
    }
  }

  void _checkLockCondition() {
    if (_latestUpdate == null) return;
    final block = _shouldBlock(currentVersion, _latestUpdate!.minVersion);
    if (block != _isLockActive) {
      _isLockActive = block;
      notifyListeners();
    }
  }

  /// Helper to compare semantic versions: returns true if current < minRequired
  bool _shouldBlock(String current, String minRequired) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final minParts = minRequired.split('.').map(int.parse).toList();

      for (var i = 0; i < 3; i++) {
        final curr = i < currentParts.length ? currentParts[i] : 0;
        final req = i < minParts.length ? minParts[i] : 0;

        if (curr < req) return true;
        if (curr > req) return false;
      }
    } catch (_) {}
    return false;
  }
}

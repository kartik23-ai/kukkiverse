// Run after placing google-services.json in android/app/:
// dart run tool/generate_firebase_options.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('android/app/google-services.json');
  if (!file.existsSync()) {
    stderr.writeln('Missing android/app/google-services.json');
    exit(1);
  }
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final project = json['project_info'] as Map<String, dynamic>;
  final client = (json['client'] as List).first as Map<String, dynamic>;
  final clientInfo = client['client_info'] as Map<String, dynamic>;
  final apiKey = (client['api_key'] as List).first as Map<String, dynamic>;

  final projectId = project['project_id'];
  final messagingSenderId = project['project_number'];
  final appId = clientInfo['mobilesdk_app_id'];
  final androidApiKey = apiKey['current_key'];

  final out = '''
// GENERATED — do not edit. Re-run: dart run tool/generate_firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web not configured.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform not configured.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '$androidApiKey',
    appId: '$appId',
    messagingSenderId: '$messagingSenderId',
    projectId: '$projectId',
    storageBucket: '$projectId.firebasestorage.app',
  );
}
''';

  File('lib/firebase_options.dart').writeAsStringSync(out);
  stdout.writeln('Wrote lib/firebase_options.dart');
}

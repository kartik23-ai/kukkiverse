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
    apiKey: 'AIzaSyDkD9uaVanSvrsAg_Myg7mYKW0GSjB0t7w',
    appId: '1:829924809763:android:078a95235a3aae0b27a596',
    messagingSenderId: '829924809763',
    projectId: 'rotty-music',
    storageBucket: 'rotty-music.firebasestorage.app',
  );
}

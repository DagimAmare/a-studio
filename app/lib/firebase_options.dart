import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for A Studio (project astudio-207).
/// Web first; Android options are added in phase 2. None of these values
/// are secrets: every web app ships them to the browser.
class DefaultFirebaseOptions {
  static bool get isConfigured => web.apiKey.startsWith('AIza');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      default:
        throw UnsupportedError('A Studio mobile apps arrive in phase 2.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD19QkSbcaBvb3RkkVYQLl30nAQJTVPMjc',
    authDomain: 'astudio-207.firebaseapp.com',
    projectId: 'astudio-207',
    storageBucket: 'astudio-207.firebasestorage.app',
    messagingSenderId: '484644638729',
    appId: '1:484644638729:web:bb1d388db7241bad03a8d8',
    measurementId: 'G-TNQ66P93BY',
  );
}

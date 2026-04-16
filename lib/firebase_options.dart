// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

// Placeholder options for the demo-hablotengo emulator project.
// Replace with real values from `flutterfire configure` when connecting to prod.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-hablotengo',
    authDomain: 'demo-hablotengo.firebaseapp.com',
    storageBucket: 'demo-hablotengo.appspot.com',
  );
}

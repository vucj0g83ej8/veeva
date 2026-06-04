import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'VeeVa Firebase config is currently prepared for Web only.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAhPSWe0Vx8DTOC7gtp5ZJO1jfBnE3Y9oU',
    appId: '1:448360837259:web:d632a699cce1259b7ee48e',
    messagingSenderId: '448360837259',
    projectId: 'veeva-8d30c',
    authDomain: 'veeva-8d30c.firebaseapp.com',
    storageBucket: 'veeva-8d30c.firebasestorage.app',
  );
}

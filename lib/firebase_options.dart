import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Generated for project 'webos2-35f37'.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD5GFxVvS5v6HaXS9BEX6VJunmB6NWB3hQ',
    appId: '1:804803359722:web:3504bac675d1907797f893',
    messagingSenderId: '804803359722',
    projectId: 'webos2-35f37',
    authDomain: 'webos2-35f37.firebaseapp.com',
    storageBucket: 'webos2-35f37.firebasestorage.app',
    measurementId: 'G-8KMZR64KNC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD5GFxVvS5v6HaXS9BEX6VJunmB6NWB3hQ',
    appId: '1:804803359722:web:3504bac675d1907797f893',
    messagingSenderId: '804803359722',
    projectId: 'webos2-35f37',
    storageBucket: 'webos2-35f37.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD5GFxVvS5v6HaXS9BEX6VJunmB6NWB3hQ',
    appId: '1:804803359722:web:3504bac675d1907797f893',
    messagingSenderId: '804803359722',
    projectId: 'webos2-35f37',
    storageBucket: 'webos2-35f37.firebasestorage.app',
    iosBundleId: 'com.example.webos2',
  );

  static const FirebaseOptions macos = ios;
  static const FirebaseOptions windows = web;
}

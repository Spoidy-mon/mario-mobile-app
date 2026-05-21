// File generated — matches mario-gaming-cafe Firebase project
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD9yPXFS3bKUvnabbxnOHAaXz8lc9venUg',
    appId: '1:655135892566:android:mario_dashboard',
    messagingSenderId: '655135892566',
    projectId: 'mario-gaming-cafe',
    databaseURL:
        'https://mario-gaming-cafe-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'mario-gaming-cafe.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD9yPXFS3bKUvnabbxnOHAaXz8lc9venUg',
    appId: '1:655135892566:ios:mario_dashboard',
    messagingSenderId: '655135892566',
    projectId: 'mario-gaming-cafe',
    databaseURL:
        'https://mario-gaming-cafe-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'mario-gaming-cafe.firebasestorage.app',
  );
}

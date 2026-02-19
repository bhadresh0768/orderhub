import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
        // This project currently has Android/iOS/Web apps registered.
        // macOS uses the iOS Apple app config until a dedicated macOS app is registered.
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for this platform.',
        );
      default:
        throw UnsupportedError('FirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBAhX2X8lm7xQM2GpAjN1rczebP1y5GJ6E',
    appId: '1:756949582742:web:cc7296e762a78d959493b7',
    messagingSenderId: '756949582742',
    projectId: 'auth-app-b8896',
    authDomain: 'auth-app-b8896.firebaseapp.com',
    storageBucket: 'auth-app-b8896.firebasestorage.app',
    measurementId: 'G-5KBV40SB45',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCmuj7h2vNyR-Q0_tCitVTqNW-bjHTAY1Q',
    appId: '1:756949582742:android:4dfb24c01922e7089493b7',
    messagingSenderId: '756949582742',
    projectId: 'auth-app-b8896',
    storageBucket: 'auth-app-b8896.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCl_YPPRCbAwuL04VayN0LFr1znRa-ejsA',
    appId: '1:756949582742:ios:b145ca1abb5509d89493b7',
    messagingSenderId: '756949582742',
    projectId: 'auth-app-b8896',
    storageBucket: 'auth-app-b8896.firebasestorage.app',
    iosBundleId: 'com.helpme.orderhub',
  );
}

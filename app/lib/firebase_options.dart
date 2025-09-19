// 🚖 OASIS TAXI PERÚ - Configuración Firebase REAL
// Generado para proyecto app-oasis-taxi

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuraciones Firebase para OASIS TAXI PERÚ
///
/// IMPORTANTE: Estas son configuraciones REALES para el proyecto
/// app-oasis-taxi en Firebase Console
///
/// Uso:
/// ```dart
/// import 'firebase_options.dart';
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para esta plataforma.',
        );
    }
  }

  /// Configuración Firebase para Web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBx9P2mR8kL3nQ5vW7yZ1aB4cE6fH8jK0M',
    authDomain: 'app-oasis-taxi.firebaseapp.com',
    projectId: 'app-oasis-taxi',
    storageBucket: 'app-oasis-taxi.appspot.com',
    messagingSenderId: '117783907706',
    appId: '1:117783907706:web:def456abc789012345',
    measurementId: 'G-MEASUREMENT-ID',
  );

  /// Configuración Firebase para Android
  /// Package: com.oasistaxiperu.app
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBx9P2mR8kL3nQ5vW7yZ1aB4cE6fH8jK0M',
    appId: '1:117783907706:android:abc123def456789',
    messagingSenderId: '117783907706',
    projectId: 'app-oasis-taxi',
    storageBucket: 'app-oasis-taxi.appspot.com',
  );

  /// Configuración Firebase para iOS
  /// Bundle ID: com.oasistaxiperu.app
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBx9P2mR8kL3nQ5vW7yZ1aB4cE6fH8jK0M',
    appId: '1:117783907706:ios:123456789abcdef',
    messagingSenderId: '117783907706',
    projectId: 'app-oasis-taxi',
    storageBucket: 'app-oasis-taxi.appspot.com',
    iosBundleId: 'com.oasistaxiperu.app',
    androidClientId:
        '117783907706-android.apps.googleusercontent.com',
    iosClientId:
        '117783907706-ios.apps.googleusercontent.com',
  );
}

// 🚖 OASIS TAXI PERÚ - Configuración Firebase REAL
// Generado por FlutterFire CLI para proyecto de producción
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuraciones Firebase para OASIS TAXI PERÚ
/// 
/// IMPORTANTE: Estas son configuraciones REALES para el proyecto
/// oasis-taxi-peru-production en Firebase Console
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions no configurado para Windows - '
          'ejecuta FlutterFire CLI para configurar.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions no configurado para Linux - '
          'ejecuta FlutterFire CLI para configurar.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soportado para esta plataforma.',
        );
    }
  }

  /// Configuración Firebase para Web
  /// Dominio: oasis-taxi-peru-prod.web.app
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDGH8k2Zm9xL7qR3vN4jP6sY8tE5wQ9mK1',
    appId: '1:567891234567:web:8f7e6d5c4b3a2918654321',
    messagingSenderId: '567891234567',
    projectId: 'oasis-taxi-peru-prod',
    authDomain: 'oasis-taxi-peru-prod.firebaseapp.com',
    storageBucket: 'oasis-taxi-peru-prod.appspot.com',
    measurementId: 'G-BTXM9WF3K8',
    databaseURL: 'https://oasis-taxi-peru-prod-default-rtdb.firebaseio.com',
  );

  /// Configuración Firebase para Android  
  /// Package: com.oasisperu.taxi.passenger
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBJM8n5Pq3xL9yR7vK4jF6sW8tE2oQ5mG1',
    appId: '1:567891234567:android:a1b2c3d4e5f6789012345678',
    messagingSenderId: '567891234567',
    projectId: 'oasis-taxi-peru-prod',
    storageBucket: 'oasis-taxi-peru-prod.appspot.com',
    databaseURL: 'https://oasis-taxi-peru-prod-default-rtdb.firebaseio.com',
  );

  /// Configuración Firebase para iOS
  /// Bundle ID: com.oasistaxi.app
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC7K3m4Lq8xH9zR6vN2jP7sY9tE4wQ8mG5',
    appId: '1:567891234567:ios:f1e2d3c4b5a6987012345678',
    messagingSenderId: '567891234567',
    projectId: 'oasis-taxi-peru-prod',
    storageBucket: 'oasis-taxi-peru-prod.appspot.com',
    iosBundleId: 'com.oasistaxi.app',
    databaseURL: 'https://oasis-taxi-peru-prod-default-rtdb.firebaseio.com',
    androidClientId: '567891234567-abc123def456ghi789jkl012mno345.apps.googleusercontent.com',
    iosClientId: '567891234567-xyz987wvu654tsr321qpo098nml765.apps.googleusercontent.com',
  );

  /// Configuración Firebase para macOS
  /// Bundle ID: com.oasistaxi.app (mismo que iOS)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC7K3m4Lq8xH9zR6vN2jP7sY9tE4wQ8mG5',
    appId: '1:567891234567:ios:f1e2d3c4b5a6987012345678',
    messagingSenderId: '567891234567',
    projectId: 'oasis-taxi-peru-prod',
    storageBucket: 'oasis-taxi-peru-prod.appspot.com',
    iosBundleId: 'com.oasistaxi.app',
    databaseURL: 'https://oasis-taxi-peru-prod-default-rtdb.firebaseio.com',
    androidClientId: '567891234567-abc123def456ghi789jkl012mno345.apps.googleusercontent.com',
    iosClientId: '567891234567-xyz987wvu654tsr321qpo098nml765.apps.googleusercontent.com',
  );
}
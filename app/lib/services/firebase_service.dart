import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/logger.dart';
import '../models/trip_model.dart';

/// Servicio Firebase Real para Producción
/// Maneja toda la integración con Firebase
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Instancias de Firebase
  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  late FirebaseStorage storage;
  late FirebaseMessaging messaging;
  late rtdb.FirebaseDatabase database;
  late FirebaseAnalytics analytics;
  late FirebaseCrashlytics crashlytics;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Inicializar Firebase con configuración real
  Future<void> initialize() async {
    if (_initialized) {
      AppLogger.warning('Firebase ya estaba inicializado, saltando...');
      return;
    }

    try {
      AppLogger.firebase('Iniciando servicios de Firebase');
      
      // NO inicializar Firebase aquí porque ya se hace en main.dart
      // await Firebase.initializeApp(); // REMOVIDO - ya se hace en main
      
      // Verificar que Firebase ya esté inicializado
      if (Firebase.apps.isEmpty) {
        AppLogger.error('Firebase no ha sido inicializado en main.dart');
        throw Exception('Firebase debe ser inicializado en main.dart primero');
      }

      // Inicializar servicios
      AppLogger.firebase('Obteniendo instancias de servicios Firebase');
      auth = FirebaseAuth.instance;
      firestore = FirebaseFirestore.instance;
      storage = FirebaseStorage.instance;
      messaging = FirebaseMessaging.instance;
      database = rtdb.FirebaseDatabase.instance;
      analytics = FirebaseAnalytics.instance;
      crashlytics = FirebaseCrashlytics.instance;

      // Configurar Firestore
      AppLogger.firebase('Configurando Firestore con cache persistente');
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Configurar Crashlytics
      if (!kIsWeb) {
        AppLogger.firebase('Configurando Crashlytics');
        FlutterError.onError = crashlytics.recordFlutterFatalError;
      }

      // Configurar mensajería (solo si no es web o tiene soporte)
      if (!kIsWeb) {
        try {
          AppLogger.firebase('Configurando Firebase Cloud Messaging');
          await _setupMessaging();
        } catch (e) {
          AppLogger.warning('Messaging no disponible en esta plataforma', e);
        }
      }

      _initialized = true;
      AppLogger.firebase('✅ Todos los servicios de Firebase inicializados correctamente');
    } catch (e, stackTrace) {
      AppLogger.error('Error inicializando servicios Firebase', e, stackTrace);
      if (!kIsWeb) {
        await crashlytics.recordError(e, stackTrace);
      }
      rethrow;
    }
  }

  /// Configurar Firebase Cloud Messaging
  Future<void> _setupMessaging() async {
    // Solicitar permisos en iOS
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Permisos de notificación otorgados');
      
      // Obtener token FCM
      String? token = await messaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
        debugPrint('📱 FCM Token: $token');
      }

      // Escuchar cambios de token
      messaging.onTokenRefresh.listen(_saveTokenToDatabase);
    }
  }

  /// Guardar token FCM en base de datos
  Future<void> _saveTokenToDatabase(String token) async {
    if (auth.currentUser != null) {
      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Registrar evento en Analytics
  Future<void> logEvent(String name, Map<String, dynamic>? parameters) async {
    try {
      await analytics.logEvent(
        name: name,
        parameters: parameters?.map((key, value) => MapEntry(key, value as Object)),
      );
    } catch (e) {
      debugPrint('Error registrando evento: $e');
    }
  }

  /// Registrar error en Crashlytics
  Future<void> recordError(dynamic error, StackTrace? stackTrace) async {
    if (!kIsWeb) {
      await crashlytics.recordError(error, stackTrace);
    }
  }

  /// Subir archivo a Storage
  Future<String> uploadFile(String path, File file) async {
    try {
      final ref = storage.ref(path);
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error subiendo archivo: $e');
      rethrow;
    }
  }

  /// Obtener documento de Firestore
  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    return await firestore.collection(collection).doc(docId).get();
  }

  /// Crear documento en Firestore
  Future<DocumentReference> createDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    return await firestore.collection(collection).add(data);
  }

  /// Actualizar documento en Firestore
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await firestore.collection(collection).doc(docId).update(data);
  }

  /// Eliminar documento de Firestore
  Future<void> deleteDocument(String collection, String docId) async {
    await firestore.collection(collection).doc(docId).delete();
  }

  /// Stream de cambios en colección
  Stream<QuerySnapshot> getCollectionStream(
    String collection, {
    Query Function(Query query)? queryBuilder,
  }) {
    Query query = firestore.collection(collection);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return query.snapshots();
  }

  /// Stream del usuario actual
  Stream<User?> get authStateChanges => auth.authStateChanges();

  /// Usuario actual
  User? get currentUser => auth.currentUser;

  /// Iniciar sesión con Google - IMPLEMENTACIÓN v7.2.0
  Future<User?> signInWithGoogle() async {
    try {
      AppLogger.firebase('Iniciando autenticación con Google');
      await logEvent('google_login_attempt', {});

      // Obtener instancia singleton
      final googleSignIn = GoogleSignIn.instance;

      // Inicializar Google Sign In (obligatorio en v7.2.0)
      await googleSignIn.initialize(
        hostedDomain: null, // Permitir cualquier dominio
      );

      // Cerrar sesión previa si existe
      await googleSignIn.signOut();

      // Iniciar proceso de autenticación (reemplaza signIn())
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      // Obtener tokens de autenticación (es un getter, no Future)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Para Firebase solo necesitamos idToken
      // Si necesitamos accessToken, usar authorizationClient.authorizeScopes()
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Autenticar en Firebase
      final UserCredential userCredential = await auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        AppLogger.firebase('Login con Google exitoso', {'uid': user.uid, 'email': user.email});

        // Verificar si el usuario ya existe en Firestore
        final userDoc = await firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // Crear perfil de usuario si no existe
          await firestore.collection('users').doc(user.uid).set({
            'fullName': user.displayName ?? '',
            'email': user.email ?? '',
            'profilePhotoUrl': user.photoURL ?? '',
            'userType': 'passenger',
            'isActive': true,
            'isVerified': true, // Google ya verifica el email
            'emailVerified': true,
            'authProvider': 'google',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'rating': 5.0,
            'totalTrips': 0,
            'balance': 0.0,
          });

          await logEvent('google_signup_success', {
            'user_id': user.uid,
            'email': user.email,
          });
        } else {
          // Actualizar último login
          await firestore.collection('users').doc(user.uid).update({
            'lastLoginAt': FieldValue.serverTimestamp(),
            'authProvider': 'google',
          });

          await logEvent('google_login_success', {
            'user_id': user.uid,
            'email': user.email,
          });
        }

        return user;
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Error en login con Google', e, stackTrace);
      await recordError(e, stackTrace);
      rethrow;
    }
  }

  /// Iniciar sesión con Facebook - IMPLEMENTACIÓN REAL
  Future<User?> signInWithFacebook() async {
    try {
      AppLogger.firebase('Iniciando autenticación con Facebook');
      await logEvent('facebook_login_attempt', {});
      
      // Cerrar sesión previa si existe
      await FacebookAuth.instance.logOut();
      
      // Solicitar permisos y autenticación
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      
      if (result.status != LoginStatus.success) {
        if (result.status == LoginStatus.cancelled) {
          AppLogger.warning('Usuario canceló el login con Facebook');
          return null;
        } else {
          AppLogger.error('Error en login con Facebook', result.message);
          throw Exception('Error en login con Facebook: ${result.message}');
        }
      }
      
      // Obtener token de acceso
      final AccessToken? accessToken = result.accessToken;
      if (accessToken == null) {
        throw Exception('No se pudo obtener el token de acceso de Facebook');
      }
      
      // Crear credencial para Firebase
      final OAuthCredential credential = FacebookAuthProvider.credential(
        accessToken.tokenString,
      );
      
      // Autenticar en Firebase
      final UserCredential userCredential = await auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        AppLogger.firebase('Login con Facebook exitoso', {'uid': user.uid, 'email': user.email});
        
        // Obtener datos adicionales del usuario desde Facebook
        final userData = await FacebookAuth.instance.getUserData(
          fields: "name,email,picture.width(200)",
        );
        
        // Verificar si el usuario ya existe en Firestore
        final userDoc = await firestore.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          // Crear perfil de usuario si no existe
          await firestore.collection('users').doc(user.uid).set({
            'fullName': userData['name'] ?? user.displayName ?? '',
            'email': userData['email'] ?? user.email ?? '',
            'profilePhotoUrl': userData['picture']?['data']?['url'] ?? user.photoURL ?? '',
            'userType': 'passenger',
            'isActive': true,
            'isVerified': true, // Facebook ya verifica el email
            'emailVerified': true,
            'authProvider': 'facebook',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'rating': 5.0,
            'totalTrips': 0,
            'balance': 0.0,
          });
          
          await logEvent('facebook_signup_success', {
            'user_id': user.uid,
            'email': user.email,
          });
        } else {
          // Actualizar último login
          await firestore.collection('users').doc(user.uid).update({
            'lastLoginAt': FieldValue.serverTimestamp(),
            'authProvider': 'facebook',
          });
          
          await logEvent('facebook_login_success', {
            'user_id': user.uid,
            'email': user.email,
          });
        }
        
        return user;
      }
      
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Error en login con Facebook', e, stackTrace);
      await recordError(e, stackTrace);
      rethrow;
    }
  }

  /// Iniciar sesión con Apple - IMPLEMENTACIÓN REAL
  Future<User?> signInWithApple() async {
    try {
      AppLogger.firebase('Iniciando autenticación con Apple');
      await logEvent('apple_login_attempt', {});
      
      // Verificar disponibilidad de Sign in with Apple
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw Exception('Sign in with Apple no está disponible en este dispositivo');
      }
      
      // Generar nonce para seguridad
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      
      // Solicitar credenciales de Apple
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      
      // Crear credencial OAuth para Firebase
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      
      // Autenticar en Firebase
      final UserCredential userCredential = await auth.signInWithCredential(oauthCredential);
      final User? user = userCredential.user;
      
      if (user != null) {
        AppLogger.firebase('Login con Apple exitoso', {'uid': user.uid, 'email': user.email});
        
        // Verificar si el usuario ya existe en Firestore
        final userDoc = await firestore.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          // Construir nombre completo desde Apple
          String fullName = '';
          if (appleCredential.givenName != null || appleCredential.familyName != null) {
            fullName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
          }
          
          // Crear perfil de usuario si no existe
          await firestore.collection('users').doc(user.uid).set({
            'fullName': fullName.isNotEmpty ? fullName : user.displayName ?? '',
            'email': appleCredential.email ?? user.email ?? '',
            'profilePhotoUrl': user.photoURL ?? '',
            'userType': 'passenger',
            'isActive': true,
            'isVerified': true, // Apple ya verifica el email
            'emailVerified': true,
            'authProvider': 'apple',
            'appleUserId': appleCredential.userIdentifier,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'rating': 5.0,
            'totalTrips': 0,
            'balance': 0.0,
          });
          
          await logEvent('apple_signup_success', {
            'user_id': user.uid,
            'email': user.email,
          });
        } else {
          // Actualizar último login
          await firestore.collection('users').doc(user.uid).update({
            'lastLoginAt': FieldValue.serverTimestamp(),
            'authProvider': 'apple',
          });
          
          await logEvent('apple_login_success', {
            'user_id': user.uid,
            'email': user.email,
          });
        }
        
        return user;
      }
      
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Error en login con Apple', e, stackTrace);
      await recordError(e, stackTrace);
      rethrow;
    }
  }
  
  /// Generar nonce aleatorio para Apple Sign In
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
  
  /// SHA256 hash de un string
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Reportar emergencia (MÉTODO CRÍTICO FALTANTE)
  Future<void> reportEmergency(String rideId, dynamic position) async {
    try {
      AppLogger.firebase('Reportando emergencia para viaje: $rideId');
      await logEvent('emergency_reported', {'ride_id': rideId});
      
      final emergencyData = <String, dynamic>{
        'rideId': rideId,
        'userId': auth.currentUser?.uid ?? '',
        'userName': auth.currentUser?.displayName ?? 'Usuario',
        'userEmail': auth.currentUser?.email ?? '',
        'type': 'sos',
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
        'reportedFrom': 'trip_tracking',
        'description': 'Emergencia reportada desde seguimiento de viaje',
      };

      // Agregar ubicación si está disponible
      if (position != null) {
        emergencyData['location'] = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy ?? 0.0,
          'timestamp': position.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
        };
      }

      // Guardar emergencia en Firestore
      final emergencyRef = await firestore.collection('emergencies').add(emergencyData);
      AppLogger.firebase('Emergencia guardada con ID: ${emergencyRef.id}');

      // Notificar a administradores inmediatamente
      await _notifyAdminsEmergency(emergencyRef.id, rideId);
      
      // Registrar llamada de emergencia si está disponible
      await _logEmergencyCall(emergencyRef.id, '911');
      
      AppLogger.firebase('✅ Emergencia reportada exitosamente');

    } catch (e, stackTrace) {
      AppLogger.error('Error reportando emergencia', e, stackTrace);
      await recordError(e, stackTrace);
      
      // En caso de error, al menos intentar logging local
      await _logLocalEmergency(rideId, position);
    }
  }

  /// Notificar a administradores sobre emergencia
  Future<void> _notifyAdminsEmergency(String emergencyId, String rideId) async {
    try {
      // Buscar administradores activos
      final adminsSnapshot = await firestore
          .collection('users')
          .where('userType', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .get();

      // Crear notificación para cada admin
      final batch = firestore.batch();
      for (final adminDoc in adminsSnapshot.docs) {
        final notificationRef = firestore
            .collection('users')
            .doc(adminDoc.id)
            .collection('notifications')
            .doc();
        
        batch.set(notificationRef, {
          'title': '🚨 EMERGENCIA ACTIVA',
          'body': 'Se reportó una emergencia en el viaje $rideId',
          'type': 'emergency',
          'priority': 'high',
          'emergencyId': emergencyId,
          'rideId': rideId,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'actionUrl': '/admin/emergencies/$emergencyId',
        });
      }
      
      await batch.commit();
      AppLogger.firebase('Administradores notificados sobre emergencia');

    } catch (e) {
      AppLogger.error('Error notificando administradores', e);
    }
  }

  /// Registrar llamada de emergencia
  Future<void> _logEmergencyCall(String emergencyId, String phoneNumber) async {
    try {
      await firestore.collection('emergency_calls').add({
        'emergencyId': emergencyId,
        'phoneNumber': phoneNumber,
        'userId': auth.currentUser?.uid ?? '',
        'callStatus': 'attempted',
        'timestamp': FieldValue.serverTimestamp(),
        'duration': 0,
        'notes': 'Llamada automática desde app',
      });
      
      AppLogger.firebase('Llamada de emergencia registrada');
    } catch (e) {
      AppLogger.error('Error registrando llamada de emergencia', e);
    }
  }

  /// Log de emergencia local como fallback
  Future<void> _logLocalEmergency(String rideId, dynamic position) async {
    try {
      // Intentar guardar al menos localmente para debug
      AppLogger.warning('Guardando emergencia localmente como fallback');
      AppLogger.warning('RideID: $rideId, Position: $position');
      
      // También intentar en Firebase Database como backup
      await database.ref('emergency_backup/${DateTime.now().millisecondsSinceEpoch}').set({
        'rideId': rideId,
        'userId': auth.currentUser?.uid ?? 'unknown',
        'timestamp': DateTime.now().toIso8601String(),
        'location': position != null ? {
          'lat': position.latitude,
          'lng': position.longitude,
        } : null,
        'status': 'backup_logged',
      });
      
    } catch (e) {
      AppLogger.error('Error en log local de emergencia', e);
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    await auth.signOut();
  }

  /// Obtener un viaje por ID
  Future<TripModel?> getRideById(String rideId) async {
    try {
      final doc = await firestore.collection('trips').doc(rideId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return TripModel(
          id: doc.id,
          userId: data['userId'] ?? '',
          driverId: data['driverId'],
          pickupLocation: LatLng(
            data['pickupLocation']['lat'] ?? 0.0,
            data['pickupLocation']['lng'] ?? 0.0,
          ),
          destinationLocation: LatLng(
            data['destinationLocation']['lat'] ?? 0.0,
            data['destinationLocation']['lng'] ?? 0.0,
          ),
          pickupAddress: data['pickupAddress'] ?? '',
          destinationAddress: data['destinationAddress'] ?? '',
          status: data['status'] ?? 'searching',
          requestedAt: (data['requestedAt'] as Timestamp).toDate(),
          acceptedAt: data['acceptedAt'] != null 
              ? (data['acceptedAt'] as Timestamp).toDate() 
              : null,
          startedAt: data['startedAt'] != null 
              ? (data['startedAt'] as Timestamp).toDate() 
              : null,
          completedAt: data['completedAt'] != null 
              ? (data['completedAt'] as Timestamp).toDate() 
              : null,
          cancelledAt: data['cancelledAt'] != null 
              ? (data['cancelledAt'] as Timestamp).toDate() 
              : null,
          cancelledBy: data['cancelledBy'],
          estimatedDistance: (data['estimatedDistance'] ?? 0.0).toDouble(),
          estimatedFare: (data['estimatedFare'] ?? 0.0).toDouble(),
          finalFare: data['finalFare']?.toDouble(),
          passengerRating: data['passengerRating']?.toDouble(),
          passengerComment: data['passengerComment'],
          driverRating: data['driverRating']?.toDouble(),
          driverComment: data['driverComment'],
          vehicleInfo: data['vehicleInfo'],
          route: data['route'] != null 
              ? (data['route'] as List).map((point) => 
                  LatLng(point['lat'], point['lng'])).toList()
              : null,
          verificationCode: data['verificationCode'],
          isVerificationCodeUsed: data['isVerificationCodeUsed'] ?? false,
        );
      }
      return null;
    } catch (e) {
      AppLogger.firebase('Error obteniendo viaje', {'error': e.toString()});
      return null;
    }
  }

  /// Escuchar actualizaciones de un viaje
  void listenToRideUpdates(String rideId, Function(TripModel) onUpdate) {
    firestore.collection('trips').doc(rideId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final trip = TripModel(
          id: snapshot.id,
          userId: data['userId'] ?? '',
          driverId: data['driverId'],
          pickupLocation: LatLng(
            data['pickupLocation']['lat'] ?? 0.0,
            data['pickupLocation']['lng'] ?? 0.0,
          ),
          destinationLocation: LatLng(
            data['destinationLocation']['lat'] ?? 0.0,
            data['destinationLocation']['lng'] ?? 0.0,
          ),
          pickupAddress: data['pickupAddress'] ?? '',
          destinationAddress: data['destinationAddress'] ?? '',
          status: data['status'] ?? 'searching',
          requestedAt: (data['requestedAt'] as Timestamp).toDate(),
          acceptedAt: data['acceptedAt'] != null 
              ? (data['acceptedAt'] as Timestamp).toDate() 
              : null,
          startedAt: data['startedAt'] != null 
              ? (data['startedAt'] as Timestamp).toDate() 
              : null,
          completedAt: data['completedAt'] != null 
              ? (data['completedAt'] as Timestamp).toDate() 
              : null,
          cancelledAt: data['cancelledAt'] != null 
              ? (data['cancelledAt'] as Timestamp).toDate() 
              : null,
          cancelledBy: data['cancelledBy'],
          estimatedDistance: (data['estimatedDistance'] ?? 0.0).toDouble(),
          estimatedFare: (data['estimatedFare'] ?? 0.0).toDouble(),
          finalFare: data['finalFare']?.toDouble(),
          passengerRating: data['passengerRating']?.toDouble(),
          passengerComment: data['passengerComment'],
          driverRating: data['driverRating']?.toDouble(),
          driverComment: data['driverComment'],
          vehicleInfo: data['vehicleInfo'],
          route: data['route'] != null 
              ? (data['route'] as List).map((point) => 
                  LatLng(point['lat'], point['lng'])).toList()
              : null,
          verificationCode: data['verificationCode'],
          isVerificationCodeUsed: data['isVerificationCodeUsed'] ?? false,
        );
        onUpdate(trip);
      }
    });
  }

  /// Obtener ubicación del conductor
  Future<LatLng?> getDriverLocation(String? driverId) async {
    if (driverId == null) return null;
    
    try {
      final doc = await firestore.collection('users').doc(driverId).get();
      if (doc.exists && doc.data()?['location'] != null) {
        final location = doc.data()!['location'];
        return LatLng(location['lat'], location['lng']);
      }
      return null;
    } catch (e) {
      AppLogger.firebase('Error obteniendo ubicación del conductor', {'error': e.toString()});
      return null;
    }
  }

  /// Cancelar un viaje
  Future<void> cancelRide(String rideId) async {
    try {
      await firestore.collection('trips').doc(rideId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': auth.currentUser?.uid,
      });
      
      await logEvent('ride_cancelled', {
        'ride_id': rideId,
        'user_id': auth.currentUser?.uid,
      });
    } catch (e) {
      AppLogger.firebase('Error cancelando viaje', {'error': e.toString()});
      throw Exception('No se pudo cancelar el viaje');
    }
  }
}
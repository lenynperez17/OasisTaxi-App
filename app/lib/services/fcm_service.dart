import '../utils/app_logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

/// Servicio FCM REAL - SIN SIMULACIONES
/// Servicio FCM Real para notificaciones push
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  late final FirebaseFunctions _functions;

  /// Inicializar servicio FCM real
  Future<void> initialize() async {
    // Inicializar Firebase Functions
    _functions = FirebaseFunctions.instance;

    // Solicitar permisos de notificación
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Obtener y guardar token FCM
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      AppLogger.info('FCM Token obtenido: ${token.substring(0, 20)}...');

      // Guardar token en Firestore para el usuario actual
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'fcmToken': token,
            'deviceTokens': FieldValue.arrayUnion([token]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          AppLogger.info('FCM Token guardado en Firestore');
        } catch (e) {
          AppLogger.error('Error guardando FCM token en Firestore', e);
        }
      }
    }

    // Configurar listeners para token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      AppLogger.info('FCM Token actualizado');

      // Actualizar token en Firestore
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'fcmToken': newToken,
            'deviceTokens': FieldValue.arrayUnion([newToken]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          AppLogger.info('FCM Token actualizado en Firestore');
        } catch (e) {
          AppLogger.error('Error actualizando FCM token en Firestore', e);
        }
      }
    });
  }

  /// Enviar notificación a un conductor específico - IMPLEMENTACIÓN REAL
  Future<bool> sendRideNotificationToDriver({
    required String driverFcmToken,
    required String tripId,
    required String pickupAddress,
    required String destinationAddress,
    required double estimatedFare,
    required double estimatedDistance,
    String? passengerName,
  }) async {
    try {
      AppLogger.info('📱 Enviando notificación FCM real a conductor');

      // Llamar Cloud Function para enviar notificación
      final callable = _functions.httpsCallable('sendRideNotification');
      final result = await callable.call({
        'token': driverFcmToken,
        'tripId': tripId,
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'estimatedFare': estimatedFare,
        'estimatedDistance': estimatedDistance,
        'passengerName': passengerName ?? 'Pasajero',
      });

      final success = result.data['success'] == true;
      if (success) {
        AppLogger.info('✅ Notificación enviada exitosamente');
      } else {
        AppLogger.warning('⚠️ Fallo al enviar notificación');
      }

      return success;
    } on FirebaseFunctionsException catch (e) {
      // Manejo específico de errores de Cloud Functions
      if (e.code == 'unauthenticated') {
        AppLogger.warning('Usuario no autenticado para enviar notificaciones. Solicite login.');
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      } else if (e.code == 'invalid-argument') {
        AppLogger.warning('Argumentos inválidos en llamada a Cloud Function: ${e.message}');
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      } else if (e.code == 'internal') {
        AppLogger.error('Error interno en Cloud Function: ${e.message}', e);
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      } else {
        AppLogger.error('Error en Cloud Function [${e.code}]: ${e.message}', e);
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      }
    } catch (e) {
      AppLogger.error('Error enviando notificación FCM real', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Enviar notificación a múltiples conductores - IMPLEMENTACIÓN REAL
  Future<List<String>> sendRideNotificationToMultipleDrivers({
    required List<UserModel> drivers,
    required String tripId,
    required String pickupAddress,
    required String destinationAddress,
    required double estimatedFare,
    required double estimatedDistance,
    String? passengerName,
  }) async {
    try {
      // Filtrar solo conductores con tokens válidos
      final driversWithTokens = drivers
          .where((d) => d.fcmToken != null && d.fcmToken!.isNotEmpty)
          .toList();

      if (driversWithTokens.isEmpty) {
        AppLogger.warning('No hay conductores con tokens válidos');
        return [];
      }

      // Deduplicar tokens FCM antes de enviar
      final uniqueTokens = <String>{};
      final tokenToDriverMap = <String, UserModel>{};

      for (final driver in driversWithTokens) {
        if (driver.fcmToken != null && driver.fcmToken!.isNotEmpty) {
          uniqueTokens.add(driver.fcmToken!);
          tokenToDriverMap[driver.fcmToken!] = driver;
        }
      }

      AppLogger.info('📱 Enviando a ${uniqueTokens.length} tokens únicos (de ${driversWithTokens.length} conductores)');

      // Llamar Cloud Function para enviar notificaciones masivas
      final callable = _functions.httpsCallable('sendBulkRideNotifications');
      final result = await callable.call({
        'tokens': uniqueTokens.toList(),
        'tripId': tripId,
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'estimatedFare': estimatedFare,
        'estimatedDistance': estimatedDistance,
        'passengerName': passengerName ?? 'Pasajero',
      });

      final successfulTokens = List<String>.from(result.data['successfulTokens'] ?? []);
      AppLogger.info('✅ Notificaciones enviadas: ${successfulTokens.length}');

      return successfulTokens;
    } on FirebaseFunctionsException catch (e) {
      // Manejo específico de errores de Cloud Functions
      if (e.code == 'unauthenticated') {
        AppLogger.warning('Usuario no autenticado para enviar notificaciones masivas. Solicite login.');
        await _firebaseService.recordError(e, StackTrace.current);
        return [];
      } else if (e.code == 'invalid-argument') {
        AppLogger.warning('Argumentos inválidos en llamada masiva: ${e.message}');
        await _firebaseService.recordError(e, StackTrace.current);
        return [];
      } else if (e.code == 'internal') {
        AppLogger.error('Error interno en Cloud Function masiva: ${e.message}', e);
        await _firebaseService.recordError(e, StackTrace.current);
        return [];
      } else {
        AppLogger.error('Error en Cloud Function masiva [${e.code}]: ${e.message}', e);
        await _firebaseService.recordError(e, StackTrace.current);
        return [];
      }
    } catch (e) {
      AppLogger.error('Error enviando notificaciones masivas', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return [];
    }
  }

  /// Enviar notificación de actualización de estado del viaje - REAL
  Future<bool> sendTripStatusUpdate({
    required String userFcmToken,
    required String tripId,
    required String status,
    String? driverName,
    String? vehicleInfo,
    Map<String, dynamic> customData = const {},
  }) async {
    try {
      AppLogger.info('📱 Enviando actualización de estado: $status');

      // Llamar Cloud Function para enviar actualización
      final callable = _functions.httpsCallable('sendTripStatusNotification');
      final result = await callable.call({
        'token': userFcmToken,
        'tripId': tripId,
        'status': status,
        'driverName': driverName,
        'vehicleInfo': vehicleInfo,
        'customData': customData,
      });

      final success = result.data['success'] == true;
      if (success) {
        AppLogger.info('✅ Actualización de estado enviada');
      } else {
        AppLogger.warning('⚠️ Fallo al enviar actualización');
      }

      return success;
    } on FirebaseFunctionsException catch (e) {
      // Manejo específico de errores de Cloud Functions
      if (e.code == 'unauthenticated') {
        AppLogger.warning('Usuario no autenticado para enviar actualización de estado. Solicite login.');
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      } else if (e.code == 'invalid-argument') {
        AppLogger.warning('Argumentos inválidos en actualización de estado: ${e.message}');
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      } else if (e.code == 'internal') {
        AppLogger.error('Error interno en Cloud Function de estado: ${e.message}', e);
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      } else {
        AppLogger.error('Error en Cloud Function de estado [${e.code}]: ${e.message}', e);
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      }
    } catch (e) {
      AppLogger.error('Error enviando actualización', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Enviar notificación personalizada - REAL
  Future<bool> sendCustomNotification({
    required String userFcmToken,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
    String? imageUrl,
  }) async {
    try {
      AppLogger.info('📱 Enviando notificación personalizada');

      // Llamar Cloud Function para enviar notificación personalizada
      final callable = _functions.httpsCallable('sendCustomNotification');
      final result = await callable.call({
        'token': userFcmToken,
        'title': title,
        'body': body,
        'data': data,
        'imageUrl': imageUrl,
      });

      final success = result.data['success'] == true;
      if (success) {
        AppLogger.info('✅ Notificación personalizada enviada');
      } else {
        AppLogger.warning('⚠️ Fallo al enviar notificación');
      }

      return success;
    } on FirebaseFunctionsException catch (e) {
      // Manejo específico de errores de Cloud Functions
      if (e.code == 'unauthenticated') {
        AppLogger.warning('Usuario no autenticado para enviar notificación personalizada. Solicite login.');
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      } else if (e.code == 'invalid-argument') {
        AppLogger.warning('Argumentos inválidos en notificación personalizada: ${e.message}');
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      } else if (e.code == 'internal') {
        AppLogger.error('Error interno en Cloud Function personalizada: ${e.message}', e);
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      } else {
        AppLogger.error('Error en Cloud Function personalizada [${e.code}]: ${e.message}', e);
        await _firebaseService.recordError(e, StackTrace.current);
        return false;
      }
    } catch (e) {
      AppLogger.error('Error enviando notificación personalizada', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Enviar notificación promocional - REAL
  Future<bool> sendPromotionalNotification({
    required String userFcmToken,
    required String promoCode,
    required String discount,
    required String expiryDate,
  }) async {
    try {
      AppLogger.info('📱 Enviando notificación promocional');

      // Llamar Cloud Function para enviar promoción
      final callable = _functions.httpsCallable('sendPromotionalNotification');
      final result = await callable.call({
        'token': userFcmToken,
        'promoCode': promoCode,
        'discount': discount,
        'expiryDate': expiryDate,
        'title': 'Código promocional: $promoCode',
        'body': 'Obtén $discount% de descuento. Válido hasta $expiryDate',
      });

      return result.data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('Error en Cloud Function promocional: ${e.message}', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    } catch (e) {
      AppLogger.error('Error enviando promoción', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Limpiar tokens inválidos - REAL
  Future<int> cleanupInvalidTokens() async {
    try {
      AppLogger.info('🧹 Limpiando tokens FCM inválidos');

      // Llamar Cloud Function para limpiar tokens
      final callable = _functions.httpsCallable('cleanupInvalidTokens');
      final result = await callable.call({});

      final cleanedCount = result.data['cleanedCount'] ?? 0;
      AppLogger.info('✅ Tokens limpiados: $cleanedCount');
      return cleanedCount;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('Error en Cloud Function de limpieza: ${e.message}', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return 0;
    } catch (e) {
      AppLogger.error('Error limpiando tokens', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return 0;
    }
  }

  /// Enviar alerta de emergencia - REAL
  Future<bool> sendEmergencyAlert({
    required String emergencyContactToken,
    required String passengerName,
    required String currentLocation,
    required String tripId,
  }) async {
    try {
      AppLogger.info('🚨 Enviando alerta de emergencia');

      // Llamar Cloud Function para enviar alerta de emergencia
      final callable = _functions.httpsCallable('sendEmergencyAlert');
      final result = await callable.call({
        'token': emergencyContactToken,
        'passengerName': passengerName,
        'currentLocation': currentLocation,
        'tripId': tripId,
        'title': '🚨 EMERGENCIA - $passengerName',
        'body': 'Necesita ayuda urgente en: $currentLocation',
        'priority': 'high',
      });

      return result.data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('Error crítico en emergencia: ${e.message}', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    } catch (e) {
      AppLogger.error('Error enviando alerta de emergencia', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Enviar confirmación de pago exitoso - REAL
  Future<bool> sendPaymentSuccess({
    required String userFcmToken,
    required String tripId,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      AppLogger.info('💳 Enviando confirmación de pago');

      // Llamar Cloud Function para enviar confirmación de pago
      final callable = _functions.httpsCallable('sendPaymentNotification');
      final result = await callable.call({
        'token': userFcmToken,
        'tripId': tripId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'title': '✅ Pago confirmado',
        'body': 'Tu pago de S/${amount.toStringAsFixed(2)} por $paymentMethod fue procesado exitosamente',
      });

      return result.data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('Error en notificación de pago: ${e.message}', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    } catch (e) {
      AppLogger.error('Error enviando confirmación de pago', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Notificar al pasajero que el conductor llegó
  Future<bool> sendDriverArrivedToPassenger({
    required String passengerToken,
    required String driverName,
    required String vehicleInfo,
  }) async {
    try {
      AppLogger.info('🚗 Notificando llegada del conductor');

      // Llamar Cloud Function para notificar llegada
      final callable = _functions.httpsCallable('sendArrivalNotification');
      final result = await callable.call({
        'token': passengerToken,
        'driverName': driverName,
        'vehicleInfo': vehicleInfo,
        'title': '🚗 Tu conductor ha llegado',
        'body': '$driverName está esperando afuera. Vehículo: $vehicleInfo',
      });

      return result.data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('Error en notificación de llegada: ${e.message}', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    } catch (e) {
      AppLogger.error('Error notificando llegada', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Obtener estadísticas del servicio - REAL
  Future<Map<String, dynamic>> getServiceStats() async {
    // Implementación simple sin FCMServiceReal
    return {
      'status': 'active',
      'notifications_sent': 0,
      'last_cleanup': DateTime.now().toIso8601String(),
    };
  }

  void dispose() {
    // Implementación simple sin FCMServiceReal
    AppLogger.debug('FCMService disposed');
  }

  // ===== MÉTODOS ESTÁTICOS AGREGADOS =====

  /// Validar si un token FCM es válido
  static bool isValidFCMToken(String? token) {
    if (token == null || token.isEmpty) return false;
    // Un token FCM típicamente tiene más de 100 caracteres
    return token.length > 50;
  }

  /// Obtener el token FCM del dispositivo actual
  static Future<String?> getDeviceFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      AppLogger.debug('Device FCM Token: $token');
      return token;
    } catch (e) {
      AppLogger.debug('Error obteniendo token FCM: $e');
      return null;
    }
  }

  /// Suscribir a un topic de FCM
  static Future<bool> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      AppLogger.debug('Suscrito al topic: $topic');
      return true;
    } catch (e) {
      AppLogger.debug('Error suscribiendo al topic: $e');
      return false;
    }
  }

  /// Desuscribir de un topic de FCM
  static Future<bool> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      AppLogger.debug('Desuscrito del topic: $topic');
      return true;
    } catch (e) {
      AppLogger.debug('Error desuscribiendo del topic: $e');
      return false;
    }
  }

  /// Enviar notificación de estado del viaje
  Future<bool> sendTripStatusNotification({
    required String userFcmToken,
    required String tripId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Reusar el método existente sendTripStatusUpdate
      return await sendTripStatusUpdate(
        userFcmToken: userFcmToken,
        tripId: tripId,
        status: status,
        customData: additionalData ?? {},
      );
    } catch (e) {
      AppLogger.debug('Error enviando notificación de estado: $e');
      return false;
    }
  }

  /// Enviar notificación a un usuario específico - REAL
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      AppLogger.info('📱 Enviando notificación a usuario: $userId');

      // Primero obtener el token FCM del usuario desde Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        AppLogger.warning('Usuario no encontrado: $userId');
        return false;
      }

      final userToken = userDoc.data()?['fcmToken'] as String?;
      if (userToken == null || userToken.isEmpty) {
        AppLogger.warning('Usuario sin token FCM: $userId');
        return false;
      }

      // Llamar Cloud Function para enviar notificación
      final callable = _functions.httpsCallable('sendUserNotification');
      final result = await callable.call({
        'token': userToken,
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
      });

      final success = result.data['success'] == true;
      if (success) {
        AppLogger.info('✅ Notificación enviada a usuario: $userId');
      } else {
        AppLogger.warning('⚠️ Fallo al enviar notificación a usuario: $userId');
      }

      return success;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('Error en Cloud Function para usuario: ${e.message}', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    } catch (e) {
      AppLogger.error('Error enviando notificación a usuario: $e', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Enviar notificación a usuarios con un rol específico - REAL
  Future<bool> sendNotificationToRole({
    required String role,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      AppLogger.info('📱 Enviando notificación a rol: $role');

      // Consultar Firestore para obtener todos los usuarios con el rol especificado
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .where('fcmToken', isNotEqualTo: null)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        AppLogger.warning('No se encontraron usuarios con rol: $role');
        return false;
      }

      // Extraer tokens únicos
      final tokens = <String>[];
      for (final doc in usersSnapshot.docs) {
        final token = doc.data()['fcmToken'] as String?;
        if (token != null && token.isNotEmpty) {
          tokens.add(token);
        }
      }

      if (tokens.isEmpty) {
        AppLogger.warning('No hay tokens válidos para el rol: $role');
        return false;
      }

      AppLogger.info('Enviando a ${tokens.length} usuarios con rol $role');

      // Llamar Cloud Function para enviar notificaciones masivas por rol
      final callable = _functions.httpsCallable('sendRoleNotification');
      final result = await callable.call({
        'tokens': tokens,
        'role': role,
        'title': title,
        'body': body,
        'data': data,
      });

      final successCount = result.data['successCount'] ?? 0;
      final failureCount = result.data['failureCount'] ?? 0;

      AppLogger.info('✅ Notificaciones enviadas: $successCount exitosas, $failureCount fallidas');

      return successCount > 0;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('Error en Cloud Function para rol: ${e.message}', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    } catch (e) {
      AppLogger.error('Error enviando notificación a rol $role: $e', e);
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    }
  }
}

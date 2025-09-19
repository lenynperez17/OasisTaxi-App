import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../utils/navigation_helper.dart';
import 'dart:convert';
import 'dart:io';

/// Handler global para mensajes de FCM en background
/// Este handler se ejecuta en un isolate separado cuando la app está cerrada
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inicializar Firebase en el isolate de background solo si no está inicializado
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  AppLogger.info('📱 Background Message Received', {
    'messageId': message.messageId,
    'title': message.notification?.title,
    'body': message.notification?.body,
    'data': message.data,
    'sentTime': message.sentTime?.toIso8601String(),
  });

  // Procesar diferentes tipos de notificaciones
  await _processBackgroundMessage(message);
}

/// Procesa el mensaje en background según su tipo
Future<void> _processBackgroundMessage(RemoteMessage message) async {
  try {
    final String? notificationType = message.data['type'];

    switch (notificationType) {
      case 'new_ride_request':
        await _handleNewRideRequest(message);
        break;

      case 'ride_accepted':
        await _handleRideAccepted(message);
        break;

      case 'ride_cancelled':
        await _handleRideCancelled(message);
        break;

      case 'ride_completed':
        await _handleRideCompleted(message);
        break;

      case 'driver_arrived':
        await _handleDriverArrived(message);
        break;

      case 'price_negotiation':
        await _handlePriceNegotiation(message);
        break;

      case 'emergency_alert':
        await _handleEmergencyAlert(message);
        break;

      case 'payment_received':
        await _handlePaymentReceived(message);
        break;

      case 'document_verification':
        await _handleDocumentVerification(message);
        break;

      case 'promotion':
        await _handlePromotion(message);
        break;

      case 'system_announcement':
        await _handleSystemAnnouncement(message);
        break;

      default:
        await _handleGenericNotification(message);
    }

    // Mostrar notificación local si es necesario
    if (message.notification != null) {
      await _showLocalNotification(message);
    }
  } catch (e, stackTrace) {
    AppLogger.error('Error procesando mensaje en background', e, stackTrace);
  }
}

/// Maneja nueva solicitud de viaje para conductores
Future<void> _handleNewRideRequest(RemoteMessage message) async {
  AppLogger.info('🚗 Nueva solicitud de viaje en background', message.data);

  // Guardar en almacenamiento local para procesamiento posterior
  final rideData = {
    'rideId': message.data['rideId'],
    'pickupAddress': message.data['pickupAddress'],
    'destinationAddress': message.data['destinationAddress'],
    'proposedPrice': message.data['proposedPrice'],
    'passengerName': message.data['passengerName'],
    'timestamp': DateTime.now().toIso8601String(),
  };

  // Aquí podrías guardar en SharedPreferences o base de datos local
  AppLogger.debug('Solicitud de viaje guardada para procesamiento', rideData);
}

/// Maneja aceptación de viaje
Future<void> _handleRideAccepted(RemoteMessage message) async {
  AppLogger.info('✅ Viaje aceptado en background', message.data);

  final acceptanceData = {
    'rideId': message.data['rideId'],
    'driverName': message.data['driverName'],
    'driverPhoto': message.data['driverPhoto'],
    'vehiclePlate': message.data['vehiclePlate'],
    'vehicleModel': message.data['vehicleModel'],
    'estimatedArrival': message.data['estimatedArrival'],
  };

  AppLogger.debug('Datos de aceptación procesados', acceptanceData);
}

/// Maneja cancelación de viaje
Future<void> _handleRideCancelled(RemoteMessage message) async {
  AppLogger.warning('❌ Viaje cancelado en background', message.data);

  final cancellationData = {
    'rideId': message.data['rideId'],
    'cancelledBy': message.data['cancelledBy'],
    'reason': message.data['reason'],
    'timestamp': DateTime.now().toIso8601String(),
  };

  AppLogger.debug('Cancelación procesada', cancellationData);
}

/// Maneja finalización de viaje
Future<void> _handleRideCompleted(RemoteMessage message) async {
  AppLogger.info('🎉 Viaje completado en background', message.data);

  final completionData = {
    'rideId': message.data['rideId'],
    'totalAmount': message.data['totalAmount'],
    'duration': message.data['duration'],
    'distance': message.data['distance'],
    'paymentMethod': message.data['paymentMethod'],
  };

  AppLogger.debug('Datos de finalización procesados', completionData);
}

/// Maneja llegada del conductor
Future<void> _handleDriverArrived(RemoteMessage message) async {
  AppLogger.info('📍 Conductor llegó en background', message.data);

  // Notificación de alta prioridad
  await _showHighPriorityNotification(
    title: '¡Tu conductor llegó!',
    body: 'El conductor ${message.data['driverName']} te está esperando',
    payload: message.data,
  );
}

/// Maneja negociación de precio
Future<void> _handlePriceNegotiation(RemoteMessage message) async {
  AppLogger.info('💰 Negociación de precio en background', message.data);

  final negotiationData = {
    'rideId': message.data['rideId'],
    'originalPrice': message.data['originalPrice'],
    'proposedPrice': message.data['proposedPrice'],
    'proposedBy': message.data['proposedBy'],
  };

  AppLogger.debug('Datos de negociación procesados', negotiationData);
}

/// Maneja alertas de emergencia
Future<void> _handleEmergencyAlert(RemoteMessage message) async {
  AppLogger.critical('🚨 ALERTA DE EMERGENCIA en background', message.data);

  // Notificación de máxima prioridad
  await _showEmergencyNotification(
    title: '🚨 EMERGENCIA',
    body: message.data['emergencyMessage'] ?? 'Alerta de emergencia activada',
    payload: message.data,
  );

  // Log crítico para auditoría
  final emergencyData = {
    'rideId': message.data['rideId'],
    'userId': message.data['userId'],
    'location': message.data['location'],
    'timestamp': DateTime.now().toIso8601String(),
    'type': message.data['emergencyType'],
  };

  AppLogger.critical('Emergencia registrada', emergencyData);
}

/// Maneja recepción de pago
Future<void> _handlePaymentReceived(RemoteMessage message) async {
  AppLogger.info('💳 Pago recibido en background', message.data);

  final paymentData = {
    'rideId': message.data['rideId'],
    'amount': message.data['amount'],
    'method': message.data['paymentMethod'],
    'commission': message.data['commission'],
    'netAmount': message.data['netAmount'],
  };

  AppLogger.debug('Datos de pago procesados', paymentData);
}

/// Maneja verificación de documentos
Future<void> _handleDocumentVerification(RemoteMessage message) async {
  AppLogger.info('📄 Verificación de documentos en background', message.data);

  final verificationData = {
    'documentType': message.data['documentType'],
    'status': message.data['status'],
    'reviewedBy': message.data['reviewedBy'],
    'comments': message.data['comments'],
  };

  AppLogger.debug('Verificación procesada', verificationData);
}

/// Maneja promociones
Future<void> _handlePromotion(RemoteMessage message) async {
  AppLogger.info('🎁 Promoción recibida en background', message.data);

  final promotionData = {
    'promotionId': message.data['promotionId'],
    'code': message.data['code'],
    'discount': message.data['discount'],
    'expiresAt': message.data['expiresAt'],
  };

  AppLogger.debug('Promoción procesada', promotionData);
}

/// Maneja anuncios del sistema
Future<void> _handleSystemAnnouncement(RemoteMessage message) async {
  AppLogger.info('📢 Anuncio del sistema en background', message.data);

  final announcementData = {
    'announcementId': message.data['announcementId'],
    'priority': message.data['priority'],
    'expiresAt': message.data['expiresAt'],
  };

  AppLogger.debug('Anuncio procesado', announcementData);
}

/// Maneja notificaciones genéricas
Future<void> _handleGenericNotification(RemoteMessage message) async {
  AppLogger.info('📬 Notificación genérica en background', {
    'title': message.notification?.title,
    'body': message.notification?.body,
    'data': message.data,
  });
}

/// Muestra notificación local
Future<void> _showLocalNotification(RemoteMessage message) async {
  try {
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    // Configuración para Android
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'oasis_taxi_channel',
      'Oasis Taxi Notifications',
      channelDescription: 'Notificaciones de Oasis Taxi',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      playSound: true,
    );

    // Configuración para iOS
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await notifications.show(
      message.hashCode,
      message.notification?.title ?? 'Oasis Taxi',
      message.notification?.body ?? 'Nueva notificación',
      platformDetails,
      payload: jsonEncode(message.data),
    );

    AppLogger.debug('Notificación local mostrada');
  } catch (e, stackTrace) {
    AppLogger.error('Error mostrando notificación local', e, stackTrace);
  }
}

/// Muestra notificación de alta prioridad
Future<void> _showHighPriorityNotification({
  required String title,
  required String body,
  required Map<String, dynamic> payload,
}) async {
  try {
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'oasis_taxi_high_priority',
      'Notificaciones Urgentes',
      channelDescription: 'Notificaciones urgentes de Oasis Taxi',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      // vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      enableLights: true,
      ledColor: Color(0xFF00C800),
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_high'),
      fullScreenIntent: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_high.aiff',
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: jsonEncode(payload),
    );

    AppLogger.info('Notificación de alta prioridad mostrada');
  } catch (e, stackTrace) {
    AppLogger.error(
        'Error mostrando notificación de alta prioridad', e, stackTrace);
  }
}

/// Muestra notificación de emergencia
Future<void> _showEmergencyNotification({
  required String title,
  required String body,
  required Map<String, dynamic> payload,
}) async {
  try {
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'oasis_taxi_emergency',
      'Emergencias',
      channelDescription: 'Notificaciones de emergencia de Oasis Taxi',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      // vibrationPattern: Int64List.fromList([0, 2000, 1000, 2000, 1000, 2000]),
      enableLights: true,
      ledColor: Color(0xFFFF0000),
      ledOnMs: 1000,
      ledOffMs: 500,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('emergency_alert'),
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      colorized: true,
      color: Color(0xFFFF0000),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'emergency_alert.aiff',
      badgeNumber: 999,
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await notifications.show(
      999999, // ID fijo para emergencias
      title,
      body,
      platformDetails,
      payload: jsonEncode(payload),
    );

    AppLogger.critical('🚨 Notificación de emergencia mostrada', payload);
  } catch (e, stackTrace) {
    AppLogger.error(
        'Error crítico mostrando notificación de emergencia', e, stackTrace);
  }
}

/// Inicializa el handler de mensajería
class FirebaseMessagingHandler {
  static final FirebaseMessagingHandler _instance =
      FirebaseMessagingHandler._internal();
  factory FirebaseMessagingHandler() => _instance;
  FirebaseMessagingHandler._internal();

  /// Configura los handlers de mensajería
  Future<void> initialize() async {
    try {
      // Comment 12: Handle iOS critical alerts with fallback
      if (Platform.isIOS) {
        try {
          // Try to request with critical alerts (requires special entitlement)
          await FirebaseMessaging.instance.requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: true, // Requires special Apple entitlement
            provisional: false,
            sound: true,
          );
        } catch (e) {
          // Fallback to standard permissions if critical alert fails
          AppLogger.warning('Critical alerts not available, using standard permissions', e);
          await FirebaseMessaging.instance.requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false, // Fallback without critical
            provisional: false,
            sound: true,
          );
        }
      }

      // Configurar presentación de notificaciones en primer plano
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Obtener token FCM
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        AppLogger.info('FCM Token obtenido', {'token': token});
        // Aquí podrías enviar el token a tu servidor
      }

      // Escuchar cambios de token
      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
        AppLogger.info('FCM Token actualizado', {'token': newToken});
        // Actualizar token en el servidor
      });

      // Handler para mensajes en primer plano
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handler para cuando el usuario toca la notificación
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Verificar si la app se abrió desde una notificación
      final RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.info('App abierta desde notificación', initialMessage.data);
        _handleNotificationTap(initialMessage);
      }

      AppLogger.info('✅ Firebase Messaging Handler inicializado correctamente');
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error inicializando Firebase Messaging Handler', e, stackTrace);
    }
  }

  /// Maneja mensajes en primer plano
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('📱 Mensaje en primer plano recibido', {
      'messageId': message.messageId,
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
    });

    // Procesar según el tipo de notificación
    _processBackgroundMessage(message);
  }

  /// Maneja cuando el usuario toca una notificación
  void _handleNotificationTap(RemoteMessage message) {
    AppLogger.info('👆 Notificación tocada', message.data);

    // Implement navigation based on notification type
    final String? notificationType = message.data['type'];
    final String? screen = message.data['screen'];
    final String? targetId = message.data['targetId'];
    final String? rideId = message.data['rideId'];

    // Use NavigationHelper to navigate with proper context
    final nav = NavigationHelper.navigatorKey.currentState;

    if (nav != null && screen != null) {
      switch (screen) {
        case 'wallet':
          AppLogger.navigation('notification', '/driver/wallet');
          nav.pushNamed('/driver/wallet');
          break;
        case 'vehicle':
        case 'vehicle_management':
          AppLogger.navigation('notification', '/driver/vehicle-management');
          nav.pushNamed('/driver/vehicle-management');
          break;
        case 'documents':
          AppLogger.navigation('notification', '/driver/documents');
          nav.pushNamed('/driver/documents');
          break;
        case 'chat':
          AppLogger.navigation('notification', '/shared/chat');
          if (rideId != null) {
            nav.pushNamed('/shared/chat', arguments: {'rideId': rideId});
          } else {
            nav.pushNamed('/shared/chat');
          }
          break;
        case 'ride':
        case 'navigation':
          AppLogger.navigation('notification', '/driver/navigation');
          if (rideId != null) {
            nav.pushNamed('/driver/navigation', arguments: {'rideId': rideId});
          } else {
            nav.pushNamed('/driver/navigation');
          }
          break;
        case 'tracking':
          AppLogger.navigation('notification', '/shared/trip-tracking');
          if (rideId != null) {
            nav.pushNamed('/shared/trip-tracking', arguments: rideId);
          } else {
            nav.pushNamed('/shared/trip-tracking');
          }
          break;
        default:
          AppLogger.debug('Unknown screen for navigation', {'screen': screen});
      }
    } else if (notificationType != null && targetId != null) {
      // Legacy navigation support - navigate based on notification type
      AppLogger.debug('Legacy navigation', {
        'type': notificationType,
        'targetId': targetId,
      });

      if (nav != null) {
        // Map legacy notification types to screens
        switch (notificationType) {
          case 'document_expiry':
            nav.pushNamed('/driver/documents');
            break;
          case 'maintenance_reminder':
          case 'custom_reminder':
            nav.pushNamed('/driver/vehicle-management');
            break;
          case 'wallet_transaction':
          case 'withdrawal_status':
            nav.pushNamed('/driver/wallet');
            break;
          default:
            AppLogger.debug('Unknown notification type for navigation', {'type': notificationType});
        }
      }
    }
  }
}

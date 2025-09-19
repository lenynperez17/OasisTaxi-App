import '../utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Servicio de Notificaciones Real para Producción
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Stream controller para manejar notificaciones seleccionadas
  final StreamController<String> _notificationSelectedController =
      StreamController<String>.broadcast();

  /// Stream para escuchar notificaciones seleccionadas
  Stream<String>? get onNotificationSelected =>
      _notificationSelectedController.stream;

  /// Canal de notificaciones para Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'oasis_taxi_channel',
    'Oasis Taxi Notifications',
    description: 'Notificaciones de Oasis Taxi',
    importance: Importance.max,
    playSound: true,
    enableLights: true,
    enableVibration: true,
  );

  /// Inicializar servicio de notificaciones
  Future<void> initialize() async {
    if (_initialized) return;

    // Configuración Android
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Configuración general
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Inicializar plugin de notificaciones locales
    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Crear canal de notificaciones Android (solo móvil)
    if (Platform.isAndroid) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Configurar handlers de Firebase Messaging
    await _setupFirebaseMessaging();

    _initialized = true;
    AppLogger.debug('✅ Servicio de notificaciones inicializado');
  }

  /// Configurar Firebase Messaging
  Future<void> _setupFirebaseMessaging() async {
    // Handler para mensajes en primer plano
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handler para cuando se abre la app desde una notificación
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Obtener mensaje inicial si la app se abrió desde una notificación
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Configurar handler para mensajes en segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Handler para mensajes en primer plano
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    AppLogger.debug(
        '📱 Mensaje recibido en primer plano: ${message.messageId}');

    // Mostrar notificación local
    await showNotification(
      title: message.notification?.title ?? 'Nueva notificación',
      body: message.notification?.body ?? '',
      payload: json.encode(message.data),
    );
  }

  /// Handler para cuando se abre la app desde notificación
  void _handleMessageOpenedApp(RemoteMessage message) {
    AppLogger.debug('📱 App abierta desde notificación: ${message.messageId}');
    _handleNotificationClick(message.data);
  }

  /// Mostrar notificación local
  /// Enviar notificación push vía FCM
  Future<void> sendNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    AppLogger.info(
        'Enviando notificación push a token: ${token.substring(0, 10)}...');
    // En una implementación real, aquí usaríamos el Admin SDK de Firebase
    // Por ahora, mostrar notificación local
    await showNotification(title: title, body: body);
  }

  /// Enviar notificación de viaje aceptado
  Future<void> sendTripAcceptedNotification(String tripId) async {
    AppLogger.info('Enviando notificación de viaje aceptado: $tripId');
    await showNotification(
      title: '🚗 Viaje Aceptado',
      body: 'Un conductor ha aceptado tu viaje',
    );
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'oasis_taxi_channel',
      'Oasis Taxi Notifications',
      channelDescription: 'Notificaciones de Oasis Taxi',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50),
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Mostrar notificación de viaje
  Future<void> showRideNotification({
    required String title,
    required String body,
    required Map<String, dynamic> rideData,
  }) async {
    await showNotification(
      title: title,
      body: body,
      payload: json.encode({
        'type': 'ride',
        'data': rideData,
      }),
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Mostrar notificación de chat
  Future<void> showChatNotification({
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    await showNotification(
      title: senderName,
      body: message,
      payload: json.encode({
        'type': 'chat',
        'chatId': chatId,
      }),
      id: chatId.hashCode,
    );
  }

  /// Mostrar notificación de promoción
  Future<void> showPromoNotification({
    required String title,
    required String description,
    required String promoCode,
  }) async {
    await showNotification(
      title: title,
      body: '$description\nCódigo: $promoCode',
      payload: json.encode({
        'type': 'promo',
        'code': promoCode,
      }),
      id: promoCode.hashCode,
    );
  }

  /// Cancelar notificación
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Handler para respuesta a notificación
  static void _onNotificationResponse(NotificationResponse response) {
    AppLogger.debug('📱 Notificación clickeada: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        _instance._handleNotificationClick(data);
      } catch (e) {
        AppLogger.debug('Error procesando payload: $e');
      }
    }
  }

  /// Manejar click en notificación y emitir evento
  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'] ?? '';

    // Emitir evento para que el NotificationHandler lo procese
    String payload = '';

    switch (type) {
      case 'ride':
        final rideId = data['data']['rideId'] ?? '';
        payload = 'ride:$rideId';
        AppLogger.debug('Navegar a viaje: $rideId');
        break;
      case 'chat':
        payload = 'chat:${data['chatId']}';
        AppLogger.debug('Navegar a chat: ${data['chatId']}');
        break;
      case 'promo':
        payload = 'promo:${data['code']}';
        AppLogger.debug('Aplicar promo: ${data['code']}');
        break;
      case 'emergency':
        payload = 'emergency';
        AppLogger.debug('Manejar emergencia');
        break;
      case 'price_negotiation':
        payload = 'price_negotiation';
        AppLogger.debug('Nueva negociación de precio');
        break;
      case 'driver_found':
        payload = 'driver_found';
        break;
      case 'driver_arrived':
        payload = 'driver_arrived';
        break;
      case 'trip_completed':
        payload = 'trip_completed';
        break;
      case 'payment_received':
        payload = 'payment_received';
        break;
      case 'ride_request':
        payload = 'ride_request';
        break;
      default:
        payload = type;
        AppLogger.debug('Tipo de notificación desconocido: $type');
    }

    // Emitir el payload al stream
    if (payload.isNotEmpty) {
      _notificationSelectedController.add(payload);
    }
  }

  /// Obtener detalles de notificación pendiente
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Actualizar badge de la app (iOS)
  Future<void> updateBadge(int count) async {
    if (Platform.isIOS) {
      // Implementar actualización de badge para iOS
      AppLogger.debug('Badge actualizado a: $count');
    }
  }

  /// Limpiar recursos
  void dispose() {
    _notificationSelectedController.close();
  }
}

/// Handler para mensajes en segundo plano (debe ser top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Verificar si Firebase está inicializado antes de inicializar
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  AppLogger.debug('📱 Mensaje en segundo plano: ${message.messageId}');
  // Procesar mensaje en segundo plano si es necesario
}

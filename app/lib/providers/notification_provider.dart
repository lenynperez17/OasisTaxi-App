import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../services/firebase_service.dart';
import '../services/fcm_service.dart';
import '../models/notification_types.dart';

/// Provider de Notificaciones Real para Producción
class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final FirebaseService _firebaseService = FirebaseService();

  final List<NotificationData> _notifications = [];
  bool _notificationsEnabled = true;
  bool _isLoading = false;
  final Map<String, bool> _subscribedTopics = {
    'all_users': true,
    'app_updates': true,
    'passengers': true,
    'drivers': false,
    'admins': false,
    'passenger_promotions': true,
    'system_alerts': true,
  };

  // Getters
  List<NotificationData> get notifications => List.unmodifiable(_notifications);
  List<NotificationData> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => unreadNotifications.length;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoading => _isLoading;
  Map<String, bool> get subscribedTopics => Map.unmodifiable(_subscribedTopics);
  Map<String, bool> get topicSubscriptions => subscribedTopics;
  String? get fcmToken =>
      _firebaseService.currentUser?.uid; // Token basado en Firebase
  bool get isInitialized => _firebaseService.isInitialized;

  NotificationProvider() {
    _initializeNotifications();
  }

  /// Inicializar notificaciones
  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    await _loadNotificationsFromFirebase();
  }

  /// Cargar notificaciones desde Firebase
  Future<void> _loadNotificationsFromFirebase() async {
    if (!_firebaseService.isInitialized ||
        _firebaseService.currentUser == null) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final userId = _firebaseService.currentUser!.uid;
      // Buscar en colección global de notificaciones para el usuario
      final snapshot = await _firebaseService.firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      _notifications.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _notifications.add(NotificationData(
          id: doc.id,
          title: data['title'] ?? '',
          body: data['body'] ?? '',
          timestamp:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          type: _getNotificationTypeFromString(data['type'] ?? 'system'),
          isRead: data['isRead'] ?? false,
          data: data['data'],
          channel: NotificationChannel.general,
        ));
      }
    } catch (e) {
      AppLogger.debug('Error cargando notificaciones: $e');
      // En caso de error, no mostrar notificaciones de ejemplo
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  NotificationType _getNotificationTypeFromString(String type) {
    switch (type) {
      case 'general':
        return NotificationType.general;
      case 'tripRequest':
        return NotificationType.tripRequest;
      case 'tripAccepted':
        return NotificationType.tripAccepted;
      case 'tripStarted':
        return NotificationType.tripStarted;
      case 'tripCancelled':
        return NotificationType.tripCancelled;
      case 'tripCompleted':
        return NotificationType.tripCompleted;
      case 'driverArrived':
        return NotificationType.driverArrived;
      case 'payment':
        return NotificationType.payment;
      case 'promotion':
        return NotificationType.promotion;
      case 'support':
        return NotificationType.support;
      default:
        return NotificationType.system;
    }
  }

  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }

  /// Agregar nueva notificación
  Future<void> addNotification(NotificationData notification) async {
    _notifications.insert(0, notification);
    notifyListeners();

    // Guardar en Firebase si el usuario está autenticado
    if (_firebaseService.isInitialized &&
        _firebaseService.currentUser != null) {
      try {
        final userId = _firebaseService.currentUser!.uid;
        await _firebaseService.firestore
            .collection('notifications')
            .doc(notification.id)
            .set({
          'userId': userId,
          'title': notification.title,
          'body': notification.body,
          'type': notification.type.toString().split('.').last,
          'timestamp': Timestamp.fromDate(notification.timestamp),
          'isRead': notification.isRead,
          'data': notification.data,
        });
      } catch (e) {
        AppLogger.debug('Error guardando notificación: $e');
      }
    }
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = NotificationData(
        id: _notifications[index].id,
        title: _notifications[index].title,
        body: _notifications[index].body,
        timestamp: _notifications[index].timestamp,
        type: _notifications[index].type,
        isRead: true,
        data: _notifications[index].data,
        channel: NotificationChannel.general,
      );
      notifyListeners();

      // Actualizar en Firebase
      _updateNotificationInFirebase(notificationId, {'isRead': true});
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = NotificationData(
          id: _notifications[i].id,
          title: _notifications[i].title,
          body: _notifications[i].body,
          timestamp: _notifications[i].timestamp,
          type: _notifications[i].type,
          isRead: true,
          data: _notifications[i].data,
          channel: NotificationChannel.general,
        );
      }
    }
    notifyListeners();

    // Actualizar todas en Firebase
    for (var notification in _notifications) {
      _updateNotificationInFirebase(notification.id, {'isRead': true});
    }
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  void clearAllNotifications() {
    clearAll();
    // También eliminar de Firebase si es necesario
  }

  void deleteNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();

    // Eliminar de Firebase
    _deleteNotificationFromFirebase(notificationId);
  }

  void removeNotification(String notificationId) {
    deleteNotification(notificationId);
  }

  void updateTopicSubscription(String topic, bool subscribed) {
    _subscribedTopics[topic] = subscribed;
    notifyListeners();
  }

  void subscribeToTopic(String topic) {
    _subscribedTopics[topic] = true;
    notifyListeners();
  }

  void unsubscribeFromTopic(String topic) {
    _subscribedTopics[topic] = false;
    notifyListeners();
  }

  void sendTestNotification() {
    addNotification(NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Notificación de prueba',
      body: 'Esta es una notificación de prueba del sistema',
      timestamp: DateTime.now(),
      type: NotificationType.system,
      isRead: false,
      channel: NotificationChannel.general,
    ));
  }

  Future<void> _updateNotificationInFirebase(
      String notificationId, Map<String, dynamic> data) async {
    if (_firebaseService.isInitialized &&
        _firebaseService.currentUser != null) {
      try {
        final userId = _firebaseService.currentUser!.uid;
        await _firebaseService.firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(notificationId)
            .update(data);
      } catch (e) {
        AppLogger.debug('Error actualizando notificación: $e');
      }
    }
  }

  Future<void> _deleteNotificationFromFirebase(String notificationId) async {
    if (_firebaseService.isInitialized &&
        _firebaseService.currentUser != null) {
      try {
        final userId = _firebaseService.currentUser!.uid;
        await _firebaseService.firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(notificationId)
            .delete();
      } catch (e) {
        AppLogger.debug('Error eliminando notificación: $e');
      }
    }
  }

  /// Agregar notificación de viaje específica
  Future<void> addTripNotification({
    required String tripId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? tripData,
  }) async {
    final notification = NotificationData(
      id: '${type.toString().split('.').last}_$tripId',
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
      data: {
        'tripId': tripId,
        ...?tripData,
      },
      channel: NotificationChannel.general,
    );

    await addNotification(notification);

    // También mostrar notificación local
    await _notificationService.showRideNotification(
      title: title,
      body: body,
      rideData: {
        'tripId': tripId,
        'type': type.toString(),
        ...?tripData,
      },
    );
  }

  /// Notificar solicitud de viaje recibida (para conductores)
  Future<void> notifyRideRequestReceived({
    required String tripId,
    required String pickupAddress,
    required String destinationAddress,
    required double fare,
    required String passengerName,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.tripRequest,
      title: '¡Nueva solicitud de viaje!',
      body: '$passengerName solicita un viaje desde $pickupAddress',
      tripData: {
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'fare': fare,
        'passengerName': passengerName,
      },
    );
  }

  /// Notificar viaje aceptado (para pasajeros)
  Future<void> notifyRideAccepted({
    required String tripId,
    required String driverName,
    required String vehicleInfo,
    required String estimatedArrival,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.tripAccepted,
      title: '¡Viaje aceptado!',
      body: '$driverName va hacia ti. Llegada estimada: $estimatedArrival',
      tripData: {
        'driverName': driverName,
        'vehicleInfo': vehicleInfo,
        'estimatedArrival': estimatedArrival,
      },
    );
  }

  /// Notificar que el conductor llegó
  Future<void> notifyDriverArrived({
    required String tripId,
    required String driverName,
    required String verificationCode,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.driverArrived,
      title: '¡Tu conductor ha llegado!',
      body: '$driverName está esperándote. Código: $verificationCode',
      tripData: {
        'driverName': driverName,
        'verificationCode': verificationCode,
      },
    );
  }

  /// Notificar viaje iniciado
  Future<void> notifyTripStarted({
    required String tripId,
    required String destinationAddress,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.tripStarted,
      title: '¡Viaje iniciado!',
      body: 'En camino a $destinationAddress',
      tripData: {
        'destinationAddress': destinationAddress,
      },
    );
  }

  /// Notificar viaje completado
  Future<void> notifyTripCompleted({
    required String tripId,
    required double totalFare,
    required String paymentMethod,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.tripCompleted,
      title: '¡Viaje completado!',
      body: 'Total: \$${totalFare.toStringAsFixed(2)} - $paymentMethod',
      tripData: {
        'totalFare': totalFare,
        'paymentMethod': paymentMethod,
      },
    );
  }

  /// Notificar viaje cancelado
  Future<void> notifyTripCancelled({
    required String tripId,
    required String reason,
    required String cancelledBy,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.tripCancelled,
      title: 'Viaje cancelado',
      body: 'Cancelado por $cancelledBy. Motivo: $reason',
      tripData: {
        'reason': reason,
        'cancelledBy': cancelledBy,
      },
    );
  }

  /// Actualizar token FCM del usuario actual
  Future<void> updateUserFCMToken() async {
    try {
      final token = await FCMService.getDeviceFCMToken();
      if (token != null && _firebaseService.currentUser != null) {
        await _firebaseService.firestore
            .collection('users')
            .doc(_firebaseService.currentUser!.uid)
            .update({'fcmToken': token});

        AppLogger.debug(
            '✅ Token FCM actualizado para usuario: ${_firebaseService.currentUser!.uid}');
      }
    } catch (e) {
      AppLogger.error('Error actualizando token FCM: $e');
    }
  }

  /// Suscribirse a tópicos según tipo de usuario
  Future<void> subscribeToUserTypeTopics(String userType) async {
    try {
      // Tópicos base para todos los usuarios
      await FCMService.subscribeToTopic('all_users');
      await FCMService.subscribeToTopic('app_updates');

      // Tópicos específicos por tipo de usuario
      switch (userType) {
        case 'passenger':
          await FCMService.subscribeToTopic('passengers');
          await FCMService.subscribeToTopic('passenger_promotions');
          await FCMService.unsubscribeFromTopic('drivers');
          break;
        case 'driver':
          await FCMService.subscribeToTopic('drivers');
          await FCMService.subscribeToTopic('driver_updates');
          await FCMService.unsubscribeFromTopic('passengers');
          await FCMService.unsubscribeFromTopic('passenger_promotions');
          break;
        case 'admin':
          await FCMService.subscribeToTopic('admins');
          await FCMService.subscribeToTopic('system_alerts');
          break;
      }

      AppLogger.debug('✅ Suscrito a tópicos para tipo de usuario: $userType');
    } catch (e) {
      AppLogger.error('Error suscribiendo a tópicos: $e');
    }
  }

  /// Obtener estadísticas de notificaciones
  Map<String, int> getNotificationStats() {
    return {
      'total': _notifications.length,
      'unread': unreadCount,
      'tripRequests': _notifications
          .where((n) => n.type == NotificationType.tripRequest)
          .length,
      'tripUpdates': _notifications
          .where((n) =>
              n.type == NotificationType.tripAccepted ||
              n.type == NotificationType.tripStarted ||
              n.type == NotificationType.driverArrived ||
              n.type == NotificationType.tripCompleted)
          .length,
      'promotions': _notifications
          .where((n) => n.type == NotificationType.promotion)
          .length,
    };
  }

  /// Limpiar notificaciones antiguas (más de 30 días)
  Future<void> cleanupOldNotifications() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final oldNotifications = _notifications
          .where((n) => n.timestamp.isBefore(cutoffDate))
          .toList();

      for (final notification in oldNotifications) {
        await _deleteNotificationFromFirebase(notification.id);
        _notifications.remove(notification);
      }

      if (oldNotifications.isNotEmpty) {
        AppLogger.debug(
            '🧹 Limpiadas ${oldNotifications.length} notificaciones antiguas');
        notifyListeners();
      }
    } catch (e) {
      AppLogger.debug('Error limpiando notificaciones antiguas: $e');
    }
  }
}

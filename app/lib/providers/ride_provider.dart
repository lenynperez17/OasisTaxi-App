import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/firebase_service.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';

/// Provider de Viajes Real con Firebase
class RideProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FCMService _fcmService = FCMService();
  final NotificationService _notificationService = NotificationService();
  
  TripModel? _currentTrip;
  List<TripModel> _tripHistory = [];
  List<UserModel> _nearbyDrivers = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Estados del viaje
  TripStatus _tripStatus = TripStatus.none;
  
  // Getters
  TripModel? get currentTrip => _currentTrip;
  List<TripModel> get tripHistory => _tripHistory;
  List<UserModel> get nearbyDrivers => _nearbyDrivers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TripStatus get tripStatus => _tripStatus;
  bool get hasActiveTrip => _currentTrip != null && 
    (_tripStatus == TripStatus.requested || 
     _tripStatus == TripStatus.accepted || 
     _tripStatus == TripStatus.driverArriving ||
     _tripStatus == TripStatus.inProgress);

  /// Buscar conductores cercanos
  Future<void> searchNearbyDrivers(LatLng userLocation, double radiusKm) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Calcular bounds aproximados
      double latRange = radiusKm / 111.0; // 1 grado ≈ 111 km
      double lngRange = radiusKm / (111.0 * cos(userLocation.latitude * pi / 180));

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'driver')
          .where('isActive', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .where('location.lat', isGreaterThan: userLocation.latitude - latRange)
          .where('location.lat', isLessThan: userLocation.latitude + latRange)
          .get();

      _nearbyDrivers = query.docs
          .map((doc) => UserModel.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .where((driver) {
            // Filtrar por longitud y distancia real
            if (driver.location == null) return false;
            
            double driverLng = driver.location!.longitude;
            if (driverLng < userLocation.longitude - lngRange ||
                driverLng > userLocation.longitude + lngRange) {
              return false;
            }
            
            double distance = _calculateDistance(userLocation, driver.location!);
            return distance <= radiusKm * 1000; // Convertir a metros
          })
          .toList();

      debugPrint('🚗 Conductores encontrados: ${_nearbyDrivers.length}');
      
      await _firebaseService.logEvent('drivers_searched', {
        'count': _nearbyDrivers.length,
        'radius_km': radiusKm,
      });

    } catch (e) {
      _errorMessage = 'Error buscando conductores: $e';
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Solicitar viaje
  Future<bool> requestRide({
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required String pickupAddress,
    required String destinationAddress,
    required String userId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Crear documento del viaje
      final tripData = {
        'userId': userId,
        'pickupLocation': {
          'lat': pickupLocation.latitude,
          'lng': pickupLocation.longitude,
        },
        'destinationLocation': {
          'lat': destinationLocation.latitude,
          'lng': destinationLocation.longitude,
        },
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'status': 'requested',
        'requestedAt': FieldValue.serverTimestamp(),
        'estimatedDistance': _calculateDistance(pickupLocation, destinationLocation),
        'estimatedFare': _calculateFare(pickupLocation, destinationLocation),
        'driverId': null,
        'vehicleInfo': null,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('trips')
          .add(tripData);

      // Crear el modelo del viaje
      _currentTrip = TripModel.fromJson({
        'id': docRef.id,
        ...tripData,
        'requestedAt': DateTime.now().toIso8601String(),
      });

      _tripStatus = TripStatus.requested;

      // Notificar a conductores cercanos
      await _notifyNearbyDrivers(pickupLocation, docRef.id);

      await _firebaseService.logEvent('ride_requested', {
        'trip_id': docRef.id,
        'pickup_lat': pickupLocation.latitude,
        'pickup_lng': pickupLocation.longitude,
        'destination_lat': destinationLocation.latitude,
        'destination_lng': destinationLocation.longitude,
      });

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = 'Error solicitando viaje: $e';
      await _firebaseService.recordError(e, null);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancelar viaje
  Future<bool> cancelRide() async {
    if (_currentTrip == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(_currentTrip!.id)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'passenger',
      });

      await _firebaseService.logEvent('ride_cancelled', {
        'trip_id': _currentTrip!.id,
        'cancelled_by': 'passenger',
      });

      _currentTrip = null;
      _tripStatus = TripStatus.cancelled;
      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = 'Error cancelando viaje: $e';
      await _firebaseService.recordError(e, null);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Calificar viaje
  Future<bool> rateTrip(String tripId, double rating, String? comment) async {
    _isLoading = true;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .update({
        'passengerRating': rating,
        'passengerComment': comment,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      await _firebaseService.logEvent('trip_rated', {
        'trip_id': tripId,
        'rating': rating,
        'has_comment': comment != null && comment.isNotEmpty,
      });

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = 'Error calificando viaje: $e';
      await _firebaseService.recordError(e, null);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtener historial de viajes
  Future<void> loadTripHistory(String userId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .orderBy('requestedAt', descending: true)
          .limit(50)
          .get();

      _tripHistory = query.docs
          .map((doc) => TripModel.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();

      notifyListeners();

    } catch (e) {
      debugPrint('Error cargando historial: $e');
      await _firebaseService.recordError(e, null);
    }
  }

  /// Escuchar cambios del viaje actual
  StreamSubscription<DocumentSnapshot>? _tripSubscription;
  
  void listenToCurrentTrip() {
    if (_currentTrip == null) return;

    _tripSubscription?.cancel();
    _tripSubscription = FirebaseFirestore.instance
        .collection('trips')
        .doc(_currentTrip!.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        
        _currentTrip = TripModel.fromJson({
          'id': snapshot.id,
          ...data,
        });

        _updateTripStatus(data['status']);
        notifyListeners();
      }
    });
  }

  /// Actualizar estado del viaje
  void _updateTripStatus(String status) {
    switch (status) {
      case 'requested':
        _tripStatus = TripStatus.requested;
        break;
      case 'accepted':
        _tripStatus = TripStatus.accepted;
        break;
      case 'driver_arriving':
        _tripStatus = TripStatus.driverArriving;
        break;
      case 'in_progress':
        _tripStatus = TripStatus.inProgress;
        break;
      case 'completed':
        _tripStatus = TripStatus.completed;
        break;
      case 'cancelled':
        _tripStatus = TripStatus.cancelled;
        break;
      default:
        _tripStatus = TripStatus.none;
    }
  }

  /// Calcular distancia entre dos puntos
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // metros
    double lat1Rad = start.latitude * pi / 180;
    double lat2Rad = end.latitude * pi / 180;
    double deltaLatRad = (end.latitude - start.latitude) * pi / 180;
    double deltaLngRad = (end.longitude - start.longitude) * pi / 180;

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calcular tarifa estimada
  double _calculateFare(LatLng start, LatLng end) {
    double distanceKm = _calculateDistance(start, end) / 1000;
    
    // Tarifa base + por km
    double baseFare = 25.0; // MXN
    double perKmRate = 8.5; // MXN por km
    
    return baseFare + (distanceKm * perKmRate);
  }

  /// Notificar a conductores cercanos con FCM real
  Future<void> _notifyNearbyDrivers(LatLng location, String tripId) async {
    try {
      if (_nearbyDrivers.isEmpty) {
        debugPrint('⚠️ No hay conductores cercanos para notificar');
        return;
      }

      // Obtener información del viaje actual
      if (_currentTrip == null) {
        debugPrint('❌ No hay viaje actual para notificar');
        return;
      }

      // Filtrar conductores con token FCM válido
      final validDrivers = _nearbyDrivers
          .where((driver) => FCMService.isValidFCMToken(driver.fcmToken))
          .toList();

      if (validDrivers.isEmpty) {
        debugPrint('⚠️ No hay conductores con tokens FCM válidos');
        return;
      }

      debugPrint('📧 Enviando notificaciones a ${validDrivers.length} conductores');

      // Enviar notificaciones en paralelo usando el servicio FCM
      final successfulTokens = await _fcmService.sendRideNotificationToMultipleDrivers(
        drivers: validDrivers,
        tripId: tripId,
        pickupAddress: _currentTrip!.pickupAddress,
        destinationAddress: _currentTrip!.destinationAddress,
        estimatedFare: _currentTrip!.estimatedFare,
        estimatedDistance: _currentTrip!.estimatedDistance,
        passengerName: await _getPassengerName(),
      );

      // Registrar resultados
      final successCount = successfulTokens.length;
      final failureCount = validDrivers.length - successCount;

      debugPrint('✅ Notificaciones enviadas: $successCount exitosas, $failureCount fallidas');

      // Actualizar métricas en Firebase
      await _updateNotificationMetrics(tripId, successCount, failureCount);

      // Crear notificación local para el pasajero
      await _createLocalNotificationForPassenger(successCount);

    } catch (e) {
      debugPrint('❌ Error enviando notificaciones a conductores: $e');
      await _firebaseService.recordError(e, StackTrace.current);
    }
  }

  /// Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Generar código de verificación de 4 dígitos
  String _generateVerificationCode() {
    final random = Random();
    String code = '';
    for (int i = 0; i < 4; i++) {
      code += random.nextInt(10).toString();
    }
    return code;
  }

  /// Crear viaje con código de verificación
  Future<TripModel?> createTripWithVerification({
    required String userId,
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required String pickupAddress,
    required String destinationAddress,
    required double estimatedDistance,
    required double estimatedFare,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final verificationCode = _generateVerificationCode();
      
      final tripData = {
        'userId': userId,
        'pickupLocation': {
          'lat': pickupLocation.latitude,
          'lng': pickupLocation.longitude,
        },
        'destinationLocation': {
          'lat': destinationLocation.latitude,
          'lng': destinationLocation.longitude,
        },
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'status': 'requested',
        'requestedAt': FieldValue.serverTimestamp(),
        'estimatedDistance': estimatedDistance,
        'estimatedFare': estimatedFare,
        'verificationCode': verificationCode,
        'isVerificationCodeUsed': false,
      };

      final docRef = await _firebaseService.firestore
          .collection('trips')
          .add(tripData);

      // Obtener el documento creado
      final doc = await docRef.get();
      final trip = TripModel.fromJson({
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
        'requestedAt': DateTime.now().toIso8601String(),
      });

      _currentTrip = trip;
      _tripStatus = TripStatus.requested;
      _isLoading = false;
      notifyListeners();

      debugPrint('✅ Viaje creado con código de verificación: $verificationCode');
      return trip;
    } catch (e) {
      _errorMessage = 'Error creando viaje: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error creando viaje: $e');
      return null;
    }
  }

  /// Verificar código de verificación del conductor
  Future<bool> verifyTripCode(String tripId, String enteredCode) async {
    try {
      _isLoading = true;
      notifyListeners();

      final tripDoc = await _firebaseService.firestore
          .collection('trips')
          .doc(tripId)
          .get();

      if (!tripDoc.exists) {
        throw Exception('Viaje no encontrado');
      }

      final tripData = tripDoc.data() as Map<String, dynamic>;
      final correctCode = tripData['verificationCode'];
      final isCodeUsed = tripData['isVerificationCodeUsed'] ?? false;

      if (isCodeUsed) {
        _errorMessage = 'Este código ya fue utilizado';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (enteredCode == correctCode) {
        // Código correcto - marcar como usado y actualizar estado
        await _firebaseService.firestore
            .collection('trips')
            .doc(tripId)
            .update({
          'isVerificationCodeUsed': true,
          'status': 'in_progress',
          'startedAt': FieldValue.serverTimestamp(),
        });

        // Actualizar el trip local
        if (_currentTrip?.id == tripId) {
          _currentTrip = _currentTrip!.copyWith(
            status: 'in_progress',
            isVerificationCodeUsed: true,
            startedAt: DateTime.now(),
          );
          _tripStatus = TripStatus.inProgress;
        }

        _isLoading = false;
        notifyListeners();
        
        debugPrint('✅ Código verificado correctamente para viaje: $tripId');
        return true;
      } else {
        _errorMessage = 'Código de verificación incorrecto';
        _isLoading = false;
        notifyListeners();
        
        debugPrint('❌ Código incorrecto para viaje: $tripId');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error verificando código: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error verificando código: $e');
      return false;
    }
  }

  /// Obtener código de verificación del viaje actual
  String? get currentTripVerificationCode {
    return _currentTrip?.verificationCode;
  }

  /// Verificar si el código del viaje actual ya fue usado
  bool get isCurrentTripCodeUsed {
    return _currentTrip?.isVerificationCodeUsed ?? false;
  }

  /// Actualizar estado del viaje cuando el conductor llega
  Future<void> markDriverArrived(String tripId) async {
    try {
      await _firebaseService.firestore
          .collection('trips')
          .doc(tripId)
          .update({
        'status': 'driver_arriving',
        'arrivedAt': FieldValue.serverTimestamp(),
      });

      if (_currentTrip?.id == tripId) {
        _currentTrip = _currentTrip!.copyWith(
          status: 'driver_arriving',
        );
        _tripStatus = TripStatus.driverArriving;
        notifyListeners();
      }

      debugPrint('✅ Conductor marcado como llegado para viaje: $tripId');
    } catch (e) {
      debugPrint('❌ Error marcando conductor como llegado: $e');
    }
  }

  /// Obtener historial de viajes del usuario
  Future<List<TripModel>> getUserTripHistory(String userId) async {
    try {
      final query = await _firebaseService.firestore
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .orderBy('requestedAt', descending: true)
          .limit(50)
          .get();

      return query.docs
          .map((doc) => TripModel.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo historial de usuario: $e');
      return [];
    }
  }

  /// Obtener historial de viajes del conductor
  Future<List<TripModel>> getDriverTripHistory(
    String driverId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firebaseService.firestore
          .collection('trips')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed');

      if (startDate != null) {
        query = query.where('completedAt', isGreaterThanOrEqualTo: startDate);
      }
      
      if (endDate != null) {
        query = query.where('completedAt', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query
          .orderBy('completedAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => TripModel.fromJson({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo historial del conductor: $e');
      return [];
    }
  }

  /// Obtener nombre del pasajero actual
  Future<String> _getPassengerName() async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        final userDoc = await _firebaseService.firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          return userData['fullName'] ?? 'Pasajero';
        }
      }
      return 'Pasajero';
    } catch (e) {
      debugPrint('Error obteniendo nombre del pasajero: $e');
      return 'Pasajero';
    }
  }

  /// Actualizar métricas de notificaciones en Firebase
  Future<void> _updateNotificationMetrics(String tripId, int successCount, int failureCount) async {
    try {
      await _firebaseService.firestore
          .collection('trips')
          .doc(tripId)
          .update({
        'notificationMetrics': {
          'driversNotified': successCount + failureCount,
          'successfulNotifications': successCount,
          'failedNotifications': failureCount,
          'notifiedAt': FieldValue.serverTimestamp(),
        }
      });

      // Registrar evento para analytics
      await _firebaseService.logEvent('driver_notifications_sent', {
        'trip_id': tripId,
        'drivers_notified': successCount + failureCount,
        'successful': successCount,
        'failed': failureCount,
      });
    } catch (e) {
      debugPrint('Error actualizando métricas de notificaciones: $e');
    }
  }

  /// Crear notificación local para el pasajero
  Future<void> _createLocalNotificationForPassenger(int driversNotified) async {
    try {
      String message;
      if (driversNotified > 0) {
        message = driversNotified == 1 
            ? 'Se ha notificado a 1 conductor cercano'
            : 'Se ha notificado a $driversNotified conductores cercanos';
      } else {
        message = 'No se pudieron enviar notificaciones a conductores';
      }

      await _notificationService.showNotification(
        title: 'Buscando conductor...',
        body: message,
        payload: 'searching_driver',
      );
    } catch (e) {
      debugPrint('Error creando notificación local: $e');
    }
  }

  /// Enviar notificación de cambio de estado del viaje
  Future<void> sendTripStatusNotification({
    required String fcmToken,
    required String status,
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_currentTrip == null) return;

    try {
      await _fcmService.sendTripStatusNotification(
        userFcmToken: fcmToken,
        tripId: _currentTrip!.id,
        status: status,
        additionalData: additionalData,
      );
    } catch (e) {
      debugPrint('Error enviando notificación de estado: $e');
      await _firebaseService.recordError(e, StackTrace.current);
    }
  }

  /// Obtener estadísticas de notificaciones para un viaje
  Future<Map<String, int>?> getTripNotificationStats(String tripId) async {
    try {
      final tripDoc = await _firebaseService.firestore
          .collection('trips')
          .doc(tripId)
          .get();

      if (tripDoc.exists) {
        final data = tripDoc.data() as Map<String, dynamic>;
        final metrics = data['notificationMetrics'] as Map<String, dynamic>?;
        
        if (metrics != null) {
          return {
            'driversNotified': metrics['driversNotified'] ?? 0,
            'successfulNotifications': metrics['successfulNotifications'] ?? 0,
            'failedNotifications': metrics['failedNotifications'] ?? 0,
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo estadísticas de notificaciones: $e');
      return null;
    }
  }

  /// Reenviar notificaciones a conductores (en caso de no recibir respuesta)
  Future<void> resendNotificationsToDrivers() async {
    if (_currentTrip == null || _tripStatus != TripStatus.requested) {
      debugPrint('No se puede reenviar notificaciones: no hay viaje activo');
      return;
    }

    try {
      debugPrint('🔄 Reenviando notificaciones a conductores...');
      
      // Buscar nuevos conductores cercanos si es necesario
      if (_nearbyDrivers.isEmpty) {
        final pickupLocation = LatLng(
          _currentTrip!.pickupLocation.latitude,
          _currentTrip!.pickupLocation.longitude,
        );
        await searchNearbyDrivers(pickupLocation, 5.0); // 5km radius
      }

      // Reenviar notificaciones
      await _notifyNearbyDrivers(
        LatLng(
          _currentTrip!.pickupLocation.latitude,
          _currentTrip!.pickupLocation.longitude,
        ),
        _currentTrip!.id,
      );

      await _firebaseService.logEvent('notifications_resent', {
        'trip_id': _currentTrip!.id,
        'drivers_count': _nearbyDrivers.length,
      });

    } catch (e) {
      debugPrint('Error reenviando notificaciones: $e');
      await _firebaseService.recordError(e, StackTrace.current);
    }
  }

  /// Limpiar tokens FCM inválidos (mantenimiento)
  Future<void> cleanupInvalidFCMTokens() async {
    try {
      await _fcmService.cleanupInvalidTokens();
    } catch (e) {
      debugPrint('Error limpiando tokens FCM: $e');
    }
  }

  /// Actualizar calificación del viaje
  Future<void> updateTripRating(String tripId, String userId, double rating, String comment, List<String> tags) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Actualizar calificación en Firebase
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .update({
        'rating': rating,
        'comment': comment,
        'tags': tags,
        'ratingSubmittedAt': FieldValue.serverTimestamp(),
        'ratingSubmittedBy': userId,
      });

      // También crear registro en la subcolección de calificaciones
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('ratings')
          .doc(userId)
          .set({
        'userId': userId,
        'rating': rating,
        'comment': comment,
        'tags': tags,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Registrar evento para analytics
      await _firebaseService.logEvent('trip_rated', {
        'trip_id': tripId,
        'rating': rating,
        'has_comment': comment.isNotEmpty,
        'tags_count': tags.length,
      });

      // Actualizar trip en la lista local si está disponible
      final tripIndex = _tripHistory.indexWhere((trip) => trip.id == tripId);
      if (tripIndex != -1) {
        _tripHistory[tripIndex] = _tripHistory[tripIndex].copyWith(
          passengerRating: rating,
          passengerComment: comment,
        );
      }

      debugPrint('Calificación actualizada: $rating estrellas para viaje $tripId');
      
    } catch (e) {
      debugPrint('Error actualizando calificación: $e');
      _errorMessage = 'Error al guardar calificación: $e';
      await _firebaseService.recordError(e, StackTrace.current);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    super.dispose();
  }
}

/// Estados del viaje
enum TripStatus {
  none,
  requested,
  accepted,
  driverArriving,
  inProgress,
  completed,
  cancelled,
}
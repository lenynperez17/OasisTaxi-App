import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';
import 'dart:async';
import 'dart:math' as math;

/// Servicio completo de base de datos Firestore para OasisTaxi Perú
/// Gestiona todas las operaciones CRUD, consultas, transacciones y listeners
class FirestoreDatabaseService {
  static final FirestoreDatabaseService _instance =
      FirestoreDatabaseService._internal();
  factory FirestoreDatabaseService() => _instance;
  FirestoreDatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _subscriptions = {};

  // Colecciones principales
  static const String usersCollection = 'users';
  static const String driversCollection = 'drivers';
  static const String tripsCollection = 'trips';
  static const String vehiclesCollection = 'vehicles';
  static const String paymentsCollection = 'payments';
  static const String priceNegotiationsCollection = 'price_negotiations';
  static const String emergenciesCollection = 'emergencies';
  static const String documentsCollection = 'documents';
  static const String ratingsCollection = 'ratings';
  static const String walletsCollection = 'wallets';
  static const String notificationsCollection = 'notifications';
  static const String chatMessagesCollection = 'chat_messages';
  static const String adminLogsCollection = 'admin_logs';
  static const String configCollection = 'config';
  static const String analyticsCollection = 'analytics';
  static const String promotionsCollection = 'promotions';
  static const String vehicleTypesCollection = 'vehicle_types';
  static const String zonesCollection = 'zones';
  static const String reportsCollection = 'reports';
  static const String transactionsCollection = 'transactions';

  // ==================== CONFIGURACIÓN INICIAL ====================

  /// Inicializa el servicio y configura índices
  Future<void> initialize() async {
    try {
      AppLogger.info('Inicializando Firestore Database Service');

      // Configurar persistencia offline - v6.0.1 ya no usa enablePersistence
      // La persistencia ahora se maneja autom\u00e1ticamente en Firestore v6+
      // Solo configuramos los settings de cache si es necesario
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Configurar configuración inicial si no existe
      await _ensureInitialConfig();

      AppLogger.info('Firestore Database Service inicializado');
    } catch (e) {
      AppLogger.error('Error inicializando Firestore', e);
    }
  }

  /// Asegura que existe la configuración inicial
  Future<void> _ensureInitialConfig() async {
    try {
      final configDoc =
          await _firestore.collection(configCollection).doc('general').get();

      if (!configDoc.exists) {
        await _firestore.collection(configCollection).doc('general').set({
          'appName': 'OasisTaxi Perú',
          'version': '1.0.0',
          'commission': 0.20, // 20% comisión
          'currency': 'PEN',
          'country': 'PE',
          'emergencyPhone': '105', // Policía Perú
          'supportEmail': 'soporte@oasistaxiperu.com',
          'minTripPrice': 5.0,
          'maxTripPrice': 500.0,
          'pricePerKm': 2.5,
          'pricePerMinute': 0.5,
          'baseFare': 5.0,
          'peakHourMultiplier': 1.5,
          'nightMultiplier': 1.3,
          'cancellationFee': 5.0,
          'maxNegotiationAttempts': 3,
          'driverSearchRadius': 5000, // metros
          'tripRequestTimeout': 120, // segundos
          'maintenanceMode': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      AppLogger.error('Error configurando config inicial', e);
    }
  }

  // ==================== OPERACIONES DE USUARIOS ====================

  /// Crea un nuevo usuario
  Future<String?> createUser({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String userType,
    String? photoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      AppLogger.info('Creando usuario: $uid');

      final userData = {
        'uid': uid,
        'email': email,
        'name': name,
        'phone': phone,
        'userType': userType,
        'photoUrl': photoUrl,
        'isActive': true,
        'isVerified': false,
        'rating': 0.0,
        'totalTrips': 0,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'deviceTokens': [],
        'preferredLanguage': 'es',
        'preferredPaymentMethod': 'cash',
        ...?additionalData,
      };

      await _firestore.collection(usersCollection).doc(uid).set(userData);

      // Crear wallet para el usuario
      await _createUserWallet(uid, userType);

      // Si es conductor, crear documento en colección drivers
      if (userType == 'driver') {
        await _createDriverProfile(uid, name, email, phone);
      }

      AppLogger.info('Usuario creado exitosamente: $uid');
      return uid;
    } catch (e) {
      AppLogger.error('Error creando usuario', e);
      return null;
    }
  }

  /// Obtiene datos de un usuario
  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(usersCollection).doc(uid).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      AppLogger.error('Error obteniendo usuario: $uid', e);
      return null;
    }
  }

  /// Obtiene un documento genérico de cualquier colección
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(documentId).get();
      return doc;
    } catch (e) {
      AppLogger.error('Error obteniendo documento: $collection/$documentId', e);
      rethrow;
    }
  }

  /// Actualiza datos de usuario
  Future<bool> updateUser(String uid, Map<String, dynamic> updates) async {
    try {
      updates['lastActive'] = FieldValue.serverTimestamp();
      await _firestore.collection(usersCollection).doc(uid).update(updates);
      AppLogger.info('Usuario actualizado: $uid');
      return true;
    } catch (e) {
      AppLogger.error('Error actualizando usuario', e);
      return false;
    }
  }

  /// Busca usuarios por criterios
  Future<List<Map<String, dynamic>>> searchUsers({
    String? name,
    String? email,
    String? phone,
    String? userType,
    bool? isActive,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore.collection(usersCollection);

      if (userType != null) {
        query = query.where('userType', isEqualTo: userType);
      }
      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }
      if (phone != null) {
        query = query.where('phone', isEqualTo: phone);
      }
      if (email != null) {
        query = query.where('email', isEqualTo: email);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      final users = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();

      // Filtrar por nombre si se proporciona (no se puede hacer en query)
      if (name != null && name.isNotEmpty) {
        return users.where((user) {
          final userName = (user['name'] as String).toLowerCase();
          return userName.contains(name.toLowerCase());
        }).toList();
      }

      return users;
    } catch (e) {
      AppLogger.error('Error buscando usuarios', e);
      return [];
    }
  }

  // ==================== OPERACIONES DE CONDUCTORES ====================

  /// Crea perfil de conductor
  Future<void> _createDriverProfile(
    String uid,
    String name,
    String email,
    String phone,
  ) async {
    try {
      await _firestore.collection(driversCollection).doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'status': 'pending_verification',
        'isOnline': false,
        'isAvailable': false,
        'currentLocation': null,
        'currentTripId': null,
        'vehicleId': null,
        'rating': 0.0,
        'totalTrips': 0,
        'totalEarnings': 0.0,
        'documentsVerified': false,
        'licenseNumber': null,
        'licenseExpiry': null,
        'vehiclePlate': null,
        'vehicleModel': null,
        'vehicleYear': null,
        'vehicleColor': null,
        'bankAccount': null,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastLocationUpdate': null,
      });
    } catch (e) {
      AppLogger.error('Error creando perfil de conductor', e);
    }
  }

  /// Obtiene conductores disponibles cerca de una ubicación
  Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
    String? vehicleType,
    int limit = 10,
  }) async {
    try {
      // Calcular límites de búsqueda (aproximación simple)
      final latDelta = radiusKm / 111; // 1 grado ≈ 111 km
      final lonDelta =
          radiusKm / (111 * 0.87); // Ajuste para Perú (latitud ~-12°)

      Query query = _firestore
          .collection(driversCollection)
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .where('documentsVerified', isEqualTo: true);

      // Filtrar por tipo de vehículo si se especifica
      if (vehicleType != null) {
        query = query.where('vehicleType', isEqualTo: vehicleType);
      }

      final snapshot =
          await query.limit(limit * 2).get(); // Obtener más para filtrar

      final drivers = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final location = data['currentLocation'] as Map<String, dynamic>?;

        if (location != null) {
          final driverLat = location['latitude'] as double;
          final driverLon = location['longitude'] as double;

          // Verificar si está dentro del radio
          if ((driverLat - latitude).abs() <= latDelta &&
              (driverLon - longitude).abs() <= lonDelta) {
            // Calcular distancia real
            final distance = _calculateDistance(
              latitude,
              longitude,
              driverLat,
              driverLon,
            );

            if (distance <= radiusKm) {
              drivers.add({
                'id': doc.id,
                'distance': distance,
                ...data,
              });
            }
          }
        }
      }

      // Ordenar por distancia
      drivers.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      return drivers.take(limit).toList();
    } catch (e) {
      AppLogger.error('Error obteniendo conductores cercanos', e);
      return [];
    }
  }

  /// Actualiza ubicación del conductor
  Future<bool> updateDriverLocation(
    String driverId,
    double latitude,
    double longitude, {
    double? heading,
    double? speed,
  }) async {
    try {
      await _firestore.collection(driversCollection).doc(driverId).update({
        'currentLocation': {
          'latitude': latitude,
          'longitude': longitude,
          'heading': heading,
          'speed': speed,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      AppLogger.error('Error actualizando ubicación del conductor', e);
      return false;
    }
  }

  /// Actualiza estado del conductor (online/offline, disponible/ocupado)
  Future<bool> updateDriverStatus(
    String driverId, {
    bool? isOnline,
    bool? isAvailable,
    String? currentTripId,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (isOnline != null) updates['isOnline'] = isOnline;
      if (isAvailable != null) updates['isAvailable'] = isAvailable;
      if (currentTripId != null) updates['currentTripId'] = currentTripId;

      updates['lastStatusUpdate'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(driversCollection)
          .doc(driverId)
          .update(updates);

      AppLogger.info('Estado del conductor actualizado: $driverId');
      return true;
    } catch (e) {
      AppLogger.error('Error actualizando estado del conductor', e);
      return false;
    }
  }

  // ==================== OPERACIONES DE VIAJES ====================

  /// Crea una nueva solicitud de viaje
  Future<String?> createTripRequest({
    required String passengerId,
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> destination,
    required String vehicleType,
    required double estimatedPrice,
    String paymentMethod = 'cash',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      AppLogger.info('Creando solicitud de viaje para: $passengerId');

      final tripData = {
        'passengerId': passengerId,
        'driverId': null,
        'status': 'searching_driver',
        'pickup': pickup,
        'destination': destination,
        'vehicleType': vehicleType,
        'estimatedPrice': estimatedPrice,
        'finalPrice': null,
        'paymentMethod': paymentMethod,
        'distance': null,
        'duration': null,
        'route': [],
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': null,
        'startedAt': null,
        'completedAt': null,
        'cancelledAt': null,
        'cancelledBy': null,
        'cancellationReason': null,
        'rating': null,
        'driverRating': null,
        'passengerRating': null,
        'verificationCode': _generateVerificationCode(),
        ...?additionalData,
      };

      final docRef = await _firestore.collection(tripsCollection).add(tripData);

      AppLogger.info('Viaje creado: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Error creando viaje', e);
      return null;
    }
  }

  /// Acepta una solicitud de viaje (conductor)
  Future<bool> acceptTrip(String tripId, String driverId) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final tripDoc = await transaction
            .get(_firestore.collection(tripsCollection).doc(tripId));

        if (!tripDoc.exists) {
          throw Exception('Viaje no encontrado');
        }

        final tripData = tripDoc.data()!;

        if (tripData['status'] != 'searching_driver') {
          throw Exception('El viaje ya no está disponible');
        }

        // Actualizar viaje
        transaction.update(tripDoc.reference, {
          'driverId': driverId,
          'status': 'driver_assigned',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // Actualizar estado del conductor
        transaction.update(
          _firestore.collection(driversCollection).doc(driverId),
          {
            'isAvailable': false,
            'currentTripId': tripId,
          },
        );

        AppLogger.info('Viaje aceptado: $tripId por conductor: $driverId');
        return true;
      });
    } catch (e) {
      AppLogger.error('Error aceptando viaje', e);
      return false;
    }
  }

  /// Inicia un viaje
  Future<bool> startTrip(String tripId) async {
    try {
      await _firestore.collection(tripsCollection).doc(tripId).update({
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Viaje iniciado: $tripId');
      return true;
    } catch (e) {
      AppLogger.error('Error iniciando viaje', e);
      return false;
    }
  }

  /// Completa un viaje
  Future<bool> completeTrip(
    String tripId, {
    required double finalPrice,
    required double distance,
    required int duration,
    List<Map<String, dynamic>>? route,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final tripDoc = await transaction
            .get(_firestore.collection(tripsCollection).doc(tripId));

        if (!tripDoc.exists) {
          throw Exception('Viaje no encontrado');
        }

        final tripData = tripDoc.data()!;
        final driverId = tripData['driverId'];

        // Actualizar viaje
        transaction.update(tripDoc.reference, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'finalPrice': finalPrice,
          'distance': distance,
          'duration': duration,
          'route': route ?? [],
        });

        // Liberar conductor
        if (driverId != null) {
          transaction.update(
            _firestore.collection(driversCollection).doc(driverId),
            {
              'isAvailable': true,
              'currentTripId': null,
            },
          );

          // Actualizar métricas del conductor
          transaction.update(
            _firestore.collection(driversCollection).doc(driverId),
            {
              'totalTrips': FieldValue.increment(1),
              'totalEarnings': FieldValue.increment(
                  finalPrice * 0.8), // 80% para el conductor
            },
          );
        }

        // Actualizar métricas del pasajero
        transaction.update(
          _firestore.collection(usersCollection).doc(tripData['passengerId']),
          {
            'totalTrips': FieldValue.increment(1),
          },
        );

        AppLogger.info('Viaje completado: $tripId');
        return true;
      });
    } catch (e) {
      AppLogger.error('Error completando viaje', e);
      return false;
    }
  }

  /// Cancela un viaje
  Future<bool> cancelTrip(
    String tripId,
    String cancelledBy,
    String reason,
  ) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final tripDoc = await transaction
            .get(_firestore.collection(tripsCollection).doc(tripId));

        if (!tripDoc.exists) {
          throw Exception('Viaje no encontrado');
        }

        final tripData = tripDoc.data()!;
        final driverId = tripData['driverId'];

        // Actualizar viaje
        transaction.update(tripDoc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': cancelledBy,
          'cancellationReason': reason,
        });

        // Liberar conductor si estaba asignado
        if (driverId != null) {
          transaction.update(
            _firestore.collection(driversCollection).doc(driverId),
            {
              'isAvailable': true,
              'currentTripId': null,
            },
          );
        }

        AppLogger.info('Viaje cancelado: $tripId por: $cancelledBy');
        return true;
      });
    } catch (e) {
      AppLogger.error('Error cancelando viaje', e);
      return false;
    }
  }

  /// Obtiene historial de viajes
  Future<List<Map<String, dynamic>>> getTripHistory({
    String? userId,
    String? userType,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore.collection(tripsCollection);

      if (userId != null && userType != null) {
        if (userType == 'passenger') {
          query = query.where('passengerId', isEqualTo: userId);
        } else if (userType == 'driver') {
          query = query.where('driverId', isEqualTo: userId);
        }
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      AppLogger.error('Error obteniendo historial de viajes', e);
      return [];
    }
  }

  // ==================== NEGOCIACIÓN DE PRECIOS ====================

  /// Crea una negociación de precio
  Future<String?> createPriceNegotiation({
    required String tripId,
    required String passengerId,
    required double initialPrice,
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> destination,
    required String vehicleType,
  }) async {
    try {
      final negotiationData = {
        'tripId': tripId,
        'passengerId': passengerId,
        'initialPrice': initialPrice,
        'currentPrice': initialPrice,
        'finalPrice': null,
        'status': 'waiting_driver',
        'pickup': pickup,
        'destination': destination,
        'vehicleType': vehicleType,
        'offers': [],
        'selectedDriverId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
      };

      final docRef = await _firestore
          .collection(priceNegotiationsCollection)
          .add(negotiationData);

      AppLogger.info('Negociación creada: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Error creando negociación', e);
      return null;
    }
  }

  /// Conductor hace una oferta
  Future<bool> makeDriverOffer({
    required String negotiationId,
    required String driverId,
    required double offeredPrice,
    String? message,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final negotiationDoc = await transaction.get(_firestore
            .collection(priceNegotiationsCollection)
            .doc(negotiationId));

        if (!negotiationDoc.exists) {
          throw Exception('Negociación no encontrada');
        }

        final data = negotiationDoc.data()!;
        final offers = List<Map<String, dynamic>>.from(data['offers'] ?? []);

        // Agregar nueva oferta
        offers.add({
          'driverId': driverId,
          'price': offeredPrice,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        });

        transaction.update(negotiationDoc.reference, {
          'offers': offers,
          'status': 'driver_offered',
        });
      });

      AppLogger.info('Oferta realizada en negociación: $negotiationId');
      return true;
    } catch (e) {
      AppLogger.error('Error haciendo oferta', e);
      return false;
    }
  }

  /// Pasajero acepta una oferta
  Future<bool> acceptOffer({
    required String negotiationId,
    required String driverId,
    required double acceptedPrice,
  }) async {
    try {
      await _firestore
          .collection(priceNegotiationsCollection)
          .doc(negotiationId)
          .update({
        'selectedDriverId': driverId,
        'finalPrice': acceptedPrice,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Oferta aceptada en negociación: $negotiationId');
      return true;
    } catch (e) {
      AppLogger.error('Error aceptando oferta', e);
      return false;
    }
  }

  // ==================== SISTEMA DE PAGOS ====================

  /// Registra un pago
  Future<String?> recordPayment({
    required String tripId,
    required String passengerId,
    required String? driverId,
    required double amount,
    required String method,
    String status = 'pending',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final paymentData = {
        'tripId': tripId,
        'passengerId': passengerId,
        'driverId': driverId,
        'amount': amount,
        'method': method,
        'status': status,
        'commission': amount * 0.20, // 20% comisión
        'driverAmount': amount * 0.80, // 80% para conductor
        'currency': 'PEN',
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
        'processedAt':
            status == 'completed' ? FieldValue.serverTimestamp() : null,
      };

      final docRef =
          await _firestore.collection(paymentsCollection).add(paymentData);

      // Si el pago está completado, actualizar wallets
      if (status == 'completed' && driverId != null) {
        await _updateWalletsAfterPayment(
          driverId: driverId,
          amount: amount,
          paymentId: docRef.id,
        );
      }

      AppLogger.info('Pago registrado: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Error registrando pago', e);
      return null;
    }
  }

  /// Actualiza wallets después de un pago
  Future<void> _updateWalletsAfterPayment({
    required String driverId,
    required double amount,
    required String paymentId,
  }) async {
    try {
      final driverAmount = amount * 0.80;
      final commission = amount * 0.20;

      // Actualizar wallet del conductor
      await _firestore.collection(walletsCollection).doc(driverId).update({
        'balance': FieldValue.increment(driverAmount),
        'totalEarnings': FieldValue.increment(driverAmount),
        'lastTransaction': FieldValue.serverTimestamp(),
      });

      // Registrar transacción
      await _firestore.collection(transactionsCollection).add({
        'walletId': driverId,
        'type': 'credit',
        'amount': driverAmount,
        'description': 'Pago por viaje',
        'paymentId': paymentId,
        'balance': driverAmount,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Actualizar wallet de la empresa (comisión)
      await _firestore.collection(walletsCollection).doc('company').update({
        'balance': FieldValue.increment(commission),
        'totalCommissions': FieldValue.increment(commission),
      });
    } catch (e) {
      AppLogger.error('Error actualizando wallets', e);
    }
  }

  // ==================== SISTEMA DE EMERGENCIAS ====================

  /// Crea una alerta de emergencia
  Future<String?> createEmergencyAlert({
    required String tripId,
    required String userId,
    required String userType,
    required Map<String, double> location,
    required String emergencyType,
    String? message,
    List<String>? photoUrls,
  }) async {
    try {
      final emergencyData = {
        'tripId': tripId,
        'userId': userId,
        'userType': userType,
        'location': location,
        'emergencyType': emergencyType,
        'message': message,
        'photoUrls': photoUrls ?? [],
        'status': 'active',
        'priority': 'critical',
        'responders': [],
        'createdAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'resolution': null,
      };

      final docRef =
          await _firestore.collection(emergenciesCollection).add(emergencyData);

      // Registrar en log de administrador
      await _logAdminAction(
        action: 'emergency_alert',
        data: {
          'emergencyId': docRef.id,
          'tripId': tripId,
          'userId': userId,
          'type': emergencyType,
        },
        severity: 'critical',
      );

      AppLogger.critical('Alerta de emergencia creada: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Error creando alerta de emergencia', e);
      return null;
    }
  }

  /// Actualiza estado de emergencia
  Future<bool> updateEmergencyStatus(
    String emergencyId,
    String status,
    String? resolution,
  ) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'resolved' && resolution != null) {
        updates['resolvedAt'] = FieldValue.serverTimestamp();
        updates['resolution'] = resolution;
      }

      await _firestore
          .collection(emergenciesCollection)
          .doc(emergencyId)
          .update(updates);

      AppLogger.info('Emergencia actualizada: $emergencyId a $status');
      return true;
    } catch (e) {
      AppLogger.error('Error actualizando emergencia', e);
      return false;
    }
  }

  // ==================== SISTEMA DE CALIFICACIONES ====================

  /// Crea una calificación
  Future<bool> createRating({
    required String tripId,
    required String fromUserId,
    required String toUserId,
    required String fromUserType,
    required double rating,
    String? comment,
    List<String>? tags,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Crear calificación
        final ratingRef = _firestore.collection(ratingsCollection).doc();
        transaction.set(ratingRef, {
          'tripId': tripId,
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'fromUserType': fromUserType,
          'rating': rating,
          'comment': comment,
          'tags': tags ?? [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Actualizar rating promedio del usuario calificado
        final userDoc = await transaction
            .get(_firestore.collection(usersCollection).doc(toUserId));

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final currentRating = userData['rating'] ?? 0.0;
          final totalRatings = userData['totalRatings'] ?? 0;

          final newTotalRatings = totalRatings + 1;
          final newRating =
              ((currentRating * totalRatings) + rating) / newTotalRatings;

          transaction.update(userDoc.reference, {
            'rating': newRating,
            'totalRatings': newTotalRatings,
          });
        }

        // Actualizar viaje con la calificación
        final tripRef = _firestore.collection(tripsCollection).doc(tripId);
        if (fromUserType == 'passenger') {
          transaction.update(tripRef, {'passengerRating': rating});
        } else {
          transaction.update(tripRef, {'driverRating': rating});
        }
      });

      AppLogger.info('Calificación creada para viaje: $tripId');
      return true;
    } catch (e) {
      AppLogger.error('Error creando calificación', e);
      return false;
    }
  }

  // ==================== SISTEMA DE WALLETS ====================

  /// Crea wallet para usuario
  Future<void> _createUserWallet(String userId, String userType) async {
    try {
      await _firestore.collection(walletsCollection).doc(userId).set({
        'userId': userId,
        'userType': userType,
        'balance': 0.0,
        'totalEarnings': 0.0,
        'totalWithdrawals': 0.0,
        'pendingWithdrawal': 0.0,
        'currency': 'PEN',
        'bankAccount': null,
        'lastTransaction': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Wallet creado para usuario: $userId');
    } catch (e) {
      AppLogger.error('Error creando wallet', e);
    }
  }

  /// Solicita retiro de fondos
  Future<String?> requestWithdrawal({
    required String userId,
    required double amount,
    required Map<String, dynamic> bankDetails,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final walletDoc = await transaction
            .get(_firestore.collection(walletsCollection).doc(userId));

        if (!walletDoc.exists) {
          throw Exception('Wallet no encontrado');
        }

        final walletData = walletDoc.data()!;
        final balance = walletData['balance'] ?? 0.0;

        if (balance < amount) {
          throw Exception('Saldo insuficiente');
        }

        // Crear solicitud de retiro
        final withdrawalRef = _firestore.collection('withdrawals').doc();
        transaction.set(withdrawalRef, {
          'userId': userId,
          'amount': amount,
          'bankDetails': bankDetails,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Actualizar wallet
        transaction.update(walletDoc.reference, {
          'balance': FieldValue.increment(-amount),
          'pendingWithdrawal': FieldValue.increment(amount),
        });

        return withdrawalRef.id;
      });
    } catch (e) {
      AppLogger.error('Error solicitando retiro', e);
      return null;
    }
  }

  // ==================== SISTEMA DE NOTIFICACIONES ====================

  /// Crea una notificación
  Future<String?> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
    String priority = 'normal',
  }) async {
    try {
      final notificationData = {
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'priority': priority,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection(notificationsCollection)
          .add(notificationData);

      AppLogger.info('Notificación creada: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Error creando notificación', e);
      return null;
    }
  }

  /// Marca notificaciones como leídas
  Future<bool> markNotificationsAsRead(List<String> notificationIds) async {
    try {
      final batch = _firestore.batch();

      for (final id in notificationIds) {
        batch.update(
          _firestore.collection(notificationsCollection).doc(id),
          {'read': true, 'readAt': FieldValue.serverTimestamp()},
        );
      }

      await batch.commit();
      return true;
    } catch (e) {
      AppLogger.error('Error marcando notificaciones como leídas', e);
      return false;
    }
  }

  // ==================== LISTENERS EN TIEMPO REAL ====================

  /// Escucha cambios en un viaje
  Stream<Map<String, dynamic>?> listenToTrip(String tripId) {
    return _firestore
        .collection(tripsCollection)
        .doc(tripId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return {'id': snapshot.id, ...snapshot.data()!};
      }
      return null;
    });
  }

  /// Escucha solicitudes de viaje para conductores
  Stream<List<Map<String, dynamic>>> listenToTripRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
    String? vehicleType,
  }) {
    return _firestore
        .collection(tripsCollection)
        .where('status', isEqualTo: 'searching_driver')
        .snapshots()
        .map((snapshot) {
      final trips = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final pickup = data['pickup'] as Map<String, dynamic>;

        // Calcular distancia
        final distance = _calculateDistance(
          latitude,
          longitude,
          pickup['latitude'] as double,
          pickup['longitude'] as double,
        );

        // Filtrar por radio y tipo de vehículo
        if (distance <= radiusKm) {
          if (vehicleType == null || data['vehicleType'] == vehicleType) {
            trips.add({
              'id': doc.id,
              'distance': distance,
              ...data,
            });
          }
        }
      }

      // Ordenar por distancia
      trips.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      return trips;
    });
  }

  /// Escucha ubicación del conductor durante un viaje
  Stream<Map<String, double>?> listenToDriverLocation(String driverId) {
    return _firestore
        .collection(driversCollection)
        .doc(driverId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final location = data['currentLocation'] as Map<String, dynamic>?;
        if (location != null) {
          return {
            'latitude': location['latitude'] as double,
            'longitude': location['longitude'] as double,
            'heading': location['heading'] as double? ?? 0,
          };
        }
      }
      return null;
    });
  }

  /// Escucha notificaciones del usuario
  Stream<List<Map<String, dynamic>>> listenToNotifications(String userId) {
    return _firestore
        .collection(notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    });
  }

  // ==================== UTILIDADES PRIVADAS ====================

  /// Calcula distancia entre dos puntos (fórmula Haversine)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (3.141592653589793 / 180);
  }

  /// Genera código de verificación para viajes
  String _generateVerificationCode() {
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    return random.toString().padLeft(4, '0');
  }

  // ==================== LOGS DE ADMINISTRADOR ====================

  /// Registra acción de administrador
  Future<void> _logAdminAction({
    required String action,
    required Map<String, dynamic> data,
    String severity = 'info',
    String? adminId,
  }) async {
    try {
      await _firestore.collection(adminLogsCollection).add({
        'action': action,
        'data': data,
        'severity': severity,
        'adminId': adminId ?? 'system',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Error registrando log de admin', e);
    }
  }

  // ==================== LIMPIEZA ====================

  /// Cancela todas las suscripciones
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    AppLogger.info('Firestore Database Service disposed');
  }
}

// Extensiones útiles para conversión de tipos
extension FirestoreExtensions on DocumentSnapshot {
  Map<String, dynamic> toMap() {
    return {'id': id, ...data() as Map<String, dynamic>};
  }
}

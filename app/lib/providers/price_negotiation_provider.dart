import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../models/price_negotiation_model.dart';

/// Provider para manejar las negociaciones de precios con implementación real
class PriceNegotiationProvider extends ChangeNotifier {
  final List<PriceNegotiation> _activeNegotiations = [];
  List<PriceNegotiation> _driverVisibleRequests = [];
  PriceNegotiation? _currentNegotiation;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<PriceNegotiation> get activeNegotiations => _activeNegotiations;
  List<PriceNegotiation> get driverVisibleRequests => _driverVisibleRequests;
  PriceNegotiation? get currentNegotiation => _currentNegotiation;
  
  /// Para pasajeros: Crear nueva negociación con datos reales
  Future<void> createNegotiation({
    required LocationPoint pickup,
    required LocationPoint destination,
    required double offeredPrice,
    required PaymentMethod paymentMethod,
    String? notes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Usuario no autenticado');
        return;
      }

      // Obtener datos del usuario desde Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Calcular datos reales
      final pickupLatLng = _locationPointToLatLng(pickup);
      final destLatLng = _locationPointToLatLng(destination);
      
      final distance = await _calculateRealDistance(pickupLatLng, destLatLng);
      final estimatedTime = await _calculateRealTime(pickupLatLng, destLatLng);
      final suggestedPrice = _calculateSuggestedPrice(distance);

      final negotiation = PriceNegotiation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        passengerId: user.uid,
        passengerName: user.displayName ?? userData['name'] ?? 'Usuario',
        passengerPhoto: user.photoURL ?? userData['photoUrl'] ?? '',
        passengerRating: (userData['rating'] ?? 5.0).toDouble(),
        pickup: pickup,
        destination: destination,
        suggestedPrice: suggestedPrice,
        offeredPrice: offeredPrice,
        distance: distance,
        estimatedTime: estimatedTime,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: NegotiationStatus.waiting,
        driverOffers: [],
        paymentMethod: paymentMethod,
        notes: notes,
      );
      
      _currentNegotiation = negotiation;
      _activeNegotiations.add(negotiation);
      await _broadcastToDrivers(negotiation);
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error creando negociación: $e');
    }
  }
  
  /// Para conductores: Ver todas las solicitudes activas desde Firestore
  Future<void> loadDriverRequests() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Obtener ubicación actual del conductor
      final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
      final driverData = driverDoc.data();
      
      if (driverData == null || driverData['location'] == null) {
        debugPrint('Conductor sin ubicación registrada');
        return;
      }

      // Buscar negociaciones activas en un radio de 10km
      final driverLat = driverData['location']['lat'];
      final driverLng = driverData['location']['lng'];
      
      final snapshot = await _firestore
          .collection('negotiations')
          .where('status', isEqualTo: 'waiting')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();

      _driverVisibleRequests = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return PriceNegotiation(
              id: data['id'] ?? '',
              passengerId: data['passengerId'] ?? '',
              passengerName: data['passengerName'] ?? '',
              passengerPhoto: data['passengerPhoto'] ?? '',
              passengerRating: (data['passengerRating'] ?? 5.0).toDouble(),
              pickup: LocationPoint(
                latitude: data['pickup']['latitude'].toDouble(),
                longitude: data['pickup']['longitude'].toDouble(),
                address: data['pickup']['address'] ?? '',
                reference: data['pickup']['reference'],
              ),
              destination: LocationPoint(
                latitude: data['destination']['latitude'].toDouble(),
                longitude: data['destination']['longitude'].toDouble(),
                address: data['destination']['address'] ?? '',
                reference: data['destination']['reference'],
              ),
              suggestedPrice: (data['suggestedPrice'] ?? 0.0).toDouble(),
              offeredPrice: (data['offeredPrice'] ?? 0.0).toDouble(),
              distance: (data['distance'] ?? 0.0).toDouble(),
              estimatedTime: data['estimatedTime'] ?? 0,
              createdAt: DateTime.parse(data['createdAt']),
              expiresAt: DateTime.parse(data['expiresAt']),
              status: NegotiationStatus.values.firstWhere(
                (status) => status.name == data['status'],
                orElse: () => NegotiationStatus.waiting,
              ),
              driverOffers: [],
              paymentMethod: PaymentMethod.values.firstWhere(
                (method) => method.name == data['paymentMethod'],
                orElse: () => PaymentMethod.cash,
              ),
              notes: data['notes'],
            );
          })
          .where((negotiation) {
            // Filtrar por proximidad (10km radio)
            final distance = _calculateHaversineDistance(
              LatLng(driverLat, driverLng),
              _locationPointToLatLng(negotiation.pickup),
            );
            return distance <= 10.0; // 10km máximo
          })
          .toList();
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error cargando solicitudes de conductores: $e');
    }
  }
  
  /// Para conductores: Hacer una oferta con datos reales
  Future<void> makeDriverOffer(String negotiationId, double acceptedPrice) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Obtener datos del conductor desde Firestore
      final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
      final driverData = driverDoc.data() ?? {};
      
      // Obtener datos del vehículo
      final vehicleData = driverData['vehicle'] ?? {};
      
      // Calcular tiempo de llegada real
      final negotiationIndex = _activeNegotiations.indexWhere((n) => n.id == negotiationId);
      int estimatedArrival = 5; // default
      
      if (negotiationIndex != -1 && driverData['location'] != null) {
        final driverLocation = LatLng(
          driverData['location']['lat'].toDouble(),
          driverData['location']['lng'].toDouble(),
        );
        final pickupLocation = _locationPointToLatLng(
          _activeNegotiations[negotiationIndex].pickup,
        );
        
        estimatedArrival = await _calculateRealTime(driverLocation, pickupLocation);
      }

      final offer = DriverOffer(
        driverId: user.uid,
        driverName: user.displayName ?? driverData['name'] ?? 'Conductor',
        driverPhoto: user.photoURL ?? driverData['photoUrl'] ?? '',
        driverRating: (driverData['rating'] ?? 5.0).toDouble(),
        vehicleModel: await _getDriverVehicleModel(),
        vehiclePlate: vehicleData['plate'] ?? 'XXX-000',
        vehicleColor: vehicleData['color'] ?? 'Color no especificado',
        acceptedPrice: acceptedPrice,
        estimatedArrival: estimatedArrival,
        offeredAt: DateTime.now(),
        status: OfferStatus.pending,
        completedTrips: driverData['completedTrips'] ?? 0,
        acceptanceRate: (driverData['acceptanceRate'] ?? 100.0).toDouble(),
      );
      
      if (negotiationIndex != -1) {
        final updatedOffers = List<DriverOffer>.from(
          _activeNegotiations[negotiationIndex].driverOffers
        )..add(offer);
        
        _activeNegotiations[negotiationIndex] = 
            _activeNegotiations[negotiationIndex].copyWith(
          driverOffers: updatedOffers,
          status: NegotiationStatus.negotiating,
        );
        
        // Guardar oferta en Firestore
        await _firestore
            .collection('negotiations')
            .doc(negotiationId)
            .collection('offers')
            .doc(user.uid)
            .set({
              'driverId': offer.driverId,
              'driverName': offer.driverName,
              'driverPhoto': offer.driverPhoto,
              'driverRating': offer.driverRating,
              'vehicleModel': offer.vehicleModel,
              'vehiclePlate': offer.vehiclePlate,
              'vehicleColor': offer.vehicleColor,
              'acceptedPrice': offer.acceptedPrice,
              'estimatedArrival': offer.estimatedArrival,
              'offeredAt': offer.offeredAt.toIso8601String(),
              'status': offer.status.name,
              'completedTrips': offer.completedTrips,
              'acceptanceRate': offer.acceptanceRate,
            });
        
        if (_currentNegotiation?.id == negotiationId) {
          _currentNegotiation = _activeNegotiations[negotiationIndex];
        }
        
        notifyListeners();
      }
      
    } catch (e) {
      debugPrint('Error haciendo oferta: $e');
    }
  }
  
  /// Para pasajeros: Aceptar oferta de conductor
  void acceptDriverOffer(String negotiationId, String driverId) {
    final negotiationIndex = _activeNegotiations
        .indexWhere((n) => n.id == negotiationId);
    
    if (negotiationIndex != -1) {
      final offerIndex = _activeNegotiations[negotiationIndex]
          .driverOffers
          .indexWhere((o) => o.driverId == driverId);
      
      if (offerIndex != -1) {
        // Actualizar estado de la oferta aceptada
        final updatedOffers = List<DriverOffer>.from(
          _activeNegotiations[negotiationIndex].driverOffers
        );
        
        for (int i = 0; i < updatedOffers.length; i++) {
          updatedOffers[i] = updatedOffers[i].copyWith(
            status: i == offerIndex 
                ? OfferStatus.accepted 
                : OfferStatus.rejected,
          );
        }
        
        _activeNegotiations[negotiationIndex] = 
            _activeNegotiations[negotiationIndex].copyWith(
          driverOffers: updatedOffers,
          status: NegotiationStatus.accepted,
          acceptedDriverId: driverId,
        );
        
        if (_currentNegotiation?.id == negotiationId) {
          _currentNegotiation = _activeNegotiations[negotiationIndex];
        }
        
        notifyListeners();
      }
    }
  }
  
  // MÉTODOS AUXILIARES REALES
  
  /// Calcular precio sugerido basado en distancia real y tarifas de Perú
  double _calculateSuggestedPrice(double distanceKm) {
    const double tarifaBase = 4.0; // S/ 4.00 tarifa base en Perú
    const double tarifaPorKm = 2.5; // S/ 2.50 por kilómetro
    const double tarifaMinima = 8.0; // S/ 8.00 mínimo
    
    final precio = tarifaBase + (distanceKm * tarifaPorKm);
    return math.max(precio, tarifaMinima).roundToDouble();
  }
  
  /// Obtener modelo del vehículo del conductor
  Future<String> _getDriverVehicleModel() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Vehículo no especificado';
      
      final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
      final vehicleData = driverDoc.data()?['vehicle'] ?? {};
      
      final marca = vehicleData['brand'] ?? '';
      final modelo = vehicleData['model'] ?? '';
      final anio = vehicleData['year'] ?? '';
      
      if (marca.isNotEmpty && modelo.isNotEmpty) {
        return '$marca $modelo ${anio.isNotEmpty ? anio : ''}'.trim();
      }
      
      return 'Vehículo no especificado';
      
    } catch (e) {
      debugPrint('Error obteniendo modelo de vehículo: $e');
      return 'Vehículo no especificado';
    }
  }
  
  /// Broadcast real a conductores cercanos via Firestore
  Future<void> _broadcastToDrivers(PriceNegotiation negotiation) async {
    try {
      // Guardar negociación en Firestore para que los conductores la vean
      await _firestore
          .collection('negotiations')
          .doc(negotiation.id)
          .set({
            'id': negotiation.id,
            'passengerId': negotiation.passengerId,
            'passengerName': negotiation.passengerName,
            'passengerPhoto': negotiation.passengerPhoto,
            'passengerRating': negotiation.passengerRating,
            'pickup': {
              'latitude': negotiation.pickup.latitude,
              'longitude': negotiation.pickup.longitude,
              'address': negotiation.pickup.address,
              'reference': negotiation.pickup.reference,
            },
            'destination': {
              'latitude': negotiation.destination.latitude,
              'longitude': negotiation.destination.longitude,
              'address': negotiation.destination.address,
              'reference': negotiation.destination.reference,
            },
            'suggestedPrice': negotiation.suggestedPrice,
            'offeredPrice': negotiation.offeredPrice,
            'distance': negotiation.distance,
            'estimatedTime': negotiation.estimatedTime,
            'createdAt': negotiation.createdAt.toIso8601String(),
            'expiresAt': negotiation.expiresAt.toIso8601String(),
            'status': negotiation.status.name,
            'paymentMethod': negotiation.paymentMethod.name,
            'notes': negotiation.notes,
          });
      
      // Buscar conductores activos en un radio de 15km
      final pickupLatLng = _locationPointToLatLng(negotiation.pickup);
      
      final driversSnapshot = await _firestore
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();
      
      final List<String> nearbyDriverIds = [];
      
      for (final driverDoc in driversSnapshot.docs) {
        final driverData = driverDoc.data();
        if (driverData['location'] != null) {
          final driverLocation = LatLng(
            driverData['location']['lat'].toDouble(),
            driverData['location']['lng'].toDouble(),
          );
          
          final distance = _calculateHaversineDistance(
            pickupLatLng,
            driverLocation,
          );
          
          if (distance <= 15.0) { // 15km radio
            nearbyDriverIds.add(driverDoc.id);
          }
        }
      }
      
      // Enviar notificación push a conductores cercanos
      if (nearbyDriverIds.isNotEmpty) {
        await _sendPushNotificationToDrivers(nearbyDriverIds, negotiation);
      }
      
      _driverVisibleRequests.add(negotiation);
      debugPrint('Negociación broadcast a ${nearbyDriverIds.length} conductores');
      
    } catch (e) {
      debugPrint('Error haciendo broadcast a conductores: $e');
    }
  }
  
  /// Enviar notificaciones push a conductores
  Future<void> _sendPushNotificationToDrivers(List<String> driverIds, PriceNegotiation negotiation) async {
    // Implementar envío de notificaciones push usando Firebase Cloud Messaging
    // Este método se conectará con el servicio de notificaciones
    debugPrint('Enviando notificaciones push a conductores: $driverIds');
  }

  LatLng _locationPointToLatLng(LocationPoint point) {
    return LatLng(point.latitude, point.longitude);
  }

  double _calculateHaversineDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLat = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLng = (point2.longitude - point1.longitude) * (math.pi / 180);

    double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  Future<double> _calculateRealDistance(LatLng point1, LatLng point2) async {
    return _calculateHaversineDistance(point1, point2);
  }

  Future<int> _calculateRealTime(LatLng point1, LatLng point2) async {
    double distanceKm = _calculateHaversineDistance(point1, point2);
    return (distanceKm / 30 * 60).round();
  }
}
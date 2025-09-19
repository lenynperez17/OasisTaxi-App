import 'package:cloud_firestore/cloud_firestore.dart';
import 'service_type_model.dart';
import 'price_calculation_model.dart';

// Modelo para negociación de precio estilo InDriver
class PriceNegotiation {
  final String id;
  final String passengerId;
  final String passengerName;
  final String passengerPhoto;
  final double passengerRating;
  final LocationPoint pickup;
  final LocationPoint destination;
  final double suggestedPrice;
  final double offeredPrice;
  final double distance;
  final int estimatedTime; // en minutos
  final DateTime createdAt;
  final DateTime expiresAt;
  final NegotiationStatus status;
  final List<DriverOffer> driverOffers;
  final String? selectedDriverId;
  final PaymentMethod paymentMethod;
  final String? notes;
  final ServiceType? serviceType;

  PriceNegotiation({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhoto,
    required this.passengerRating,
    required this.pickup,
    required this.destination,
    required this.suggestedPrice,
    required this.offeredPrice,
    required this.distance,
    required this.estimatedTime,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.driverOffers,
    this.selectedDriverId,
    required this.paymentMethod,
    this.notes,
    this.serviceType,
  });

  // Constructor desde Firestore
  factory PriceNegotiation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PriceNegotiation(
      id: doc.id,
      passengerId: data['passengerId'] ?? '',
      passengerName: data['passengerName'] ?? '',
      passengerPhoto: data['passengerPhoto'] ?? '',
      passengerRating: (data['passengerRating'] ?? 0.0).toDouble(),
      pickup: LocationPoint.fromMap(data['pickup'] ?? {}),
      destination: LocationPoint.fromMap(data['destination'] ?? {}),
      suggestedPrice: (data['suggestedPrice'] ?? 0.0).toDouble(),
      offeredPrice: (data['offeredPrice'] ?? 0.0).toDouble(),
      distance: (data['distance'] ?? 0.0).toDouble(),
      estimatedTime: data['estimatedTime'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(Duration(minutes: 10)),
      status: _statusFromString(data['status'] ?? 'waiting'),
      driverOffers: (data['driverOffers'] as List<dynamic>?)
              ?.map(
                  (offer) => DriverOffer.fromMap(offer as Map<String, dynamic>))
              .toList() ??
          [],
      selectedDriverId: data['selectedDriverId'],
      paymentMethod: _paymentMethodFromString(data['paymentMethod'] ?? 'cash'),
      notes: data['notes'],
      serviceType: _serviceTypeFromString(data['serviceType']),
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhoto': passengerPhoto,
      'passengerRating': passengerRating,
      'pickup': pickup.toMap(),
      'destination': destination.toMap(),
      'suggestedPrice': suggestedPrice,
      'offeredPrice': offeredPrice,
      'distance': distance,
      'estimatedTime': estimatedTime,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.toString().split('.').last,
      'driverOffers': driverOffers.map((offer) => offer.toMap()).toList(),
      'selectedDriverId': selectedDriverId,
      'paymentMethod': paymentMethod.toString().split('.').last,
      'notes': notes,
      'serviceType': serviceType?.toString().split('.').last,
    };
  }

  // Métodos helper para conversión
  static NegotiationStatus _statusFromString(String status) {
    switch (status) {
      case 'waiting':
        return NegotiationStatus.waiting;
      case 'negotiating':
        return NegotiationStatus.negotiating;
      case 'accepted':
        return NegotiationStatus.accepted;
      case 'inProgress':
        return NegotiationStatus.inProgress;
      case 'completed':
        return NegotiationStatus.completed;
      case 'cancelled':
        return NegotiationStatus.cancelled;
      case 'expired':
        return NegotiationStatus.expired;
      default:
        return NegotiationStatus.waiting;
    }
  }

  static PaymentMethod _paymentMethodFromString(String method) {
    switch (method) {
      case 'cash':
        return PaymentMethod.cash;
      case 'card':
        return PaymentMethod.card;
      case 'wallet':
        return PaymentMethod.wallet;
      default:
        return PaymentMethod.cash;
    }
  }

  static ServiceType? _serviceTypeFromString(String? type) {
    if (type == null) return null;
    try {
      return ServiceType.values.firstWhere(
        (e) => e.toString().split('.').last == type,
        orElse: () => ServiceType.taxiEconomico,
      );
    } catch (e) {
      return ServiceType.taxiEconomico;
    }
  }

  PriceNegotiation copyWith({
    double? offeredPrice,
    NegotiationStatus? status,
    List<DriverOffer>? driverOffers,
    String? selectedDriverId,
    String? acceptedDriverId,
  }) {
    return PriceNegotiation(
      id: id,
      passengerId: passengerId,
      passengerName: passengerName,
      passengerPhoto: passengerPhoto,
      passengerRating: passengerRating,
      pickup: pickup,
      destination: destination,
      suggestedPrice: suggestedPrice,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      distance: distance,
      estimatedTime: estimatedTime,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      driverOffers: driverOffers ?? this.driverOffers,
      selectedDriverId:
          acceptedDriverId ?? selectedDriverId ?? this.selectedDriverId,
      paymentMethod: paymentMethod,
      notes: notes,
      serviceType: serviceType,
    );
  }

  // Calcular tiempo restante para ofertar
  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  // Verificar si la negociación ha expirado
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // Obtener la mejor oferta de los conductores
  DriverOffer? get bestOffer {
    if (driverOffers.isEmpty) return null;
    return driverOffers
        .reduce((a, b) => a.acceptedPrice < b.acceptedPrice ? a : b);
  }
}

// Oferta de conductor
class DriverOffer {
  final String driverId;
  final String driverName;
  final String driverPhoto;
  final double driverRating;
  final String vehicleModel;
  final String vehiclePlate;
  final String vehicleColor;
  final double acceptedPrice;
  final int estimatedArrival; // en minutos
  final DateTime offeredAt;
  final OfferStatus status;
  final int completedTrips;
  final double acceptanceRate;

  DriverOffer({
    required this.driverId,
    required this.driverName,
    required this.driverPhoto,
    required this.driverRating,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.vehicleColor,
    required this.acceptedPrice,
    required this.estimatedArrival,
    required this.offeredAt,
    required this.status,
    required this.completedTrips,
    required this.acceptanceRate,
  });

  factory DriverOffer.fromMap(Map<String, dynamic> map) {
    return DriverOffer(
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? '',
      driverPhoto: map['driverPhoto'] ?? '',
      driverRating: (map['driverRating'] ?? 0.0).toDouble(),
      vehicleModel: map['vehicleModel'] ?? '',
      vehiclePlate: map['vehiclePlate'] ?? '',
      vehicleColor: map['vehicleColor'] ?? '',
      acceptedPrice: (map['acceptedPrice'] ?? 0.0).toDouble(),
      estimatedArrival: map['estimatedArrival'] ?? 0,
      offeredAt: (map['offeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _offerStatusFromString(map['status'] ?? 'pending'),
      completedTrips: map['completedTrips'] ?? 0,
      acceptanceRate: (map['acceptanceRate'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhoto': driverPhoto,
      'driverRating': driverRating,
      'vehicleModel': vehicleModel,
      'vehiclePlate': vehiclePlate,
      'vehicleColor': vehicleColor,
      'acceptedPrice': acceptedPrice,
      'estimatedArrival': estimatedArrival,
      'offeredAt': Timestamp.fromDate(offeredAt),
      'status': status.toString().split('.').last,
      'completedTrips': completedTrips,
      'acceptanceRate': acceptanceRate,
    };
  }

  static OfferStatus _offerStatusFromString(String status) {
    switch (status) {
      case 'pending':
        return OfferStatus.pending;
      case 'accepted':
        return OfferStatus.accepted;
      case 'rejected':
        return OfferStatus.rejected;
      case 'withdrawn':
        return OfferStatus.withdrawn;
      default:
        return OfferStatus.pending;
    }
  }

  DriverOffer copyWith({
    OfferStatus? status,
  }) {
    return DriverOffer(
      driverId: driverId,
      driverName: driverName,
      driverPhoto: driverPhoto,
      driverRating: driverRating,
      vehicleModel: vehicleModel,
      vehiclePlate: vehiclePlate,
      vehicleColor: vehicleColor,
      acceptedPrice: acceptedPrice,
      estimatedArrival: estimatedArrival,
      offeredAt: offeredAt,
      status: status ?? this.status,
      completedTrips: completedTrips,
      acceptanceRate: acceptanceRate,
    );
  }
}

// Estados de negociación
enum NegotiationStatus {
  waiting, // Esperando ofertas de conductores
  negotiating, // Conductores han hecho ofertas
  accepted, // Pasajero aceptó una oferta
  inProgress, // Viaje en curso
  completed, // Viaje completado
  cancelled, // Cancelado
  expired, // Expirado sin respuesta
}

// Estados de oferta del conductor
enum OfferStatus {
  pending, // Esperando respuesta del pasajero
  accepted, // Aceptada por el pasajero
  rejected, // Rechazada por el pasajero
  withdrawn, // Retirada por el conductor
}

// Métodos de pago
enum PaymentMethod {
  cash,
  card,
  wallet,
}

// Alias para compatibilidad
typedef PaymentMethodType = PaymentMethod;

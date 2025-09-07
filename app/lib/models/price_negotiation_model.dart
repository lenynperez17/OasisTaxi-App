
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
  });

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
      selectedDriverId: acceptedDriverId ?? selectedDriverId ?? this.selectedDriverId,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }

  // Calcular tiempo restante para ofertar
  Duration get timeRemaining => expiresAt.difference(DateTime.now());
  
  // Verificar si la negociación ha expirado
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  // Obtener la mejor oferta de los conductores
  DriverOffer? get bestOffer {
    if (driverOffers.isEmpty) return null;
    return driverOffers.reduce((a, b) => 
      a.acceptedPrice < b.acceptedPrice ? a : b
    );
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

// Punto de ubicación
class LocationPoint {
  final double latitude;
  final double longitude;
  final String address;
  final String? reference;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.reference,
  });
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
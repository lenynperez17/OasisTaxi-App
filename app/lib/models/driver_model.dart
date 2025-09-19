import 'package:cloud_firestore/cloud_firestore.dart';
import 'service_type_model.dart';

enum VehicleType {
  sedan,
  suv,
  moto,
  van,
  camioneta,
  grua,
}

class DriverVehicle {
  final String id;
  final VehicleType type;
  final String brand;
  final String model;
  final String plate;
  final String color;
  final int year;
  final int maxPassengers;
  final bool hasAC;
  final bool hasLuggage;
  final List<ServiceType> supportedServices;
  final bool isVerified;
  final DateTime? verifiedAt;

  DriverVehicle({
    required this.id,
    required this.type,
    required this.brand,
    required this.model,
    required this.plate,
    required this.color,
    required this.year,
    required this.maxPassengers,
    this.hasAC = true,
    this.hasLuggage = true,
    required this.supportedServices,
    this.isVerified = false,
    this.verifiedAt,
  });

  factory DriverVehicle.fromMap(Map<String, dynamic> map, String id) {
    return DriverVehicle(
      id: id,
      type: VehicleType.values[map['type'] ?? 0],
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
      plate: map['plate'] ?? '',
      color: map['color'] ?? '',
      year: map['year'] ?? 2020,
      maxPassengers: map['maxPassengers'] ?? 4,
      hasAC: map['hasAC'] ?? true,
      hasLuggage: map['hasLuggage'] ?? true,
      supportedServices: (map['supportedServices'] as List<dynamic>?)
              ?.map((s) => ServiceType.values[s as int])
              .toList() ??
          [],
      isVerified: map['isVerified'] ?? false,
      verifiedAt: (map['verifiedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'brand': brand,
      'model': model,
      'plate': plate,
      'color': color,
      'year': year,
      'maxPassengers': maxPassengers,
      'hasAC': hasAC,
      'hasLuggage': hasLuggage,
      'supportedServices': supportedServices.map((s) => s.index).toList(),
      'isVerified': isVerified,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
    };
  }
}

class Driver {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final double rating;
  final int totalTrips;
  final int totalRatings;
  final bool isOnline;
  final bool isAvailable;
  final DriverVehicle? currentVehicle;
  final List<DriverVehicle> vehicles;
  final double walletBalance;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final GeoPoint? currentLocation;
  final bool documentsVerified;
  final Map<String, bool> verifiedDocuments;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl,
    this.rating = 5.0,
    this.totalTrips = 0,
    this.totalRatings = 0,
    this.isOnline = false,
    this.isAvailable = false,
    this.currentVehicle,
    this.vehicles = const [],
    this.walletBalance = 0.0,
    required this.createdAt,
    this.lastActiveAt,
    this.currentLocation,
    this.documentsVerified = false,
    this.verifiedDocuments = const {},
  });

  List<ServiceType> get availableServices {
    if (currentVehicle == null) return [];
    return currentVehicle!.supportedServices;
  }

  bool canHandleService(ServiceType serviceType) {
    return availableServices.contains(serviceType);
  }

  factory Driver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Driver(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      photoUrl: data['photoUrl'],
      rating: (data['rating'] ?? 5.0).toDouble(),
      totalTrips: data['totalTrips'] ?? 0,
      totalRatings: data['totalRatings'] ?? 0,
      isOnline: data['isOnline'] ?? false,
      isAvailable: data['isAvailable'] ?? false,
      currentVehicle: data['currentVehicle'] != null
          ? DriverVehicle.fromMap(
              data['currentVehicle'], data['currentVehicleId'] ?? '')
          : null,
      vehicles: (data['vehicles'] as List<dynamic>?)
              ?.map((v) => DriverVehicle.fromMap(v, v['id'] ?? ''))
              .toList() ??
          [],
      walletBalance: (data['walletBalance'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
      currentLocation: data['currentLocation'] as GeoPoint?,
      documentsVerified: data['documentsVerified'] ?? false,
      verifiedDocuments:
          Map<String, bool>.from(data['verifiedDocuments'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'rating': rating,
      'totalTrips': totalTrips,
      'totalRatings': totalRatings,
      'isOnline': isOnline,
      'isAvailable': isAvailable,
      'currentVehicle': currentVehicle?.toMap(),
      'currentVehicleId': currentVehicle?.id,
      'vehicles': vehicles.map((v) => v.toMap()).toList(),
      'walletBalance': walletBalance,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt':
          lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'currentLocation': currentLocation,
      'documentsVerified': documentsVerified,
      'verifiedDocuments': verifiedDocuments,
    };
  }
}

// Configuración de servicios por tipo de vehículo
class VehicleServiceConfig {
  static Map<VehicleType, List<ServiceType>> vehicleServices = {
    VehicleType.sedan: [
      ServiceType.taxiEconomico,
      ServiceType.taxiComfort,
      ServiceType.mensajeria,
      ServiceType.paquetes,
    ],
    VehicleType.suv: [
      ServiceType.taxiComfort,
      ServiceType.taxiPremium,
      ServiceType.mensajeria,
      ServiceType.paquetes,
      ServiceType.mascotas,
    ],
    VehicleType.moto: [
      ServiceType.motoTaxi,
      ServiceType.mensajeria,
      ServiceType.farmacia,
      ServiceType.comida,
    ],
    VehicleType.van: [
      ServiceType.van,
      ServiceType.mudanzas,
      ServiceType.paquetes,
      ServiceType.transporteMedico,
    ],
    VehicleType.camioneta: [
      ServiceType.mudanzas,
      ServiceType.paquetes,
      ServiceType.compras,
    ],
    VehicleType.grua: [
      ServiceType.grua,
    ],
  };

  static List<ServiceType> getServicesForVehicle(VehicleType type) {
    return vehicleServices[type] ?? [];
  }

  static bool canVehicleHandleService(
      VehicleType vehicleType, ServiceType serviceType) {
    return getServicesForVehicle(vehicleType).contains(serviceType);
  }

  static String getVehicleTypeName(VehicleType type) {
    switch (type) {
      case VehicleType.sedan:
        return 'Sedán';
      case VehicleType.suv:
        return 'SUV';
      case VehicleType.moto:
        return 'Moto';
      case VehicleType.van:
        return 'Van';
      case VehicleType.camioneta:
        return 'Camioneta';
      case VehicleType.grua:
        return 'Grúa';
    }
  }

  static String getVehicleIcon(VehicleType type) {
    switch (type) {
      case VehicleType.sedan:
        return '🚗';
      case VehicleType.suv:
        return '🚙';
      case VehicleType.moto:
        return '🏍️';
      case VehicleType.van:
        return '🚐';
      case VehicleType.camioneta:
        return '🛻';
      case VehicleType.grua:
        return '🚛';
    }
  }
}

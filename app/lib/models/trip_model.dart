import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Modelo de Viaje
class TripModel {
  final String id;
  final String userId;
  final String? driverId;
  final LatLng pickupLocation;
  final LatLng destinationLocation;
  final String pickupAddress;
  final String destinationAddress;
  final String status;
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final double estimatedDistance;
  final double estimatedFare;
  final double? finalFare;
  final double? passengerRating;
  final String? passengerComment;
  final double? driverRating;
  final String? driverComment;
  final Map<String, dynamic>? vehicleInfo;
  final List<LatLng>? route;
  final String? verificationCode; // Código de 4 dígitos para verificación
  final bool isVerificationCodeUsed; // Si el código ya fue usado

  TripModel({
    required this.id,
    required this.userId,
    this.driverId,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.status,
    required this.requestedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    required this.estimatedDistance,
    required this.estimatedFare,
    this.finalFare,
    this.passengerRating,
    this.passengerComment,
    this.driverRating,
    this.driverComment,
    this.vehicleInfo,
    this.route,
    this.verificationCode,
    this.isVerificationCodeUsed = false,
  });

  /// Crear desde JSON
  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      driverId: json['driverId'],
      pickupLocation: LatLng(
        (json['pickupLocation']['lat'] ?? 0.0).toDouble(),
        (json['pickupLocation']['lng'] ?? 0.0).toDouble(),
      ),
      destinationLocation: LatLng(
        (json['destinationLocation']['lat'] ?? 0.0).toDouble(),
        (json['destinationLocation']['lng'] ?? 0.0).toDouble(),
      ),
      pickupAddress: json['pickupAddress'] ?? '',
      destinationAddress: json['destinationAddress'] ?? '',
      status: json['status'] ?? 'requested',
      requestedAt: _parseDateTime(json['requestedAt']),
      acceptedAt: _parseDateTime(json['acceptedAt']),
      startedAt: _parseDateTime(json['startedAt']),
      completedAt: _parseDateTime(json['completedAt']),
      cancelledAt: _parseDateTime(json['cancelledAt']),
      cancelledBy: json['cancelledBy'],
      estimatedDistance: (json['estimatedDistance'] ?? 0.0).toDouble(),
      estimatedFare: (json['estimatedFare'] ?? 0.0).toDouble(),
      finalFare: json['finalFare']?.toDouble(),
      passengerRating: json['passengerRating']?.toDouble(),
      passengerComment: json['passengerComment'],
      driverRating: json['driverRating']?.toDouble(),
      driverComment: json['driverComment'],
      vehicleInfo: json['vehicleInfo'],
      route: json['route'] != null 
          ? (json['route'] as List)
              .map((point) => LatLng(
                    point['lat'].toDouble(),
                    point['lng'].toDouble(),
                  ))
              .toList()
          : null,
      verificationCode: json['verificationCode'],
      isVerificationCodeUsed: json['isVerificationCodeUsed'] ?? false,
    );
  }

  /// Parsear fecha
  static DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    if (dateTime is DateTime) return dateTime;
    if (dateTime is String) {
      return DateTime.tryParse(dateTime) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'driverId': driverId,
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
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancelledBy': cancelledBy,
      'estimatedDistance': estimatedDistance,
      'estimatedFare': estimatedFare,
      'finalFare': finalFare,
      'passengerRating': passengerRating,
      'passengerComment': passengerComment,
      'driverRating': driverRating,
      'driverComment': driverComment,
      'vehicleInfo': vehicleInfo,
      'route': route?.map((point) => {
        'lat': point.latitude,
        'lng': point.longitude,
      }).toList(),
      'verificationCode': verificationCode,
      'isVerificationCodeUsed': isVerificationCodeUsed,
    };
  }

  /// Copiar con cambios
  TripModel copyWith({
    String? id,
    String? userId,
    String? driverId,
    LatLng? pickupLocation,
    LatLng? destinationLocation,
    String? pickupAddress,
    String? destinationAddress,
    String? status,
    DateTime? requestedAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancelledBy,
    double? estimatedDistance,
    double? estimatedFare,
    double? finalFare,
    double? passengerRating,
    String? passengerComment,
    double? driverRating,
    String? driverComment,
    Map<String, dynamic>? vehicleInfo,
    List<LatLng>? route,
    String? verificationCode,
    bool? isVerificationCodeUsed,
  }) {
    return TripModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      driverId: driverId ?? this.driverId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      finalFare: finalFare ?? this.finalFare,
      passengerRating: passengerRating ?? this.passengerRating,
      passengerComment: passengerComment ?? this.passengerComment,
      driverRating: driverRating ?? this.driverRating,
      driverComment: driverComment ?? this.driverComment,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
      route: route ?? this.route,
      verificationCode: verificationCode ?? this.verificationCode,
      isVerificationCodeUsed: isVerificationCodeUsed ?? this.isVerificationCodeUsed,
    );
  }

  /// Verificar si el viaje está activo
  bool get isActive {
    return status == 'requested' || 
           status == 'accepted' || 
           status == 'driver_arriving' || 
           status == 'in_progress';
  }

  /// Verificar si el viaje está completado
  bool get isCompleted => status == 'completed';

  /// Verificar si el viaje está cancelado
  bool get isCancelled => status == 'cancelled';

  /// Obtener duración del viaje
  Duration? get tripDuration {
    if (startedAt != null && completedAt != null) {
      return completedAt!.difference(startedAt!);
    }
    return null;
  }

  /// Obtener duración de espera
  Duration? get waitingDuration {
    if (acceptedAt != null) {
      return acceptedAt!.difference(requestedAt);
    }
    return null;
  }

  /// Obtener estado legible
  String get statusDisplay {
    switch (status) {
      case 'requested':
        return 'Solicitado';
      case 'accepted':
        return 'Aceptado';
      case 'driver_arriving':
        return 'Conductor en camino';
      case 'in_progress':
        return 'En progreso';
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }

  @override
  String toString() {
    return 'TripModel(id: $id, status: $status, from: $pickupAddress, to: $destinationAddress)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para los resultados del cálculo de precios dinámicos
class PriceCalculationModel {
  final String id;
  final String userId;
  final String tripId;
  final double basePrice;
  final double dynamicPrice;
  final double surgePrice;
  final double finalPrice;
  final String currency;
  final Map<String, double> appliedFactors;
  final double surgeMultiplier;
  final List<AppliedDiscount> appliedDiscounts;
  final double totalDiscountAmount;
  final String vehicleType;
  final double distanceKm;
  final double estimatedDurationMinutes;
  final LocationPoint origin;
  final LocationPoint destination;
  final String geographicZone;
  final DateTime calculatedAt;
  final DateTime expiresAt;
  final bool isFallback;
  final String calculationMethod;
  final Map<String, dynamic> debugInfo;

  PriceCalculationModel({
    required this.id,
    required this.userId,
    required this.tripId,
    required this.basePrice,
    required this.dynamicPrice,
    required this.surgePrice,
    required this.finalPrice,
    required this.currency,
    required this.appliedFactors,
    required this.surgeMultiplier,
    required this.appliedDiscounts,
    required this.totalDiscountAmount,
    required this.vehicleType,
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    required this.origin,
    required this.destination,
    required this.geographicZone,
    required this.calculatedAt,
    required this.expiresAt,
    this.isFallback = false,
    this.calculationMethod = 'dynamic',
    this.debugInfo = const {},
  });

  /// Crear desde Firestore
  factory PriceCalculationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PriceCalculationModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 0.0,
      dynamicPrice: (data['dynamicPrice'] as num?)?.toDouble() ?? 0.0,
      surgePrice: (data['surgePrice'] as num?)?.toDouble() ?? 0.0,
      finalPrice: (data['finalPrice'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'PEN',
      appliedFactors: Map<String, double>.from(data['appliedFactors'] ?? {}),
      surgeMultiplier: (data['surgeMultiplier'] as num?)?.toDouble() ?? 1.0,
      appliedDiscounts: (data['appliedDiscounts'] as List<dynamic>?)
              ?.map((discount) =>
                  AppliedDiscount.fromMap(discount as Map<String, dynamic>))
              .toList() ??
          [],
      totalDiscountAmount:
          (data['totalDiscountAmount'] as num?)?.toDouble() ?? 0.0,
      vehicleType: data['vehicleType'] as String? ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
      estimatedDurationMinutes:
          (data['estimatedDurationMinutes'] as num?)?.toDouble() ?? 0.0,
      origin:
          LocationPoint.fromMap(data['origin'] as Map<String, dynamic>? ?? {}),
      destination: LocationPoint.fromMap(
          data['destination'] as Map<String, dynamic>? ?? {}),
      geographicZone: data['geographicZone'] as String? ?? 'default',
      calculatedAt:
          (data['calculatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(minutes: 15)),
      isFallback: data['isFallback'] as bool? ?? false,
      calculationMethod: data['calculationMethod'] as String? ?? 'dynamic',
      debugInfo: data['debugInfo'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'tripId': tripId,
      'basePrice': basePrice,
      'dynamicPrice': dynamicPrice,
      'surgePrice': surgePrice,
      'finalPrice': finalPrice,
      'currency': currency,
      'appliedFactors': appliedFactors,
      'surgeMultiplier': surgeMultiplier,
      'appliedDiscounts':
          appliedDiscounts.map((discount) => discount.toMap()).toList(),
      'totalDiscountAmount': totalDiscountAmount,
      'vehicleType': vehicleType,
      'distanceKm': distanceKm,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'origin': origin.toMap(),
      'destination': destination.toMap(),
      'geographicZone': geographicZone,
      'calculatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isFallback': isFallback,
      'calculationMethod': calculationMethod,
      'debugInfo': debugInfo,
    };
  }

  /// Verificar si el cálculo sigue siendo válido
  bool get isValid => DateTime.now().isBefore(expiresAt);

  /// Obtener precio con formato de moneda peruana
  String get formattedPrice => 'S/ ${finalPrice.toStringAsFixed(2)}';

  /// Obtener ahorro total por descuentos
  double get totalSavings => surgePrice - finalPrice;

  /// Verificar si hay surge pricing activo
  bool get hasSurgePrice => surgeMultiplier > 1.0;

  /// Obtener descripción del surge pricing
  String get surgeDescription {
    if (!hasSurgePrice) return '';

    final percentage = ((surgeMultiplier - 1.0) * 100).round();
    return 'Tarifa aumentada +$percentage% por alta demanda';
  }

  /// Obtener resumen de descuentos aplicados
  String get discountSummary {
    if (appliedDiscounts.isEmpty) return '';

    if (appliedDiscounts.length == 1) {
      return appliedDiscounts.first.name;
    }

    return '${appliedDiscounts.length} descuentos aplicados';
  }

  /// Crear copia con modificaciones
  PriceCalculationModel copyWith({
    String? id,
    String? userId,
    String? tripId,
    double? basePrice,
    double? dynamicPrice,
    double? surgePrice,
    double? finalPrice,
    String? currency,
    Map<String, double>? appliedFactors,
    double? surgeMultiplier,
    List<AppliedDiscount>? appliedDiscounts,
    double? totalDiscountAmount,
    String? vehicleType,
    double? distanceKm,
    double? estimatedDurationMinutes,
    LocationPoint? origin,
    LocationPoint? destination,
    String? geographicZone,
    DateTime? calculatedAt,
    DateTime? expiresAt,
    bool? isFallback,
    String? calculationMethod,
    Map<String, dynamic>? debugInfo,
  }) {
    return PriceCalculationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tripId: tripId ?? this.tripId,
      basePrice: basePrice ?? this.basePrice,
      dynamicPrice: dynamicPrice ?? this.dynamicPrice,
      surgePrice: surgePrice ?? this.surgePrice,
      finalPrice: finalPrice ?? this.finalPrice,
      currency: currency ?? this.currency,
      appliedFactors: appliedFactors ?? this.appliedFactors,
      surgeMultiplier: surgeMultiplier ?? this.surgeMultiplier,
      appliedDiscounts: appliedDiscounts ?? this.appliedDiscounts,
      totalDiscountAmount: totalDiscountAmount ?? this.totalDiscountAmount,
      vehicleType: vehicleType ?? this.vehicleType,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      geographicZone: geographicZone ?? this.geographicZone,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isFallback: isFallback ?? this.isFallback,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      debugInfo: debugInfo ?? this.debugInfo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceCalculationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PriceCalculationModel{'
        'id: $id, '
        'finalPrice: $formattedPrice, '
        'vehicleType: $vehicleType, '
        'zone: $geographicZone, '
        'hasSurge: $hasSurgePrice'
        '}';
  }
}

/// Modelo para descuentos aplicados
class AppliedDiscount {
  final String id;
  final String name;
  final String type;
  final double amount;
  final double percentage;
  final String description;
  final String promoCode;
  final DateTime appliedAt;
  final Map<String, dynamic> metadata;

  AppliedDiscount({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.percentage,
    required this.description,
    this.promoCode = '',
    DateTime? appliedAt,
    this.metadata = const {},
  }) : appliedAt = appliedAt ?? DateTime.now();

  /// Crear desde Map
  factory AppliedDiscount.fromMap(Map<String, dynamic> map) {
    return AppliedDiscount(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      promoCode: map['promoCode'] as String? ?? '',
      appliedAt: map['appliedAt'] != null
          ? (map['appliedAt'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'amount': amount,
      'percentage': percentage,
      'description': description,
      'promoCode': promoCode,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'metadata': metadata,
    };
  }

  /// Obtener monto formateado
  String get formattedAmount => 'S/ ${amount.toStringAsFixed(2)}';

  /// Obtener porcentaje formateado
  String get formattedPercentage => '${percentage.toStringAsFixed(1)}%';

  @override
  String toString() => 'AppliedDiscount{name: $name, amount: $formattedAmount}';
}

/// Modelo para punto de ubicación
class LocationPoint {
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String district;
  final String postalCode;
  final String? reference;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.city = '',
    this.district = '',
    this.postalCode = '',
    this.reference,
  });

  /// Crear desde Map
  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      district: map['district'] as String? ?? '',
      postalCode: map['postalCode'] as String? ?? '',
      reference: map['reference'] as String?,
    );
  }

  /// Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'district': district,
      'postalCode': postalCode,
      'reference': reference,
    };
  }

  /// Crear desde GeoPoint de Firestore
  factory LocationPoint.fromGeoPoint(GeoPoint geoPoint, {String address = ''}) {
    return LocationPoint(
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
      address: address,
    );
  }

  /// Convertir a GeoPoint de Firestore
  GeoPoint toGeoPoint() {
    return GeoPoint(latitude, longitude);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() =>
      'LocationPoint{lat: $latitude, lng: $longitude, address: $address}';
}

/// Modelo para factores de precio dinámico
class DynamicPricingFactors {
  final double timeFactor;
  final double demandFactor;
  final double trafficFactor;
  final double weatherFactor;
  final double eventFactor;
  final double seasonalFactor;
  final double distanceFactor;
  final double vehicleAvailabilityFactor;
  final Map<String, dynamic> customFactors;

  DynamicPricingFactors({
    required this.timeFactor,
    required this.demandFactor,
    required this.trafficFactor,
    required this.weatherFactor,
    required this.eventFactor,
    required this.seasonalFactor,
    required this.distanceFactor,
    required this.vehicleAvailabilityFactor,
    this.customFactors = const {},
  });

  /// Crear factores normales (sin modificación de precio)
  factory DynamicPricingFactors.normal() {
    return DynamicPricingFactors(
      timeFactor: 1.0,
      demandFactor: 1.0,
      trafficFactor: 1.0,
      weatherFactor: 1.0,
      eventFactor: 1.0,
      seasonalFactor: 1.0,
      distanceFactor: 1.0,
      vehicleAvailabilityFactor: 1.0,
    );
  }

  /// Crear desde Map
  factory DynamicPricingFactors.fromMap(Map<String, dynamic> map) {
    return DynamicPricingFactors(
      timeFactor: (map['timeFactor'] as num?)?.toDouble() ?? 1.0,
      demandFactor: (map['demandFactor'] as num?)?.toDouble() ?? 1.0,
      trafficFactor: (map['trafficFactor'] as num?)?.toDouble() ?? 1.0,
      weatherFactor: (map['weatherFactor'] as num?)?.toDouble() ?? 1.0,
      eventFactor: (map['eventFactor'] as num?)?.toDouble() ?? 1.0,
      seasonalFactor: (map['seasonalFactor'] as num?)?.toDouble() ?? 1.0,
      distanceFactor: (map['distanceFactor'] as num?)?.toDouble() ?? 1.0,
      vehicleAvailabilityFactor:
          (map['vehicleAvailabilityFactor'] as num?)?.toDouble() ?? 1.0,
      customFactors: map['customFactors'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'timeFactor': timeFactor,
      'demandFactor': demandFactor,
      'trafficFactor': trafficFactor,
      'weatherFactor': weatherFactor,
      'eventFactor': eventFactor,
      'seasonalFactor': seasonalFactor,
      'distanceFactor': distanceFactor,
      'vehicleAvailabilityFactor': vehicleAvailabilityFactor,
      'customFactors': customFactors,
      'combinedFactor': combinedFactor,
    };
  }

  /// Factor combinado de todos los factores
  double get combinedFactor {
    double combined = timeFactor *
        demandFactor *
        trafficFactor *
        weatherFactor *
        eventFactor *
        seasonalFactor *
        distanceFactor *
        vehicleAvailabilityFactor;

    // Aplicar factores personalizados
    for (final factor in customFactors.values) {
      if (factor is num) {
        combined *= factor.toDouble();
      }
    }

    // Limitar el factor combinado a un rango razonable
    return combined.clamp(0.5, 3.0);
  }

  /// Verificar si hay factores que incrementan el precio significativamente
  bool get hasSignificantIncrease => combinedFactor > 1.3;

  /// Verificar si hay factores que reducen el precio
  bool get hasDecrease => combinedFactor < 0.95;

  /// Obtener descripción de los factores más relevantes
  List<String> get significantFactorsDescription {
    final descriptions = <String>[];

    if (timeFactor > 1.2) descriptions.add('Hora pico');
    if (demandFactor > 1.2) descriptions.add('Alta demanda');
    if (trafficFactor > 1.2) descriptions.add('Tráfico intenso');
    if (weatherFactor > 1.1) descriptions.add('Condiciones climáticas');
    if (eventFactor > 1.1) descriptions.add('Evento especial');
    if (vehicleAvailabilityFactor > 1.2) {
      descriptions.add('Pocos vehículos disponibles');
    }

    if (timeFactor < 0.9) descriptions.add('Hora de baja demanda');
    if (demandFactor < 0.9) descriptions.add('Demanda reducida');

    return descriptions;
  }

  @override
  String toString() {
    return 'DynamicPricingFactors{combinedFactor: ${combinedFactor.toStringAsFixed(2)}}';
  }
}

/// Modelo para configuración de precios por zona
class ZonePricingConfiguration {
  final String zoneId;
  final String zoneName;
  final double baseRatePerKm;
  final double minimumFare;
  final double bookingFee;
  final double cancellationFee;
  final double waitingTimeRate;
  final Map<String, double> vehicleTypeMultipliers;
  final Map<String, double> timeSlotMultipliers;
  final bool surgeEnabled;
  final double maxSurgeMultiplier;
  final bool isActive;
  final DateTime lastUpdated;
  final Map<String, dynamic> specialRules;

  ZonePricingConfiguration({
    required this.zoneId,
    required this.zoneName,
    required this.baseRatePerKm,
    required this.minimumFare,
    required this.bookingFee,
    required this.cancellationFee,
    required this.waitingTimeRate,
    required this.vehicleTypeMultipliers,
    required this.timeSlotMultipliers,
    required this.surgeEnabled,
    required this.maxSurgeMultiplier,
    required this.isActive,
    required this.lastUpdated,
    this.specialRules = const {},
  });

  /// Crear desde Firestore
  factory ZonePricingConfiguration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ZonePricingConfiguration(
      zoneId: doc.id,
      zoneName: data['zoneName'] as String? ?? '',
      baseRatePerKm: (data['baseRatePerKm'] as num?)?.toDouble() ?? 2.5,
      minimumFare: (data['minimumFare'] as num?)?.toDouble() ?? 8.0,
      bookingFee: (data['bookingFee'] as num?)?.toDouble() ?? 2.0,
      cancellationFee: (data['cancellationFee'] as num?)?.toDouble() ?? 5.0,
      waitingTimeRate: (data['waitingTimeRate'] as num?)?.toDouble() ?? 0.5,
      vehicleTypeMultipliers:
          Map<String, double>.from(data['vehicleTypeMultipliers'] ?? {}),
      timeSlotMultipliers:
          Map<String, double>.from(data['timeSlotMultipliers'] ?? {}),
      surgeEnabled: data['surgeEnabled'] as bool? ?? true,
      maxSurgeMultiplier:
          (data['maxSurgeMultiplier'] as num?)?.toDouble() ?? 2.5,
      isActive: data['isActive'] as bool? ?? true,
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      specialRules: data['specialRules'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'zoneName': zoneName,
      'baseRatePerKm': baseRatePerKm,
      'minimumFare': minimumFare,
      'bookingFee': bookingFee,
      'cancellationFee': cancellationFee,
      'waitingTimeRate': waitingTimeRate,
      'vehicleTypeMultipliers': vehicleTypeMultipliers,
      'timeSlotMultipliers': timeSlotMultipliers,
      'surgeEnabled': surgeEnabled,
      'maxSurgeMultiplier': maxSurgeMultiplier,
      'isActive': isActive,
      'lastUpdated': FieldValue.serverTimestamp(),
      'specialRules': specialRules,
    };
  }

  /// Obtener multiplicador para tipo de vehículo
  double getVehicleMultiplier(String vehicleType) {
    return vehicleTypeMultipliers[vehicleType] ?? 1.0;
  }

  /// Obtener multiplicador para hora del día
  double getTimeSlotMultiplier(DateTime dateTime) {
    final hour = dateTime.hour;
    final timeSlot = _getTimeSlot(hour);
    return timeSlotMultipliers[timeSlot] ?? 1.0;
  }

  /// Determinar slot de tiempo
  String _getTimeSlot(int hour) {
    if (hour >= 5 && hour < 9) return 'morning_rush';
    if (hour >= 9 && hour < 17) return 'daytime';
    if (hour >= 17 && hour < 21) return 'evening_rush';
    if (hour >= 21 || hour < 5) return 'night';
    return 'normal';
  }

  @override
  String toString() =>
      'ZonePricingConfiguration{zone: $zoneName, baseRate: $baseRatePerKm}';
}

/// Modelo para análisis de demanda histórica
class DemandAnalysisData {
  final String zoneId;
  final DateTime timestamp;
  final int tripRequestCount;
  final int completedTripCount;
  final int availableDriverCount;
  final double averageWaitTime;
  final double demandSupplyRatio;
  final double averagePrice;
  final Map<String, int> vehicleTypeDemand;
  final String period; // '15min', '1hour', '1day'

  DemandAnalysisData({
    required this.zoneId,
    required this.timestamp,
    required this.tripRequestCount,
    required this.completedTripCount,
    required this.availableDriverCount,
    required this.averageWaitTime,
    required this.demandSupplyRatio,
    required this.averagePrice,
    required this.vehicleTypeDemand,
    required this.period,
  });

  /// Crear desde Firestore
  factory DemandAnalysisData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return DemandAnalysisData(
      zoneId: data['zoneId'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tripRequestCount: data['tripRequestCount'] as int? ?? 0,
      completedTripCount: data['completedTripCount'] as int? ?? 0,
      availableDriverCount: data['availableDriverCount'] as int? ?? 0,
      averageWaitTime: (data['averageWaitTime'] as num?)?.toDouble() ?? 0.0,
      demandSupplyRatio: (data['demandSupplyRatio'] as num?)?.toDouble() ?? 1.0,
      averagePrice: (data['averagePrice'] as num?)?.toDouble() ?? 0.0,
      vehicleTypeDemand: Map<String, int>.from(data['vehicleTypeDemand'] ?? {}),
      period: data['period'] as String? ?? '15min',
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'zoneId': zoneId,
      'timestamp': FieldValue.serverTimestamp(),
      'tripRequestCount': tripRequestCount,
      'completedTripCount': completedTripCount,
      'availableDriverCount': availableDriverCount,
      'averageWaitTime': averageWaitTime,
      'demandSupplyRatio': demandSupplyRatio,
      'averagePrice': averagePrice,
      'vehicleTypeDemand': vehicleTypeDemand,
      'period': period,
    };
  }

  /// Calcular factor de demanda para pricing
  double calculateDemandFactor() {
    // Factor basado en la relación demanda/oferta
    if (demandSupplyRatio <= 0.5) return 0.8; // Muy baja demanda: -20%
    if (demandSupplyRatio <= 0.8) return 0.9; // Baja demanda: -10%
    if (demandSupplyRatio <= 1.2) return 1.0; // Demanda normal
    if (demandSupplyRatio <= 1.8) return 1.3; // Alta demanda: +30%
    if (demandSupplyRatio <= 2.5) return 1.6; // Muy alta demanda: +60%
    return 2.0; // Demanda extrema: +100%
  }

  /// Verificar si se debe activar surge pricing
  bool shouldActivateSurge() {
    return demandSupplyRatio > 1.8 && averageWaitTime > 8.0;
  }

  @override
  String toString() =>
      'DemandAnalysisData{zone: $zoneId, ratio: $demandSupplyRatio}';
}

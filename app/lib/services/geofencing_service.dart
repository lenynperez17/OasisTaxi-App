import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_logger.dart';
import 'cloud_functions_service.dart';
import 'firebase_analytics_service.dart';

/// Servicio completo de Geofencing para OasisTaxi Perú
/// Maneja zonas de servicio, tarifas dinámicas y restricciones geográficas
class GeofencingService {
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionsService _functionsService = CloudFunctionsService();
  final FirebaseAnalyticsService _analytics = FirebaseAnalyticsService();

  // Cache para zonas frecuentes
  final Map<String, GeofenceZone> _zoneCache = {};
  final Map<String, List<GeofenceZone>> _cityZonesCache = {};
  DateTime _lastCacheUpdate = DateTime.now().subtract(Duration(hours: 1));
  static const Duration cacheTimeout = Duration(minutes: 30);

  // ==================== CONFIGURACIÓN PERÚ ====================

  /// Zonas principales de servicio en Perú
  static const Map<String, CityConfig> peruCities = {
    'lima': CityConfig(
      name: 'Lima',
      center: LatLng(-12.0464, -77.0428),
      radius: 50000.0, // 50km
      departamento: 'Lima',
      timezone: 'America/Lima',
    ),
    'arequipa': CityConfig(
      name: 'Arequipa',
      center: LatLng(-16.4090, -71.5375),
      radius: 30000.0, // 30km
      departamento: 'Arequipa',
      timezone: 'America/Lima',
    ),
    'trujillo': CityConfig(
      name: 'Trujillo',
      center: LatLng(-8.1116, -79.0290),
      radius: 25000.0, // 25km
      departamento: 'La Libertad',
      timezone: 'America/Lima',
    ),
    'cusco': CityConfig(
      name: 'Cusco',
      center: LatLng(-13.5319, -71.9675),
      radius: 20000.0, // 20km
      departamento: 'Cusco',
      timezone: 'America/Lima',
    ),
    'piura': CityConfig(
      name: 'Piura',
      center: LatLng(-5.1945, -80.6328),
      radius: 20000.0, // 20km
      departamento: 'Piura',
      timezone: 'America/Lima',
    ),
  };

  // ==================== INICIALIZACIÓN ====================

  /// Inicializa el servicio de geofencing
  Future<void> initialize() async {
    try {
      AppLogger.info('Inicializando Geofencing Service para Perú');

      await _loadServiceZones();
      await _setupGeofenceListeners();

      AppLogger.info('Geofencing Service inicializado correctamente');

      await _analytics.logEvent('geofencing_service_initialized', {
        'cities_count': peruCities.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error inicializando Geofencing Service', e, stackTrace);
      throw GeofencingException('Error de inicialización: $e');
    }
  }

  /// Carga las zonas de servicio desde Firestore
  Future<void> _loadServiceZones() async {
    try {
      AppLogger.info('Cargando zonas de servicio desde Firestore');

      final zonesSnapshot = await _firestore
          .collection('geofence_zones')
          .where('status', isEqualTo: 'active')
          .where('country', isEqualTo: 'PE')
          .get();

      _zoneCache.clear();
      _cityZonesCache.clear();

      for (final doc in zonesSnapshot.docs) {
        final zone = GeofenceZone.fromMap(doc.data(), doc.id);
        _zoneCache[zone.id] = zone;

        if (!_cityZonesCache.containsKey(zone.cityCode)) {
          _cityZonesCache[zone.cityCode] = [];
        }
        _cityZonesCache[zone.cityCode]!.add(zone);
      }

      _lastCacheUpdate = DateTime.now();

      AppLogger.info('Cargadas ${_zoneCache.length} zonas de geofencing');
    } catch (e, stackTrace) {
      AppLogger.error('Error cargando zonas de servicio', e, stackTrace);
      throw GeofencingException('Error cargando zonas: $e');
    }
  }

  /// Configura listeners para cambios en zonas
  Future<void> _setupGeofenceListeners() async {
    try {
      _firestore
          .collection('geofence_zones')
          .where('country', isEqualTo: 'PE')
          .snapshots()
          .listen((snapshot) {
        for (final docChange in snapshot.docChanges) {
          final zone =
              GeofenceZone.fromMap(docChange.doc.data()!, docChange.doc.id);

          switch (docChange.type) {
            case DocumentChangeType.added:
            case DocumentChangeType.modified:
              _zoneCache[zone.id] = zone;
              _updateCityCache(zone);
              break;
            case DocumentChangeType.removed:
              _zoneCache.remove(zone.id);
              _removeCityCache(zone);
              break;
          }
        }

        AppLogger.info(
            'Cache de geofencing actualizado con ${_zoneCache.length} zonas');
      });
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error configurando listeners de geofencing', e, stackTrace);
    }
  }

  // ==================== VERIFICACIÓN DE UBICACIÓN ====================

  /// Verifica si una ubicación está dentro del área de servicio
  Future<LocationValidationResult> validateLocation({
    required double latitude,
    required double longitude,
    String? userId,
    String? purpose, // 'pickup', 'dropoff', 'driver_location'
  }) async {
    try {
      final position = LatLng(latitude, longitude);

      // Verificar cache primero
      if (_needsCacheUpdate()) {
        await _loadServiceZones();
      }

      // Encontrar la ciudad más cercana
      final nearestCity = await _findNearestCity(position);
      if (nearestCity == null) {
        return LocationValidationResult(
          isValid: false,
          reason: 'Ubicación fuera del área de servicio de OasisTaxi Perú',
          cityCode: null,
          recommendedLocation: await _findNearestServicePoint(position),
        );
      }

      // Verificar zonas específicas de la ciudad
      final cityZones = _cityZonesCache[nearestCity] ?? [];
      final validZones = <GeofenceZone>[];

      for (final zone in cityZones) {
        if (await _isPointInZone(position, zone)) {
          validZones.add(zone);
        }
      }

      if (validZones.isEmpty) {
        return LocationValidationResult(
          isValid: false,
          reason: 'Ubicación fuera de las zonas de servicio activas',
          cityCode: nearestCity,
          recommendedLocation: await _findNearestZonePoint(position, cityZones),
        );
      }

      // Encontrar la mejor zona (menor tarifa surge si hay múltiples)
      final bestZone = validZones
          .reduce((a, b) => a.surgeMultiplier < b.surgeMultiplier ? a : b);

      await _analytics.logEvent('location_validated', {
        'city_code': nearestCity,
        'zone_id': bestZone.id,
        'zone_type': bestZone.type.toString(),
        'purpose': purpose ?? 'unknown',
        'user_id': userId,
      });

      return LocationValidationResult(
        isValid: true,
        reason: 'Ubicación válida en ${bestZone.displayName}',
        cityCode: nearestCity,
        zone: bestZone,
        surgeMultiplier: bestZone.surgeMultiplier,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error validando ubicación', e, stackTrace);
      throw GeofencingException('Error de validación: $e');
    }
  }

  /// Encuentra la ciudad más cercana que tenga servicio
  Future<String?> _findNearestCity(LatLng position) async {
    double minDistance = double.infinity;
    String? nearestCity;

    for (final entry in peruCities.entries) {
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        entry.value.center.latitude,
        entry.value.center.longitude,
      );

      if (distance <= entry.value.radius && distance < minDistance) {
        minDistance = distance;
        nearestCity = entry.key;
      }
    }

    return nearestCity;
  }

  /// Verifica si un punto está dentro de una zona específica
  Future<bool> _isPointInZone(LatLng point, GeofenceZone zone) async {
    switch (zone.geometry.type) {
      case GeofenceType.circle:
        final distance = _calculateDistance(
          point.latitude,
          point.longitude,
          zone.geometry.center.latitude,
          zone.geometry.center.longitude,
        );
        return distance <= zone.geometry.radius;

      case GeofenceType.polygon:
        return _isPointInPolygon(point, zone.geometry.vertices);

      default:
        return false;
    }
  }

  /// Verifica si un punto está dentro de un polígono
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersections = 0;
    final x = point.longitude;
    final y = point.latitude;

    for (int i = 0; i < polygon.length; i++) {
      final vertex1 = polygon[i];
      final vertex2 = polygon[(i + 1) % polygon.length];

      if (((vertex1.latitude > y) != (vertex2.latitude > y)) &&
          (x <
              (vertex2.longitude - vertex1.longitude) *
                      (y - vertex1.latitude) /
                      (vertex2.latitude - vertex1.latitude) +
                  vertex1.longitude)) {
        intersections++;
      }
    }

    return intersections % 2 == 1;
  }

  // ==================== GESTIÓN DE CONDUCTORES ====================

  /// Registra entrada de conductor a una zona
  Future<void> registerDriverEnter({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final validationResult = await validateLocation(
        latitude: latitude,
        longitude: longitude,
        userId: driverId,
        purpose: 'driver_location',
      );

      if (!validationResult.isValid) {
        throw GeofencingException('Conductor fuera de zona de servicio');
      }

      await _functionsService.callFunction(
        'updateDriverZoneStatus',
        parameters: {
          'driver_id': driverId,
          'zone_id': validationResult.zone?.id,
          'city_code': validationResult.cityCode,
          'status': 'entered',
          'timestamp': FieldValue.serverTimestamp(),
          'location': GeoPoint(latitude, longitude),
        },
      );

      AppLogger.info(
          'Conductor $driverId registrado en zona ${validationResult.zone?.displayName}');

      await _analytics.logEvent('driver_entered_zone', {
        'driver_id': driverId,
        'zone_id': validationResult.zone?.id,
        'city_code': validationResult.cityCode,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error registrando entrada de conductor', e, stackTrace);
      rethrow;
    }
  }

  /// Registra salida de conductor de una zona
  Future<void> registerDriverExit({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _functionsService.callFunction(
        'updateDriverZoneStatus',
        parameters: {
          'driver_id': driverId,
          'status': 'exited',
          'timestamp': FieldValue.serverTimestamp(),
          'location': GeoPoint(latitude, longitude),
        },
      );

      AppLogger.info('Conductor $driverId registrado salida de zona');

      await _analytics.logEvent('driver_exited_zone', {
        'driver_id': driverId,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error registrando salida de conductor', e, stackTrace);
      rethrow;
    }
  }

  // ==================== TARIFAS DINÁMICAS ====================

  /// Calcula el multiplicador de tarifa para una ubicación
  Future<double> calculateSurgeMultiplier({
    required double pickupLatitude,
    required double pickupLongitude,
    String? dropoffLatitude,
    String? dropoffLongitude,
  }) async {
    try {
      final pickupValidation = await validateLocation(
        latitude: pickupLatitude,
        longitude: pickupLongitude,
        purpose: 'pickup',
      );

      if (!pickupValidation.isValid) {
        return 1.0; // Sin surge si está fuera de zona
      }

      double maxSurge = pickupValidation.surgeMultiplier ?? 1.0;

      // Si hay destino, verificar también esa zona
      if (dropoffLatitude != null && dropoffLongitude != null) {
        final dropoffValidation = await validateLocation(
          latitude: double.parse(dropoffLatitude),
          longitude: double.parse(dropoffLongitude),
          purpose: 'dropoff',
        );

        if (dropoffValidation.isValid &&
            dropoffValidation.surgeMultiplier != null) {
          maxSurge = math.max(maxSurge, dropoffValidation.surgeMultiplier!);
        }
      }

      await _analytics.logEvent('surge_calculated', {
        'pickup_zone': pickupValidation.zone?.id,
        'surge_multiplier': maxSurge,
      });

      return maxSurge;
    } catch (e, stackTrace) {
      AppLogger.error('Error calculando surge multiplier', e, stackTrace);
      return 1.0; // Tarifa base en caso de error
    }
  }

  // ==================== UTILIDADES ====================

  /// Calcula la distancia entre dos puntos usando fórmula Haversine
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Radio de la Tierra en metros

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Encuentra el punto de servicio más cercano
  Future<LatLng?> _findNearestServicePoint(LatLng position) async {
    LatLng? nearest;
    double minDistance = double.infinity;

    for (final city in peruCities.values) {
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        city.center.latitude,
        city.center.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = city.center;
      }
    }

    return nearest;
  }

  /// Encuentra el punto más cercano dentro de zonas válidas
  Future<LatLng?> _findNearestZonePoint(
      LatLng position, List<GeofenceZone> zones) async {
    if (zones.isEmpty) return null;

    // Por simplicidad, retornamos el centro de la zona más cercana
    GeofenceZone? nearestZone;
    double minDistance = double.infinity;

    for (final zone in zones) {
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        zone.geometry.center.latitude,
        zone.geometry.center.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestZone = zone;
      }
    }

    return nearestZone?.geometry.center;
  }

  /// Verifica si necesita actualizar cache
  bool _needsCacheUpdate() {
    return DateTime.now().difference(_lastCacheUpdate) > cacheTimeout;
  }

  /// Actualiza cache de ciudad para una zona
  void _updateCityCache(GeofenceZone zone) {
    if (!_cityZonesCache.containsKey(zone.cityCode)) {
      _cityZonesCache[zone.cityCode] = [];
    }

    final cityZones = _cityZonesCache[zone.cityCode]!;
    final existingIndex = cityZones.indexWhere((z) => z.id == zone.id);

    if (existingIndex != -1) {
      cityZones[existingIndex] = zone;
    } else {
      cityZones.add(zone);
    }
  }

  /// Remueve zona del cache de ciudad
  void _removeCityCache(GeofenceZone zone) {
    final cityZones = _cityZonesCache[zone.cityCode];
    if (cityZones != null) {
      cityZones.removeWhere((z) => z.id == zone.id);
      if (cityZones.isEmpty) {
        _cityZonesCache.remove(zone.cityCode);
      }
    }
  }

  // ==================== ANÁLISIS Y REPORTING ====================

  /// Obtiene estadísticas de zonas
  Future<GeofenceStats> getZoneStatistics(String? cityCode) async {
    try {
      final stats = GeofenceStats();

      final zones = cityCode != null
          ? (_cityZonesCache[cityCode] ?? [])
          : _zoneCache.values.toList();

      stats.totalZones = zones.length;
      stats.activeZones = zones.where((z) => z.isActive).length;

      for (final zone in zones) {
        if (zone.surgeMultiplier > 1.0) {
          stats.surgeZones++;
        }

        switch (zone.type) {
          case ZoneType.airport:
            stats.airportZones++;
            break;
          case ZoneType.downtown:
            stats.downtownZones++;
            break;
          case ZoneType.residential:
            stats.residentialZones++;
            break;
          case ZoneType.commercial:
            stats.commercialZones++;
            break;
          default:
            break;
        }
      }

      return stats;
    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo estadísticas de zonas', e, stackTrace);
      throw GeofencingException('Error estadísticas: $e');
    }
  }

  /// Limpia el cache
  void clearCache() {
    _zoneCache.clear();
    _cityZonesCache.clear();
    _lastCacheUpdate = DateTime.now().subtract(Duration(hours: 1));
    AppLogger.info('Cache de geofencing limpiado');
  }
}

// ==================== MODELOS DE DATOS ====================

class GeofenceZone {
  final String id;
  final String displayName;
  final String cityCode;
  final ZoneType type;
  final GeofenceGeometry geometry;
  final double surgeMultiplier;
  final bool isActive;
  final Map<String, dynamic> restrictions;
  final DateTime createdAt;
  final DateTime updatedAt;

  GeofenceZone({
    required this.id,
    required this.displayName,
    required this.cityCode,
    required this.type,
    required this.geometry,
    required this.surgeMultiplier,
    required this.isActive,
    required this.restrictions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GeofenceZone.fromMap(Map<String, dynamic> map, String id) {
    return GeofenceZone(
      id: id,
      displayName: map['display_name'] ?? '',
      cityCode: map['city_code'] ?? '',
      type: ZoneType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ZoneType.general,
      ),
      geometry: GeofenceGeometry.fromMap(map['geometry']),
      surgeMultiplier: (map['surge_multiplier'] ?? 1.0).toDouble(),
      isActive: map['is_active'] ?? true,
      restrictions: Map<String, dynamic>.from(map['restrictions'] ?? {}),
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'display_name': displayName,
      'city_code': cityCode,
      'type': type.toString().split('.').last,
      'geometry': geometry.toMap(),
      'surge_multiplier': surgeMultiplier,
      'is_active': isActive,
      'restrictions': restrictions,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
}

class GeofenceGeometry {
  final GeofenceType type;
  final LatLng center;
  final double radius; // Para círculos
  final List<LatLng> vertices; // Para polígonos

  GeofenceGeometry({
    required this.type,
    required this.center,
    this.radius = 0.0,
    this.vertices = const [],
  });

  factory GeofenceGeometry.fromMap(Map<String, dynamic> map) {
    return GeofenceGeometry(
      type: GeofenceType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => GeofenceType.circle,
      ),
      center: LatLng(
        map['center']['latitude']?.toDouble() ?? 0.0,
        map['center']['longitude']?.toDouble() ?? 0.0,
      ),
      radius: (map['radius'] ?? 0.0).toDouble(),
      vertices: (map['vertices'] as List<dynamic>?)
              ?.map((v) => LatLng(
                    v['latitude']?.toDouble() ?? 0.0,
                    v['longitude']?.toDouble() ?? 0.0,
                  ))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'center': {
        'latitude': center.latitude,
        'longitude': center.longitude,
      },
      'radius': radius,
      'vertices': vertices
          .map((v) => {
                'latitude': v.latitude,
                'longitude': v.longitude,
              })
          .toList(),
    };
  }
}

class LocationValidationResult {
  final bool isValid;
  final String reason;
  final String? cityCode;
  final GeofenceZone? zone;
  final double? surgeMultiplier;
  final LatLng? recommendedLocation;

  LocationValidationResult({
    required this.isValid,
    required this.reason,
    this.cityCode,
    this.zone,
    this.surgeMultiplier,
    this.recommendedLocation,
  });
}

class CityConfig {
  final String name;
  final LatLng center;
  final double radius;
  final String departamento;
  final String timezone;

  const CityConfig({
    required this.name,
    required this.center,
    required this.radius,
    required this.departamento,
    required this.timezone,
  });
}

class GeofenceStats {
  int totalZones = 0;
  int activeZones = 0;
  int surgeZones = 0;
  int airportZones = 0;
  int downtownZones = 0;
  int residentialZones = 0;
  int commercialZones = 0;
}

// ==================== ENUMS ====================

enum GeofenceType {
  circle,
  polygon,
  rectangle,
}

enum ZoneType {
  general,
  airport,
  downtown,
  residential,
  commercial,
  industrial,
  tourist,
  restricted,
}

// ==================== EXCEPCIONES ====================

class GeofencingException implements Exception {
  final String message;
  GeofencingException(this.message);

  @override
  String toString() => 'GeofencingException: $message';
}

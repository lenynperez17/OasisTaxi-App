import '../utils/app_logger.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'http_client.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'firebase_service.dart';
import 'location_service.dart';
import 'google_maps_service.dart';
import 'geofencing_service.dart';
import '../core/config/environment_config.dart';

/// SERVICIO DE TRACKING EN TIEMPO REAL - FLUTTER
/// ==============================================
///
/// Funcionalidades implementadas:
/// 📍 Actualización de ubicación cada 5 segundos
/// 🗺️ Cálculo de ETA dinámico usando Google Directions API
/// 📊 Historial completo de ruta guardado localmente y en servidor
/// 🔄 Emisión en tiempo real vía Socket.IO a pasajeros/conductores
/// 📏 Cálculo de distancias y tiempo de viaje exacto
/// 🚦 Optimización de rutas en tiempo real según tráfico
/// ⚠️ Detección de desvíos de ruta y alertas automáticas
/// 📱 Notificaciones push cuando cambia la ubicación/ETA
class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  final HttpClient _httpClient = HttpClient();

  final FirebaseService _firebaseService = FirebaseService();
  final LocationService _locationService = LocationService();
  final GoogleMapsService _mapsService = GoogleMapsService();
  final GeofencingService _geofencingService = GeofencingService();

  bool _initialized = false;
  bool _trackingActive = false;
  String? _activeSessionId;
  Timer? _locationUpdateTimer;
  Timer? _etaRecalcTimer;
  late String _apiBaseUrl;
  io.Socket? _socket;

  // URLs de la API backend
  static const String _localApi = 'http://localhost:3000/api/v1';
  static const String _productionApi = 'https://api.oasistaxiperu.com/api/v1';

  // Configuración de tracking
  static const int _updateIntervalSeconds = 5; // Actualizar cada 5 segundos

  // Helper para convertir valores a int de forma segura
  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) {
      if (value.isNaN || value.isInfinite) return 0;
      return value.toInt();
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed == null || parsed.isNaN || parsed.isInfinite) return 0;
      return parsed.toInt();
    }
    return 0;
  }

  /// Inicializar el servicio de tracking
  Future<void> initialize({bool isProduction = false}) async {
    if (_initialized) return;

    try {
      _apiBaseUrl = isProduction ? _productionApi : _localApi;

      await _firebaseService.initialize();
      await _locationService.initialize();

      // Initialize GoogleMapsService if not already initialized
      if (!_mapsService.isInitialized) {
        await _mapsService.initialize(
          googleMapsApiKey: EnvironmentConfig.googleMapsApiKey,
        );
        AppLogger.debug('📍 TrackingService: GoogleMapsService inicializado');
      }

      // Configurar Socket.IO para actualizaciones en tiempo real
      await _initializeSocket(isProduction);

      _initialized = true;
      AppLogger.debug('📍 TrackingService: Inicializado correctamente');

      await _firebaseService.analytics?.logEvent(
        name: 'tracking_service_initialized',
        parameters: {},
      );
    } catch (e) {
      AppLogger.debug('📍 TrackingService: Error inicializando - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      _initialized = true; // Continuar en modo desarrollo
    }
  }

  // ============================================================================
  // INICIAR Y DETENER TRACKING
  // ============================================================================

  /// Iniciar tracking para un viaje
  Future<TrackingResult> startTracking({
    required String rideId,
    required String driverId,
    required String passengerId,
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      if (_trackingActive) {
        return TrackingResult.error('Ya hay un tracking activo');
      }

      AppLogger.debug(
          '📍 TrackingService: Iniciando tracking para viaje $rideId');

      // 1. OBTENER UBICACIÓN INICIAL DEL CONDUCTOR
      final currentPosition = await _locationService.getCurrentLocation();
      if (currentPosition == null) {
        return TrackingResult.error('No se pudo obtener la ubicación actual');
      }

      // 2. LLAMAR AL BACKEND PARA INICIAR TRACKING
      final response = await _httpClient.post(
        '$_apiBaseUrl/tracking/start',
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'rideId': rideId,
          'driverId': driverId,
          'passengerId': passengerId,
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
          'initialDriverLocation': {
            'driverId': driverId,
            'latitude': currentPosition.latitude,
            'longitude': currentPosition.longitude,
            'accuracy': currentPosition.accuracy,
            'heading': currentPosition.heading,
            'speed': currentPosition.speed,
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['success']) {
          final sessionId = data['sessionId'];
          _activeSessionId = sessionId;
          _trackingActive = true;

          // 3. INICIAR ACTUALIZACIONES PERIÓDICAS DE UBICACIÓN
          await _startLocationUpdates(driverId, rideId);

          // 4. UNIRSE A LA SALA DE SOCKET.IO PARA ESTE VIAJE
          _socket?.emit('join_ride', rideId);

          await _firebaseService.analytics?.logEvent(
            name: 'tracking_started',
            parameters: {
              'ride_id': rideId,
              'driver_id': driverId,
              'passenger_id': passengerId,
              'session_id': sessionId,
            },
          );

          AppLogger.debug(
              '📍 TrackingService: Tracking iniciado - Sesión: $sessionId');

          return TrackingResult.success(
            sessionId: sessionId,
            message: 'Tracking iniciado exitosamente',
          );
        } else {
          return TrackingResult.error(
              data['message'] ?? 'Error iniciando tracking');
        }
      } else {
        return TrackingResult.error(
            'Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('📍 TrackingService: Error iniciando tracking - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return TrackingResult.error('Error iniciando tracking: $e');
    }
  }

  /// Detener tracking activo
  Future<bool> stopTracking(String rideId) async {
    try {
      if (!_trackingActive || _activeSessionId == null) {
        return false;
      }

      // 1. DETENER TIMERS DE ACTUALIZACIÓN
      _locationUpdateTimer?.cancel();
      _etaRecalcTimer?.cancel();

      // 2. LLAMAR AL BACKEND PARA FINALIZAR TRACKING
      final response = await _httpClient.post(
        '$_apiBaseUrl/tracking/stop',
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sessionId': _activeSessionId,
          'rideId': rideId,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['success']) {
          // 3. SALIR DE LA SALA DE SOCKET.IO
          _socket?.emit('leave_ride', rideId);

          _trackingActive = false;
          _activeSessionId = null;

          await _firebaseService.analytics?.logEvent(
            name: 'tracking_stopped',
            parameters: {
              'ride_id': rideId,
            },
          );

          AppLogger.debug('📍 TrackingService: Tracking detenido exitosamente');
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLogger.debug('📍 TrackingService: Error deteniendo tracking - $e');
      return false;
    }
  }

  // ============================================================================
  // CÁLCULO DE RUTAS Y ETA
  // ============================================================================

  /// Calcular ruta entre dos puntos
  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    bool avoidTolls = false,
    bool optimizeWaypoints = false,
  }) async {
    try {
      final response = await _httpClient.post(
        '$_apiBaseUrl/tracking/calculate-route',
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
          if (waypoints != null)
            'waypoints': waypoints
                .map((point) => {
                      'latitude': point.latitude,
                      'longitude': point.longitude,
                    })
                .toList(),
          'avoidTolls': avoidTolls,
          'optimizeWaypoints': optimizeWaypoints,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['success']) {
          final routeData = data['data'];

          return RouteResult.success(
            distance: routeData['distance'].toDouble(), // metros
            duration: _safeToInt(routeData['duration']), // segundos
            polyline: routeData['polyline'],
            steps: (routeData['steps'] as List)
                .map((step) => RouteStep(
                      instruction: step['instruction'],
                      distance: step['distance'].toDouble(),
                      duration: _safeToInt(step['duration']),
                      startLocation: LatLng(
                        step['startLocation']['latitude'],
                        step['startLocation']['longitude'],
                      ),
                      endLocation: LatLng(
                        step['endLocation']['latitude'],
                        step['endLocation']['longitude'],
                      ),
                    ))
                .toList(),
          );
        } else {
          return RouteResult.error(data['message'] ?? 'Error calculando ruta');
        }
      } else {
        return RouteResult.error(
            'Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('📍 TrackingService: Error calculando ruta - $e');
      return RouteResult.error('Error calculando ruta: $e');
    }
  }

  /// Calcular ETA dinámico
  Future<ETAResult> calculateDynamicETA({
    required LatLng currentLocation,
    required LatLng destination,
  }) async {
    try {
      final response = await _httpClient.post(
        '$_apiBaseUrl/tracking/calculate-eta',
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'currentLocation': {
            'latitude': currentLocation.latitude,
            'longitude': currentLocation.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['success']) {
          final etaData = data['data'];

          return ETAResult.success(
            eta: DateTime.parse(etaData['eta']),
            duration: _safeToInt(etaData['duration']),
            distance: etaData['distance'].toDouble(),
          );
        } else {
          return ETAResult.error(data['message'] ?? 'Error calculando ETA');
        }
      } else {
        return ETAResult.error('Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('📍 TrackingService: Error calculando ETA - $e');
      return ETAResult.error('Error calculando ETA: $e');
    }
  }

  /// Obtener polyline de ruta para mostrar en el mapa
  Future<String?> getRoutePolyline(LatLng origin, LatLng destination) async {
    final routeResult =
        await calculateRoute(origin: origin, destination: destination);
    return routeResult.success ? routeResult.polyline : null;
  }

  /// Optimizar ruta con múltiples paradas
  Future<RouteOptimizationResult> optimizeMultiStopRoute({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
    String? driverId,
  }) async {
    try {
      if (!EnvironmentConfig.routeOptimizationEnabled) {
        return RouteOptimizationResult.error('Optimización de rutas deshabilitada');
      }

      // Validate all locations with geofencing
      final validationResults = <LocationValidationResult>[];

      // Validate origin
      final originValidation = await _geofencingService.validateLocation(
        latitude: origin.latitude,
        longitude: origin.longitude,
        userId: driverId,
        purpose: 'pickup',
      );
      validationResults.add(originValidation);

      // Validate destination
      final destValidation = await _geofencingService.validateLocation(
        latitude: destination.latitude,
        longitude: destination.longitude,
        userId: driverId,
        purpose: 'dropoff',
      );
      validationResults.add(destValidation);

      // Validate waypoints
      for (int i = 0; i < waypoints.length; i++) {
        final waypointValidation = await _geofencingService.validateLocation(
          latitude: waypoints[i].latitude,
          longitude: waypoints[i].longitude,
          userId: driverId,
          purpose: 'waypoint',
        );
        validationResults.add(waypointValidation);
      }

      // Check if any location is invalid
      final invalidLocations = validationResults
          .where((result) => !result.isValid)
          .toList();

      if (invalidLocations.isNotEmpty) {
        return RouteOptimizationResult.error(
          'Ubicaciones fuera de zona de servicio: ${invalidLocations.map((l) => l.reason).join(', ')}'
        );
      }

      // Get optimized route from Google Maps
      final optimizedRoute = await _mapsService.getOptimizedRoute(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        travelMode: TravelMode.driving,
        avoidTolls: false,
        avoidHighways: false,
      );

      if (!optimizedRoute.success) {
        return RouteOptimizationResult.error(
          optimizedRoute.error ?? 'Error optimizando ruta'
        );
      }

      // Calculate surge pricing for the route
      double totalSurgeMultiplier = 1.0;
      for (final validation in validationResults) {
        if (validation.surgeMultiplier != null) {
          totalSurgeMultiplier = math.max(totalSurgeMultiplier, validation.surgeMultiplier!);
        }
      }

      AppLogger.info(
        'Ruta optimizada: ${(optimizedRoute.distanceValue! / 1000).toStringAsFixed(1)} km, '
        '${(optimizedRoute.durationValue! / 60).round()} min, '
        'surge: ${totalSurgeMultiplier}x'
      );

      return RouteOptimizationResult.success(
        optimizedRoute: optimizedRoute,
        surgeMultiplier: totalSurgeMultiplier,
        validationResults: validationResults,
        estimatedCost: _calculateEstimatedCost(
          optimizedRoute.distanceValue!.toDouble(),
          optimizedRoute.durationValue!,
          totalSurgeMultiplier,
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error optimizando ruta multi-parada', e, stackTrace);
      return RouteOptimizationResult.error('Error de optimización: $e');
    }
  }

  /// Calcular costo estimado del viaje
  double _calculateEstimatedCost(double distanceMeters, int durationSeconds, double surgeMultiplier) {
    final distanceKm = distanceMeters / 1000;
    final durationMinutes = durationSeconds / 60;

    final baseCost = EnvironmentConfig.baseFareAmount;
    final distanceCost = distanceKm * EnvironmentConfig.pricePerKm;
    final timeCost = durationMinutes * EnvironmentConfig.pricePerMinute;

    final totalCost = (baseCost + distanceCost + timeCost) * surgeMultiplier;

    return math.max(totalCost, EnvironmentConfig.minimumFare);
  }

  // ============================================================================
  // INFORMACIÓN DE TRACKING
  // ============================================================================

  /// Obtener información completa de tracking
  Future<TrackingInfo?> getTrackingInfo(String sessionId) async {
    try {
      final response = await _httpClient.get(
        '$_apiBaseUrl/tracking/info/$sessionId',
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['success']) {
          final trackingData = data['data'];

          return TrackingInfo(
            sessionId: trackingData['sessionId'],
            rideId: trackingData['rideId'],
            driverId: trackingData['driverId'],
            passengerId: trackingData['passengerId'],
            isActive: trackingData['isActive'],
            currentLocation: LatLng(
              trackingData['currentLocation']['latitude'],
              trackingData['currentLocation']['longitude'],
            ),
            destination: LatLng(
              trackingData['destination']['latitude'],
              trackingData['destination']['longitude'],
            ),
            estimatedArrival: DateTime.parse(trackingData['estimatedArrival']),
            totalDistance: trackingData['totalDistance']?.toDouble() ?? 0.0,
            totalDuration: _safeToInt(trackingData['totalDuration']),
            startedAt: DateTime.parse(trackingData['startedAt']),
            completedAt: trackingData['completedAt'] != null
                ? DateTime.parse(trackingData['completedAt'])
                : null,
          );
        }
      }

      return null;
    } catch (e) {
      AppLogger.debug(
          '📍 TrackingService: Error obteniendo info de tracking - $e');
      return null;
    }
  }

  /// Obtener tracking activo por viaje
  Future<TrackingInfo?> getActiveTrackingByRide(String rideId) async {
    try {
      final response = await _httpClient.get(
        '$_apiBaseUrl/tracking/active/$rideId',
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['success'] && data['data'] != null) {
          final trackingData = data['data'];

          return TrackingInfo(
            sessionId: trackingData['sessionId'],
            rideId: trackingData['rideId'],
            driverId: trackingData['driverId'],
            passengerId: trackingData['passengerId'],
            isActive: trackingData['isActive'],
            currentLocation: LatLng(
              trackingData['currentLocation']['latitude'],
              trackingData['currentLocation']['longitude'],
            ),
            destination: LatLng(
              trackingData['destination']['latitude'],
              trackingData['destination']['longitude'],
            ),
            estimatedArrival: DateTime.parse(trackingData['estimatedArrival']),
            totalDistance: trackingData['totalDistance']?.toDouble() ?? 0.0,
            totalDuration: _safeToInt(trackingData['totalDuration']),
            startedAt: DateTime.parse(trackingData['startedAt']),
            completedAt: trackingData['completedAt'] != null
                ? DateTime.parse(trackingData['completedAt'])
                : null,
          );
        }
      }

      return null;
    } catch (e) {
      AppLogger.debug(
          '📍 TrackingService: Error obteniendo tracking activo - $e');
      return null;
    }
  }

  // ============================================================================
  // STREAMS PARA ACTUALIZACIONES EN TIEMPO REAL
  // ============================================================================

  /// Stream de actualizaciones de ubicación
  Stream<TrackingUpdate> getTrackingUpdates(String rideId) {
    final controller = StreamController<TrackingUpdate>.broadcast();

    if (_socket != null) {
      _socket!.on('tracking_update', (data) {
        try {
          final update = TrackingUpdate(
            type: data['type'],
            sessionId: data['sessionId'],
            rideId: data['rideId'],
            currentLocation: data['currentLocation'] != null
                ? LatLng(
                    data['currentLocation']['latitude'],
                    data['currentLocation']['longitude'],
                  )
                : null,
            estimatedArrival: data['estimatedArrival'] != null
                ? DateTime.parse(data['estimatedArrival'])
                : null,
            hasDeviated: data['deviation']?['hasDeviated'] ?? false,
            deviationDistance:
                data['deviation']?['deviationDistance']?.toDouble(),
            timestamp: DateTime.parse(data['timestamp']),
          );

          controller.add(update);
        } catch (e) {
          AppLogger.debug(
              '📍 TrackingService: Error procesando actualización - $e');
        }
      });
    }

    return controller.stream;
  }

  // ============================================================================
  // MÉTODOS PRIVADOS
  // ============================================================================

  /// Inicializar conexión Socket.IO
  Future<void> _initializeSocket(bool isProduction) async {
    try {
      final socketUrl = isProduction
          ? 'https://api.oasistaxiperu.com'
          : 'http://localhost:3000';

      _socket = io.io(
          socketUrl,
          io.OptionBuilder()
              .setTransports(['websocket'])
              .enableAutoConnect()
              .build());

      _socket!.connect();

      _socket!.onConnect((_) {
        AppLogger.debug('📍 TrackingService: Socket.IO conectado');
      });

      _socket!.onDisconnect((_) {
        AppLogger.debug('📍 TrackingService: Socket.IO desconectado');
      });
    } catch (e) {
      AppLogger.debug('📍 TrackingService: Error inicializando Socket.IO - $e');
    }
  }

  /// Iniciar actualizaciones periódicas de ubicación
  Future<void> _startLocationUpdates(String driverId, String rideId) async {
    _locationUpdateTimer = Timer.periodic(
      Duration(seconds: _updateIntervalSeconds),
      (timer) async {
        try {
          final position = await _locationService.getCurrentLocation();
          if (position != null) {
            await _updateDriverLocation(
              driverId: driverId,
              position: position,
              rideId: rideId,
            );
          }
        } catch (e) {
          AppLogger.debug(
              '📍 TrackingService: Error en actualización de ubicación - $e');
        }
      },
    );

    AppLogger.debug(
        '📍 TrackingService: Actualizaciones de ubicación iniciadas cada $_updateIntervalSeconds segundos');
  }

  /// Monitorear geofencing durante el tracking
  Future<void> _monitorGeofencing(String driverId, Position position, String rideId) async {
    try {
      // Validate current location
      final validation = await _geofencingService.validateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        userId: driverId,
        purpose: 'driver_location',
      );

      if (!validation.isValid) {
        // Driver is outside service area
        AppLogger.warning('Conductor $driverId fuera de zona de servicio: ${validation.reason}');

        // Notify backend about zone violation
        await _httpClient.post(
          '$_apiBaseUrl/tracking/zone-violation',
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'driverId': driverId,
            'rideId': rideId,
            'location': {
              'latitude': position.latitude,
              'longitude': position.longitude,
            },
            'violationReason': validation.reason,
            'recommendedLocation': validation.recommendedLocation != null ? {
              'latitude': validation.recommendedLocation!.latitude,
              'longitude': validation.recommendedLocation!.longitude,
            } : null,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
      } else {
        // Register driver in zone
        await _geofencingService.registerDriverEnter(
          driverId: driverId,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (e) {
      AppLogger.error('Error monitoreando geofencing', e);
    }
  }

  /// Actualizar ubicación del conductor con monitoreo de geofencing
  Future<void> _updateDriverLocation({
    required String driverId,
    required Position position,
    String? rideId,
  }) async {
    try {
      // Monitor geofencing if ride is active
      if (rideId != null) {
        await _monitorGeofencing(driverId, position, rideId);
      }

      final response = await _httpClient.post(
        '$_apiBaseUrl/tracking/update-location',
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'driverId': driverId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'heading': position.heading,
          'speed': position.speed,
          if (rideId != null) 'rideId': rideId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        AppLogger.debug(
            '📍 TrackingService: Error actualizando ubicación - ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('📍 TrackingService: Error enviando ubicación - $e');
    }
  }

  // Dispose resources
  void dispose() {
    _locationUpdateTimer?.cancel();
    _etaRecalcTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
  }

  // Getters
  bool get isInitialized => _initialized;
  bool get isTrackingActive => _trackingActive;
  String? get activeSessionId => _activeSessionId;
}

// ============================================================================
// CLASES DE DATOS Y RESULTADOS
// ============================================================================

/// Resultado de operación de tracking
class TrackingResult {
  final bool success;
  final String? sessionId;
  final String? message;
  final String? error;

  TrackingResult.success({
    required this.sessionId,
    required this.message,
  })  : success = true,
        error = null;

  TrackingResult.error(this.error)
      : success = false,
        sessionId = null,
        message = null;
}

/// Resultado de cálculo de ruta
class RouteResult {
  final bool success;
  final double? distance; // metros
  final int? duration; // segundos
  final String? polyline;
  final List<RouteStep>? steps;
  final String? error;

  RouteResult.success({
    required this.distance,
    required this.duration,
    required this.polyline,
    required this.steps,
  })  : success = true,
        error = null;

  RouteResult.error(this.error)
      : success = false,
        distance = null,
        duration = null,
        polyline = null,
        steps = null;
}

/// Paso de ruta
class RouteStep {
  final String instruction;
  final double distance;
  final int duration;
  final LatLng startLocation;
  final LatLng endLocation;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });
}

/// Resultado de cálculo de ETA
class ETAResult {
  final bool success;
  final DateTime? eta;
  final int? duration; // segundos
  final double? distance; // metros
  final String? error;

  ETAResult.success({
    required this.eta,
    required this.duration,
    required this.distance,
  })  : success = true,
        error = null;

  ETAResult.error(this.error)
      : success = false,
        eta = null,
        duration = null,
        distance = null;
}

/// Información de tracking
class TrackingInfo {
  final String sessionId;
  final String rideId;
  final String driverId;
  final String passengerId;
  final bool isActive;
  final LatLng currentLocation;
  final LatLng destination;
  final DateTime estimatedArrival;
  final double totalDistance;
  final int totalDuration;
  final DateTime startedAt;
  final DateTime? completedAt;

  TrackingInfo({
    required this.sessionId,
    required this.rideId,
    required this.driverId,
    required this.passengerId,
    required this.isActive,
    required this.currentLocation,
    required this.destination,
    required this.estimatedArrival,
    required this.totalDistance,
    required this.totalDuration,
    required this.startedAt,
    this.completedAt,
  });
}

/// Actualización de tracking en tiempo real
class TrackingUpdate {
  final String type; // 'location_updated', 'route_recalculated', etc.
  final String sessionId;
  final String rideId;
  final LatLng? currentLocation;
  final DateTime? estimatedArrival;
  final bool hasDeviated;
  final double? deviationDistance;
  final DateTime timestamp;

  TrackingUpdate({
    required this.type,
    required this.sessionId,
    required this.rideId,
    this.currentLocation,
    this.estimatedArrival,
    required this.hasDeviated,
    this.deviationDistance,
    required this.timestamp,
  });
}

/// Resultado de optimización de ruta con múltiples paradas
class RouteOptimizationResult {
  final bool success;
  final DirectionsResult? optimizedRoute;
  final double? surgeMultiplier;
  final double? estimatedCost;
  final List<LatLng>? optimizedWaypoints;
  final List<LocationValidationResult>? validationResults;
  final String? error;

  RouteOptimizationResult.success({
    required this.optimizedRoute,
    required this.surgeMultiplier,
    required this.estimatedCost,
    required this.validationResults,
    this.optimizedWaypoints,
  })  : success = true,
        error = null;

  RouteOptimizationResult.error(this.error)
      : success = false,
        optimizedRoute = null,
        surgeMultiplier = null,
        estimatedCost = null,
        optimizedWaypoints = null,
        validationResults = null;
}

/// Estados de tracking
enum TrackingStatus {
  inactive,
  starting,
  active,
  paused,
  completed,
  error,
}

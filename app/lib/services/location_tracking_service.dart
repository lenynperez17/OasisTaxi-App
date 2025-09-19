import '../utils/app_logger.dart';
import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  Timer? _trackingTimer;
  StreamSubscription<Position>? _positionStream;
  io.Socket? _socket;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isTracking = false;
  String? _currentRideId;
  Position? _lastPosition;

  // Configuración de tracking
  final Duration _updateInterval = const Duration(seconds: 5);
  final double _distanceFilter = 10.0; // metros

  // Stream controllers
  final _locationController = StreamController<Position>.broadcast();
  final _trackingStatusController = StreamController<bool>.broadcast();

  // Getters
  Stream<Position> get locationStream => _locationController.stream;
  Stream<bool> get trackingStatusStream => _trackingStatusController.stream;
  bool get isTracking => _isTracking;
  String? get currentRideId => _currentRideId;
  Position? get lastPosition => _lastPosition;

  /// Inicializar el servicio con socket
  void initializeSocket(String serverUrl) {
    _socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.on('connect', (_) {
      AppLogger.debug('📡 Socket conectado para tracking');
      _authenticateSocket();
    });

    _socket!.on('disconnect', (_) {
      AppLogger.debug('📡 Socket desconectado');
    });

    _socket!.on('location-error', (data) {
      AppLogger.error('Error de ubicación: $data');
    });

    _socket!.connect();
  }

  /// Autenticar socket con el servidor
  void _authenticateSocket() {
    final user = _auth.currentUser;
    if (user != null && _socket != null) {
      _socket!.emit('authenticate', {
        'userId': user.uid,
        'userType': 'driver', // Cambiar según el tipo de usuario
      });
    }
  }

  /// Solicitar permisos de ubicación (SOLO MÓVIL)
  Future<bool> requestLocationPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Abrir configuración de la app
        await openAppSettings();
        return false;
      }

      // Verificar que el servicio de ubicación esté habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Solicitar activar ubicación
        if (Platform.isAndroid) {
          serviceEnabled = await Geolocator.openLocationSettings();
        }
        return serviceEnabled;
      }

      // Para iOS, solicitar permiso de ubicación en background
      if (Platform.isIOS) {
        final backgroundStatus = await Permission.locationAlways.request();
        return backgroundStatus.isGranted;
      }

      return true;
    } catch (e) {
      AppLogger.debug('Error solicitando permisos: $e');
      return false;
    }
  }

  /// Iniciar tracking para un viaje
  Future<void> startTracking(String rideId) async {
    if (_isTracking) {
      AppLogger.warning('Ya se está haciendo tracking');
      return;
    }

    final hasPermission = await requestLocationPermissions();
    if (!hasPermission) {
      throw Exception('No se otorgaron permisos de ubicación');
    }

    _currentRideId = rideId;
    _isTracking = true;
    _trackingStatusController.add(true);

    AppLogger.debug('🎯 Iniciando tracking para viaje: $rideId');

    // Unirse a la sala del viaje
    _socket?.emit('join-ride', rideId);

    // Configurar stream de ubicación
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualizar cada 10 metros
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _handleLocationUpdate(position);
      },
      onError: (error) {
        AppLogger.error('Error en stream de ubicación: $error');
      },
    );

    // También usar timer para asegurar actualizaciones regulares
    _trackingTimer = Timer.periodic(_updateInterval, (_) async {
      if (_isTracking) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          _handleLocationUpdate(position);
        } catch (e) {
          AppLogger.debug('Error obteniendo ubicación: $e');
        }
      }
    });
  }

  /// Manejar actualización de ubicación
  void _handleLocationUpdate(Position position) {
    // Verificar si la posición ha cambiado significativamente
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Si el cambio es menor al filtro de distancia, no actualizar
      if (distance < _distanceFilter) {
        return;
      }
    }

    _lastPosition = position;
    _locationController.add(position);

    // Emitir ubicación por socket
    if (_socket != null && _currentRideId != null) {
      final locationData = {
        'rideId': _currentRideId,
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'driverId': _auth.currentUser?.uid,
      };

      _socket!.emit('update-location', locationData);

      AppLogger.debug(
          '📍 Ubicación actualizada: ${position.latitude}, ${position.longitude}');
    }

    // También actualizar en Firestore
    _updateFirestoreLocation(position);
  }

  /// Actualizar ubicación en Firestore
  Future<void> _updateFirestoreLocation(Position position) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null || _currentRideId == null) return;

      // Actualizar ubicación del viaje
      await _firestore.collection('rides').doc(_currentRideId).update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'heading': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
      });

      // Actualizar ubicación del usuario
      await _firestore.collection('users').doc(userId).update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.debug('Error actualizando ubicación en Firestore: $e');
    }
  }

  /// Detener tracking
  void stopTracking() {
    AppLogger.debug('🛑 Deteniendo tracking');

    _isTracking = false;
    _trackingStatusController.add(false);

    _trackingTimer?.cancel();
    _trackingTimer = null;

    _positionStream?.cancel();
    _positionStream = null;

    // Salir de la sala del viaje
    if (_currentRideId != null) {
      _socket?.emit('leave-ride', _currentRideId);
    }

    _currentRideId = null;
  }

  /// Obtener ubicación actual una sola vez
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermissions();
      if (!hasPermission) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _lastPosition = position;
      return position;
    } catch (e) {
      AppLogger.debug('Error obteniendo ubicación actual: $e');
      return null;
    }
  }

  /// Calcular distancia entre dos puntos
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
  }

  /// Obtener dirección desde coordenadas (geocoding inverso)
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      // Aquí podrías usar un servicio de geocoding como Google Maps
      // Por ahora retornamos las coordenadas como string
      return '$lat, $lng';
    } catch (e) {
      return 'Ubicación desconocida';
    }
  }

  /// Habilitar tracking en background (solo móvil)
  Future<void> enableBackgroundTracking() async {
    if (Platform.isAndroid) {
      // Configurar servicio en background para Android
      // Esto requiere configuración adicional en el manifest
      AppLogger.debug('Configurando tracking en background para Android');
    } else if (Platform.isIOS) {
      // Configurar background location para iOS
      // Requiere configuración en Info.plist
      AppLogger.debug('Configurando tracking en background para iOS');
    }
  }

  /// Verificar si el GPS está habilitado
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Abrir configuración de ubicación del dispositivo
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Limpiar recursos
  void dispose() {
    stopTracking();
    _locationController.close();
    _trackingStatusController.close();
    _socket?.disconnect();
    _socket?.dispose();
  }

  /// Reconectar socket si se pierde la conexión
  void reconnectSocket() {
    if (_socket != null && !_socket!.connected) {
      _socket!.connect();
    }
  }

  /// Verificar estado de la conexión del socket
  bool get isSocketConnected => _socket?.connected ?? false;

  /// Obtener estadísticas de tracking
  Map<String, dynamic> getTrackingStats() {
    return {
      'isTracking': _isTracking,
      'currentRideId': _currentRideId,
      'lastPosition': _lastPosition != null
          ? {
              'lat': _lastPosition!.latitude,
              'lng': _lastPosition!.longitude,
              'accuracy': _lastPosition!.accuracy,
              'speed': _lastPosition!.speed,
              'timestamp': _lastPosition!.timestamp,
            }
          : null,
      'socketConnected': isSocketConnected,
    };
  }
}

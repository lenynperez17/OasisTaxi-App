// ignore_for_file: deprecated_member_use, unused_field, unused_element, use_build_context_synchronously
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math' as math;

// Core

// Models
import '../../models/trip_model.dart';

// Providers
import '../../providers/auth_provider.dart';

// Services
import '../../services/firebase_service.dart';

// Utils
import '../../utils/logger.dart';

// Screens
import 'chat_screen.dart';

class TripTrackingScreen extends StatefulWidget {
  final String rideId;
  final TripModel? ride;

  const TripTrackingScreen({
    super.key,
    required this.rideId,
    this.ride,
  });

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _driverLocationTimer;
  Timer? _etaTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  TripModel? _currentRide;
  Position? _currentPosition;
  Position? _driverPosition;
  LatLng? _driverLatLng;
  
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];
  
  String _estimatedArrival = 'Calculando...';
  double _distanceToDestination = 0.0;
  double _distanceToPickup = 0.0;
  String _currentStatus = 'Buscando conductor...';
  bool _isMapLoaded = false;
  bool _showDriverInfo = true;
  
  // Colores del tema
  static const primaryColor = Color(0xFF00C800);
  static const accentColor = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadRideData();
    _startLocationTracking();
    _startDriverLocationUpdates();
    _startETAUpdates();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _positionSubscription?.cancel();
    _driverLocationTimer?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
  }

  Future<void> _loadRideData() async {
    try {
      if (!mounted) return;
      
      if (widget.ride != null) {
        if (!mounted) return;
        setState(() {
          _currentRide = widget.ride;
          _updateStatus();
        });
      } else {
        final ride = await FirebaseService().getRideById(widget.rideId);
        if (mounted) {
          setState(() {
            _currentRide = ride;
            _updateStatus();
          });
        }
      }

      if (_currentRide != null) {
        _setupMapMarkers();
        _calculateRoute();
        _listenToRideUpdates();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos del viaje: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _listenToRideUpdates() {
    FirebaseService().listenToRideUpdates(widget.rideId, (ride) {
      if (mounted) {
        setState(() {
          _currentRide = ride;
          _updateStatus();
          _setupMapMarkers();
        });
        
        // Por ahora no hay ubicación del conductor en TripModel
        // Se actualizará dinámicamente desde Firebase
      }
    });
  }

  void _updateStatus() {
    if (_currentRide == null) return;
    
    switch (_currentRide!.status) {
      case 'searching':
        _currentStatus = 'Buscando conductor...';
        break;
      case 'accepted':
        _currentStatus = 'Conductor asignado - En camino';
        break;
      case 'arrived':
        _currentStatus = 'Conductor ha llegado';
        break;
      case 'in_progress':
        _currentStatus = 'Viaje en curso';
        break;
      case 'completed':
        _currentStatus = 'Viaje completado';
        break;
      case 'cancelled':
        _currentStatus = 'Viaje cancelado';
        break;
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          _calculateDistances();
        }
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error al obtener ubicación', e, stackTrace);
    }
  }

  void _startDriverLocationUpdates() {
    _driverLocationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        _updateDriverLocation();
      },
    );
  }

  void _startETAUpdates() {
    _etaTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        _calculateETA();
      },
    );
  }

  Future<void> _updateDriverLocation() async {
    if (_currentRide?.driverId == null) return;

    try {
      final driverLocation = await FirebaseService()
          .getDriverLocation(_currentRide!.driverId);
      
      if (driverLocation != null && mounted) {
        _updateDriverPosition(driverLocation);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al actualizar ubicación del conductor', e, stackTrace);
    }
  }

  void _updateDriverPosition(LatLng position) {
    setState(() {
      _driverLatLng = position;
      _driverPosition = Position(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    });
    _setupMapMarkers();
    _calculateDistances();
    _calculateRoute();
  }

  void _calculateDistances() {
    if (_currentPosition == null) return;

    if (_currentRide != null) {
      // Distancia al destino
      _distanceToDestination = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _currentRide!.destinationLocation.latitude,
        _currentRide!.destinationLocation.longitude,
      ) / 1000;

      // Distancia al pickup (si el viaje no ha empezado)
      if (_currentRide!.status == 'accepted' ||
          _currentRide!.status == 'arrived') {
        _distanceToPickup = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          _currentRide!.pickupLocation.latitude,
          _currentRide!.pickupLocation.longitude,
        ) / 1000;
      }
    }
  }

  Future<void> _calculateETA() async {
    if (_driverLatLng == null || _currentRide == null) return;

    try {
      // Simulación de cálculo de ETA (en producción usar Google Directions API)
      double distance;
      
      if (_currentRide!.status == 'accepted' ||
          _currentRide!.status == 'arrived') {
        // Distancia del conductor al pickup
        distance = Geolocator.distanceBetween(
          _driverLatLng!.latitude,
          _driverLatLng!.longitude,
          _currentRide!.pickupLocation.latitude,
          _currentRide!.pickupLocation.longitude,
        ) / 1000;
      } else {
        // Distancia del conductor/usuario al destino
        distance = _distanceToDestination;
      }

      // Velocidad promedio estimada (30 km/h en ciudad)
      const averageSpeed = 30.0;
      final etaMinutes = (distance / averageSpeed * 60).round();
      
      if (mounted) {
        setState(() {
          _estimatedArrival = etaMinutes > 0 
              ? '$etaMinutes min' 
              : 'Muy pronto';
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al calcular ETA', e, stackTrace);
    }
  }

  void _setupMapMarkers() {
    if (_currentRide == null) return;

    _markers.clear();

    // Marcador de origen
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(
        _currentRide!.pickupLocation.latitude,
        _currentRide!.pickupLocation.longitude,
      ),
      infoWindow: InfoWindow(
        title: 'Origen',
        snippet: _currentRide!.pickupAddress,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ));

    // Marcador de destino
    _markers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: LatLng(
        _currentRide!.destinationLocation.latitude,
        _currentRide!.destinationLocation.longitude,
      ),
      infoWindow: InfoWindow(
        title: 'Destino',
        snippet: _currentRide!.destinationAddress,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));

    // Marcador del conductor (si está disponible)
    if (_driverLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverLatLng!,
        infoWindow: InfoWindow(
          title: 'Conductor',
          snippet: _currentRide!.vehicleInfo?['driverName'] ?? 'Conductor asignado',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    // Marcador de posición actual
    if (_currentPosition != null) {
      _markers.add(Marker(
        markerId: const MarkerId('current'),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        infoWindow: const InfoWindow(
          title: 'Mi ubicación',
          snippet: 'Tu ubicación actual',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    setState(() {});
  }

  Future<void> _calculateRoute() async {
    if (_currentRide == null) return;

    _polylines.clear();

    // En una implementación real, usar Google Directions API
    // Por ahora, dibujamos línea directa
    List<LatLng> points = [];
    
    if (_driverLatLng != null && (_currentRide!.status == 'accepted' || 
        _currentRide!.status == 'arrived')) {
      // Ruta del conductor al pickup
      points = [
        _driverLatLng!,
        _currentRide!.pickupLocation,
      ];
    } else if (_currentRide!.status == 'in_progress') {
      // Ruta del pickup al destino
      points = [
        _currentRide!.pickupLocation,
        _currentRide!.destinationLocation,
      ];
    }

    if (points.isNotEmpty) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: primaryColor,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
      
      setState(() {
        _routePoints = points;
      });
    }
  }

  Future<void> _centerMapOnRoute() async {
    if (_mapController == null || _routePoints.isEmpty) return;

    LatLngBounds bounds;
    if (_routePoints.length == 1) {
      bounds = LatLngBounds(
        southwest: _routePoints.first,
        northeast: _routePoints.first,
      );
    } else {
      double minLat = _routePoints.first.latitude;
      double maxLat = _routePoints.first.latitude;
      double minLng = _routePoints.first.longitude;
      double maxLng = _routePoints.first.longitude;

      for (LatLng point in _routePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Future<void> _callDriver() async {
    if (_currentRide?.vehicleInfo?['driverPhone'] == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Número de conductor no disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: _currentRide!.vehicleInfo?['driverPhone'] ?? '');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _openChat() async {
    if (_currentRide?.driverId == null) return;

    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            rideId: widget.rideId,
            otherUserName: _currentRide!.vehicleInfo?['driverName'] ?? 'Conductor',
            otherUserRole: 'driver',
            otherUserId: _currentRide!.driverId,
          ),
        ),
      );
    }
  }

  Future<void> _showEmergencyDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Emergencia', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: const Text(
            '¿Necesitas ayuda de emergencia? Esto notificará a nuestro equipo de soporte inmediatamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _activateEmergency();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Activar Emergencia'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _activateEmergency() async {
    try {
      // Llamar a servicios de emergencia
      final Uri emergencyUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(emergencyUri)) {
        await launchUrl(emergencyUri);
      }

      // Notificar al sistema
      await FirebaseService().reportEmergency(
        widget.rideId,
        _currentPosition,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergencia activada. Ayuda en camino.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al activar emergencia: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelRide() async {
    if (_currentRide?.status == 'in_progress') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes cancelar un viaje en curso'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Viaje'),
        content: const Text('¿Estás seguro de que deseas cancelar este viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseService().cancelRide(widget.rideId);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDriverInfo() {
    if (_currentRide?.driverId == null) return Container();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  backgroundImage: _currentRide?.vehicleInfo?['driverPhoto'] != null
                      ? NetworkImage(_currentRide!.vehicleInfo?['driverPhoto'])
                      : null,
                  child: _currentRide?.vehicleInfo?['driverPhoto'] == null
                      ? Icon(Icons.person, size: 30, color: primaryColor)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentRide?.vehicleInfo?['driverName'] ?? 'Conductor',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _currentRide?.vehicleInfo?['driverRating']?.toStringAsFixed(1) ?? '5.0',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (_currentRide?.vehicleInfo?['plate'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_currentRide?.vehicleInfo?['model']} - ${_currentRide?.vehicleInfo?['plate']}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _callDriver,
                      icon: const Icon(Icons.phone),
                      style: IconButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _openChat,
                      icon: const Icon(Icons.chat),
                      style: IconButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ETA: $_estimatedArrival',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _distanceToDestination > 0 
                      ? '${_distanceToDestination.toStringAsFixed(1)} km'
                      : '...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_currentRide?.status == 'accepted' ||
              _currentRide?.status == 'arrived') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.my_location, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Distancia al punto de recogida: ${_distanceToPickup.toStringAsFixed(1)} km',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              setState(() {
                _isMapLoaded = true;
              });
              
              // Centrar mapa en la ruta después de un delay
              Future.delayed(const Duration(seconds: 1), () {
                _centerMapOnRoute();
              });
            },
            initialCameraPosition: CameraPosition(
              target: _currentRide != null
                  ? LatLng(
                      _currentRide!.pickupLocation.latitude,
                      _currentRide!.pickupLocation.longitude,
                    )
                  : const LatLng(-12.0464, -77.0428), // Lima por defecto
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            trafficEnabled: true,
            buildingsEnabled: true,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentRide?.status != 'completed' &&
              _currentRide?.status != 'cancelled') ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cancelRide,
                icon: const Icon(Icons.cancel),
                label: const Text('Cancelar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showEmergencyDialog,
              icon: const Icon(Icons.warning),
              label: const Text('Emergencia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: _centerMapOnRoute,
            backgroundColor: primaryColor,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Seguimiento de Viaje',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_showDriverInfo)
            IconButton(
              onPressed: () {
                setState(() {
                  _showDriverInfo = !_showDriverInfo;
                });
              },
              icon: Icon(_showDriverInfo ? Icons.visibility_off : Icons.visibility),
            ),
        ],
      ),
      body: _currentRide == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando información del viaje...'),
                ],
              ),
            )
          : Column(
              children: [
                _buildStatusCard(),
                if (_showDriverInfo && _currentRide?.driverId != null)
                  _buildDriverInfo(),
                _buildMap(),
                _buildActionButtons(),
              ],
            ),
    );
  }
}
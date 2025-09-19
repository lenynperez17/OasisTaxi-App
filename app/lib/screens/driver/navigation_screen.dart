import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';
import '../../utils/app_logger.dart';
import '../../services/google_maps_service.dart';
import '../../services/tracking_service.dart';
import '../../services/geofencing_service.dart';
import '../../core/config/environment_config.dart';

class NavigationScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;

  NavigationScreen({super.key, this.tripData});

  @override
  NavigationScreenState createState() => NavigationScreenState();
}

class NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Service instances
  final GoogleMapsService _mapsService = GoogleMapsService();
  final TrackingService _trackingService = TrackingService();
  final GeofencingService _geofencingService = GeofencingService();

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  // Navigation state
  bool _isNavigating = false;
  final bool _showInstructions = true;
  String _currentInstruction = 'Calculando ruta...';
  String _nextInstruction = '';
  double _distanceToNext = 0;
  int _estimatedTime = 0;
  double _totalDistance = 0;
  int _totalTime = 0;

  // Current location simulation
  LatLng _currentLocation = LatLng(-12.0851, -76.9770);
  final LatLng _destination = LatLng(-12.0951, -76.9870);
  Timer? _locationTimer;
  Timer? _trafficTimer;

  // Route instructions
  List<RouteInstruction> _instructions = [];
  int _currentInstructionIndex = 0;

  // Tracking session
  String? _activeRideId;
  StreamSubscription<TrackingUpdate>? _trackingSubscription;
  bool _useRealTracking = false; // Toggle for real vs simulated

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('NavigationScreen', 'initState');

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );

    _slideController.forward();
    _initializeRoute();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _locationTimer?.cancel();
    _trafficTimer?.cancel();
    _trackingSubscription?.cancel();
    _stopTracking();
    _mapController?.dispose();
    super.dispose();
  }

  void _initializeRoute() async {
    try {
      AppLogger.info('Inicializando ruta con Google Maps API');

      // Initialize Google Maps service
      await _mapsService.initialize(googleMapsApiKey: EnvironmentConfig.googleMapsApiKey);

      // Get real directions from Google Maps
      final directionsResult = await _mapsService.getDirections(
        origin: _currentLocation,
        destination: _destination,
        travelMode: TravelMode.driving,
        avoidTolls: false,
        avoidHighways: false,
      );

      if (directionsResult.success) {
        setState(() {
          // Convert real directions to route instructions
          _instructions = directionsResult.steps?.map((step) => RouteInstruction(
            instruction: step.instruction,
            distance: step.distanceValue.toDouble(),
            duration: step.durationValue,
            turnIcon: _getIconForInstruction(step.instruction),
            position: step.startLocation,
          )).toList() ?? [];

          _totalDistance = directionsResult.distanceValue?.toDouble() ?? 0.0;
          _totalTime = directionsResult.durationValue ?? 0;

          // Update polyline with real route
          _polylines.clear();
          if (directionsResult.polylinePoints != null) {
            _polylines.add(
              Polyline(
                polylineId: PolylineId('route'),
                points: directionsResult.polylinePoints!,
                color: ModernTheme.primaryBlue,
                width: 5,
                patterns: [],
              ),
            );
          }

          // Add markers for origin and destination if missing
          if (!_markers.any((m) => m.markerId.value == 'origin')) {
            _markers.add(
              Marker(
                markerId: MarkerId('origin'),
                position: _currentLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                infoWindow: InfoWindow(title: 'Inicio'),
              ),
            );
          }

          if (!_markers.any((m) => m.markerId.value == 'destination')) {
            _markers.add(
              Marker(
                markerId: MarkerId('destination'),
                position: _destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(title: 'Destino'),
              ),
            );
          }
        });

        AppLogger.info('Ruta real cargada: ${(_totalDistance/1000).toStringAsFixed(1)} km, ${(_totalTime/60).round()} min');

        _updateCurrentInstruction();
      } else {
        AppLogger.error('Error obteniendo direcciones: ${directionsResult.error}');
        _initializeFallbackRoute();
      }
    } catch (e) {
      AppLogger.error('Error inicializando ruta real', e);
      _initializeFallbackRoute();
    }
  }

  /// Fallback route with mock data if Google Maps fails
  void _initializeFallbackRoute() {
    AppLogger.warning('Usando ruta de respaldo con datos simulados');

    _instructions = [
      RouteInstruction(
        instruction: 'Dirígete hacia el norte por Av. Principal',
        distance: 250,
        duration: 60,
        turnIcon: Icons.arrow_upward,
        position: LatLng(-12.0851, -76.9770),
      ),
      RouteInstruction(
        instruction: 'Gira a la derecha en Calle 2',
        distance: 500,
        duration: 120,
        turnIcon: Icons.turn_right,
        position: LatLng(-12.0861, -76.9780),
      ),
      RouteInstruction(
        instruction: 'Continúa recto por 800 metros',
        distance: 800,
        duration: 180,
        turnIcon: Icons.straight,
        position: LatLng(-12.0881, -76.9800),
      ),
      RouteInstruction(
        instruction: 'Gira a la izquierda en Av. Secundaria',
        distance: 400,
        duration: 90,
        turnIcon: Icons.turn_left,
        position: LatLng(-12.0901, -76.9820),
      ),
      RouteInstruction(
        instruction: 'En la rotonda, toma la segunda salida',
        distance: 200,
        duration: 45,
        turnIcon: Icons.rotate_right,
        position: LatLng(-12.0921, -76.9840),
      ),
      RouteInstruction(
        instruction: 'Tu destino está a la derecha',
        distance: 50,
        duration: 15,
        turnIcon: Icons.location_on,
        position: LatLng(-12.0941, -76.9860),
      ),
    ];

    _totalDistance = _instructions.fold(0, (sum, inst) => sum + inst.distance);
    _totalTime = _instructions.fold(0, (sum, inst) => sum + inst.duration);

    _updateCurrentInstruction();
    _drawRoute(useFallback: true);
  }

  /// Get appropriate icon for navigation instruction
  IconData _getIconForInstruction(String instruction) {
    final lowerInstruction = instruction.toLowerCase();

    if (lowerInstruction.contains('derecha') || lowerInstruction.contains('right')) {
      return Icons.turn_right;
    } else if (lowerInstruction.contains('izquierda') || lowerInstruction.contains('left')) {
      return Icons.turn_left;
    } else if (lowerInstruction.contains('recto') || lowerInstruction.contains('straight')) {
      return Icons.straight;
    } else if (lowerInstruction.contains('rotonda') || lowerInstruction.contains('roundabout')) {
      return Icons.rotate_right;
    } else if (lowerInstruction.contains('destino') || lowerInstruction.contains('destination')) {
      return Icons.location_on;
    } else {
      return Icons.arrow_upward;
    }
  }

  void _updateCurrentInstruction() {
    if (_currentInstructionIndex < _instructions.length) {
      final current = _instructions[_currentInstructionIndex];
      _currentInstruction = current.instruction;
      _distanceToNext = current.distance.toDouble();
      _estimatedTime = current.duration;

      if (_currentInstructionIndex + 1 < _instructions.length) {
        _nextInstruction =
            _instructions[_currentInstructionIndex + 1].instruction;
      } else {
        _nextInstruction = 'Llegando al destino';
      }
    }
  }

  void _drawRoute({bool useFallback = false}) {
    if (useFallback) {
      // Create fallback route polyline
      List<LatLng> routePoints =
          _instructions.map((inst) => inst.position).toList();
      routePoints.add(_destination);

      _polylines.add(
        Polyline(
          polylineId: PolylineId('route_fallback'),
          points: routePoints,
          color: ModernTheme.primaryBlue,
          width: 5,
          patterns: [],
        ),
      );
    }

    // Add markers only if they don't exist
    if (!_markers.any((m) => m.markerId.value == 'origin')) {
      _markers.add(
        Marker(
          markerId: MarkerId('origin'),
          position: _currentLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Inicio'),
        ),
      );
    }

    if (!_markers.any((m) => m.markerId.value == 'destination')) {
      _markers.add(
        Marker(
          markerId: MarkerId('destination'),
          position: _destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destino'),
        ),
      );
    }

    setState(() {});
  }

  void _startNavigation() async {
    setState(() {
      _isNavigating = true;
    });

    // Check if we should use real tracking
    if (widget.tripData != null && widget.tripData!['rideId'] != null) {
      _activeRideId = widget.tripData!['rideId'];
      _useRealTracking = true;
      await _startRealTracking();
    } else {
      // Fallback to simulation if no ride ID
      _startSimulatedTracking();
    }

    // Start traffic monitoring
    _startTrafficMonitoring();
  }

  /// Start real tracking using TrackingService
  Future<void> _startRealTracking() async {
    if (_activeRideId == null) return;

    try {
      // Initialize tracking service if needed
      if (!_trackingService.isInitialized) {
        await _trackingService.initialize(isProduction: EnvironmentConfig.isProduction);
      }

      // Start tracking session
      final result = await _trackingService.startTracking(
        rideId: _activeRideId!,
        driverId: widget.tripData?['driverId'] ?? 'driver_id',
        passengerId: widget.tripData?['passengerId'] ?? 'passenger_id',
        origin: _currentLocation,
        destination: _destination,
      );

      if (result.success) {
        // Subscribe to tracking updates
        _trackingSubscription = _trackingService.getTrackingUpdates(_activeRideId!).listen(
          _handleTrackingUpdate,
          onError: (error) => AppLogger.error('Error en tracking stream', error),
        );

        AppLogger.info('Tracking real iniciado para viaje $_activeRideId');
      } else {
        AppLogger.error('No se pudo iniciar tracking: ${result.error}');
        // Fallback to simulation
        _startSimulatedTracking();
      }
    } catch (e) {
      AppLogger.error('Error iniciando tracking real', e);
      _startSimulatedTracking();
    }
  }

  /// Handle real tracking updates
  void _handleTrackingUpdate(TrackingUpdate update) {
    if (!mounted) return;

    setState(() {
      // Update current location from tracking
      if (update.currentLocation != null) {
        _currentLocation = update.currentLocation!;

        // Update driver marker
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(
          Marker(
            markerId: MarkerId('driver'),
            position: _currentLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(title: 'Tu ubicación'),
          ),
        );

        // Update camera position
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLocation),
        );
      }

      // Update ETA if available
      if (update.estimatedArrival != null) {
        final now = DateTime.now();
        final difference = update.estimatedArrival!.difference(now);
        _estimatedTime = difference.inSeconds;
      }

      // Update current instruction based on location
      _updateCurrentInstruction();
    });
  }

  /// Start simulated tracking (fallback)
  void _startSimulatedTracking() {
    _useRealTracking = false;
    _locationTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _simulateMovement();
    });
    AppLogger.info('Usando tracking simulado');
  }

  /// Stop tracking session
  Future<void> _stopTracking() async {
    if (_activeRideId != null && _useRealTracking) {
      await _trackingService.stopTracking(_activeRideId!);
      _trackingSubscription?.cancel();
      AppLogger.info('Tracking detenido para viaje $_activeRideId');
    }
  }

  /// Start real-time traffic monitoring
  void _startTrafficMonitoring() {
    if (!EnvironmentConfig.realTimeTraffic) return;

    _trafficTimer = Timer.periodic(Duration(minutes: 2), (timer) async {
      try {
        final trafficInfo = await _mapsService.getTrafficInfo(
          origin: _currentLocation,
          destination: _destination,
        );

        if (trafficInfo.delayMinutes > 5) {
          _showTrafficAlert(trafficInfo);
        }
      } catch (e) {
        AppLogger.error('Error obteniendo información de tráfico', e);
      }
    });
  }

  /// Show traffic alert to user
  void _showTrafficAlert(TrafficInfo trafficInfo) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.traffic, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tráfico detectado: +${trafficInfo.delayMinutes} min de retraso',
              ),
            ),
          ],
        ),
        backgroundColor: _getTrafficColor(trafficInfo.trafficLevel),
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Ruta alternativa',
          textColor: Colors.white,
          onPressed: () => _suggestAlternativeRoute(),
        ),
      ),
    );
  }

  /// Get color based on traffic level
  Color _getTrafficColor(TrafficLevel level) {
    switch (level) {
      case TrafficLevel.light:
        return Colors.green;
      case TrafficLevel.moderate:
        return Colors.orange;
      case TrafficLevel.heavy:
        return Colors.red;
      case TrafficLevel.severe:
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  /// Suggest alternative route
  void _suggestAlternativeRoute() async {
    try {
      final alternatives = await _mapsService.getAlternativeRoutes(
        origin: _currentLocation,
        destination: _destination,
        maxAlternatives: 3,
      );

      if (alternatives.isNotEmpty) {
        _showAlternativeRoutesDialog(alternatives);
      }
    } catch (e) {
      AppLogger.error('Error obteniendo rutas alternativas', e);
    }
  }

  /// Show alternative routes dialog
  void _showAlternativeRoutesDialog(List<DirectionsResult> alternatives) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rutas Alternativas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: alternatives.asMap().entries.map((entry) {
            final index = entry.key;
            final route = entry.value;
            return ListTile(
              leading: CircleAvatar(
                child: Text('${index + 1}'),
                backgroundColor: ModernTheme.oasisGreen,
              ),
              title: Text('${route.distance} - ${route.duration}'),
              subtitle: Text('Ruta ${index + 1}'),
              onTap: () {
                Navigator.pop(context);
                _switchToAlternativeRoute(route);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Switch to selected alternative route
  void _switchToAlternativeRoute(DirectionsResult route) {
    setState(() {
      _polylines.clear();
      if (route.polylinePoints != null) {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('alternative_route'),
            points: route.polylinePoints!,
            color: Colors.blue,
            width: 5,
          ),
        );
      }

      _totalDistance = route.distanceValue?.toDouble() ?? 0.0;
      _totalTime = route.durationValue ?? 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ruta alternativa seleccionada'),
        backgroundColor: ModernTheme.oasisGreen,
      ),
    );
  }

  void _simulateMovement() {
    if (_currentInstructionIndex < _instructions.length - 1) {
      setState(() {
        _distanceToNext -= 50; // Reduce 50 meters
        _estimatedTime = math.max(0, _estimatedTime - 2);

        if (_distanceToNext <= 50) {
          _currentInstructionIndex++;
          _updateCurrentInstruction();

          // Voice instruction simulation
          _showVoiceNotification();
        }

        // Update current location marker
        _currentLocation = _instructions[_currentInstructionIndex].position;
        _updateLocationMarker();
      });
    } else {
      _arriveAtDestination();
    }
  }

  void _updateLocationMarker() {
    _markers.removeWhere((marker) => marker.markerId.value == 'current');
    _markers.add(
      Marker(
        markerId: MarkerId('current'),
        position: _currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        anchor: Offset(0.5, 0.5),
      ),
    );
  }

  void _showVoiceNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.volume_up, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(_currentInstruction)),
          ],
        ),
        backgroundColor: ModernTheme.primaryBlue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _arriveAtDestination() {
    _locationTimer?.cancel();
    setState(() {
      _isNavigating = false;
      _currentInstruction = '¡Has llegado a tu destino!';
    });

    _showArrivalDialog();
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: ModernTheme.success, size: 32),
            const SizedBox(width: 12),
            Text('¡Llegaste!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Has llegado a tu destino exitosamente.'),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.route, size: 20, color: ModernTheme.textSecondary),
                const SizedBox(width: 8),
                Text('${(_totalDistance / 1000).toStringAsFixed(1)} km'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer, size: 20, color: ModernTheme.textSecondary),
                const SizedBox(width: 8),
                Text('${(_totalTime / 60).round()} min'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 16,
              tilt: 45,
              bearing: 90,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _applyMapStyle();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            buildingsEnabled: true,
            trafficEnabled: EnvironmentConfig.realTimeTraffic,
            mapType: MapType.normal,
          ),

          // Top navigation bar
          SafeArea(
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -100 * (1 - _slideAnimation.value)),
                  child: _buildNavigationBar(),
                );
              },
            ),
          ),

          // Bottom instruction panel
          if (_showInstructions)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 200 * (1 - _slideAnimation.value)),
                    child: _buildInstructionPanel(),
                  );
                },
              ),
            ),

          // Floating action buttons
          Positioned(
            right: 16,
            bottom: _showInstructions ? 280 : 100,
            child: Column(
              children: [
                _buildFloatingButton(
                  Icons.my_location,
                  () => _recenterMap(),
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  Icons.layers,
                  () => _toggleMapType(),
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  Icons.volume_up,
                  () => _toggleVoice(),
                ),
              ],
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: ModernTheme.cardShadow,
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: ModernTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernTheme.oasisGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ModernTheme.floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current instruction
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _currentInstructionIndex < _instructions.length
                      ? _instructions[_currentInstructionIndex].turnIcon
                      : Icons.location_on,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentInstruction,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${_distanceToNext.round()} m',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '$_estimatedTime seg',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Progress bar
          Container(
            margin: EdgeInsets.only(top: 12),
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: (_currentInstructionIndex + 1) / _instructions.length,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: ModernTheme.floatingShadow,
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Trip info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem(
                Icons.route,
                '${(_totalDistance / 1000).toStringAsFixed(1)} km',
                'Distancia total',
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade300,
              ),
              _buildInfoItem(
                Icons.timer,
                '${(_totalTime / 60).round()} min',
                'Tiempo estimado',
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade300,
              ),
              _buildInfoItem(
                Icons.speed,
                '45 km/h',
                'Velocidad',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Next instruction preview
          if (_nextInstruction.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right,
                      color: ModernTheme.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Luego:',
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _nextInstruction,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isNavigating ? null : _startNavigation,
                  icon: Icon(_isNavigating ? Icons.pause : Icons.play_arrow),
                  label: Text(_isNavigating ? 'Navegando...' : 'Iniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.oasisGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _cancelNavigation,
                icon: Icon(Icons.close),
                label: Text('Cancelar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.error,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: ModernTheme.oasisGreen, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: ModernTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: ModernTheme.cardShadow,
      ),
      child: IconButton(
        icon: Icon(icon, color: ModernTheme.oasisGreen),
        onPressed: onPressed,
      ),
    );
  }

  void _recenterMap() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: 16,
          tilt: 45,
          bearing: 90,
        ),
      ),
    );
  }

  void _toggleMapType() {
    // Toggle between normal and satellite view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cambiar tipo de mapa'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _toggleVoice() {
    // Toggle voice instructions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Instrucciones de voz activadas'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _cancelNavigation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancelar navegación'),
        content: Text('¿Estás seguro de que deseas cancelar la navegación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: ModernTheme.error,
            ),
            child: Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  void _applyMapStyle() async {
    try {
      final String style = await rootBundle.loadString('assets/map_style.json');
      await _mapController?.setMapStyle(style);
      AppLogger.info('Estilo de mapa personalizado aplicado exitosamente');
    } catch (e) {
      AppLogger.error('Error aplicando estilo de mapa', e, StackTrace.current);
    }
  }
}

class RouteInstruction {
  final String instruction;
  final double distance;
  final int duration;
  final IconData turnIcon;
  final LatLng position;

  RouteInstruction({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.turnIcon,
    required this.position,
  });
}

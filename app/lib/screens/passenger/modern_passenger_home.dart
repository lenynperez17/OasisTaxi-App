import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

// Core
import '../../core/theme/modern_theme.dart';
import '../../core/services/places_service.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/oasis_button.dart';

// Common Widgets
import '../../widgets/common/oasis_app_bar.dart';
import '../../widgets/cards/oasis_card.dart';

// Services
import '../../services/google_maps_service.dart';

// Models
import '../../models/service_type_model.dart';

// Providers
import '../../providers/location_provider.dart';

// Widgets
import '../../widgets/address_search_widget.dart';
import '../../widgets/transport_options_widget.dart';
import '../../widgets/passenger_drawer.dart';

// Utils
import '../../utils/app_logger.dart';

class ModernPassengerHomeScreen extends StatefulWidget {
  const ModernPassengerHomeScreen({super.key});

  @override
  ModernPassengerHomeScreenState createState() =>
      ModernPassengerHomeScreenState();
}

class ModernPassengerHomeScreenState extends State<ModernPassengerHomeScreen>
    with TickerProviderStateMixin {
  // GlobalKey para el Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controllers
  GoogleMapController? _mapController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;

  // Estado de ubicación
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  String _currentAddress = 'Obteniendo ubicación...';
  final TextEditingController _originController = TextEditingController();
  String _destinationAddress = '';

  // Estado del viaje
  ServiceType _selectedService = ServiceType.taxiEconomico;
  double? _estimatedDistance;
  int? _estimatedTime;
  double? _estimatedPrice;
  bool _isRequestingRide = false;
  bool _showServiceOptions = false;
  bool _destinationSelected = false;

  // Marcadores y rutas
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Maps Service
  final GoogleMapsService _googleMapsService = GoogleMapsService();

  // Subscriptions
  StreamSubscription? _locationSubscription;
  StreamSubscription? _driversSubscription;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernPassengerHomeScreen', 'initState');
    _initializeAnimations();
    _initializeServices();
    // Postergar inicialización de ubicación para evitar setState durante build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
    _subscribeToDrivers();
  }

  Future<void> _initializeServices() async {
    try {
      await _googleMapsService.initialize(
        googleMapsApiKey: AppConfig.googleDirectionsApiKey,
      );
      AppLogger.info('🗺️ GoogleMapsService inicializado correctamente');
    } catch (e) {
      AppLogger.error('Error inicializando GoogleMapsService', e);
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;

    try {
      // Diferir la llamada al Provider para evitar setState durante build
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);

      // Intentar obtener ubicación con timeout
      await Future.any([
        locationProvider.getCurrentLocation(),
        Future.delayed(const Duration(seconds: 10)),
      ]);

      // Verificar que el widget aún esté montado antes de setState
      if (!mounted) return;

      // Obtener ubicación inicial - sin stream porque LocationProvider no lo tiene
      if (locationProvider.currentLocation != null) {
        setState(() {
          _currentLocation = locationProvider.currentLocation;
          _updateCurrentAddress();
          _updateMapCamera();
        });
      } else {
        // Si no se pudo obtener la ubicación, usar ubicación por defecto (Lima)
        setState(() {
          _currentLocation = const LatLng(-12.0464, -77.0428);
          _currentAddress = 'Plaza de Armas, Lima';
          _updateMapCamera();
        });

        // Intentar obtener ubicación real en segundo plano
        _retryLocationInBackground();
      }
    } catch (e) {
      if (mounted) {
        AppLogger.error('Error inicializando ubicación', e);
        // Usar ubicación por defecto si hay error
        setState(() {
          _currentLocation = const LatLng(-12.0464, -77.0428);
          _currentAddress = 'Plaza de Armas, Lima';
          _updateMapCamera();
        });
      }
    }
  }

  Future<void> _retryLocationInBackground() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.getCurrentLocation();

    if (mounted && locationProvider.currentLocation != null) {
      setState(() {
        _currentLocation = locationProvider.currentLocation;
        _updateCurrentAddress();
        _updateMapCamera();
      });
    }
  }

  Future<void> _updateCurrentAddress() async {
    if (_currentLocation == null) return;

    try {
      final address = await PlacesService.getAddressFromCoordinates(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      if (mounted && address != null) {
        setState(() {
          _currentAddress = address;
        });
      }
    } catch (e) {
      AppLogger.error('Error obteniendo dirección actual', e);
    }
  }

  void _updateMapCamera() {
    if (_mapController != null && _currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _subscribeToDrivers() {
    _driversSubscription = _firestore
        .collection('drivers')
        .where('isOnline', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _updateDriverMarkers(snapshot.docs);
    });
  }

  void _updateDriverMarkers(List<QueryDocumentSnapshot> drivers) {
    if (!mounted) return;

    setState(() {
      _markers
          .removeWhere((marker) => marker.markerId.value.startsWith('driver_'));

      for (var doc in drivers) {
        final data = doc.data() as Map<String, dynamic>;
        final location = data['location'] as GeoPoint?;
        final serviceType = data['serviceType'] as String?;

        if (location != null) {
          final service = _getServiceFromString(serviceType);
          final serviceInfo = ServiceTypeConfig.getServiceInfo(service);

          _markers.add(
            Marker(
              markerId: MarkerId('driver_${doc.id}'),
              position: LatLng(location.latitude, location.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerHue(serviceInfo.color),
              ),
              infoWindow: InfoWindow(
                title: serviceInfo.name,
                snippet: data['driverName'] ?? 'Conductor disponible',
              ),
            ),
          );
        }
      }
    });
  }

  ServiceType _getServiceFromString(String? type) {
    if (type == null) return ServiceType.taxiEconomico;

    try {
      return ServiceType.values.firstWhere(
        (e) => e.toString().split('.').last == type,
        orElse: () => ServiceType.taxiEconomico,
      );
    } catch (e) {
      return ServiceType.taxiEconomico;
    }
  }

  double _getMarkerHue(Color color) {
    if (color == Color(0xFF2196F3)) return BitmapDescriptor.hueBlue;
    if (color == Color(0xFF4CAF50)) return BitmapDescriptor.hueGreen;
    if (color == Color(0xFFFF9800)) return BitmapDescriptor.hueOrange;
    if (color == Color(0xFFF44336)) return BitmapDescriptor.hueRed;
    if (color == Color(0xFFFFD700)) return BitmapDescriptor.hueYellow;
    return BitmapDescriptor.hueAzure;
  }

  void _onDestinationSelected(PlaceDetails place) {
    setState(() {
      _destinationLocation = LatLng(place.latitude, place.longitude);
      _destinationAddress = place.formattedAddress;
      _destinationSelected = true;
      _showServiceOptions = true;
    });

    _calculateRoute();
    _slideController.forward();
  }

  void _onOriginSelected(PlaceDetails place) {
    setState(() {
      _currentLocation = LatLng(place.latitude, place.longitude);
      _currentAddress = place.formattedAddress;
    });

    // Actualizar el provider de ubicación
    if (mounted) {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      locationProvider.updateLocation(LatLng(place.latitude, place.longitude));
    }

    // Si ya había destino seleccionado, recalcular ruta
    if (_destinationLocation != null) {
      _calculateRoute();
    }

    // Actualizar cámara del mapa para mostrar la nueva ubicación
    _updateMapCamera();
  }

  Future<void> _getCurrentGPSLocation() async {
    try {
      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Obteniendo tu ubicación GPS...'),
              ],
            ),
            duration: Duration(seconds: 10),
            backgroundColor: ModernTheme.primaryBlue,
          ),
        );
      }

      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);

      // Obtener ubicación GPS actual con timeout
      await Future.any([
        locationProvider.getCurrentLocation(),
        Future.delayed(const Duration(seconds: 15)),
      ]);

      if (!mounted) return;

      if (locationProvider.currentLocation != null) {
        // Obtener la dirección de la ubicación GPS
        await locationProvider.getCurrentLocation();

        setState(() {
          _currentLocation = locationProvider.currentLocation;
          _currentAddress =
              locationProvider.currentAddress ?? 'Ubicación GPS obtenida';
          // Actualizar el controlador del campo de texto
          _originController.text = _currentAddress;
        });

        // Si ya había destino seleccionado, recalcular ruta
        if (_destinationLocation != null) {
          _calculateRoute();
        }

        // Actualizar cámara del mapa
        _updateMapCamera();

        // Verificar si el widget aún está montado antes de usar context
        if (!mounted) return;

        // Ocultar snackbar de loading
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Mostrar confirmación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Ubicación GPS obtenida exitosamente'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: ModernTheme.success,
          ),
        );

        AppLogger.info('📍 Ubicación GPS obtenida: $_currentAddress');
      } else {
        // Error obteniendo ubicación
        _showLocationError(
            'No se pudo obtener tu ubicación GPS. Verifica que el GPS esté activado y los permisos estén concedidos.');
      }
    } catch (e) {
      AppLogger.error('Error obteniendo ubicación GPS', e);
      if (mounted) {
        _showLocationError('Error al obtener ubicación GPS: ${e.toString()}');
      }
    }
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        duration: Duration(seconds: 4),
        backgroundColor: ModernTheme.error,
      ),
    );
  }

  Future<void> _calculateRoute() async {
    if (_currentLocation == null || _destinationLocation == null) return;

    try {
      AppLogger.info('🗺️ Calculando ruta real con Google Directions API...');

      // Usar Google Directions API REAL
      final directionsResult = await _googleMapsService.getDirections(
        origin: _currentLocation!,
        destination: _destinationLocation!,
        travelMode: TravelMode.driving,
        avoidTolls: false,
        avoidHighways: false,
      );

      if (directionsResult.success && directionsResult.polylinePoints != null) {
        // Convertir metros a kilómetros para la distancia
        final distanceKm = (directionsResult.distanceValue! / 1000);
        // Convertir segundos a minutos para el tiempo
        final timeMinutes = (directionsResult.durationValue! / 60).round();

        setState(() {
          _estimatedDistance = distanceKm;
          _estimatedTime = timeMinutes;
          _estimatedPrice = ServiceTypeConfig.calculatePrice(
            _selectedService,
            distanceKm,
            timeMinutes,
          );

          // Añadir marcador de destino
          _markers.add(
            Marker(
              markerId: MarkerId('destination'),
              position: _destinationLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: 'Destino',
                snippet: _destinationAddress,
              ),
            ),
          );

          // Añadir polyline REAL con todos los puntos de la ruta
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route'),
              points: directionsResult.polylinePoints!,
              color: ModernTheme.primaryOrange,
              width: 4,
              patterns: [], // Sin patrones para línea sólida
              geodesic: true, // Seguir curvatura de la Tierra
            ),
          );
        });

        AppLogger.info(
            '✅ Ruta calculada: ${directionsResult.distance}, ${directionsResult.duration}');

        // Ajustar cámara para mostrar toda la ruta
        _fitRouteInMap();
      } else {
        AppLogger.warning(
            '⚠️ Error obteniendo direcciones: ${directionsResult.error}');
        // Fallback a estimación simple si falla la API
        _calculateRouteFallback();
      }
    } catch (e) {
      AppLogger.error('Error calculando ruta con Google Directions', e);
      // Fallback a estimación simple
      _calculateRouteFallback();
    }
  }

  void _calculateRouteFallback() {
    AppLogger.info('📍 Usando fallback: estimación de ruta simple');
    final distance =
        _calculateDistanceHaversine(_currentLocation!, _destinationLocation!);

    setState(() {
      _estimatedDistance = distance;
      _estimatedTime = (distance * 3).round(); // Estimación: 3 min por km
      _estimatedPrice = ServiceTypeConfig.calculatePrice(
        _selectedService,
        distance,
        _estimatedTime!,
      );

      // Añadir marcador de destino
      _markers.add(
        Marker(
          markerId: MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destino',
            snippet: _destinationAddress,
          ),
        ),
      );

      // Línea directa como fallback
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          points: [_currentLocation!, _destinationLocation!],
          color: ModernTheme.primaryOrange,
          width: 4,
        ),
      );
    });

    _fitRouteInMap();
  }

  double _calculateDistanceHaversine(LatLng start, LatLng end) {
    // Fórmula Haversine simplificada (solo como fallback)
    const double earthRadius = 6371; // km
    final double lat1Rad = start.latitude * (3.141592653589793 / 180);
    final double lat2Rad = end.latitude * (3.141592653589793 / 180);
    final double deltaLat =
        (end.latitude - start.latitude) * (3.141592653589793 / 180);
    final double deltaLon =
        (end.longitude - start.longitude) * (3.141592653589793 / 180);

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);

    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  void _fitRouteInMap() {
    if (_mapController == null ||
        _currentLocation == null ||
        _destinationLocation == null) {
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(
        _currentLocation!.latitude < _destinationLocation!.latitude
            ? _currentLocation!.latitude
            : _destinationLocation!.latitude,
        _currentLocation!.longitude < _destinationLocation!.longitude
            ? _currentLocation!.longitude
            : _destinationLocation!.longitude,
      ),
      northeast: LatLng(
        _currentLocation!.latitude > _destinationLocation!.latitude
            ? _currentLocation!.latitude
            : _destinationLocation!.latitude,
        _currentLocation!.longitude > _destinationLocation!.longitude
            ? _currentLocation!.longitude
            : _destinationLocation!.longitude,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Future<void> _requestRide() async {
    if (_isRequestingRide) return;

    setState(() {
      _isRequestingRide = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Crear solicitud de viaje
      final rideRequest = await _firestore.collection('ride_requests').add({
        'passengerId': user.uid,
        'passengerName': user.displayName ?? 'Pasajero',
        'passengerPhone': user.phoneNumber ?? '',
        'serviceType': _selectedService.toString().split('.').last,
        'pickupLocation':
            GeoPoint(_currentLocation!.latitude, _currentLocation!.longitude),
        'pickupAddress': _currentAddress,
        'destinationLocation': GeoPoint(
            _destinationLocation!.latitude, _destinationLocation!.longitude),
        'destinationAddress': _destinationAddress,
        'estimatedDistance': _estimatedDistance,
        'estimatedTime': _estimatedTime,
        'estimatedPrice': _estimatedPrice,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Navegar a pantalla de espera
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/passenger/tracking', // Cambiar a tracking existente
          arguments: rideRequest.id,
        );
      }
    } catch (e) {
      AppLogger.error('Error solicitando viaje', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al solicitar el viaje'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingRide = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _locationSubscription?.cancel();
    _driversSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: OasisAppBar.standard(
        title: 'Inicio',
        showBackButton: false,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/shared/notifications'),
          ),
        ],
      ),
      drawer: PassengerDrawer(),
      body: Stack(
        children: [
          // Mapa de fondo
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? LatLng(-12.0464, -77.0428),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _updateMapCamera();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Gradiente superior
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Contenido principal con padding responsivo
          SafeArea(
            child: SingleChildScrollView(
              padding: ModernTheme.getResponsivePadding(context),
              child: Column(
                children: [

                  // Tarjeta de búsqueda
                  if (!_destinationSelected)
                    OasisCard.elevated(
                      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Padding(
                        padding: AppSpacing.all(AppSpacing.md),
                    child: Column(
                      children: [
                        // Ubicación actual - Completamente editable con GPS
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: ModernTheme.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            AppSpacing.horizontalSpaceSM,
                            Expanded(
                              child: AddressSearchWidget(
                                hintText: 'Tu ubicación actual',
                                initialText: _currentAddress,
                                onPlaceSelected: _onOriginSelected,
                                autofocus: false,
                              ),
                            ),
                            AppSpacing.horizontalSpaceXS,
                            // Botón GPS - Más visible
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: ModernTheme.primaryOrange,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: ModernTheme.primaryOrange
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.my_location_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: _getCurrentGPSLocation,
                                tooltip: 'Obtener mi ubicación GPS',
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),

                        Padding(
                          padding: EdgeInsets.only(left: AppSpacing.xs),
                          child: Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                        ),

                        // Campo de búsqueda de destino
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: ModernTheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            AppSpacing.horizontalSpaceSM,
                            Expanded(
                              child: AddressSearchWidget(
                                hintText: '¿A dónde vas?',
                                onPlaceSelected: _onDestinationSelected,
                                autofocus: false,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Información del viaje seleccionado
                if (_destinationSelected)
                  OasisCard.elevated(
                    margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Padding(
                      padding: AppSpacing.all(AppSpacing.md),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.route, color: ModernTheme.primaryBlue),
                              AppSpacing.horizontalSpaceXS,
                              Text(
                                '${_estimatedDistance?.toStringAsFixed(1) ?? '0'} km',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              AppSpacing.horizontalSpaceMD,
                              Icon(Icons.access_time,
                                  color: ModernTheme.primaryBlue),
                              AppSpacing.horizontalSpaceXS,
                              Text(
                                '${_estimatedTime ?? 0} min',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Spacer(),
                              OasisButton.text(
                                text: 'Cambiar',
                                onPressed: () {
                                  setState(() {
                                    _destinationSelected = false;
                                    _showServiceOptions = false;
                                    _destinationLocation = null;
                                    _destinationAddress = '';
                                    _markers.removeWhere(
                                        (m) => m.markerId.value == 'destination');
                                    _polylines.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Botón de ubicación actual
          Positioned(
            right: AppSpacing.md,
            bottom: _showServiceOptions ? 320 : 100,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              child: OasisButton.icon(
                icon: Icons.my_location,
                onPressed: _updateMapCamera,
                size: OasisButtonSize.medium,
                variant: OasisButtonVariant.secondary,
              ),
            ),
          ),

          // Panel de opciones de servicio con DraggableScrollableSheet responsivo
          if (_showServiceOptions)
            LayoutBuilder(
              builder: (context, constraints) {
                // Determinar si es pantalla pequeña
                final isSmallScreen = constraints.maxHeight < 600 ||
                                    constraints.maxWidth < ModernTheme.mobileBreakpoint;

                return DraggableScrollableSheet(
                  initialChildSize: isSmallScreen ? 0.5 : 0.4, // Más espacio en pantallas pequeñas
                  minChildSize: isSmallScreen ? 0.35 : 0.25, // Tamaño mínimo más grande en pantallas pequeñas
                  maxChildSize: isSmallScreen ? 0.85 : 0.75, // Tamaño máximo más grande en pantallas pequeñas
                  snap: true, // Habilitar snap a posiciones predefinidas
                  snapSizes: isSmallScreen
                      ? const [0.35, 0.5, 0.85] // Posiciones para pantallas pequeñas
                      : const [0.25, 0.4, 0.75], // Posiciones para pantallas normales
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 25,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Widget de opciones de transporte
                      Expanded(
                        child: TransportOptionsWidget(
                          selectedService: _selectedService,
                          onServiceSelected: (service) {
                            setState(() {
                              _selectedService = service;
                              _estimatedPrice =
                                  ServiceTypeConfig.calculatePrice(
                                service,
                                _estimatedDistance ?? 0,
                                _estimatedTime ?? 0,
                              );
                            });
                          },
                          distance: _estimatedDistance,
                          scrollController: scrollController,
                        ),
                      ),
                      // Botón de solicitar taxi integrado en el panel
                      if (_destinationSelected)
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: Offset(0, -5),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OasisButton.primary(
                                      text: _isRequestingRide
                                          ? 'Solicitando...'
                                          : 'Solicitar ${ServiceTypeConfig.getServiceInfo(_selectedService).name}',
                                      onPressed: _isRequestingRide ? null : _requestRide,
                                      size: OasisButtonSize.large,
                                      icon: _isRequestingRide
                                          ? null
                                          : Icons.arrow_forward,
                                      loading: _isRequestingRide,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            )
        ],
      ),
      drawer: const PassengerDrawer(),
    );
  }
}

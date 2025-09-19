import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../core/theme/modern_theme.dart';
import '../../models/service_type_model.dart';
import '../../models/driver_model.dart';
import '../../models/price_negotiation_model.dart';
import '../../providers/location_provider.dart';
import '../../utils/app_logger.dart';

class ModernDriverHomeScreen extends StatefulWidget {
  const ModernDriverHomeScreen({super.key});

  @override
  ModernDriverHomeScreenState createState() => ModernDriverHomeScreenState();
}

class ModernDriverHomeScreenState extends State<ModernDriverHomeScreen>
    with TickerProviderStateMixin {
  // Controladores
  // GoogleMapController? _mapController; // No usado actualmente
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Estado del conductor
  Driver? _currentDriver;
  bool _isOnline = false;
  // bool _hasActiveTrip = false; // No usado actualmente
  // VehicleType _selectedVehicle = VehicleType.sedan; // No usado actualmente

  // Solicitudes
  List<PriceNegotiation> _availableRequests = [];
  PriceNegotiation? _selectedRequest;
  bool _showRequestDetails = false;
  StreamSubscription? _requestsSubscription;

  // Estadísticas
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  final double _acceptanceRate = 95.5;

  // Mapa
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernDriverHomeScreen', 'initState');
    _initializeAnimations();
    _initializeDriver();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );

    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeDriver() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      // Cargar o crear perfil del conductor
      final driverDoc =
          await _firestore.collection('drivers').doc(user.uid).get();

      if (!driverDoc.exists) {
        // Crear perfil básico del conductor
        final newDriver = {
          'name': user.displayName ?? 'Conductor',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'rating': 5.0,
          'totalTrips': 0,
          'totalRatings': 0,
          'isOnline': false,
          'isAvailable': false,
          'walletBalance': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'documentsVerified': false,
          'verifiedDocuments': {},
          'vehicles': [],
          'currentVehicle': null,
        };

        await _firestore.collection('drivers').doc(user.uid).set(newDriver);

        if (mounted) {
          setState(() {
            _currentDriver = Driver(
              id: user.uid,
              name: user.displayName ?? 'Conductor',
              email: user.email ?? '',
              phone: user.phoneNumber ?? '',
              createdAt: DateTime.now(),
            );
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentDriver = Driver.fromFirestore(driverDoc);
            // if (_currentDriver!.currentVehicle != null) {
            //   _selectedVehicle = _currentDriver!.currentVehicle!.type;
            // }
          });
        }
      }

      await _loadTodayStats();
    } catch (e) {
      AppLogger.error('Error inicializando conductor', e);
    }
  }

  void _toggleOnlineStatus() async {
    if (_currentDriver == null) return;

    // Verificar si tiene vehículo configurado
    if (_currentDriver!.currentVehicle == null && _isOnline == false) {
      _showVehicleRequiredDialog();
      return;
    }

    setState(() {
      _isOnline = !_isOnline;
    });

    // Actualizar en Firebase
    await _firestore.collection('drivers').doc(_currentDriver!.id).update({
      'isOnline': _isOnline,
      'isAvailable': _isOnline,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });

    if (_isOnline) {
      _startListeningForRequests();
      _updateLocationPeriodically();
    } else {
      _stopListeningForRequests();
    }

    HapticFeedback.mediumImpact();
  }

  void _startListeningForRequests() {
    if (_currentDriver == null || _currentDriver!.currentVehicle == null) {
      return;
    }

    final supportedServices = _currentDriver!.availableServices;

    _requestsSubscription = _firestore
        .collection('price_negotiations')
        .where('status', isEqualTo: 'waiting')
        .where('serviceType',
            whereIn: supportedServices.map((s) => s.index).toList())
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      final requests = <PriceNegotiation>[];

      for (var doc in snapshot.docs) {
        try {
          requests.add(PriceNegotiation.fromFirestore(doc));
        } catch (e) {
          AppLogger.error('Error parseando solicitud ${doc.id}', e);
        }
      }

      setState(() {
        _availableRequests = requests;
        _updateMapMarkers();
      });
    });
  }

  void _stopListeningForRequests() {
    _requestsSubscription?.cancel();
    setState(() {
      _availableRequests = [];
      _markers.clear();
    });
  }

  void _updateLocationPeriodically() {
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isOnline) {
        timer.cancel();
        return;
      }

      final locationProvider = context.read<LocationProvider>();
      if (locationProvider.currentLocation != null) {
        _firestore.collection('drivers').doc(_currentDriver!.id).update({
          'currentLocation': GeoPoint(
            locationProvider.currentLocation!.latitude,
            locationProvider.currentLocation!.longitude,
          ),
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  void _updateMapMarkers() {
    _markers.clear();

    for (var request in _availableRequests) {
      final serviceInfo =
          ServiceTypeConfig.getServiceInfo(request.serviceType!);

      _markers.add(
        Marker(
          markerId: MarkerId(request.id),
          position: LatLng(request.pickup.latitude, request.pickup.longitude),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: serviceInfo.name,
            snippet: 'S/ ${request.offeredPrice.toStringAsFixed(2)}',
          ),
          onTap: () => _selectRequest(request),
        ),
      );
    }
  }

  void _selectRequest(PriceNegotiation request) {
    setState(() {
      _selectedRequest = request;
      _showRequestDetails = true;
    });
    _slideController.forward();
  }

  void _acceptRequest(PriceNegotiation request) async {
    try {
      // Actualizar solicitud
      await _firestore.collection('price_negotiations').doc(request.id).update({
        'status': 'accepted',
        'driverId': _currentDriver!.id,
        'driverName': _currentDriver!.name,
        'driverPhoto': _currentDriver!.photoUrl ?? '',
        'driverRating': _currentDriver!.rating,
        'driverVehicle': _currentDriver!.currentVehicle?.toMap(),
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Crear viaje
      await _firestore.collection('rides').add({
        'negotiationId': request.id,
        'passengerId': request.passengerId,
        'driverId': _currentDriver!.id,
        'serviceType': request.serviceType?.index,
        'pickupAddress': request.pickup.address,
        'pickupLocation':
            GeoPoint(request.pickup.latitude, request.pickup.longitude),
        'destinationAddress': request.destination.address,
        'destinationLocation': GeoPoint(
            request.destination.latitude, request.destination.longitude),
        'fare': request.offeredPrice,
        'distance': request.distance,
        'estimatedTime': request.estimatedTime,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _availableRequests.remove(request);
          _showRequestDetails = false;
        });

        _showAcceptedDialog(request);
      }
    } catch (e) {
      AppLogger.error('Error aceptando solicitud', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar el viaje'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _rejectRequest(PriceNegotiation request) async {
    setState(() {
      _availableRequests.remove(request);
      _showRequestDetails = false;
      _selectedRequest = null;
    });
    _slideController.reverse();
  }

  void _showVehicleRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.directions_car, color: ModernTheme.warning),
            const SizedBox(width: 12),
            Text('Vehículo Requerido'),
          ],
        ),
        content: Text(
          'Debes configurar tu vehículo antes de conectarte. Ve a tu perfil para agregar los datos de tu vehículo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver/vehicle-management');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.primaryOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Configurar Vehículo'),
          ),
        ],
      ),
    );
  }

  void _showAcceptedDialog(PriceNegotiation request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: ModernTheme.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '¡Viaje Aceptado!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dirígete al punto de recogida',
              style: TextStyle(color: ModernTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/navigation');
              },
              icon: const Icon(Icons.navigation),
              label: Text('Iniciar Navegación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.primaryOrange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTodayStats() async {
    if (_currentDriver == null) return;

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final stats = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _currentDriver!.id)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('status', isEqualTo: 'completed')
          .get();

      double earnings = 0;
      for (var doc in stats.docs) {
        earnings += (doc.data()['fare'] ?? 0).toDouble();
      }

      setState(() {
        _todayEarnings = earnings * 0.8; // 80% para el conductor
        _todayTrips = stats.size;
      });
    } catch (e) {
      AppLogger.error('Error cargando estadísticas', e);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa de fondo
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(-12.0464, -77.0428),
              zoom: 13,
            ),
            // onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Header degradado
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _isOnline ? ModernTheme.success : ModernTheme.textSecondary,
                  _isOnline
                      ? ModernTheme.success.withValues(alpha: 0.0)
                      : ModernTheme.textSecondary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          // Contenido principal
          SafeArea(
            child: Column(
              children: [
                // AppBar personalizado
                _buildCustomAppBar(),

                // Panel de control
                _buildControlPanel(),

                // Estadísticas
                if (_isOnline) _buildStatsPanel(),

                Spacer(),

                // Lista de solicitudes
                if (_isOnline && _availableRequests.isNotEmpty)
                  _buildRequestsList(),
              ],
            ),
          ),

          // Detalle de solicitud
          if (_showRequestDetails && _selectedRequest != null)
            _buildRequestDetailSheet(),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _currentDriver?.currentVehicle != null
                  ? _getVehicleIcon(_currentDriver!.currentVehicle!.type)
                  : Icons.directions_car,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentDriver?.name ?? 'Conductor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _isOnline
                      ? 'CONECTADO • ${_currentDriver?.currentVehicle != null ? VehicleServiceConfig.getVehicleTypeName(_currentDriver!.currentVehicle!.type) : "Sin vehículo"}'
                      : 'DESCONECTADO',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Botón de billetera
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon:
                  const Icon(Icons.account_balance_wallet, color: Colors.white),
              onPressed: () => Navigator.pushNamed(context, '/driver/wallet'),
            ),
          ),
          // Menú
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _showDriverMenu(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Switch principal
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? ModernTheme.success
                      : ModernTheme.textSecondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnline ? 'CONECTADO' : 'DESCONECTADO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isOnline
                            ? ModernTheme.success
                            : ModernTheme.textSecondary,
                      ),
                    ),
                    Text(
                      _isOnline
                          ? 'Recibiendo solicitudes'
                          : 'Actívate para recibir viajes',
                      style: TextStyle(
                        fontSize: 12,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isOnline,
                onChanged: (value) => _toggleOnlineStatus(),
              ),
            ],
          ),

          // Servicios disponibles
          if (_currentDriver?.currentVehicle != null && _isOnline) ...[
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servicios Activos',
                    style: TextStyle(
                      fontSize: 12,
                      color: ModernTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _currentDriver!.availableServices.map((service) {
                      final info = ServiceTypeConfig.getServiceInfo(service);
                      return Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: info.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: info.color.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(info.icon, size: 16, color: info.color),
                            const SizedBox(width: 4),
                            Text(
                              info.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: info.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hoy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ModernTheme.primaryOrange,
                      ModernTheme.accentYellow
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  DateTime.now().day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Ganancias',
                'S/ ${_todayEarnings.toStringAsFixed(0)}',
                Icons.monetization_on,
                ModernTheme.success,
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildStatItem(
                'Viajes',
                _todayTrips.toString(),
                Icons.directions_car,
                ModernTheme.primaryBlue,
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildStatItem(
                'Rating',
                '${_acceptanceRate.toStringAsFixed(1)}%',
                Icons.star,
                ModernTheme.accentYellow,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: ModernTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Solicitudes Disponibles',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: ModernTheme.primaryOrange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_availableRequests.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20),
              itemCount: _availableRequests.length,
              itemBuilder: (context, index) {
                return _buildRequestCard(_availableRequests[index]);
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRequestCard(PriceNegotiation request) {
    final serviceInfo = ServiceTypeConfig.getServiceInfo(request.serviceType!);
    final timeRemaining = request.timeRemaining;
    final isUrgent = timeRemaining.inMinutes < 2;

    return GestureDetector(
      onTap: () => _selectRequest(request),
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              serviceInfo.color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUrgent
                ? ModernTheme.warning
                : serviceInfo.color.withValues(alpha: 0.3),
            width: isUrgent ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: serviceInfo.color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con tipo de servicio
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: serviceInfo.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(serviceInfo.icon,
                      color: serviceInfo.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceInfo.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: serviceInfo.color,
                        ),
                      ),
                      Text(
                        request.passengerName,
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Precio
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ModernTheme.success,
                        ModernTheme.success.withValues(alpha: 0.8)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'S/ ${request.offeredPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Ubicaciones
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 16, color: ModernTheme.success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.pickup.address,
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, size: 16, color: ModernTheme.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.destination.address,
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            Spacer(),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.route,
                        size: 14, color: ModernTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${request.distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                          fontSize: 12, color: ModernTheme.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.timer,
                        size: 14, color: ModernTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${request.estimatedTime} min',
                      style: TextStyle(
                          fontSize: 12, color: ModernTheme.textSecondary),
                    ),
                  ],
                ),
                // Tiempo restante
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent ? ModernTheme.warning : ModernTheme.info,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestDetailSheet() {
    if (_selectedRequest == null) return SizedBox();

    final request = _selectedRequest!;
    final serviceInfo = ServiceTypeConfig.getServiceInfo(request.serviceType!);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 500 * (1 - _slideAnimation.value)),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Tipo de servicio
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          serviceInfo.color.withValues(alpha: 0.1),
                          serviceInfo.color.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(serviceInfo.icon,
                            color: serviceInfo.color, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceInfo.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: serviceInfo.color,
                              ),
                            ),
                            Text(
                              serviceInfo.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: ModernTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Información del pasajero
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor:
                            ModernTheme.primaryOrange.withValues(alpha: 0.1),
                        child: Icon(Icons.person,
                            color: ModernTheme.primaryOrange),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.passengerName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star,
                                    size: 16, color: ModernTheme.accentYellow),
                                const SizedBox(width: 4),
                                Text(
                                  request.passengerRating.toStringAsFixed(1),
                                  style: TextStyle(
                                      color: ModernTheme.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  request.paymentMethod.toString() == 'cash'
                                      ? Icons.money
                                      : Icons.credit_card,
                                  size: 16,
                                  color: ModernTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  request.paymentMethod.toString() == 'cash'
                                      ? 'Efectivo'
                                      : 'Tarjeta',
                                  style: TextStyle(
                                      color: ModernTheme.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ModernTheme.success,
                              ModernTheme.success.withValues(alpha: 0.8)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'S/ ${request.offeredPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Detalles del viaje
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ModernTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recogida',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ModernTheme.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    request.pickup.address,
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
                        Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                        ),
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Destino',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ModernTheme.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    request.destination.address,
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Información adicional
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoChip(
                        Icons.route,
                        '${request.distance.toStringAsFixed(1)} km',
                      ),
                      _buildInfoChip(
                        Icons.access_time,
                        '${request.estimatedTime} min',
                      ),
                      _buildInfoChip(
                        Icons.timer,
                        '${request.timeRemaining.inMinutes}:${(request.timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rejectRequest(request),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(color: ModernTheme.textSecondary),
                          ),
                          child: Text(
                            'Rechazar',
                            style: TextStyle(
                              color: ModernTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _acceptRequest(request),
                          icon: Icon(Icons.check),
                          label: Text(
                            'Aceptar Viaje',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ModernTheme.success,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ModernTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: ModernTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getVehicleIcon(VehicleType type) {
    switch (type) {
      case VehicleType.moto:
        return Icons.two_wheeler;
      case VehicleType.van:
        return Icons.airport_shuttle;
      case VehicleType.camioneta:
        return Icons.local_shipping;
      case VehicleType.grua:
        return Icons.car_repair;
      default:
        return Icons.directions_car;
    }
  }

  void _showDriverMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person, color: ModernTheme.primaryOrange),
              title: Text('Mi Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/profile');
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.directions_car, color: ModernTheme.primaryOrange),
              title: Text('Mi Vehículo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/vehicle-management');
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics, color: ModernTheme.primaryOrange),
              title: Text('Métricas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/metrics');
              },
            ),
            ListTile(
              leading: Icon(Icons.history, color: ModernTheme.primaryOrange),
              title: Text('Historial'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/transactions-history');
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.description, color: ModernTheme.primaryOrange),
              title: Text('Documentos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver/documents');
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: ModernTheme.primaryOrange),
              title: Text('Configuración'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/shared/settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: ModernTheme.error),
              title: Text('Cerrar Sesión'),
              onTap: () {
                Navigator.pop(context);
                _auth.signOut();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

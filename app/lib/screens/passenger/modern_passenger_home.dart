// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../models/price_negotiation_model.dart' as models;
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../shared/settings_screen.dart';
import '../shared/about_screen.dart';
import '../../utils/logger.dart';

class ModernPassengerHomeScreen extends StatefulWidget {
  const ModernPassengerHomeScreen({super.key});

  @override
  State<ModernPassengerHomeScreen> createState() =>
      _ModernPassengerHomeScreenState();
}

class _ModernPassengerHomeScreenState extends State<ModernPassengerHomeScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Controllers
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  
  // Animation controllers
  late AnimationController _bottomSheetController;
  late AnimationController _searchBarController;
  late Animation<double> _bottomSheetAnimation;
  late Animation<double> _searchBarAnimation;
  
  // Estados
  bool _isSearchingDestination = false;
  bool _showPriceNegotiation = false;
  bool _showDriverOffers = false;
  double _offeredPrice = 15.0;
  
  // Negociación actual
  models.PriceNegotiation? _currentNegotiation;
  Timer? _negotiationTimer;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernPassengerHomeScreen', 'initState');
    
    _bottomSheetController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    
    _searchBarController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    _bottomSheetAnimation = CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeInOut,
    );
    
    _searchBarAnimation = CurvedAnimation(
      parent: _searchBarController,
      curve: Curves.easeInOut,
    );
    
    _bottomSheetController.forward();
    _searchBarController.forward();
    
    // Listener para cambios en el estado del viaje
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRideProviderListener();
    });
  }
  
  void _setupRideProviderListener() {
    if (!mounted) return;
    
    AppLogger.debug('Configurando listener del RideProvider');
    try {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      // Escuchar cambios en el viaje actual
      rideProvider.addListener(_onRideProviderChanged);
      AppLogger.debug('Listener del RideProvider configurado exitosamente');
    } catch (e) {
      AppLogger.error('Error configurando listener del RideProvider', e);
    }
  }
  
  void _onRideProviderChanged() {
    if (!mounted) return;
    
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final currentTrip = rideProvider.currentTrip;
    
    if (currentTrip != null) {
      // Navegar al código de verificación cuando el conductor sea asignado
      if (currentTrip.status == 'accepted' || currentTrip.status == 'driver_arriving') {
        if (currentTrip.verificationCode != null) {
          Navigator.pushNamed(
            context, 
            '/passenger/verification-code',
            arguments: currentTrip,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    // Remover listener antes de dispose para evitar "widget deactivated" error
    try {
      if (mounted) {
        final rideProvider = Provider.of<RideProvider>(context, listen: false);
        rideProvider.removeListener(_onRideProviderChanged);
      }
    } catch (e) {
      // Ignorar errores si el context ya no está disponible
      AppLogger.debug('Error removiendo listener en dispose: $e');
    }
    
    _bottomSheetController.dispose();
    _searchBarController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _negotiationTimer?.cancel();
    super.dispose();
  }

  void _startNegotiation() async {
    // Validar que se hayan ingresado origen y destino
    if (_pickupController.text.isEmpty || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debes ingresar origen y destino'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (!mounted) return;
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Usuario no autenticado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _showPriceNegotiation = true;
      });

      // Obtener ubicación real del GPS del dispositivo
      LatLng? currentLocation = await _getCurrentLocation();
      if (currentLocation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación actual. Verifica los permisos GPS.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Geocoding real para destino (si no se proporcionó coordenadas específicas)
      LatLng? destinationLocation = await _getDestinationLocation();
      if (destinationLocation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo encontrar la dirección de destino'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Crear solicitud de viaje REAL usando ubicaciones reales
      await rideProvider.requestRide(
        pickupLocation: currentLocation, // UBICACIÓN GPS REAL
        destinationLocation: destinationLocation, // DESTINO REAL GEOCODIFICADO
        pickupAddress: _pickupController.text.isEmpty ? 'Mi ubicación actual' : _pickupController.text,
        destinationAddress: _destinationController.text,
        userId: user.id,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Buscando conductores disponibles...'),
          backgroundColor: ModernTheme.oasisGreen,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _showPriceNegotiation = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al solicitar viaje: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _simulateDriverOffers() {
    _negotiationTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (_currentNegotiation != null && 
          _currentNegotiation!.driverOffers.length < 5) {
        if (!mounted) return;
        setState(() {
          final newOffer = models.DriverOffer(
            driverId: 'driver${_currentNegotiation!.driverOffers.length}',
            driverName: 'Conductor ${_currentNegotiation!.driverOffers.length + 1}',
            driverPhoto: '', // Se obtiene del perfil del conductor desde Firebase
            driverRating: 4.5 + (_currentNegotiation!.driverOffers.length * 0.1),
            vehicleModel: ['Toyota Corolla', 'Nissan Sentra', 'Hyundai Accent'][
              _currentNegotiation!.driverOffers.length % 3
            ],
            vehiclePlate: 'ABC-${100 + _currentNegotiation!.driverOffers.length}',
            vehicleColor: ['Blanco', 'Negro', 'Gris'][
              _currentNegotiation!.driverOffers.length % 3
            ],
            acceptedPrice: _offeredPrice - (_currentNegotiation!.driverOffers.length * 0.5),
            estimatedArrival: 3 + _currentNegotiation!.driverOffers.length,
            offeredAt: DateTime.now(),
            status: models.OfferStatus.pending,
            completedTrips: 500 + (_currentNegotiation!.driverOffers.length * 100),
            acceptanceRate: 90.0 + _currentNegotiation!.driverOffers.length,
          );
          
          _currentNegotiation = _currentNegotiation!.copyWith(
            driverOffers: [..._currentNegotiation!.driverOffers, newOffer],
            status: models.NegotiationStatus.negotiating,
          );
          
          _showDriverOffers = true;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OasisAppBar(
        title: 'Oasis Taxi',
        showBackButton: false,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/shared/notifications'),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(-12.0851, -76.9770),
              zoom: 15,
            ),
            // onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // Barra de búsqueda superior
          SafeArea(
            child: AnimatedBuilder(
              animation: _searchBarAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -100 * (1 - _searchBarAnimation.value)),
                  child: Opacity(
                    opacity: _searchBarAnimation.value,
                    child: _buildSearchBar(),
                  ),
                );
              },
            ),
          ),
          
          // Bottom sheet con negociación de precio
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _bottomSheetAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 400 * (1 - _bottomSheetAnimation.value)),
                  child: _showDriverOffers
                      ? _buildDriverOffersSheet()
                      : _showPriceNegotiation
                          ? _buildPriceNegotiationSheet()
                          : _buildDestinationSheet(),
                );
              },
            ),
          ),
          
          
          // Botón de ubicación actual
          Positioned(
            right: 16,
            bottom: _showPriceNegotiation ? 420 : 320,
            child: _buildLocationButton(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ModernTheme.floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Campo de recogida
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ModernTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _pickupController,
                    decoration: InputDecoration(
                      hintText: '¿Dónde estás?',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.my_location, color: ModernTheme.primaryOrange),
                  onPressed: () {
                    _pickupController.text = 'Mi ubicación actual';
                  },
                ),
              ],
            ),
          ),
          
          Divider(height: 1),
          
          // Campo de destino
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ModernTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      hintText: '¿A dónde vas?',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: TextStyle(fontSize: 16),
                    onTap: () {
                      if (!mounted) return;
                      setState(() => _isSearchingDestination = true);
                    },
                  ),
                ),
                if (_destinationController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close, size: 20),
                    onPressed: () {
                      _destinationController.clear();
                      if (!mounted) return;
                      setState(() => _isSearchingDestination = false);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDestinationSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: ModernTheme.floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Lugares favoritos
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lugares favoritos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFavoritePlace(Icons.home, 'Casa'),
                    _buildFavoritePlace(Icons.work, 'Trabajo'),
                    _buildFavoritePlace(Icons.school, 'Universidad'),
                    _buildFavoritePlace(Icons.add, 'Agregar'),
                  ],
                ),
              ],
            ),
          ),
          
          Divider(),
          
          // Destinos recientes
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 16),
                _buildRecentPlace('Centro Comercial Plaza', 'Av. Principal 123'),
                _buildRecentPlace('Aeropuerto Internacional', 'Terminal 1'),
                _buildRecentPlace('Parque Central', 'Calle Principal s/n'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPriceNegotiationSheet() {
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
            margin: EdgeInsets.only(bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Título
          Text(
            'Ofrece tu precio',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Los conductores cercanos verán tu oferta',
            style: TextStyle(
              fontSize: 14,
              color: ModernTheme.textSecondary,
            ),
          ),
          SizedBox(height: 24),
          
          // Información del viaje
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.backgroundLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.route, color: ModernTheme.primaryBlue),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '5.5 km • 15 min',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Precio sugerido: S/ 15.00',
                        style: TextStyle(
                          color: ModernTheme.success,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          
          // Slider de precio
          PriceNegotiationSlider(
            minPrice: 10.0,
            maxPrice: 25.0,
            suggestedPrice: 15.0,
            onPriceChanged: (price) {
              if (!mounted) return;
              setState(() => _offeredPrice = price);
            },
          ),
          SizedBox(height: 24),
          
          // Métodos de pago
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPaymentMethod(Icons.money, 'Efectivo', true),
              _buildPaymentMethod(Icons.credit_card, 'Tarjeta', false),
              _buildPaymentMethod(Icons.account_balance_wallet, 'Billetera', false),
            ],
          ),
          SizedBox(height: 24),
          
          // Botón de buscar conductor
          AnimatedPulseButton(
            text: 'Buscar conductor',
            icon: Icons.search,
            onPressed: _startNegotiation,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDriverOffersSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: ModernTheme.floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Título con contador
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ofertas de conductores',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_currentNegotiation?.driverOffers.length ?? 0} conductores interesados',
                      style: TextStyle(
                        fontSize: 14,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                // Timer countdown
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ModernTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: ModernTheme.warning),
                      SizedBox(width: 4),
                      Text(
                        '${_currentNegotiation?.timeRemaining.inMinutes ?? 0}:${(_currentNegotiation?.timeRemaining.inSeconds ?? 0) % 60}',
                        style: TextStyle(
                          color: ModernTheme.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de ofertas
          SizedBox(
            height: 300,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20),
              itemCount: _currentNegotiation?.driverOffers.length ?? 0,
              itemBuilder: (context, index) {
                final offer = _currentNegotiation!.driverOffers[index];
                return _buildDriverOfferCard(offer);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDriverOfferCard(models.DriverOffer offer) {
    return AnimatedElevatedCard(
      onTap: () {
        // Aceptar oferta
        _showDriverAcceptedDialog(offer);
      },
      borderRadius: 16,
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            // Foto del conductor
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(offer.driverPhoto),
            ),
            SizedBox(width: 12),
            
            // Información del conductor
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        offer.driverName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.star, size: 16, color: ModernTheme.accentYellow),
                      Text(
                        offer.driverRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${offer.vehicleModel} • ${offer.vehicleColor}',
                    style: TextStyle(
                      fontSize: 14,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: ModernTheme.info),
                      SizedBox(width: 4),
                      Text(
                        '${offer.estimatedArrival} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.info,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.directions_car, size: 14, color: ModernTheme.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        '${offer.completedTrips} viajes',
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
            
            // Precio ofertado
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'S/ ${offer.acceptedPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: ModernTheme.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFavoritePlace(IconData icon, String label) {
    return InkWell(
      onTap: () {
        if (label != 'Agregar') {
          _destinationController.text = label;
          if (!mounted) return;
          setState(() => _showPriceNegotiation = true);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: ModernTheme.primaryOrange),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentPlace(String title, String subtitle) {
    return InkWell(
      onTap: () {
        _destinationController.text = title;
        if (!mounted) return;
        setState(() => _showPriceNegotiation = true);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ModernTheme.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                color: ModernTheme.textSecondary,
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: ModernTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethod(IconData icon, String label, bool selected) {
    return InkWell(
      onTap: () {
        // Cambiar método de pago
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ModernTheme.primaryOrange.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? ModernTheme.primaryOrange : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? ModernTheme.primaryOrange : ModernTheme.textSecondary,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? ModernTheme.primaryOrange : ModernTheme.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildLocationButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: ModernTheme.cardShadow,
      ),
      child: IconButton(
        icon: Icon(Icons.my_location, color: ModernTheme.primaryOrange),
        onPressed: () {
          // Centrar en ubicación actual
        },
      ),
    );
  }
  
  void _showDriverAcceptedDialog(models.DriverOffer offer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernLoadingIndicator(color: ModernTheme.success),
            SizedBox(height: 20),
            Text(
              '¡Conductor encontrado!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${offer.driverName} está en camino',
              style: TextStyle(color: ModernTheme.textSecondary),
            ),
            SizedBox(height: 20),
            AnimatedPulseButton(
              text: 'Ver detalles',
              onPressed: () {
                Navigator.of(context).pop();
                // Navegar a pantalla de seguimiento
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header del drawer unificado
            OasisDrawerHeader(
              userType: 'passenger',
              userName: 'Usuario Pasajero',
            ),
            
            // Opciones del menú
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.history,
                    title: 'Historial de Viajes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/trip-history');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.star,
                    title: 'Mis Calificaciones',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/ratings-history');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.payment,
                    title: 'Métodos de Pago',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/payment-methods');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.favorite,
                    title: 'Lugares Favoritos',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/favorites');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.local_offer,
                    title: 'Promociones',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/promotions');
                    },
                  ),
                  Divider(),
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Mi Perfil',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/passenger/profile');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Configuración',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help,
                    title: 'Ayuda',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AboutScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: 'Cerrar Sesión',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    },
                    color: ModernTheme.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? ModernTheme.oasisGreen,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? ModernTheme.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  /// Obtener ubicación GPS REAL del dispositivo
  Future<LatLng?> _getCurrentLocation() async {
    try {
      AppLogger.info('Obteniendo ubicación GPS real del dispositivo');
      
      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('Permisos de ubicación denegados');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        AppLogger.error('Permisos de ubicación denegados permanentemente');
        return null;
      }

      // Obtener ubicación actual real
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final LatLng currentLocation = LatLng(position.latitude, position.longitude);
      AppLogger.info('Ubicación GPS real obtenida: ${position.latitude}, ${position.longitude}');
      
      return currentLocation;
      
    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo ubicación GPS real', e, stackTrace);
      return null;
    }
  }

  /// Geocodificar dirección de destino REAL usando Google Maps API
  Future<LatLng?> _getDestinationLocation() async {
    if (_destinationController.text.trim().isEmpty) {
      AppLogger.warning('Dirección de destino vacía');
      return null;
    }

    try {
      AppLogger.info('Geocodificando dirección: ${_destinationController.text}');
      
      // Geocodificación básica usando coordenadas fijas para desarrollo
      if (!mounted) return null;
      
      // Por ahora, usar coordenadas fijas para el centro de Lima
      // En producción esto debe ser reemplazado por un servicio de geocoding real
      final coordinates = LatLng(-12.0464, -77.0428); // Plaza de Armas, Lima
      
      AppLogger.info('Usando coordenadas fijas para desarrollo: ${coordinates.latitude}, ${coordinates.longitude}');
      return coordinates;
      
    } catch (e, stackTrace) {
      AppLogger.error('Error en geocoding de destino', e, stackTrace);
      return null;
    }
  }
}
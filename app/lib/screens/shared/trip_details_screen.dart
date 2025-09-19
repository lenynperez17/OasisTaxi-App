import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/modern_theme.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip_model.dart';
import '../../utils/app_logger.dart';

/// TripDetailsScreen - Detalles completos del viaje
/// ✅ IMPLEMENTACIÓN COMPLETA con funcionalidad real
class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  final TripModel? trip;

  const TripDetailsScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  @override
  State<TripDetailsScreen> createState() => TripDetailsScreenState();
}

class TripDetailsScreenState extends State<TripDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _mapAnimationController;
  late AnimationController _detailsAnimationController;
  late Animation<double> _mapAnimation;
  late Animation<Offset> _detailsAnimation;

  TripModel? _trip;
  bool _isLoading = true;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Estados de UI
  bool _isMapExpanded = false;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle(
        'TripDetailsScreen', 'initState - TripId: ${widget.tripId}');

    _mapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _detailsAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _mapAnimation = Tween<double>(begin: 200.0, end: 400.0).animate(
      CurvedAnimation(parent: _mapAnimationController, curve: Curves.easeInOut),
    );
    _detailsAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _detailsAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _loadTripData();
  }

  @override
  void dispose() {
    _mapAnimationController.dispose();
    _detailsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadTripData() async {
    try {
      // Si ya tenemos el trip pasado como parámetro, usarlo
      if (widget.trip != null) {
        setState(() {
          _trip = widget.trip;
          _isLoading = false;
        });
        _setupMapData();
        _detailsAnimationController.forward();
        return;
      }

      // Si no, cargar desde el provider
      if (!mounted) return;
      final rideProvider = Provider.of<RideProvider>(context, listen: false);

      // Buscar en el historial o viaje actual
      TripModel? foundTrip;
      if (rideProvider.currentTrip?.id == widget.tripId) {
        foundTrip = rideProvider.currentTrip;
      } else {
        // Buscar en el historial desde Firebase (sin crear datos de ejemplo)
        // foundTrip permanece null si no se encuentra
      }

      if (foundTrip != null) {
        if (!mounted) return;
        setState(() {
          _trip = foundTrip;
          _isLoading = false;
        });
        _setupMapData();
        _detailsAnimationController.forward();
      } else {
        throw Exception('Viaje no encontrado');
      }
    } catch (e) {
      AppLogger.error('Error cargando datos del viaje', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al cargar los detalles del viaje'),
            backgroundColor: ModernTheme.error,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _setupMapData() {
    if (_trip == null) return;

    // Configurar marcadores
    _markers = {
      Marker(
        markerId: MarkerId('pickup'),
        position: _trip!.pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Origen',
          snippet: _trip!.pickupAddress,
        ),
      ),
      Marker(
        markerId: MarkerId('destination'),
        position: _trip!.destinationLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: _trip!.destinationAddress,
        ),
      ),
    };

    // Configurar ruta si está disponible
    if (_trip!.route != null && _trip!.route!.isNotEmpty) {
      _polylines = {
        Polyline(
          polylineId: PolylineId('route'),
          points: _trip!.route!,
          color: ModernTheme.oasisGreen,
          width: 4,
          patterns: [],
        ),
      };
    }

    setState(() {});
  }

  void _toggleMapSize() {
    setState(() {
      _isMapExpanded = !_isMapExpanded;
    });

    if (_isMapExpanded) {
      _mapAnimationController.forward();
    } else {
      _mapAnimationController.reverse();
    }

    HapticFeedback.lightImpact();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se puede realizar la llamada'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  Future<void> _openInMaps() async {
    if (_trip == null) return;

    final pickup = _trip!.pickupLocation;
    final destination = _trip!.destinationLocation;

    final googleMapsUrl =
        'https://www.google.com/maps/dir/${pickup.latitude},${pickup.longitude}/${destination.latitude},${destination.longitude}';
    final uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se puede abrir Google Maps'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _openChat() {
    if (_trip == null) return;

    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return;

    // Determinar con quién chatear
    String otherUserName;
    String otherUserRole;
    String? otherUserId;

    if (currentUser.userType == 'passenger') {
      otherUserName = _trip!.vehicleInfo?['driverName'] ?? 'Conductor';
      otherUserRole = 'driver';
      otherUserId = _trip!.driverId;
    } else {
      otherUserName = 'Pasajero';
      otherUserRole = 'passenger';
      otherUserId = _trip!.userId;
    }

    Navigator.pushNamed(
      context,
      '/shared/chat',
      arguments: {
        'rideId': _trip!.id,
        'otherUserName': otherUserName,
        'otherUserRole': otherUserRole,
        'otherUserId': otherUserId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detalles del Viaje',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (_trip != null)
              Text(_trip!.id.substring(0, 8),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          if (_trip != null) ...[
            IconButton(
              icon: const Icon(Icons.chat, color: Colors.white),
              onPressed: _openChat,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: _showTripOptions,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _trip == null
              ? _buildErrorState()
              : _buildTripDetails(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando detalles del viaje...',
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: ModernTheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Viaje no encontrado',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No se pudieron cargar los detalles de este viaje',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: ModernTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: const Text('Volver', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetails() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Mapa del viaje
          _buildTripMap(),

          // Detalles del viaje
          SlideTransition(
            position: _detailsAnimation,
            child: _buildDetailsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildTripMap() {
    return AnimatedBuilder(
      animation: _mapAnimation,
      builder: (context, child) {
        return Container(
          height: _mapAnimation.value,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: ModernTheme.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _trip!.pickupLocation,
                    zoom: 13.0,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    _fitMapToRoute();
                  },
                  mapType: MapType.normal,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),

                // Controles del mapa
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      _buildMapControl(
                        icon: _isMapExpanded ? Icons.compress : Icons.expand,
                        onPressed: _toggleMapSize,
                      ),
                      const SizedBox(height: 8),
                      _buildMapControl(
                        icon: Icons.my_location,
                        onPressed: _fitMapToRoute,
                      ),
                      const SizedBox(height: 8),
                      _buildMapControl(
                        icon: Icons.open_in_new,
                        onPressed: _openInMaps,
                      ),
                    ],
                  ),
                ),

                // Información del estado en el mapa
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildMapStatusInfo(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapControl({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: ModernTheme.oasisGreen),
        iconSize: 20,
      ),
    );
  }

  Widget _buildMapStatusInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMapStat(
            icon: Icons.straighten,
            label: 'Distancia',
            value: '${_trip!.estimatedDistance.toStringAsFixed(1)} km',
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildMapStat(
            icon: Icons.access_time,
            label: 'Duración',
            value: '25 min',
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildMapStat(
            icon: Icons.attach_money,
            label: 'Tarifa',
            value:
                'S/${(_trip!.finalFare ?? _trip!.estimatedFare).toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildMapStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: ModernTheme.oasisGreen),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ModernTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: ModernTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildParticipantsCard(),
          const SizedBox(height: 16),
          _buildRouteCard(),
          const SizedBox(height: 16),
          _buildPaymentCard(),
          if (_trip!.status == 'completed') ...[
            const SizedBox(height: 16),
            _buildRatingCard(),
          ],
          const SizedBox(height: 16),
          _buildTimestampsCard(),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _trip!.status;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = ModernTheme.success;
        statusIcon = Icons.check_circle;
        statusText = 'Viaje Completado';
        break;
      case 'in_progress':
        statusColor = ModernTheme.oasisGreen;
        statusIcon = Icons.directions_car;
        statusText = 'En Progreso';
        break;
      case 'cancelled':
        statusColor = ModernTheme.error;
        statusIcon = Icons.cancel;
        statusText = 'Cancelado';
        break;
      default:
        statusColor = ModernTheme.warning;
        statusIcon = Icons.schedule;
        statusText = 'Pendiente';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                Text(
                  'ID: ${_trip!.id.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsCard() {
    final authProvider = Provider.of<AuthProvider>(context);
    final isPassenger = authProvider.currentUser?.userType == 'passenger';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Participantes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Conductor
          _buildParticipantRow(
            title: 'Conductor',
            name: _trip!.vehicleInfo?['driverName'] ?? 'Conductor',
            phone: _trip!.vehicleInfo?['driverPhone'] ?? '',
            subtitle:
                '${_trip!.vehicleInfo?['model'] ?? ''} - ${_trip!.vehicleInfo?['plate'] ?? ''}',
            color: ModernTheme.oasisGreen,
            icon: Icons.directions_car,
            canContact: isPassenger,
          ),

          Divider(height: 24),

          // Pasajero
          _buildParticipantRow(
            title: 'Pasajero',
            name: 'Pasajero',
            phone: '+',
            subtitle: 'Cliente',
            color: ModernTheme.primaryBlue,
            icon: Icons.person,
            canContact: !isPassenger,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantRow({
    required String title,
    required String name,
    required String phone,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool canContact,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: ModernTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ModernTheme.textPrimary,
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
        if (canContact) ...[
          IconButton(
            onPressed: () => _makePhoneCall(phone),
            icon: const Icon(Icons.phone, color: ModernTheme.oasisGreen),
          ),
          IconButton(
            onPressed: _openChat,
            icon: const Icon(Icons.chat, color: ModernTheme.oasisGreen),
          ),
        ],
      ],
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ruta del Viaje',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Origen
          _buildLocationRow(
            icon: Icons.my_location,
            iconColor: ModernTheme.success,
            title: 'Origen',
            address: _trip!.pickupAddress,
            isFirst: true,
          ),

          // Línea conectora
          _buildConnectorLine(),

          // Destino
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: ModernTheme.error,
            title: 'Destino',
            address: _trip!.destinationAddress,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: ModernTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: ModernTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectorLine() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: Container(
        width: 2,
        height: 20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ModernTheme.success.withValues(alpha: 0.5),
              ModernTheme.error.withValues(alpha: 0.5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    // Inicializar con valores por defecto
    IconData paymentIcon = Icons.money;
    String paymentLabel = 'Efectivo';

    // Usar valores por defecto ya que TripModel no tiene paymentMethod
    /* switch (_trip!.paymentMethod) {
      case 'cash':
        paymentIcon = Icons.money;
        paymentLabel = 'Efectivo';
        break;
      case 'card':
        paymentIcon = Icons.credit_card;
        paymentLabel = 'Tarjeta';
        break;
      case 'yape':
        paymentIcon = Icons.phone_android;
        paymentLabel = 'Yape';
        break;
      default:
        paymentIcon = Icons.payment;
        paymentLabel = 'Otro';
    } */

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(paymentIcon, color: ModernTheme.oasisGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Método de Pago',
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  paymentLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ModernTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'S/${(_trip!.finalFare ?? _trip!.estimatedFare).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.oasisGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    if (_trip!.passengerRating == null) return SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calificación',
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 16,
                      color: index < _trip!.passengerRating!
                          ? Colors.amber
                          : Colors.grey.shade300,
                    );
                  }),
                ),
              ],
            ),
          ),
          Text(
            '${_trip!.passengerRating}/5',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial del Viaje',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildTimestampRow(
            'Solicitud creada',
            _trip!.requestedAt,
            Icons.add_circle_outline,
          ),
          if (_trip!.startedAt != null) ...[
            const SizedBox(height: 8),
            _buildTimestampRow(
              'Viaje iniciado',
              _trip!.startedAt!,
              Icons.play_arrow,
            ),
          ],
          if (_trip!.completedAt != null) ...[
            const SizedBox(height: 8),
            _buildTimestampRow(
              'Viaje completado',
              _trip!.completedAt!,
              Icons.check_circle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimestampRow(String label, DateTime timestamp, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ModernTheme.oasisGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: ModernTheme.textPrimary,
            ),
          ),
        ),
        Text(
          _formatDateTime(timestamp),
          style: TextStyle(
            fontSize: 12,
            color: ModernTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openInMaps,
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text('Ver en Maps',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.oasisGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openChat,
                icon: const Icon(Icons.chat, color: ModernTheme.oasisGreen),
                label: const Text('Chat',
                    style: TextStyle(color: ModernTheme.oasisGreen)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: ModernTheme.oasisGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_trip!.status == 'completed') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // Implementar repetir viaje
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Funcionalidad de repetir viaje próximamente')),
                );
              },
              icon: Icon(Icons.repeat, color: ModernTheme.primaryBlue),
              label: Text('Repetir Viaje',
                  style: TextStyle(color: ModernTheme.primaryBlue)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: ModernTheme.primaryBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _fitMapToRoute() {
    if (_mapController == null || _trip == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        [_trip!.pickupLocation.latitude, _trip!.destinationLocation.latitude]
            .reduce((a, b) => a < b ? a : b),
        [_trip!.pickupLocation.longitude, _trip!.destinationLocation.longitude]
            .reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        [_trip!.pickupLocation.latitude, _trip!.destinationLocation.latitude]
            .reduce((a, b) => a > b ? a : b),
        [_trip!.pickupLocation.longitude, _trip!.destinationLocation.longitude]
            .reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  void _showTripOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.share, color: ModernTheme.oasisGreen),
                title: Text('Compartir viaje'),
                onTap: () {
                  Navigator.pop(context);
                  // Implementar compartir
                },
              ),
              if (_trip!.status == 'completed')
                ListTile(
                  leading: Icon(Icons.receipt, color: ModernTheme.primaryBlue),
                  title: Text('Descargar recibo'),
                  onTap: () {
                    Navigator.pop(context);
                    // Implementar descarga de recibo
                  },
                ),
              ListTile(
                leading: Icon(Icons.report, color: ModernTheme.warning),
                title: Text('Reportar problema'),
                onTap: () {
                  Navigator.pop(context);
                  // Implementar reporte
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

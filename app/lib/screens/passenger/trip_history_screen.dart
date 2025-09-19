import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/oasis_button.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../widgets/cards/oasis_card.dart';
import '../../utils/app_logger.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  TripHistoryScreenState createState() => TripHistoryScreenState();
}

class TripHistoryScreenState extends State<TripHistoryScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  late AnimationController _animationController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _allTrips = [];
  List<Map<String, dynamic>> _completedTrips = [];
  List<Map<String, dynamic>> _cancelledTrips = [];
  List<Map<String, dynamic>> _activeTrips = [];

  // Estadísticas
  int _totalTrips = 0;
  double _totalSpent = 0.0;
  double _totalDistance = 0.0;
  double _averageRating = 0.0;
  int _favoriteDriverCount = 0;
  String _mostVisitedPlace = '';

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('TripHistoryScreen', 'initState');
    _tabController = TabController(length: 4, vsync: this);
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _loadTripHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTripHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Cargar viajes desde Firestore
      final querySnapshot = await _firestore
          .collection('trips')
          .where('passengerId', isEqualTo: user.uid)
          .orderBy('requestedAt', descending: true)
          .limit(100)
          .get();

      _allTrips = [];
      _completedTrips = [];
      _cancelledTrips = [];
      _activeTrips = [];

      double totalFare = 0.0;
      double totalDist = 0.0;
      double totalRating = 0.0;
      int ratedTrips = 0;
      Map<String, int> destinations = {};
      Set<String> drivers = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        // Asegurar que los campos necesarios existen
        data['requestedAt'] = data['requestedAt'] ?? Timestamp.now();
        data['status'] = data['status'] ?? 'unknown';

        _allTrips.add(data);

        // Clasificar por estado
        switch (data['status']) {
          case 'completed':
            _completedTrips.add(data);
            totalFare +=
                (data['finalFare'] ?? data['estimatedFare'] ?? 0.0).toDouble();
            totalDist += (data['estimatedDistance'] ?? 0.0).toDouble();

            if (data['passengerRating'] != null) {
              totalRating += data['passengerRating'].toDouble();
              ratedTrips++;
            }

            // Contar destinos
            final destination = data['dropoffAddress'] ?? '';
            if (destination.isNotEmpty) {
              destinations[destination] = (destinations[destination] ?? 0) + 1;
            }

            // Contar conductores únicos
            if (data['driverId'] != null) {
              drivers.add(data['driverId']);
            }
            break;

          case 'cancelled':
          case 'cancelled_by_passenger':
          case 'cancelled_by_driver':
            _cancelledTrips.add(data);
            break;

          case 'requested':
          case 'accepted':
          case 'on_the_way':
          case 'arrived':
          case 'in_progress':
            _activeTrips.add(data);
            break;
        }
      }

      // Calcular estadísticas
      _totalTrips = _allTrips.length;
      _totalSpent = totalFare;
      _totalDistance = totalDist;
      _averageRating = ratedTrips > 0 ? totalRating / ratedTrips : 0.0;
      _favoriteDriverCount = drivers.length;

      // Encontrar el lugar más visitado
      if (destinations.isNotEmpty) {
        var sortedDestinations = destinations.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        _mostVisitedPlace = sortedDestinations.first.key;
      }

      setState(() {
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      AppLogger.error('Error cargando historial de viajes', e);
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar el historial'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: OasisAppBar.standard(
        title: 'Historial de Viajes',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Todos (${_allTrips.length})'),
            Tab(text: 'Completados (${_completedTrips.length})'),
            Tab(text: 'Activos (${_activeTrips.length})'),
            Tab(text: 'Cancelados (${_cancelledTrips.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: ModernTheme.oasisGreen,
              ),
            )
          : Column(
              children: [
                _buildStatisticsCard(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTripsList(_allTrips),
                      _buildTripsList(_completedTrips),
                      _buildTripsList(_activeTrips),
                      _buildTripsList(_cancelledTrips),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatisticsCard() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -50 * (1 - _animationController.value)),
          child: Opacity(
            opacity: _animationController.value,
            child: Container(
              margin: AppSpacing.all(AppSpacing.md),
              child: OasisCard(
                gradient: ModernTheme.primaryGradient,
                padding: AppSpacing.cardPaddingLargeAll,
                  child: Column(
                children: [
                  Text(
                    'Resumen de tu Actividad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.verticalSpaceLG,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        Icons.directions_car,
                        _totalTrips.toString(),
                        'Viajes',
                      ),
                      _buildStatItem(
                        Icons.attach_money,
                        'S/ ${_totalSpent.toStringAsFixed(2)}',
                        'Gastado',
                      ),
                      _buildStatItem(
                        Icons.star,
                        _averageRating.toStringAsFixed(1),
                        'Rating',
                      ),
                    ],
                  ),
                  AppSpacing.verticalSpaceMD,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        Icons.route,
                        '${_totalDistance.toStringAsFixed(1)} km',
                        'Distancia',
                      ),
                      _buildStatItem(
                        Icons.person,
                        _favoriteDriverCount.toString(),
                        'Conductores',
                      ),
                    ],
                  ),
                  if (_mostVisitedPlace.isNotEmpty) ...[
                    AppSpacing.verticalSpaceMD,
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.favorite, color: Colors.white, size: 20),
                          AppSpacing.horizontalSpaceSM,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Destino Favorito',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _mostVisitedPlace,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                ),
              ),
            )),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        AppSpacing.verticalSpaceXS,
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTripsList(List<Map<String, dynamic>> trips) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 80,
              color: ModernTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay viajes en esta categoría',
              style: TextStyle(
                fontSize: 18,
                color: ModernTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.verticalSpaceXS,
            Text(
              'Tus viajes aparecerán aquí',
              style: TextStyle(
                fontSize: 14,
                color: ModernTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: AppSpacing.all(AppSpacing.md),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return _buildTripCard(trip, index);
      },
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip, int index) {
    final timestamp = trip['requestedAt'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();
    final status = trip['status'] ?? 'unknown';
    final fare = (trip['finalFare'] ?? trip['estimatedFare'] ?? 0.0).toDouble();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = Tween<double>(
          begin: 0,
          end: 1,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              delay.clamp(0.0, 1.0),
              (delay + 0.5).clamp(0.0, 1.0),
              curve: Curves.easeOutBack,
            ),
          ),
        );

        return Transform.translate(
          offset: Offset(50 * (1 - animation.value), 0),
          child: Opacity(
            opacity: animation.value,
            child: Container(
              margin: EdgeInsets.only(bottom: AppSpacing.md),
              child: OasisCard.elevated(
                child: InkWell(
                  onTap: () => _showTripDetails(trip),
                  borderRadius: AppSpacing.borderRadiusLG,
                  child: Padding(
                    padding: AppSpacing.all(AppSpacing.md),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con fecha y estado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy').format(date),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                DateFormat('HH:mm').format(date),
                                style: TextStyle(
                                  color: ModernTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(status),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getStatusText(status),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      AppSpacing.verticalSpaceMD,

                      // Ruta
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: ModernTheme.oasisGreen,
                                ),
                                Container(
                                  width: 2,
                                  height: 30,
                                  color: ModernTheme.textSecondary
                                      .withValues(alpha: 0.3),
                                ),
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: ModernTheme.error,
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.horizontalSpaceSM,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip['pickupAddress'] ?? 'Origen',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  trip['dropoffAddress'] ?? 'Destino',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      AppSpacing.verticalSpaceMD,

                      // Footer con precio y calificación
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 20,
                                color: ModernTheme.oasisGreen,
                              ),
                              Text(
                                'S/ ${fare.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ModernTheme.oasisGreen,
                                ),
                              ),
                            ],
                          ),
                          if (status == 'completed' &&
                              trip['passengerRating'] != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 18,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  trip['passengerRating'].toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          if (status == 'completed' &&
                              trip['passengerRating'] == null)
                            TextButton.icon(
                              onPressed: () => _rateTrip(trip),
                              icon: Icon(Icons.star_border, size: 18),
                              label: Text('Calificar'),
                              style: TextButton.styleFrom(
                                foregroundColor: ModernTheme.oasisGreen,
                              ),
                            ),
                        ],
                      ),

                      // Información del conductor si existe
                      if (trip['driverName'] != null) ...[
                        Divider(height: 24),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  ModernTheme.oasisGreen.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.person,
                                size: 18,
                                color: ModernTheme.oasisGreen,
                              ),
                            ),
                            AppSpacing.horizontalSpaceSM,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip['driverName'] ?? 'Conductor',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (trip['vehicleInfo'] != null)
                                    Text(
                                      '${trip['vehicleInfo']['brand'] ?? ''} ${trip['vehicleInfo']['model'] ?? ''} - ${trip['vehicleInfo']['plate'] ?? ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ModernTheme.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    ),
                  ),
                ),
              ),
            ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return ModernTheme.success;
      case 'cancelled':
      case 'cancelled_by_passenger':
      case 'cancelled_by_driver':
        return ModernTheme.error;
      case 'requested':
      case 'accepted':
      case 'on_the_way':
      case 'arrived':
      case 'in_progress':
        return ModernTheme.warning;
      default:
        return ModernTheme.textSecondary;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      case 'cancelled_by_passenger':
        return 'Cancelado por ti';
      case 'cancelled_by_driver':
        return 'Cancelado por conductor';
      case 'requested':
        return 'Solicitado';
      case 'accepted':
        return 'Aceptado';
      case 'on_the_way':
        return 'En camino';
      case 'arrived':
        return 'Conductor llegó';
      case 'in_progress':
        return 'En progreso';
      default:
        return 'Desconocido';
    }
  }

  void _showTripDetails(Map<String, dynamic> trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TripDetailsModal(trip: trip),
    );
  }

  void _rateTrip(Map<String, dynamic> trip) {
    // Implementar diálogo de calificación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Función de calificación en desarrollo'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
}

// Modal de detalles del viaje
class TripDetailsModal extends StatelessWidget {
  final Map<String, dynamic> trip;

  const TripDetailsModal({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final timestamp = trip['requestedAt'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();
    final fare = (trip['finalFare'] ?? trip['estimatedFare'] ?? 0.0).toDouble();
    final distance = (trip['estimatedDistance'] ?? 0.0).toDouble();
    final duration = trip['estimatedDuration'] ?? 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detalles del Viaje',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del viaje
                  _buildDetailSection(
                    'Información del Viaje',
                    [
                      _buildDetailRow(Icons.calendar_today, 'Fecha',
                          DateFormat('dd/MM/yyyy').format(date)),
                      _buildDetailRow(Icons.access_time, 'Hora',
                          DateFormat('HH:mm').format(date)),
                      _buildDetailRow(
                          Icons.tag, 'ID del viaje', trip['id'] ?? 'N/A'),
                      _buildDetailRow(Icons.info, 'Estado',
                          _getStatusText(trip['status'] ?? 'unknown')),
                    ],
                  ),

                  AppSpacing.verticalSpaceLG,

                  // Ruta
                  _buildDetailSection(
                    'Ruta del Viaje',
                    [
                      _buildDetailRow(Icons.trip_origin, 'Origen',
                          trip['pickupAddress'] ?? 'No especificado'),
                      _buildDetailRow(Icons.location_on, 'Destino',
                          trip['dropoffAddress'] ?? 'No especificado'),
                      _buildDetailRow(Icons.route, 'Distancia',
                          '${distance.toStringAsFixed(2)} km'),
                      _buildDetailRow(Icons.timer, 'Duración estimada',
                          '$duration minutos'),
                    ],
                  ),

                  AppSpacing.verticalSpaceLG,

                  // Información de pago
                  _buildDetailSection(
                    'Información de Pago',
                    [
                      _buildDetailRow(Icons.attach_money, 'Tarifa',
                          'S/ ${fare.toStringAsFixed(2)}'),
                      _buildDetailRow(Icons.payment, 'Método de pago',
                          trip['paymentMethod'] ?? 'Efectivo'),
                      if (trip['discount'] != null && trip['discount'] > 0)
                        _buildDetailRow(Icons.local_offer, 'Descuento',
                            'S/ ${trip['discount'].toStringAsFixed(2)}'),
                    ],
                  ),

                  // Información del conductor
                  if (trip['driverName'] != null) ...[
                    AppSpacing.verticalSpaceLG,
                    _buildDetailSection(
                      'Información del Conductor',
                      [
                        _buildDetailRow(Icons.person, 'Nombre',
                            trip['driverName'] ?? 'No disponible'),
                        if (trip['driverRating'] != null)
                          _buildDetailRow(Icons.star, 'Calificación',
                              '${trip['driverRating']} ⭐'),
                        if (trip['vehicleInfo'] != null) ...[
                          _buildDetailRow(Icons.directions_car, 'Vehículo',
                              '${trip['vehicleInfo']['brand'] ?? ''} ${trip['vehicleInfo']['model'] ?? ''}'),
                          _buildDetailRow(Icons.pin, 'Placa',
                              trip['vehicleInfo']['plate'] ?? 'N/A'),
                        ],
                      ],
                    ),
                  ],

                  // Calificación del pasajero
                  if (trip['passengerRating'] != null) ...[
                    AppSpacing.verticalSpaceLG,
                    _buildDetailSection(
                      'Tu Calificación',
                      [
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text(
                              '${trip['passengerRating']} estrellas',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (trip['passengerComment'] != null)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              trip['passengerComment'],
                              style: TextStyle(
                                fontSize: 14,
                                color: ModernTheme.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  AppSpacing.verticalSpaceXL,

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OasisButton.primary(
                          text: 'Repetir viaje',
                          icon: Icons.refresh,
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Función en desarrollo'),
                                backgroundColor: ModernTheme.info,
                              ),
                            );
                          },
                        ),
                      ),
                      AppSpacing.horizontalSpaceSM,
                      Expanded(
                        child: OasisButton.outlined(
                          text: 'Ver recibo',
                          icon: Icons.receipt,
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Función en desarrollo'),
                                backgroundColor: ModernTheme.info,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        OasisCard.elevated(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ModernTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: ModernTheme.textSecondary),
          ),
          Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      case 'cancelled_by_passenger':
        return 'Cancelado por ti';
      case 'cancelled_by_driver':
        return 'Cancelado por conductor';
      case 'requested':
        return 'Solicitado';
      case 'accepted':
        return 'Aceptado';
      case 'on_the_way':
        return 'En camino';
      case 'arrived':
        return 'Conductor llegó';
      case 'in_progress':
        return 'En progreso';
      default:
        return 'Desconocido';
    }
  }
}

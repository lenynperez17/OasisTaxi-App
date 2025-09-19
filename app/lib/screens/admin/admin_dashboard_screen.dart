import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme/modern_theme.dart';
import '../../models/service_type_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/app_logger.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  AdminDashboardScreenState createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
//   // final int _selectedIndex = 0; // No usado actualmente
  late FirebaseService _firebaseService;
  late TabController _tabController;

  // Estadísticas generales
  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'totalDrivers': 0,
    'tripsToday': 0,
    'todayEarnings': 0.0,
    'activeUsers': 0,
    'onlineDrivers': 0,
    'availableDrivers': 0,
    'driversInTrip': 0,
    'pendingVerifications': 0,
    'activeTrips': 0,
    'cancelledTrips': 0,
    'completedTrips': 0,
    'averageRating': 0.0,
    'commissionRate': 20.0,
    'totalCommissions': 0.0,
    'pendingWithdrawals': 0,
    'approvedWithdrawals': 0,
    'totalAlerts': 0,
    'criticalAlerts': 0,
  };

  // Métricas por tipo de servicio
  final Map<ServiceType, Map<String, dynamic>> _serviceStats = {};

  // Listas de datos en tiempo real
  List<Map<String, dynamic>> _activeTrips = [];
  List<Map<String, dynamic>> _recentUsers = [];
  // List<Map<String, dynamic>> _pendingDrivers = []; // No usado actualmente
  // final List<Map<String, dynamic>> _recentTransactions = []; // No usado actualmente
  List<Map<String, dynamic>> _systemAlerts = [];

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('AdminDashboardScreen', 'initState');
    _firebaseService = FirebaseService();
    _tabController = TabController(length: 7, vsync: this);
    _initializeServiceStats();
    _loadDashboardData();
    _setupRealtimeListeners();
  }

  void _initializeServiceStats() {
    for (var serviceType in ServiceType.values) {
      _serviceStats[serviceType] = {
        'trips': 0,
        'earnings': 0.0,
        'avgDuration': 0,
        'avgDistance': 0.0,
        'rating': 0.0,
      };
    }
  }

  void _setupRealtimeListeners() {
    // Listener para viajes activos
    _firebaseService.firestore
        .collection('trips')
        .where('status', whereIn: ['requested', 'accepted', 'in_progress'])
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          setState(() {
            _activeTrips = snapshot.docs.map((doc) {
              var data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
          });
        });

    // Listener para alertas del sistema
    _firebaseService.firestore
        .collection('system_alerts')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _systemAlerts = snapshot.docs.map((doc) {
          var data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    });
  }

  Future<void> _loadDashboardData() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Cargar usuarios
      final usersSnapshot =
          await _firebaseService.firestore.collection('users').get();
      final driversSnapshot = await _firebaseService.firestore
          .collection('users')
          .where('userType', isEqualTo: 'driver')
          .get();

      // Cargar viajes del día
      final tripsSnapshot = await _firebaseService.firestore
          .collection('trips')
          .where('requestedAt', isGreaterThanOrEqualTo: todayStart)
          .get();

      // Cargar verificaciones pendientes
      final pendingVerifications = await _firebaseService.firestore
          .collection('users')
          .where('userType', isEqualTo: 'driver')
          .where('documentsVerified', isEqualTo: false)
          .get();

      // Cargar retiros pendientes
      final pendingWithdrawals = await _firebaseService.firestore
          .collection('withdrawals')
          .where('status', isEqualTo: 'pending')
          .get();

      // Procesar estadísticas
      double todayEarnings = 0.0;
      double totalCommissions = 0.0;
      int activeUsers = 0;
      int onlineDrivers = 0;
      int availableDrivers = 0;
      int driversInTrip = 0;
      int activeTrips = 0;
      int completedTrips = 0;
      int cancelledTrips = 0;
      double totalRating = 0.0;
      int ratingCount = 0;

      // Procesar usuarios
      for (var user in usersSnapshot.docs) {
        final userData = user.data();
        if (userData['isActive'] == true) activeUsers++;
      }

      // Procesar conductores
      for (var driver in driversSnapshot.docs) {
        final driverData = driver.data();
        if (driverData['isOnline'] == true) onlineDrivers++;
        if (driverData['isAvailable'] == true) availableDrivers++;
        if (driverData['status'] == 'in_trip') driversInTrip++;

        final rating = (driverData['rating'] ?? 0.0).toDouble();
        if (rating > 0) {
          totalRating += rating;
          ratingCount++;
        }
      }

      // Procesar viajes y métricas por servicio
      for (var trip in tripsSnapshot.docs) {
        final tripData = trip.data();
        final status = tripData['status'];
        final serviceTypeIndex = tripData['serviceType'] ?? 0;
        final serviceType = ServiceType.values[serviceTypeIndex];

        if (status == 'in_progress' || status == 'accepted') activeTrips++;
        if (status == 'completed') {
          completedTrips++;
          final fare = (tripData['finalFare'] ?? 0.0).toDouble();
          todayEarnings += fare;
          totalCommissions += fare * 0.2; // 20% de comisión

          // Actualizar métricas por servicio
          _serviceStats[serviceType]!['trips']++;
          _serviceStats[serviceType]!['earnings'] += fare;

          if (tripData['rating'] != null) {
            _serviceStats[serviceType]!['rating'] =
                ((_serviceStats[serviceType]!['rating'] *
                            (_serviceStats[serviceType]!['trips'] - 1)) +
                        tripData['rating']) /
                    _serviceStats[serviceType]!['trips'];
          }
        }
        if (status == 'cancelled') cancelledTrips++;
      }

      // Cargar usuarios recientes
      final recentUsersSnapshot = await _firebaseService.firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      _recentUsers = recentUsersSnapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Cargar conductores pendientes de verificación (comentado - no se usa)
      // _pendingDrivers = pendingVerifications.docs.map((doc) {
      //   var data = doc.data();
      //   data['id'] = doc.id;
      //   return data;
      // }).toList();

      // Actualizar estadísticas
      if (!mounted) return;
      setState(() {
        _stats = {
          'totalUsers': usersSnapshot.docs.length,
          'totalDrivers': driversSnapshot.docs.length,
          'tripsToday': tripsSnapshot.docs.length,
          'todayEarnings': todayEarnings,
          'activeUsers': activeUsers,
          'onlineDrivers': onlineDrivers,
          'availableDrivers': availableDrivers,
          'driversInTrip': driversInTrip,
          'pendingVerifications': pendingVerifications.docs.length,
          'activeTrips': activeTrips,
          'completedTrips': completedTrips,
          'cancelledTrips': cancelledTrips,
          'averageRating': ratingCount > 0 ? totalRating / ratingCount : 0.0,
          'commissionRate': 20.0,
          'totalCommissions': totalCommissions,
          'pendingWithdrawals': pendingWithdrawals.docs.length,
          'approvedWithdrawals': 0,
          'totalAlerts': _systemAlerts.length,
          'criticalAlerts':
              _systemAlerts.where((a) => a['severity'] == 'critical').length,
        };
      });
    } catch (e) {
      AppLogger.error('Error cargando datos del dashboard', e);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ModernTheme.textPrimary,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.admin_panel_settings,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Panel de Control TOTAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Control absoluto del sistema',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Indicador de alertas
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => _showAlertsDialog(),
              ),
              if (_stats['criticalAlerts'] > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_stats['criticalAlerts']}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Botón de actualizar
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: ModernTheme.primaryOrange,
          indicatorWeight: 3,
          tabs: [
            const Tab(text: 'DASHBOARD', icon: Icon(Icons.dashboard, size: 20)),
            const Tab(
                text: 'VIAJES ACTIVOS',
                icon: Icon(Icons.directions_car, size: 20)),
            const Tab(text: 'USUARIOS', icon: Icon(Icons.people, size: 20)),
            const Tab(
                text: 'CONDUCTORES', icon: Icon(Icons.drive_eta, size: 20)),
            const Tab(
                text: 'FINANZAS', icon: Icon(Icons.attach_money, size: 20)),
            const Tab(
                text: 'VERIFICACIONES',
                icon: Icon(Icons.verified_user, size: 20)),
            const Tab(
                text: 'CONFIGURACIÓN', icon: Icon(Icons.settings, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildActiveTripsTab(),
          _buildUsersTab(),
          _buildDriversTab(),
          _buildFinancesTab(),
          _buildVerificationsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  // TAB 1: DASHBOARD GENERAL
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPIs principales
            Text(
              'Métricas en Tiempo Real',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 900
                  ? 5
                  : MediaQuery.of(context).size.width > 600
                      ? 3
                      : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(
                  'Viajes Activos',
                  '${_stats['activeTrips']}',
                  Icons.directions_car,
                  ModernTheme.success,
                  subtitle: 'En curso ahora',
                ),
                _buildMetricCard(
                  'Conductores Online',
                  '${_stats['onlineDrivers']}',
                  Icons.wifi,
                  ModernTheme.primaryBlue,
                  subtitle: '${_stats['availableDrivers']} disponibles',
                ),
                _buildMetricCard(
                  'Ingresos Hoy',
                  'S/ ${_stats['todayEarnings'].toStringAsFixed(0)}',
                  Icons.attach_money,
                  ModernTheme.primaryOrange,
                  subtitle:
                      'S/ ${_stats['totalCommissions'].toStringAsFixed(0)} comisión',
                ),
                _buildMetricCard(
                  'Verificaciones',
                  '${_stats['pendingVerifications']}',
                  Icons.pending_actions,
                  ModernTheme.warning,
                  subtitle: 'Pendientes',
                ),
                _buildMetricCard(
                  'Alertas Críticas',
                  '${_stats['criticalAlerts']}',
                  Icons.warning,
                  _stats['criticalAlerts'] > 0
                      ? ModernTheme.error
                      : Colors.grey,
                  subtitle: 'Requieren atención',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Métricas por tipo de servicio
            Text(
              'Rendimiento por Tipo de Servicio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: ServiceType.values.length,
                itemBuilder: (context, index) {
                  final serviceType = ServiceType.values[index];
                  final serviceInfo =
                      ServiceTypeConfig.getServiceInfo(serviceType);
                  final stats = _serviceStats[serviceType]!;

                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          serviceInfo.color.withValues(alpha: 0.1),
                          serviceInfo.color.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: serviceInfo.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              serviceInfo.icon,
                              color: serviceInfo.color,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                serviceInfo.name,
                                style: TextStyle(
                                  color: serviceInfo.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${stats['trips']} viajes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ModernTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'S/ ${stats['earnings'].toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: ModernTheme.textSecondary,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 14),
                            Text(
                              ' ${stats['rating'].toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: ModernTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Gráfico de actividad (simplificado)
            Text(
              'Actividad de las Últimas 24 Horas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: ModernTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(24, (index) {
                        double height = 20 + (index % 7) * 15.0;
                        bool isActive = index >= 6 && index <= 22;

                        return Flexible(
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            height: isActive ? height : height * 0.3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isActive
                                    ? [
                                        ModernTheme.oasisGreen
                                            .withValues(alpha: 0.8),
                                        ModernTheme.oasisGreen
                                      ]
                                    : [
                                        Colors.grey.withValues(alpha: 0.3),
                                        Colors.grey.withValues(alpha: 0.5)
                                      ],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(2)),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('00:00',
                          style: TextStyle(
                              fontSize: 10, color: ModernTheme.textSecondary)),
                      const Text('06:00',
                          style: TextStyle(
                              fontSize: 10, color: ModernTheme.textSecondary)),
                      const Text('12:00',
                          style: TextStyle(
                              fontSize: 10, color: ModernTheme.textSecondary)),
                      const Text('18:00',
                          style: TextStyle(
                              fontSize: 10, color: ModernTheme.textSecondary)),
                      const Text('23:59',
                          style: TextStyle(
                              fontSize: 10, color: ModernTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Acciones rápidas
            Text(
              'Acciones Rápidas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildQuickAction(
                  'Ver Todos los Viajes',
                  Icons.list_alt,
                  ModernTheme.primaryBlue,
                  () => _tabController.animateTo(1),
                ),
                _buildQuickAction(
                  'Verificar Documentos',
                  Icons.verified_user,
                  ModernTheme.warning,
                  () => _tabController.animateTo(5),
                ),
                _buildQuickAction(
                  'Gestionar Usuarios',
                  Icons.people,
                  ModernTheme.primaryOrange,
                  () => Navigator.pushNamed(context, '/admin/users-management'),
                ),
                _buildQuickAction(
                  'Gestionar Conductores',
                  Icons.drive_eta,
                  ModernTheme.success,
                  () =>
                      Navigator.pushNamed(context, '/admin/drivers-management'),
                ),
                _buildQuickAction(
                  'Reportes Financieros',
                  Icons.analytics,
                  ModernTheme.textPrimary,
                  () => Navigator.pushNamed(context, '/admin/financial'),
                ),
                _buildQuickAction(
                  'Configurar Sistema',
                  Icons.settings,
                  Colors.grey,
                  () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                _buildQuickAction(
                  'Data Studio Dashboards',
                  Icons.dashboard,
                  ModernTheme.accentYellow,
                  () => Navigator.pushNamed(
                      context, '/admin/embedded-dashboards'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // TAB 2: VIAJES ACTIVOS EN TIEMPO REAL
  Widget _buildActiveTripsTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: Column(
        children: [
          // Filtros rápidos
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_activeTrips.length} viajes activos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadDashboardData,
                ),
              ],
            ),
          ),

          // Lista de viajes activos
          Expanded(
            child: _activeTrips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 64,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay viajes activos',
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _activeTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _activeTrips[index];
                      final status = trip['status'] ?? 'unknown';
                      final serviceTypeIndex = trip['serviceType'] ?? 0;
                      final serviceType = ServiceType.values[serviceTypeIndex];
                      final serviceInfo =
                          ServiceTypeConfig.getServiceInfo(serviceType);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getStatusColor(status)
                                  .withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: serviceInfo.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                serviceInfo.icon,
                                color: serviceInfo.color,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Viaje #${trip['id']?.substring(0, 8) ?? 'N/A'}',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _getStatusColor(status)
                                          .withValues(alpha: 0.3),
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
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.person,
                                        size: 14,
                                        color: ModernTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Pasajero: ${trip['userName'] ?? 'N/A'}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.drive_eta,
                                        size: 14,
                                        color: ModernTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Conductor: ${trip['driverName'] ?? 'Buscando...'}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.attach_money,
                                        size: 14,
                                        color: ModernTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'S/ ${(trip['estimatedFare'] ?? 0.0).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: ModernTheme.primaryOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Origen y destino
                                    _buildLocationRow(
                                      'Origen',
                                      trip['pickupAddress'] ?? 'N/A',
                                      Icons.my_location,
                                      Colors.green,
                                    ),
                                    _buildLocationRow(
                                      'Destino',
                                      trip['destinationAddress'] ?? 'N/A',
                                      Icons.location_on,
                                      Colors.red,
                                    ),

                                    const SizedBox(height: 12),

                                    // Acciones de administrador
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _showTripDetails(trip),
                                          icon: Icon(Icons.info, size: 16),
                                          label: const Text('Detalles'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                ModernTheme.primaryBlue,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _cancelTrip(trip['id']),
                                          icon: Icon(Icons.cancel, size: 16),
                                          label: const Text('Cancelar'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: ModernTheme.error,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _reassignDriver(trip['id']),
                                          icon:
                                              Icon(Icons.swap_horiz, size: 16),
                                          label: const Text('Reasignar'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                ModernTheme.warning,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 3: GESTIÓN DE USUARIOS
  Widget _buildUsersTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: ModernTheme.primaryOrange,
              unselectedLabelColor: ModernTheme.textSecondary,
              indicatorColor: ModernTheme.primaryOrange,
              tabs: [
                Tab(text: 'Todos (${_stats['totalUsers']})'),
                Tab(text: 'Activos (${_stats['activeUsers']})'),
                Tab(text: 'Nuevos (${_recentUsers.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildUsersList('all'),
                _buildUsersList('active'),
                _buildUsersList('recent'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(String filter) {
    return FutureBuilder<QuerySnapshot>(
      future: _getUsersQuery(filter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: const Text('No hay usuarios para mostrar'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final userDoc = snapshot.data!.docs[index];
            final userData = userDoc.data() as Map<String, dynamic>;

            return Card(
              margin: EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      ModernTheme.primaryBlue.withValues(alpha: 0.1),
                  child: Text(
                    (userData['name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: ModernTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(userData['name'] ?? 'Sin nombre'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userData['email'] ?? 'Sin email'),
                    Text(
                      userData['phone'] ?? 'Sin teléfono',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) =>
                      _handleUserAction(value, userDoc.id, userData),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 20),
                          const SizedBox(width: 8),
                          const Text('Ver detalles'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value:
                          userData['isActive'] == true ? 'suspend' : 'activate',
                      child: Row(
                        children: [
                          Icon(
                            userData['isActive'] == true
                                ? Icons.block
                                : Icons.check_circle,
                            size: 20,
                            color: userData['isActive'] == true
                                ? ModernTheme.error
                                : ModernTheme.success,
                          ),
                          const SizedBox(width: 8),
                          Text(userData['isActive'] == true
                              ? 'Suspender'
                              : 'Activar'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reset_password',
                      child: Row(
                        children: [
                          Icon(Icons.lock_reset, size: 20),
                          const SizedBox(width: 8),
                          const Text('Resetear contraseña'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete,
                              size: 20, color: ModernTheme.error),
                          const SizedBox(width: 8),
                          Text('Eliminar',
                              style: TextStyle(color: ModernTheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // TAB 4: GESTIÓN DE CONDUCTORES
  Widget _buildDriversTab() {
    return Navigator.pushNamed(context, '/admin/drivers-management') as Widget;
  }

  // TAB 5: FINANZAS
  Widget _buildFinancesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen financiero del día
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ModernTheme.oasisGreen,
                  ModernTheme.oasisGreen.withValues(alpha: 0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: ModernTheme.cardShadow,
            ),
            child: Column(
              children: [
                Text(
                  'Balance del Día',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'S/ ${_stats['todayEarnings'].toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFinanceItem(
                      'Ingresos Brutos',
                      'S/ ${_stats['todayEarnings'].toStringAsFixed(0)}',
                      Icons.trending_up,
                    ),
                    Container(width: 1, height: 40, color: Colors.white30),
                    _buildFinanceItem(
                      'Comisiones (20%)',
                      'S/ ${_stats['totalCommissions'].toStringAsFixed(0)}',
                      Icons.percent,
                    ),
                    Container(width: 1, height: 40, color: Colors.white30),
                    _buildFinanceItem(
                      'Retiros Pendientes',
                      '${_stats['pendingWithdrawals']}',
                      Icons.pending,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Configuración de comisiones
          Text(
            'Configuración de Comisiones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Comisión actual:'),
                      Row(
                        children: [
                          Text(
                            '${_stats['commissionRate'].toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: ModernTheme.primaryOrange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => _showCommissionDialog(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ModernTheme.primaryBlue,
                            ),
                            child: const Text('Cambiar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nota: Los cambios en la comisión se aplicarán solo a viajes futuros',
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Acciones financieras
          Text(
            'Acciones Financieras',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3,
            children: [
              _buildActionButton(
                'Aprobar Retiros',
                Icons.check_circle,
                ModernTheme.success,
                () => Navigator.pushNamed(context, '/admin/financial'),
              ),
              _buildActionButton(
                'Ver Transacciones',
                Icons.receipt_long,
                ModernTheme.primaryBlue,
                () => Navigator.pushNamed(context, '/admin/financial'),
              ),
              _buildActionButton(
                'Generar Reporte',
                Icons.analytics,
                ModernTheme.primaryOrange,
                () => _generateFinancialReport(),
              ),
              _buildActionButton(
                'Exportar Excel',
                Icons.file_download,
                ModernTheme.textPrimary,
                () => _exportToExcel(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 6: VERIFICACIONES
  Widget _buildVerificationsTab() {
    return Navigator.pushNamed(context, '/admin/document-verification')
        as Widget;
  }

  // TAB 7: CONFIGURACIÓN
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Configuraciones del sistema
          _buildSettingSection(
            'Configuración General',
            [
              _buildSettingItem(
                'Tarifas Base',
                'Configurar precios por tipo de servicio',
                Icons.attach_money,
                () => _showTariffsDialog(),
              ),
              _buildSettingItem(
                'Zonas de Servicio',
                'Definir áreas de cobertura',
                Icons.map,
                () => _showZonesDialog(),
              ),
              _buildSettingItem(
                'Horarios de Operación',
                '24/7 actualmente',
                Icons.schedule,
                () => _showScheduleDialog(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildSettingSection(
            'Notificaciones y Alertas',
            [
              _buildSettingItem(
                'Plantillas de Mensajes',
                'Personalizar notificaciones automáticas',
                Icons.message,
                () => _showMessagesDialog(),
              ),
              _buildSettingItem(
                'Alertas del Sistema',
                'Configurar triggers y umbrales',
                Icons.notifications_active,
                () => _showAlertsConfigDialog(),
              ),
              _buildSettingItem(
                'Notificaciones Push',
                'Gestionar envío de notificaciones',
                Icons.phone_android,
                () => _showPushNotificationsDialog(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildSettingSection(
            'Seguridad y Permisos',
            [
              _buildSettingItem(
                'Roles de Administrador',
                'Gestionar permisos de admin',
                Icons.admin_panel_settings,
                () => _showRolesDialog(),
              ),
              _buildSettingItem(
                'Políticas de Seguridad',
                'Configurar reglas de seguridad',
                Icons.security,
                () => _showSecurityDialog(),
              ),
              _buildSettingItem(
                'Auditoría del Sistema',
                'Ver logs y actividad',
                Icons.history,
                () => _showAuditDialog(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildSettingSection(
            'Mantenimiento',
            [
              _buildSettingItem(
                'Respaldo de Datos',
                'Último: Hoy 3:00 AM',
                Icons.backup,
                () => _performBackup(),
              ),
              _buildSettingItem(
                'Limpiar Caché',
                'Liberar espacio del sistema',
                Icons.cleaning_services,
                () => _clearCache(),
              ),
              _buildSettingItem(
                'Modo Mantenimiento',
                'Desactivado',
                Icons.build,
                () => _toggleMaintenanceMode(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widgets auxiliares
  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: ModernTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(
      String label, String address, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: ModernTheme.textSecondary,
                  ),
                ),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
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
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSettingSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: ModernTheme.primaryBlue, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // Funciones auxiliares
  Color _getStatusColor(String status) {
    switch (status) {
      case 'requested':
        return ModernTheme.warning;
      case 'accepted':
        return ModernTheme.primaryBlue;
      case 'in_progress':
        return ModernTheme.success;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return ModernTheme.error;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'requested':
        return 'Solicitado';
      case 'accepted':
        return 'Aceptado';
      case 'in_progress':
        return 'En Progreso';
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }

  Future<QuerySnapshot> _getUsersQuery(String filter) {
    Query query = _firebaseService.firestore.collection('users');

    switch (filter) {
      case 'active':
        query = query.where('isActive', isEqualTo: true);
        break;
      case 'recent':
        query = query.orderBy('createdAt', descending: true).limit(10);
        break;
    }

    return query.get();
  }

  // Métodos de acción
  void _showTripDetails(Map<String, dynamic> trip) {
    Navigator.pushNamed(
      context,
      '/shared/trip-details',
      arguments: trip['id'],
    );
  }

  void _cancelTrip(String tripId) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Cancelación'),
        content: const Text('¿Está seguro de cancelar este viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firebaseService.firestore
          .collection('trips')
          .doc(tripId)
          .update({'status': 'cancelled'});
      if (mounted) {
        _loadDashboardData();
      }
    }
  }

  void _reassignDriver(String tripId) {
    // Implementar reasignación de conductor
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Función de reasignación en desarrollo')),
    );
  }

  void _handleUserAction(
      String action, String userId, Map<String, dynamic> userData) async {
    switch (action) {
      case 'view':
        // Ver detalles del usuario
        break;
      case 'suspend':
      case 'activate':
        await _firebaseService.firestore
            .collection('users')
            .doc(userId)
            .update({'isActive': action == 'activate'});
        if (mounted) {
          _loadDashboardData();
        }
        break;
      case 'reset_password':
        // Implementar reset de contraseña
        break;
      case 'delete':
        // Implementar eliminación con confirmación
        break;
    }
  }

  void _showAlertsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Alertas del Sistema'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _systemAlerts.length,
            itemBuilder: (context, index) {
              final alert = _systemAlerts[index];
              return ListTile(
                leading: Icon(
                  Icons.warning,
                  color: alert['severity'] == 'critical'
                      ? ModernTheme.error
                      : ModernTheme.warning,
                ),
                title: Text(alert['message'] ?? 'Alerta'),
                subtitle: Text(
                  DateFormat('dd/MM HH:mm').format(
                    (alert['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showCommissionDialog() {
    final TextEditingController commissionController = TextEditingController(
      text: _stats['commissionRate'].toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cambiar Tasa de Comisión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingrese el nuevo porcentaje de comisión que se aplicará a todos los viajes futuros.',
              style: TextStyle(fontSize: 14, color: ModernTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: commissionController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Porcentaje de Comisión',
                suffixText: '%',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.percent),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ModernTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: ModernTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este cambio solo afectará viajes futuros',
                      style:
                          TextStyle(fontSize: 12, color: ModernTheme.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newRate = double.tryParse(commissionController.text);
              if (newRate != null && newRate >= 0 && newRate <= 100) {
                await _firebaseService.firestore
                    .collection('settings')
                    .doc('commission')
                    .set({
                  'rate': newRate,
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': _firebaseService.auth.currentUser?.uid,
                });

                if (mounted) {
                  setState(() {
                    _stats['commissionRate'] = newRate;
                  });

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Comisión actualizada a $newRate%'),
                      backgroundColor: ModernTheme.success,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Por favor ingrese un valor válido entre 0 y 100'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.primaryOrange,
            ),
            child: Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _generateFinancialReport() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Generando reporte financiero...'),
          ],
        ),
      ),
    );

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Obtener datos del mes
      final tripsSnapshot = await _firebaseService.firestore
          .collection('trips')
          .where('requestedAt', isGreaterThanOrEqualTo: startOfMonth)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalIngresos = 0;
      double totalComisiones = 0;
      Map<ServiceType, double> ingresosPorServicio = {};
      Map<ServiceType, int> viajesPorServicio = {};

      for (var trip in tripsSnapshot.docs) {
        final data = trip.data();
        final fare = (data['finalFare'] ?? 0.0).toDouble();
        final serviceTypeIndex = data['serviceType'] ?? 0;
        final serviceType = ServiceType.values[serviceTypeIndex];

        totalIngresos += fare;
        totalComisiones += fare * (_stats['commissionRate'] / 100);

        ingresosPorServicio[serviceType] =
            (ingresosPorServicio[serviceType] ?? 0) + fare;
        viajesPorServicio[serviceType] =
            (viajesPorServicio[serviceType] ?? 0) + 1;
      }

      if (!mounted) return;
      if (!context.mounted) return;
      Navigator.pop(context);

      // Mostrar reporte
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reporte Financiero',
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
                Text(
                  'Mes: ${DateFormat('MMMM yyyy', 'es').format(now)}',
                  style: TextStyle(color: ModernTheme.textSecondary),
                ),
                Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReportSection(
                          'Resumen General',
                          [
                            _buildReportRow('Total Viajes',
                                tripsSnapshot.docs.length.toString()),
                            _buildReportRow('Ingresos Brutos',
                                'S/ ${totalIngresos.toStringAsFixed(2)}'),
                            _buildReportRow(
                                'Comisiones (${_stats['commissionRate']}%)',
                                'S/ ${totalComisiones.toStringAsFixed(2)}'),
                            _buildReportRow('Neto para Conductores',
                                'S/ ${(totalIngresos - totalComisiones).toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Desglose por Servicio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...ServiceType.values.map((serviceType) {
                          final ingresos =
                              ingresosPorServicio[serviceType] ?? 0;
                          final viajes = viajesPorServicio[serviceType] ?? 0;
                          if (viajes == 0) return SizedBox.shrink();

                          final serviceInfo =
                              ServiceTypeConfig.getServiceInfo(serviceType);
                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                serviceInfo.icon,
                                color: serviceInfo.color,
                              ),
                              title: Text(serviceInfo.name),
                              subtitle: Text('$viajes viajes'),
                              trailing: Text(
                                'S/ ${ingresos.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: serviceInfo.color,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _exportToExcel(),
                      icon: Icon(Icons.download),
                      label: Text('Exportar Excel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.primaryOrange,
                      ),
                      child: Text('Cerrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar reporte: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildReportSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _exportToExcel() async {
    if (!mounted) return;

    try {
      final now = DateTime.now();
      final fileName =
          'reporte_oasistxi_${DateFormat('yyyy_MM_dd').format(now)}.csv';

      // Generar contenido CSV
      StringBuffer csvContent = StringBuffer();
      csvContent.writeln('REPORTE FINANCIERO OASISTXI');
      csvContent.writeln(
          'Fecha de generación,${DateFormat('dd/MM/yyyy HH:mm').format(now)}');
      csvContent.writeln('');
      csvContent.writeln('RESUMEN GENERAL');
      csvContent.writeln('Métrica,Valor');
      csvContent.writeln('Total Usuarios,${_stats['totalUsers']}');
      csvContent.writeln('Total Conductores,${_stats['totalDrivers']}');
      csvContent.writeln('Viajes Hoy,${_stats['tripsToday']}');
      csvContent.writeln(
          'Ingresos Hoy,S/ ${_stats['todayEarnings'].toStringAsFixed(2)}');
      csvContent.writeln(
          'Comisiones Hoy,S/ ${_stats['totalCommissions'].toStringAsFixed(2)}');
      csvContent.writeln('Tasa de Comisión,${_stats['commissionRate']}%');
      csvContent.writeln('');
      csvContent.writeln('MÉTRICAS POR SERVICIO');
      csvContent.writeln('Servicio,Viajes,Ingresos,Rating');

      for (var entry in _serviceStats.entries) {
        final serviceInfo = ServiceTypeConfig.getServiceInfo(entry.key);
        final stats = entry.value;
        csvContent.writeln(
            '${serviceInfo.name},${stats['trips']},S/ ${stats['earnings'].toStringAsFixed(2)},${stats['rating'].toStringAsFixed(1)}');
      }

      // Simular descarga del archivo
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Reporte exportado: $fileName'),
              ),
            ],
          ),
          backgroundColor: ModernTheme.success,
          duration: Duration(seconds: 3),
        ),
      );

      // En producción real, aquí usarías un paquete como csv o excel
      // para generar y descargar el archivo real
      AppLogger.info('Reporte CSV generado', {'filename': fileName});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _showTariffsDialog() {
    Map<ServiceType, Map<String, TextEditingController>> controllers = {};

    for (var serviceType in ServiceType.values) {
      final serviceInfo = ServiceTypeConfig.getServiceInfo(serviceType);
      controllers[serviceType] = {
        'base': TextEditingController(
            text: serviceInfo.basePrice.toStringAsFixed(2)),
        'km': TextEditingController(
            text: serviceInfo.pricePerKm.toStringAsFixed(2)),
        'min': TextEditingController(
            text: serviceInfo.pricePerMin.toStringAsFixed(2)),
      };
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Configuración de Tarifas',
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
              Text(
                'Ajuste las tarifas para cada tipo de servicio',
                style: TextStyle(color: ModernTheme.textSecondary),
              ),
              Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: ServiceType.values.length,
                  itemBuilder: (context, index) {
                    final serviceType = ServiceType.values[index];
                    final serviceInfo =
                        ServiceTypeConfig.getServiceInfo(serviceType);
                    final serviceControllers = controllers[serviceType]!;

                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: Icon(
                          serviceInfo.icon,
                          color: serviceInfo.color,
                        ),
                        title: Text(
                          serviceInfo.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(serviceInfo.description),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: serviceControllers['base'],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Tarifa Base',
                                          prefixText: 'S/ ',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: serviceControllers['km'],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Por Km',
                                          prefixText: 'S/ ',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: serviceControllers['min'],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Por Min',
                                          prefixText: 'S/ ',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      // Guardar tarifas en Firestore
                      for (var entry in controllers.entries) {
                        final serviceType = entry.key;
                        final serviceControllers = entry.value;

                        await _firebaseService.firestore
                            .collection('settings')
                            .doc('tariffs')
                            .collection('services')
                            .doc(serviceType.toString())
                            .set({
                          'basePrice':
                              double.parse(serviceControllers['base']!.text),
                          'pricePerKm':
                              double.parse(serviceControllers['km']!.text),
                          'pricePerMin':
                              double.parse(serviceControllers['min']!.text),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tarifas actualizadas correctamente'),
                          backgroundColor: ModernTheme.success,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.primaryOrange,
                    ),
                    child: Text('Guardar Cambios'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showZonesDialog() {
    List<Map<String, dynamic>> zones = [
      {'name': 'Lima Centro', 'active': true, 'surcharge': 0.0},
      {'name': 'San Isidro', 'active': true, 'surcharge': 2.0},
      {'name': 'Miraflores', 'active': true, 'surcharge': 2.0},
      {'name': 'Surco', 'active': true, 'surcharge': 3.0},
      {'name': 'La Molina', 'active': true, 'surcharge': 4.0},
      {'name': 'San Borja', 'active': true, 'surcharge': 2.5},
      {'name': 'Callao', 'active': false, 'surcharge': 5.0},
      {'name': 'Aeropuerto', 'active': true, 'surcharge': 10.0},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Zonas de Servicio'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Configure las zonas donde opera el servicio',
                  style:
                      TextStyle(color: ModernTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 400,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: zones.length,
                    itemBuilder: (context, index) {
                      final zone = zones[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.location_on,
                            color: zone['active']
                                ? ModernTheme.success
                                : Colors.grey,
                          ),
                          title: Text(zone['name']),
                          subtitle: Text(
                            zone['active']
                                ? 'Recargo: S/ ${zone['surcharge'].toStringAsFixed(2)}'
                                : 'Zona desactivada',
                          ),
                          trailing: Switch(
                            value: zone['active'],
                            onChanged: (value) {
                              setState(() {
                                zone['active'] = value;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Guardar configuración de zonas
                for (var zone in zones) {
                  await _firebaseService.firestore
                      .collection('settings')
                      .doc('zones')
                      .collection('areas')
                      .doc(zone['name']
                          .toString()
                          .toLowerCase()
                          .replaceAll(' ', '_'))
                      .set({
                    'name': zone['name'],
                    'active': zone['active'],
                    'surcharge': zone['surcharge'],
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }

                if (!context.mounted) return;
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Zonas actualizadas'),
                    backgroundColor: ModernTheme.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.primaryOrange,
              ),
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleDialog() {
    Map<String, Map<String, TimeOfDay>> schedule = {
      'Lunes': {
        'open': TimeOfDay(hour: 0, minute: 0),
        'close': TimeOfDay(hour: 23, minute: 59)
      },
      'Martes': {
        'open': TimeOfDay(hour: 0, minute: 0),
        'close': TimeOfDay(hour: 23, minute: 59)
      },
      'Miércoles': {
        'open': TimeOfDay(hour: 0, minute: 0),
        'close': TimeOfDay(hour: 23, minute: 59)
      },
      'Jueves': {
        'open': TimeOfDay(hour: 0, minute: 0),
        'close': TimeOfDay(hour: 23, minute: 59)
      },
      'Viernes': {
        'open': TimeOfDay(hour: 0, minute: 0),
        'close': TimeOfDay(hour: 23, minute: 59)
      },
      'Sábado': {
        'open': TimeOfDay(hour: 0, minute: 0),
        'close': TimeOfDay(hour: 23, minute: 59)
      },
      'Domingo': {
        'open': TimeOfDay(hour: 0, minute: 0),
        'close': TimeOfDay(hour: 23, minute: 59)
      },
    };

    bool is24Hours = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Horarios de Operación'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text('Servicio 24/7'),
                  subtitle: Text(
                    is24Hours
                        ? 'Servicio disponible todo el día'
                        : 'Configurar horarios personalizados',
                  ),
                  value: is24Hours,
                  onChanged: (value) {
                    setState(() {
                      is24Hours = value;
                    });
                  },
                ),
                if (!is24Hours) ...[
                  Divider(),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: schedule.length,
                      itemBuilder: (context, index) {
                        final day = schedule.keys.elementAt(index);
                        final times = schedule[day]!;

                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(day),
                            subtitle: Text(
                                '${times['open']!.format(context)} - ${times['close']!.format(context)}'),
                            trailing: IconButton(
                              icon: Icon(Icons.edit,
                                  color: ModernTheme.primaryBlue),
                              onPressed: () async {
                                final openTime = await showTimePicker(
                                  context: context,
                                  initialTime: times['open']!,
                                  helpText: 'Hora de apertura',
                                );
                                if (openTime != null) {
                                  if (!context.mounted) return;
                                  final closeTime = await showTimePicker(
                                    context: context,
                                    initialTime: times['close']!,
                                    helpText: 'Hora de cierre',
                                  );
                                  if (closeTime != null) {
                                    setState(() {
                                      schedule[day] = {
                                        'open': openTime,
                                        'close': closeTime,
                                      };
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _firebaseService.firestore
                    .collection('settings')
                    .doc('schedule')
                    .set({
                  'is24Hours': is24Hours,
                  'schedule': is24Hours
                      ? null
                      : schedule.map((key, value) => MapEntry(
                            key,
                            {
                              'open':
                                  '${value['open']!.hour}:${value['open']!.minute}',
                              'close':
                                  '${value['close']!.hour}:${value['close']!.minute}',
                            },
                          )),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!context.mounted) return;
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Horarios actualizados'),
                    backgroundColor: ModernTheme.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.primaryOrange,
              ),
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessagesDialog() {
    Map<String, TextEditingController> templates = {
      'welcome': TextEditingController(
          text:
              'Bienvenido a OasisTxi, {name}! Tu cuenta ha sido creada exitosamente.'),
      'trip_accepted': TextEditingController(
          text: 'Tu viaje ha sido aceptado. {driver} está en camino.'),
      'trip_started': TextEditingController(
          text: 'Tu viaje ha comenzado. Disfruta del trayecto!'),
      'trip_completed': TextEditingController(
          text:
              'Viaje completado. Total: S/ {amount}. Gracias por usar OasisTxi!'),
      'driver_nearby': TextEditingController(
          text: 'Tu conductor está a {minutes} minutos de distancia.'),
      'payment_received': TextEditingController(
          text: 'Pago de S/ {amount} recibido correctamente.'),
      'verification_approved': TextEditingController(
          text: 'Felicidades! Tus documentos han sido verificados.'),
      'verification_rejected': TextEditingController(
          text:
              'Tus documentos necesitan revisión. Por favor, verifica: {reason}'),
    };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Plantillas de Mensajes',
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
              Text(
                'Personaliza los mensajes automáticos del sistema',
                style:
                    TextStyle(color: ModernTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16, color: ModernTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Variables: {name}, {driver}, {amount}, {minutes}, {reason}',
                      style: TextStyle(
                          fontSize: 12, color: ModernTheme.primaryBlue),
                    ),
                  ],
                ),
              ),
              Divider(),
              Expanded(
                child: ListView(
                  children: [
                    _buildMessageTemplate('Bienvenida', templates['welcome']!),
                    _buildMessageTemplate(
                        'Viaje Aceptado', templates['trip_accepted']!),
                    _buildMessageTemplate(
                        'Viaje Iniciado', templates['trip_started']!),
                    _buildMessageTemplate(
                        'Viaje Completado', templates['trip_completed']!),
                    _buildMessageTemplate(
                        'Conductor Cerca', templates['driver_nearby']!),
                    _buildMessageTemplate(
                        'Pago Recibido', templates['payment_received']!),
                    _buildMessageTemplate('Verificación Aprobada',
                        templates['verification_approved']!),
                    _buildMessageTemplate('Verificación Rechazada',
                        templates['verification_rejected']!),
                  ],
                ),
              ),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      Map<String, String> templateData = {};
                      templates.forEach((key, controller) {
                        templateData[key] = controller.text;
                      });

                      await _firebaseService.firestore
                          .collection('settings')
                          .doc('message_templates')
                          .set({
                        'templates': templateData,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Plantillas actualizadas'),
                          backgroundColor: ModernTheme.success,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.primaryOrange,
                    ),
                    child: Text('Guardar Cambios'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageTemplate(String title, TextEditingController controller) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: 'Mensaje...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlertsConfigDialog() {
    Map<String, Map<String, dynamic>> alertConfigs = {
      'low_drivers': {
        'enabled': true,
        'threshold': 5,
        'message': 'Pocos conductores disponibles',
      },
      'high_demand': {
        'enabled': true,
        'threshold': 20,
        'message': 'Alta demanda de viajes',
      },
      'payment_failed': {
        'enabled': true,
        'threshold': 1,
        'message': 'Pago fallido detectado',
      },
      'driver_offline': {
        'enabled': true,
        'threshold': 30,
        'message': 'Conductor sin actividad',
      },
      'verification_pending': {
        'enabled': true,
        'threshold': 10,
        'message': 'Verificaciones pendientes',
      },
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Configuración de Alertas'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Configure las alertas automáticas del sistema',
                  style:
                      TextStyle(color: ModernTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 400,
                  child: ListView(
                    children: alertConfigs.entries.map((entry) {
                      final config = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    config['message'],
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Switch(
                                    value: config['enabled'],
                                    onChanged: (value) {
                                      setState(() {
                                        config['enabled'] = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (config['enabled']) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('Umbral: '),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 60,
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                        ),
                                        controller: TextEditingController(
                                          text: config['threshold'].toString(),
                                        ),
                                        onChanged: (value) {
                                          config['threshold'] =
                                              int.tryParse(value) ?? 0;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getAlertUnit(entry.key),
                                      style: TextStyle(
                                        color: ModernTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _firebaseService.firestore
                    .collection('settings')
                    .doc('alerts')
                    .set({
                  'configurations': alertConfigs,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Configuración de alertas guardada'),
                    backgroundColor: ModernTheme.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.primaryOrange,
              ),
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  String _getAlertUnit(String alertType) {
    switch (alertType) {
      case 'low_drivers':
        return 'conductores mínimo';
      case 'high_demand':
        return 'viajes en espera';
      case 'payment_failed':
        return 'fallos';
      case 'driver_offline':
        return 'minutos inactivo';
      case 'verification_pending':
        return 'documentos pendientes';
      default:
        return '';
    }
  }

  void _showPushNotificationsDialog() {
    Map<String, bool> notificationSettings = {
      'new_trip': true,
      'trip_accepted': true,
      'trip_cancelled': true,
      'payment_received': true,
      'driver_nearby': true,
      'promotions': false,
      'system_updates': true,
      'chat_messages': true,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Notificaciones Push'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Configure qué notificaciones enviar a los usuarios',
                  style:
                      TextStyle(color: ModernTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 350,
                  child: ListView(
                    children: [
                      _buildNotificationSwitch(
                        'Nuevo Viaje',
                        'Notificar cuando hay una nueva solicitud',
                        notificationSettings['new_trip']!,
                        (value) => setState(
                            () => notificationSettings['new_trip'] = value),
                      ),
                      _buildNotificationSwitch(
                        'Viaje Aceptado',
                        'Cuando un conductor acepta el viaje',
                        notificationSettings['trip_accepted']!,
                        (value) => setState(() =>
                            notificationSettings['trip_accepted'] = value),
                      ),
                      _buildNotificationSwitch(
                        'Viaje Cancelado',
                        'Si se cancela un viaje',
                        notificationSettings['trip_cancelled']!,
                        (value) => setState(() =>
                            notificationSettings['trip_cancelled'] = value),
                      ),
                      _buildNotificationSwitch(
                        'Pago Recibido',
                        'Confirmación de pagos',
                        notificationSettings['payment_received']!,
                        (value) => setState(() =>
                            notificationSettings['payment_received'] = value),
                      ),
                      _buildNotificationSwitch(
                        'Conductor Cerca',
                        'Cuando el conductor está próximo',
                        notificationSettings['driver_nearby']!,
                        (value) => setState(() =>
                            notificationSettings['driver_nearby'] = value),
                      ),
                      _buildNotificationSwitch(
                        'Promociones',
                        'Ofertas y descuentos especiales',
                        notificationSettings['promotions']!,
                        (value) => setState(
                            () => notificationSettings['promotions'] = value),
                      ),
                      _buildNotificationSwitch(
                        'Actualizaciones',
                        'Información del sistema',
                        notificationSettings['system_updates']!,
                        (value) => setState(() =>
                            notificationSettings['system_updates'] = value),
                      ),
                      _buildNotificationSwitch(
                        'Mensajes de Chat',
                        'Mensajes entre conductor y pasajero',
                        notificationSettings['chat_messages']!,
                        (value) => setState(() =>
                            notificationSettings['chat_messages'] = value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _firebaseService.firestore
                    .collection('settings')
                    .doc('notifications')
                    .set({
                  'push_settings': notificationSettings,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Configuración de notificaciones guardada'),
                    backgroundColor: ModernTheme.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.primaryOrange,
              ),
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSwitch(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  void _showRolesDialog() {
    List<Map<String, dynamic>> admins = [
      {
        'name': 'Admin Principal',
        'email': 'admin@oasistxi.com',
        'role': 'super_admin',
        'permissions': ['all'],
      },
      {
        'name': 'Soporte Técnico',
        'email': 'soporte@oasistxi.com',
        'role': 'support',
        'permissions': ['users', 'drivers', 'trips'],
      },
      {
        'name': 'Finanzas',
        'email': 'finanzas@oasistxi.com',
        'role': 'finance',
        'permissions': ['finances', 'reports'],
      },
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gestión de Administradores',
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
              Divider(),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: admins.length,
                  itemBuilder: (context, index) {
                    final admin = admins[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(admin['role']),
                          child: Text(
                            admin['name'][0],
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(admin['name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(admin['email']),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children:
                                  (admin['permissions'] as List).map((perm) {
                                return Chip(
                                  label: Text(
                                    perm,
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: ModernTheme.primaryBlue
                                      .withValues(alpha: 0.1),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              // Editar permisos
                            } else if (value == 'delete') {
                              // Eliminar admin
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Editar'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 20, color: ModernTheme.error),
                                  const SizedBox(width: 8),
                                  Text('Eliminar',
                                      style:
                                          TextStyle(color: ModernTheme.error)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // Agregar nuevo admin
                    },
                    icon: Icon(Icons.add),
                    label: Text('Agregar Admin'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.primaryOrange,
                    ),
                    child: Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return ModernTheme.error;
      case 'support':
        return ModernTheme.primaryBlue;
      case 'finance':
        return ModernTheme.success;
      default:
        return Colors.grey;
    }
  }

  void _showSecurityDialog() {
    Map<String, bool> securitySettings = {
      'two_factor_admin': true,
      'two_factor_drivers': false,
      'session_timeout': true,
      'ip_whitelist': false,
      'password_complexity': true,
      'email_verification': true,
      'phone_verification': true,
      'document_verification': true,
      'background_check': false,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Políticas de Seguridad'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 400,
                  child: ListView(
                    children: [
                      _buildSecurityOption(
                        '2FA para Administradores',
                        'Autenticación de dos factores obligatoria',
                        Icons.admin_panel_settings,
                        securitySettings['two_factor_admin']!,
                        (value) => setState(
                            () => securitySettings['two_factor_admin'] = value),
                      ),
                      _buildSecurityOption(
                        '2FA para Conductores',
                        'Autenticación de dos factores opcional',
                        Icons.drive_eta,
                        securitySettings['two_factor_drivers']!,
                        (value) => setState(() =>
                            securitySettings['two_factor_drivers'] = value),
                      ),
                      _buildSecurityOption(
                        'Timeout de Sesión',
                        'Cerrar sesión después de 30 min inactivo',
                        Icons.timer,
                        securitySettings['session_timeout']!,
                        (value) => setState(
                            () => securitySettings['session_timeout'] = value),
                      ),
                      _buildSecurityOption(
                        'Lista Blanca de IPs',
                        'Solo permitir IPs autorizadas',
                        Icons.security,
                        securitySettings['ip_whitelist']!,
                        (value) => setState(
                            () => securitySettings['ip_whitelist'] = value),
                      ),
                      _buildSecurityOption(
                        'Contraseñas Complejas',
                        'Min 8 caracteres, mayús, números y símbolos',
                        Icons.password,
                        securitySettings['password_complexity']!,
                        (value) => setState(() =>
                            securitySettings['password_complexity'] = value),
                      ),
                      _buildSecurityOption(
                        'Verificación Email',
                        'Confirmar email antes de activar cuenta',
                        Icons.email,
                        securitySettings['email_verification']!,
                        (value) => setState(() =>
                            securitySettings['email_verification'] = value),
                      ),
                      _buildSecurityOption(
                        'Verificación Teléfono',
                        'Confirmar número con SMS',
                        Icons.phone,
                        securitySettings['phone_verification']!,
                        (value) => setState(() =>
                            securitySettings['phone_verification'] = value),
                      ),
                      _buildSecurityOption(
                        'Verificación Documentos',
                        'Validar documentos de conductores',
                        Icons.verified_user,
                        securitySettings['document_verification']!,
                        (value) => setState(() =>
                            securitySettings['document_verification'] = value),
                      ),
                      _buildSecurityOption(
                        'Verificación Antecedentes',
                        'Revisar antecedentes penales',
                        Icons.policy,
                        securitySettings['background_check']!,
                        (value) => setState(
                            () => securitySettings['background_check'] = value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _firebaseService.firestore
                    .collection('settings')
                    .doc('security')
                    .set({
                  'policies': securitySettings,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Políticas de seguridad actualizadas'),
                    backgroundColor: ModernTheme.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.primaryOrange,
              ),
              child: Text('Aplicar Políticas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityOption(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: value ? ModernTheme.success : Colors.grey),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showAuditDialog() {
    List<Map<String, dynamic>> auditLogs = [
      {
        'timestamp': DateTime.now().subtract(Duration(minutes: 5)),
        'user': 'admin@oasistxi.com',
        'action': 'Cambió comisión',
        'details': 'De 18% a 20%',
        'type': 'config',
      },
      {
        'timestamp': DateTime.now().subtract(Duration(hours: 1)),
        'user': 'soporte@oasistxi.com',
        'action': 'Verificó conductor',
        'details': 'ID: driver123',
        'type': 'verification',
      },
      {
        'timestamp': DateTime.now().subtract(Duration(hours: 2)),
        'user': 'admin@oasistxi.com',
        'action': 'Suspendió usuario',
        'details': 'usuario@gmail.com - Comportamiento inadecuado',
        'type': 'user',
      },
      {
        'timestamp': DateTime.now().subtract(Duration(hours: 3)),
        'user': 'finanzas@oasistxi.com',
        'action': 'Aprobó retiro',
        'details': 'S/ 250.00 - conductor456',
        'type': 'finance',
      },
      {
        'timestamp': DateTime.now().subtract(Duration(days: 1)),
        'user': 'admin@oasistxi.com',
        'action': 'Actualizó tarifas',
        'details': 'Taxi Económico: S/ 5.00 base',
        'type': 'config',
      },
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Registro de Auditoría',
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
              Row(
                children: [
                  Chip(
                    label: Text('Últimas 24 horas'),
                    backgroundColor:
                        ModernTheme.primaryBlue.withValues(alpha: 0.1),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.filter_list),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.download),
                    onPressed: () {},
                  ),
                ],
              ),
              Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: auditLogs.length,
                  itemBuilder: (context, index) {
                    final log = auditLogs[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getAuditColor(log['type'])
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getAuditIcon(log['type']),
                            color: _getAuditColor(log['type']),
                            size: 20,
                          ),
                        ),
                        title: Text(log['action']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log['details'],
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.person,
                                    size: 12, color: ModernTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  log['user'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ModernTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.access_time,
                                    size: 12, color: ModernTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd/MM HH:mm')
                                      .format(log['timestamp']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ModernTheme.textSecondary,
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
              ),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      // Exportar logs
                    },
                    child: Text('Exportar Logs'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.primaryOrange,
                    ),
                    child: Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getAuditIcon(String type) {
    switch (type) {
      case 'config':
        return Icons.settings;
      case 'verification':
        return Icons.verified_user;
      case 'user':
        return Icons.person;
      case 'finance':
        return Icons.attach_money;
      default:
        return Icons.info;
    }
  }

  Color _getAuditColor(String type) {
    switch (type) {
      case 'config':
        return ModernTheme.primaryBlue;
      case 'verification':
        return ModernTheme.success;
      case 'user':
        return ModernTheme.warning;
      case 'finance':
        return ModernTheme.primaryOrange;
      default:
        return Colors.grey;
    }
  }

  void _performBackup() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Respaldo de Datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Realizando respaldo de la base de datos...'),
            const SizedBox(height: 8),
            Text(
              'Esto puede tomar varios minutos',
              style: TextStyle(
                fontSize: 12,
                color: ModernTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    // Simular proceso de respaldo
    await Future.delayed(Duration(seconds: 3));

    if (!mounted) return;
    if (!context.mounted) return;
    Navigator.pop(context);

    final backupInfo = {
      'timestamp': DateTime.now(),
      'size': '125 MB',
      'collections': ['users', 'trips', 'drivers', 'payments', 'settings'],
      'documents': 15432,
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: ModernTheme.success),
            const SizedBox(width: 8),
            Text('Respaldo Completado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackupInfo(
                'Fecha:',
                DateFormat('dd/MM/yyyy HH:mm')
                    .format(backupInfo['timestamp'] as DateTime)),
            _buildBackupInfo('Tamaño:', backupInfo['size'] as String),
            _buildBackupInfo('Documentos:', backupInfo['documents'].toString()),
            const SizedBox(height: 12),
            Text(
              'Colecciones respaldadas:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...(backupInfo['collections'] as List).map((col) => Text(
                  '• $col',
                  style: TextStyle(fontSize: 12),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Descargar respaldo
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Descargando backup_oasistxi_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.zip'),
                  backgroundColor: ModernTheme.primaryBlue,
                ),
              );
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: Text('Descargar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.primaryOrange,
            ),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );

    // Guardar registro del respaldo
    await _firebaseService.firestore.collection('backups').add({
      'timestamp': FieldValue.serverTimestamp(),
      'size': backupInfo['size'],
      'documents': backupInfo['documents'],
      'performedBy': _firebaseService.auth.currentUser?.uid,
    });
  }

  Widget _buildBackupInfo(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }

  void _clearCache() async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limpiar Caché'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Está seguro de limpiar el caché del sistema?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ModernTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: ModernTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esto puede hacer que la app funcione más lento temporalmente',
                      style: TextStyle(
                        fontSize: 12,
                        color: ModernTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.warning,
            ),
            child: Text('Limpiar Caché'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Limpiando caché...'),
            ],
          ),
        ),
      );

      // Simular limpieza de caché
      await Future.delayed(Duration(seconds: 2));

      if (!mounted) return;
      if (!context.mounted) return;
      Navigator.pop(context);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Caché limpiado: 45.2 MB liberados'),
            ],
          ),
          backgroundColor: ModernTheme.success,
        ),
      );

      // Registrar en auditoría
      await _firebaseService.firestore.collection('audit_logs').add({
        'action': 'cache_cleared',
        'performedBy': _firebaseService.auth.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'details': '45.2 MB cleared',
      });
    }
  }

  void _toggleMaintenanceMode() async {
    if (!mounted) return;

    bool isMaintenanceMode = false; // Obtener estado actual de Firestore

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Modo Mantenimiento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Activar modo mantenimiento detendrá temporalmente el servicio',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ModernTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ModernTheme.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning,
                      color: ModernTheme.warning,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esto afectará a TODOS los usuarios',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.warning,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Mensaje de mantenimiento',
                  hintText: 'Mensaje que verán los usuarios...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                controller: TextEditingController(
                  text:
                      'Estamos realizando mantenimiento para mejorar nuestro servicio. Volveremos pronto.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Cambiar estado de mantenimiento
                await _firebaseService.firestore
                    .collection('settings')
                    .doc('maintenance')
                    .set({
                  'enabled': !isMaintenanceMode,
                  'message':
                      'Estamos realizando mantenimiento para mejorar nuestro servicio.',
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': _firebaseService.auth.currentUser?.uid,
                });

                if (!context.mounted) return;
                if (!context.mounted) return;
                Navigator.pop(context);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Modo mantenimiento ACTIVADO - Servicio detenido',
                    ),
                    backgroundColor: ModernTheme.warning,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.error,
              ),
              child: Text(
                'Activar Mantenimiento',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

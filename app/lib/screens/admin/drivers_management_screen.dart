import '../../utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';

// Enums y clases auxiliares necesarias
enum DriverStatus { active, inactive, suspended, pending }

class Document {
  final String type;
  final String status;
  final DateTime? expiry;

  Document({required this.type, required this.status, this.expiry});
}

// Clase Driver extendida para panel de administración
class Driver {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String photo;
  DriverStatus status; // Cambiado a no-final para poder modificar
  final double rating;
  final int totalTrips;
  final DateTime? joinDate;
  final Vehicle vehicle;
  final List<Document> documents;
  final double earnings;
  final double commission;
  final DateTime? lastTrip;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.photo,
    required this.status,
    required this.rating,
    required this.totalTrips,
    this.joinDate,
    required this.vehicle,
    required this.documents,
    required this.earnings,
    required this.commission,
    this.lastTrip,
  });
}

// Clase Vehicle para compatibilidad
class Vehicle {
  final String brand;
  final String model;
  final int year;
  final String plate;
  final String color;

  Vehicle({
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.color,
  });
}

class DriversManagementScreen extends StatefulWidget {
  const DriversManagementScreen({super.key});

  @override
  DriversManagementScreenState createState() => DriversManagementScreenState();
}

class DriversManagementScreenState extends State<DriversManagementScreen>
    with TickerProviderStateMixin {
  late AnimationController _listController;
  late AnimationController _statsController;
  late TabController _tabController;

  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _sortBy = 'name';

  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lista de conductores desde Firebase
  List<Driver> _drivers = [];
  bool _isLoading = true;

  // Lista de conductores desde Firebase
  // final List<Driver> _mockDrivers = []; // No usado actualmente

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('DriversManagementScreen', 'initState');
    _listController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _tabController = TabController(length: 4, vsync: this);

    _listController.forward();
    _statsController.forward();

    // Cargar conductores desde Firebase
    _loadDriversFromFirebase();
  }

  Future<void> _loadDriversFromFirebase() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Obtener conductores desde Firebase
      final QuerySnapshot driversSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .orderBy('createdAt', descending: true)
          .get();

      List<Driver> loadedDrivers = [];

      for (var doc in driversSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Obtener vehículo del conductor si existe
        Vehicle? vehicle;
        if (data['vehicleId'] != null) {
          final vehicleDoc = await _firestore
              .collection('vehicles')
              .doc(data['vehicleId'])
              .get();

          if (vehicleDoc.exists) {
            final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
            vehicle = Vehicle(
              brand: vehicleData['brand'] ?? 'Sin marca',
              model: vehicleData['model'] ?? 'Sin modelo',
              year: vehicleData['year'] ?? 2020,
              plate: vehicleData['plate'] ?? 'SIN-PLACA',
              color: vehicleData['color'] ?? 'Sin color',
            );
          }
        }

        // Si no hay vehículo, usar uno por defecto
        vehicle ??= Vehicle(
          brand: 'Por registrar',
          model: 'Por registrar',
          year: DateTime.now().year,
          plate: 'SIN-PLACA',
          color: 'Por registrar',
        );

        // Obtener documentos del conductor
        List<Document> documents = [];
        if (data['documents'] != null && data['documents'] is List) {
          for (var docData in data['documents']) {
            documents.add(Document(
              type: docData['type'] ?? 'Desconocido',
              status: docData['status'] ?? 'pending',
              expiry: docData['expiry'] != null
                  ? (docData['expiry'] as Timestamp).toDate()
                  : null,
            ));
          }
        }

        // Si no hay documentos, agregar los requeridos por defecto
        if (documents.isEmpty) {
          documents = [
            Document(type: 'Licencia', status: 'pending', expiry: null),
            Document(type: 'SOAT', status: 'pending', expiry: null),
            Document(type: 'Antecedentes', status: 'pending', expiry: null),
          ];
        }

        // Calcular estadísticas desde la colección de rides
        int totalTrips = 0;
        double totalEarnings = 0;
        double totalCommission = 0;
        DateTime? lastTripDate;

        final ridesSnapshot = await _firestore
            .collection('rides')
            .where('driverId', isEqualTo: doc.id)
            .orderBy('createdAt', descending: true)
            .get();

        totalTrips = ridesSnapshot.docs.length;

        for (var rideDoc in ridesSnapshot.docs) {
          final rideData = rideDoc.data();
          if (rideData['fare'] != null) {
            double fare = (rideData['fare'] as num).toDouble();
            totalEarnings += fare;
            totalCommission += fare * 0.20; // 20% de comisión
          }
        }

        if (ridesSnapshot.docs.isNotEmpty) {
          lastTripDate =
              (ridesSnapshot.docs.first.data()['completedAt'] as Timestamp?)
                  ?.toDate();
        }

        // Determinar estado del conductor
        DriverStatus status;
        if (data['isSuspended'] == true) {
          status = DriverStatus.suspended;
        } else if (data['isActive'] == false) {
          status = DriverStatus.inactive;
        } else if (data['isVerified'] == false) {
          status = DriverStatus.pending;
        } else {
          status = DriverStatus.active;
        }

        loadedDrivers.add(Driver(
          id: doc.id,
          name: data['displayName'] ?? 'Sin nombre',
          email: data['email'] ?? 'sin@email.com',
          phone: data['phoneNumber'] ?? '+51 999 999 999',
          photo: data['photoURL'] ?? '',
          status: status,
          rating: (data['rating'] ?? 5.0).toDouble(),
          totalTrips: totalTrips,
          joinDate: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          vehicle: vehicle,
          documents: documents,
          earnings: totalEarnings,
          commission: totalCommission,
          lastTrip: lastTripDate,
        ));
      }

      setState(() {
        _drivers = loadedDrivers;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('cargando conductores', e);
      setState(() {
        _isLoading = false;
      });

      // Mostrar error al usuario
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar conductores: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  List<Driver> get _filteredDrivers {
    var filtered = _drivers;

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((driver) {
        return driver.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            driver.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            driver.phone.contains(_searchQuery) ||
            driver.vehicle.plate
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filtrar por estado
    if (_selectedStatus != 'all') {
      filtered = filtered.where((driver) {
        return driver.status.toString().split('.').last == _selectedStatus;
      }).toList();
    }

    // Ordenar
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a.name.compareTo(b.name);
        case 'rating':
          return b.rating.compareTo(a.rating);
        case 'trips':
          return b.totalTrips.compareTo(a.totalTrips);
        case 'earnings':
          return b.earnings.compareTo(a.earnings);
        default:
          return 0;
      }
    });

    return filtered;
  }

  Map<String, dynamic> get _statistics {
    final activeDrivers =
        _drivers.where((d) => d.status == DriverStatus.active).length;
    final pendingDrivers =
        _drivers.where((d) => d.status == DriverStatus.pending).length;
    final totalEarnings =
        _drivers.fold<double>(0, (accumulator, d) => accumulator + d.earnings);
    final totalCommission = _drivers.fold<double>(
        0, (accumulator, d) => accumulator + d.commission);

    return {
      'total': _drivers.length,
      'active': activeDrivers,
      'pending': pendingDrivers,
      'earnings': totalEarnings,
      'commission': totalCommission,
    };
  }

  @override
  void dispose() {
    _listController.dispose();
    _statsController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _statistics;

    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        title: Text(
          'Gestión de Conductores',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: _exportData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: ModernTheme.oasisGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando conductores...',
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDriversFromFirebase,
              color: ModernTheme.oasisGreen,
              child: Column(
                children: [
                  // Estadísticas
                  AnimatedBuilder(
                    animation: _statsController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, -50 * (1 - _statsController.value)),
                        child: Opacity(
                          opacity: _statsController.value,
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  ModernTheme.oasisGreen,
                                  ModernTheme.oasisGreen.withBlue(30),
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatCard(
                                    'Total', '${stats['total']}', Icons.group),
                                _buildStatCard('Activos', '${stats['active']}',
                                    Icons.check_circle),
                                _buildStatCard('Pendientes',
                                    '${stats['pending']}', Icons.pending),
                                _buildStatCard(
                                  'Ganancias',
                                  'S/ ${(stats['earnings'] / 1000).toStringAsFixed(1)}K',
                                  Icons.attach_money,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Barra de búsqueda
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText:
                                  'Buscar por nombre, email, teléfono o placa...',
                              prefixIcon: Icon(Icons.search,
                                  color: ModernTheme.oasisGreen),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: ModernTheme.backgroundLight,
                            ),
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.sort, color: ModernTheme.oasisGreen),
                          onSelected: (value) {
                            setState(() => _sortBy = value);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'name', child: Text('Nombre')),
                            PopupMenuItem(
                                value: 'rating', child: Text('Calificación')),
                            PopupMenuItem(
                                value: 'trips', child: Text('Viajes')),
                            PopupMenuItem(
                                value: 'earnings', child: Text('Ganancias')),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tabs de estado
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: ModernTheme.oasisGreen,
                      unselectedLabelColor: ModernTheme.textSecondary,
                      indicatorColor: ModernTheme.oasisGreen,
                      onTap: (index) {
                        setState(() {
                          switch (index) {
                            case 0:
                              _selectedStatus = 'all';
                              break;
                            case 1:
                              _selectedStatus = 'active';
                              break;
                            case 2:
                              _selectedStatus = 'pending';
                              break;
                            case 3:
                              _selectedStatus = 'inactive';
                              break;
                          }
                        });
                      },
                      tabs: [
                        Tab(text: 'Todos'),
                        Tab(text: 'Activos'),
                        Tab(text: 'Pendientes'),
                        Tab(text: 'Inactivos'),
                      ],
                    ),
                  ),

                  // Lista de conductores
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _listController,
                      builder: (context, child) {
                        return ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredDrivers.length,
                          itemBuilder: (context, index) {
                            final driver = _filteredDrivers[index];
                            final delay = index * 0.1;
                            final animation = Tween<double>(
                              begin: 0,
                              end: 1,
                            ).animate(
                              CurvedAnimation(
                                parent: _listController,
                                curve: Interval(
                                  delay,
                                  delay + 0.5,
                                  curve: Curves.easeOutBack,
                                ),
                              ),
                            );

                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(50 * (1 - animation.value), 0),
                                  child: Opacity(
                                    opacity: animation.value,
                                    child: _buildDriverCard(driver),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewDriver,
        backgroundColor: ModernTheme.oasisGreen,
        icon: Icon(Icons.person_add, color: Colors.white),
        label: Text('Agregar Conductor', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
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

  Widget _buildDriverCard(Driver driver) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () => _showDriverDetails(driver),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Header con foto y estado
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(driver.photo),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _getStatusColor(driver.status),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          driver.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: ModernTheme.textSecondary,
                          ),
                        ),
                        Text(
                          driver.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: ModernTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(driver.status),
                ],
              ),

              const SizedBox(height: 16),

              // Información del vehículo
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ModernTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car,
                        color: ModernTheme.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${driver.vehicle.brand} ${driver.vehicle.model} ${driver.vehicle.year}',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        driver.vehicle.plate,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Estadísticas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(Icons.star, driver.rating.toString(), 'Rating',
                      Colors.amber),
                  _buildMiniStat(Icons.route, driver.totalTrips.toString(),
                      'Viajes', ModernTheme.primaryBlue),
                  _buildMiniStat(
                      Icons.attach_money,
                      'S/ ${(driver.earnings / 1000).toStringAsFixed(1)}K',
                      'Ganancias',
                      ModernTheme.success),
                  if (driver.lastTrip != null)
                    _buildMiniStat(
                        Icons.access_time,
                        _formatLastTrip(driver.lastTrip!),
                        'Último',
                        ModernTheme.info),
                ],
              ),

              const SizedBox(height: 12),

              // Documentos
              _buildDocumentsRow(driver.documents),

              const SizedBox(height: 12),

              // Acciones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (driver.status == DriverStatus.pending) ...[
                    TextButton.icon(
                      onPressed: () => _rejectDriver(driver),
                      icon: Icon(Icons.close, color: ModernTheme.error),
                      label: Text('Rechazar',
                          style: TextStyle(color: ModernTheme.error)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _approveDriver(driver),
                      icon: Icon(Icons.check, color: Colors.white),
                      label: Text('Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.success,
                      ),
                    ),
                  ] else if (driver.status == DriverStatus.active) ...[
                    TextButton.icon(
                      onPressed: () => _suspendDriver(driver),
                      icon: Icon(Icons.block, color: ModernTheme.warning),
                      label: Text('Suspender',
                          style: TextStyle(color: ModernTheme.warning)),
                    ),
                  ] else if (driver.status == DriverStatus.suspended) ...[
                    ElevatedButton.icon(
                      onPressed: () => _activateDriver(driver),
                      icon: Icon(Icons.check_circle, color: Colors.white),
                      label: Text('Activar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.oasisGreen,
                      ),
                    ),
                  ],
                  IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () => _showDriverOptions(driver),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(DriverStatus status) {
    String text;
    Color color;

    switch (status) {
      case DriverStatus.active:
        text = 'Activo';
        color = ModernTheme.success;
        break;
      case DriverStatus.inactive:
        text = 'Inactivo';
        color = ModernTheme.textSecondary;
        break;
      case DriverStatus.pending:
        text = 'Pendiente';
        color = ModernTheme.warning;
        break;
      case DriverStatus.suspended:
        text = 'Suspendido';
        color = ModernTheme.error;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMiniStat(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
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

  Widget _buildDocumentsRow(List<Document> documents) {
    return Row(
      children: [
        Icon(Icons.description, size: 16, color: ModernTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          'Documentos:',
          style: TextStyle(
            fontSize: 12,
            color: ModernTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: documents.map((doc) {
              Color color;
              IconData icon;

              switch (doc.status) {
                case 'verified':
                  color = ModernTheme.success;
                  icon = Icons.check_circle;
                  break;
                case 'pending':
                  color = ModernTheme.warning;
                  icon = Icons.pending;
                  break;
                case 'expired':
                  color = ModernTheme.error;
                  icon = Icons.error;
                  break;
                case 'rejected':
                  color = ModernTheme.error;
                  icon = Icons.cancel;
                  break;
                default:
                  color = ModernTheme.textSecondary;
                  icon = Icons.help;
              }

              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: '${doc.type}: ${doc.status}',
                  child: Icon(icon, size: 20, color: color),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.active:
        return ModernTheme.success;
      case DriverStatus.inactive:
        return Colors.grey;
      case DriverStatus.pending:
        return ModernTheme.warning;
      case DriverStatus.suspended:
        return ModernTheme.error;
    }
  }

  String _formatLastTrip(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }

  void _showDriverDetails(Driver driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DriverDetailsModal(driver: driver),
    );
  }

  void _showDriverOptions(Driver driver) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Editar información'),
              onTap: () {
                Navigator.pop(context);
                _editDriver(driver);
              },
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text('Ver historial'),
              onTap: () {
                Navigator.pop(context);
                _showDriverHistory(driver);
              },
            ),
            ListTile(
              leading: Icon(Icons.message),
              title: Text('Enviar mensaje'),
              onTap: () {
                Navigator.pop(context);
                _sendMessage(driver);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: ModernTheme.error),
              title: Text('Eliminar conductor',
                  style: TextStyle(color: ModernTheme.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteDriver(driver);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _approveDriver(Driver driver) {
    setState(() {
      driver.status = DriverStatus.active;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conductor aprobado exitosamente'),
        backgroundColor: ModernTheme.success,
      ),
    );
  }

  void _rejectDriver(Driver driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rechazar Conductor'),
        content: TextField(
          decoration: InputDecoration(
            labelText: 'Motivo del rechazo',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                driver.status = DriverStatus.inactive;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Conductor rechazado'),
                  backgroundColor: ModernTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.error),
            child: Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  void _suspendDriver(Driver driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Suspender Conductor'),
        content:
            Text('¿Estás seguro de que deseas suspender a este conductor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!mounted) return;
              Navigator.pop(context);

              try {
                // Actualizar en Firebase
                await _firestore.collection('users').doc(driver.id).update({
                  'isSuspended': true,
                  'isActive': false,
                  'suspendedAt': FieldValue.serverTimestamp(),
                });

                _showSnackBar(
                    'Conductor suspendido correctamente', ModernTheme.warning);

                // Recargar conductores
                _loadDriversFromFirebase();
              } catch (e) {
                _showSnackBar(
                    'Error al suspender conductor: $e', ModernTheme.error);
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: ModernTheme.warning),
            child: Text('Suspender'),
          ),
        ],
      ),
    );
  }

  void _activateDriver(Driver driver) async {
    try {
      // Actualizar en Firebase
      await _firestore.collection('users').doc(driver.id).update({
        'isSuspended': false,
        'isActive': true,
        'isVerified': true,
        'activatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conductor activado correctamente'),
          backgroundColor: ModernTheme.success,
        ),
      );

      // Recargar conductores
      _loadDriversFromFirebase();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al activar conductor: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _editDriver(Driver driver) {
    // Implementar edición
  }

  void _showDriverHistory(Driver driver) {
    // Implementar historial
  }

  void _sendMessage(Driver driver) {
    // Implementar mensajería
  }

  void _deleteDriver(Driver driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar Conductor'),
        content: Text('Esta acción no se puede deshacer. ¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // Eliminar de Firebase
                await _firestore.collection('users').doc(driver.id).delete();

                // También eliminar el vehículo asociado si existe
                final vehicleSnapshot = await _firestore
                    .collection('vehicles')
                    .where('driverId', isEqualTo: driver.id)
                    .get();

                for (var doc in vehicleSnapshot.docs) {
                  await doc.reference.delete();
                }

                _showSnackBar(
                    'Conductor eliminado correctamente', ModernTheme.error);

                // Recargar conductores
                _loadDriversFromFirebase();
              } catch (e) {
                _showSnackBar(
                    'Error al eliminar conductor: $e', ModernTheme.error);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.error),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _addNewDriver() {
    // Implementar agregar conductor
  }

  void _showFilterDialog() {
    // Implementar filtros avanzados
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportando datos...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Modal de detalles del conductor
class DriverDetailsModal extends StatelessWidget {
  final Driver driver;

  const DriverDetailsModal({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: ModernTheme.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(driver.photo),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        driver.email,
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        driver.phone,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
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
                  // Información del vehículo
                  _buildSection(
                    'Vehículo',
                    Icons.directions_car,
                    [
                      _buildInfoRow('Marca', driver.vehicle.brand),
                      _buildInfoRow('Modelo', driver.vehicle.model),
                      _buildInfoRow('Año', driver.vehicle.year.toString()),
                      _buildInfoRow('Placa', driver.vehicle.plate),
                      _buildInfoRow('Color', driver.vehicle.color),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Documentos
                  _buildSection(
                    'Documentos',
                    Icons.description,
                    driver.documents.map((doc) {
                      return _buildDocumentRow(doc);
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Estadísticas
                  _buildSection(
                    'Estadísticas',
                    Icons.bar_chart,
                    [
                      _buildInfoRow('Calificación', '${driver.rating} ⭐'),
                      _buildInfoRow(
                          'Viajes totales', driver.totalTrips.toString()),
                      _buildInfoRow('Ganancias',
                          'S/ ${driver.earnings.toStringAsFixed(2)}'),
                      _buildInfoRow('Comisión',
                          'S/ ${driver.commission.toStringAsFixed(2)}'),
                      _buildInfoRow(
                          'Fecha de registro',
                          driver.joinDate != null
                              ? '${driver.joinDate!.day}/${driver.joinDate!.month}/${driver.joinDate!.year}'
                              : 'No disponible'),
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

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: ModernTheme.oasisGreen),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ModernTheme.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: ModernTheme.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(Document doc) {
    Color statusColor;
    String statusText;

    switch (doc.status) {
      case 'verified':
        statusColor = ModernTheme.success;
        statusText = 'Verificado';
        break;
      case 'pending':
        statusColor = ModernTheme.warning;
        statusText = 'Pendiente';
        break;
      case 'expired':
        statusColor = ModernTheme.error;
        statusText = 'Expirado';
        break;
      case 'rejected':
        statusColor = ModernTheme.error;
        statusText = 'Rechazado';
        break;
      default:
        statusColor = ModernTheme.textSecondary;
        statusText = 'Desconocido';
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(doc.type),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (doc.expiry != null) ...[
            const SizedBox(width: 8),
            Text(
              'Exp: ${doc.expiry!.day}/${doc.expiry!.month}/${doc.expiry!.year}',
              style: TextStyle(
                fontSize: 11,
                color: ModernTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

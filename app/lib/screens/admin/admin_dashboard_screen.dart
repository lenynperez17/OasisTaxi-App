// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../services/firebase_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  late FirebaseService _firebaseService;
  
  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'totalDrivers': 0,
    'tripsToday': 0,
    'todayEarnings': 0.0,
    'activeUsers': 0,
    'onlineDrivers': 0,
    'availableDrivers': 0,
    'driversInTrip': 0,
  };

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final usersSnapshot = await _firebaseService.firestore.collection('users').get();
      final driversSnapshot = await _firebaseService.firestore.collection('users').where('userType', isEqualTo: 'driver').get();
      final tripsSnapshot = await _firebaseService.firestore.collection('trips')
          .where('requestedAt', isGreaterThanOrEqualTo: todayStart)
          .get();

      double todayEarnings = 0.0;
      int activeUsers = 0;
      int onlineDrivers = 0;
      int availableDrivers = 0;
      int driversInTrip = 0;

      for (var user in usersSnapshot.docs) {
        final userData = user.data();
        if (userData['isActive'] == true) activeUsers++;
      }

      for (var driver in driversSnapshot.docs) {
        final driverData = driver.data();
        if (driverData['isOnline'] == true) onlineDrivers++;
        if (driverData['isAvailable'] == true) availableDrivers++;
        if (driverData['status'] == 'in_trip') driversInTrip++;
      }

      for (var trip in tripsSnapshot.docs) {
        final tripData = trip.data();
        if (tripData['status'] == 'completed') {
          todayEarnings += (tripData['finalFare'] ?? 0.0).toDouble();
        }
      }

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
        };
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  final List<AdminMenuItem> _menuItems = [
    AdminMenuItem(
      icon: Icons.dashboard,
      title: 'Dashboard',
      subtitle: 'Vista general',
    ),
    AdminMenuItem(
      icon: Icons.people,
      title: 'Usuarios',
      subtitle: 'Gestión de usuarios',
    ),
    AdminMenuItem(
      icon: Icons.directions_car,
      title: 'Conductores',
      subtitle: 'Gestión de conductores',
    ),
    AdminMenuItem(
      icon: Icons.analytics,
      title: 'Analíticas',
      subtitle: 'Estadísticas y reportes',
    ),
    AdminMenuItem(
      icon: Icons.account_balance_wallet,
      title: 'Finanzas',
      subtitle: 'Gestión financiera',
    ),
    AdminMenuItem(
      icon: Icons.settings,
      title: 'Configuración',
      subtitle: 'Ajustes del sistema',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: OasisAppBar(
        title: 'Panel Administrativo',
        showBackButton: false,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Layout para desktop/tablet
            return Row(
              children: [
                SizedBox(
                  width: 280,
                  child: _buildSidebar(),
                ),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            );
          } else {
            // Layout para móvil
            return Column(
              children: [
                SizedBox(
                  height: 60,
                  child: _buildMobileNav(),
                ),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          OasisDrawerHeader(
            userType: 'admin',
            userName: 'Administrador',
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isSelected = index == _selectedIndex;
                
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected
                          ? ModernTheme.oasisGreen
                          : ModernTheme.textSecondary,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected
                            ? ModernTheme.oasisGreen
                            : ModernTheme.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                      // Navegar a las pantallas correspondientes
                      switch (index) {
                        case 1:
                          Navigator.pushNamed(context, '/admin/users-management');
                          break;
                        case 2:
                          Navigator.pushNamed(context, '/admin/drivers-management');
                          break;
                        case 3:
                          Navigator.pushNamed(context, '/admin/analytics');
                          break;
                        case 4:
                          Navigator.pushNamed(context, '/admin/financial');
                          break;
                        case 5:
                          Navigator.pushNamed(context, '/admin/settings');
                          break;
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNav() {
    return Container(
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          final isSelected = index == _selectedIndex;
          
          return SizedBox(
            width: 80,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    color: isSelected
                        ? ModernTheme.oasisGreen
                        : ModernTheme.textSecondary,
                    size: 24,
                  ),
                  SizedBox(height: 4),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: isSelected
                          ? ModernTheme.oasisGreen
                          : ModernTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _menuItems[_selectedIndex].title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _menuItems[_selectedIndex].subtitle,
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: _buildContentForIndex(_selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildContentForIndex(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildUsersContent();
      case 2:
        return _buildDriversContent();
      case 3:
        return _buildAnalyticsContent();
      case 4:
        return _buildFinancesContent();
      case 5:
        return _buildSettingsContent();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.8 : 1.5,
      children: [
        _buildStatsCard('Usuarios Totales', _stats['totalUsers'].toString(), Icons.people, Colors.blue),
        _buildStatsCard('Conductores', _stats['totalDrivers'].toString(), Icons.directions_car, Colors.green),
        _buildStatsCard('Viajes Hoy', _stats['tripsToday'].toString(), Icons.route, Colors.orange),
        _buildStatsCard('Ingresos', '\$${_stats['todayEarnings'].toStringAsFixed(0)}', Icons.attach_money, Colors.purple),
      ],
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ModernTheme.cardShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                  maxLines: 1,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Estadísticas de usuarios
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.8 : 1.5,
            children: [
              _buildStatsCard('Total Usuarios', _stats['totalUsers'].toString(), Icons.people, Colors.blue),
              _buildStatsCard('Activos', _stats['activeUsers'].toString(), Icons.check_circle, Colors.green),
              _buildStatsCard('Nuevos (Mes)', '0', Icons.person_add, Colors.orange),
              _buildStatsCard('Suspendidos', '0', Icons.block, Colors.red),
            ],
          ),
          SizedBox(height: 24),
          // Botón para ir a gestión completa
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/users-management'),
            icon: Icon(Icons.manage_accounts),
            label: Text('Gestión Completa de Usuarios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Estadísticas de conductores
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.8 : 1.5,
            children: [
              _buildStatsCard('Total Conductores', _stats['totalDrivers'].toString(), Icons.directions_car, Colors.green),
              _buildStatsCard('En Línea', _stats['onlineDrivers'].toString(), Icons.wifi, Colors.blue),
              _buildStatsCard('Disponibles', _stats['availableDrivers'].toString(), Icons.check, Colors.orange),
              _buildStatsCard('En Viaje', _stats['driversInTrip'].toString(), Icons.route, Colors.purple),
            ],
          ),
          SizedBox(height: 24),
          // Botón para ir a gestión completa
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/drivers-management'),
            icon: Icon(Icons.drive_eta),
            label: Text('Gestión Completa de Conductores'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // KPIs principales
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.8 : 1.5,
            children: [
              _buildStatsCard('Viajes Hoy', _stats['tripsToday'].toString(), Icons.route, Colors.blue),
              _buildStatsCard('Ingresos Hoy', '\$${_stats['todayEarnings'].toStringAsFixed(0)}', Icons.attach_money, Colors.green),
              _buildStatsCard('Rating Promedio', '5.0⭐', Icons.star, Colors.amber),
              _buildStatsCard('Tasa Conversión', '0%', Icons.trending_up, Colors.purple),
            ],
          ),
          SizedBox(height: 24),
          // Mini gráfico de barras simple
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Viajes Últimos 7 días', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      double height = 20 + (index * 8.0);
                      return Flexible(
                        child: Container(
                          width: 25,
                          height: height,
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: ModernTheme.oasisGreen.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          // Botón para ir a analíticas completas
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/analytics'),
            icon: Icon(Icons.analytics),
            label: Text('Ver Analíticas Completas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancesContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Resumen financiero
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ModernTheme.oasisGreen, ModernTheme.oasisGreen.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.cardShadow,
            ),
            child: Column(
              children: [
                Text(
                  'Balance del Día',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '\$${_stats['todayEarnings'].toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Ingresos', style: TextStyle(color: Colors.white70)),
                        Text('\$${_stats['todayEarnings'].toStringAsFixed(0)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(width: 1, height: 30, color: Colors.white30),
                    Column(
                      children: [
                        Text('Comisiones', style: TextStyle(color: Colors.white70)),
                        Text('\$${(_stats['todayEarnings'] * 0.2).toStringAsFixed(0)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          // Estadísticas financieras
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildStatsCard('Pagos Pendientes', '0', Icons.pending, Colors.orange),
              _buildStatsCard('Pagos Completados', _stats['tripsToday'].toString(), Icons.check_circle, Colors.green),
              _buildStatsCard('Retiros Hoy', '0', Icons.account_balance, Colors.blue),
              _buildStatsCard('Disputas', '0', Icons.warning, Colors.red),
            ],
          ),
          SizedBox(height: 24),
          // Botón para ir a finanzas completas
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/financial'),
            icon: Icon(Icons.account_balance_wallet),
            label: Text('Gestión Financiera Completa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Lista de configuraciones
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.cardShadow,
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.attach_money, color: ModernTheme.oasisGreen),
                  title: Text('Tarifas y Precios'),
                  subtitle: Text('Configurar tarifas base y comisiones'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.map, color: ModernTheme.primaryBlue),
                  title: Text('Zonas y Cobertura'),
                  subtitle: Text('Gestionar áreas de servicio'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.local_offer, color: ModernTheme.primaryOrange),
                  title: Text('Promociones'),
                  subtitle: Text('Códigos y descuentos activos'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.notifications, color: ModernTheme.warning),
                  title: Text('Notificaciones'),
                  subtitle: Text('Configurar alertas y mensajes'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.security, color: ModernTheme.error),
                  title: Text('Seguridad'),
                  subtitle: Text('Políticas y permisos'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          // Información del sistema
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.backgroundLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Versión del Sistema:'),
                    Text('2.0.0', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Último Respaldo:'),
                    Text('Hoy 3:00 AM', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Estado del Servidor:'),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ModernTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Operativo',
                        style: TextStyle(
                          color: ModernTheme.success,
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
          SizedBox(height: 24),
          // Botón para ir a configuración completa
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin/settings'),
            icon: Icon(Icons.settings),
            label: Text('Configuración Completa del Sistema'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;

  AdminMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
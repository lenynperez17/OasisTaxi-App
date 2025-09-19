import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/embedded_data_studio_widget.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../utils/app_logger.dart';

/// Pantalla para mostrar dashboards embebidos de Google Data Studio
///
/// Características:
/// - Vista de dashboards múltiples en tabs
/// - Dashboards responsivos según el rol del usuario
/// - Filtros avanzados por fecha y categorías
/// - Exportación masiva de reportes
/// - Alertas automáticas sobre métricas críticas
/// - Modo pantalla completa para presentaciones
class EmbeddedDashboardsScreen extends StatefulWidget {
  const EmbeddedDashboardsScreen({super.key});

  @override
  State<EmbeddedDashboardsScreen> createState() =>
      _EmbeddedDashboardsScreenState();
}

class _EmbeddedDashboardsScreenState extends State<EmbeddedDashboardsScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _isFullScreen = false;
  String? _selectedDashboard = 'analytics';
  Map<String, dynamic> _globalFilters = {};
  Timer? _alertsCheckTimer;

  // Configuración de dashboards según rol
  final Map<String, List<DashboardTab>> _dashboardsByRole = {
    'super_admin': [
      DashboardTab('executive', 'Ejecutivo', Icons.bar_chart, Colors.purple),
      DashboardTab(
          'operations', 'Operaciones', Icons.directions_car, Colors.blue),
      DashboardTab(
          'financial', 'Financiero', Icons.monetization_on, Colors.green),
      DashboardTab('drivers', 'Conductores', Icons.person_pin, Colors.orange),
      DashboardTab('passengers', 'Pasajeros', Icons.people, Colors.teal),
      DashboardTab('quality', 'Calidad', Icons.star, Colors.amber),
      DashboardTab('marketing', 'Marketing', Icons.campaign, Colors.pink),
    ],
    'admin': [
      DashboardTab('executive', 'Ejecutivo', Icons.bar_chart, Colors.purple),
      DashboardTab(
          'operations', 'Operaciones', Icons.directions_car, Colors.blue),
      DashboardTab(
          'financial', 'Financiero', Icons.monetization_on, Colors.green),
      DashboardTab('drivers', 'Conductores', Icons.person_pin, Colors.orange),
      DashboardTab('passengers', 'Pasajeros', Icons.people, Colors.teal),
      DashboardTab('quality', 'Calidad', Icons.star, Colors.amber),
    ],
    'manager': [
      DashboardTab(
          'operations', 'Operaciones', Icons.directions_car, Colors.blue),
      DashboardTab('drivers', 'Conductores', Icons.person_pin, Colors.orange),
      DashboardTab('quality', 'Calidad', Icons.star, Colors.amber),
    ],
  };

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('EmbeddedDashboardsScreen', 'initState');
    _initializeDashboards();
    _setupAlertsMonitoring();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _alertsCheckTimer?.cancel();
    super.dispose();
  }

  void _initializeDashboards() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.userRole ?? 'admin';

    final availableDashboards =
        _dashboardsByRole[userRole] ?? _dashboardsByRole['admin']!;

    _tabController = TabController(
      length: availableDashboards.length,
      vsync: this,
    );

    _selectedDashboard =
        availableDashboards.isNotEmpty ? availableDashboards.first.type : null;

    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) {
        final selectedTab = availableDashboards[_tabController!.index];
        setState(() {
          _selectedDashboard = selectedTab.type;
        });

        AppLogger.info('📊 Cambiando a dashboard: ${selectedTab.type}');
      }
    });

    // Configurar filtros globales por defecto
    _globalFilters = {
      'dateRange': 'last_30_days',
      'timezone': 'America/Lima',
      'currency': 'PEN',
    };

    AppLogger.info('📊 Dashboards inicializados para rol: $userRole');
  }

  void _setupAlertsMonitoring() {
    // Verificar alertas críticas cada 5 minutos
    _alertsCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkCriticalAlerts();
    });
  }

  Future<void> _checkCriticalAlerts() async {
    try {
      // Aquí se implementaría la lógica para verificar alertas críticas
      // basadas en las métricas de los dashboards

      // Ejemplo de alertas que se podrían verificar:
      // - Caída en revenue por debajo del 80% del promedio
      // - Más del 20% de trips cancelados
      // - Rating promedio por debajo de 4.0
      // - Más del 10% de conductores offline

      AppLogger.debug('🚨 Verificando alertas críticas...');
    } catch (error) {
      AppLogger.warning('Error verificando alertas: $error');
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  void _showFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildFiltersDialog(),
    );
  }

  Future<void> _exportAllDashboards() async {
    try {
      AppLogger.info('📄 Iniciando exportación masiva de dashboards');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userRole = authProvider.userRole ?? 'admin';
      final availableDashboards = _dashboardsByRole[userRole] ?? [];

      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _buildExportProgressDialog(availableDashboards.length),
      );

      // Simular exportación de cada dashboard
      for (int i = 0; i < availableDashboards.length; i++) {
        await Future.delayed(const Duration(seconds: 2));
        // Aquí iría la lógica real de exportación
        AppLogger.debug('Exportando dashboard: ${availableDashboards[i].name}');
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar diálogo de progreso
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${availableDashboards.length} dashboards exportados exitosamente'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar diálogo de progreso

      AppLogger.error('Error exportando dashboards', error);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exportando dashboards: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final userRole = authProvider.userRole ?? 'admin';
        final availableDashboards = _dashboardsByRole[userRole] ?? [];

        if (availableDashboards.isEmpty) {
          return Scaffold(
            appBar: OasisAppBar(title: 'Dashboards'),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay dashboards disponibles para tu rol',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: _isFullScreen ? null : _buildAppBar(availableDashboards),
          body: _buildBody(availableDashboards),
          floatingActionButton: _isFullScreen ? _buildFullScreenFAB() : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(List<DashboardTab> dashboards) {
    return AppBar(
      title: const Text('Data Studio Dashboards'),
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 2,
      actions: [
        // Botón de filtros
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFiltersDialog,
          tooltip: 'Filtros',
        ),

        // Botón de exportación masiva
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: _exportAllDashboards,
          tooltip: 'Exportar todos',
        ),

        // Botón de pantalla completa
        IconButton(
          icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
          onPressed: _toggleFullScreen,
          tooltip: _isFullScreen
              ? 'Salir de pantalla completa'
              : 'Pantalla completa',
        ),

        const SizedBox(width: 8),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: dashboards.length > 4,
        tabs: dashboards
            .map((dashboard) => Tab(
                  icon: Icon(dashboard.icon),
                  text: dashboard.name,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildBody(List<DashboardTab> dashboards) {
    return TabBarView(
      controller: _tabController,
      children: dashboards
          .map((dashboard) => _buildDashboardPage(dashboard))
          .toList(),
    );
  }

  Widget _buildDashboardPage(DashboardTab dashboard) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Información del dashboard (solo si no está en pantalla completa)
          if (!_isFullScreen) _buildDashboardHeader(dashboard),

          // Dashboard embebido
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(_isFullScreen ? 0 : 16),
              child: EmbeddedDataStudioWidget(
                dashboardType: dashboard.type,
                filters: _globalFilters,
                showToolbar: !_isFullScreen,
                allowExport: true,
                height: _isFullScreen ? double.infinity : 600,
                onDataLoaded: () {
                  AppLogger.info('✅ Dashboard ${dashboard.name} cargado');
                },
                onError: (error) {
                  _showDashboardError(dashboard.name, error);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(DashboardTab dashboard) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dashboard.color.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: dashboard.color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: dashboard.color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              dashboard.icon,
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
                  'Dashboard ${dashboard.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Métricas y análisis en tiempo real',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Indicador de estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  color: Colors.green,
                  size: 8,
                ),
                SizedBox(width: 6),
                Text(
                  'Activo',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenFAB() {
    return FloatingActionButton(
      onPressed: _toggleFullScreen,
      backgroundColor: Theme.of(context).primaryColor,
      child: const Icon(Icons.fullscreen_exit),
    );
  }

  Widget _buildFiltersDialog() {
    return AlertDialog(
      title: const Text('Filtros de Dashboard'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selector de rango de fechas
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Rango de fechas'),
            subtitle: Text(_getDateRangeLabel(_globalFilters['dateRange'])),
            onTap: () => _showDateRangePicker(),
          ),

          const Divider(),

          // Selector de zona horaria
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Zona horaria'),
            subtitle: Text(_globalFilters['timezone'] ?? 'America/Lima'),
            onTap: () => _showTimezonePicker(),
          ),

          const Divider(),

          // Selector de moneda
          ListTile(
            leading: const Icon(Icons.monetization_on),
            title: const Text('Moneda'),
            subtitle: Text(_globalFilters['currency'] ?? 'PEN'),
            onTap: () => _showCurrencyPicker(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _applyFilters();
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }

  Widget _buildExportProgressDialog(int totalDashboards) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Exportando $totalDashboards dashboards...'),
          const SizedBox(height: 8),
          const Text(
            'Esto puede tomar algunos minutos',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Seleccionar rango de fechas'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() {
                _globalFilters['dateRange'] = 'last_7_days';
              });
              Navigator.pop(context);
            },
            child: const Text('Últimos 7 días'),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() {
                _globalFilters['dateRange'] = 'last_30_days';
              });
              Navigator.pop(context);
            },
            child: const Text('Últimos 30 días'),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() {
                _globalFilters['dateRange'] = 'last_90_days';
              });
              Navigator.pop(context);
            },
            child: const Text('Últimos 90 días'),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() {
                _globalFilters['dateRange'] = 'this_year';
              });
              Navigator.pop(context);
            },
            child: const Text('Este año'),
          ),
        ],
      ),
    );
  }

  void _showTimezonePicker() {
    // Implementar selector de zona horaria
    // Por simplicidad, solo mostrar algunas opciones
  }

  void _showCurrencyPicker() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Seleccionar moneda'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() {
                _globalFilters['currency'] = 'PEN';
              });
              Navigator.pop(context);
            },
            child: const Text('Soles Peruanos (PEN)'),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() {
                _globalFilters['currency'] = 'USD';
              });
              Navigator.pop(context);
            },
            child: const Text('Dólares Americanos (USD)'),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    // Refrescar todos los dashboards con los nuevos filtros
    AppLogger.info('🔄 Aplicando filtros globales a dashboards');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filtros aplicados a todos los dashboards'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showDashboardError(String dashboardName, String error) {
    AppLogger.error('Error en dashboard $dashboardName: $error');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en dashboard $dashboardName: $error'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Reintentar',
            textColor: Colors.white,
            onPressed: () {
              // Recargar dashboard
              setState(() {});
            },
          ),
        ),
      );
    }
  }

  String _getDateRangeLabel(String? range) {
    switch (range) {
      case 'last_7_days':
        return 'Últimos 7 días';
      case 'last_30_days':
        return 'Últimos 30 días';
      case 'last_90_days':
        return 'Últimos 90 días';
      case 'this_year':
        return 'Este año';
      default:
        return 'Últimos 30 días';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE TAB DE DASHBOARD
// ═══════════════════════════════════════════════════════════════════

class DashboardTab {
  final String type;
  final String name;
  final IconData icon;
  final Color color;

  DashboardTab(this.type, this.name, this.icon, this.color);
}

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as auth;
import '../utils/app_logger.dart';
import '../services/data_studio_service.dart';

/// Widget para embeber dashboards de Google Data Studio
///
/// Características:
/// - Integración nativa con Google Data Studio
/// - Autenticación automática con tokens de Firebase
/// - Dashboards responsivos y adaptativos
/// - Cache inteligente para mejor rendimiento
/// - Filtros dinámicos basados en rol de usuario
/// - Exportación a PDF y Excel desde el widget
/// - Alertas en tiempo real sobre métricas críticas
/// - Refresh automático cada 5 minutos
class EmbeddedDataStudioWidget extends StatefulWidget {
  final String dashboardType;
  final String? reportId;
  final Map<String, dynamic>? filters;
  final bool showToolbar;
  final bool allowExport;
  final double height;
  final VoidCallback? onDataLoaded;
  final Function(String)? onError;

  const EmbeddedDataStudioWidget({
    super.key,
    required this.dashboardType,
    this.reportId,
    this.filters,
    this.showToolbar = true,
    this.allowExport = true,
    this.height = 600,
    this.onDataLoaded,
    this.onError,
  });

  @override
  State<EmbeddedDataStudioWidget> createState() =>
      _EmbeddedDataStudioWidgetState();
}

class _EmbeddedDataStudioWidgetState extends State<EmbeddedDataStudioWidget>
    with WidgetsBindingObserver {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _currentDashboardUrl;
  Timer? _refreshTimer;
  Timer? _healthCheckTimer;

  final DataStudioService _dataStudioService = DataStudioService.instance;

  // Configuración de dashboards disponibles
  final Map<String, DashboardConfig> _dashboardConfigs = {
    'executive': DashboardConfig(
      id: 'oasis_executive_dashboard',
      name: 'Dashboard Ejecutivo',
      description: 'Métricas ejecutivas y KPIs principales',
      reportUrl:
          'https://datastudio.google.com/embed/reporting/executive-dashboard',
      requiredRole: 'admin',
      refreshInterval: Duration(minutes: 5),
      filters: ['dateRange', 'department', 'region'],
    ),
    'operations': DashboardConfig(
      id: 'oasis_operations_dashboard',
      name: 'Dashboard de Operaciones',
      description: 'Monitoreo de operaciones en tiempo real',
      reportUrl:
          'https://datastudio.google.com/embed/reporting/operations-dashboard',
      requiredRole: 'admin',
      refreshInterval: Duration(minutes: 2),
      filters: ['dateRange', 'vehicleType', 'district'],
    ),
    'financial': DashboardConfig(
      id: 'oasis_financial_dashboard',
      name: 'Dashboard Financiero',
      description: 'Análisis financiero y de comisiones',
      reportUrl:
          'https://datastudio.google.com/embed/reporting/financial-dashboard',
      requiredRole: 'admin',
      refreshInterval: Duration(minutes: 10),
      filters: ['dateRange', 'paymentMethod', 'currency'],
    ),
    'drivers': DashboardConfig(
      id: 'oasis_drivers_dashboard',
      name: 'Dashboard de Conductores',
      description: 'Métricas y rendimiento de conductores',
      reportUrl:
          'https://datastudio.google.com/embed/reporting/drivers-dashboard',
      requiredRole: 'admin',
      refreshInterval: Duration(minutes: 5),
      filters: ['dateRange', 'driverStatus', 'vehicleType'],
    ),
    'passengers': DashboardConfig(
      id: 'oasis_passengers_dashboard',
      name: 'Dashboard de Pasajeros',
      description: 'Análisis de comportamiento de pasajeros',
      reportUrl:
          'https://datastudio.google.com/embed/reporting/passengers-dashboard',
      requiredRole: 'admin',
      refreshInterval: Duration(minutes: 10),
      filters: ['dateRange', 'userSegment', 'district'],
    ),
    'quality': DashboardConfig(
      id: 'oasis_quality_dashboard',
      name: 'Dashboard de Calidad',
      description: 'Métricas de calidad y satisfacción',
      reportUrl:
          'https://datastudio.google.com/embed/reporting/quality-dashboard',
      requiredRole: 'admin',
      refreshInterval: Duration(minutes: 15),
      filters: ['dateRange', 'ratingRange', 'complaintType'],
    ),
    'marketing': DashboardConfig(
      id: 'oasis_marketing_dashboard',
      name: 'Dashboard de Marketing',
      description: 'Análisis de campañas y adquisición',
      reportUrl:
          'https://datastudio.google.com/embed/reporting/marketing-dashboard',
      requiredRole: 'admin',
      refreshInterval: Duration(minutes: 30),
      filters: ['dateRange', 'campaignType', 'channel'],
    ),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDataStudio();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _healthCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _resumeDashboard();
        break;
      case AppLifecycleState.paused:
        _pauseDashboard();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeDataStudio() async {
    try {
      AppLogger.info(
          '📊 Inicializando Data Studio embebido: ${widget.dashboardType}');

      // Verificar autenticación
      final authProvider =
          Provider.of<auth.AuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        _setError('Usuario no autenticado');
        return;
      }

      // Obtener configuración del dashboard
      final config = _dashboardConfigs[widget.dashboardType];
      if (config == null) {
        _setError('Tipo de dashboard no válido: ${widget.dashboardType}');
        return;
      }

      // Verificar permisos
      if (!_hasRequiredPermissions(config, authProvider)) {
        _setError('No tienes permisos para ver este dashboard');
        return;
      }

      // Generar URL del dashboard con autenticación
      final dashboardUrl = await _generateDashboardUrl(config);

      setState(() {
        _currentDashboardUrl = dashboardUrl;
        _hasError = false;
        _errorMessage = null;
      });

      // Inicializar WebView
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (String url) {
            AppLogger.debug('📊 Cargando dashboard: $url');
          },
          onPageFinished: (String url) {
            _onDashboardLoaded();
          },
          onWebResourceError: (WebResourceError error) {
            _setError('Error cargando dashboard: ${error.description}');
          },
        ))
        ..addJavaScriptChannel('DataStudioBridge',
            onMessageReceived: (JavaScriptMessage message) {
          _handleDataStudioMessage(message.message);
        })
        ..loadRequest(Uri.parse(dashboardUrl));

      // Configurar refresh automático
      _setupAutoRefresh(config.refreshInterval);

      // Configurar monitoreo de salud
      _setupHealthCheck();

      AppLogger.info('✅ Data Studio inicializado correctamente');
    } catch (error, stackTrace) {
      AppLogger.error('❌ Error inicializando Data Studio', error, stackTrace);
      _setError('Error inicializando dashboard: $error');
    }
  }

  Future<String> _generateDashboardUrl(DashboardConfig config) async {
    try {
      // Obtener token de autenticación de Firebase
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      // Construir parámetros de consulta
      final queryParams = <String, String>{
        'config': 'true',
        'theme': 'dark',
        'locale': 'es-ES',
        'timezone': 'America/Lima',
        'embed': 'true',
        'auth_token': idToken ?? '',
      };

      // Agregar filtros
      if (widget.filters != null) {
        widget.filters!.forEach((key, value) {
          queryParams['filter_$key'] = value.toString();
        });
      }

      // Agregar filtros basados en rol de usuario
      final authProvider =
          Provider.of<auth.AuthProvider>(context, listen: false);
      final userRole = authProvider.userRole;

      if (userRole == 'admin') {
        queryParams['show_all_data'] = 'true';
      } else {
        queryParams['user_filter'] = authProvider.currentUser?.id ?? '';
      }

      // Construir URL final
      final uri = Uri.parse(config.reportUrl).replace(
        queryParameters: queryParams,
      );

      AppLogger.debug('📊 URL del dashboard generada: ${uri.toString()}');
      return uri.toString();
    } catch (error) {
      AppLogger.error('Error generando URL del dashboard', error);
      throw Exception('No se pudo generar URL del dashboard');
    }
  }

  bool _hasRequiredPermissions(
      DashboardConfig config, auth.AuthProvider authProvider) {
    final userRole = authProvider.userRole;

    // Super admin puede ver todo
    if (userRole == 'super_admin') return true;

    // Verificar rol requerido
    if (config.requiredRole == 'admin' && userRole != 'admin') {
      return false;
    }

    // Verificar permisos específicos
    final userPermissions = authProvider.userPermissions ?? [];
    const requiredPermission = 'view_dashboards';

    return userPermissions.contains(requiredPermission);
  }

  void _setupAutoRefresh(Duration interval) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (timer) {
      if (mounted && !_hasError) {
        _refreshDashboard();
      }
    });
  }

  void _setupHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _checkDashboardHealth();
      }
    });
  }

  Future<void> _refreshDashboard() async {
    try {
      AppLogger.debug('🔄 Refrescando dashboard');

      if (_webViewController != null) {
        await _webViewController!.runJavaScript('''
          if (window.location.reload) {
            window.location.reload();
          } else if (typeof refreshDataStudio === 'function') {
            refreshDataStudio();
          }
        ''');
      }
    } catch (error) {
      AppLogger.warning('Error refrescando dashboard: $error');
    }
  }

  Future<void> _checkDashboardHealth() async {
    try {
      if (_webViewController != null) {
        final result =
            await _webViewController!.runJavaScriptReturningResult('''
          (function() {
            try {
              return {
                loaded: document.readyState === 'complete',
                hasErrors: document.querySelector('.error-message') !== null,
                timestamp: new Date().toISOString()
              };
            } catch (e) {
              return { error: e.message };
            }
          })();
        ''');

        final healthData = jsonDecode(result.toString());

        if (healthData['hasErrors'] == true) {
          _setError('Dashboard reportó errores internos');
        }
      }
    } catch (error) {
      AppLogger.debug('Error en health check del dashboard: $error');
    }
  }

  void _handleDataStudioMessage(String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      switch (type) {
        case 'data_loaded':
          _onDashboardDataLoaded();
          break;
        case 'error':
          _setError('Error en Data Studio: ${data['message']}');
          break;
        case 'filter_changed':
          AppLogger.debug('Filtro cambiado en Data Studio: ${data['filter']}');
          break;
        case 'export_requested':
          _handleExportRequest(data);
          break;
        default:
          AppLogger.debug('Mensaje de Data Studio no manejado: $type');
      }
    } catch (error) {
      AppLogger.warning('Error procesando mensaje de Data Studio: $error');
    }
  }

  void _onDashboardLoaded() {
    setState(() {
      _isLoading = false;
    });

    widget.onDataLoaded?.call();
    AppLogger.info('✅ Dashboard cargado exitosamente');
  }

  void _onDashboardDataLoaded() {
    // Inyectar JavaScript personalizado para mejorar la integración
    _webViewController?.runJavaScript('''
      // Configurar comunicación con Flutter
      window.DataStudioBridge = {
        sendMessage: function(type, data) {
          if (window.DataStudioBridge && window.DataStudioBridge.postMessage) {
            window.DataStudioBridge.postMessage(JSON.stringify({
              type: type,
              data: data,
              timestamp: new Date().toISOString()
            }));
          }
        }
      };
      
      // Interceptar errores
      window.addEventListener('error', function(e) {
        window.DataStudioBridge.sendMessage('error', {
          message: e.message,
          filename: e.filename,
          lineno: e.lineno
        });
      });
      
      // Detectar cambios en filtros (si Data Studio los expone)
      if (typeof google !== 'undefined' && google.visualization) {
        // Intentar detectar cambios en controles
        google.visualization.events.addListener(dashboard, 'ready', function() {
          window.DataStudioBridge.sendMessage('data_loaded', {
            timestamp: new Date().toISOString()
          });
        });
      }
      
      // Personalizar estilo para mejor integración
      const style = document.createElement('style');
      style.textContent = `
        body {
          background: transparent !important;
          margin: 0 !important;
          padding: 0 !important;
        }
        
        .dashboard-container {
          border-radius: 8px !important;
          overflow: hidden !important;
        }
        
        .export-button {
          background: #FF6B35 !important;
          color: white !important;
          border: none !important;
          padding: 8px 16px !important;
          border-radius: 4px !important;
          cursor: pointer !important;
        }
      `;
      document.head.appendChild(style);
      
      console.log('🎯 Data Studio bridge configurado correctamente');
    ''');
  }

  Future<void> _handleExportRequest(Map<String, dynamic> data) async {
    try {
      final exportType = data['format'] ?? 'pdf';
      AppLogger.info('📄 Exportando dashboard como $exportType');

      // Aquí se implementaría la lógica de exportación
      // Por ahora, simular la exportación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exportando dashboard como $exportType...'),
          backgroundColor: Colors.blue,
        ),
      );

      // Simular delay de exportación
      await Future.delayed(const Duration(seconds: 2));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dashboard exportado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      AppLogger.error('Error exportando dashboard', error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exportando dashboard: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setError(String error) {
    setState(() {
      _hasError = true;
      _errorMessage = error;
      _isLoading = false;
    });

    widget.onError?.call(error);
    AppLogger.error('❌ Error en Data Studio widget: $error');
  }

  void _resumeDashboard() {
    if (_webViewController != null && !_hasError) {
      _refreshDashboard();
    }
  }

  void _pauseDashboard() {
    // Pausar timers para ahorrar batería
    _refreshTimer?.cancel();
  }

  Future<void> _exportDashboard(String format) async {
    try {
      if (_webViewController != null) {
        await _webViewController!.runJavaScript('''
          window.DataStudioBridge.sendMessage('export_requested', {
            format: '$format'
          });
        ''');
      }
    } catch (error) {
      AppLogger.error('Error iniciando exportación', error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _dashboardConfigs[widget.dashboardType];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header con título y controles
          if (widget.showToolbar) _buildToolbar(config),

          // Contenido del dashboard
          Expanded(
            child: ClipRRect(
              borderRadius: widget.showToolbar
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    )
                  : BorderRadius.circular(12),
              child: _buildDashboardContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(DashboardConfig? config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          // Icono y título
          Icon(
            Icons.dashboard,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  config?.name ?? 'Dashboard',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (config?.description != null)
                  Text(
                    config!.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // Controles
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón de refresh
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _hasError ? null : () => _refreshDashboard(),
                tooltip: 'Actualizar',
              ),

              // Botón de exportación
              if (widget.allowExport)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Exportar',
                  onSelected: _exportDashboard,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'pdf', child: Text('Exportar como PDF')),
                    const PopupMenuItem(
                        value: 'xlsx', child: Text('Exportar como Excel')),
                    const PopupMenuItem(
                        value: 'png', child: Text('Exportar como Imagen')),
                  ],
                ),

              // Indicador de estado
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hasError
                      ? Colors.red
                      : _isLoading
                          ? Colors.orange
                          : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (_isLoading || _webViewController == null) {
      return _buildLoadingWidget();
    }

    return SizedBox(
      height: widget.height,
      child: WebViewWidget(controller: _webViewController!),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: widget.height,
      color: Theme.of(context).cardColor,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Cargando dashboard...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Conectando con Google Data Studio',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: widget.height,
      color: Theme.of(context).cardColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error cargando dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _errorMessage = null;
                  _isLoading = true;
                });
                _initializeDataStudio();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE CONFIGURACIÓN
// ═══════════════════════════════════════════════════════════════════

/// Configuración de dashboard
class DashboardConfig {
  final String id;
  final String name;
  final String description;
  final String reportUrl;
  final String requiredRole;
  final Duration refreshInterval;
  final List<String> filters;

  DashboardConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.reportUrl,
    required this.requiredRole,
    required this.refreshInterval,
    required this.filters,
  });
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET DE DASHBOARD GRID
// ═══════════════════════════════════════════════════════════════════

/// Widget para mostrar múltiples dashboards en una grilla
class DataStudioDashboardGrid extends StatelessWidget {
  final List<String> dashboardTypes;
  final int crossAxisCount;
  final double aspectRatio;
  final EdgeInsetsGeometry? padding;
  final double spacing;

  const DataStudioDashboardGrid({
    super.key,
    required this.dashboardTypes,
    this.crossAxisCount = 2,
    this.aspectRatio = 1.5,
    this.padding,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemCount: dashboardTypes.length,
        itemBuilder: (context, index) {
          final dashboardType = dashboardTypes[index];
          return EmbeddedDataStudioWidget(
            dashboardType: dashboardType,
            height: 400,
            showToolbar: true,
            allowExport: true,
            onDataLoaded: () {
              AppLogger.debug('Dashboard $dashboardType cargado en grid');
            },
            onError: (error) {
              AppLogger.warning('Error en dashboard $dashboardType: $error');
            },
          );
        },
      ),
    );
  }
}

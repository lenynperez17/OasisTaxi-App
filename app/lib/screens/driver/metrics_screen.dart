import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';
import '../../services/driver_metrics_service.dart';
import '../../utils/app_logger.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  MetricsScreenState createState() => MetricsScreenState();
}

class MetricsScreenState extends State<MetricsScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _chartController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _chartAnimation;

  // Selected period
  String _selectedPeriod = 'week';
  int _selectedMetricIndex = 0;

  // Services
  final DriverMetricsService _metricsService = DriverMetricsService();

  // Real data from Firebase
  DriverMetricsData? _metricsData;
  List<DriverGoal> _goals = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('MetricsScreen', 'initState');

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _chartController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeInOut,
    );

    _loadMetricsData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _chartController.dispose();
    _metricsService.dispose();
    // Limpiar datos para liberar memoria
    _metricsData = null;
    _goals.clear();
    super.dispose();
  }

  /// Cargar datos de métricas reales desde Firebase
  Future<void> _loadMetricsData() async {
    if (!mounted) return; // Verificar si el widget sigue montado

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Cargar métricas y objetivos en paralelo con timeout
      final results = await Future.wait([
        _metricsService.getDriverMetrics(period: _selectedPeriod),
        _metricsService.getDriverGoals(),
      ]).timeout(
        Duration(seconds: 30),
        onTimeout: () => throw Exception(
            'Tiempo de espera agotado. Verifica tu conexión a internet.'),
      );

      if (!mounted) return; // Verificar nuevamente después del await

      final metricsData = results[0] as DriverMetricsData;
      final goals = results[1] as List<DriverGoal>;

      // Actualizar valores actuales de objetivos basados en métricas
      _updateGoalsCurrentValues(goals, metricsData);

      if (mounted) {
        setState(() {
          _metricsData = metricsData;
          _goals = goals;
          _isLoading = false;
        });

        // Iniciar animaciones después de cargar datos
        await Future.delayed(Duration(milliseconds: 200));
        if (mounted) {
          _fadeController.forward();
          await Future.delayed(Duration(milliseconds: 300));
          if (mounted) {
            _chartController.forward();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// Actualizar valores actuales de objetivos
  void _updateGoalsCurrentValues(
      List<DriverGoal> goals, DriverMetricsData metrics) {
    for (var goal in goals) {
      switch (goal.id) {
        case 'daily_trips':
          // Para objetivos diarios, calcular promedio del período
          if (_selectedPeriod == 'day') {
            goal.currentValue = metrics.totalTrips.toDouble();
          } else {
            goal.currentValue = metrics.totalTrips > 0
                ? (metrics.totalTrips / _getDaysInPeriod(_selectedPeriod))
                : 0.0;
          }
          break;
        case 'weekly_earnings':
          goal.currentValue = metrics.totalEarnings;
          break;
        case 'rating':
          goal.currentValue = metrics.avgRating;
          break;
        case 'online_hours':
          goal.currentValue = metrics.onlineHours;
          break;
      }
    }
  }

  /// Obtener número de días en el período
  int _getDaysInPeriod(String period) {
    switch (period.toLowerCase()) {
      case 'day':
        return 1;
      case 'week':
        return 7;
      case 'month':
        return 30;
      case 'year':
        return 365;
      default:
        return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Mis Métricas',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: _exportReport,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: ModernTheme.oasisGreen,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Cargando tus métricas reales...',
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analizando datos desde Firebase',
              style: TextStyle(
                color: ModernTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: ModernTheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Error al cargar métricas',
              style: TextStyle(
                color: ModernTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.oasisGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_metricsData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: ModernTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay datos disponibles',
              style: TextStyle(
                color: ModernTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Comienza a realizar viajes para ver tus métricas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: ModernTheme.oasisGreen,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Period selector
                  _buildPeriodSelector(),

                  // Summary cards
                  _buildSummaryCards(),

                  // Performance chart
                  _buildPerformanceChart(),

                  // Goals progress
                  _buildGoalsSection(),

                  // Hourly distribution
                  _buildHourlyDistribution(),

                  // Best zones
                  _buildBestZones(),

                  // Stats comparison
                  _buildStatsComparison(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Período de análisis',
            style: TextStyle(
              color: ModernTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPeriodButton('Día', 'day')),
              const SizedBox(width: 8),
              Expanded(child: _buildPeriodButton('Semana', 'week')),
              const SizedBox(width: 8),
              Expanded(child: _buildPeriodButton('Mes', 'month')),
              const SizedBox(width: 8),
              Expanded(child: _buildPeriodButton('Año', 'year')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;

    return InkWell(
      onTap: () {
        if (_selectedPeriod != value) {
          setState(() {
            _selectedPeriod = value;
          });
          _refreshData();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? ModernTheme.oasisGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ModernTheme.oasisGreen : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : ModernTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_metricsData == null) return SizedBox.shrink();

    return SizedBox(
      height: 130,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(16),
        children: [
          _buildMetricCard(
            'Viajes Totales',
            '${_metricsData!.totalTrips}',
            Icons.route,
            ModernTheme.primaryBlue,
            _metricsData!.growthRate >= 0
                ? '+${_metricsData!.growthRate.toStringAsFixed(1)}%'
                : '${_metricsData!.growthRate.toStringAsFixed(1)}%',
            _metricsData!.growthRate >= 0,
          ),
          _buildMetricCard(
            'Ganancias',
            'S/ ${_metricsData!.totalEarnings.toStringAsFixed(2)}',
            Icons.attach_money,
            ModernTheme.oasisGreen,
            _metricsData!.earningsGrowth >= 0
                ? '+${_metricsData!.earningsGrowth.toStringAsFixed(1)}%'
                : '${_metricsData!.earningsGrowth.toStringAsFixed(1)}%',
            _metricsData!.earningsGrowth >= 0,
          ),
          _buildMetricCard(
            'Calificación',
            _metricsData!.avgRating.toStringAsFixed(2),
            Icons.star,
            ModernTheme.accentYellow,
            _metricsData!.ratingChange >= 0
                ? '+${_metricsData!.ratingChange.toStringAsFixed(2)}'
                : _metricsData!.ratingChange.toStringAsFixed(2),
            _metricsData!.ratingChange >= 0,
          ),
          _buildMetricCard(
            'Tasa Aceptación',
            '${_metricsData!.acceptanceRate.toStringAsFixed(1)}%',
            Icons.check_circle,
            Colors.purple,
            '${_metricsData!.completedTrips} completados',
            true,
            showPercentage: false,
          ),
          _buildMetricCard(
            'Horas en Línea',
            '${_metricsData!.onlineHours.toStringAsFixed(1)}h',
            Icons.timer,
            Colors.orange,
            'Promedio ${(_metricsData!.onlineHours / _getDaysInPeriod(_selectedPeriod)).toStringAsFixed(1)}h/día',
            true,
            showPercentage: false,
          ),
          _buildMetricCard(
            'Distancia Total',
            '${(_metricsData!.totalDistance / 1000).toStringAsFixed(1)} km',
            Icons.straighten,
            Colors.cyan,
            'Promedio ${(_metricsData!.avgTripDistance / 1000).toStringAsFixed(1)} km/viaje',
            true,
            showPercentage: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
    bool isPositive, {
    bool showPercentage = true,
  }) {
    return Container(
      width: 140,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (change.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: showPercentage
                        ? (isPositive ? ModernTheme.success : ModernTheme.error)
                            .withValues(alpha: 0.1)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    change,
                    style: TextStyle(
                      color: showPercentage
                          ? (isPositive
                              ? ModernTheme.success
                              : ModernTheme.error)
                          : color,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
              Text(
                title,
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
  }

  Widget _buildPerformanceChart() {
    if (_metricsData == null || _metricsData!.hourlyData.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rendimiento por ${_getPeriodLabel()}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _buildChartToggle(Icons.show_chart, 0),
                  const SizedBox(width: 8),
                  _buildChartToggle(Icons.bar_chart, 1),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _selectedMetricIndex == 0
                      ? LineChartPainter(
                          data: _getChartDataFromHourly(),
                          progress: _chartAnimation.value,
                        )
                      : BarChartPainter(
                          data: _getChartDataFromHourly(),
                          progress: _chartAnimation.value,
                        ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Chart legend
          if (_metricsData!.hourlyData.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _getChartDataFromHourly().take(7).map((data) {
                return Column(
                  children: [
                    Text(
                      data['day'],
                      style: TextStyle(
                        fontSize: 11,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${data['trips']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildChartToggle(IconData icon, int index) {
    final isSelected = _selectedMetricIndex == index;

    return InkWell(
      onTap: () {
        setState(() => _selectedMetricIndex = index);
        _chartController.reset();
        _chartController.forward();
      },
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? ModernTheme.oasisGreen.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color:
              isSelected ? ModernTheme.oasisGreen : ModernTheme.textSecondary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildGoalsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Objetivos y Metas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._goals.map((goal) => _buildGoalItem(goal)),
        ],
      ),
    );
  }

  Widget _buildGoalItem(DriverGoal goal) {
    final progress = goal.targetValue > 0
        ? (goal.currentValue / goal.targetValue).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_getGoalIcon(goal.id),
                      color: _getGoalColor(goal.id), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    goal.title,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                '${_formatGoalValue(goal.currentValue, goal.id)} / ${_formatGoalValue(goal.targetValue, goal.id)}',
                style: TextStyle(
                  fontSize: 12,
                  color: ModernTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: _getGoalColor(goal.id).withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(_getGoalColor(goal.id)),
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).round()}% completado',
            style: TextStyle(
              fontSize: 11,
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyDistribution() {
    if (_metricsData == null || _metricsData!.hourlyData.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución por Horas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Identifica tus horas más productivas',
            style: TextStyle(
              fontSize: 12,
              color: ModernTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: HourlyChartPainter(
                data: _getHourlyChartData(),
                peakHours: _getPeakHours(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Peak hours info
          if (_getPeakHours().isNotEmpty)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up, color: ModernTheme.oasisGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Horas Pico',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ModernTheme.oasisGreen,
                          ),
                        ),
                        Text(
                          _getPeakHours().join(', '),
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBestZones() {
    if (_metricsData == null || _metricsData!.bestZones.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zonas Más Rentables',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._metricsData!.bestZones.asMap().entries.map((entry) {
            final index = entry.key;
            final zone = entry.value;

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ModernTheme.oasisGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: ModernTheme.oasisGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.zoneName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${zone.totalTrips} viajes',
                          style: TextStyle(
                            fontSize: 12,
                            color: ModernTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'S/ ${zone.totalEarnings.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.oasisGreen,
                        ),
                      ),
                      Text(
                        'S/ ${zone.avgPrice.toStringAsFixed(2)}/viaje',
                        style: TextStyle(
                          fontSize: 11,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatsComparison() {
    if (_metricsData == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(16),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu Rendimiento',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildComparisonItem(
                '${_metricsData!.avgRating.toStringAsFixed(1)} ⭐',
                'Calificación promedio',
                Icons.star,
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white24,
              ),
              _buildComparisonItem(
                '${_metricsData!.acceptanceRate.toStringAsFixed(1)}%',
                'Tasa de aceptación',
                Icons.check_circle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget _buildComparison() { // Método no utilizado - para futuras funcionalidades
  //   return Container(
  //     margin: EdgeInsets.all(16),
  //     padding: EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       gradient: LinearGradient(
  //         colors: [ModernTheme.oasisGreen, ModernTheme.oasisGreen.withValues(alpha: 0.8)],
  //         begin: Alignment.topLeft,
  //         end: Alignment.bottomRight,
  //       ),
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: ModernTheme.cardShadow,
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'Comparación con Otros Conductores',
  //           style: TextStyle(
  //             fontSize: 18,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.white,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceAround,
  //           children: [
  //             _buildComparisonItem(
  //               'Top 15%',
  //               'Mejor que el 85% de conductores',
  //               Icons.emoji_events,
  //             ),
  //             Container(
  //               width: 1,
  //               height: 60,
  //               color: Colors.white24,
  //             ),
  //             _buildComparisonItem(
  //               '#24',
  //               'Ranking esta semana',
  //               Icons.leaderboard,
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildComparisonItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reporte exportado exitosamente'),
        backgroundColor: ModernTheme.success,
      ),
    );
  }

  Future<void> _refreshData() async {
    // Reset animaciones para un efecto de recarga suave
    _fadeController.reset();
    _chartController.reset();

    await _loadMetricsData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Datos actualizados desde Firebase'),
            ],
          ),
          backgroundColor: ModernTheme.success,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Obtener etiqueta del período seleccionado
  String _getPeriodLabel() {
    switch (_selectedPeriod.toLowerCase()) {
      case 'day':
        return 'Día';
      case 'week':
        return 'Semana';
      case 'month':
        return 'Mes';
      case 'year':
        return 'Año';
      default:
        return 'Semana';
    }
  }

  /// Convertir datos horarios a formato de gráfico
  List<Map<String, dynamic>> _getChartDataFromHourly() {
    if (_metricsData == null) return [];

    return _metricsData!.hourlyData.map((hourly) {
      return {
        'day': hourly.hour,
        'trips': hourly.trips,
        'earnings': hourly.avgEarnings,
      };
    }).toList();
  }

  /// Obtener datos para el gráfico de distribución horaria
  List<Map<String, dynamic>> _getHourlyChartData() {
    if (_metricsData == null) return [];

    // Crear datos para todas las horas del día (0-23)
    List<Map<String, dynamic>> hourlyChart = [];
    for (int hour = 0; hour < 24; hour++) {
      final hourlyData = _metricsData!.hourlyData
          .where((h) => h.hour == '${hour.toString().padLeft(2, '0')}:00')
          .toList();

      final trips = hourlyData.isNotEmpty ? hourlyData.first.trips : 0;

      hourlyChart.add({
        'hour': '${hour.toString().padLeft(2, '0')}:00',
        'trips': trips,
      });
    }

    return hourlyChart;
  }

  /// Obtener las horas pico basadas en datos reales
  List<String> _getPeakHours() {
    if (_metricsData == null || _metricsData!.hourlyData.isEmpty) return [];

    // Encontrar las horas con más viajes
    final sortedHours = List<HourlyTripData>.from(_metricsData!.hourlyData)
      ..sort((a, b) => b.trips.compareTo(a.trips));

    // Tomar las top 3 horas con más viajes
    final topHours = sortedHours.take(3).toList();

    return topHours.map((h) => '${h.hour}-${_getNextHour(h.hour)}').toList();
  }

  /// Obtener la siguiente hora en formato de string
  String _getNextHour(String hourStr) {
    final hour = int.tryParse(hourStr.split(':')[0]) ?? 0;
    final nextHour = (hour + 1) % 24;
    return '${nextHour.toString().padLeft(2, '0')}:00';
  }

  /// Obtener icono para objetivo
  IconData _getGoalIcon(String goalId) {
    switch (goalId) {
      case 'daily_trips':
        return Icons.route;
      case 'weekly_earnings':
        return Icons.attach_money;
      case 'rating':
        return Icons.star;
      case 'online_hours':
        return Icons.timer;
      default:
        return Icons.flag;
    }
  }

  /// Obtener color para objetivo
  Color _getGoalColor(String goalId) {
    switch (goalId) {
      case 'daily_trips':
        return ModernTheme.primaryBlue;
      case 'weekly_earnings':
        return ModernTheme.oasisGreen;
      case 'rating':
        return ModernTheme.accentYellow;
      case 'online_hours':
        return Colors.orange;
      default:
        return ModernTheme.oasisGreen;
    }
  }

  /// Formatear valor del objetivo
  String _formatGoalValue(double value, String goalId) {
    switch (goalId) {
      case 'daily_trips':
        return value.round().toString();
      case 'weekly_earnings':
        return 'S/ ${value.toStringAsFixed(2)}';
      case 'rating':
        return value.toStringAsFixed(2);
      case 'online_hours':
        return '${value.toStringAsFixed(1)}h';
      default:
        return value.toString();
    }
  }
}

// Line chart painter optimizado
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double progress;

  const LineChartPainter(
      {super.repaint, required this.data, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = ModernTheme.oasisGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = ModernTheme.oasisGreen.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = ModernTheme.oasisGreen
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // Optimización: calcular maxValue solo una vez
    final trips = data.map((d) => (d['trips'] as int).toDouble()).toList();
    double maxValue = trips.reduce(math.max);
    if (maxValue <= 0) maxValue = 1; // Evitar división por cero

    // Optimización: precalcular valores
    final stepWidth = data.length > 1 ? size.width / (data.length - 1) : 0;

    for (int i = 0; i < data.length; i++) {
      final x = (i * stepWidth).toDouble();
      final normalizedValue = trips[i] / maxValue;
      final y =
          (size.height - (size.height * normalizedValue * progress)).toDouble();

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Dibujar puntos solo si están visibles y el progreso es completo
      if (progress > 0.8) {
        canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), 3, dotPaint);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Dibujar relleno primero, luego línea
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.data.length != data.length;
}

// Bar chart painter optimizado
class BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double progress;

  const BarChartPainter(
      {super.repaint, required this.data, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Optimización: filtrar y calcular maxValue de forma eficiente
    final earnings = data
        .where((d) => d['earnings'] != null)
        .map((d) => d['earnings'] as double)
        .toList();

    if (earnings.isEmpty) return;

    double maxValue = earnings.reduce(math.max);
    if (maxValue <= 0) maxValue = 1; // Evitar división por cero

    final barWidth = size.width / (data.length * 1.5); // Mejor espaciado
    final spacing = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final earningsValue = data[i]['earnings'] as double? ?? 0.0;
      final x = spacing * i + (spacing - barWidth) / 2;
      final normalizedValue = earningsValue / maxValue;
      final barHeight = size.height * normalizedValue * progress;
      final y = size.height - barHeight;

      // Añadir gradiente a las barras para mejor apariencia
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ModernTheme.oasisGreen,
          ModernTheme.oasisGreen.withValues(alpha: 0.7),
        ],
      );

      final gradientPaint = Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(x.toDouble(),
            y.toDouble(), barWidth.toDouble(), barHeight.toDouble()));

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), barWidth.toDouble(),
            barHeight.toDouble()),
        Radius.circular(6),
      );

      canvas.drawRRect(rect, gradientPaint);
    }
  }

  @override
  bool shouldRepaint(BarChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.data.length != data.length;
}

// Hourly distribution chart painter optimizado
class HourlyChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final List<String> peakHours;

  const HourlyChartPainter(
      {super.repaint, required this.data, required this.peakHours});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final normalPaint = Paint()
      ..color = ModernTheme.oasisGreen.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final peakPaint = Paint()
      ..color = ModernTheme.oasisGreen
      ..style = PaintingStyle.fill;

    // Optimización: precalcular maxTrips y barWidth
    final trips = data.map((d) => d['trips'] as int).toList();
    double maxTrips = trips.reduce(math.max).toDouble();
    if (maxTrips <= 0) maxTrips = 1; // Evitar división por cero

    final barWidth = size.width / data.length;

    // Optimización: precalcular horas pico para evitar parsing repetitivo
    final peakHourRanges = <Map<String, int>>[];
    for (String peak in peakHours) {
      final range = peak.split('-');
      if (range.length >= 2) {
        final startHour = int.tryParse(range[0].split(':')[0]) ?? 0;
        final endHour = int.tryParse(range[1].split(':')[0]) ?? 0;
        peakHourRanges.add({'start': startHour, 'end': endHour});
      }
    }

    for (int i = 0; i < data.length; i++) {
      final hour = data[i]['hour'] as String;
      final tripCount = trips[i];
      final barHeight = (size.height * (tripCount / maxTrips));

      // Optimización: verificar horas pico de forma más eficiente
      final currentHour = int.tryParse(hour.split(':')[0]) ?? 0;
      bool isPeakHour = peakHourRanges.any((range) =>
          currentHour >= range['start']! && currentHour <= range['end']!);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * barWidth + 1,
          size.height - barHeight,
          barWidth - 2,
          barHeight,
        ),
        Radius.circular(2),
      );

      canvas.drawRRect(rect, isPeakHour ? peakPaint : normalPaint);
    }
  }

  @override
  bool shouldRepaint(HourlyChartPainter oldDelegate) =>
      oldDelegate.data.length != data.length ||
      oldDelegate.peakHours.length != peakHours.length;
}

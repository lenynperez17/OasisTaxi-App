// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  _MetricsScreenState createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> 
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _chartController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _chartAnimation;
  
  // Selected period
  String _selectedPeriod = 'week';
  int _selectedMetricIndex = 0;
  
  // Metrics data
  final Map<String, dynamic> _currentMetrics = {
    'totalTrips': 142,
    'totalEarnings': 3456.78,
    'avgRating': 4.85,
    'acceptanceRate': 92.5,
    'cancellationRate': 2.3,
    'onlineHours': 186.5,
    'totalDistance': 1842.5,
    'peakHours': ['07:00-09:00', '18:00-20:00'],
    'bestZones': ['Centro', 'Miraflores', 'San Isidro'],
  };
  
  final Map<String, dynamic> _comparisons = {
    'tripsGrowth': 12.5,
    'earningsGrowth': 18.3,
    'ratingChange': 0.15,
    'acceptanceChange': 2.1,
  };
  
  final List<Map<String, dynamic>> _weeklyData = [
    {'day': 'Lun', 'trips': 18, 'earnings': 425.50, 'hours': 9.5, 'rating': 4.8},
    {'day': 'Mar', 'trips': 22, 'earnings': 512.00, 'hours': 10.2, 'rating': 4.9},
    {'day': 'Mié', 'trips': 20, 'earnings': 468.75, 'hours': 9.8, 'rating': 4.7},
    {'day': 'Jue', 'trips': 25, 'earnings': 587.25, 'hours': 11.0, 'rating': 4.9},
    {'day': 'Vie', 'trips': 28, 'earnings': 645.80, 'hours': 12.5, 'rating': 4.8},
    {'day': 'Sáb', 'trips': 15, 'earnings': 398.90, 'hours': 7.5, 'rating': 4.9},
    {'day': 'Dom', 'trips': 14, 'earnings': 418.58, 'hours': 8.0, 'rating': 4.85},
  ];
  
  final List<Map<String, dynamic>> _hourlyDistribution = [
    {'hour': '00:00', 'trips': 2, 'avg': 28.50},
    {'hour': '01:00', 'trips': 1, 'avg': 25.00},
    {'hour': '02:00', 'trips': 0, 'avg': 0},
    {'hour': '03:00', 'trips': 0, 'avg': 0},
    {'hour': '04:00', 'trips': 1, 'avg': 22.00},
    {'hour': '05:00', 'trips': 3, 'avg': 18.50},
    {'hour': '06:00', 'trips': 8, 'avg': 15.75},
    {'hour': '07:00', 'trips': 15, 'avg': 16.25},
    {'hour': '08:00', 'trips': 18, 'avg': 17.50},
    {'hour': '09:00', 'trips': 12, 'avg': 18.00},
    {'hour': '10:00', 'trips': 8, 'avg': 20.25},
    {'hour': '11:00', 'trips': 6, 'avg': 22.50},
    {'hour': '12:00', 'trips': 9, 'avg': 19.75},
    {'hour': '13:00', 'trips': 10, 'avg': 18.50},
    {'hour': '14:00', 'trips': 7, 'avg': 21.00},
    {'hour': '15:00', 'trips': 6, 'avg': 23.25},
    {'hour': '16:00', 'trips': 8, 'avg': 24.50},
    {'hour': '17:00', 'trips': 11, 'avg': 25.75},
    {'hour': '18:00', 'trips': 16, 'avg': 26.50},
    {'hour': '19:00', 'trips': 14, 'avg': 27.25},
    {'hour': '20:00', 'trips': 12, 'avg': 28.00},
    {'hour': '21:00', 'trips': 9, 'avg': 29.50},
    {'hour': '22:00', 'trips': 6, 'avg': 31.00},
    {'hour': '23:00', 'trips': 4, 'avg': 32.50},
  ];
  
  final List<Map<String, dynamic>> _goals = [
    {
      'title': 'Viajes Diarios',
      'current': 20,
      'target': 25,
      'icon': Icons.route,
      'color': ModernTheme.primaryBlue,
    },
    {
      'title': 'Ganancias Semanales',
      'current': 3456.78,
      'target': 4000.00,
      'icon': Icons.attach_money,
      'color': ModernTheme.oasisGreen,
    },
    {
      'title': 'Calificación',
      'current': 4.85,
      'target': 5.0,
      'icon': Icons.star,
      'color': ModernTheme.accentYellow,
    },
    {
      'title': 'Horas en Línea',
      'current': 45,
      'target': 50,
      'icon': Icons.timer,
      'color': Colors.purple,
    },
  ];
  
  @override
  void initState() {
    super.initState();
    
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
    
    _fadeController.forward();
    _chartController.forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _chartController.dispose();
    super.dispose();
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
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
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
                  
                  // Comparison with others
                  _buildComparison(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodButton('Día', 'day'),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildPeriodButton('Semana', 'week'),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildPeriodButton('Mes', 'month'),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildPeriodButton('Año', 'year'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    
    return InkWell(
      onTap: () => setState(() => _selectedPeriod = value),
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
          ),
        ),
      ),
    );
  }
  
  Widget _buildSummaryCards() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(16),
        children: [
          _buildMetricCard(
            'Viajes',
            '${_currentMetrics['totalTrips']}',
            Icons.route,
            ModernTheme.primaryBlue,
            '+${_comparisons['tripsGrowth']}%',
            true,
          ),
          _buildMetricCard(
            'Ganancias',
            'S/ ${_currentMetrics['totalEarnings']}',
            Icons.attach_money,
            ModernTheme.oasisGreen,
            '+${_comparisons['earningsGrowth']}%',
            true,
          ),
          _buildMetricCard(
            'Calificación',
            '${_currentMetrics['avgRating']}',
            Icons.star,
            ModernTheme.accentYellow,
            '+${_comparisons['ratingChange']}',
            true,
          ),
          _buildMetricCard(
            'Aceptación',
            '${_currentMetrics['acceptanceRate']}%',
            Icons.check_circle,
            Colors.purple,
            '+${_comparisons['acceptanceChange']}%',
            true,
          ),
          _buildMetricCard(
            'Horas',
            '${_currentMetrics['onlineHours']}h',
            Icons.timer,
            Colors.orange,
            '',
            false,
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
    bool showChange,
  ) {
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
              if (showChange && change.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ModernTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    change,
                    style: TextStyle(
                      color: ModernTheme.success,
                      fontSize: 10,
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
                'Rendimiento Semanal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _buildChartToggle(Icons.show_chart, 0),
                  SizedBox(width: 8),
                  _buildChartToggle(Icons.bar_chart, 1),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _selectedMetricIndex == 0
                      ? LineChartPainter(
                          data: _weeklyData,
                          progress: _chartAnimation.value,
                        )
                      : BarChartPainter(
                          data: _weeklyData,
                          progress: _chartAnimation.value,
                        ),
                );
              },
            ),
          ),
          
          SizedBox(height: 16),
          
          // Chart legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _weeklyData.map((data) {
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
          color: isSelected ? ModernTheme.oasisGreen.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? ModernTheme.oasisGreen : ModernTheme.textSecondary,
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
          SizedBox(height: 16),
          
          ..._goals.map((goal) => _buildGoalItem(goal)),
        ],
      ),
    );
  }
  
  Widget _buildGoalItem(Map<String, dynamic> goal) {
    final progress = (goal['current'] / goal['target']).clamp(0.0, 1.0);
    
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
                  Icon(goal['icon'], color: goal['color'], size: 20),
                  SizedBox(width: 8),
                  Text(
                    goal['title'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                '${goal['current']} / ${goal['target']}',
                style: TextStyle(
                  fontSize: 12,
                  color: ModernTheme.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          
          LinearProgressIndicator(
            value: progress,
            backgroundColor: goal['color'].withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(goal['color']),
            minHeight: 6,
          ),
          
          SizedBox(height: 4),
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
          SizedBox(height: 8),
          Text(
            'Identifica tus horas más productivas',
            style: TextStyle(
              fontSize: 12,
              color: ModernTheme.textSecondary,
            ),
          ),
          SizedBox(height: 16),
          
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: HourlyChartPainter(
                data: _hourlyDistribution,
                peakHours: _currentMetrics['peakHours'],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Peak hours info
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: ModernTheme.oasisGreen),
                SizedBox(width: 12),
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
                        (_currentMetrics['peakHours'] as List).join(', '),
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
          SizedBox(height: 16),
          
          ...(_currentMetrics['bestZones'] as List).asMap().entries.map((entry) {
            final index = entry.key;
            final zone = entry.value;
            final earnings = [850.50, 720.25, 615.75][index];
            final trips = [35, 28, 22][index];
            
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
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '$trips viajes',
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
                        'S/ $earnings',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.oasisGreen,
                        ),
                      ),
                      Text(
                        'S/ ${(earnings / trips).toStringAsFixed(2)}/viaje',
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
  
  Widget _buildComparison() {
    return Container(
      margin: EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparación con Otros Conductores',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildComparisonItem(
                'Top 15%',
                'Mejor que el 85% de conductores',
                Icons.emoji_events,
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white24,
              ),
              _buildComparisonItem(
                '#24',
                'Ranking esta semana',
                Icons.leaderboard,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildComparisonItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        SizedBox(height: 8),
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
  
  void _refreshData() {
    setState(() {
      _chartController.reset();
      _chartController.forward();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Datos actualizados'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
}

// Line chart painter
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double progress;
  
  const LineChartPainter({super.repaint, required this.data, required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernTheme.oasisGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final fillPaint = Paint()
      ..color = ModernTheme.oasisGreen.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    
    final dotPaint = Paint()
      ..color = ModernTheme.oasisGreen
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final fillPath = Path();
    
    double maxValue = data.map((d) => d['trips'] as int).reduce(math.max).toDouble();
    
    for (int i = 0; i < data.length; i++) {
      final x = (size.width / (data.length - 1)) * i;
      final y = size.height - (size.height * (data[i]['trips'] / maxValue) * progress);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      
      // Draw dots
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
    
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(LineChartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Bar chart painter
class BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double progress;
  
  const BarChartPainter({super.repaint, required this.data, required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernTheme.oasisGreen
      ..style = PaintingStyle.fill;
    
    double maxValue = data.map((d) => d['earnings'] as double).reduce(math.max);
    final barWidth = size.width / (data.length * 2);
    
    for (int i = 0; i < data.length; i++) {
      final x = (size.width / data.length) * i + barWidth / 2;
      final barHeight = (size.height * (data[i]['earnings'] / maxValue) * progress);
      final y = size.height - barHeight;
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(4),
      );
      
      canvas.drawRRect(rect, paint);
    }
  }
  
  @override
  bool shouldRepaint(BarChartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Hourly distribution chart painter
class HourlyChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final List<String> peakHours;
  
  const HourlyChartPainter({super.repaint, required this.data, required this.peakHours});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;
    
    double maxTrips = data.map((d) => d['trips'] as int).reduce(math.max).toDouble();
    final barWidth = size.width / data.length;
    
    for (int i = 0; i < data.length; i++) {
      final hour = data[i]['hour'] as String;
      final trips = data[i]['trips'] as int;
      final barHeight = (size.height * (trips / maxTrips));
      
      // Check if it's a peak hour
      bool isPeakHour = false;
      for (String peak in peakHours) {
        final range = peak.split('-');
        final startHour = int.parse(range[0].split(':')[0]);
        final endHour = int.parse(range[1].split(':')[0]);
        final currentHour = int.parse(hour.split(':')[0]);
        
        if (currentHour >= startHour && currentHour <= endHour) {
          isPeakHour = true;
          break;
        }
      }
      
      paint.color = isPeakHour 
          ? ModernTheme.oasisGreen 
          : ModernTheme.oasisGreen.withValues(alpha: 0.3);
      
      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - barHeight,
        barWidth - 1,
        barHeight,
      );
      
      canvas.drawRect(rect, paint);
    }
  }
  
  @override
  bool shouldRepaint(HourlyChartPainter oldDelegate) => false;
}
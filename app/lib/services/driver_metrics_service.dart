import '../utils/app_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

/// SERVICIO DE MÉTRICAS REALES DEL CONDUCTOR - OASIS TAXI
/// ======================================================
///
/// Funcionalidades implementadas:
/// 📊 Cálculo de métricas en tiempo real desde Firebase
/// 🚗 Estadísticas personalizadas por conductor
/// 📈 Análisis de rendimiento y ganancias reales
/// ⏰ Métricas por períodos (día, semana, mes, año)
/// 🎯 Objetivos y metas personalizables
/// 📍 Análisis de zonas más rentables
/// 🔄 Cache inteligente para optimización
/// 📱 Notificaciones de logros y alertas
class DriverMetricsService {
  static final DriverMetricsService _instance =
      DriverMetricsService._internal();
  factory DriverMetricsService() => _instance;
  DriverMetricsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache para métricas calculadas
  final Map<String, DriverMetricsData> _metricsCache = {};
  DateTime? _lastCacheUpdate;
  static const int _cacheValidityMinutes = 5; // Cache válido por 5 minutos

  /// Obtener métricas completas del conductor actual
  Future<DriverMetricsData> getDriverMetrics({
    required String period,
    bool forceRefresh = false,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuario no autenticado');
    }

    final cacheKey = '${currentUser.uid}_$period';

    // Verificar cache válido
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      return _metricsCache[cacheKey]!;
    }

    try {
      // Calcular fechas del período
      final dateRange = _calculateDateRange(period);

      // Obtener datos del conductor
      final driverDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!driverDoc.exists) {
        throw Exception('Datos del conductor no encontrados');
      }

      // Obtener todos los viajes del conductor en el período
      final ridesQuery = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: currentUser.uid)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      // Calcular métricas
      final metrics = await _calculateMetrics(ridesQuery.docs, period);

      // Actualizar cache
      _metricsCache[cacheKey] = metrics;
      _lastCacheUpdate = DateTime.now();

      return metrics;
    } catch (e) {
      AppLogger.error('obteniendo métricas del conductor', e);
      rethrow;
    }
  }

  /// Calcular todas las métricas basadas en los datos reales
  Future<DriverMetricsData> _calculateMetrics(
    List<QueryDocumentSnapshot> ridesDocs,
    String period,
  ) async {
    int totalTrips = ridesDocs.length;
    double totalEarnings = 0.0;
    double totalDistance = 0.0;
    double totalDuration = 0.0;
    int completedTrips = 0;
    int cancelledTrips = 0;
    int acceptedTrips = 0;
    // int rejectedTrips = 0; // Comentado porque no se usa actualmente
    double totalRating = 0.0;
    int ratedTrips = 0;
    double totalOnlineHours = 0.0;

    // Mapas para análisis temporal
    Map<int, int> tripsByHour = {};
    Map<String, int> tripsByDay = {};
    Map<String, ZoneStats> zoneStats = {};

    // Procesar cada viaje
    for (var doc in ridesDocs) {
      final data = doc.data() as Map<String, dynamic>;

      // Estadísticas básicas
      if (data['status'] == 'completed') {
        completedTrips++;

        if (data['fare'] != null) {
          totalEarnings += (data['fare'] as num).toDouble();
        }

        if (data['distance'] != null) {
          totalDistance += (data['distance'] as num).toDouble();
        }

        if (data['duration'] != null) {
          totalDuration += (data['duration'] as num).toDouble();
        }

        if (data['rating'] != null) {
          totalRating += (data['rating'] as num).toDouble();
          ratedTrips++;
        }
      } else if (data['status'] == 'cancelled') {
        cancelledTrips++;
      }

      // Análisis temporal
      if (data['createdAt'] != null) {
        final tripDate = (data['createdAt'] as Timestamp).toDate();
        final hour = tripDate.hour;
        final dayName = _getDayName(tripDate.weekday);

        tripsByHour[hour] = (tripsByHour[hour] ?? 0) + 1;
        tripsByDay[dayName] = (tripsByDay[dayName] ?? 0) + 1;
      }

      // Análisis de zonas
      if (data['pickupZone'] != null) {
        final zone = data['pickupZone'] as String;
        if (!zoneStats.containsKey(zone)) {
          zoneStats[zone] = ZoneStats(
            zoneName: zone,
            totalTrips: 0,
            totalEarnings: 0.0,
          );
        }

        zoneStats[zone]!.totalTrips++;
        if (data['status'] == 'completed' && data['fare'] != null) {
          zoneStats[zone]!.totalEarnings += (data['fare'] as num).toDouble();
        }
      }
    }

    // Obtener horas en línea desde colección driver_sessions
    totalOnlineHours = await _calculateOnlineHours(period);

    // Encontrar hora pico
    int peakHour = 0;
    int maxTrips = 0;
    tripsByHour.forEach((hour, trips) {
      if (trips > maxTrips) {
        maxTrips = trips;
        peakHour = hour;
      }
    });

    // Encontrar día más ocupado
    String busiestDay = 'N/A';
    int maxDayTrips = 0;
    tripsByDay.forEach((day, trips) {
      if (trips > maxDayTrips) {
        maxDayTrips = trips;
        busiestDay = day;
      }
    });

    // Calcular promedios
    final avgRating = ratedTrips > 0 ? totalRating / ratedTrips : 0.0;
    final avgTripEarnings =
        completedTrips > 0 ? totalEarnings / completedTrips : 0.0;
    final avgTripDistance =
        completedTrips > 0 ? totalDistance / completedTrips : 0.0;
    final avgTripDuration =
        completedTrips > 0 ? totalDuration / completedTrips : 0.0;

    // Calcular tasas
    final acceptanceRate =
        totalTrips > 0 ? (acceptedTrips / totalTrips) * 100 : 0.0;
    final cancellationRate =
        totalTrips > 0 ? (cancelledTrips / totalTrips) * 100 : 0.0;
    final completionRate =
        totalTrips > 0 ? (completedTrips / totalTrips) * 100 : 0.0;

    // Crear datos de horas ordenados
    final hourlyData = List.generate(
        24,
        (hour) => HourlyTripData(
              hour: '${hour.toString().padLeft(2, '0')}:00',
              trips: tripsByHour[hour] ?? 0,
              avgEarnings: _calculateAvgEarningsForHour(ridesDocs, hour),
            ));

    // Preparar mejores zonas (top 5)
    final sortedZones = zoneStats.values.toList()
      ..sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));
    final bestZones = sortedZones.take(5).toList();

    // Calcular crecimiento comparado con período anterior
    final growthData = await _calculateGrowthRate(period);

    return DriverMetricsData(
      totalTrips: totalTrips,
      completedTrips: completedTrips,
      totalEarnings: totalEarnings,
      avgRating: avgRating,
      acceptanceRate: acceptanceRate,
      cancellationRate: cancellationRate,
      completionRate: completionRate,
      onlineHours: totalOnlineHours,
      totalDistance: totalDistance,
      avgTripEarnings: avgTripEarnings,
      avgTripDistance: avgTripDistance,
      avgTripDuration: avgTripDuration,
      peakHour:
          '${peakHour.toString().padLeft(2, '0')}:00-${(peakHour + 1).toString().padLeft(2, '0')}:00',
      busiestDay: busiestDay,
      hourlyData: hourlyData,
      bestZones: bestZones,
      growthRate: growthData.tripGrowth,
      earningsGrowth: growthData.earningsGrowth,
      ratingChange: growthData.ratingChange,
      period: period,
      lastUpdated: DateTime.now(),
    );
  }

  /// Calcular horas en línea del conductor
  Future<double> _calculateOnlineHours(String period) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0.0;

    try {
      final dateRange = _calculateDateRange(period);

      final sessionsQuery = await _firestore
          .collection('driver_sessions')
          .where('driverId', isEqualTo: currentUser.uid)
          .where('startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('startTime',
              isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .get();

      double totalHours = 0.0;

      for (var doc in sessionsQuery.docs) {
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();
        final endTime = data['endTime'] != null
            ? (data['endTime'] as Timestamp).toDate()
            : DateTime.now();

        final duration = endTime.difference(startTime);
        totalHours += duration.inMinutes / 60.0;
      }

      return totalHours;
    } catch (e) {
      AppLogger.error('calculando horas en línea', e);
      return 0.0;
    }
  }

  /// Calcular ganancias promedio por hora
  double _calculateAvgEarningsForHour(
      List<QueryDocumentSnapshot> rides, int hour) {
    double totalEarnings = 0.0;
    int tripsInHour = 0;

    for (var doc in rides) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['createdAt'] != null && data['status'] == 'completed') {
        final tripDate = (data['createdAt'] as Timestamp).toDate();
        if (tripDate.hour == hour && data['fare'] != null) {
          totalEarnings += (data['fare'] as num).toDouble();
          tripsInHour++;
        }
      }
    }

    return tripsInHour > 0 ? totalEarnings / tripsInHour : 0.0;
  }

  /// Calcular tasa de crecimiento comparado con período anterior
  Future<GrowthData> _calculateGrowthRate(String period) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return GrowthData(
          tripGrowth: 0.0, earningsGrowth: 0.0, ratingChange: 0.0);
    }

    try {
      final currentRange = _calculateDateRange(period);
      final previousRange = _calculatePreviousPeriodRange(period);

      // Obtener viajes del período anterior
      final previousRidesQuery = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: currentUser.uid)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(previousRange.start))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(previousRange.end))
          .get();

      // Obtener viajes del período actual
      final currentRidesQuery = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: currentUser.uid)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(currentRange.start))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(currentRange.end))
          .get();

      // Calcular métricas de ambos períodos
      final previousTrips = previousRidesQuery.docs.length;
      final currentTrips = currentRidesQuery.docs.length;

      double previousEarnings = 0.0;
      double currentEarnings = 0.0;
      double previousRating = 0.0;
      double currentRating = 0.0;
      int previousRatedTrips = 0;
      int currentRatedTrips = 0;

      // Calcular earnings y ratings anteriores
      for (var doc in previousRidesQuery.docs) {
        final data = doc.data();
        if (data['status'] == 'completed' && data['fare'] != null) {
          previousEarnings += (data['fare'] as num).toDouble();
        }
        if (data['rating'] != null) {
          previousRating += (data['rating'] as num).toDouble();
          previousRatedTrips++;
        }
      }

      // Calcular earnings y ratings actuales
      for (var doc in currentRidesQuery.docs) {
        final data = doc.data();
        if (data['status'] == 'completed' && data['fare'] != null) {
          currentEarnings += (data['fare'] as num).toDouble();
        }
        if (data['rating'] != null) {
          currentRating += (data['rating'] as num).toDouble();
          currentRatedTrips++;
        }
      }

      // Calcular cambios porcentuales
      final tripGrowth = previousTrips > 0
          ? ((currentTrips - previousTrips) / previousTrips) * 100
          : 0.0;

      final earningsGrowth = previousEarnings > 0
          ? ((currentEarnings - previousEarnings) / previousEarnings) * 100
          : 0.0;

      final avgPreviousRating =
          previousRatedTrips > 0 ? previousRating / previousRatedTrips : 0.0;
      final avgCurrentRating =
          currentRatedTrips > 0 ? currentRating / currentRatedTrips : 0.0;
      final ratingChange = avgCurrentRating - avgPreviousRating;

      return GrowthData(
        tripGrowth: tripGrowth,
        earningsGrowth: earningsGrowth,
        ratingChange: ratingChange,
      );
    } catch (e) {
      AppLogger.error('calculando tasa de crecimiento', e);
      return GrowthData(
          tripGrowth: 0.0, earningsGrowth: 0.0, ratingChange: 0.0);
    }
  }

  /// Obtener objetivos del conductor
  Future<List<DriverGoal>> getDriverGoals() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      final goalsDoc = await _firestore
          .collection('driver_goals')
          .doc(currentUser.uid)
          .get();

      if (!goalsDoc.exists) {
        // Crear objetivos por defecto si no existen
        return _createDefaultGoals();
      }

      final data = goalsDoc.data()!;
      final goalsList = data['goals'] as List<dynamic>? ?? [];

      return goalsList
          .map<DriverGoal>((goal) => DriverGoal.fromMap(goal))
          .toList();
    } catch (e) {
      AppLogger.error('obteniendo objetivos del conductor', e);
      return _createDefaultGoals();
    }
  }

  /// Crear objetivos por defecto
  List<DriverGoal> _createDefaultGoals() {
    return [
      DriverGoal(
        id: 'daily_trips',
        title: 'Viajes Diarios',
        targetValue: 25,
        currentValue: 0,
        unit: 'viajes',
        icon: 'route',
        color: '#2196F3',
        period: 'daily',
      ),
      DriverGoal(
        id: 'weekly_earnings',
        title: 'Ganancias Semanales',
        targetValue: 4000,
        currentValue: 0,
        unit: 'soles',
        icon: 'attach_money',
        color: '#4CAF50',
        period: 'weekly',
      ),
      DriverGoal(
        id: 'rating',
        title: 'Calificación Promedio',
        targetValue: 5.0,
        currentValue: 0,
        unit: 'estrellas',
        icon: 'star',
        color: '#FFC107',
        period: 'monthly',
      ),
      DriverGoal(
        id: 'online_hours',
        title: 'Horas en Línea Semanales',
        targetValue: 50,
        currentValue: 0,
        unit: 'horas',
        icon: 'timer',
        color: '#9C27B0',
        period: 'weekly',
      ),
    ];
  }

  /// Verificar si el cache es válido
  bool _isCacheValid(String cacheKey) {
    if (!_metricsCache.containsKey(cacheKey) || _lastCacheUpdate == null) {
      return false;
    }

    final now = DateTime.now();
    final cacheAge = now.difference(_lastCacheUpdate!);
    return cacheAge.inMinutes < _cacheValidityMinutes;
  }

  /// Calcular rango de fechas según el período
  DateRange _calculateDateRange(String period) {
    final now = DateTime.now();

    switch (period.toLowerCase()) {
      case 'day':
      case 'today':
        return DateRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: now,
        );

      case 'month':
        return DateRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );

      case 'year':
        return DateRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        );

      default:
        return DateRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    }
  }

  /// Calcular rango de fechas del período anterior
  DateRange _calculatePreviousPeriodRange(String period) {
    final now = DateTime.now();

    switch (period.toLowerCase()) {
      case 'day':
      case 'today':
        final yesterday = now.subtract(Duration(days: 1));
        return DateRange(
          start: DateTime(yesterday.year, yesterday.month, yesterday.day),
          end: DateTime(
              yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
        );

      case 'week':
        final lastWeekEnd = now.subtract(Duration(days: now.weekday));
        final lastWeekStart = lastWeekEnd.subtract(Duration(days: 6));
        return DateRange(
          start: DateTime(
              lastWeekStart.year, lastWeekStart.month, lastWeekStart.day),
          end: DateTime(
              lastWeekEnd.year, lastWeekEnd.month, lastWeekEnd.day, 23, 59, 59),
        );

      case 'month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
        return DateRange(
          start: lastMonth,
          end: lastMonthEnd,
        );

      case 'year':
        final lastYear = DateTime(now.year - 1, 1, 1);
        final lastYearEnd = DateTime(now.year - 1, 12, 31, 23, 59, 59);
        return DateRange(
          start: lastYear,
          end: lastYearEnd,
        );

      default:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
        return DateRange(
          start: lastMonth,
          end: lastMonthEnd,
        );
    }
  }

  /// Obtener nombre del día
  String _getDayName(int weekday) {
    const dayNames = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    return dayNames[weekday - 1];
  }

  /// Limpiar cache
  void clearCache() {
    _metricsCache.clear();
    _lastCacheUpdate = null;
  }

  /// Dispose del servicio
  void dispose() {
    clearCache();
  }
}

/// Modelo de datos de métricas del conductor
class DriverMetricsData {
  final int totalTrips;
  final int completedTrips;
  final double totalEarnings;
  final double avgRating;
  final double acceptanceRate;
  final double cancellationRate;
  final double completionRate;
  final double onlineHours;
  final double totalDistance;
  final double avgTripEarnings;
  final double avgTripDistance;
  final double avgTripDuration;
  final String peakHour;
  final String busiestDay;
  final List<HourlyTripData> hourlyData;
  final List<ZoneStats> bestZones;
  final double growthRate;
  final double earningsGrowth;
  final double ratingChange;
  final String period;
  final DateTime lastUpdated;

  DriverMetricsData({
    required this.totalTrips,
    required this.completedTrips,
    required this.totalEarnings,
    required this.avgRating,
    required this.acceptanceRate,
    required this.cancellationRate,
    required this.completionRate,
    required this.onlineHours,
    required this.totalDistance,
    required this.avgTripEarnings,
    required this.avgTripDistance,
    required this.avgTripDuration,
    required this.peakHour,
    required this.busiestDay,
    required this.hourlyData,
    required this.bestZones,
    required this.growthRate,
    required this.earningsGrowth,
    required this.ratingChange,
    required this.period,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalTrips': totalTrips,
      'completedTrips': completedTrips,
      'totalEarnings': totalEarnings,
      'avgRating': avgRating,
      'acceptanceRate': acceptanceRate,
      'cancellationRate': cancellationRate,
      'completionRate': completionRate,
      'onlineHours': onlineHours,
      'totalDistance': totalDistance,
      'avgTripEarnings': avgTripEarnings,
      'avgTripDistance': avgTripDistance,
      'avgTripDuration': avgTripDuration,
      'peakHour': peakHour,
      'busiestDay': busiestDay,
      'hourlyData': hourlyData.map((x) => x.toMap()).toList(),
      'bestZones': bestZones.map((x) => x.toMap()).toList(),
      'growthRate': growthRate,
      'earningsGrowth': earningsGrowth,
      'ratingChange': ratingChange,
      'period': period,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  factory DriverMetricsData.fromMap(Map<String, dynamic> map) {
    return DriverMetricsData(
      totalTrips: map['totalTrips']?.toInt() ?? 0,
      completedTrips: map['completedTrips']?.toInt() ?? 0,
      totalEarnings: map['totalEarnings']?.toDouble() ?? 0.0,
      avgRating: map['avgRating']?.toDouble() ?? 0.0,
      acceptanceRate: map['acceptanceRate']?.toDouble() ?? 0.0,
      cancellationRate: map['cancellationRate']?.toDouble() ?? 0.0,
      completionRate: map['completionRate']?.toDouble() ?? 0.0,
      onlineHours: map['onlineHours']?.toDouble() ?? 0.0,
      totalDistance: map['totalDistance']?.toDouble() ?? 0.0,
      avgTripEarnings: map['avgTripEarnings']?.toDouble() ?? 0.0,
      avgTripDistance: map['avgTripDistance']?.toDouble() ?? 0.0,
      avgTripDuration: map['avgTripDuration']?.toDouble() ?? 0.0,
      peakHour: map['peakHour'] ?? '',
      busiestDay: map['busiestDay'] ?? '',
      hourlyData: List<HourlyTripData>.from(
        (map['hourlyData'] as List<dynamic>? ?? []).map<HourlyTripData>(
          (x) => HourlyTripData.fromMap(x),
        ),
      ),
      bestZones: List<ZoneStats>.from(
        (map['bestZones'] as List<dynamic>? ?? []).map<ZoneStats>(
          (x) => ZoneStats.fromMap(x),
        ),
      ),
      growthRate: map['growthRate']?.toDouble() ?? 0.0,
      earningsGrowth: map['earningsGrowth']?.toDouble() ?? 0.0,
      ratingChange: map['ratingChange']?.toDouble() ?? 0.0,
      period: map['period'] ?? '',
      lastUpdated: DateTime.parse(map['lastUpdated']),
    );
  }

  factory DriverMetricsData.fromJson(String source) =>
      DriverMetricsData.fromMap(json.decode(source));
}

/// Datos de viajes por hora
class HourlyTripData {
  final String hour;
  final int trips;
  final double avgEarnings;

  HourlyTripData({
    required this.hour,
    required this.trips,
    required this.avgEarnings,
  });

  Map<String, dynamic> toMap() {
    return {
      'hour': hour,
      'trips': trips,
      'avgEarnings': avgEarnings,
    };
  }

  factory HourlyTripData.fromMap(Map<String, dynamic> map) {
    return HourlyTripData(
      hour: map['hour'] ?? '',
      trips: map['trips']?.toInt() ?? 0,
      avgEarnings: map['avgEarnings']?.toDouble() ?? 0.0,
    );
  }
}

/// Estadísticas de zonas
class ZoneStats {
  final String zoneName;
  int totalTrips;
  double totalEarnings;

  ZoneStats({
    required this.zoneName,
    required this.totalTrips,
    required this.totalEarnings,
  });

  double get avgPrice => totalTrips > 0 ? totalEarnings / totalTrips : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'zoneName': zoneName,
      'totalTrips': totalTrips,
      'totalEarnings': totalEarnings,
    };
  }

  factory ZoneStats.fromMap(Map<String, dynamic> map) {
    return ZoneStats(
      zoneName: map['zoneName'] ?? '',
      totalTrips: map['totalTrips']?.toInt() ?? 0,
      totalEarnings: map['totalEarnings']?.toDouble() ?? 0.0,
    );
  }
}

/// Datos de crecimiento
class GrowthData {
  final double tripGrowth;
  final double earningsGrowth;
  final double ratingChange;

  GrowthData({
    required this.tripGrowth,
    required this.earningsGrowth,
    required this.ratingChange,
  });
}

/// Objetivo del conductor
class DriverGoal {
  final String id;
  final String title;
  final double targetValue;
  double currentValue;
  final String unit;
  final String icon;
  final String color;
  final String period;

  DriverGoal({
    required this.id,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.icon,
    required this.color,
    required this.period,
  });

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
  int get progressPercentage => (progress * 100).round();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      'icon': icon,
      'color': color,
      'period': period,
    };
  }

  factory DriverGoal.fromMap(Map<String, dynamic> map) {
    return DriverGoal(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      targetValue: map['targetValue']?.toDouble() ?? 0.0,
      currentValue: map['currentValue']?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      icon: map['icon'] ?? '',
      color: map['color'] ?? '',
      period: map['period'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory DriverGoal.fromJson(String source) =>
      DriverGoal.fromMap(json.decode(source));
}

/// Rango de fechas
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

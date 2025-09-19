import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Servicio de integración con Data Studio y BigQuery
///
/// Funcionalidades principales:
/// - Exportación de datos a BigQuery
/// - Configuración de dashboards
/// - Métricas en tiempo real para Data Studio
/// - Análisis de cohorts y retención
/// - Reportes automáticos
///
/// Implementa singleton pattern para garantizar una sola instancia
class DataStudioService {
  static DataStudioService? _instance;
  static DataStudioService get instance =>
      _instance ??= DataStudioService._internal();

  DataStudioService._internal();

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Cache para métricas
  final Map<String, dynamic> _metricsCache = {};
  Timer? _cacheRefreshTimer;

  // Configuración
  static const String _cacheKey = 'data_studio_metrics_cache';
  static const Duration _cacheRefreshInterval = Duration(minutes: 5);

  /// Inicializar el servicio
  Future<void> initialize() async {
    try {
      AppLogger.info('🚀 Inicializando DataStudioService');

      // Cargar cache desde SharedPreferences
      await _loadCacheFromStorage();

      // Configurar timer para refrescar métricas
      _setupCacheRefresh();

      // Registrar eventos de Analytics
      await _analytics.logEvent(
        name: 'data_studio_service_initialized',
        parameters: {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'version': '1.0.0',
        },
      );

      AppLogger.info('✅ DataStudioService inicializado correctamente');
    } catch (error, stackTrace) {
      AppLogger.error(
          '❌ Error inicializando DataStudioService', error, stackTrace);
      rethrow;
    }
  }

  /// Obtener métricas de negocio en tiempo real
  Future<BusinessMetrics> getBusinessMetrics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 1));
      final end = endDate ?? DateTime.now();

      AppLogger.info('📊 Obteniendo métricas de negocio: $start - $end');

      // Verificar cache primero
      final cacheKey =
          'business_metrics_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';
      if (_metricsCache.containsKey(cacheKey)) {
        AppLogger.debug('📋 Usando métricas desde cache');
        return BusinessMetrics.fromJson(_metricsCache[cacheKey]);
      }

      // Consultar Firestore para obtener datos
      final tripsQuery = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      // Procesar datos
      final completedTrips = tripsQuery.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .toList();
      final totalRevenue = completedTrips.fold<double>(
          0.0, (sum, doc) => sum + (doc.data()['finalPrice'] ?? 0.0));
      final avgRating = await _calculateAverageRating(start, end);
      final activeDrivers = await _countActiveDrivers(start, end);

      final metrics = BusinessMetrics(
        totalTrips: tripsQuery.docs.length,
        completedTrips: completedTrips.length,
        totalRevenue: totalRevenue,
        averageRating: avgRating,
        activeDrivers: activeDrivers,
        cancelledTrips: tripsQuery.docs
            .where((doc) => doc.data()['status'] == 'cancelled')
            .length,
        inProgressTrips: tripsQuery.docs
            .where((doc) => doc.data()['status'] == 'in_progress')
            .length,
        conversionRate: completedTrips.length / tripsQuery.docs.length,
        revenuePerTrip:
            completedTrips.isEmpty ? 0.0 : totalRevenue / completedTrips.length,
        timestamp: DateTime.now(),
        dateRange: DateRange(start: start, end: end),
      );

      // Guardar en cache
      _metricsCache[cacheKey] = metrics.toJson();
      await _saveCacheToStorage();

      // Log analytics
      await _analytics.logEvent(
        name: 'business_metrics_calculated',
        parameters: {
          'total_trips': metrics.totalTrips,
          'total_revenue': metrics.totalRevenue,
          'date_range_days': end.difference(start).inDays,
        },
      );

      AppLogger.info('✅ Métricas de negocio calculadas correctamente');
      return metrics;
    } catch (error, stackTrace) {
      AppLogger.error(
          '❌ Error obteniendo métricas de negocio', error, stackTrace);
      rethrow;
    }
  }

  /// Obtener análisis de conductores
  Future<DriverAnalytics> getDriverAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();

      AppLogger.info('🚗 Obteniendo análisis de conductores');

      // Consultar trips por conductor
      final tripsQuery = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('status', isEqualTo: 'completed')
          .get();

      // Agrupar por conductor
      final Map<String, List<DocumentSnapshot>> tripsByDriver = {};
      for (final doc in tripsQuery.docs) {
        final driverId = doc.data()['driverId'] as String?;
        if (driverId != null) {
          tripsByDriver.putIfAbsent(driverId, () => []).add(doc);
        }
      }

      // Calcular métricas por conductor
      final List<DriverMetrics> driverMetrics = [];
      for (final entry in tripsByDriver.entries) {
        final driverId = entry.key;
        final trips = entry.value;

        final totalEarnings = trips.fold<double>(
            0.0,
            (sum, doc) =>
                sum +
                ((doc.data() as Map<String, dynamic>)['finalPrice'] ?? 0.0));
        final avgRating =
            await _calculateDriverAverageRating(driverId, start, end);

        // Obtener datos del conductor
        final driverDoc =
            await _firestore.collection('users').doc(driverId).get();
        final driverData = driverDoc.data();

        driverMetrics.add(DriverMetrics(
          driverId: driverId,
          driverName: driverData?['displayName'] ?? 'Conductor $driverId',
          totalTrips: trips.length,
          totalEarnings: totalEarnings,
          driverShare: totalEarnings * 0.8, // 80% para conductor
          averageRating: avgRating,
          completionRate:
              1.0, // Todos los trips en esta consulta están completed
          cancellationCount:
              await _getDriverCancellations(driverId, start, end),
        ));
      }

      // Ordenar por ganancias
      driverMetrics.sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));

      final analytics = DriverAnalytics(
        totalActiveDrivers: driverMetrics.length,
        topDrivers: driverMetrics.take(limit).toList(),
        averageTripsPerDriver: driverMetrics.isEmpty
            ? 0.0
            : driverMetrics.map((d) => d.totalTrips).reduce((a, b) => a + b) /
                driverMetrics.length,
        averageEarningsPerDriver: driverMetrics.isEmpty
            ? 0.0
            : driverMetrics
                    .map((d) => d.totalEarnings)
                    .reduce((a, b) => a + b) /
                driverMetrics.length,
        averageRating: driverMetrics.isEmpty
            ? 0.0
            : driverMetrics
                    .map((d) => d.averageRating)
                    .reduce((a, b) => a + b) /
                driverMetrics.length,
        timestamp: DateTime.now(),
        dateRange: DateRange(start: start, end: end),
      );

      AppLogger.info(
          '✅ Análisis de conductores completado: ${analytics.totalActiveDrivers} conductores');
      return analytics;
    } catch (error, stackTrace) {
      AppLogger.error('❌ Error en análisis de conductores', error, stackTrace);
      rethrow;
    }
  }

  /// Obtener análisis de experiencia de usuario
  Future<UserExperienceMetrics> getUserExperienceMetrics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      AppLogger.info('📱 Calculando métricas de experiencia de usuario');

      // NPS Score
      final npsScore = await _calculateNPSScore(start, end);

      // Embudo de conversión
      final conversionFunnel = await _calculateConversionFunnel(start, end);

      // Razones de cancelación
      final cancellationReasons = await _getCancellationReasons(start, end);

      // Tiempo promedio de respuesta
      final avgResponseTime = await _calculateAverageResponseTime(start, end);

      final metrics = UserExperienceMetrics(
        npsScore: npsScore,
        conversionFunnel: conversionFunnel,
        cancellationReasons: cancellationReasons,
        averageResponseTime: avgResponseTime,
        customerSatisfactionRate:
            npsScore >= 50 ? 0.8 : 0.6, // Estimación basada en NPS
        timestamp: DateTime.now(),
        dateRange: DateRange(start: start, end: end),
      );

      AppLogger.info('✅ Métricas de experiencia calculadas: NPS $npsScore');
      return metrics;
    } catch (error, stackTrace) {
      AppLogger.error(
          '❌ Error calculando métricas de experiencia', error, stackTrace);
      rethrow;
    }
  }

  /// Obtener análisis financiero
  Future<FinancialAnalytics> getFinancialAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      AppLogger.info('💰 Calculando análisis financiero');

      // Consultar trips completados
      final tripsQuery = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('status', isEqualTo: 'completed')
          .get();

      // Calcular métricas financieras
      double totalRevenue = 0.0;
      double totalCommission = 0.0;
      final Map<String, double> revenueByPaymentMethod = {};

      for (final doc in tripsQuery.docs) {
        final data = doc.data();
        final finalPrice = data['finalPrice'] ?? 0.0;
        final paymentMethod = data['paymentMethod'] ?? 'cash';

        totalRevenue += finalPrice;
        totalCommission += finalPrice * 0.2; // 20% comisión

        revenueByPaymentMethod[paymentMethod] =
            (revenueByPaymentMethod[paymentMethod] ?? 0.0) + finalPrice;
      }

      // Precio promedio negociado
      final avgNegotiatedPrice =
          await _calculateAverageNegotiatedPrice(start, end);

      // Eficiencia de negociación
      final negotiationEfficiency =
          await _calculateNegotiationEfficiency(start, end);

      final analytics = FinancialAnalytics(
        totalRevenue: totalRevenue,
        totalCommission: totalCommission,
        driverEarnings: totalRevenue - totalCommission,
        revenueByPaymentMethod: revenueByPaymentMethod,
        averageNegotiatedPrice: avgNegotiatedPrice,
        negotiationEfficiency: negotiationEfficiency,
        transactionCount: tripsQuery.docs.length,
        averageTransactionValue: tripsQuery.docs.isEmpty
            ? 0.0
            : totalRevenue / tripsQuery.docs.length,
        timestamp: DateTime.now(),
        dateRange: DateRange(start: start, end: end),
      );

      AppLogger.info(
          '✅ Análisis financiero completado: S/ ${totalRevenue.toStringAsFixed(2)}');
      return analytics;
    } catch (error, stackTrace) {
      AppLogger.error('❌ Error en análisis financiero', error, stackTrace);
      rethrow;
    }
  }

  /// Obtener análisis temporal y patrones
  Future<TemporalAnalytics> getTemporalAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      AppLogger.info('🕐 Calculando análisis temporal');

      // Mapa de calor de demanda
      final demandHeatmap = await _calculateDemandHeatmap(start, end);

      // Tendencia de surge pricing
      final surgeTrend = await _calculateSurgeTrend(start, end);

      // Distribución por distrito (Lima)
      final districtDistribution =
          await _calculateDistrictDistribution(start, end);

      // Patrones de pico de demanda
      final peakHours = await _identifyPeakHours(start, end);

      final analytics = TemporalAnalytics(
        demandHeatmap: demandHeatmap,
        surgePricingTrend: surgeTrend,
        districtDistribution: districtDistribution,
        peakHours: peakHours,
        timestamp: DateTime.now(),
        dateRange: DateRange(start: start, end: end),
      );

      AppLogger.info('✅ Análisis temporal completado');
      return analytics;
    } catch (error, stackTrace) {
      AppLogger.error('❌ Error en análisis temporal', error, stackTrace);
      rethrow;
    }
  }

  /// Exportar datos a BigQuery (simulación)
  Future<void> exportToBigQuery({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    try {
      AppLogger.info('📤 Exportando datos a BigQuery: $tableName');

      // En producción, aquí se haría la exportación real a BigQuery
      // Por ahora, simulamos guardando en Firestore con prefijo bigquery_export
      await _firestore
          .collection('bigquery_exports')
          .doc('${tableName}_${DateTime.now().millisecondsSinceEpoch}')
          .set({
        'tableName': tableName,
        'data': data,
        'exportedAt': FieldValue.serverTimestamp(),
        'status': 'exported',
      });

      await _analytics.logEvent(
        name: 'bigquery_export',
        parameters: {
          'table_name': tableName,
          'data_size': data.length,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      AppLogger.info('✅ Datos exportados correctamente a BigQuery');
    } catch (error, stackTrace) {
      AppLogger.error('❌ Error exportando a BigQuery', error, stackTrace);
      rethrow;
    }
  }

  /// Generar reporte automático
  Future<DashboardReport> generateAutomaticReport({
    DateTime? reportDate,
  }) async {
    try {
      final date = reportDate ?? DateTime.now();
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(microseconds: 1));

      AppLogger.info(
          '📋 Generando reporte automático para ${date.toIso8601String()}');

      // Obtener todas las métricas
      final businessMetrics = await getBusinessMetrics(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      final driverAnalytics = await getDriverAnalytics(
        startDate: startOfDay,
        endDate: endOfDay,
        limit: 10,
      );

      final userExperience = await getUserExperienceMetrics(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      final financialAnalytics = await getFinancialAnalytics(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      final report = DashboardReport(
        reportDate: date,
        businessMetrics: businessMetrics,
        driverAnalytics: driverAnalytics,
        userExperienceMetrics: userExperience,
        financialAnalytics: financialAnalytics,
        generatedAt: DateTime.now(),
      );

      // Guardar reporte en Firestore
      await _firestore
          .collection('dashboard_reports')
          .doc('report_${date.toIso8601String().substring(0, 10)}')
          .set(report.toJson());

      AppLogger.info('✅ Reporte automático generado exitosamente');
      return report;
    } catch (error, stackTrace) {
      AppLogger.error(
          '❌ Error generando reporte automático', error, stackTrace);
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉTODOS AUXILIARES PRIVADOS
  // ═══════════════════════════════════════════════════════════════════

  Future<double> _calculateAverageRating(DateTime start, DateTime end) async {
    try {
      final ratingsQuery = await _firestore
          .collection('ratings')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      if (ratingsQuery.docs.isEmpty) return 0.0;

      final totalRating = ratingsQuery.docs
          .fold<double>(0.0, (sum, doc) => sum + (doc.data()['rating'] ?? 0.0));

      return totalRating / ratingsQuery.docs.length;
    } catch (error) {
      AppLogger.warning('Error calculando rating promedio: $error');
      return 0.0;
    }
  }

  Future<int> _countActiveDrivers(DateTime start, DateTime end) async {
    try {
      final tripsQuery = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final driverIds = <String>{};
      for (final doc in tripsQuery.docs) {
        final driverId = doc.data()['driverId'] as String?;
        if (driverId != null) {
          driverIds.add(driverId);
        }
      }

      return driverIds.length;
    } catch (error) {
      AppLogger.warning('Error contando conductores activos: $error');
      return 0;
    }
  }

  Future<double> _calculateDriverAverageRating(
      String driverId, DateTime start, DateTime end) async {
    try {
      final ratingsQuery = await _firestore
          .collection('ratings')
          .where('driverId', isEqualTo: driverId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      if (ratingsQuery.docs.isEmpty) return 0.0;

      final totalRating = ratingsQuery.docs
          .fold<double>(0.0, (sum, doc) => sum + (doc.data()['rating'] ?? 0.0));

      return totalRating / ratingsQuery.docs.length;
    } catch (error) {
      return 0.0;
    }
  }

  Future<int> _getDriverCancellations(
      String driverId, DateTime start, DateTime end) async {
    try {
      final cancellationsQuery = await _firestore
          .collection('trips')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'cancelled')
          .where('cancelledBy', isEqualTo: 'driver')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      return cancellationsQuery.docs.length;
    } catch (error) {
      return 0;
    }
  }

  Future<double> _calculateNPSScore(DateTime start, DateTime end) async {
    try {
      final ratingsQuery = await _firestore
          .collection('ratings')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      if (ratingsQuery.docs.isEmpty) return 0.0;

      int promoters = 0;
      int detractors = 0;
      int total = 0;

      for (final doc in ratingsQuery.docs) {
        final rating = doc.data()['rating'] ?? 0.0;
        total++;

        if (rating >= 9) {
          promoters++;
        } else if (rating <= 6) {
          detractors++;
        }
      }

      return total > 0 ? ((promoters - detractors) / total * 100) : 0.0;
    } catch (error) {
      return 0.0;
    }
  }

  Future<ConversionFunnel> _calculateConversionFunnel(
      DateTime start, DateTime end) async {
    try {
      final allTripsQuery = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final totalCreated = allTripsQuery.docs.length;
      final driverAssigned = allTripsQuery.docs
          .where((doc) => doc.data()['driverId'] != null)
          .length;
      final inProgress = allTripsQuery.docs
          .where((doc) =>
              ['in_progress', 'completed'].contains(doc.data()['status']))
          .length;
      final completed = allTripsQuery.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      return ConversionFunnel(
        totalCreated: totalCreated,
        driverAssigned: driverAssigned,
        tripStarted: inProgress,
        tripCompleted: completed,
      );
    } catch (error) {
      return ConversionFunnel(
        totalCreated: 0,
        driverAssigned: 0,
        tripStarted: 0,
        tripCompleted: 0,
      );
    }
  }

  Future<Map<String, int>> _getCancellationReasons(
      DateTime start, DateTime end) async {
    try {
      final cancelledTripsQuery = await _firestore
          .collection('trips')
          .where('status', isEqualTo: 'cancelled')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final Map<String, int> reasons = {};

      for (final doc in cancelledTripsQuery.docs) {
        final reason = doc.data()['cancellationReason'] ?? 'No especificado';
        reasons[reason] = (reasons[reason] ?? 0) + 1;
      }

      return reasons;
    } catch (error) {
      return {};
    }
  }

  Future<double> _calculateAverageResponseTime(
      DateTime start, DateTime end) async {
    try {
      final tripsQuery = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('acceptedAt', isNotEqualTo: null)
          .get();

      if (tripsQuery.docs.isEmpty) return 0.0;

      double totalResponseTime = 0.0;
      int validTrips = 0;

      for (final doc in tripsQuery.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final acceptedAt = (data['acceptedAt'] as Timestamp?)?.toDate();

        if (createdAt != null && acceptedAt != null) {
          totalResponseTime += acceptedAt.difference(createdAt).inSeconds;
          validTrips++;
        }
      }

      return validTrips > 0 ? totalResponseTime / validTrips : 0.0;
    } catch (error) {
      return 0.0;
    }
  }

  Future<double> _calculateAverageNegotiatedPrice(
      DateTime start, DateTime end) async {
    try {
      final negotiationsQuery = await _firestore
          .collection('price_negotiations')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('status', isEqualTo: 'accepted')
          .get();

      if (negotiationsQuery.docs.isEmpty) return 0.0;

      final totalPrice = negotiationsQuery.docs.fold<double>(
          0.0, (sum, doc) => sum + (doc.data()['finalPrice'] ?? 0.0));

      return totalPrice / negotiationsQuery.docs.length;
    } catch (error) {
      return 0.0;
    }
  }

  Future<double> _calculateNegotiationEfficiency(
      DateTime start, DateTime end) async {
    try {
      final negotiationsQuery = await _firestore
          .collection('price_negotiations')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('status', isEqualTo: 'accepted')
          .get();

      if (negotiationsQuery.docs.isEmpty) return 0.0;

      int successfulNegotiations = 0;

      for (final doc in negotiationsQuery.docs) {
        final data = doc.data();
        final initialPrice = data['initialPrice'] ?? 0.0;
        final finalPrice = data['finalPrice'] ?? 0.0;

        if (finalPrice > initialPrice) {
          successfulNegotiations++;
        }
      }

      return (successfulNegotiations / negotiationsQuery.docs.length) * 100;
    } catch (error) {
      return 0.0;
    }
  }

  Future<Map<String, Map<int, int>>> _calculateDemandHeatmap(
      DateTime start, DateTime end) async {
    try {
      final tripsQuery = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final Map<String, Map<int, int>> heatmap = {};

      for (final doc in tripsQuery.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          final dayOfWeek = _getDayOfWeekName(createdAt.weekday);
          final hour = createdAt.hour;

          heatmap.putIfAbsent(dayOfWeek, () => {});
          heatmap[dayOfWeek]![hour] = (heatmap[dayOfWeek]![hour] ?? 0) + 1;
        }
      }

      return heatmap;
    } catch (error) {
      return {};
    }
  }

  Future<List<SurgeDataPoint>> _calculateSurgeTrend(
      DateTime start, DateTime end) async {
    try {
      final tripsQuery = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('createdAt')
          .get();

      final List<SurgeDataPoint> surgeTrend = [];
      final Map<DateTime, List<double>> surgeByHour = {};

      for (final doc in tripsQuery.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final surgeMultiplier = data['surgeMultiplier'] ?? 1.0;

        if (createdAt != null) {
          final hour = DateTime(
              createdAt.year, createdAt.month, createdAt.day, createdAt.hour);
          surgeByHour.putIfAbsent(hour, () => []).add(surgeMultiplier);
        }
      }

      surgeByHour.forEach((hour, surges) {
        final avgSurge = surges.fold<double>(0.0, (sum, surge) => sum + surge) /
            surges.length;
        surgeTrend.add(SurgeDataPoint(
          timestamp: hour,
          averageSurge: avgSurge,
          tripCount: surges.length,
        ));
      });

      surgeTrend.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return surgeTrend;
    } catch (error) {
      return [];
    }
  }

  Future<Map<String, DistrictMetrics>> _calculateDistrictDistribution(
      DateTime start, DateTime end) async {
    try {
      final tripsQuery = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('status', isEqualTo: 'completed')
          .get();

      final Map<String, List<double>> districtData = {};

      for (final doc in tripsQuery.docs) {
        final data = doc.data();
        final pickupAddress = data['pickup']?['address'] ?? '';
        final finalPrice = data['finalPrice'] ?? 0.0;

        final district = _extractDistrict(pickupAddress);
        districtData.putIfAbsent(district, () => []).add(finalPrice);
      }

      final Map<String, DistrictMetrics> distribution = {};
      districtData.forEach((district, prices) {
        distribution[district] = DistrictMetrics(
          district: district,
          tripCount: prices.length,
          averagePrice: prices.fold<double>(0.0, (sum, price) => sum + price) /
              prices.length,
          totalRevenue: prices.fold<double>(0.0, (sum, price) => sum + price),
        );
      });

      return distribution;
    } catch (error) {
      return {};
    }
  }

  Future<List<PeakHour>> _identifyPeakHours(
      DateTime start, DateTime end) async {
    try {
      final tripsQuery = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final Map<int, int> hourlyTrips = {};

      for (final doc in tripsQuery.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          final hour = createdAt.hour;
          hourlyTrips[hour] = (hourlyTrips[hour] ?? 0) + 1;
        }
      }

      final List<PeakHour> peakHours = [];
      final sortedHours = hourlyTrips.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Tomar top 8 horas pico
      for (int i = 0; i < 8 && i < sortedHours.length; i++) {
        final entry = sortedHours[i];
        peakHours.add(PeakHour(
          hour: entry.key,
          tripCount: entry.value,
          demandLevel: i < 3
              ? 'Peak'
              : i < 6
                  ? 'Medium'
                  : 'Low',
        ));
      }

      return peakHours;
    } catch (error) {
      return [];
    }
  }

  void _setupCacheRefresh() {
    _cacheRefreshTimer?.cancel();
    _cacheRefreshTimer = Timer.periodic(_cacheRefreshInterval, (timer) {
      _metricsCache.clear();
      AppLogger.debug('🔄 Cache de métricas limpiado');
    });
  }

  Future<void> _loadCacheFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey);
      if (cacheData != null) {
        final cacheJson = jsonDecode(cacheData) as Map<String, dynamic>;
        _metricsCache.addAll(cacheJson);
        AppLogger.debug('📋 Cache cargado desde almacenamiento');
      }
    } catch (error) {
      AppLogger.warning('Error cargando cache: $error');
    }
  }

  Future<void> _saveCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_metricsCache));
    } catch (error) {
      AppLogger.warning('Error guardando cache: $error');
    }
  }

  String _getDayOfWeekName(int weekday) {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    return days[weekday - 1];
  }

  String _extractDistrict(String address) {
    final districts = [
      'Miraflores',
      'San Isidro',
      'Barranco',
      'Surco',
      'La Molina',
      'San Borja',
      'Pueblo Libre',
      'Jesús María',
      'Lince',
      'Magdalena'
    ];

    for (final district in districts) {
      if (address.toLowerCase().contains(district.toLowerCase())) {
        return district;
      }
    }

    return 'Otros';
  }

  /// Limpiar recursos
  void dispose() {
    _cacheRefreshTimer?.cancel();
    _metricsCache.clear();
    AppLogger.info('🔄 DataStudioService disposed');
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODELOS DE DATOS
// ═══════════════════════════════════════════════════════════════════

/// Métricas de negocio
class BusinessMetrics {
  final int totalTrips;
  final int completedTrips;
  final int cancelledTrips;
  final int inProgressTrips;
  final double totalRevenue;
  final double averageRating;
  final int activeDrivers;
  final double conversionRate;
  final double revenuePerTrip;
  final DateTime timestamp;
  final DateRange dateRange;

  BusinessMetrics({
    required this.totalTrips,
    required this.completedTrips,
    required this.cancelledTrips,
    required this.inProgressTrips,
    required this.totalRevenue,
    required this.averageRating,
    required this.activeDrivers,
    required this.conversionRate,
    required this.revenuePerTrip,
    required this.timestamp,
    required this.dateRange,
  });

  Map<String, dynamic> toJson() => {
        'totalTrips': totalTrips,
        'completedTrips': completedTrips,
        'cancelledTrips': cancelledTrips,
        'inProgressTrips': inProgressTrips,
        'totalRevenue': totalRevenue,
        'averageRating': averageRating,
        'activeDrivers': activeDrivers,
        'conversionRate': conversionRate,
        'revenuePerTrip': revenuePerTrip,
        'timestamp': timestamp.toIso8601String(),
        'dateRange': dateRange.toJson(),
      };

  factory BusinessMetrics.fromJson(Map<String, dynamic> json) =>
      BusinessMetrics(
        totalTrips: json['totalTrips'] ?? 0,
        completedTrips: json['completedTrips'] ?? 0,
        cancelledTrips: json['cancelledTrips'] ?? 0,
        inProgressTrips: json['inProgressTrips'] ?? 0,
        totalRevenue: (json['totalRevenue'] ?? 0.0).toDouble(),
        averageRating: (json['averageRating'] ?? 0.0).toDouble(),
        activeDrivers: json['activeDrivers'] ?? 0,
        conversionRate: (json['conversionRate'] ?? 0.0).toDouble(),
        revenuePerTrip: (json['revenuePerTrip'] ?? 0.0).toDouble(),
        timestamp: DateTime.parse(json['timestamp']),
        dateRange: DateRange.fromJson(json['dateRange']),
      );
}

/// Análisis de conductores
class DriverAnalytics {
  final int totalActiveDrivers;
  final List<DriverMetrics> topDrivers;
  final double averageTripsPerDriver;
  final double averageEarningsPerDriver;
  final double averageRating;
  final DateTime timestamp;
  final DateRange dateRange;

  DriverAnalytics({
    required this.totalActiveDrivers,
    required this.topDrivers,
    required this.averageTripsPerDriver,
    required this.averageEarningsPerDriver,
    required this.averageRating,
    required this.timestamp,
    required this.dateRange,
  });

  Map<String, dynamic> toJson() => {
        'totalActiveDrivers': totalActiveDrivers,
        'topDrivers': topDrivers.map((d) => d.toJson()).toList(),
        'averageTripsPerDriver': averageTripsPerDriver,
        'averageEarningsPerDriver': averageEarningsPerDriver,
        'averageRating': averageRating,
        'timestamp': timestamp.toIso8601String(),
        'dateRange': dateRange.toJson(),
      };
}

/// Métricas de conductor individual
class DriverMetrics {
  final String driverId;
  final String driverName;
  final int totalTrips;
  final double totalEarnings;
  final double driverShare;
  final double averageRating;
  final double completionRate;
  final int cancellationCount;

  DriverMetrics({
    required this.driverId,
    required this.driverName,
    required this.totalTrips,
    required this.totalEarnings,
    required this.driverShare,
    required this.averageRating,
    required this.completionRate,
    required this.cancellationCount,
  });

  Map<String, dynamic> toJson() => {
        'driverId': driverId,
        'driverName': driverName,
        'totalTrips': totalTrips,
        'totalEarnings': totalEarnings,
        'driverShare': driverShare,
        'averageRating': averageRating,
        'completionRate': completionRate,
        'cancellationCount': cancellationCount,
      };
}

/// Métricas de experiencia de usuario
class UserExperienceMetrics {
  final double npsScore;
  final ConversionFunnel conversionFunnel;
  final Map<String, int> cancellationReasons;
  final double averageResponseTime;
  final double customerSatisfactionRate;
  final DateTime timestamp;
  final DateRange dateRange;

  UserExperienceMetrics({
    required this.npsScore,
    required this.conversionFunnel,
    required this.cancellationReasons,
    required this.averageResponseTime,
    required this.customerSatisfactionRate,
    required this.timestamp,
    required this.dateRange,
  });

  Map<String, dynamic> toJson() => {
        'npsScore': npsScore,
        'conversionFunnel': conversionFunnel.toJson(),
        'cancellationReasons': cancellationReasons,
        'averageResponseTime': averageResponseTime,
        'customerSatisfactionRate': customerSatisfactionRate,
        'timestamp': timestamp.toIso8601String(),
        'dateRange': dateRange.toJson(),
      };
}

/// Embudo de conversión
class ConversionFunnel {
  final int totalCreated;
  final int driverAssigned;
  final int tripStarted;
  final int tripCompleted;

  ConversionFunnel({
    required this.totalCreated,
    required this.driverAssigned,
    required this.tripStarted,
    required this.tripCompleted,
  });

  Map<String, dynamic> toJson() => {
        'totalCreated': totalCreated,
        'driverAssigned': driverAssigned,
        'tripStarted': tripStarted,
        'tripCompleted': tripCompleted,
      };
}

/// Análisis financiero
class FinancialAnalytics {
  final double totalRevenue;
  final double totalCommission;
  final double driverEarnings;
  final Map<String, double> revenueByPaymentMethod;
  final double averageNegotiatedPrice;
  final double negotiationEfficiency;
  final int transactionCount;
  final double averageTransactionValue;
  final DateTime timestamp;
  final DateRange dateRange;

  FinancialAnalytics({
    required this.totalRevenue,
    required this.totalCommission,
    required this.driverEarnings,
    required this.revenueByPaymentMethod,
    required this.averageNegotiatedPrice,
    required this.negotiationEfficiency,
    required this.transactionCount,
    required this.averageTransactionValue,
    required this.timestamp,
    required this.dateRange,
  });

  Map<String, dynamic> toJson() => {
        'totalRevenue': totalRevenue,
        'totalCommission': totalCommission,
        'driverEarnings': driverEarnings,
        'revenueByPaymentMethod': revenueByPaymentMethod,
        'averageNegotiatedPrice': averageNegotiatedPrice,
        'negotiationEfficiency': negotiationEfficiency,
        'transactionCount': transactionCount,
        'averageTransactionValue': averageTransactionValue,
        'timestamp': timestamp.toIso8601String(),
        'dateRange': dateRange.toJson(),
      };
}

/// Análisis temporal
class TemporalAnalytics {
  final Map<String, Map<int, int>> demandHeatmap;
  final List<SurgeDataPoint> surgePricingTrend;
  final Map<String, DistrictMetrics> districtDistribution;
  final List<PeakHour> peakHours;
  final DateTime timestamp;
  final DateRange dateRange;

  TemporalAnalytics({
    required this.demandHeatmap,
    required this.surgePricingTrend,
    required this.districtDistribution,
    required this.peakHours,
    required this.timestamp,
    required this.dateRange,
  });
}

/// Punto de datos de surge pricing
class SurgeDataPoint {
  final DateTime timestamp;
  final double averageSurge;
  final int tripCount;

  SurgeDataPoint({
    required this.timestamp,
    required this.averageSurge,
    required this.tripCount,
  });
}

/// Métricas por distrito
class DistrictMetrics {
  final String district;
  final int tripCount;
  final double averagePrice;
  final double totalRevenue;

  DistrictMetrics({
    required this.district,
    required this.tripCount,
    required this.averagePrice,
    required this.totalRevenue,
  });
}

/// Hora pico
class PeakHour {
  final int hour;
  final int tripCount;
  final String demandLevel;

  PeakHour({
    required this.hour,
    required this.tripCount,
    required this.demandLevel,
  });
}

/// Rango de fechas
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };

  factory DateRange.fromJson(Map<String, dynamic> json) => DateRange(
        start: DateTime.parse(json['start']),
        end: DateTime.parse(json['end']),
      );
}

/// Reporte completo del dashboard
class DashboardReport {
  final DateTime reportDate;
  final BusinessMetrics businessMetrics;
  final DriverAnalytics driverAnalytics;
  final UserExperienceMetrics userExperienceMetrics;
  final FinancialAnalytics financialAnalytics;
  final DateTime generatedAt;

  DashboardReport({
    required this.reportDate,
    required this.businessMetrics,
    required this.driverAnalytics,
    required this.userExperienceMetrics,
    required this.financialAnalytics,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'reportDate': reportDate.toIso8601String(),
        'businessMetrics': businessMetrics.toJson(),
        'driverAnalytics': driverAnalytics.toJson(),
        'userExperienceMetrics': userExperienceMetrics.toJson(),
        'financialAnalytics': financialAnalytics.toJson(),
        'generatedAt': generatedAt.toIso8601String(),
      };
}

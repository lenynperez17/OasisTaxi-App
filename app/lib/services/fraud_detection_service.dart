import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_logger.dart';

/// Resultado del análisis de comportamiento fraudulento
class FraudAnalysisResult {
  final String riskLevel;
  final double riskScore;
  final List<String> factors;
  final String? rideId;
  final String? userId;
  final FraudAction action;
  final List<String> riskFactors;
  final Map<String, double> riskFactorsMap;
  final DateTime timestamp;
  final String recommendation;

  const FraudAnalysisResult({
    required this.riskLevel,
    required this.riskScore,
    required this.factors,
    this.rideId,
    this.userId,
    required this.action,
    this.riskFactors = const [],
    this.riskFactorsMap = const {},
    required this.timestamp,
    required this.recommendation,
  });

  // Constructor named para errores
  factory FraudAnalysisResult.error(
      String? rideId, String? userId, String error) {
    return FraudAnalysisResult(
      riskLevel: 'error',
      riskScore: 0.0,
      factors: [error],
      rideId: rideId,
      userId: userId,
      action: FraudAction.allow,
      riskFactors: [error],
      riskFactorsMap: {},
      timestamp: DateTime.now(),
      recommendation: 'Error en el análisis: $error',
    );
  }
}

/// Servicio de detección de fraude con Firebase ML para OasisTaxi Peru
/// Implementa análisis de comportamiento, geolocalización y patrones de fraude
class FraudDetectionService {
  static final FraudDetectionService _instance =
      FraudDetectionService._internal();
  factory FraudDetectionService() => _instance;
  FraudDetectionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Configuración de detección de fraude para Peru
  static const Map<String, dynamic> fraudConfig = {
    'maxRideDistance': 500.0, // 500 km máximo
    'maxRidePrice': 500.0, // S/ 500 máximo
    'maxDailyRides': 20, // 20 viajes por día máximo
    'maxAccountsPerDevice': 3, // 3 cuentas por dispositivo
    'maxFailedPayments': 5, // 5 pagos fallidos
    'suspiciousVelocityKmh': 150.0, // 150 km/h velocidad sospechosa
    'nightTimeStart': 22, // 10:00 PM
    'nightTimeEnd': 6, // 6:00 AM
    'riskScoreThreshold': 0.7, // 70% umbral de riesgo
    'blockingThreshold': 0.9, // 90% umbral de bloqueo
  };

  // Zonas de alto riesgo en Lima y ciudades principales de Perú
  static const List<Map<String, dynamic>> highRiskZones = [
    {
      'name': 'Villa El Salvador',
      'lat': -12.2035,
      'lng': -76.9378,
      'radius': 5000, // 5km radio
      'riskLevel': 0.8,
    },
    {
      'name': 'San Juan de Lurigancho',
      'lat': -11.9590,
      'lng': -77.0073,
      'radius': 8000,
      'riskLevel': 0.7,
    },
    {
      'name': 'Ate Vitarte',
      'lat': -12.0464,
      'lng': -76.8909,
      'radius': 6000,
      'riskLevel': 0.6,
    },
    {
      'name': 'Callao Puerto',
      'lat': -12.0586,
      'lng': -77.1441,
      'radius': 4000,
      'riskLevel': 0.8,
    },
    {
      'name': 'Comas',
      'lat': -11.9344,
      'lng': -77.0566,
      'radius': 7000,
      'riskLevel': 0.7,
    },
  ];

  // Patrones de comportamiento fraudulento
  static const Map<String, double> fraudPatterns = {
    'multiple_accounts_same_device': 0.8,
    'rapid_successive_rides': 0.7,
    'impossible_travel_speed': 0.9,
    'payment_method_cycling': 0.6,
    'fake_gps_coordinates': 0.9,
    'abnormal_route_patterns': 0.5,
    'high_cancellation_rate': 0.4,
    'document_tampering': 0.9,
    'suspicious_registration_time': 0.3,
    'vpn_or_proxy_usage': 0.6,
  };

  /// Analizar riesgo de fraude para una transacción
  Future<FraudAnalysisResult> analyzeTransaction({
    required String userId,
    required String rideId,
    required Map<String, dynamic> rideDetails,
    required Map<String, dynamic> paymentDetails,
    required Map<String, dynamic> locationData,
  }) async {
    try {
      AppLogger.info('📊 Analizando riesgo de fraude para ride: $rideId');

      final riskFactors = <String, double>{};
      double totalRiskScore = 0.0;

      // Análisis de ubicación
      final locationRisk = await _analyzeLocationRisk(locationData);
      riskFactors.addAll(locationRisk);

      // Análisis de comportamiento del usuario
      final behaviorRisk = await _analyzeBehaviorRisk(userId, rideDetails);
      riskFactors.addAll(behaviorRisk);

      // Análisis de patrones de pago
      final paymentRisk = await _analyzePaymentRisk(userId, paymentDetails);
      riskFactors.addAll(paymentRisk);

      // Análisis de dispositivo
      final deviceRisk = await _analyzeDeviceRisk(userId);
      riskFactors.addAll(deviceRisk);

      // Análisis de tiempo y frecuencia
      final timeRisk = await _analyzeTimePatterns(userId, rideDetails);
      riskFactors.addAll(timeRisk);

      // Usar Firebase ML para análisis avanzado
      final mlRisk = await _analyzeWithFirebaseML({
        'rideDetails': rideDetails,
        'paymentDetails': paymentDetails,
        'locationData': locationData,
        'userHistory': await _getUserHistory(userId),
      });
      riskFactors['ml_analysis'] = mlRisk;

      // Calcular score total
      totalRiskScore = _calculateTotalRiskScore(riskFactors);

      final result = FraudAnalysisResult(
        rideId: rideId,
        userId: userId,
        riskScore: totalRiskScore,
        riskLevel: _determineRiskLevel(totalRiskScore),
        factors: _generateFactorsList(riskFactors),
        riskFactors: _generateFactorsList(riskFactors),
        riskFactorsMap: riskFactors,
        timestamp: DateTime.now(),
        action: _determineAction(totalRiskScore),
        recommendation: _generateRecommendation(riskFactors, totalRiskScore),
      );

      // Guardar análisis para ML training
      await _saveFraudAnalysis(result);

      // Tomar acción si es necesario
      if (result.action != FraudAction.allow) {
        await _takeFraudAction(result);
      }

      AppLogger.info(
          '✅ Análisis de fraude completado - ride: $rideId, score: $totalRiskScore, action: ${result.action}');

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Error en análisis de fraude', e, stackTrace);
      return FraudAnalysisResult.error(rideId, userId, e.toString());
    }
  }

  /// Analizar riesgo de ubicación
  Future<Map<String, double>> _analyzeLocationRisk(
      Map<String, dynamic> locationData) async {
    final risks = <String, double>{};

    try {
      final pickupLat = locationData['pickupLat'] as double?;
      final pickupLng = locationData['pickupLng'] as double?;
      final dropoffLat = locationData['dropoffLat'] as double?;
      final dropoffLng = locationData['dropoffLng'] as double?;

      if (pickupLat == null ||
          pickupLng == null ||
          dropoffLat == null ||
          dropoffLng == null) {
        risks['invalid_coordinates'] = 0.8;
        return risks;
      }

      // Verificar si está en zona de alto riesgo
      for (final zone in highRiskZones) {
        final distance = Geolocator.distanceBetween(
          pickupLat,
          pickupLng,
          zone['lat'],
          zone['lng'],
        );

        if (distance <= zone['radius']) {
          risks['high_risk_zone_pickup'] = zone['riskLevel'] * 0.6;
          break;
        }
      }

      // Verificar dropoff en zona de riesgo
      for (final zone in highRiskZones) {
        final distance = Geolocator.distanceBetween(
          dropoffLat,
          dropoffLng,
          zone['lat'],
          zone['lng'],
        );

        if (distance <= zone['radius']) {
          risks['high_risk_zone_dropoff'] = zone['riskLevel'] * 0.4;
          break;
        }
      }

      // Verificar distancia del viaje
      final rideDistance = Geolocator.distanceBetween(
            pickupLat,
            pickupLng,
            dropoffLat,
            dropoffLng,
          ) /
          1000; // convertir a km

      if (rideDistance > fraudConfig['maxRideDistance']) {
        risks['excessive_distance'] = 0.7;
      }

      // Verificar coordenadas falsas (GPS spoofing)
      if (await _detectGPSSpoofing(pickupLat, pickupLng)) {
        risks['fake_gps'] = 0.9;
      }

      // Verificar si está fuera del área de servicio de Perú
      if (!_isWithinPeruServiceArea(pickupLat, pickupLng)) {
        risks['outside_service_area'] = 0.8;
      }
    } catch (e) {
      AppLogger.error('Error analizando riesgo de ubicación', e);
      risks['location_analysis_error'] = 0.3;
    }

    return risks;
  }

  /// Analizar riesgo de comportamiento del usuario
  Future<Map<String, double>> _analyzeBehaviorRisk(
      String userId, Map<String, dynamic> rideDetails) async {
    final risks = <String, double>{};

    try {
      // Obtener historial reciente del usuario
      final recentRides = await _getRecentRides(userId, days: 7);

      // Verificar frecuencia de viajes
      if (recentRides.length > fraudConfig['maxDailyRides']) {
        risks['excessive_daily_rides'] = 0.6;
      }

      // Verificar patrones de cancelación
      final cancellationRate = await _getCancellationRate(userId);
      if (cancellationRate > 0.5) {
        // 50% de cancelaciones
        risks['high_cancellation_rate'] = cancellationRate * 0.4;
      }

      // Verificar viajes sucesivos rápidos
      final rapidRides = _checkRapidSuccessiveRides(recentRides);
      if (rapidRides > 0) {
        risks['rapid_successive_rides'] = math.min(rapidRides * 0.2, 0.7);
      }

      // Verificar velocidad de viaje imposible
      final impossibleSpeed =
          await _checkImpossibleTravelSpeed(userId, rideDetails);
      if (impossibleSpeed) {
        risks['impossible_travel_speed'] = 0.9;
      }

      // Verificar horario sospechoso (madrugada)
      final hour = DateTime.now().hour;
      if ((hour >= fraudConfig['nightTimeStart'] ||
              hour <= fraudConfig['nightTimeEnd']) &&
          recentRides.where((r) => _isNightTime(r['timestamp'])).length > 5) {
        risks['suspicious_night_activity'] = 0.4;
      }
    } catch (e) {
      AppLogger.error('Error analizando comportamiento', e);
      risks['behavior_analysis_error'] = 0.2;
    }

    return risks;
  }

  /// Analizar riesgo de pago
  Future<Map<String, double>> _analyzePaymentRisk(
      String userId, Map<String, dynamic> paymentDetails) async {
    final risks = <String, double>{};

    try {
      // Verificar monto sospechoso
      final amount = paymentDetails['amount'] as double? ?? 0.0;
      if (amount > fraudConfig['maxRidePrice']) {
        risks['excessive_amount'] = 0.6;
      }

      // Verificar historial de pagos fallidos
      final failedPayments = await _getFailedPaymentsCount(userId);
      if (failedPayments > fraudConfig['maxFailedPayments']) {
        risks['multiple_failed_payments'] = math.min(failedPayments * 0.1, 0.7);
      }

      // Verificar cambio frecuente de métodos de pago
      final paymentMethodChanges = await _getPaymentMethodChanges(userId);
      if (paymentMethodChanges > 5) {
        risks['payment_method_cycling'] = 0.6;
      }

      // Verificar uso de tarjetas stolen/comprometidas
      final cardFingerprint = paymentDetails['cardFingerprint'] as String?;
      if (cardFingerprint != null &&
          await _isCompromisedCard(cardFingerprint)) {
        risks['compromised_card'] = 0.9;
      }
    } catch (e) {
      AppLogger.error('Error analizando riesgo de pago', e);
      risks['payment_analysis_error'] = 0.2;
    }

    return risks;
  }

  /// Analizar riesgo de dispositivo
  Future<Map<String, double>> _analyzeDeviceRisk(String userId) async {
    final risks = <String, double>{};

    try {
      // Verificar múltiples cuentas en el mismo dispositivo
      final accountsOnDevice = await _getAccountsOnDevice(userId);
      if (accountsOnDevice > fraudConfig['maxAccountsPerDevice']) {
        risks['multiple_accounts_device'] = 0.8;
      }

      // Verificar si el dispositivo está en lista negra
      final deviceId = await _getDeviceId(userId);
      if (await _isBlacklistedDevice(deviceId)) {
        risks['blacklisted_device'] = 0.9;
      }

      // Verificar uso de VPN/Proxy
      if (await _detectVPNUsage(userId)) {
        risks['vpn_usage'] = 0.6;
      }
    } catch (e) {
      AppLogger.error('Error analizando dispositivo', e);
      risks['device_analysis_error'] = 0.2;
    }

    return risks;
  }

  /// Analizar patrones de tiempo
  Future<Map<String, double>> _analyzeTimePatterns(
      String userId, Map<String, dynamic> rideDetails) async {
    final risks = <String, double>{};

    try {
      // Verificar registro reciente sospechoso
      final accountAge = await _getAccountAge(userId);
      if (accountAge.inHours < 24) {
        risks['new_account'] = 0.4;
      }

      // Verificar patrones de tiempo anómalos
      final timePatterns = await _analyzeUserTimePatterns(userId);
      if (timePatterns['anomalous'] == true) {
        risks['anomalous_time_patterns'] = 0.5;
      }
    } catch (e) {
      AppLogger.error('Error analizando patrones de tiempo', e);
      risks['time_analysis_error'] = 0.1;
    }

    return risks;
  }

  /// Analizar con Firebase ML
  Future<double> _analyzeWithFirebaseML(Map<String, dynamic> data) async {
    try {
      // Usar Cloud Function con Firebase ML
      final callable = _functions.httpsCallable('analyzeFraudWithML');
      final result = await callable.call(data);

      return (result.data['riskScore'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      AppLogger.error('Error en análisis ML', e);
      return 0.0;
    }
  }

  /// Calcular score total de riesgo
  double _calculateTotalRiskScore(Map<String, double> riskFactors) {
    if (riskFactors.isEmpty) return 0.0;

    // Calcular promedio ponderado
    double totalWeight = 0.0;
    double weightedSum = 0.0;

    for (final entry in riskFactors.entries) {
      final weight = _getRiskWeight(entry.key);
      totalWeight += weight;
      weightedSum += entry.value * weight;
    }

    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }

  /// Obtener peso de riesgo por factor
  double _getRiskWeight(String factor) {
    const weights = {
      'fake_gps': 3.0,
      'impossible_travel_speed': 3.0,
      'compromised_card': 2.5,
      'blacklisted_device': 2.5,
      'multiple_accounts_device': 2.0,
      'excessive_distance': 1.5,
      'high_risk_zone_pickup': 1.2,
      'multiple_failed_payments': 1.0,
      'ml_analysis': 2.0,
    };

    return weights[factor] ?? 1.0;
  }

  /// Determinar acción basada en score de riesgo
  FraudAction _determineAction(double riskScore) {
    if (riskScore >= fraudConfig['blockingThreshold']) {
      return FraudAction.block;
    } else if (riskScore >= fraudConfig['riskScoreThreshold']) {
      return FraudAction.review;
    }
    return FraudAction.allow;
  }

  /// Generar recomendación
  String _generateRecommendation(
      Map<String, double> riskFactors, double totalScore) {
    if (totalScore >= 0.9) {
      return 'BLOQUEAR: Actividad altamente sospechosa detectada';
    } else if (totalScore >= 0.7) {
      return 'REVISAR: Patrones de riesgo detectados, requiere verificación manual';
    } else if (totalScore >= 0.5) {
      return 'MONITOREAR: Actividad con riesgo moderado';
    }
    return 'PERMITIR: Actividad normal detectada';
  }

  /// Determinar nivel de riesgo basado en score
  String _determineRiskLevel(double riskScore) {
    if (riskScore >= 0.9) {
      return 'CRITICAL';
    } else if (riskScore >= 0.7) {
      return 'HIGH';
    } else if (riskScore >= 0.4) {
      return 'MEDIUM';
    } else {
      return 'LOW';
    }
  }

  /// Generar lista de factores de riesgo
  List<String> _generateFactorsList(Map<String, double> riskFactors) {
    return riskFactors.entries
        .where((entry) => entry.value > 0.3)
        .map((entry) => 'Riesgo ${entry.key}: ${(entry.value * 100).toInt()}%')
        .toList();
  }

  /// Tomar acción de fraude
  Future<void> _takeFraudAction(FraudAnalysisResult result) async {
    try {
      final callable = _functions.httpsCallable('takeFraudAction');
      await callable.call({
        'action': result.action.toString(),
        'userId': result.userId,
        'rideId': result.rideId,
        'riskScore': result.riskScore,
        'riskFactors': result.riskFactors,
      });

      AppLogger.warning(
          '🚨 Acción de fraude ejecutada - action: ${result.action}, score: ${result.riskScore}');
    } catch (e) {
      AppLogger.error('Error ejecutando acción de fraude', e);
    }
  }

  /// Guardar análisis para ML training
  Future<void> _saveFraudAnalysis(FraudAnalysisResult result) async {
    try {
      await _firestore.collection('fraud_analysis').add({
        'rideId': result.rideId,
        'userId': result.userId,
        'riskScore': result.riskScore,
        'riskFactors': result.riskFactors,
        'action': result.action.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'country': 'PE',
      });
    } catch (e) {
      AppLogger.error('Error guardando análisis de fraude', e);
    }
  }

  // Métodos auxiliares

  Future<List<Map<String, dynamic>>> _getRecentRides(String userId,
      {int days = 7}) async {
    try {
      final snapshot = await _firestore
          .collection('rides')
          .where('userId', isEqualTo: userId)
          .where('createdAt',
              isGreaterThan: DateTime.now().subtract(Duration(days: days)))
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<double> _getCancellationRate(String userId) async {
    try {
      final totalRides = await _firestore
          .collection('rides')
          .where('userId', isEqualTo: userId)
          .get();

      final cancelledRides = await _firestore
          .collection('rides')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'cancelled')
          .get();

      return totalRides.docs.isEmpty
          ? 0.0
          : cancelledRides.docs.length / totalRides.docs.length;
    } catch (e) {
      return 0.0;
    }
  }

  int _checkRapidSuccessiveRides(List<Map<String, dynamic>> rides) {
    int rapidCount = 0;
    rides.sort(
        (a, b) => (a['timestamp'] as Timestamp).compareTo(b['timestamp']));

    for (int i = 1; i < rides.length; i++) {
      final prev = (rides[i - 1]['timestamp'] as Timestamp).toDate();
      final current = (rides[i]['timestamp'] as Timestamp).toDate();
      final diff = current.difference(prev).inMinutes;

      if (diff < 10) {
        // Menos de 10 minutos entre viajes
        rapidCount++;
      }
    }

    return rapidCount;
  }

  Future<bool> _checkImpossibleTravelSpeed(
      String userId, Map<String, dynamic> rideDetails) async {
    try {
      // Obtener último viaje
      final lastRide = await _getLastCompletedRide(userId);
      if (lastRide == null) return false;

      final lastEndTime = (lastRide['endTime'] as Timestamp?)?.toDate();
      final currentStartTime = DateTime.now();

      if (lastEndTime == null) return false;

      final timeDiff = currentStartTime.difference(lastEndTime).inMinutes;
      if (timeDiff <= 0) return true;

      // Calcular distancia entre viajes
      final distance = Geolocator.distanceBetween(
            lastRide['dropoffLat'],
            lastRide['dropoffLng'],
            rideDetails['pickupLat'],
            rideDetails['pickupLng'],
          ) /
          1000; // km

      final speed = distance / (timeDiff / 60); // km/h
      return speed > fraudConfig['suspiciousVelocityKmh'];
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getLastCompletedRide(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('rides')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('endTime', descending: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null;
    } catch (e) {
      return null;
    }
  }

  bool _isNightTime(Timestamp timestamp) {
    final hour = timestamp.toDate().hour;
    return hour >= fraudConfig['nightTimeStart'] ||
        hour <= fraudConfig['nightTimeEnd'];
  }

  Future<int> _getFailedPaymentsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'failed')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getPaymentMethodChanges(String userId) async {
    // Mock implementation
    return 0;
  }

  Future<bool> _isCompromisedCard(String cardFingerprint) async {
    // Mock implementation - en producción verificar contra base de datos de tarjetas comprometidas
    return false;
  }

  Future<int> _getAccountsOnDevice(String userId) async {
    // Mock implementation
    return 1;
  }

  Future<String> _getDeviceId(String userId) async {
    // Mock implementation
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<bool> _isBlacklistedDevice(String deviceId) async {
    // Mock implementation
    return false;
  }

  Future<bool> _detectVPNUsage(String userId) async {
    // Mock implementation
    return false;
  }

  Future<Duration> _getAccountAge(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return Duration.zero;

      final createdAt = (userDoc.data()?['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null
          ? DateTime.now().difference(createdAt)
          : Duration.zero;
    } catch (e) {
      return Duration.zero;
    }
  }

  Future<Map<String, dynamic>> _analyzeUserTimePatterns(String userId) async {
    // Mock implementation - en producción analizar patrones temporales
    return {'anomalous': false};
  }

  Future<bool> _detectGPSSpoofing(double lat, double lng) async {
    // Mock implementation - en producción usar algoritmos de detección de GPS spoofing
    return false;
  }

  bool _isWithinPeruServiceArea(double lat, double lng) {
    // Coordenadas aproximadas de Perú
    const peruBounds = {
      'north': -0.037,
      'south': -18.348,
      'east': -68.677,
      'west': -81.328,
    };

    return lat >= peruBounds['south']! &&
        lat <= peruBounds['north']! &&
        lng >= peruBounds['west']! &&
        lng <= peruBounds['east']!;
  }

  Future<Map<String, dynamic>> _getUserHistory(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data() ?? {};
    } catch (e) {
      return {};
    }
  }

  /// Analizar comportamiento de usuario para detectar fraude
  Future<FraudAnalysisResult> analyzeBehavior(String userId) async {
    try {
      // Obtener historial del usuario
      final userRides = await _firestore
          .collection('trips')
          .where('passengerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (userRides.docs.isEmpty) {
        return FraudAnalysisResult(
          riskLevel: 'LOW',
          riskScore: 0.0,
          factors: ['Nuevo usuario sin historial'],
          action: FraudAction.allow,
          timestamp: DateTime.now(),
          recommendation: 'Usuario nuevo sin historial de viajes',
        );
      }

      double totalRisk = 0.0;
      List<String> riskFactors = [];

      // Calcular riesgo basado en patrones
      final rideDetails = userRides.docs.map((doc) => doc.data()).toList();
      final behaviorRisk =
          await _analyzeBehaviorRisk(userId, {'rides': rideDetails});

      for (final entry in behaviorRisk.entries) {
        totalRisk += entry.value;
        if (entry.value > 0.3) {
          riskFactors
              .add('Riesgo ${entry.key}: ${(entry.value * 100).toInt()}%');
        }
      }

      // Normalizar score
      final normalizedScore = math.min(totalRisk, 1.0);

      String riskLevel;
      if (normalizedScore >= 0.9) {
        riskLevel = 'CRITICAL';
      } else if (normalizedScore >= 0.7) {
        riskLevel = 'HIGH';
      } else if (normalizedScore >= 0.4) {
        riskLevel = 'MEDIUM';
      } else {
        riskLevel = 'LOW';
      }

      AppLogger.info(
          '📊 Análisis de fraude completado - user: $userId, score: $normalizedScore, level: $riskLevel');

      return FraudAnalysisResult(
        riskLevel: riskLevel,
        riskScore: normalizedScore,
        factors: riskFactors,
        action: _determineAction(normalizedScore),
        timestamp: DateTime.now(),
        recommendation: _generateRecommendation({}, normalizedScore),
      );
    } catch (e) {
      AppLogger.error('Error en análisis de comportamiento: $e');
      return FraudAnalysisResult(
        riskLevel: 'UNKNOWN',
        riskScore: 0.5,
        factors: ['Error al analizar comportamiento'],
        action: FraudAction.review,
        timestamp: DateTime.now(),
        recommendation:
            'Error en el análisis de comportamiento, requiere revisión manual',
      );
    }
  }
}

/// Acciones de fraude
enum FraudAction {
  allow, // Permitir transacción
  review, // Revisar manualmente
  block, // Bloquear transacción
}

import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio completo de Cloud Functions para OasisTaxi
/// Gestiona toda la lógica del backend y procesamiento serverless
class CloudFunctionsService {
  static final CloudFunctionsService _instance =
      CloudFunctionsService._internal();
  factory CloudFunctionsService() => _instance;
  CloudFunctionsService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Estado del servicio
  bool _isInitialized = false;
  Map<String, dynamic> _functionsConfig = {};

  // Configuración regional
  static const String _region = 'us-central1';

  // Cache de funciones llamadas frecuentemente
  final Map<String, CachedFunctionResult> _functionCache = {};
  Timer? _cacheCleanupTimer;
  static const Duration _cacheExpiration = Duration(minutes: 5);

  // Control de rate limiting
  final Map<String, RateLimitInfo> _rateLimits = {};

  // Funciones disponibles para OasisTaxi
  static const Map<String, FunctionConfig> _availableFunctions = {
    // Funciones de viaje
    'calculateTripPrice': FunctionConfig(
      name: 'calculateTripPrice',
      timeout: Duration(seconds: 10),
      retries: 2,
      cacheable: true,
    ),
    'matchDriverToTrip': FunctionConfig(
      name: 'matchDriverToTrip',
      timeout: Duration(seconds: 15),
      retries: 3,
      cacheable: false,
    ),
    'processPayment': FunctionConfig(
      name: 'processPayment',
      timeout: Duration(seconds: 30),
      retries: 1,
      cacheable: false,
    ),
    'completeTrip': FunctionConfig(
      name: 'completeTrip',
      timeout: Duration(seconds: 20),
      retries: 2,
      cacheable: false,
    ),

    // Funciones de notificación
    'sendNotification': FunctionConfig(
      name: 'sendNotification',
      timeout: Duration(seconds: 10),
      retries: 3,
      cacheable: false,
    ),
    'sendBulkNotifications': FunctionConfig(
      name: 'sendBulkNotifications',
      timeout: Duration(seconds: 30),
      retries: 2,
      cacheable: false,
    ),
    'sendEmergencyAlert': FunctionConfig(
      name: 'sendEmergencyAlert',
      timeout: Duration(seconds: 5),
      retries: 5,
      cacheable: false,
    ),

    // Funciones de verificación
    'verifyDriverDocuments': FunctionConfig(
      name: 'verifyDriverDocuments',
      timeout: Duration(seconds: 45),
      retries: 2,
      cacheable: false,
    ),
    'verifyPaymentMethod': FunctionConfig(
      name: 'verifyPaymentMethod',
      timeout: Duration(seconds: 20),
      retries: 2,
      cacheable: false,
    ),
    'validatePromoCode': FunctionConfig(
      name: 'validatePromoCode',
      timeout: Duration(seconds: 10),
      retries: 2,
      cacheable: true,
    ),

    // Funciones de análisis
    'generateDriverReport': FunctionConfig(
      name: 'generateDriverReport',
      timeout: Duration(seconds: 60),
      retries: 1,
      cacheable: true,
    ),
    'calculateDriverEarnings': FunctionConfig(
      name: 'calculateDriverEarnings',
      timeout: Duration(seconds: 20),
      retries: 2,
      cacheable: true,
    ),
    'generateInvoice': FunctionConfig(
      name: 'generateInvoice',
      timeout: Duration(seconds: 30),
      retries: 2,
      cacheable: false,
    ),

    // Funciones de administración
    'suspendUser': FunctionConfig(
      name: 'suspendUser',
      timeout: Duration(seconds: 10),
      retries: 1,
      cacheable: false,
    ),
    'approveDriver': FunctionConfig(
      name: 'approveDriver',
      timeout: Duration(seconds: 15),
      retries: 2,
      cacheable: false,
    ),
    'processWithdrawal': FunctionConfig(
      name: 'processWithdrawal',
      timeout: Duration(seconds: 30),
      retries: 1,
      cacheable: false,
    ),

    // Funciones de mantenimiento
    'cleanupOldData': FunctionConfig(
      name: 'cleanupOldData',
      timeout: Duration(minutes: 5),
      retries: 1,
      cacheable: false,
    ),
    'backupDatabase': FunctionConfig(
      name: 'backupDatabase',
      timeout: Duration(minutes: 10),
      retries: 1,
      cacheable: false,
    ),
    'optimizeRoutes': FunctionConfig(
      name: 'optimizeRoutes',
      timeout: Duration(seconds: 30),
      retries: 2,
      cacheable: true,
    ),
  };

  // Métricas de funciones
  final Map<String, FunctionMetrics> _functionMetrics = {};

  /// Inicializa el servicio de Cloud Functions
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('⚡ Inicializando Cloud Functions Service para OasisTaxi');

      // Configurar región
      _functions.useFunctionsEmulator(
          'localhost', 5001); // Solo para desarrollo

      // Cargar configuración
      await _loadFunctionsConfig();

      // Inicializar cache cleanup
      _startCacheCleanup();

      // Cargar métricas
      await _loadFunctionMetrics();

      // Registrar funciones
      await _registerFunctions();

      _isInitialized = true;
      AppLogger.info('✅ Cloud Functions Service inicializado correctamente');
    } catch (e, stackTrace) {
      AppLogger.error(
          '❌ Error al inicializar Cloud Functions Service', e, stackTrace);
      rethrow;
    }
  }

  /// Carga la configuración de Functions
  Future<void> _loadFunctionsConfig() async {
    try {
      final doc = await _firestore
          .collection('configuration')
          .doc('functions_config')
          .get();

      if (doc.exists) {
        _functionsConfig = doc.data() ?? {};
      } else {
        _functionsConfig = _getDefaultFunctionsConfig();
        await _saveFunctionsConfig();
      }

      AppLogger.info('📋 Configuración de Functions cargada');
    } catch (e) {
      AppLogger.error('Error al cargar configuración de Functions', e);
      _functionsConfig = _getDefaultFunctionsConfig();
    }
  }

  /// Obtiene configuración por defecto
  Map<String, dynamic> _getDefaultFunctionsConfig() {
    return {
      'region': _region,
      'enableCache': true,
      'cacheExpirationMinutes': 5,
      'enableRetries': true,
      'maxRetries': 3,
      'timeoutSeconds': 30,
      'enableRateLimiting': true,
      'rateLimitPerMinute': 60,
      'enableMetrics': true,
      'enableErrorReporting': true,
      'environment': 'production',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Guarda configuración de Functions
  Future<void> _saveFunctionsConfig() async {
    try {
      await _firestore
          .collection('configuration')
          .doc('functions_config')
          .set(_functionsConfig, SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Error al guardar configuración de Functions', e);
    }
  }

  /// Registra funciones disponibles
  Future<void> _registerFunctions() async {
    try {
      for (final entry in _availableFunctions.entries) {
        await _firestore.collection('cloud_functions').doc(entry.key).set({
          'name': entry.value.name,
          'timeout': entry.value.timeout.inSeconds,
          'retries': entry.value.retries,
          'cacheable': entry.value.cacheable,
          'registered': true,
          'registeredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      AppLogger.info('✅ ${_availableFunctions.length} funciones registradas');
    } catch (e) {
      AppLogger.error('Error al registrar funciones', e);
    }
  }

  /// Inicia limpieza de cache
  void _startCacheCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanFunctionCache();
    });
  }

  /// Limpia cache de funciones
  void _cleanFunctionCache() {
    final now = DateTime.now();
    _functionCache.removeWhere((key, cached) {
      return now.difference(cached.timestamp) > _cacheExpiration;
    });

    AppLogger.debug(
        '🧹 Cache de funciones limpiado: ${_functionCache.length} entradas');
  }

  /// Calcula precio del viaje
  Future<TripPriceResult> calculateTripPrice({
    required double distance,
    required int duration,
    required String vehicleType,
    required DateTime requestTime,
    String? promoCode,
    Map<String, dynamic>? additionalFactors,
  }) async {
    try {
      AppLogger.info('💰 Calculando precio del viaje');

      // Verificar cache
      final cacheKey = '$distance-$duration-$vehicleType-${requestTime.hour}';
      if (_functionCache.containsKey(cacheKey)) {
        final cached = _functionCache[cacheKey]!;
        if (DateTime.now().difference(cached.timestamp) < _cacheExpiration) {
          AppLogger.debug('✅ Precio obtenido de cache');
          return TripPriceResult.fromJson(cached.data);
        }
      }

      // Llamar función
      final result = await _callFunction(
        'calculateTripPrice',
        parameters: {
          'distance': distance,
          'duration': duration,
          'vehicleType': vehicleType,
          'requestTime': requestTime.toIso8601String(),
          'promoCode': promoCode,
          'additionalFactors': additionalFactors,
        },
      );

      // Guardar en cache
      _functionCache[cacheKey] = CachedFunctionResult(
        data: result.data,
        timestamp: DateTime.now(),
      );

      return TripPriceResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al calcular precio', e, stackTrace);

      // Cálculo fallback local
      return _calculatePriceFallback(distance, duration, vehicleType);
    }
  }

  /// Cálculo de precio fallback
  TripPriceResult _calculatePriceFallback(
    double distance,
    int duration,
    String vehicleType,
  ) {
    // Tarifas base por tipo de vehículo (Soles)
    final rates = {
      'economico': {'base': 5.0, 'perKm': 1.5, 'perMin': 0.3},
      'comfort': {'base': 7.0, 'perKm': 2.0, 'perMin': 0.4},
      'premium': {'base': 10.0, 'perKm': 3.0, 'perMin': 0.6},
      'van': {'base': 12.0, 'perKm': 3.5, 'perMin': 0.7},
    };

    final rate = rates[vehicleType] ?? rates['economico']!;
    final basePrice = rate['base']! +
        (distance * rate['perKm']!) +
        (duration * rate['perMin']!);

    return TripPriceResult(
      basePrice: basePrice,
      finalPrice: basePrice,
      breakdown: {
        'base': rate['base']!,
        'distance': distance * rate['perKm']!,
        'time': duration * rate['perMin']!,
      },
      currency: 'PEN',
    );
  }

  /// Empareja conductor con viaje
  Future<DriverMatchResult> matchDriverToTrip({
    required String tripId,
    required Map<String, double> pickupLocation,
    required String vehicleType,
    required double offeredPrice,
    int radiusKm = 5,
  }) async {
    try {
      AppLogger.info('🚗 Buscando conductor para viaje $tripId');

      final result = await _callFunction(
        'matchDriverToTrip',
        parameters: {
          'tripId': tripId,
          'pickupLocation': pickupLocation,
          'vehicleType': vehicleType,
          'offeredPrice': offeredPrice,
          'radiusKm': radiusKm,
        },
      );

      return DriverMatchResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al emparejar conductor', e, stackTrace);
      throw FunctionException('No se pudo encontrar conductor disponible');
    }
  }

  /// Procesa pago
  Future<PaymentResult> processPayment({
    required String tripId,
    required String userId,
    required double amount,
    required String paymentMethod,
    String? paymentToken,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.info('💳 Procesando pago de S/ $amount para viaje $tripId');

      // No cachear pagos
      final result = await _callFunction(
        'processPayment',
        parameters: {
          'tripId': tripId,
          'userId': userId,
          'amount': amount,
          'paymentMethod': paymentMethod,
          'paymentToken': paymentToken,
          'currency': 'PEN',
          'metadata': metadata,
        },
      );

      final paymentResult = PaymentResult.fromJson(result.data);

      // Registrar en Firestore
      await _firestore.collection('payments').add({
        'tripId': tripId,
        'userId': userId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'status': paymentResult.status,
        'transactionId': paymentResult.transactionId,
        'processedAt': FieldValue.serverTimestamp(),
      });

      return paymentResult;
    } catch (e, stackTrace) {
      AppLogger.error('Error al procesar pago', e, stackTrace);
      throw FunctionException('Error al procesar el pago');
    }
  }

  /// Completa viaje
  Future<CompleteTripResult> completeTrip({
    required String tripId,
    required String driverId,
    required double finalDistance,
    required int finalDuration,
    required double finalPrice,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      AppLogger.info('✅ Completando viaje $tripId');

      final result = await _callFunction(
        'completeTrip',
        parameters: {
          'tripId': tripId,
          'driverId': driverId,
          'finalDistance': finalDistance,
          'finalDuration': finalDuration,
          'finalPrice': finalPrice,
          'additionalData': additionalData,
        },
      );

      return CompleteTripResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al completar viaje', e, stackTrace);
      throw FunctionException('No se pudo completar el viaje');
    }
  }

  /// Envía notificación
  Future<NotificationResult> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String priority = 'normal',
  }) async {
    try {
      AppLogger.info('📨 Enviando notificación a usuario $userId');

      final result = await _callFunction(
        'sendNotification',
        parameters: {
          'userId': userId,
          'title': title,
          'body': body,
          'data': data,
          'priority': priority,
        },
      );

      return NotificationResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al enviar notificación', e, stackTrace);
      throw FunctionException('No se pudo enviar la notificación');
    }
  }

  /// Envía notificaciones masivas
  Future<BulkNotificationResult> sendBulkNotifications({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? segment,
  }) async {
    try {
      AppLogger.info(
          '📨 Enviando notificaciones masivas a ${userIds.length} usuarios');

      final result = await _callFunction(
        'sendBulkNotifications',
        parameters: {
          'userIds': userIds,
          'title': title,
          'body': body,
          'data': data,
          'segment': segment,
        },
      );

      return BulkNotificationResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al enviar notificaciones masivas', e, stackTrace);
      throw FunctionException('Error en envío masivo de notificaciones');
    }
  }

  /// Envía alerta de emergencia
  Future<EmergencyAlertResult> sendEmergencyAlert({
    required String tripId,
    required String userId,
    required Map<String, double> location,
    required String emergencyType,
    String? message,
  }) async {
    try {
      AppLogger.critical('🚨 ENVIANDO ALERTA DE EMERGENCIA para viaje $tripId');

      // Alta prioridad, sin cache
      final result = await _callFunction(
        'sendEmergencyAlert',
        parameters: {
          'tripId': tripId,
          'userId': userId,
          'location': location,
          'emergencyType': emergencyType,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final alertResult = EmergencyAlertResult.fromJson(result.data);

      // Registrar en Firestore inmediatamente
      await _firestore.collection('emergency_alerts').add({
        'tripId': tripId,
        'userId': userId,
        'location': location,
        'emergencyType': emergencyType,
        'message': message,
        'alertId': alertResult.alertId,
        'notifiedContacts': alertResult.notifiedContacts,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      return alertResult;
    } catch (e, stackTrace) {
      AppLogger.error(
          'ERROR CRÍTICO al enviar alerta de emergencia', e, stackTrace);

      // Fallback: intentar guardar localmente
      await _saveEmergencyAlertLocally(tripId, userId, location, emergencyType);

      throw FunctionException('Error crítico en alerta de emergencia');
    }
  }

  /// Verifica documentos del conductor
  Future<DocumentVerificationResult> verifyDriverDocuments({
    required String driverId,
    required Map<String, String> documentUrls,
    required String verificationType,
  }) async {
    try {
      AppLogger.info('📄 Verificando documentos del conductor $driverId');

      final result = await _callFunction(
        'verifyDriverDocuments',
        parameters: {
          'driverId': driverId,
          'documentUrls': documentUrls,
          'verificationType': verificationType,
        },
      );

      final verificationResult =
          DocumentVerificationResult.fromJson(result.data);

      // Actualizar estado en Firestore
      await _firestore.collection('drivers').doc(driverId).update({
        'verificationStatus': verificationResult.status,
        'verifiedDocuments': verificationResult.verifiedDocuments,
        'verificationDate': FieldValue.serverTimestamp(),
      });

      return verificationResult;
    } catch (e, stackTrace) {
      AppLogger.error('Error al verificar documentos', e, stackTrace);
      throw FunctionException('No se pudieron verificar los documentos');
    }
  }

  /// Verifica método de pago
  Future<PaymentMethodVerificationResult> verifyPaymentMethod({
    required String userId,
    required String paymentMethod,
    required Map<String, dynamic> paymentData,
  }) async {
    try {
      AppLogger.info('💳 Verificando método de pago para usuario $userId');

      final result = await _callFunction(
        'verifyPaymentMethod',
        parameters: {
          'userId': userId,
          'paymentMethod': paymentMethod,
          'paymentData': paymentData,
        },
      );

      return PaymentMethodVerificationResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al verificar método de pago', e, stackTrace);
      throw FunctionException('No se pudo verificar el método de pago');
    }
  }

  /// Valida código promocional
  Future<PromoCodeValidationResult> validatePromoCode({
    required String promoCode,
    required String userId,
    required double tripAmount,
  }) async {
    try {
      AppLogger.info('🎟️ Validando código promocional: $promoCode');

      // Verificar cache
      final cacheKey = 'promo_$promoCode';
      if (_functionCache.containsKey(cacheKey)) {
        final cached = _functionCache[cacheKey]!;
        if (DateTime.now().difference(cached.timestamp) < _cacheExpiration) {
          return PromoCodeValidationResult.fromJson(cached.data);
        }
      }

      final result = await _callFunction(
        'validatePromoCode',
        parameters: {
          'promoCode': promoCode,
          'userId': userId,
          'tripAmount': tripAmount,
        },
      );

      // Guardar en cache
      _functionCache[cacheKey] = CachedFunctionResult(
        data: result.data,
        timestamp: DateTime.now(),
      );

      return PromoCodeValidationResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al validar código promocional', e, stackTrace);
      throw FunctionException('Código promocional inválido');
    }
  }

  /// Genera reporte del conductor
  Future<DriverReportResult> generateDriverReport({
    required String driverId,
    required DateTime startDate,
    required DateTime endDate,
    required String reportType,
  }) async {
    try {
      AppLogger.info('📊 Generando reporte para conductor $driverId');

      // Cache por 5 minutos
      final cacheKey =
          'report_${driverId}_${startDate.toIso8601String()}_${endDate.toIso8601String()}_$reportType';
      if (_functionCache.containsKey(cacheKey)) {
        final cached = _functionCache[cacheKey]!;
        if (DateTime.now().difference(cached.timestamp) < _cacheExpiration) {
          return DriverReportResult.fromJson(cached.data);
        }
      }

      final result = await _callFunction(
        'generateDriverReport',
        parameters: {
          'driverId': driverId,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'reportType': reportType,
        },
      );

      // Guardar en cache
      _functionCache[cacheKey] = CachedFunctionResult(
        data: result.data,
        timestamp: DateTime.now(),
      );

      return DriverReportResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al generar reporte', e, stackTrace);
      throw FunctionException('No se pudo generar el reporte');
    }
  }

  /// Calcula ganancias del conductor
  Future<DriverEarningsResult> calculateDriverEarnings({
    required String driverId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      AppLogger.info('💰 Calculando ganancias del conductor $driverId');

      final result = await _callFunction(
        'calculateDriverEarnings',
        parameters: {
          'driverId': driverId,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
      );

      return DriverEarningsResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al calcular ganancias', e, stackTrace);
      throw FunctionException('No se pudieron calcular las ganancias');
    }
  }

  /// Genera factura
  Future<InvoiceResult> generateInvoice({
    required String tripId,
    required String userId,
    required String invoiceType,
    Map<String, dynamic>? billingData,
  }) async {
    try {
      AppLogger.info('📄 Generando factura para viaje $tripId');

      final result = await _callFunction(
        'generateInvoice',
        parameters: {
          'tripId': tripId,
          'userId': userId,
          'invoiceType': invoiceType,
          'billingData': billingData,
        },
      );

      return InvoiceResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al generar factura', e, stackTrace);
      throw FunctionException('No se pudo generar la factura');
    }
  }

  /// Suspende usuario
  Future<UserSuspensionResult> suspendUser({
    required String userId,
    required String reason,
    required int durationDays,
    String? adminId,
  }) async {
    try {
      AppLogger.warning(
          '⛔ Suspendiendo usuario $userId por $durationDays días');

      final result = await _callFunction(
        'suspendUser',
        parameters: {
          'userId': userId,
          'reason': reason,
          'durationDays': durationDays,
          'adminId': adminId,
          'suspendedAt': DateTime.now().toIso8601String(),
        },
      );

      return UserSuspensionResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al suspender usuario', e, stackTrace);
      throw FunctionException('No se pudo suspender al usuario');
    }
  }

  /// Aprueba conductor
  Future<DriverApprovalResult> approveDriver({
    required String driverId,
    required String adminId,
    Map<String, dynamic>? approvalData,
  }) async {
    try {
      AppLogger.info('✅ Aprobando conductor $driverId');

      final result = await _callFunction(
        'approveDriver',
        parameters: {
          'driverId': driverId,
          'adminId': adminId,
          'approvalData': approvalData,
          'approvedAt': DateTime.now().toIso8601String(),
        },
      );

      final approvalResult = DriverApprovalResult.fromJson(result.data);

      // Actualizar estado en Firestore
      await _firestore.collection('drivers').doc(driverId).update({
        'status': 'approved',
        'approvedBy': adminId,
        'approvedAt': FieldValue.serverTimestamp(),
        'canAcceptTrips': true,
      });

      return approvalResult;
    } catch (e, stackTrace) {
      AppLogger.error('Error al aprobar conductor', e, stackTrace);
      throw FunctionException('No se pudo aprobar al conductor');
    }
  }

  /// Procesa retiro de fondos
  Future<WithdrawalResult> processWithdrawal({
    required String driverId,
    required double amount,
    required String withdrawalMethod,
    required Map<String, dynamic> bankDetails,
  }) async {
    try {
      AppLogger.info(
          '💸 Procesando retiro de S/ $amount para conductor $driverId');

      final result = await _callFunction(
        'processWithdrawal',
        parameters: {
          'driverId': driverId,
          'amount': amount,
          'withdrawalMethod': withdrawalMethod,
          'bankDetails': bankDetails,
          'currency': 'PEN',
          'requestedAt': DateTime.now().toIso8601String(),
        },
      );

      return WithdrawalResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al procesar retiro', e, stackTrace);
      throw FunctionException('No se pudo procesar el retiro');
    }
  }

  /// Optimiza rutas
  Future<RouteOptimizationResult> optimizeRoutes({
    required List<Map<String, double>> waypoints,
    required Map<String, double> origin,
    required Map<String, double> destination,
    String? vehicleType,
  }) async {
    try {
      AppLogger.info('🗺️ Optimizando ruta con ${waypoints.length} puntos');

      // Cache por ubicación
      final cacheKey =
          'route_${origin.hashCode}_${destination.hashCode}_${waypoints.length}';
      if (_functionCache.containsKey(cacheKey)) {
        final cached = _functionCache[cacheKey]!;
        if (DateTime.now().difference(cached.timestamp) < _cacheExpiration) {
          return RouteOptimizationResult.fromJson(cached.data);
        }
      }

      final result = await _callFunction(
        'optimizeRoutes',
        parameters: {
          'waypoints': waypoints,
          'origin': origin,
          'destination': destination,
          'vehicleType': vehicleType,
        },
      );

      // Guardar en cache
      _functionCache[cacheKey] = CachedFunctionResult(
        data: result.data,
        timestamp: DateTime.now(),
      );

      return RouteOptimizationResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al optimizar rutas', e, stackTrace);
      throw FunctionException('No se pudieron optimizar las rutas');
    }
  }

  /// Limpia datos antiguos
  Future<CleanupResult> cleanupOldData({
    int daysToKeep = 365,
    List<String>? collections,
  }) async {
    try {
      AppLogger.info('🧹 Limpiando datos antiguos (> $daysToKeep días)');

      final result = await _callFunction(
        'cleanupOldData',
        parameters: {
          'daysToKeep': daysToKeep,
          'collections': collections ?? ['trips', 'logs', 'analytics_events'],
        },
      );

      return CleanupResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al limpiar datos', e, stackTrace);
      throw FunctionException('No se pudieron limpiar los datos');
    }
  }

  /// Respalda base de datos
  Future<BackupResult> backupDatabase({
    String? backupType,
    List<String>? collections,
  }) async {
    try {
      AppLogger.info('💾 Iniciando respaldo de base de datos');

      final result = await _callFunction(
        'backupDatabase',
        parameters: {
          'backupType': backupType ?? 'full',
          'collections': collections,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return BackupResult.fromJson(result.data);
    } catch (e, stackTrace) {
      AppLogger.error('Error al respaldar base de datos', e, stackTrace);
      throw FunctionException('No se pudo respaldar la base de datos');
    }
  }

  /// Método público para llamar funciones (usado por otros servicios)
  Future<HttpsCallableResult> callFunction(
    String functionName, {
    Map<String, dynamic>? parameters,
  }) async {
    return _callFunction(functionName, parameters: parameters);
  }

  /// Llama a una función genérica
  Future<HttpsCallableResult> _callFunction(
    String functionName, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      // Verificar rate limiting
      if (!_checkRateLimit(functionName)) {
        throw FunctionException(
            'Límite de llamadas excedido. Intenta más tarde.');
      }

      // Obtener configuración de la función
      final config = _availableFunctions[functionName];
      if (config == null) {
        throw FunctionException('Función no disponible: $functionName');
      }

      // Configurar función
      final callable = _functions.httpsCallable(
        functionName,
        options: HttpsCallableOptions(
          timeout: config.timeout,
        ),
      );

      // Llamar función con reintentos
      HttpsCallableResult? result;
      int attempts = 0;

      while (attempts < config.retries) {
        try {
          attempts++;
          result = await callable.call(parameters);

          // Actualizar métricas
          _updateFunctionMetrics(functionName, true);

          return result;
        } catch (e) {
          if (attempts >= config.retries) {
            _updateFunctionMetrics(functionName, false);
            rethrow;
          }

          // Esperar antes de reintentar
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }

      throw FunctionException('Función falló después de $attempts intentos');
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('Error de Firebase Functions', e);
      throw FunctionException(_getFunctionErrorMessage(e.code));
    } catch (e) {
      AppLogger.error('Error al llamar función', e);
      rethrow;
    }
  }

  /// Verifica rate limiting
  bool _checkRateLimit(String functionName) {
    if (_functionsConfig['enableRateLimiting'] != true) {
      return true;
    }

    final now = DateTime.now();
    final limit = _functionsConfig['rateLimitPerMinute'] ?? 60;

    if (!_rateLimits.containsKey(functionName)) {
      _rateLimits[functionName] = RateLimitInfo(
        count: 1,
        windowStart: now,
      );
      return true;
    }

    final rateLimit = _rateLimits[functionName]!;

    // Reiniciar ventana si ha pasado un minuto
    if (now.difference(rateLimit.windowStart).inMinutes >= 1) {
      rateLimit.count = 1;
      rateLimit.windowStart = now;
      return true;
    }

    // Verificar límite
    if (rateLimit.count >= limit) {
      return false;
    }

    rateLimit.count++;
    return true;
  }

  /// Actualiza métricas de función
  void _updateFunctionMetrics(String functionName, bool success) {
    if (!_functionMetrics.containsKey(functionName)) {
      _functionMetrics[functionName] = FunctionMetrics(
        name: functionName,
        totalCalls: 0,
        successfulCalls: 0,
        failedCalls: 0,
        averageLatency: 0,
      );
    }

    final metrics = _functionMetrics[functionName]!;
    metrics.totalCalls++;

    if (success) {
      metrics.successfulCalls++;
    } else {
      metrics.failedCalls++;
    }

    // Guardar métricas periódicamente
    if (metrics.totalCalls % 10 == 0) {
      _saveFunctionMetrics();
    }
  }

  /// Guarda métricas de funciones
  Future<void> _saveFunctionMetrics() async {
    try {
      for (final entry in _functionMetrics.entries) {
        await _firestore
            .collection('function_metrics')
            .doc(entry.key)
            .set(entry.value.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      AppLogger.error('Error al guardar métricas de funciones', e);
    }
  }

  /// Carga métricas de funciones
  Future<void> _loadFunctionMetrics() async {
    try {
      final snapshot = await _firestore.collection('function_metrics').get();

      for (final doc in snapshot.docs) {
        _functionMetrics[doc.id] = FunctionMetrics.fromMap(doc.data());
      }

      AppLogger.info('📊 Métricas de funciones cargadas');
    } catch (e) {
      AppLogger.error('Error al cargar métricas de funciones', e);
    }
  }

  /// Guarda alerta de emergencia localmente
  Future<void> _saveEmergencyAlertLocally(
    String tripId,
    String userId,
    Map<String, double> location,
    String emergencyType,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alerts = prefs.getStringList('pending_emergency_alerts') ?? [];

      alerts.add(jsonEncode({
        'tripId': tripId,
        'userId': userId,
        'location': location,
        'emergencyType': emergencyType,
        'timestamp': DateTime.now().toIso8601String(),
      }));

      await prefs.setStringList('pending_emergency_alerts', alerts);
    } catch (e) {
      AppLogger.error('Error al guardar alerta localmente', e);
    }
  }

  /// Obtiene mensaje de error legible
  String _getFunctionErrorMessage(String code) {
    switch (code) {
      case 'cancelled':
        return 'La operación fue cancelada';
      case 'invalid-argument':
        return 'Datos inválidos proporcionados';
      case 'deadline-exceeded':
        return 'Tiempo de espera agotado';
      case 'not-found':
        return 'Recurso no encontrado';
      case 'already-exists':
        return 'El recurso ya existe';
      case 'permission-denied':
        return 'No tienes permisos para esta operación';
      case 'resource-exhausted':
        return 'Límite de recursos excedido';
      case 'failed-precondition':
        return 'Condiciones previas no cumplidas';
      case 'aborted':
        return 'Operación abortada';
      case 'out-of-range':
        return 'Valor fuera de rango';
      case 'unimplemented':
        return 'Función no implementada';
      case 'internal':
        return 'Error interno del servidor';
      case 'unavailable':
        return 'Servicio no disponible';
      case 'data-loss':
        return 'Pérdida de datos detectada';
      case 'unauthenticated':
        return 'No autenticado';
      default:
        return 'Error desconocido: $code';
    }
  }

  /// Obtiene métricas de funciones
  Map<String, FunctionMetrics> getFunctionMetrics() =>
      Map.from(_functionMetrics);

  /// Limpia recursos
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _saveFunctionMetrics();
    AppLogger.info('🔚 Cloud Functions Service disposed');
  }
}

// Modelos auxiliares

/// Configuración de función
class FunctionConfig {
  final String name;
  final Duration timeout;
  final int retries;
  final bool cacheable;

  const FunctionConfig({
    required this.name,
    required this.timeout,
    required this.retries,
    required this.cacheable,
  });
}

/// Resultado cacheado de función
class CachedFunctionResult {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  CachedFunctionResult({
    required this.data,
    required this.timestamp,
  });
}

/// Información de rate limiting
class RateLimitInfo {
  int count;
  DateTime windowStart;

  RateLimitInfo({
    required this.count,
    required this.windowStart,
  });
}

/// Métricas de función
class FunctionMetrics {
  final String name;
  int totalCalls;
  int successfulCalls;
  int failedCalls;
  double averageLatency;

  FunctionMetrics({
    required this.name,
    required this.totalCalls,
    required this.successfulCalls,
    required this.failedCalls,
    required this.averageLatency,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'totalCalls': totalCalls,
        'successfulCalls': successfulCalls,
        'failedCalls': failedCalls,
        'successRate': totalCalls > 0 ? successfulCalls / totalCalls : 0,
        'averageLatency': averageLatency,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

  factory FunctionMetrics.fromMap(Map<String, dynamic> map) => FunctionMetrics(
        name: map['name'] ?? '',
        totalCalls: map['totalCalls'] ?? 0,
        successfulCalls: map['successfulCalls'] ?? 0,
        failedCalls: map['failedCalls'] ?? 0,
        averageLatency: (map['averageLatency'] ?? 0).toDouble(),
      );
}

/// Excepción de función
class FunctionException implements Exception {
  final String message;

  FunctionException(this.message);

  @override
  String toString() => 'FunctionException: $message';
}

// Modelos de resultados específicos

class TripPriceResult {
  final double basePrice;
  final double finalPrice;
  final Map<String, double> breakdown;
  final String currency;

  TripPriceResult({
    required this.basePrice,
    required this.finalPrice,
    required this.breakdown,
    required this.currency,
  });

  factory TripPriceResult.fromJson(Map<String, dynamic> json) =>
      TripPriceResult(
        basePrice: (json['basePrice'] ?? 0).toDouble(),
        finalPrice: (json['finalPrice'] ?? 0).toDouble(),
        breakdown: Map<String, double>.from(json['breakdown'] ?? {}),
        currency: json['currency'] ?? 'PEN',
      );
}

class DriverMatchResult {
  final String? driverId;
  final String? driverName;
  final double? rating;
  final double? distance;
  final int? estimatedArrival;
  final bool found;

  DriverMatchResult({
    this.driverId,
    this.driverName,
    this.rating,
    this.distance,
    this.estimatedArrival,
    required this.found,
  });

  factory DriverMatchResult.fromJson(Map<String, dynamic> json) =>
      DriverMatchResult(
        driverId: json['driverId'],
        driverName: json['driverName'],
        rating: (json['rating'] ?? 0).toDouble(),
        distance: (json['distance'] ?? 0).toDouble(),
        estimatedArrival: json['estimatedArrival'],
        found: json['found'] ?? false,
      );
}

class PaymentResult {
  final String transactionId;
  final String status;
  final double amount;
  final String? receiptUrl;

  PaymentResult({
    required this.transactionId,
    required this.status,
    required this.amount,
    this.receiptUrl,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) => PaymentResult(
        transactionId: json['transactionId'] ?? '',
        status: json['status'] ?? 'pending',
        amount: (json['amount'] ?? 0).toDouble(),
        receiptUrl: json['receiptUrl'],
      );
}

class CompleteTripResult {
  final String tripId;
  final String status;
  final double driverEarnings;
  final double platformCommission;

  CompleteTripResult({
    required this.tripId,
    required this.status,
    required this.driverEarnings,
    required this.platformCommission,
  });

  factory CompleteTripResult.fromJson(Map<String, dynamic> json) =>
      CompleteTripResult(
        tripId: json['tripId'] ?? '',
        status: json['status'] ?? 'completed',
        driverEarnings: (json['driverEarnings'] ?? 0).toDouble(),
        platformCommission: (json['platformCommission'] ?? 0).toDouble(),
      );
}

class NotificationResult {
  final String messageId;
  final bool sent;
  final String? error;

  NotificationResult({
    required this.messageId,
    required this.sent,
    this.error,
  });

  factory NotificationResult.fromJson(Map<String, dynamic> json) =>
      NotificationResult(
        messageId: json['messageId'] ?? '',
        sent: json['sent'] ?? false,
        error: json['error'],
      );
}

class BulkNotificationResult {
  final int totalSent;
  final int successful;
  final int failed;
  final List<String>? failedUserIds;

  BulkNotificationResult({
    required this.totalSent,
    required this.successful,
    required this.failed,
    this.failedUserIds,
  });

  factory BulkNotificationResult.fromJson(Map<String, dynamic> json) =>
      BulkNotificationResult(
        totalSent: json['totalSent'] ?? 0,
        successful: json['successful'] ?? 0,
        failed: json['failed'] ?? 0,
        failedUserIds: json['failedUserIds'] != null
            ? List<String>.from(json['failedUserIds'])
            : null,
      );
}

class EmergencyAlertResult {
  final String alertId;
  final List<String> notifiedContacts;
  final bool policeNotified;
  final bool ambulanceNotified;

  EmergencyAlertResult({
    required this.alertId,
    required this.notifiedContacts,
    required this.policeNotified,
    required this.ambulanceNotified,
  });

  factory EmergencyAlertResult.fromJson(Map<String, dynamic> json) =>
      EmergencyAlertResult(
        alertId: json['alertId'] ?? '',
        notifiedContacts: List<String>.from(json['notifiedContacts'] ?? []),
        policeNotified: json['policeNotified'] ?? false,
        ambulanceNotified: json['ambulanceNotified'] ?? false,
      );
}

class DocumentVerificationResult {
  final String status;
  final Map<String, bool> verifiedDocuments;
  final List<String>? issues;

  DocumentVerificationResult({
    required this.status,
    required this.verifiedDocuments,
    this.issues,
  });

  factory DocumentVerificationResult.fromJson(Map<String, dynamic> json) =>
      DocumentVerificationResult(
        status: json['status'] ?? 'pending',
        verifiedDocuments:
            Map<String, bool>.from(json['verifiedDocuments'] ?? {}),
        issues:
            json['issues'] != null ? List<String>.from(json['issues']) : null,
      );
}

class PaymentMethodVerificationResult {
  final bool isValid;
  final String? cardBrand;
  final String? last4Digits;

  PaymentMethodVerificationResult({
    required this.isValid,
    this.cardBrand,
    this.last4Digits,
  });

  factory PaymentMethodVerificationResult.fromJson(Map<String, dynamic> json) =>
      PaymentMethodVerificationResult(
        isValid: json['isValid'] ?? false,
        cardBrand: json['cardBrand'],
        last4Digits: json['last4Digits'],
      );
}

class PromoCodeValidationResult {
  final bool isValid;
  final double? discountAmount;
  final double? discountPercentage;
  final String? message;

  PromoCodeValidationResult({
    required this.isValid,
    this.discountAmount,
    this.discountPercentage,
    this.message,
  });

  factory PromoCodeValidationResult.fromJson(Map<String, dynamic> json) =>
      PromoCodeValidationResult(
        isValid: json['isValid'] ?? false,
        discountAmount: json['discountAmount']?.toDouble(),
        discountPercentage: json['discountPercentage']?.toDouble(),
        message: json['message'],
      );
}

class DriverReportResult {
  final String reportId;
  final String reportUrl;
  final Map<String, dynamic> summary;

  DriverReportResult({
    required this.reportId,
    required this.reportUrl,
    required this.summary,
  });

  factory DriverReportResult.fromJson(Map<String, dynamic> json) =>
      DriverReportResult(
        reportId: json['reportId'] ?? '',
        reportUrl: json['reportUrl'] ?? '',
        summary: json['summary'] ?? {},
      );
}

class DriverEarningsResult {
  final double totalEarnings;
  final double netEarnings;
  final double platformCommission;
  final int totalTrips;

  DriverEarningsResult({
    required this.totalEarnings,
    required this.netEarnings,
    required this.platformCommission,
    required this.totalTrips,
  });

  factory DriverEarningsResult.fromJson(Map<String, dynamic> json) =>
      DriverEarningsResult(
        totalEarnings: (json['totalEarnings'] ?? 0).toDouble(),
        netEarnings: (json['netEarnings'] ?? 0).toDouble(),
        platformCommission: (json['platformCommission'] ?? 0).toDouble(),
        totalTrips: json['totalTrips'] ?? 0,
      );
}

class InvoiceResult {
  final String invoiceId;
  final String invoiceUrl;
  final String invoiceNumber;

  InvoiceResult({
    required this.invoiceId,
    required this.invoiceUrl,
    required this.invoiceNumber,
  });

  factory InvoiceResult.fromJson(Map<String, dynamic> json) => InvoiceResult(
        invoiceId: json['invoiceId'] ?? '',
        invoiceUrl: json['invoiceUrl'] ?? '',
        invoiceNumber: json['invoiceNumber'] ?? '',
      );
}

class UserSuspensionResult {
  final bool suspended;
  final DateTime? suspendedUntil;

  UserSuspensionResult({
    required this.suspended,
    this.suspendedUntil,
  });

  factory UserSuspensionResult.fromJson(Map<String, dynamic> json) =>
      UserSuspensionResult(
        suspended: json['suspended'] ?? false,
        suspendedUntil: json['suspendedUntil'] != null
            ? DateTime.parse(json['suspendedUntil'])
            : null,
      );
}

class DriverApprovalResult {
  final bool approved;
  final String? message;

  DriverApprovalResult({
    required this.approved,
    this.message,
  });

  factory DriverApprovalResult.fromJson(Map<String, dynamic> json) =>
      DriverApprovalResult(
        approved: json['approved'] ?? false,
        message: json['message'],
      );
}

class WithdrawalResult {
  final String withdrawalId;
  final String status;
  final String? transactionReference;

  WithdrawalResult({
    required this.withdrawalId,
    required this.status,
    this.transactionReference,
  });

  factory WithdrawalResult.fromJson(Map<String, dynamic> json) =>
      WithdrawalResult(
        withdrawalId: json['withdrawalId'] ?? '',
        status: json['status'] ?? 'pending',
        transactionReference: json['transactionReference'],
      );
}

class RouteOptimizationResult {
  final List<Map<String, double>> optimizedRoute;
  final double totalDistance;
  final int estimatedTime;

  RouteOptimizationResult({
    required this.optimizedRoute,
    required this.totalDistance,
    required this.estimatedTime,
  });

  factory RouteOptimizationResult.fromJson(Map<String, dynamic> json) =>
      RouteOptimizationResult(
        optimizedRoute: List<Map<String, double>>.from(
            (json['optimizedRoute'] ?? [])
                .map((point) => Map<String, double>.from(point))),
        totalDistance: (json['totalDistance'] ?? 0).toDouble(),
        estimatedTime: json['estimatedTime'] ?? 0,
      );
}

class CleanupResult {
  final int deletedRecords;
  final int freedSpace;
  final List<String> cleanedCollections;

  CleanupResult({
    required this.deletedRecords,
    required this.freedSpace,
    required this.cleanedCollections,
  });

  factory CleanupResult.fromJson(Map<String, dynamic> json) => CleanupResult(
        deletedRecords: json['deletedRecords'] ?? 0,
        freedSpace: json['freedSpace'] ?? 0,
        cleanedCollections: List<String>.from(json['cleanedCollections'] ?? []),
      );
}

class BackupResult {
  final String backupId;
  final String backupUrl;
  final int recordsBackedUp;

  BackupResult({
    required this.backupId,
    required this.backupUrl,
    required this.recordsBackedUp,
  });

  factory BackupResult.fromJson(Map<String, dynamic> json) => BackupResult(
        backupId: json['backupId'] ?? '',
        backupUrl: json['backupUrl'] ?? '',
        recordsBackedUp: json['recordsBackedUp'] ?? 0,
      );
}

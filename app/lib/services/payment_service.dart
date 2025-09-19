import '../utils/app_logger.dart';
import 'dart:convert';
import 'http_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import '../core/config/environment_config.dart';
import 'transaction_security_service.dart';
import '../utils/validation_patterns.dart';

/// SERVICIO COMPLETO DE PAGOS OASIS TAXI - PERÚ
/// ============================================
///
/// Funcionalidades implementadas:
/// ✅ MercadoPago (preferencias y webhooks)
/// ✅ Yape (código QR y validación)
/// ✅ Plin (código QR y validación)
/// ✅ Comisiones automáticas (20% plataforma)
/// ✅ Reembolsos completos
/// ✅ Historial de pagos
/// ✅ Verificación de estado de pago
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  bool _initialized = false;
  late String _apiBaseUrl;
  late String _mercadoPagoPublicKey;
  final TransactionSecurityService _securityService = TransactionSecurityService();

  // All payment processing is done through Firebase Cloud Functions
  // External API endpoints have been removed for security

  /// Inicializar el servicio de pagos
  Future<void> initialize({bool isProduction = false}) async {
    if (_initialized) return;

    try {
      // API base URL - kept for backward compatibility with legacy consumers
      // All actual payment processing is now done through Firebase Cloud Functions
      _apiBaseUrl = EnvironmentConfig.apiBaseUrl;

      // Usar credenciales de MercadoPago desde variables de entorno
      _mercadoPagoPublicKey = EnvironmentConfig.mercadopagoPublicKey;
      // Note: Access token removed for security - all server calls via Cloud Functions

      await _firebaseService.initialize();

      _initialized = true;
      AppLogger.debug('💳 PaymentService: Inicializado');

      await _firebaseService.analytics?.logEvent(
        name: 'payment_service_initialized',
        parameters: {},
      );
    } catch (e) {
      AppLogger.debug('💳 PaymentService: Error inicializando - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      _initialized = true; // Continuar en modo desarrollo
    }
  }

  // ============================================================================
  // MERCADOPAGO - PREFERENCIAS DE PAGO
  // ============================================================================

  /// Crear preferencia de pago con MercadoPago
  Future<PaymentPreferenceResult> createMercadoPagoPreference({
    required String rideId,
    required double amount,
    required String payerEmail,
    required String payerName,
    String? description,
  }) async {
    try {
      AppLogger.debug(
          '💳 PaymentService: Creando preferencia MercadoPago - S/$amount');

      // Use Firebase Callable Function
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('processPayment');

      final response = await callable.call({
        'tripId': rideId,
        'amount': amount,
        'description': description ?? 'Viaje Oasis Taxi #$rideId',
        'paymentMethodId': 'mercadopago',
      });

      final data = response.data;

      if (data['success'] == true) {
        final payment = data['payment'];

        // Get commission rate from config or use default
        final commissionRate = await _getCommissionRate();
        final platformCommission = amount * commissionRate;
        final driverEarnings = amount - platformCommission;

        await _firebaseService.analytics?.logEvent(
          name: 'mercadopago_preference_created',
          parameters: {
            'ride_id': rideId,
            'amount': amount,
            'preference_id': payment['preferenceId'],
          },
        );

        return PaymentPreferenceResult.success(
          preferenceId: payment['preferenceId'],
          initPoint: payment['init_point'],
          publicKey: _mercadoPagoPublicKey,
          amount: amount,
          platformCommission: platformCommission,
          driverEarnings: driverEarnings,
        );
      } else {
        return PaymentPreferenceResult.error(
            data['message'] ?? 'Error creando preferencia');
      }
    } catch (e) {
      AppLogger.debug(
          '💳 PaymentService: Error creando preferencia MercadoPago - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return PaymentPreferenceResult.error('Error creando preferencia: $e');
    }
  }

  /// Abrir checkout de MercadoPago
  Future<bool> openMercadoPagoCheckout(String initPoint) async {
    try {
      final uri = Uri.parse(initPoint);
      if (await canLaunchUrl(uri)) {
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);

        await _firebaseService.analytics?.logEvent(
          name: 'mercadopago_checkout_opened',
          parameters: {
            'init_point': initPoint,
            'success': launched,
          },
        );

        return launched;
      } else {
        return false;
      }
    } catch (e) {
      AppLogger.debug(
          '💳 PaymentService: Error abriendo checkout MercadoPago - $e');
      return false;
    }
  }

  // ============================================================================
  // YAPE - PAGOS CON CÓDIGO QR
  // ============================================================================

  /// Procesar pago con Yape
  Future<YapePaymentResult> processWithYape({
    required String rideId,
    required double amount,
    required String phoneNumber,
    String? transactionCode,
  }) async {
    try {
      AppLogger.debug(
          '📱 PaymentService: Procesando pago con Yape - S/$amount');

      // Validar número de teléfono peruano usando ValidationPatterns
      if (!ValidationPatterns.isValidPeruMobile(phoneNumber)) {
        return YapePaymentResult.error(ValidationPatterns.getPhoneError());
      }

      // Use Firebase Callable Function
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('processYape');

      final response = await callable.call({
        'tripId': rideId,
        'amount': amount,
        'phoneNumber': phoneNumber,
        'transactionCode': transactionCode,
      });

      final data = response.data;

      if (data['success'] == true) {
        // Get commission rate from config
        final commissionRate = await _getCommissionRate();
        final platformCommission = amount * commissionRate;
        final driverEarnings = amount - platformCommission;

        await _firebaseService.analytics?.logEvent(
          name: 'yape_payment_initiated',
          parameters: {
            'ride_id': rideId,
            'amount': amount,
            'payment_id': data['paymentId'],
          },
        );

        return YapePaymentResult.success(
          paymentId: data['paymentId'],
          qrUrl: data['qrUrl'],
          phoneNumber: phoneNumber,
          amount: amount,
          instructions: data['instructions'] ?? 'Complete el pago en la app Yape',
          platformCommission: platformCommission,
          driverEarnings: driverEarnings,
        );
      } else {
        return YapePaymentResult.error(
            data['message'] ?? 'Error procesando pago con Yape');
      }
    } catch (e) {
      AppLogger.debug('📱 PaymentService: Error procesando pago con Yape - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return YapePaymentResult.error('Error procesando pago con Yape: $e');
    }
  }

  /// Abrir app de Yape con código QR
  Future<bool> openYapeApp(
      String phoneNumber, double amount, String message) async {
    try {
      final yapeUrl =
          'yape://payment?amount=$amount&phone=$phoneNumber&message=${Uri.encodeComponent(message)}';
      final uri = Uri.parse(yapeUrl);

      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri);

        await _firebaseService.analytics?.logEvent(
          name: 'yape_app_opened',
          parameters: {
            'amount': amount,
            'phone_number': phoneNumber,
            'success': launched,
          },
        );

        return launched;
      } else {
        // Fallback: abrir Play Store para descargar Yape
        final playStoreUri = Uri.parse(
            'https://play.google.com/store/apps/details?id=com.bcp.yape');
        return await launchUrl(playStoreUri,
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.debug('📱 PaymentService: Error abriendo app Yape - $e');
      return false;
    }
  }

  // ============================================================================
  // PLIN - PAGOS CON CÓDIGO QR
  // ============================================================================

  /// Procesar pago con Plin
  Future<PlinPaymentResult> processWithPlin({
    required String rideId,
    required double amount,
    required String phoneNumber,
  }) async {
    try {
      AppLogger.debug(
          '📱 PaymentService: Procesando pago con Plin - S/$amount');

      // Validar número de teléfono peruano usando ValidationPatterns
      if (!ValidationPatterns.isValidPeruMobile(phoneNumber)) {
        return PlinPaymentResult.error(ValidationPatterns.getPhoneError());
      }

      // Use Firebase Callable Function
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('processPlin');

      final response = await callable.call({
        'tripId': rideId,
        'amount': amount,
        'phoneNumber': phoneNumber,
      });

      final data = response.data;

      if (data['success'] == true) {
        // Get commission rate from config
        final commissionRate = await _getCommissionRate();
        final platformCommission = amount * commissionRate;
        final driverEarnings = amount - platformCommission;

        await _firebaseService.analytics?.logEvent(
          name: 'plin_payment_initiated',
          parameters: {
            'ride_id': rideId,
            'amount': amount,
            'payment_id': data['paymentId'],
          },
        );

        return PlinPaymentResult.success(
          paymentId: data['paymentId'],
          qrUrl: data['qrUrl'],
          phoneNumber: phoneNumber,
          amount: amount,
          instructions: data['instructions'] ?? 'Complete el pago en la app Plin',
          platformCommission: platformCommission,
          driverEarnings: driverEarnings,
        );
      } else {
        return PlinPaymentResult.error(
            data['message'] ?? 'Error procesando pago con Plin');
      }
    } catch (e) {
      AppLogger.debug('📱 PaymentService: Error procesando pago con Plin - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return PlinPaymentResult.error('Error procesando pago con Plin: $e');
    }
  }

  /// Abrir app de Plin
  Future<bool> openPlinApp(
      String phoneNumber, double amount, String message) async {
    try {
      final plinUrl =
          'plin://payment?amount=$amount&phone=$phoneNumber&message=${Uri.encodeComponent(message)}';
      final uri = Uri.parse(plinUrl);

      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri);

        await _firebaseService.analytics?.logEvent(
          name: 'plin_app_opened',
          parameters: {
            'amount': amount,
            'phone_number': phoneNumber,
            'success': launched,
          },
        );

        return launched;
      } else {
        // Fallback: abrir Play Store para descargar Plin
        final playStoreUri = Uri.parse(
            'https://play.google.com/store/apps/details?id=pe.interbank.plin');
        return await launchUrl(playStoreUri,
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.debug('📱 PaymentService: Error abriendo app Plin - $e');
      return false;
    }
  }

  // ============================================================================
  // VERIFICACIÓN Y ESTADO DE PAGOS
  // ============================================================================

  /// Verificar estado de pago
  Future<PaymentStatusResult> checkPaymentStatus(String paymentId) async {
    try {
      // Verification Comment 1: Use Cloud Functions instead of REST
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getPaymentStatus');

      final response = await callable.call({
        'paymentId': paymentId,
      });

      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final paymentData = data['payment'] as Map<String, dynamic>;
        final metadata = paymentData['metadata'] as Map<String, dynamic>? ?? {};

        return PaymentStatusResult.success(
          id: paymentData['id'] ?? paymentId,
          status: paymentData['status'] ?? 'unknown',
          amount: (paymentData['amount'] ?? 0.0).toDouble(),
          paymentMethod: paymentData['paymentMethod'] ?? metadata['paymentMethod'] ?? 'unknown',
          platformCommission: (metadata['commission'] ?? 0.0).toDouble(),
          driverEarnings: (paymentData['amount'] ?? 0.0).toDouble() - (metadata['commission'] ?? 0.0).toDouble(),
          createdAt: _parseTimestamp(paymentData['createdAt']),
          approvedAt: paymentData['completedAt'] != null
              ? _parseTimestamp(paymentData['completedAt'])
              : null,
          refundedAt: paymentData['refundedAt'] != null
              ? _parseTimestamp(paymentData['refundedAt'])
              : null,
        );
      } else {
        return PaymentStatusResult.error(data['message'] ?? 'Error verificando estado');
      }
    } catch (e) {
      AppLogger.debug('💳 PaymentService: Error verificando estado - $e');
      return PaymentStatusResult.error('Error verificando estado: $e');
    }
  }

  /// Helper method to parse timestamps from Firestore
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) return DateTime.parse(timestamp);
    if (timestamp is Map && timestamp['_seconds'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        timestamp['_seconds'] * 1000 + (timestamp['_nanoseconds'] ?? 0) ~/ 1000000
      );
    }
    return DateTime.now();
  }

  /// Obtener historial de pagos de usuario
  Future<List<PaymentHistoryItem>> getUserPaymentHistory(
      String userId, String role) async {
    try {
      // Verification Comment 1: Use Cloud Functions instead of REST
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('listUserPayments');

      final response = await callable.call({
        'role': role,
        'limit': 50,
      });

      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final List<dynamic> payments = data['payments'] ?? [];

        return payments
            .map((payment) {
              final metadata = payment['metadata'] as Map<String, dynamic>? ?? {};

              return PaymentHistoryItem(
                id: payment['id'] ?? '',
                rideId: payment['tripId'] ?? '',
                amount: (payment['amount'] ?? 0.0).toDouble(),
                paymentMethod: payment['paymentMethod'] ?? metadata['paymentMethod'] ?? 'unknown',
                status: payment['status'] ?? 'unknown',
                createdAt: _parseTimestamp(payment['createdAt']),
                approvedAt: payment['completedAt'] != null
                    ? _parseTimestamp(payment['completedAt'])
                    : null,
                platformCommission:
                    (metadata['commission'] ?? 0.0).toDouble(),
                driverEarnings:
                    (payment['amount'] ?? 0.0).toDouble() - (metadata['commission'] ?? 0.0).toDouble(),
              );
            })
            .toList();
      } else {
        AppLogger.debug('💳 PaymentService: Error en listUserPayments - ${data['message']}');
        return [];
      }
    } catch (e) {
      AppLogger.debug('💳 PaymentService: Error obteniendo historial - $e');
      return [];
    }
  }

  // ============================================================================
  // REEMBOLSOS
  // ============================================================================

  /// Procesar reembolso
  Future<RefundResult> processRefund({
    required String paymentId,
    double? amount,
    required String reason,
  }) async {
    try {
      // Verification Comment 1: Use Cloud Functions instead of REST
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('refundPayment');

      final response = await callable.call({
        'paymentId': paymentId,
        if (amount != null) 'amount': amount,
        'reason': reason,
      });

      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final refundId = data['refundId'] ?? '';
        final status = data['status'] ?? 'pending';
        final refundAmount = (data['amount'] ?? amount ?? 0.0).toDouble();

        await _firebaseService.analytics?.logEvent(
          name: 'refund_processed',
          parameters: {
            'payment_id': paymentId,
            'refund_id': refundId,
            'refund_amount': refundAmount,
            'reason': reason,
            'status': status,
          },
        );

        return RefundResult.success(
          refundAmount: refundAmount,
          status: status,
        );
      } else {
        return RefundResult.error(
            data['message'] ?? 'Error procesando reembolso');
      }
    } catch (e) {
      AppLogger.debug('💳 PaymentService: Error procesando reembolso - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return RefundResult.error('Error procesando reembolso: $e');
    }
  }

  /// Solicitar retiro de ganancias
  Future<WithdrawalResult> requestWithdrawal({
    required double amount,
    required Map<String, dynamic> bankAccount,
    String? notes,
  }) async {
    try {
      // Verification Comment 8: Get driverId from auth context
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Validate transaction with security service
      final validation = await _securityService.validateTransaction(
        userId: user.uid,
        type: 'withdrawal',
        amount: amount,
        metadata: {'bankAccount': bankAccount},
      );

      if (!validation.isValid) {
        return WithdrawalResult.error(validation.error ?? 'Transacción no válida');
      }

      // Use Firebase Callable Function
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('processWithdrawal');

      final response = await callable.call({
        // Verification Comment 8: Not sending driverId, server uses auth.uid
        'amount': amount,
        'bankAccount': bankAccount,
        'notes': notes,
      });

      final data = response.data;

      if (data['success'] == true) {
        // Audit the transaction
        await _securityService.auditTransaction(
          transactionId: data['withdrawalId'],
          userId: user.uid,
          type: 'withdrawal',
          amount: amount,
          validation: validation,
          metadata: {'bankAccount': bankAccount},
        );

        return WithdrawalResult.success(
          withdrawalId: data['withdrawalId'],
          status: data['status'] ?? 'pending',
          estimatedProcessingTime: '24-48 horas',
        );
      }
      return WithdrawalResult.error(data['message'] ?? 'Error procesando solicitud de retiro');
    } catch (e) {
      AppLogger.error('Error procesando retiro', e);
      return WithdrawalResult.error('Error de conectividad: $e');
    }
  }

  /// Transferir dinero entre conductores
  Future<TransferResult> transferToDriver({
    required String fromDriverId,
    required String toDriverId,
    required double amount,
    required String concept,
  }) async {
    try {
      // Validate transaction with security service
      final validation = await _securityService.validateTransaction(
        userId: fromDriverId,
        type: 'transfer',
        amount: amount,
        metadata: {'toDriverId': toDriverId},
      );

      if (!validation.isValid) {
        return TransferResult.error(validation.error ?? 'Transacción no válida');
      }

      // Use Firebase Callable Function
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('transferBetweenDrivers');

      final response = await callable.call({
        'toDriverId': toDriverId,
        'amount': amount,
        'concept': concept,
      });

      final data = response.data;

      if (data['success'] == true) {
        // Audit the transaction
        await _securityService.auditTransaction(
          transactionId: data['transferId'],
          userId: fromDriverId,
          type: 'transfer',
          amount: amount,
          validation: validation,
          metadata: {'toDriverId': toDriverId, 'concept': concept},
        );

        return TransferResult.success(
          transferId: data['transferId'],
          status: data['status'] ?? 'completed',
        );
      }
      return TransferResult.error(data['message'] ?? 'Error procesando transferencia');
    } catch (e) {
      AppLogger.error('Error procesando transferencia', e);
      return TransferResult.error('Error de conectividad: $e');
    }
  }

  // ============================================================================
  // CÁLCULOS Y UTILIDADES
  // ============================================================================

  /// Calcular tarifa del viaje
  double calculateFare({
    required double distanceKm,
    required int durationMinutes,
    required String vehicleType,
    bool applyDynamicPricing = false,
    double dynamicMultiplier = 1.0,
  }) {
    // 🇵🇪 TARIFAS COMPETITIVAS PARA LIMA, PERÚ (2024)
    // Basadas en tarifas de mercado actual (Uber, DiDi, InDrive)
    final baseFares = {
      'standard': 3.50, // Tarifa base competitiva S/3.50
      'premium': 5.00, // Premium (autos nuevos) S/5.00
      'van': 7.00, // Van familiar (6-8 personas) S/7.00
    };

    // Tarifas por kilómetro - Competitivas con el mercado
    final perKmRates = {
      'standard': 1.20, // S/1.20/km (competitivo)
      'premium': 1.80, // S/1.80/km (premium)
      'van': 2.50, // S/2.50/km (van familiar)
    };

    // Tarifas por minuto - Tiempo de espera y tráfico
    final perMinuteRates = {
      'standard': 0.25, // S/0.25/min (tráfico Lima)
      'premium': 0.40, // S/0.40/min (premium)
      'van': 0.60, // S/0.60/min (van familiar)
    };

    final baseFare = baseFares[vehicleType] ?? baseFares['standard']!;
    final perKm = perKmRates[vehicleType] ?? perKmRates['standard']!;
    final perMinute =
        perMinuteRates[vehicleType] ?? perMinuteRates['standard']!;

    double fare =
        baseFare + (distanceKm * perKm) + (durationMinutes * perMinute);

    // Aplicar pricing dinámico si está habilitado
    if (applyDynamicPricing) {
      fare *= dynamicMultiplier;
    }

    // Tarifa mínima competitiva S/4.50 (ajustada para Perú)
    return fare < 4.5 ? 4.5 : double.parse(fare.toStringAsFixed(2));
  }

  /// Calcular comisión de la plataforma (20%)
  double calculatePlatformCommission(double fareAmount) {
    return double.parse((fareAmount * 0.20).toStringAsFixed(2));
  }

  /// Calcular ganancias del conductor
  double calculateDriverEarnings(double fareAmount) {
    return double.parse((fareAmount * 0.80).toStringAsFixed(2));
  }

  // ============================================================================
  // MÉTODOS AUXILIARES PRIVADOS
  // ============================================================================

  // Método _validatePeruvianPhoneNumber eliminado - ahora se usa ValidationPatterns.isValidPeruMobile

  /// Obtener métodos de pago disponibles para Perú
  List<PaymentMethodInfo> getAvailablePaymentMethods() {
    return [
      // MercadoPago - Tarjetas y métodos digitales
      PaymentMethodInfo(
        id: 'mercadopago',
        name: 'MercadoPago',
        description: 'Visa, Mastercard, American Express',
        icon: '💳',
        isEnabled: true,
        requiresPhoneNumber: false,
      ),

      // Billeteras digitales populares en Perú
      PaymentMethodInfo(
        id: 'yape',
        name: 'Yape',
        description: 'BCP - Pago instantáneo con QR',
        icon: '🟡',
        isEnabled: true,
        requiresPhoneNumber: true,
      ),
      PaymentMethodInfo(
        id: 'plin',
        name: 'Plin',
        description: 'Interbank - Pago rápido con QR',
        icon: '🟣',
        isEnabled: true,
        requiresPhoneNumber: true,
      ),

      // Métodos bancarios Perú (via MercadoPago)
      PaymentMethodInfo(
        id: 'pagoefectivo',
        name: 'PagoEfectivo',
        description: 'Paga en Tambo+, Oxxo, Full',
        icon: '🏪',
        isEnabled: true,
        requiresPhoneNumber: false,
      ),
      PaymentMethodInfo(
        id: 'bank_transfer',
        name: 'Transferencia',
        description: 'BCP, BBVA, Interbank, Scotiabank',
        icon: '🏛️',
        isEnabled: true,
        requiresPhoneNumber: false,
      ),

      // Efectivo - siempre disponible
      PaymentMethodInfo(
        id: 'cash',
        name: 'Efectivo',
        description: 'Pago directo al conductor',
        icon: '💵',
        isEnabled: true,
        requiresPhoneNumber: false,
      ),
    ];
  }

  /// Get commission rate from Firestore config
  Future<double> _getCommissionRate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('commission')
          .get();

      if (doc.exists) {
        return (doc.data()?['rate'] ?? 0.20).toDouble();
      }
      return 0.20; // Default 20% commission
    } catch (e) {
      AppLogger.debug('Using default commission rate: $e');
      return 0.20;
    }
  }

  // Getters
  bool get isInitialized => _initialized;
  String get mercadoPagoPublicKey => _mercadoPagoPublicKey;
  String get apiBaseUrl => _apiBaseUrl;
}

// ============================================================================
// CLASES DE DATOS Y RESULTADOS
// ============================================================================

/// Resultado de creación de preferencia de MercadoPago
class PaymentPreferenceResult {
  final bool success;
  final String? preferenceId;
  final String? initPoint;
  final String? publicKey;
  final double? amount;
  final double? platformCommission;
  final double? driverEarnings;
  final String? error;

  PaymentPreferenceResult.success({
    required this.preferenceId,
    required this.initPoint,
    required this.publicKey,
    required this.amount,
    required this.platformCommission,
    required this.driverEarnings,
  })  : success = true,
        error = null;

  PaymentPreferenceResult.error(this.error)
      : success = false,
        preferenceId = null,
        initPoint = null,
        publicKey = null,
        amount = null,
        platformCommission = null,
        driverEarnings = null;
}

/// Resultado de pago con Yape
class YapePaymentResult {
  final bool success;
  final String? paymentId;
  final String? qrUrl;
  final String? phoneNumber;
  final double? amount;
  final String? instructions;
  final double? platformCommission;
  final double? driverEarnings;
  final String? error;

  YapePaymentResult.success({
    required this.paymentId,
    required this.qrUrl,
    required this.phoneNumber,
    required this.amount,
    required this.instructions,
    required this.platformCommission,
    required this.driverEarnings,
  })  : success = true,
        error = null;

  YapePaymentResult.error(this.error)
      : success = false,
        paymentId = null,
        qrUrl = null,
        phoneNumber = null,
        amount = null,
        instructions = null,
        platformCommission = null,
        driverEarnings = null;
}

/// Resultado de pago con Plin
class PlinPaymentResult {
  final bool success;
  final String? paymentId;
  final String? qrUrl;
  final String? phoneNumber;
  final double? amount;
  final String? instructions;
  final double? platformCommission;
  final double? driverEarnings;
  final String? error;

  PlinPaymentResult.success({
    required this.paymentId,
    required this.qrUrl,
    required this.phoneNumber,
    required this.amount,
    required this.instructions,
    required this.platformCommission,
    required this.driverEarnings,
  })  : success = true,
        error = null;

  PlinPaymentResult.error(this.error)
      : success = false,
        paymentId = null,
        qrUrl = null,
        phoneNumber = null,
        amount = null,
        instructions = null,
        platformCommission = null,
        driverEarnings = null;
}

/// Resultado de verificación de estado de pago
class PaymentStatusResult {
  final bool success;
  final String? id;
  final String? status;
  final double? amount;
  final String? paymentMethod;
  final double? platformCommission;
  final double? driverEarnings;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? refundedAt;
  final String? error;

  PaymentStatusResult.success({
    required this.id,
    required this.status,
    required this.amount,
    required this.paymentMethod,
    required this.platformCommission,
    required this.driverEarnings,
    required this.createdAt,
    this.approvedAt,
    this.refundedAt,
  })  : success = true,
        error = null;

  PaymentStatusResult.error(this.error)
      : success = false,
        id = null,
        status = null,
        amount = null,
        paymentMethod = null,
        platformCommission = null,
        driverEarnings = null,
        createdAt = null,
        approvedAt = null,
        refundedAt = null;
}

/// Item del historial de pagos
class PaymentHistoryItem {
  final String id;
  final String rideId;
  final double amount;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final double platformCommission;
  final double driverEarnings;

  PaymentHistoryItem({
    required this.id,
    required this.rideId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    required this.platformCommission,
    required this.driverEarnings,
  });
}

/// Resultado de reembolso
class RefundResult {
  final bool success;
  final double? refundAmount;
  final String? status;
  final String? error;

  RefundResult.success({
    required this.refundAmount,
    required this.status,
  })  : success = true,
        error = null;

  RefundResult.error(this.error)
      : success = false,
        refundAmount = null,
        status = null;
}

/// Resultado de solicitud de retiro
class WithdrawalResult {
  final bool success;
  final String? withdrawalId;
  final String? status;
  final String? estimatedProcessingTime;
  final String? error;

  WithdrawalResult.success({
    required this.withdrawalId,
    required this.status,
    required this.estimatedProcessingTime,
  }) : success = true, error = null;

  WithdrawalResult.error(this.error)
      : success = false,
        withdrawalId = null,
        status = null,
        estimatedProcessingTime = null;
}

/// Resultado de transferencia entre conductores
class TransferResult {
  final bool success;
  final String? transferId;
  final String? status;
  final String? error;

  TransferResult.success({
    required this.transferId,
    required this.status,
  }) : success = true, error = null;

  TransferResult.error(this.error)
      : success = false,
        transferId = null,
        status = null;
}

/// Información de método de pago
class PaymentMethodInfo {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isEnabled;
  final bool requiresPhoneNumber;

  PaymentMethodInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isEnabled,
    required this.requiresPhoneNumber,
  });
}

/// Estados de pago
enum PaymentStatus {
  pending,
  processing,
  approved,
  rejected,
  refunded,
  cancelled,
}

/// Métodos de pago disponibles
enum PaymentMethod {
  mercadopago,
  yape,
  plin,
  cash,
}

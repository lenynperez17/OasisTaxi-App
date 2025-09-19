import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../utils/app_logger.dart';
import 'http_client.dart';

/// Configuración específica de MercadoPago para Perú
class MercadoPagoPeruConfig {
  // URLs oficiales MercadoPago Perú
  static const String sandboxBaseUrl = 'https://api.mercadopago.com';
  static const String productionBaseUrl = 'https://api.mercadopago.com';

  // Configuraciones específicas para Perú
  static const String countryCode = 'PE';
  static const String currency = 'PEN'; // Soles peruanos
  static const String locale = 'es-PE';

  // Métodos de pago disponibles en Perú
  static const List<String> availablePaymentMethods = [
    'visa', // Visa
    'master', // Mastercard
    'amex', // American Express
    'diners', // Diners Club
    'pagoefectivo', // PagoEfectivo (específico Perú)
    'bcp', // Banco de Crédito del Perú
    'interbank', // Interbank
    'scotiabank', // Scotiabank Perú
    'bbva', // BBVA Continental
  ];

  // Comisiones MercadoPago Perú (2024)
  static const Map<String, double> commissionRates = {
    'credit_card': 0.0399, // 3.99% + IGV tarjetas crédito
    'debit_card': 0.0299, // 2.99% + IGV tarjetas débito
    'pagoefectivo': 0.0199, // 1.99% + IGV PagoEfectivo
    'bank_transfer': 0.0099, // 0.99% + IGV transferencias
  };

  // IGV Perú
  static const double igvRate = 0.18; // 18% IGV en Perú

  // Configuración webhook
  static const String webhookPath = '/api/mercadopago/webhook';
  static const List<String> webhookEvents = [
    'payment',
    'plan',
    'subscription',
    'invoice',
    'point_integration_wh',
  ];
}

/// Tipos de pago específicos de MercadoPago
enum MercadoPagoPaymentType {
  creditCard,
  debitCard,
  pagoEfectivo,
  bankTransfer,
  wallet,
}

/// Estado del pago en MercadoPago
enum MercadoPagoPaymentStatus {
  pending, // Pendiente
  approved, // Aprobado
  authorized, // Autorizado
  inProcess, // En proceso
  inMediation, // En mediación
  rejected, // Rechazado
  cancelled, // Cancelado
  refunded, // Reembolsado
  chargedBack, // Contracargo
}

/// Resultado de pago MercadoPago
class MercadoPagoPaymentResult {
  final bool success;
  final String? paymentId;
  final String? preferenceId;
  final MercadoPagoPaymentStatus status;
  final double amount;
  final double commission;
  final double netAmount;
  final String currency;
  final String? paymentMethodId;
  final String? payerEmail;
  final DateTime createdAt;
  final String? errorMessage;
  final Map<String, dynamic> rawResponse;

  const MercadoPagoPaymentResult({
    required this.success,
    this.paymentId,
    this.preferenceId,
    required this.status,
    required this.amount,
    required this.commission,
    required this.netAmount,
    required this.currency,
    this.paymentMethodId,
    this.payerEmail,
    required this.createdAt,
    this.errorMessage,
    this.rawResponse = const {},
  });

  factory MercadoPagoPaymentResult.fromJson(Map<String, dynamic> json) {
    final amount = (json['transaction_amount'] ?? 0.0).toDouble();
    final commission = (json['fee_details']?[0]?['amount'] ?? 0.0).toDouble();

    return MercadoPagoPaymentResult(
      success: json['status'] == 'approved',
      paymentId: json['id']?.toString(),
      preferenceId: json['preference_id']?.toString(),
      status: _parsePaymentStatus(json['status']),
      amount: amount,
      commission: commission,
      netAmount: amount - commission,
      currency: json['currency_id'] ?? 'PEN',
      paymentMethodId: json['payment_method_id'],
      payerEmail: json['payer']?['email'],
      createdAt: DateTime.parse(
          json['date_created'] ?? DateTime.now().toIso8601String()),
      errorMessage: json['status_detail'],
      rawResponse: json,
    );
  }

  static MercadoPagoPaymentStatus _parsePaymentStatus(String? status) {
    switch (status) {
      case 'approved':
        return MercadoPagoPaymentStatus.approved;
      case 'authorized':
        return MercadoPagoPaymentStatus.authorized;
      case 'in_process':
        return MercadoPagoPaymentStatus.inProcess;
      case 'in_mediation':
        return MercadoPagoPaymentStatus.inMediation;
      case 'rejected':
        return MercadoPagoPaymentStatus.rejected;
      case 'cancelled':
        return MercadoPagoPaymentStatus.cancelled;
      case 'refunded':
        return MercadoPagoPaymentStatus.refunded;
      case 'charged_back':
        return MercadoPagoPaymentStatus.chargedBack;
      default:
        return MercadoPagoPaymentStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'payment_id': paymentId,
      'preference_id': preferenceId,
      'status': status.toString(),
      'amount': amount,
      'commission': commission,
      'net_amount': netAmount,
      'currency': currency,
      'payment_method_id': paymentMethodId,
      'payer_email': payerEmail,
      'created_at': createdAt.toIso8601String(),
      'error_message': errorMessage,
    };
  }
}

/// Configuración de pago para OasisTaxi
class OasisTaxiPaymentConfig {
  final String rideId;
  final String passengerId;
  final String driverId;
  final double amount;
  final String description;
  final MercadoPagoPaymentType paymentType;
  final Map<String, dynamic> metadata;

  const OasisTaxiPaymentConfig({
    required this.rideId,
    required this.passengerId,
    required this.driverId,
    required this.amount,
    required this.description,
    required this.paymentType,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'ride_id': rideId,
      'passenger_id': passengerId,
      'driver_id': driverId,
      'amount': amount,
      'description': description,
      'payment_type': paymentType.toString(),
      'metadata': metadata,
    };
  }
}

/// Servicio especializado para MercadoPago Perú
/// Optimizado para OasisTaxi con comisiones y configuraciones locales
class MercadoPagoService {
  static final MercadoPagoService _instance = MercadoPagoService._internal();
  factory MercadoPagoService() => _instance;
  MercadoPagoService._internal();

  final HttpClient _httpClient = HttpClient();
  bool _isInitialized = false;
  String? _accessToken;
  String? _publicKey;
  String? _webhookSecret;
  bool _isProduction = false;

  // Cache de métodos de pago disponibles
  List<Map<String, dynamic>>? _paymentMethods;
  DateTime? _paymentMethodsLastUpdate;
  static const Duration _paymentMethodsCacheExpiry = Duration(hours: 24);

  /// Inicializa el servicio MercadoPago
  Future<bool> initialize({
    required String accessToken,
    required String publicKey,
    required String webhookSecret,
    bool isProduction = false,
  }) async {
    try {
      AppLogger.info('Inicializando MercadoPago Service para OasisTaxi Perú');

      if (accessToken.isEmpty || publicKey.isEmpty) {
        AppLogger.error(
            'Access Token y Public Key requeridos para MercadoPago');
        return false;
      }

      _accessToken = accessToken;
      _publicKey = publicKey;
      _webhookSecret = webhookSecret;
      _isProduction = isProduction;

      // Validar credenciales
      final validCredentials = await _validateCredentials();
      if (!validCredentials) {
        AppLogger.error('Credenciales de MercadoPago inválidas');
        return false;
      }

      // Obtener métodos de pago disponibles
      await _fetchPaymentMethods();

      // Configurar webhook
      if (_webhookSecret?.isNotEmpty == true) {
        await _configureWebhook();
      }

      _isInitialized = true;
      AppLogger.info('MercadoPago Service inicializado correctamente - '
          'Entorno: ${_isProduction ? 'PRODUCCIÓN' : 'SANDBOX'}');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error inicializando MercadoPago Service', e, stackTrace);
      _isInitialized = false;
      return false;
    }
  }

  /// Valida credenciales con MercadoPago
  Future<bool> _validateCredentials() async {
    try {
      final url = '${_getBaseUrl()}/users/me';
      final response = await _httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = response.jsonBody;
        AppLogger.info(
            'MercadoPago - Usuario validado: ${data['nickname']} (${data['country_id']})');

        // Verificar que sea cuenta de Perú
        if (data['country_id'] != 'PE') {
          AppLogger.warning(
              'La cuenta MercadoPago no es de Perú: ${data['country_id']}');
          return false;
        }

        return true;
      } else {
        AppLogger.error(
            'Error validando credenciales MercadoPago: ${response.statusCode}');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error en validación de credenciales MercadoPago', e, stackTrace);
      return false;
    }
  }

  /// Obtiene métodos de pago disponibles
  Future<void> _fetchPaymentMethods() async {
    try {
      final url = '${_getBaseUrl()}/v1/payment_methods';
      final response = await _httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> methods = response.jsonBody;
        _paymentMethods = methods.cast<Map<String, dynamic>>();
        _paymentMethodsLastUpdate = DateTime.now();

        AppLogger.info(
            'Métodos de pago cargados: ${_paymentMethods!.length} disponibles');
      } else {
        AppLogger.error(
            'Error obteniendo métodos de pago: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error cargando métodos de pago', e, stackTrace);
    }
  }

  /// Configura webhook para notificaciones
  Future<void> _configureWebhook() async {
    try {
      AppLogger.info('Configurando webhook MercadoPago');

      // En implementación real, configurar webhook URL
      final webhookUrl = _isProduction
          ? 'https://oasistaxi.com${MercadoPagoPeruConfig.webhookPath}'
          : 'https://dev.oasistaxi.com${MercadoPagoPeruConfig.webhookPath}';

      AppLogger.info('Webhook configurado: $webhookUrl');
    } catch (e, stackTrace) {
      AppLogger.error('Error configurando webhook', e, stackTrace);
    }
  }

  /// Crea preferencia de pago para un viaje
  Future<Map<String, dynamic>?> createPaymentPreference({
    required OasisTaxiPaymentConfig config,
    String? returnUrl,
    String? cancelUrl,
  }) async {
    try {
      if (!_isInitialized) {
        throw Exception('MercadoPago Service no inicializado');
      }

      AppLogger.info(
          'Creando preferencia de pago para viaje: ${config.rideId}');

      // Calcular comisión e IGV
      final commission =
          _calculateCommission(config.amount, config.paymentType);
      final igv = commission * MercadoPagoPeruConfig.igvRate;
      final totalWithCommission = config.amount + commission + igv;

      final preferenceData = {
        'items': [
          {
            'id': config.rideId,
            'title': config.description,
            'description': 'Viaje en OasisTaxi Perú - ${config.rideId}',
            'quantity': 1,
            'unit_price': config.amount,
            'currency_id': MercadoPagoPeruConfig.currency,
            'category_id': 'transportation',
          }
        ],
        'payer': {
          'name': 'Pasajero OasisTaxi',
          'surname': '',
          'email': 'passenger@oasistaxi.com', // Email temporal
          'phone': {'area_code': '51', 'number': '999999999'},
          'identification': {'type': 'DNI', 'number': '00000000'},
          'address': {
            'street_name': 'Lima',
            'street_number': 123,
            'zip_code': '15001'
          }
        },
        'back_urls': {
          'success': returnUrl ?? 'https://oasistaxi.com/payment/success',
          'failure': cancelUrl ?? 'https://oasistaxi.com/payment/failure',
          'pending': 'https://oasistaxi.com/payment/pending'
        },
        'auto_return': 'approved',
        'payment_methods': {
          'excluded_payment_methods': [],
          'excluded_payment_types': [],
          'installments': 1, // Solo pagos al contado para taxis
        },
        'notification_url': _isProduction
            ? 'https://oasistaxi.com${MercadoPagoPeruConfig.webhookPath}'
            : 'https://dev.oasistaxi.com${MercadoPagoPeruConfig.webhookPath}',
        'statement_descriptor': 'OASISTAXI PERU',
        'external_reference': config.rideId,
        'expires': true,
        'expiration_date_from': DateTime.now().toIso8601String(),
        'expiration_date_to':
            DateTime.now().add(Duration(hours: 1)).toIso8601String(),
        'metadata': {
          ...config.metadata,
          'ride_id': config.rideId,
          'passenger_id': config.passengerId,
          'driver_id': config.driverId,
          'payment_type': config.paymentType.toString(),
          'commission': commission,
          'igv': igv,
          'app_version': '1.0.0',
          'country': 'PE',
        }
      };

      final url = '${_getBaseUrl()}/checkout/preferences';
      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(preferenceData),
      );

      if (response.statusCode == 201) {
        final responseData = response.jsonBody;

        AppLogger.info(
            'Preferencia creada exitosamente: ${responseData['id']}');

        return {
          'preference_id': responseData['id'],
          'init_point': responseData['init_point'],
          'sandbox_init_point': responseData['sandbox_init_point'],
          'amount': config.amount,
          'commission': commission,
          'igv': igv,
          'total_with_fees': totalWithCommission,
          'currency': MercadoPagoPeruConfig.currency,
          'expires_at': responseData['expiration_date_to'],
        };
      } else {
        AppLogger.error(
            'Error creando preferencia: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error creando preferencia de pago', e, stackTrace);
      return null;
    }
  }

  /// Procesa pago directo (sin redirección)
  Future<MercadoPagoPaymentResult> processPayment({
    required OasisTaxiPaymentConfig config,
    required String cardToken,
    required Map<String, dynamic> payerInfo,
    int installments = 1,
  }) async {
    try {
      if (!_isInitialized) {
        throw Exception('MercadoPago Service no inicializado');
      }

      AppLogger.info('Procesando pago directo para viaje: ${config.rideId}');

      final commission =
          _calculateCommission(config.amount, config.paymentType);

      final paymentData = {
        'transaction_amount': config.amount,
        'token': cardToken,
        'description': config.description,
        'installments': installments,
        'payment_method_id': _getPaymentMethodId(config.paymentType),
        'issuer_id': payerInfo['issuer_id'],
        'payer': {
          'email': payerInfo['email'],
          'identification': {
            'type': payerInfo['identification_type'] ?? 'DNI',
            'number': payerInfo['identification_number']
          }
        },
        'external_reference': config.rideId,
        'metadata': {
          ...config.metadata,
          'ride_id': config.rideId,
          'passenger_id': config.passengerId,
          'driver_id': config.driverId,
          'commission': commission,
          'country': 'PE',
        },
        'notification_url': _isProduction
            ? 'https://oasistaxi.com${MercadoPagoPeruConfig.webhookPath}'
            : 'https://dev.oasistaxi.com${MercadoPagoPeruConfig.webhookPath}',
        'statement_descriptor': 'OASISTAXI PERU',
      };

      final url = '${_getBaseUrl()}/v1/payments';
      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'X-Idempotency-Key': _generateIdempotencyKey(config.rideId),
        },
        body: json.encode(paymentData),
      );

      final responseData = response.jsonBody;

      if (response.statusCode == 201) {
        final result = MercadoPagoPaymentResult.fromJson(responseData);

        AppLogger.info(
            'Pago procesado - ID: ${result.paymentId}, Status: ${result.status}');

        return result;
      } else {
        AppLogger.error(
            'Error procesando pago: ${response.statusCode} - ${response.body}');

        return MercadoPagoPaymentResult(
          success: false,
          status: MercadoPagoPaymentStatus.rejected,
          amount: config.amount,
          commission: commission,
          netAmount: config.amount - commission,
          currency: MercadoPagoPeruConfig.currency,
          createdAt: DateTime.now(),
          errorMessage: responseData['message'] ?? 'Error desconocido',
          rawResponse: responseData,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error en procesamiento de pago directo', e, stackTrace);

      return MercadoPagoPaymentResult(
        success: false,
        status: MercadoPagoPaymentStatus.rejected,
        amount: config.amount,
        commission: 0.0,
        netAmount: config.amount,
        currency: MercadoPagoPeruConfig.currency,
        createdAt: DateTime.now(),
        errorMessage: 'Error interno: ${e.toString()}',
      );
    }
  }

  /// Verifica estado de un pago
  Future<MercadoPagoPaymentResult?> getPaymentStatus(String paymentId) async {
    try {
      if (!_isInitialized) {
        throw Exception('MercadoPago Service no inicializado');
      }

      final url = '${_getBaseUrl()}/v1/payments/$paymentId';
      final response = await _httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.jsonBody;
        return MercadoPagoPaymentResult.fromJson(responseData);
      } else {
        AppLogger.error(
            'Error obteniendo estado de pago: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error verificando estado de pago', e, stackTrace);
      return null;
    }
  }

  /// Procesa webhook de MercadoPago
  Future<bool> processWebhook({
    required Map<String, dynamic> webhookData,
    required String signature,
  }) async {
    try {
      if (!_isInitialized) {
        AppLogger.warning('MercadoPago Service no inicializado para webhook');
        return false;
      }

      // Verificar firma del webhook
      if (!_verifyWebhookSignature(webhookData, signature)) {
        AppLogger.error('Firma de webhook MercadoPago inválida');
        return false;
      }

      final action = webhookData['action'];
      final dataId = webhookData['data']?['id'];

      AppLogger.info(
          'Webhook MercadoPago recibido - Action: $action, ID: $dataId');

      switch (action) {
        case 'payment.created':
        case 'payment.updated':
          return await _handlePaymentWebhook(dataId.toString());

        default:
          AppLogger.info('Webhook action no manejado: $action');
          return true;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error procesando webhook MercadoPago', e, stackTrace);
      return false;
    }
  }

  /// Maneja webhook de pago
  Future<bool> _handlePaymentWebhook(String paymentId) async {
    try {
      final paymentData = await getPaymentStatus(paymentId);

      if (paymentData != null) {
        AppLogger.info(
            'Webhook procesado - Pago $paymentId: ${paymentData.status}');

        // En implementación real, actualizar estado en Firestore
        // await _updatePaymentInFirestore(paymentData);

        return true;
      }

      return false;
    } catch (e, stackTrace) {
      AppLogger.error('Error manejando webhook de pago', e, stackTrace);
      return false;
    }
  }

  /// Verifica firma del webhook
  bool _verifyWebhookSignature(Map<String, dynamic> data, String signature) {
    try {
      if (_webhookSecret == null || _webhookSecret!.isEmpty) {
        AppLogger.warning('Webhook secret no configurado');
        return true; // En desarrollo, permitir webhooks sin verificación
      }

      final payload = json.encode(data);
      final expectedSignature = _generateWebhookSignature(payload);

      return signature == expectedSignature;
    } catch (e) {
      AppLogger.error('Error verificando firma de webhook', e);
      return false;
    }
  }

  /// Genera firma para webhook
  String _generateWebhookSignature(String payload) {
    final key = utf8.encode(_webhookSecret!);
    final bytes = utf8.encode(payload);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  /// Reembolsa un pago
  Future<bool> refundPayment({
    required String paymentId,
    double? amount,
    String? reason,
  }) async {
    try {
      if (!_isInitialized) {
        throw Exception('MercadoPago Service no inicializado');
      }

      AppLogger.info('Iniciando reembolso para pago: $paymentId');

      final refundData = <String, dynamic>{
        if (amount != null) 'amount': amount,
        if (reason != null) 'metadata': {'reason': reason},
      };

      final url = '${_getBaseUrl()}/v1/payments/$paymentId/refunds';
      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(refundData),
      );

      if (response.statusCode == 201) {
        final responseData = response.jsonBody;
        AppLogger.info('Reembolso exitoso - ID: ${responseData['id']}');
        return true;
      } else {
        AppLogger.error(
            'Error en reembolso: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error procesando reembolso', e, stackTrace);
      return false;
    }
  }

  // Métodos auxiliares

  String _getBaseUrl() {
    return _isProduction
        ? MercadoPagoPeruConfig.productionBaseUrl
        : MercadoPagoPeruConfig.sandboxBaseUrl;
  }

  double _calculateCommission(
      double amount, MercadoPagoPaymentType paymentType) {
    final rate =
        MercadoPagoPeruConfig.commissionRates[_getCommissionKey(paymentType)] ??
            0.0399;
    return amount * rate;
  }

  String _getCommissionKey(MercadoPagoPaymentType paymentType) {
    switch (paymentType) {
      case MercadoPagoPaymentType.creditCard:
        return 'credit_card';
      case MercadoPagoPaymentType.debitCard:
        return 'debit_card';
      case MercadoPagoPaymentType.pagoEfectivo:
        return 'pagoefectivo';
      case MercadoPagoPaymentType.bankTransfer:
        return 'bank_transfer';
      case MercadoPagoPaymentType.wallet:
        return 'credit_card'; // Usar tasa de tarjeta de crédito por defecto
    }
  }

  String _getPaymentMethodId(MercadoPagoPaymentType paymentType) {
    switch (paymentType) {
      case MercadoPagoPaymentType.creditCard:
        return 'visa'; // Ejemplo, debería detectarse automáticamente
      case MercadoPagoPaymentType.debitCard:
        return 'visa'; // Ejemplo
      case MercadoPagoPaymentType.pagoEfectivo:
        return 'pagoefectivo';
      case MercadoPagoPaymentType.bankTransfer:
        return 'bcp'; // Ejemplo
      case MercadoPagoPaymentType.wallet:
        return 'account_money';
    }
  }

  String _generateIdempotencyKey(String rideId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'oasistaxi_${rideId}_$timestamp';
  }

  /// Obtiene métodos de pago disponibles con cache
  Future<List<Map<String, dynamic>>> getAvailablePaymentMethods() async {
    try {
      // Verificar cache
      if (_paymentMethods != null && _paymentMethodsLastUpdate != null) {
        final timeSinceUpdate =
            DateTime.now().difference(_paymentMethodsLastUpdate!);
        if (timeSinceUpdate < _paymentMethodsCacheExpiry) {
          return _paymentMethods!;
        }
      }

      // Actualizar cache
      await _fetchPaymentMethods();
      return _paymentMethods ?? [];
    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo métodos de pago', e, stackTrace);
      return [];
    }
  }

  /// Obtiene estadísticas de transacciones
  Map<String, dynamic> getTransactionStatistics() {
    // En implementación real, consultar estadísticas desde BD
    return {
      'total_processed_today': 0,
      'total_amount_today': 0.0,
      'total_commission_today': 0.0,
      'average_transaction_amount': 0.0,
      'success_rate_percentage': 0.0,
      'most_used_payment_method': 'credit_card',
      'country': MercadoPagoPeruConfig.countryCode,
      'currency': MercadoPagoPeruConfig.currency,
      'commission_rates': MercadoPagoPeruConfig.commissionRates,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Limpia recursos del servicio
  void dispose() {
    AppLogger.info('Limpiando recursos de MercadoPago Service');
    _paymentMethods = null;
    _paymentMethodsLastUpdate = null;
    _isInitialized = false;
    _accessToken = null;
    _publicKey = null;
    _webhookSecret = null;
  }

  /// Obtiene información de diagnóstico del servicio
  Map<String, dynamic> getDiagnosticInfo() {
    return {
      'serviceName': 'MercadoPagoService',
      'version': '1.0.0',
      'isInitialized': _isInitialized,
      'isProduction': _isProduction,
      'hasAccessToken': _accessToken != null,
      'hasPublicKey': _publicKey != null,
      'hasWebhookSecret': _webhookSecret != null,
      'country': MercadoPagoPeruConfig.countryCode,
      'currency': MercadoPagoPeruConfig.currency,
      'baseUrl': _getBaseUrl(),
      'availablePaymentMethods': MercadoPagoPeruConfig.availablePaymentMethods,
      'commissionRates': MercadoPagoPeruConfig.commissionRates,
      'igvRate': MercadoPagoPeruConfig.igvRate,
      'paymentMethodsCached': _paymentMethods?.length ?? 0,
      'lastPaymentMethodsUpdate': _paymentMethodsLastUpdate?.toIso8601String(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

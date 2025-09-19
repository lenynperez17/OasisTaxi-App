import 'dart:async';
import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio completo de Firebase Analytics / GA4 para OasisTaxi
/// Gestiona todo el tracking, eventos y métricas de la aplicación
class FirebaseAnalyticsService {
  static final FirebaseAnalyticsService _instance =
      FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _instance;
  FirebaseAnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: FirebaseAnalytics.instance,
  );

  // Estado del servicio
  bool _isInitialized = false;
  Map<String, dynamic> _analyticsConfig = {};
  Map<String, dynamic> _userProperties = {};

  // Sesión y contexto
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  int _sessionEventCount = 0;
  Timer? _sessionTimer;
  static const Duration _sessionTimeout = Duration(minutes: 30);

  // Tracking de pantallas
  String? _currentScreen;
  String? _previousScreen;
  final Map<String, ScreenMetrics> _screenMetrics = {};

  // Eventos personalizados para OasisTaxi
  final Map<String, EventConfig> _customEvents = {
    // Eventos de viaje
    'trip_requested': EventConfig(
      category: 'engagement',
      parameters: [
        'pickup_location',
        'destination',
        'vehicle_type',
        'estimated_price'
      ],
    ),
    'trip_accepted': EventConfig(
      category: 'engagement',
      parameters: [
        'driver_id',
        'driver_rating',
        'estimated_arrival',
        'final_price'
      ],
    ),
    'trip_started': EventConfig(
      category: 'engagement',
      parameters: ['trip_id', 'driver_id', 'vehicle_type'],
    ),
    'trip_completed': EventConfig(
      category: 'conversion',
      parameters: [
        'trip_id',
        'duration',
        'distance',
        'final_price',
        'payment_method'
      ],
    ),
    'trip_cancelled': EventConfig(
      category: 'engagement',
      parameters: ['trip_id', 'cancelled_by', 'cancellation_reason'],
    ),

    // Eventos de negociación de precio
    'price_negotiation_started': EventConfig(
      category: 'engagement',
      parameters: ['initial_price', 'vehicle_type'],
    ),
    'price_counter_offered': EventConfig(
      category: 'engagement',
      parameters: ['original_price', 'counter_price', 'negotiation_round'],
    ),
    'price_negotiation_accepted': EventConfig(
      category: 'conversion',
      parameters: ['final_price', 'discount_amount', 'negotiation_rounds'],
    ),

    // Eventos de pago
    'payment_method_selected': EventConfig(
      category: 'engagement',
      parameters: ['payment_method', 'has_saved_cards'],
    ),
    'payment_completed': EventConfig(
      category: 'conversion',
      parameters: ['amount', 'payment_method', 'transaction_id'],
    ),
    'wallet_topped_up': EventConfig(
      category: 'revenue',
      parameters: ['amount', 'payment_method', 'bonus_amount'],
    ),

    // Eventos de conductor
    'driver_documents_uploaded': EventConfig(
      category: 'engagement',
      parameters: ['document_type', 'verification_status'],
    ),
    'driver_approved': EventConfig(
      category: 'conversion',
      parameters: ['approval_time', 'documents_count'],
    ),
    'driver_earnings_withdrawn': EventConfig(
      category: 'revenue',
      parameters: ['amount', 'withdrawal_method', 'bank'],
    ),

    // Eventos de calificación
    'rating_submitted': EventConfig(
      category: 'engagement',
      parameters: ['rating', 'has_comment', 'trip_id', 'rated_user_type'],
    ),

    // Eventos de emergencia
    'emergency_button_pressed': EventConfig(
      category: 'critical',
      parameters: ['trip_id', 'location', 'user_type'],
    ),
    'emergency_contact_called': EventConfig(
      category: 'critical',
      parameters: ['contact_type', 'trip_id'],
    ),
  };

  // Funnels de conversión
  final Map<String, ConversionFunnel> _conversionFunnels = {
    'passenger_trip': ConversionFunnel(
      name: 'Passenger Trip Funnel',
      steps: [
        'app_open',
        'destination_selected',
        'vehicle_selected',
        'trip_requested',
        'trip_accepted',
        'trip_started',
        'trip_completed',
        'payment_completed',
        'rating_submitted',
      ],
    ),
    'driver_onboarding': ConversionFunnel(
      name: 'Driver Onboarding Funnel',
      steps: [
        'registration_started',
        'personal_info_completed',
        'documents_uploaded',
        'vehicle_registered',
        'bank_account_added',
        'verification_submitted',
        'driver_approved',
        'first_trip_accepted',
      ],
    ),
    'price_negotiation': ConversionFunnel(
      name: 'Price Negotiation Funnel',
      steps: [
        'negotiation_started',
        'first_offer_made',
        'counter_offer_received',
        'counter_offer_accepted',
        'trip_confirmed',
      ],
    ),
  };

  // Métricas de rendimiento
  final Map<String, PerformanceMetric> _performanceMetrics = {};

  // Cache de eventos
  final List<AnalyticsEvent> _eventQueue = [];
  Timer? _batchTimer;
  static const int _batchSize = 20;
  static const Duration _batchInterval = Duration(seconds: 30);

  /// Inicializa el servicio de Analytics
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info(
          '📊 Inicializando Firebase Analytics Service para OasisTaxi');

      // Cargar configuración
      await _loadAnalyticsConfig();

      // Configurar Analytics
      await _configureAnalytics();

      // Iniciar sesión
      await _startSession();

      // Configurar batch processing
      _setupBatchProcessing();

      // Cargar propiedades de usuario guardadas
      await _loadUserProperties();

      // Registrar eventos personalizados
      await _registerCustomEvents();

      _isInitialized = true;
      AppLogger.info('✅ Firebase Analytics Service inicializado correctamente');
    } catch (e, stackTrace) {
      AppLogger.error(
          '❌ Error al inicializar Firebase Analytics Service', e, stackTrace);
      rethrow;
    }
  }

  /// Carga la configuración de Analytics
  Future<void> _loadAnalyticsConfig() async {
    try {
      final doc = await _firestore
          .collection('configuration')
          .doc('analytics_config')
          .get();

      if (doc.exists) {
        _analyticsConfig = doc.data() ?? {};
      } else {
        _analyticsConfig = _getDefaultAnalyticsConfig();
        await _saveAnalyticsConfig();
      }

      AppLogger.info('📋 Configuración de Analytics cargada');
    } catch (e) {
      AppLogger.error('Error al cargar configuración de Analytics', e);
      _analyticsConfig = _getDefaultAnalyticsConfig();
    }
  }

  /// Obtiene configuración por defecto
  Map<String, dynamic> _getDefaultAnalyticsConfig() {
    return {
      'enabled': true,
      'debugMode': false,
      'collectAdId': false,
      'sessionTimeoutMinutes': 30,
      'defaultEventParameters': true,
      'enhancedEcommerce': true,
      'userEngagementAutoTracking': true,
      'screenViewAutoTracking': true,
      'outboundClickAutoTracking': true,
      'siteSearchAutoTracking': true,
      'videoEngagementAutoTracking': true,
      'fileDownloadAutoTracking': true,
      'scrollAutoTracking': true,
      'formInteractionAutoTracking': true,
      'dataRetentionMonths': 14,
      'ipAnonymization': true,
      'region': 'peru',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Guarda configuración de Analytics
  Future<void> _saveAnalyticsConfig() async {
    try {
      await _firestore
          .collection('configuration')
          .doc('analytics_config')
          .set(_analyticsConfig, SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Error al guardar configuración de Analytics', e);
    }
  }

  /// Configura Analytics
  Future<void> _configureAnalytics() async {
    try {
      // Habilitar/deshabilitar Analytics
      await _analytics
          .setAnalyticsCollectionEnabled(_analyticsConfig['enabled'] ?? true);

      // Configurar tiempo de sesión
      await _analytics.setSessionTimeoutDuration(
          Duration(minutes: _analyticsConfig['sessionTimeoutMinutes'] ?? 30));

      // Configurar ID de usuario por defecto
      await _analytics.setUserId(id: null);

      // Configurar propiedades por defecto
      await _analytics.setDefaultEventParameters({
        'app_version': '1.0.0',
        'platform': 'mobile',
        'country': 'PE',
        'currency': 'PEN',
      });

      AppLogger.info('⚙️ Analytics configurado');
    } catch (e) {
      AppLogger.error('Error al configurar Analytics', e);
    }
  }

  /// Inicia una nueva sesión
  Future<void> _startSession() async {
    try {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionStartTime = DateTime.now();
      _sessionEventCount = 0;

      // Log inicio de sesión
      await logEvent('session_start', {
        'session_id': _currentSessionId,
        'timestamp': _sessionStartTime!.toIso8601String(),
      });

      // Configurar timer de sesión
      _sessionTimer?.cancel();
      _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _checkSessionTimeout();
      });

      AppLogger.info('🔄 Nueva sesión iniciada: $_currentSessionId');
    } catch (e) {
      AppLogger.error('Error al iniciar sesión', e);
    }
  }

  /// Verifica timeout de sesión
  void _checkSessionTimeout() {
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);

      if (duration > _sessionTimeout) {
        _endSession();
        _startSession();
      }
    }
  }

  /// Finaliza la sesión actual
  Future<void> _endSession() async {
    try {
      if (_currentSessionId != null && _sessionStartTime != null) {
        final duration = DateTime.now().difference(_sessionStartTime!);

        await logEvent('session_end', {
          'session_id': _currentSessionId,
          'duration_seconds': duration.inSeconds,
          'event_count': _sessionEventCount,
        });

        // Guardar métricas de sesión
        await _firestore.collection('analytics_sessions').add({
          'sessionId': _currentSessionId,
          'startTime': _sessionStartTime,
          'endTime': DateTime.now(),
          'duration': duration.inSeconds,
          'eventCount': _sessionEventCount,
          'screens': _screenMetrics.keys.toList(),
        });

        AppLogger.info('🔚 Sesión finalizada: $_currentSessionId');
      }
    } catch (e) {
      AppLogger.error('Error al finalizar sesión', e);
    }
  }

  /// Configura batch processing de eventos
  void _setupBatchProcessing() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(_batchInterval, (_) {
      _processBatchedEvents();
    });
  }

  /// Procesa eventos en batch
  Future<void> _processBatchedEvents() async {
    if (_eventQueue.isEmpty) return;

    try {
      final batch = _firestore.batch();
      final eventsToProcess = List<AnalyticsEvent>.from(_eventQueue);
      _eventQueue.clear();

      for (final event in eventsToProcess) {
        final docRef = _firestore.collection('analytics_events').doc();
        batch.set(docRef, event.toMap());
      }

      await batch.commit();

      AppLogger.info(
          '📤 ${eventsToProcess.length} eventos procesados en batch');
    } catch (e) {
      AppLogger.error('Error al procesar batch de eventos', e);
      // Re-agregar eventos a la cola en caso de error
      _eventQueue.addAll(_eventQueue);
    }
  }

  /// Carga propiedades de usuario
  Future<void> _loadUserProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final propertiesJson = prefs.getString('analytics_user_properties');

      if (propertiesJson != null) {
        _userProperties = jsonDecode(propertiesJson);

        // Aplicar propiedades a Analytics
        for (final entry in _userProperties.entries) {
          await _analytics.setUserProperty(
            name: entry.key,
            value: entry.value?.toString(),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error al cargar propiedades de usuario', e);
    }
  }

  /// Registra eventos personalizados
  Future<void> _registerCustomEvents() async {
    try {
      // Registrar cada evento personalizado en Firestore
      for (final entry in _customEvents.entries) {
        await _firestore
            .collection('analytics_custom_events')
            .doc(entry.key)
            .set({
          'name': entry.key,
          'category': entry.value.category,
          'parameters': entry.value.parameters,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      AppLogger.info(
          '✅ ${_customEvents.length} eventos personalizados registrados');
    } catch (e) {
      AppLogger.error('Error al registrar eventos personalizados', e);
    }
  }

  /// Establece el ID de usuario
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);

      if (userId != null) {
        await setUserProperty('user_id', userId);
      }

      AppLogger.info('👤 User ID establecido: ${userId ?? "null"}');
    } catch (e) {
      AppLogger.error('Error al establecer User ID', e);
    }
  }

  /// Establece una propiedad de usuario
  Future<void> setUserProperty(String name, dynamic value) async {
    try {
      final stringValue = value?.toString();

      await _analytics.setUserProperty(
        name: name,
        value: stringValue,
      );

      _userProperties[name] = value;

      // Guardar en preferencias
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'analytics_user_properties', jsonEncode(_userProperties));

      AppLogger.info('📝 Propiedad de usuario establecida: $name = $value');
    } catch (e) {
      AppLogger.error('Error al establecer propiedad de usuario', e);
    }
  }

  /// Establece propiedades de usuario en batch
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    for (final entry in properties.entries) {
      await setUserProperty(entry.key, entry.value);
    }
  }

  /// Registra una vista de pantalla
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      _previousScreen = _currentScreen;
      _currentScreen = screenName;

      // Registrar métricas de pantalla
      if (!_screenMetrics.containsKey(screenName)) {
        _screenMetrics[screenName] = ScreenMetrics(
          name: screenName,
          viewCount: 0,
          totalDuration: Duration.zero,
          lastViewed: DateTime.now(),
        );
      }

      final metrics = _screenMetrics[screenName]!;
      metrics.viewCount++;
      metrics.lastViewed = DateTime.now();

      // Log en Firebase Analytics
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
        parameters: parameters?.cast<String, Object>(),
      );

      // Log personalizado
      await logEvent('screen_view', {
        'screen_name': screenName,
        'screen_class': screenClass,
        'previous_screen': _previousScreen,
        ...?parameters,
      });

      AppLogger.info('📱 Vista de pantalla: $screenName');
    } catch (e) {
      AppLogger.error('Error al registrar vista de pantalla', e);
    }
  }

  /// Registra un evento
  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]) async {
    try {
      _sessionEventCount++;

      // Agregar parámetros por defecto
      final enrichedParameters = {
        'session_id': _currentSessionId,
        'timestamp': DateTime.now().toIso8601String(),
        'event_index': _sessionEventCount,
        ...?parameters,
      };

      // Log en Firebase Analytics
      await _analytics.logEvent(
        name: name,
        parameters: enrichedParameters.cast<String, Object>(),
      );

      // Agregar a cola para batch processing
      _eventQueue.add(AnalyticsEvent(
        name: name,
        parameters: enrichedParameters,
        timestamp: DateTime.now(),
      ));

      // Procesar batch si alcanza el tamaño máximo
      if (_eventQueue.length >= _batchSize) {
        await _processBatchedEvents();
      }

      AppLogger.debug('📊 Evento registrado: $name');
    } catch (e) {
      AppLogger.error('Error al registrar evento', e);
    }
  }

  /// Registra inicio de viaje solicitado
  Future<void> logTripRequested({
    required String pickupLocation,
    required String destination,
    required String vehicleType,
    required double estimatedPrice,
    Map<String, dynamic>? additionalParams,
  }) async {
    await logEvent('trip_requested', {
      'pickup_location': pickupLocation,
      'destination': destination,
      'vehicle_type': vehicleType,
      'estimated_price': estimatedPrice,
      'currency': 'PEN',
      ...?additionalParams,
    });

    // Actualizar funnel
    _updateFunnelProgress('passenger_trip', 'trip_requested');
  }

  /// Registra viaje aceptado
  Future<void> logTripAccepted({
    required String tripId,
    required String driverId,
    required double driverRating,
    required int estimatedArrival,
    required double finalPrice,
  }) async {
    await logEvent('trip_accepted', {
      'trip_id': tripId,
      'driver_id': driverId,
      'driver_rating': driverRating,
      'estimated_arrival': estimatedArrival,
      'final_price': finalPrice,
      'currency': 'PEN',
    });

    _updateFunnelProgress('passenger_trip', 'trip_accepted');
  }

  /// Registra viaje iniciado
  Future<void> logTripStarted({
    required String tripId,
    required String driverId,
    required String vehicleType,
  }) async {
    await logEvent('trip_started', {
      'trip_id': tripId,
      'driver_id': driverId,
      'vehicle_type': vehicleType,
    });

    _updateFunnelProgress('passenger_trip', 'trip_started');
  }

  /// Registra viaje completado
  Future<void> logTripCompleted({
    required String tripId,
    required int duration,
    required double distance,
    required double finalPrice,
    required String paymentMethod,
  }) async {
    await logEvent('trip_completed', {
      'trip_id': tripId,
      'duration_minutes': duration,
      'distance_km': distance,
      'final_price': finalPrice,
      'payment_method': paymentMethod,
      'currency': 'PEN',
    });

    // Evento de conversión para GA4
    await logConversion('trip_completion', finalPrice);

    _updateFunnelProgress('passenger_trip', 'trip_completed');
  }

  /// Registra cancelación de viaje
  Future<void> logTripCancelled({
    required String tripId,
    required String cancelledBy,
    required String reason,
  }) async {
    await logEvent('trip_cancelled', {
      'trip_id': tripId,
      'cancelled_by': cancelledBy,
      'cancellation_reason': reason,
    });
  }

  /// Registra negociación de precio iniciada
  Future<void> logPriceNegotiationStarted({
    required double initialPrice,
    required String vehicleType,
  }) async {
    await logEvent('price_negotiation_started', {
      'initial_price': initialPrice,
      'vehicle_type': vehicleType,
      'currency': 'PEN',
    });

    _updateFunnelProgress('price_negotiation', 'negotiation_started');
  }

  /// Registra contraoferta de precio
  Future<void> logPriceCounterOffer({
    required double originalPrice,
    required double counterPrice,
    required int negotiationRound,
  }) async {
    await logEvent('price_counter_offered', {
      'original_price': originalPrice,
      'counter_price': counterPrice,
      'negotiation_round': negotiationRound,
      'discount_percentage':
          ((originalPrice - counterPrice) / originalPrice * 100)
              .toStringAsFixed(2),
      'currency': 'PEN',
    });

    _updateFunnelProgress('price_negotiation', 'counter_offer_received');
  }

  /// Registra negociación aceptada
  Future<void> logPriceNegotiationAccepted({
    required double finalPrice,
    required double discountAmount,
    required int negotiationRounds,
  }) async {
    await logEvent('price_negotiation_accepted', {
      'final_price': finalPrice,
      'discount_amount': discountAmount,
      'negotiation_rounds': negotiationRounds,
      'currency': 'PEN',
    });

    _updateFunnelProgress('price_negotiation', 'counter_offer_accepted');
  }

  /// Registra método de pago seleccionado
  Future<void> logPaymentMethodSelected({
    required String paymentMethod,
    bool hasSavedCards = false,
  }) async {
    await logEvent('payment_method_selected', {
      'payment_method': paymentMethod,
      'has_saved_cards': hasSavedCards,
    });
  }

  /// Registra pago completado
  Future<void> logPaymentCompleted({
    required double amount,
    required String paymentMethod,
    required String transactionId,
  }) async {
    await logEvent('payment_completed', {
      'amount': amount,
      'payment_method': paymentMethod,
      'transaction_id': transactionId,
      'currency': 'PEN',
    });

    // Evento de revenue para GA4
    await logRevenue(amount, 'trip_payment');

    _updateFunnelProgress('passenger_trip', 'payment_completed');
  }

  /// Registra recarga de wallet
  Future<void> logWalletTopUp({
    required double amount,
    required String paymentMethod,
    double bonusAmount = 0,
  }) async {
    await logEvent('wallet_topped_up', {
      'amount': amount,
      'payment_method': paymentMethod,
      'bonus_amount': bonusAmount,
      'total_amount': amount + bonusAmount,
      'currency': 'PEN',
    });

    await logRevenue(amount, 'wallet_topup');
  }

  /// Registra documentos de conductor subidos
  Future<void> logDriverDocumentsUploaded({
    required String documentType,
    required String verificationStatus,
  }) async {
    await logEvent('driver_documents_uploaded', {
      'document_type': documentType,
      'verification_status': verificationStatus,
    });

    _updateFunnelProgress('driver_onboarding', 'documents_uploaded');
  }

  /// Registra conductor aprobado
  Future<void> logDriverApproved({
    required int approvalTimeHours,
    required int documentsCount,
  }) async {
    await logEvent('driver_approved', {
      'approval_time_hours': approvalTimeHours,
      'documents_count': documentsCount,
    });

    await logConversion('driver_approval', 1);

    _updateFunnelProgress('driver_onboarding', 'driver_approved');
  }

  /// Registra retiro de ganancias
  Future<void> logDriverEarningsWithdrawn({
    required double amount,
    required String withdrawalMethod,
    required String bank,
  }) async {
    await logEvent('driver_earnings_withdrawn', {
      'amount': amount,
      'withdrawal_method': withdrawalMethod,
      'bank': bank,
      'currency': 'PEN',
    });
  }

  /// Registra calificación enviada
  Future<void> logRatingSubmitted({
    required int rating,
    required bool hasComment,
    required String tripId,
    required String ratedUserType,
  }) async {
    await logEvent('rating_submitted', {
      'rating': rating,
      'has_comment': hasComment,
      'trip_id': tripId,
      'rated_user_type': ratedUserType,
    });

    _updateFunnelProgress('passenger_trip', 'rating_submitted');
  }

  /// Registra botón de emergencia presionado
  Future<void> logEmergencyButtonPressed({
    required String tripId,
    required String location,
    required String userType,
  }) async {
    await logEvent('emergency_button_pressed', {
      'trip_id': tripId,
      'location': location,
      'user_type': userType,
      'severity': 'critical',
    });

    // También enviar a sistema de alertas
    await _firestore.collection('emergency_alerts').add({
      'tripId': tripId,
      'location': location,
      'userType': userType,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  /// Registra contacto de emergencia llamado
  Future<void> logEmergencyContactCalled({
    required String contactType,
    required String tripId,
  }) async {
    await logEvent('emergency_contact_called', {
      'contact_type': contactType,
      'trip_id': tripId,
      'severity': 'critical',
    });
  }

  /// Registra una conversión
  Future<void> logConversion(String conversionType, double value) async {
    await _analytics.logEvent(
      name: 'conversion',
      parameters: {
        'conversion_type': conversionType,
        'value': value,
        'currency': 'PEN',
      },
    );
  }

  /// Registra revenue
  Future<void> logRevenue(double amount, String source) async {
    await _analytics.logEvent(
      name: 'purchase',
      parameters: {
        'value': amount,
        'currency': 'PEN',
        'source': source,
      },
    );
  }

  /// Registra error
  Future<void> logError({
    required String error,
    required String errorCode,
    String? screen,
    Map<String, dynamic>? additionalParams,
  }) async {
    await logEvent('app_error', {
      'error_message': error,
      'error_code': errorCode,
      'screen': screen ?? _currentScreen,
      ...?additionalParams,
    });
  }

  /// Registra búsqueda
  Future<void> logSearch({
    required String searchTerm,
    required String searchType,
    int? resultsCount,
  }) async {
    await _analytics.logSearch(
      searchTerm: searchTerm,
      numberOfNights: resultsCount,
      parameters: {
        'search_type': searchType,
      },
    );
  }

  /// Registra share
  Future<void> logShare({
    required String contentType,
    required String itemId,
    required String method,
  }) async {
    await _analytics.logShare(
      contentType: contentType,
      itemId: itemId,
      method: method,
    );
  }

  /// Actualiza progreso del funnel
  void _updateFunnelProgress(String funnelName, String step) {
    if (!_conversionFunnels.containsKey(funnelName)) return;

    final funnel = _conversionFunnels[funnelName]!;
    final stepIndex = funnel.steps.indexOf(step);

    if (stepIndex >= 0) {
      funnel.currentStep = stepIndex;
      funnel.completedSteps.add(step);
      funnel.lastUpdated = DateTime.now();

      // Log progreso del funnel
      logEvent('funnel_progress', {
        'funnel_name': funnelName,
        'step': step,
        'step_index': stepIndex,
        'total_steps': funnel.steps.length,
        'completion_rate': (stepIndex + 1) / funnel.steps.length * 100,
      });
    }
  }

  /// Obtiene métricas de conversión
  Future<Map<String, dynamic>> getConversionMetrics() async {
    try {
      final metrics = <String, dynamic>{};

      for (final entry in _conversionFunnels.entries) {
        final funnel = entry.value;
        metrics[entry.key] = {
          'name': funnel.name,
          'total_steps': funnel.steps.length,
          'completed_steps': funnel.completedSteps.length,
          'current_step': funnel.currentStep,
          'completion_rate':
              funnel.completedSteps.length / funnel.steps.length * 100,
          'last_updated': funnel.lastUpdated?.toIso8601String(),
        };
      }

      return metrics;
    } catch (e) {
      AppLogger.error('Error al obtener métricas de conversión', e);
      return {};
    }
  }

  /// Obtiene métricas de pantalla
  Map<String, ScreenMetrics> getScreenMetrics() => Map.from(_screenMetrics);

  /// Obtiene métricas de sesión
  Map<String, dynamic> getSessionMetrics() {
    return {
      'session_id': _currentSessionId,
      'start_time': _sessionStartTime?.toIso8601String(),
      'duration': _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inSeconds
          : 0,
      'event_count': _sessionEventCount,
      'current_screen': _currentScreen,
      'screens_viewed': _screenMetrics.keys.toList(),
    };
  }

  /// Registra métricas de rendimiento
  Future<void> logPerformanceMetric({
    required String name,
    required double value,
    required String unit,
    Map<String, dynamic>? metadata,
  }) async {
    _performanceMetrics[name] = PerformanceMetric(
      name: name,
      value: value,
      unit: unit,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    await logEvent('performance_metric', {
      'metric_name': name,
      'value': value,
      'unit': unit,
      ...?metadata,
    });
  }

  /// Limpia recursos
  void dispose() {
    _sessionTimer?.cancel();
    _batchTimer?.cancel();
    _endSession();
    _processBatchedEvents();
    AppLogger.info('🔚 Firebase Analytics Service disposed');
  }
}

// Modelos auxiliares

/// Configuración de evento
class EventConfig {
  final String category;
  final List<String> parameters;

  EventConfig({
    required this.category,
    required this.parameters,
  });
}

/// Evento de Analytics
class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    required this.parameters,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'parameters': parameters,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Funnel de conversión
class ConversionFunnel {
  final String name;
  final List<String> steps;
  int currentStep;
  final Set<String> completedSteps;
  DateTime? lastUpdated;

  ConversionFunnel({
    required this.name,
    required this.steps,
    this.currentStep = -1,
    Set<String>? completedSteps,
    this.lastUpdated,
  }) : completedSteps = completedSteps ?? {};
}

/// Métricas de pantalla
class ScreenMetrics {
  final String name;
  int viewCount;
  Duration totalDuration;
  DateTime lastViewed;

  ScreenMetrics({
    required this.name,
    required this.viewCount,
    required this.totalDuration,
    required this.lastViewed,
  });
}

/// Métrica de rendimiento
class PerformanceMetric {
  final String name;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceMetric({
    required this.name,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.metadata,
  });
}

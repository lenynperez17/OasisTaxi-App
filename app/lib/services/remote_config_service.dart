import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Servicio de Firebase Remote Config con timeout configurable
/// Maneja configuraciones dinámicas para OasisTaxi
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  FirebaseRemoteConfig? _remoteConfig;
  bool _isInitialized = false;

  // Configuraciones por defecto para OasisTaxi
  static const Map<String, dynamic> _defaults = {
    // Configuraciones de precio y comisiones
    'driver_commission_rate': 0.20, // 20% comisión para conductores
    'surge_pricing_enabled': true,
    'surge_multiplier_max': 3.0,
    'base_fare_price': 5.00, // Tarifa base en soles
    'price_per_km': 1.50, // Precio por kilómetro
    'price_per_minute': 0.30, // Precio por minuto
    'minimum_fare': 8.00, // Tarifa mínima

    // Timeouts y configuraciones de conexión
    'api_timeout_seconds': 30,
    'location_timeout_seconds': 15,
    'ride_request_timeout_minutes': 10,
    'driver_response_timeout_seconds': 45,
    'payment_timeout_seconds': 60,
    'websocket_reconnect_interval': 5000,

    // Configuraciones de negociación de precios
    'price_negotiation_enabled': true,
    'max_negotiation_rounds': 3,
    'negotiation_timeout_minutes': 5,
    'max_price_difference_percentage': 50.0,

    // Configuraciones de emergencia
    'emergency_contacts_enabled': true,
    'emergency_response_timeout_seconds': 10,
    'auto_emergency_call_delay_seconds': 30,

    // Configuraciones de chat
    'chat_enabled': true,
    'chat_file_upload_enabled': true,
    'max_file_size_mb': 10,
    'chat_message_retention_days': 30,

    // Configuraciones de mapa
    'maps_zoom_level': 15.0,
    'tracking_update_interval_seconds': 5,
    'route_optimization_enabled': true,
    'offline_maps_enabled': false,

    // Configuraciones de notificaciones
    'push_notifications_enabled': true,
    'notification_sound_enabled': true,
    'trip_updates_enabled': true,
    'marketing_notifications_enabled': false,

    // Configuraciones de validación
    'min_driver_rating': 3.0,
    'min_passenger_rating': 2.5,
    'rating_required_after_trip': true,
    'document_verification_required': true,

    // Configuraciones de mantenimiento
    'maintenance_mode': false,
    'maintenance_message':
        'OasisTaxi está en mantenimiento. Inténtalo más tarde.',
    'force_update_enabled': false,
    'min_app_version': '1.0.0',

    // Configuraciones de analytics
    'analytics_enabled': true,
    'crash_reporting_enabled': true,
    'performance_monitoring_enabled': true,

    // Configuraciones regionales
    'supported_countries': ['PE'], // Solo Perú inicialmente
    'default_currency': 'PEN',
    'default_language': 'es',
    'timezone': 'America/Lima',

    // Features flags
    'biometric_auth_enabled': true,
    'qr_code_pickup_enabled': true,
    'scheduled_rides_enabled': false,
    'ride_sharing_enabled': false,
    'loyalty_program_enabled': false,
  };

  /// Inicializa Firebase Remote Config con valores por defecto
  Future<bool> initialize({
    Duration fetchTimeout = const Duration(seconds: 60),
    Duration minimumFetchInterval = const Duration(hours: 1),
  }) async {
    try {
      if (_isInitialized) {
        AppLogger.warning('RemoteConfigService ya inicializado');
        return true;
      }

      _remoteConfig = FirebaseRemoteConfig.instance;

      // Configurar settings
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: fetchTimeout,
        minimumFetchInterval: minimumFetchInterval,
      ));

      // Establecer valores por defecto
      await _remoteConfig!.setDefaults(_defaults);

      // Fetch inicial
      await fetchAndActivate();

      _isInitialized = true;
      AppLogger.info('RemoteConfigService inicializado exitosamente');

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error inicializando RemoteConfigService', e, stackTrace);
      return false;
    }
  }

  /// Fetch y activar configuraciones remotas
  Future<bool> fetchAndActivate({
    Duration? customTimeout,
  }) async {
    try {
      if (_remoteConfig == null) {
        AppLogger.warning(
            'RemoteConfig no inicializado, usando valores por defecto');
        return false;
      }

      // Aplicar timeout personalizado si se proporciona
      if (customTimeout != null) {
        await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: customTimeout,
          minimumFetchInterval: Duration.zero, // Para desarrollo
        ));
      }

      final bool updated = await _remoteConfig!.fetchAndActivate();

      if (updated) {
        AppLogger.info('Configuraciones Remote Config actualizadas');
        _logConfigurationChanges();
      } else {
        AppLogger.debug('No hay nuevas configuraciones Remote Config');
      }

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error en fetchAndActivate Remote Config', e, stackTrace);
      return false;
    }
  }

  /// Obtiene un valor String con fallback
  String getString(String key, {String? defaultValue}) {
    try {
      if (_remoteConfig == null) {
        return defaultValue ?? _defaults[key]?.toString() ?? '';
      }
      return _remoteConfig!.getString(key);
    } catch (e) {
      AppLogger.error('Error obteniendo string para clave: $key', e);
      return defaultValue ?? _defaults[key]?.toString() ?? '';
    }
  }

  /// Obtiene un valor int con fallback
  int getInt(String key, {int? defaultValue}) {
    try {
      if (_remoteConfig == null) {
        return defaultValue ?? _defaults[key] ?? 0;
      }
      return _remoteConfig!.getInt(key);
    } catch (e) {
      AppLogger.error('Error obteniendo int para clave: $key', e);
      return defaultValue ?? _defaults[key] ?? 0;
    }
  }

  /// Obtiene un valor double con fallback
  double getDouble(String key, {double? defaultValue}) {
    try {
      if (_remoteConfig == null) {
        return defaultValue ?? _defaults[key] ?? 0.0;
      }
      return _remoteConfig!.getDouble(key);
    } catch (e) {
      AppLogger.error('Error obteniendo double para clave: $key', e);
      return defaultValue ?? _defaults[key] ?? 0.0;
    }
  }

  /// Obtiene un valor bool con fallback
  bool getBool(String key, {bool? defaultValue}) {
    try {
      if (_remoteConfig == null) {
        return defaultValue ?? _defaults[key] ?? false;
      }
      return _remoteConfig!.getBool(key);
    } catch (e) {
      AppLogger.error('Error obteniendo bool para clave: $key', e);
      return defaultValue ?? _defaults[key] ?? false;
    }
  }

  /// Obtiene un valor JSON decodificado
  Map<String, dynamic>? getJson(String key) {
    try {
      final String jsonString = getString(key);
      if (jsonString.isEmpty) return null;
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('Error decodificando JSON para clave: $key', e);
      return null;
    }
  }

  /// Obtiene una lista de strings
  List<String> getStringList(String key) {
    try {
      final String listString = getString(key);
      if (listString.isEmpty) return [];
      final List<dynamic> dynamicList = json.decode(listString);
      return dynamicList.cast<String>();
    } catch (e) {
      AppLogger.error('Error obteniendo lista para clave: $key', e);
      return [];
    }
  }

  // Getters específicos para OasisTaxi

  /// Configuraciones de precio
  double get driverCommissionRate => getDouble('driver_commission_rate');
  bool get surgePricingEnabled => getBool('surge_pricing_enabled');
  double get surgeMultiplierMax => getDouble('surge_multiplier_max');
  double get baseFarePrice => getDouble('base_fare_price');
  double get pricePerKm => getDouble('price_per_km');
  double get pricePerMinute => getDouble('price_per_minute');
  double get minimumFare => getDouble('minimum_fare');

  /// Configuraciones de timeout
  int get apiTimeoutSeconds => getInt('api_timeout_seconds');
  int get locationTimeoutSeconds => getInt('location_timeout_seconds');
  int get rideRequestTimeoutMinutes => getInt('ride_request_timeout_minutes');
  int get driverResponseTimeoutSeconds =>
      getInt('driver_response_timeout_seconds');
  int get paymentTimeoutSeconds => getInt('payment_timeout_seconds');
  int get websocketReconnectInterval => getInt('websocket_reconnect_interval');

  /// Configuraciones de negociación
  bool get priceNegotiationEnabled => getBool('price_negotiation_enabled');
  int get maxNegotiationRounds => getInt('max_negotiation_rounds');
  int get negotiationTimeoutMinutes => getInt('negotiation_timeout_minutes');
  double get maxPriceDifferencePercentage =>
      getDouble('max_price_difference_percentage');

  /// Configuraciones de emergencia
  bool get emergencyContactsEnabled => getBool('emergency_contacts_enabled');
  int get emergencyResponseTimeoutSeconds =>
      getInt('emergency_response_timeout_seconds');
  int get autoEmergencyCallDelaySeconds =>
      getInt('auto_emergency_call_delay_seconds');

  /// Configuraciones de chat
  bool get chatEnabled => getBool('chat_enabled');
  bool get chatFileUploadEnabled => getBool('chat_file_upload_enabled');
  int get maxFileSizeMb => getInt('max_file_size_mb');
  int get chatMessageRetentionDays => getInt('chat_message_retention_days');

  /// Configuraciones de mapa
  double get mapsZoomLevel => getDouble('maps_zoom_level');
  int get trackingUpdateIntervalSeconds =>
      getInt('tracking_update_interval_seconds');
  bool get routeOptimizationEnabled => getBool('route_optimization_enabled');
  bool get offlineMapsEnabled => getBool('offline_maps_enabled');

  /// Configuraciones de notificaciones
  bool get pushNotificationsEnabled => getBool('push_notifications_enabled');
  bool get notificationSoundEnabled => getBool('notification_sound_enabled');
  bool get tripUpdatesEnabled => getBool('trip_updates_enabled');
  bool get marketingNotificationsEnabled =>
      getBool('marketing_notifications_enabled');

  /// Configuraciones de validación
  double get minDriverRating => getDouble('min_driver_rating');
  double get minPassengerRating => getDouble('min_passenger_rating');
  bool get ratingRequiredAfterTrip => getBool('rating_required_after_trip');
  bool get documentVerificationRequired =>
      getBool('document_verification_required');

  /// Configuraciones de mantenimiento
  bool get maintenanceMode => getBool('maintenance_mode');
  String get maintenanceMessage => getString('maintenance_message');
  bool get forceUpdateEnabled => getBool('force_update_enabled');
  String get minAppVersion => getString('min_app_version');

  /// Configuraciones de analytics
  bool get analyticsEnabled => getBool('analytics_enabled');
  bool get crashReportingEnabled => getBool('crash_reporting_enabled');
  bool get performanceMonitoringEnabled =>
      getBool('performance_monitoring_enabled');

  /// Configuraciones regionales
  List<String> get supportedCountries => getStringList('supported_countries');
  String get defaultCurrency => getString('default_currency');
  String get defaultLanguage => getString('default_language');
  String get timezone => getString('timezone');

  /// Feature flags
  bool get biometricAuthEnabled => getBool('biometric_auth_enabled');
  bool get qrCodePickupEnabled => getBool('qr_code_pickup_enabled');
  bool get scheduledRidesEnabled => getBool('scheduled_rides_enabled');
  bool get rideSharingEnabled => getBool('ride_sharing_enabled');
  bool get loyaltyProgramEnabled => getBool('loyalty_program_enabled');

  /// Métodos de utilidad

  /// Fuerza un refresh completo de las configuraciones
  Future<bool> forceRefresh() async {
    try {
      if (_remoteConfig == null) return false;

      // Configurar fetch inmediato
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 30),
        minimumFetchInterval: Duration.zero,
      ));

      final bool updated = await _remoteConfig!.fetchAndActivate();

      AppLogger.info('Force refresh Remote Config completado: $updated');
      return updated;
    } catch (e, stackTrace) {
      AppLogger.error('Error en force refresh Remote Config', e, stackTrace);
      return false;
    }
  }

  /// Obtiene todas las configuraciones actuales
  Map<String, dynamic> getAllConfigs() {
    try {
      if (_remoteConfig == null) return _defaults;

      final Map<String, dynamic> configs = {};
      for (final String key in _defaults.keys) {
        configs[key] = _remoteConfig!.getValue(key).asString();
      }
      return configs;
    } catch (e) {
      AppLogger.error('Error obteniendo todas las configuraciones', e);
      return _defaults;
    }
  }

  /// Registra cambios en configuraciones críticas
  void _logConfigurationChanges() {
    if (kDebugMode) {
      AppLogger.debug('Configuraciones Remote Config actuales:');
      AppLogger.debug('- Commission Rate: $driverCommissionRate');
      AppLogger.debug('- API Timeout: ${apiTimeoutSeconds}s');
      AppLogger.debug('- Maintenance Mode: $maintenanceMode');
      AppLogger.debug('- Price Negotiation: $priceNegotiationEnabled');
      AppLogger.debug('- Emergency Contacts: $emergencyContactsEnabled');
    }
  }

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Obtiene el estado actual del servicio
  Map<String, dynamic> getServiceStatus() {
    return {
      'initialized': _isInitialized,
      'last_fetch': _remoteConfig?.lastFetchTime.toIso8601String(),
      'last_fetch_status': _remoteConfig?.lastFetchStatus.toString(),
      'config_count': _defaults.length,
    };
  }

  /// Limpia recursos
  Future<void> dispose() async {
    _remoteConfig = null;
    _isInitialized = false;
    AppLogger.info('RemoteConfigService disposed');
  }
}

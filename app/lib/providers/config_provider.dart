import 'package:flutter/material.dart';
import '../services/remote_config_service.dart';
import '../utils/app_logger.dart';

/// Provider para gestionar configuraciones dinámicas de Remote Config
/// Permite que los widgets reaccionen a cambios en configuraciones
class ConfigProvider with ChangeNotifier {
  static final ConfigProvider _instance = ConfigProvider._internal();
  factory ConfigProvider() => _instance;
  ConfigProvider._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();
  bool _isLoading = false;
  DateTime? _lastUpdate;

  // Getters para estado
  bool get isLoading => _isLoading;
  DateTime? get lastUpdate => _lastUpdate;
  bool get isInitialized => _remoteConfig.isInitialized;

  // Configuraciones de precio
  double get driverCommissionRate => _remoteConfig.driverCommissionRate;
  bool get surgePricingEnabled => _remoteConfig.surgePricingEnabled;
  double get surgeMultiplierMax => _remoteConfig.surgeMultiplierMax;
  double get baseFarePrice => _remoteConfig.baseFarePrice;
  double get pricePerKm => _remoteConfig.pricePerKm;
  double get pricePerMinute => _remoteConfig.pricePerMinute;
  double get minimumFare => _remoteConfig.minimumFare;

  // Configuraciones de timeout (más utilizados)
  int get apiTimeoutSeconds => _remoteConfig.apiTimeoutSeconds;
  int get locationTimeoutSeconds => _remoteConfig.locationTimeoutSeconds;
  int get rideRequestTimeoutMinutes => _remoteConfig.rideRequestTimeoutMinutes;
  int get driverResponseTimeoutSeconds =>
      _remoteConfig.driverResponseTimeoutSeconds;
  int get paymentTimeoutSeconds => _remoteConfig.paymentTimeoutSeconds;
  int get websocketReconnectInterval =>
      _remoteConfig.websocketReconnectInterval;

  // Configuraciones de negociación
  bool get priceNegotiationEnabled => _remoteConfig.priceNegotiationEnabled;
  int get maxNegotiationRounds => _remoteConfig.maxNegotiationRounds;
  int get negotiationTimeoutMinutes => _remoteConfig.negotiationTimeoutMinutes;
  double get maxPriceDifferencePercentage =>
      _remoteConfig.maxPriceDifferencePercentage;

  // Configuraciones de emergencia
  bool get emergencyContactsEnabled => _remoteConfig.emergencyContactsEnabled;
  int get emergencyResponseTimeoutSeconds =>
      _remoteConfig.emergencyResponseTimeoutSeconds;
  int get autoEmergencyCallDelaySeconds =>
      _remoteConfig.autoEmergencyCallDelaySeconds;

  // Configuraciones de chat
  bool get chatEnabled => _remoteConfig.chatEnabled;
  bool get chatFileUploadEnabled => _remoteConfig.chatFileUploadEnabled;
  int get maxFileSizeMb => _remoteConfig.maxFileSizeMb;
  int get chatMessageRetentionDays => _remoteConfig.chatMessageRetentionDays;

  // Configuraciones de mapa
  double get mapsZoomLevel => _remoteConfig.mapsZoomLevel;
  int get trackingUpdateIntervalSeconds =>
      _remoteConfig.trackingUpdateIntervalSeconds;
  bool get routeOptimizationEnabled => _remoteConfig.routeOptimizationEnabled;
  bool get offlineMapsEnabled => _remoteConfig.offlineMapsEnabled;

  // Configuraciones de notificaciones
  bool get pushNotificationsEnabled => _remoteConfig.pushNotificationsEnabled;
  bool get notificationSoundEnabled => _remoteConfig.notificationSoundEnabled;
  bool get tripUpdatesEnabled => _remoteConfig.tripUpdatesEnabled;
  bool get marketingNotificationsEnabled =>
      _remoteConfig.marketingNotificationsEnabled;

  // Configuraciones de validación
  double get minDriverRating => _remoteConfig.minDriverRating;
  double get minPassengerRating => _remoteConfig.minPassengerRating;
  bool get ratingRequiredAfterTrip => _remoteConfig.ratingRequiredAfterTrip;
  bool get documentVerificationRequired =>
      _remoteConfig.documentVerificationRequired;

  // Configuraciones de mantenimiento
  bool get maintenanceMode => _remoteConfig.maintenanceMode;
  String get maintenanceMessage => _remoteConfig.maintenanceMessage;
  bool get forceUpdateEnabled => _remoteConfig.forceUpdateEnabled;
  String get minAppVersion => _remoteConfig.minAppVersion;

  // Configuraciones de analytics
  bool get analyticsEnabled => _remoteConfig.analyticsEnabled;
  bool get crashReportingEnabled => _remoteConfig.crashReportingEnabled;
  bool get performanceMonitoringEnabled =>
      _remoteConfig.performanceMonitoringEnabled;

  // Configuraciones regionales
  List<String> get supportedCountries => _remoteConfig.supportedCountries;
  String get defaultCurrency => _remoteConfig.defaultCurrency;
  String get defaultLanguage => _remoteConfig.defaultLanguage;
  String get timezone => _remoteConfig.timezone;

  // Feature flags
  bool get biometricAuthEnabled => _remoteConfig.biometricAuthEnabled;
  bool get qrCodePickupEnabled => _remoteConfig.qrCodePickupEnabled;
  bool get scheduledRidesEnabled => _remoteConfig.scheduledRidesEnabled;
  bool get rideSharingEnabled => _remoteConfig.rideSharingEnabled;
  bool get loyaltyProgramEnabled => _remoteConfig.loyaltyProgramEnabled;

  /// Refresh manual de configuraciones
  Future<bool> refreshConfigurations() async {
    try {
      _isLoading = true;
      notifyListeners();

      AppLogger.info('Actualizando configuraciones Remote Config...');
      final success = await _remoteConfig.fetchAndActivate();

      _lastUpdate = DateTime.now();
      _isLoading = false;

      notifyListeners();

      if (success) {
        AppLogger.info('✅ Configuraciones actualizadas exitosamente');
      } else {
        AppLogger.warning('⚠️ No hay nuevas configuraciones disponibles');
      }

      return success;
    } catch (e, stackTrace) {
      AppLogger.error('Error actualizando configuraciones', e, stackTrace);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Force refresh completo
  Future<bool> forceRefresh() async {
    try {
      _isLoading = true;
      notifyListeners();

      AppLogger.info('Forzando actualización completa de configuraciones...');
      final success = await _remoteConfig.forceRefresh();

      _lastUpdate = DateTime.now();
      _isLoading = false;

      notifyListeners();

      if (success) {
        AppLogger.info('✅ Force refresh completado exitosamente');
      } else {
        AppLogger.warning('⚠️ Force refresh falló');
      }

      return success;
    } catch (e, stackTrace) {
      AppLogger.error('Error en force refresh', e, stackTrace);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtiene valor personalizado con tipo específico
  T getCustomValue<T>(String key, T defaultValue) {
    try {
      if (T == String) {
        return _remoteConfig.getString(key,
            defaultValue: defaultValue as String?) as T;
      } else if (T == int) {
        return _remoteConfig.getInt(key, defaultValue: defaultValue as int?)
            as T;
      } else if (T == double) {
        return _remoteConfig.getDouble(key,
            defaultValue: defaultValue as double?) as T;
      } else if (T == bool) {
        return _remoteConfig.getBool(key, defaultValue: defaultValue as bool?)
            as T;
      } else {
        AppLogger.warning('Tipo no soportado para getCustomValue: $T');
        return defaultValue;
      }
    } catch (e) {
      AppLogger.error('Error obteniendo valor personalizado para $key', e);
      return defaultValue;
    }
  }

  /// Verifica si una feature está habilitada
  bool isFeatureEnabled(String featureName) {
    return getBool(featureName, defaultValue: false);
  }

  /// Obtiene timeout en Duration
  Duration getTimeoutDuration(String configKey, {Duration? defaultTimeout}) {
    final seconds =
        getInt(configKey, defaultValue: defaultTimeout?.inSeconds ?? 30);
    return Duration(seconds: seconds);
  }

  /// Obtiene intervalo en Duration
  Duration getIntervalDuration(String configKey, {Duration? defaultInterval}) {
    final milliseconds = getInt(configKey,
        defaultValue: defaultInterval?.inMilliseconds ?? 5000);
    return Duration(milliseconds: milliseconds);
  }

  /// Métodos helper para tipos específicos
  String getString(String key, {String? defaultValue}) {
    return _remoteConfig.getString(key, defaultValue: defaultValue);
  }

  int getInt(String key, {int? defaultValue}) {
    return _remoteConfig.getInt(key, defaultValue: defaultValue);
  }

  double getDouble(String key, {double? defaultValue}) {
    return _remoteConfig.getDouble(key, defaultValue: defaultValue);
  }

  bool getBool(String key, {bool? defaultValue}) {
    return _remoteConfig.getBool(key, defaultValue: defaultValue);
  }

  Map<String, dynamic>? getJson(String key) {
    return _remoteConfig.getJson(key);
  }

  List<String> getStringList(String key) {
    return _remoteConfig.getStringList(key);
  }

  /// Obtiene todas las configuraciones actuales
  Map<String, dynamic> getAllConfigs() {
    return _remoteConfig.getAllConfigs();
  }

  /// Obtiene estado del servicio
  Map<String, dynamic> getServiceStatus() {
    final status = _remoteConfig.getServiceStatus();
    status['provider_last_update'] = _lastUpdate?.toIso8601String();
    status['provider_is_loading'] = _isLoading;
    return status;
  }

  /// Verifica si la app está en modo mantenimiento
  bool get isMaintenanceMode => maintenanceMode;

  /// Verifica si necesita actualización forzada
  bool needsForceUpdate(String currentVersion) {
    if (!forceUpdateEnabled) return false;

    try {
      // Comparación simple de versiones (ej: 1.0.0 vs 1.0.1)
      final current = currentVersion.split('.').map(int.parse).toList();
      final minimum = minAppVersion.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final currentPart = i < current.length ? current[i] : 0;
        final minimumPart = i < minimum.length ? minimum[i] : 0;

        if (currentPart < minimumPart) return true;
        if (currentPart > minimumPart) return false;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error comparando versiones', e);
      return false;
    }
  }

  /// Calcula precio dinámico basado en configuraciones
  double calculateDynamicPrice({
    required double distance,
    required int estimatedMinutes,
    double surgeFactor = 1.0,
  }) {
    double price = baseFarePrice;
    price += (distance * pricePerKm);
    price += (estimatedMinutes * pricePerMinute);

    if (surgePricingEnabled) {
      final clampedSurge = surgeFactor.clamp(1.0, surgeMultiplierMax);
      price *= clampedSurge;
    }

    return price < minimumFare ? minimumFare : price;
  }

  /// Verifica si el país está soportado
  bool isCountrySupported(String countryCode) {
    return supportedCountries.contains(countryCode.toUpperCase());
  }

  /// Obtiene configuración de timeout específica con fallback
  Duration getApiTimeout() => getTimeoutDuration('api_timeout_seconds',
      defaultTimeout: const Duration(seconds: 30));

  Duration getLocationTimeout() =>
      getTimeoutDuration('location_timeout_seconds',
          defaultTimeout: const Duration(seconds: 15));

  Duration getRideRequestTimeout() =>
      Duration(minutes: rideRequestTimeoutMinutes);

  Duration getDriverResponseTimeout() =>
      Duration(seconds: driverResponseTimeoutSeconds);

  Duration getPaymentTimeout() => Duration(seconds: paymentTimeoutSeconds);

  Duration getWebsocketReconnectInterval() =>
      Duration(milliseconds: websocketReconnectInterval);

  /// Dispose resources
  @override
  void dispose() {
    super.dispose();
    AppLogger.debug('ConfigProvider disposed');
  }
}

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/app_logger.dart';

/// CrashlyticsService - Servicio profesional de reporte de crashes
///
/// Sistema completo de manejo de crashes y errores para OasisTaxi:
/// - Integración con Firebase Crashlytics
/// - Reporte automático de errores no capturados
/// - Logs personalizados con contexto de usuario
/// - Métricas de estabilidad
/// - Segmentación por tipo de usuario (pasajero/conductor/admin)
/// - Información detallada del dispositivo
/// - Breadcrumbs para debugging
/// - Rate limiting para evitar spam
/// - Filtros de errores conocidos
/// - Reportes de ANR (Android Not Responding)
class CrashlyticsService {
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  factory CrashlyticsService() => _instance;
  CrashlyticsService._internal();

  late final FirebaseCrashlytics _crashlytics;
  late final FirebaseAnalytics _analytics;

  bool _isInitialized = false;
  String? _userId;
  String? _userType;
  String? _appVersion;
  String? _buildNumber;
  Map<String, String> _deviceInfo = {};
  final List<String> _breadcrumbs = [];

  // Rate limiting
  DateTime? _lastCrashReport;
  int _crashReportCount = 0;
  static const int _maxCrashReportsPerMinute = 10;

  // Errores conocidos para filtrar
  static const List<String> _knownIgnorableErrors = [
    'SocketException',
    'TimeoutException',
    'Connection timed out',
    'No route to host',
    'Network is unreachable',
    '_CastError',
    'RangeError (index)',
    'Failed assertion: line',
    'Null safety error',
    'setState() called after dispose()'
  ];

  /// Inicializar el servicio Crashlytics
  Future<void> initialize({
    bool collectUserMetrics = true,
    bool enableInDevMode = false,
  }) async {
    try {
      if (_isInitialized) return;

      _crashlytics = FirebaseCrashlytics.instance;
      _analytics = FirebaseAnalytics.instance;

      // Configurar colección automática
      await _crashlytics.setCrashlyticsCollectionEnabled(
        kReleaseMode || enableInDevMode,
      );

      // Obtener información de la app
      await _loadAppInfo();

      // Obtener información del dispositivo
      await _loadDeviceInfo();

      // Configurar handler de errores Flutter
      FlutterError.onError = (errorDetails) {
        _handleFlutterError(errorDetails);
      };

      // Configurar handler de errores asincrónicos
      PlatformDispatcher.instance.onError = (error, stack) {
        _handleAsyncError(error, stack);
        return true;
      };

      // Configurar custom keys por defecto
      await _setDefaultCustomKeys();

      _isInitialized = true;

      AppLogger.info('CrashlyticsService inicializado correctamente');
      addBreadcrumb('CrashlyticsService inicializado');
    } catch (e, stackTrace) {
      AppLogger.error('Error inicializando CrashlyticsService', e, stackTrace);
    }
  }

  /// Establecer información del usuario autenticado
  Future<void> setUserInfo({
    required String userId,
    required String userType, // 'passenger', 'driver', 'admin'
    String? email,
    String? phoneNumber,
    Map<String, String>? additionalInfo,
  }) async {
    try {
      if (!_isInitialized) return;

      _userId = userId;
      _userType = userType;

      // Configurar usuario en Crashlytics
      await _crashlytics.setUserIdentifier(userId);

      // Configurar custom keys
      await _crashlytics.setCustomKey('user_type', userType);

      if (email != null) {
        await _crashlytics.setCustomKey('user_email', email);
      }

      if (phoneNumber != null) {
        await _crashlytics.setCustomKey('user_phone', phoneNumber);
      }

      // Información adicional
      if (additionalInfo != null) {
        for (final entry in additionalInfo.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value);
        }
      }

      // También enviar a Analytics para correlación
      await _analytics.setUserId(id: userId);
      await _analytics.setUserProperty(name: 'user_type', value: userType);

      AppLogger.info('Usuario configurado en Crashlytics: $userId ($userType)');
      addBreadcrumb('Usuario configurado: $userType');
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error configurando usuario en Crashlytics', e, stackTrace);
    }
  }

  /// Limpiar información del usuario (logout)
  Future<void> clearUserInfo() async {
    try {
      if (!_isInitialized) return;

      _userId = null;
      _userType = null;

      // Limpiar usuario en Crashlytics
      await _crashlytics.setUserIdentifier('');

      // Limpiar custom keys relacionadas al usuario
      await _crashlytics.setCustomKey('user_type', '');
      await _crashlytics.setCustomKey('user_email', '');
      await _crashlytics.setCustomKey('user_phone', '');

      // Limpiar Analytics
      await _analytics.setUserId(id: null);

      AppLogger.info('Información de usuario limpiada de Crashlytics');
      addBreadcrumb('Usuario desconectado');
    } catch (e, stackTrace) {
      AppLogger.error('Error limpiando usuario de Crashlytics', e, stackTrace);
    }
  }

  /// Reportar error personalizado
  Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    Iterable<Object> information = const [],
    bool fatal = false,
    Map<String, String>? customKeys,
  }) async {
    try {
      if (!_isInitialized) return;

      // Rate limiting
      if (!_shouldReportError()) {
        AppLogger.warning('Error no reportado debido a rate limiting');
        return;
      }

      // Filtrar errores conocidos
      if (_isIgnorableError(exception.toString())) {
        AppLogger.debug('Error ignorado: ${exception.toString()}');
        return;
      }

      // Agregar información contextual
      final List<Object> enhancedInfo = [
        ...information,
        'User ID: $_userId',
        'User Type: $_userType',
        'App Version: $_appVersion',
        'Build Number: $_buildNumber',
        'Breadcrumbs: ${_breadcrumbs.join(' → ')}',
        ..._deviceInfo.entries.map((e) => '${e.key}: ${e.value}'),
      ];

      // Configurar custom keys si se proporcionan
      if (customKeys != null) {
        for (final entry in customKeys.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value);
        }
      }

      // Reportar error
      await _crashlytics.recordError(
        exception,
        stackTrace,
        reason: reason ?? 'Error reportado manualmente',
        information: enhancedInfo,
        fatal: fatal,
      );

      // Incrementar contador
      _crashReportCount++;
      _lastCrashReport = DateTime.now();

      // Log local
      AppLogger.error(
        'Error reportado a Crashlytics${fatal ? ' (FATAL)' : ''}${reason != null ? ': $reason' : ''}',
        exception,
        stackTrace,
      );

      // Enviar evento a Analytics
      await _analytics.logEvent(
        name: 'crash_reported',
        parameters: {
          'error_type': exception.runtimeType.toString(),
          'is_fatal': fatal,
          'user_type': _userType ?? 'unknown',
          'reason': reason ?? 'manual',
        },
      );

      addBreadcrumb(
          'Error reportado${fatal ? ' (FATAL)' : ''}: ${exception.runtimeType}');
    } catch (e, stackTrace) {
      AppLogger.error('Error reportando a Crashlytics', e, stackTrace);
    }
  }

  /// Reportar mensaje personalizado
  Future<void> log(
    String message, {
    String? level = 'INFO',
    Map<String, String>? additionalData,
  }) async {
    try {
      if (!_isInitialized) return;

      final logMessage = '[$level] $message';
      await _crashlytics.log(logMessage);

      // Configurar datos adicionales si se proporcionan
      if (additionalData != null) {
        for (final entry in additionalData.entries) {
          await _crashlytics.setCustomKey('log_${entry.key}', entry.value);
        }
      }

      AppLogger.info('Log enviado a Crashlytics: $logMessage');
    } catch (e, stackTrace) {
      AppLogger.error('Error enviando log a Crashlytics', e, stackTrace);
    }
  }

  /// Agregar breadcrumb para tracking de flujo
  void addBreadcrumb(
    String message, {
    String? category,
    Map<String, String>? data,
  }) {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final breadcrumb =
          '$timestamp: ${category != null ? '[$category] ' : ''}$message';

      _breadcrumbs.add(breadcrumb);

      // Mantener solo los últimos 20 breadcrumbs
      if (_breadcrumbs.length > 20) {
        _breadcrumbs.removeAt(0);
      }

      // También enviar a Crashlytics
      if (_isInitialized) {
        _crashlytics.log(breadcrumb);
      }

      AppLogger.debug('Breadcrumb agregado: $breadcrumb');
    } catch (e) {
      AppLogger.error('Error agregando breadcrumb', e, null);
    }
  }

  /// Configurar custom key
  Future<void> setCustomKey(String key, String value) async {
    try {
      if (!_isInitialized) return;

      await _crashlytics.setCustomKey(key, value);
      AppLogger.debug('Custom key configurada: $key = $value');
    } catch (e, stackTrace) {
      AppLogger.error('Error configurando custom key', e, stackTrace);
    }
  }

  /// Reportar evento de navegación
  Future<void> recordNavigation(String from, String to) async {
    try {
      addBreadcrumb('Navegación: $from → $to', category: 'NAVIGATION');

      await setCustomKey('last_navigation_from', from);
      await setCustomKey('last_navigation_to', to);

      // Enviar a Analytics también
      await _analytics.logEvent(
        name: 'screen_navigation',
        parameters: {
          'from_screen': from,
          'to_screen': to,
          'user_type': _userType ?? 'unknown',
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error reportando navegación', e, stackTrace);
    }
  }

  /// Reportar evento de viaje (específico para OasisTaxi)
  Future<void> recordTripEvent(
    String event, {
    String? tripId,
    String? driverId,
    String? passengerId,
    Map<String, String>? additionalData,
  }) async {
    try {
      final Map<String, String> tripData = {
        'trip_event': event,
        if (tripId != null) 'trip_id': tripId,
        if (driverId != null) 'driver_id': driverId,
        if (passengerId != null) 'passenger_id': passengerId,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      // Configurar custom keys
      for (final entry in tripData.entries) {
        await setCustomKey('trip_${entry.key}', entry.value);
      }

      addBreadcrumb('Evento de viaje: $event',
          category: 'TRIP', data: tripData);

      // Enviar a Analytics
      await _analytics.logEvent(
        name: 'trip_event',
        parameters: {
          'event_type': event,
          'user_type': _userType ?? 'unknown',
          ...tripData,
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error reportando evento de viaje', e, stackTrace);
    }
  }

  /// Reportar evento de pago
  Future<void> recordPaymentEvent(
    String event, {
    String? paymentMethod,
    double? amount,
    String? currency,
    String? transactionId,
    Map<String, String>? additionalData,
  }) async {
    try {
      final Map<String, String> paymentData = {
        'payment_event': event,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (amount != null) 'amount': amount.toString(),
        if (currency != null) 'currency': currency,
        if (transactionId != null) 'transaction_id': transactionId,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      // Configurar custom keys (sin datos sensibles)
      for (final entry in paymentData.entries) {
        if (!entry.key.contains('sensitive')) {
          await setCustomKey('payment_${entry.key}', entry.value);
        }
      }

      addBreadcrumb('Evento de pago: $event', category: 'PAYMENT');

      // Enviar a Analytics (sin datos sensibles)
      await _analytics.logEvent(
        name: 'payment_event',
        parameters: {
          'event_type': event,
          'payment_method': paymentMethod ?? 'unknown',
          'user_type': _userType ?? 'unknown',
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error reportando evento de pago', e, stackTrace);
    }
  }

  /// Forzar envío de reportes pendientes
  Future<void> sendUnsentReports() async {
    try {
      if (!_isInitialized) return;

      await _crashlytics.sendUnsentReports();
      AppLogger.info('Reportes pendientes enviados a Crashlytics');
      addBreadcrumb('Reportes pendientes enviados');
    } catch (e, stackTrace) {
      AppLogger.error('Error enviando reportes pendientes', e, stackTrace);
    }
  }

  /// Verificar si Crashlytics está habilitado
  Future<bool> isCrashlyticsCollectionEnabled() async {
    try {
      if (!_isInitialized) return false;
      return _crashlytics.isCrashlyticsCollectionEnabled;
    } catch (e) {
      AppLogger.error('Error verificando estado de Crashlytics', e, null);
      return false;
    }
  }

  /// Habilitar/deshabilitar colección de datos
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    try {
      if (!_isInitialized) return;

      await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
      AppLogger.info(
          'Colección de Crashlytics ${enabled ? 'habilitada' : 'deshabilitada'}');
      addBreadcrumb(
          'Colección de datos ${enabled ? 'habilitada' : 'deshabilitada'}');
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error configurando colección de Crashlytics', e, stackTrace);
    }
  }

  /// Obtener estadísticas de crashes
  Map<String, dynamic> getCrashStats() {
    return {
      'is_initialized': _isInitialized,
      'user_id': _userId,
      'user_type': _userType,
      'app_version': _appVersion,
      'build_number': _buildNumber,
      'device_info': _deviceInfo,
      'breadcrumbs_count': _breadcrumbs.length,
      'crash_reports_this_session': _crashReportCount,
      'last_crash_report': _lastCrashReport?.toIso8601String(),
    };
  }

  /// Obtener breadcrumbs actuales
  List<String> getBreadcrumbs() {
    return List.from(_breadcrumbs);
  }

  // Métodos privados

  /// Manejar errores de Flutter
  void _handleFlutterError(FlutterErrorDetails errorDetails) {
    try {
      // Rate limiting
      if (!_shouldReportError()) return;

      // Filtrar errores conocidos
      if (_isIgnorableError(errorDetails.toString())) return;

      // Reportar a Crashlytics
      _crashlytics.recordFlutterError(errorDetails);

      // Log local
      AppLogger.error(
        'Flutter Error capturado por Crashlytics',
        errorDetails.exception,
        errorDetails.stack,
      );

      addBreadcrumb('Flutter Error: ${errorDetails.exception.runtimeType}');

      _crashReportCount++;
      _lastCrashReport = DateTime.now();
    } catch (e) {
      AppLogger.error('Error manejando Flutter error', e, null);
    }
  }

  /// Manejar errores asincrónicos
  void _handleAsyncError(Object error, StackTrace stackTrace) {
    try {
      // Rate limiting
      if (!_shouldReportError()) return;

      // Filtrar errores conocidos
      if (_isIgnorableError(error.toString())) return;

      // Reportar a Crashlytics
      _crashlytics.recordError(
        error,
        stackTrace,
        reason: 'Uncaught async error',
        fatal: false,
      );

      // Log local
      AppLogger.error(
          'Async Error capturado por Crashlytics', error, stackTrace);

      addBreadcrumb('Async Error: ${error.runtimeType}');

      _crashReportCount++;
      _lastCrashReport = DateTime.now();
    } catch (e) {
      AppLogger.error('Error manejando async error', e, null);
    }
  }

  /// Cargar información de la aplicación
  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;

      await _crashlytics.setCustomKey('app_version', _appVersion ?? 'unknown');
      await _crashlytics.setCustomKey(
          'build_number', _buildNumber ?? 'unknown');
    } catch (e) {
      AppLogger.error('Error cargando información de la app', e, null);
    }
  }

  /// Cargar información del dispositivo
  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        _deviceInfo = {
          'platform': 'Android',
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'version_release': androidInfo.version.release,
          'version_sdk_int': androidInfo.version.sdkInt.toString(),
          'is_physical_device': androidInfo.isPhysicalDevice.toString(),
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        _deviceInfo = {
          'platform': 'iOS',
          'name': iosInfo.name,
          'model': iosInfo.model,
          'localized_model': iosInfo.localizedModel,
          'system_name': iosInfo.systemName,
          'system_version': iosInfo.systemVersion,
          'is_physical_device': iosInfo.isPhysicalDevice.toString(),
        };
      } else {
        _deviceInfo = {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        };
      }

      // Configurar custom keys
      for (final entry in _deviceInfo.entries) {
        await _crashlytics.setCustomKey('device_${entry.key}', entry.value);
      }
    } catch (e) {
      AppLogger.error('Error cargando información del dispositivo', e, null);
    }
  }

  /// Configurar custom keys por defecto
  Future<void> _setDefaultCustomKeys() async {
    try {
      await _crashlytics.setCustomKey(
          'environment', kReleaseMode ? 'production' : 'development');
      await _crashlytics.setCustomKey('app_name', 'OasisTaxi');
      await _crashlytics.setCustomKey(
          'initialized_at', DateTime.now().toIso8601String());
      await _crashlytics.setCustomKey('dart_version', Platform.version);
    } catch (e) {
      AppLogger.error('Error configurando custom keys por defecto', e, null);
    }
  }

  /// Verificar rate limiting
  bool _shouldReportError() {
    final now = DateTime.now();

    // Resetear contador cada minuto
    if (_lastCrashReport == null ||
        now.difference(_lastCrashReport!).inMinutes >= 1) {
      _crashReportCount = 0;
    }

    return _crashReportCount < _maxCrashReportsPerMinute;
  }

  /// Verificar si un error debe ser ignorado
  bool _isIgnorableError(String errorMessage) {
    return _knownIgnorableErrors.any((ignore) => errorMessage.contains(ignore));
  }
}

/// Extension para facilitar uso en widgets
extension CrashlyticsContext on Object {
  void reportError(dynamic error, [StackTrace? stackTrace, String? context]) {
    CrashlyticsService().recordError(
      error,
      stackTrace,
      reason: context ?? 'Error from $runtimeType',
    );
  }

  void addBreadcrumb(String message) {
    CrashlyticsService().addBreadcrumb('$runtimeType: $message');
  }
}

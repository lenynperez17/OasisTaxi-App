import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Sistema de logging profesional para OasisTaxi
/// Niveles: debug, info, warning, error, critical
///
/// CONFIGURACIÓN DE PRODUCCIÓN:
/// - En desarrollo: Todos los logs visibles
/// - En producción: Solo warnings y errores críticos
/// - Los logs informativos se ocultan automáticamente en release
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: kDebugMode ? 2 : 0,
      errorMethodCount: kDebugMode ? 5 : 0,
      lineLength: 120,
      colors: kDebugMode,
      printEmojis: kDebugMode,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode
        ? Level.debug
        : Level.warning, // Solo warnings y errores en producción
  );

  // Singleton
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  /// Log de información general (solo en desarrollo)
  static void info(String message, [dynamic data]) {
    if (kDebugMode) {
      _logger.i(message, error: data);
      _developerLog('INFO', message, data);
    }
  }

  /// Log de debug (solo en desarrollo)
  static void debug(String message, [dynamic data]) {
    if (kDebugMode) {
      _logger.d(message, error: data);
      _developerLog('DEBUG', message, data);
    }
  }

  /// Log de advertencia
  static void warning(String message, [dynamic data]) {
    _logger.w(message, error: data);
    _developerLog('WARNING', message, data);
  }

  /// Log de error con stack trace
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _developerLog('ERROR', message, error, stackTrace);
  }

  /// Log de error crítico
  static void critical(String message,
      [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    _developerLog('CRITICAL', message, error, stackTrace);
  }

  /// Log de llamadas API (solo en desarrollo)
  static void api(String method, String endpoint,
      [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      final message = '$method $endpoint';
      _logger.i(message, error: data);
      _developerLog('API', message, data);
    }
  }

  /// Log de operaciones Firebase (solo en desarrollo)
  static void firebase(String operation, [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      final message = 'Firebase: $operation';
      _logger.i(message, error: data);
      _developerLog('FIREBASE', message, data);
    }
  }

  /// Log de navegación (solo en desarrollo)
  static void navigation(String from, String to) {
    if (kDebugMode) {
      final message = 'Navigation: $from → $to';
      _logger.i(message);
      _developerLog('NAV', message);
    }
  }

  /// Log de performance
  static void performance(String operation, int milliseconds) {
    final message = 'Performance: $operation took ${milliseconds}ms';
    if (milliseconds > 1000) {
      _logger.w(message);
    } else {
      _logger.i(message);
    }
    _developerLog('PERF', message);
  }

  /// Log de seguridad
  static void security(String event, [Map<String, dynamic>? details]) {
    final message = 'Security: $event';
    _logger.w(message, error: details);
    _developerLog('SECURITY', message, details);
  }

  /// Log de autenticación
  static void auth(String event, [Map<String, dynamic>? details]) {
    final message = 'Auth: $event';
    _logger.i(message, error: details);
    _developerLog('AUTH', message, details);
  }

  /// Log de estado
  static void state(String message, [dynamic data]) {
    _logger.i('State: $message', error: data);
    _developerLog('STATE', message, data);
  }

  /// Log de ciclo de vida
  static void lifecycle(String event, [dynamic data]) {
    _logger.d('Lifecycle: $event', error: data);
    _developerLog('LIFECYCLE', event, data);
  }

  /// Separador visual para logs
  static void separator([String? label]) {
    final sep = '═' * 50;
    final message = label != null ? '═══ $label ═══' : sep;
    _logger.i(message);
    _developerLog('SEPARATOR', message);
  }

  /// Log de pagos
  static void payment(String event, [Map<String, dynamic>? details]) {
    final message = 'Payment: $event';
    _logger.i(message, error: details);
    _developerLog('PAYMENT', message, details);
  }

  /// Log de viajes
  static void trip(String event, String tripId,
      [Map<String, dynamic>? details]) {
    final message = 'Trip [$tripId]: $event';
    _logger.i(message, error: details);
    _developerLog('TRIP', message, details);
  }

  /// Log de chat
  static void chat(String event, [Map<String, dynamic>? details]) {
    final message = 'Chat: $event';
    _logger.i(message, error: details);
    _developerLog('CHAT', message, details);
  }

  /// Log de ubicación
  static void location(String event, [Map<String, dynamic>? details]) {
    final message = 'Location: $event';
    _logger.i(message, error: details);
    _developerLog('LOCATION', message, details);
  }

  /// Log de notificaciones
  static void notification(String event, [Map<String, dynamic>? details]) {
    final message = 'Notification: $event';
    _logger.i(message, error: details);
    _developerLog('NOTIF', message, details);
  }

  /// Log de emergencia
  static void emergency(String event, [Map<String, dynamic>? details]) {
    final message = 'EMERGENCY: $event';
    _logger.f(message, error: details);
    _developerLog('EMERGENCY', message, details);
  }

  /// Log para el developer console de Flutter
  static void _developerLog(
    String level,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    if (kDebugMode) {
      developer.log(
        message,
        name: 'OasisTaxi.$level',
        error: error,
        stackTrace: stackTrace,
        time: DateTime.now(),
      );
    }
  }

  /// Log de inicio de la aplicación
  static void appStart() {
    const message = '''
╔══════════════════════════════════════════╗
║         OASIS TAXI APP STARTED           ║
╚══════════════════════════════════════════╝
    ''';
    _logger.i(message);
    _developerLog('SYSTEM', 'App Started');
  }

  /// Log de configuración
  static void config(String key, dynamic value) {
    final message = 'Config: $key = $value';
    if (kDebugMode) {
      _logger.d(message);
      _developerLog('CONFIG', message);
    }
  }

  /// Log de base de datos
  static void database(String operation, [Map<String, dynamic>? details]) {
    final message = 'Database: $operation';
    _logger.i(message, error: details);
    _developerLog('DB', message, details);
  }

  /// Log de caché
  static void cache(String operation, [Map<String, dynamic>? details]) {
    final message = 'Cache: $operation';
    _logger.d(message, error: details);
    _developerLog('CACHE', message, details);
  }

  /// Log de validación
  static void validation(String field, String issue) {
    final message = 'Validation: $field - $issue';
    _logger.w(message);
    _developerLog('VALIDATION', message);
  }

  /// Log de WebSocket
  static void websocket(String event, [Map<String, dynamic>? details]) {
    final message = 'WebSocket: $event';
    _logger.i(message, error: details);
    _developerLog('WS', message, details);
  }

  /// Log de MFA
  static void mfa(String event, [Map<String, dynamic>? details]) {
    final message = 'MFA: $event';
    _logger.i(message, error: details);
    _developerLog('MFA', message, details);
  }

  /// Log de rate limiting
  static void rateLimit(String action, bool allowed) {
    final message = 'RateLimit: $action - ${allowed ? "ALLOWED" : "BLOCKED"}';
    if (!allowed) {
      _logger.w(message);
    } else {
      _logger.i(message);
    }
    _developerLog('RATE_LIMIT', message);
  }

  /// Log de device security
  static void deviceSecurity(String check, bool passed) {
    final message = 'DeviceSecurity: $check - ${passed ? "PASSED" : "FAILED"}';
    if (!passed) {
      _logger.w(message);
    } else {
      _logger.i(message);
    }
    _developerLog('DEVICE_SEC', message);
  }

  /// Log de App Check
  static void appCheck(String event, [Map<String, dynamic>? details]) {
    final message = 'AppCheck: $event';
    _logger.i(message, error: details);
    _developerLog('APP_CHECK', message, details);
  }

  /// Log de CAPTCHA
  static void captcha(String event, bool success) {
    final message = 'CAPTCHA: $event - ${success ? "SUCCESS" : "FAILED"}';
    _logger.i(message);
    _developerLog('CAPTCHA', message);
  }

  /// Log de audit
  static void audit(String action, String userId,
      [Map<String, dynamic>? details]) {
    final message = 'Audit: User $userId - $action';
    _logger.i(message, error: details);
    _developerLog('AUDIT', message, details);
  }

  /// Log de sesión
  static void session(String event, [Map<String, dynamic>? details]) {
    final message = 'Session: $event';
    _logger.i(message, error: details);
    _developerLog('SESSION', message, details);
  }

  /// Log de cifrado
  static void encryption(String operation, bool success) {
    final message =
        'Encryption: $operation - ${success ? "SUCCESS" : "FAILED"}';
    if (!success) {
      _logger.e(message);
    } else {
      _logger.i(message);
    }
    _developerLog('CRYPTO', message);
  }
}

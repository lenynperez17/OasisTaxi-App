import 'dart:collection';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Logger seguro que solo muestra logs en modo debug
/// En producción, los logs son completamente deshabilitados
class SecureLogger {
  static final SecureLogger _instance = SecureLogger._internal();
  factory SecureLogger() => _instance;
  SecureLogger._internal();

  // Configuración
  static const int maxLogSize = 1000; // Máximo de logs en memoria
  static const bool enableInRelease = false; // Deshabilitar en producción

  // Niveles de log
  static const String levelDebug = 'DEBUG';
  static const String levelInfo = 'INFO';
  static const String levelWarning = 'WARNING';
  static const String levelError = 'ERROR';
  static const String levelCritical = 'CRITICAL';

  // Cola de logs (solo para debug)
  final Queue<LogEntry> _logHistory = Queue<LogEntry>();

  // Patrones sensibles a filtrar
  static final List<RegExp> _sensitivePatterns = [
    RegExp(r'password[^\s]*[:=][^\s]+', caseSensitive: false),
    RegExp(r'token[^\s]*[:=][^\s]+', caseSensitive: false),
    RegExp(r'api[_-]?key[^\s]*[:=][^\s]+', caseSensitive: false),
    RegExp(r'secret[^\s]*[:=][^\s]+', caseSensitive: false),
    RegExp(r'credit[_-]?card[^\s]*[:=][\d\s-]+', caseSensitive: false),
    RegExp(
        r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'), // Tarjetas de crédito
    RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), // SSN
    RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'), // Emails
    RegExp(r'\+?51\s?\d{9}'), // Teléfonos peruanos
    RegExp(r'Bearer\s+[A-Za-z0-9._~+/-]+',
        caseSensitive: false), // Bearer tokens
  ];

  /// Log de nivel DEBUG
  static void debug(String message, [dynamic data]) {
    _instance._log(levelDebug, message, data);
  }

  /// Log de nivel INFO
  static void info(String message, [dynamic data]) {
    _instance._log(levelInfo, message, data);
  }

  /// Log de nivel WARNING
  static void warning(String message, [dynamic data]) {
    _instance._log(levelWarning, message, data);
  }

  /// Log de nivel ERROR
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _instance._log(levelError, message, error, stackTrace);
  }

  /// Log de nivel CRITICAL
  static void critical(String message,
      [dynamic error, StackTrace? stackTrace]) {
    _instance._log(levelCritical, message, error, stackTrace);
  }

  /// Log específico para eventos de encriptación
  static void logEncryptionEvent(String event, Map<String, dynamic> data) {
    _instance._log(levelInfo, 'Encryption Event: $event', data);
  }

  /// Log específico para acciones GDPR
  static void logGDPRAction(String action, Map<String, dynamic> data) {
    _instance._log(levelInfo, 'GDPR Action: $action', data);
  }

  /// Log interno
  void _log(String level, String message,
      [dynamic data, StackTrace? stackTrace]) {
    // En producción, no hacer nada
    if (!kDebugMode && !enableInRelease) {
      return;
    }

    // Sanitizar el mensaje
    final sanitizedMessage = _sanitizeMessage(message);
    final sanitizedData =
        data != null ? _sanitizeMessage(data.toString()) : null;

    // Crear entrada de log
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: sanitizedMessage,
      data: sanitizedData,
      stackTrace: stackTrace,
    );

    // Agregar a historial (con límite)
    _logHistory.add(entry);
    if (_logHistory.length > maxLogSize) {
      _logHistory.removeFirst();
    }

    // Solo imprimir en modo debug
    if (kDebugMode) {
      _printLog(entry);
    }
  }

  /// Sanitiza mensajes para remover información sensible
  String _sanitizeMessage(String message) {
    var sanitized = message;

    for (final pattern in _sensitivePatterns) {
      sanitized = sanitized.replaceAll(pattern, '***REDACTED***');
    }

    return sanitized;
  }

  /// Imprime el log formateado
  void _printLog(LogEntry entry) {
    final timestamp = DateFormat('HH:mm:ss.SSS').format(entry.timestamp);
    final icon = _getIconForLevel(entry.level);

    // Formato con colores ANSI (solo funciona en consola)
    final color = _getColorForLevel(entry.level);

    String output =
        '$color$icon [$timestamp] [${entry.level}] ${entry.message}';

    if (entry.data != null) {
      output += '\n    Data: ${entry.data}';
    }

    if (entry.stackTrace != null && entry.level != levelDebug) {
      output += '\n    Stack: ${_formatStackTrace(entry.stackTrace!)}';
    }

    output += '\x1B[0m'; // Reset color

    // Usar dart:developer log para evitar truncamiento y warnings
    if (kDebugMode) {
      developer.log(output, name: 'SecureLogger');
    }
  }

  /// Obtiene el icono para el nivel de log
  String _getIconForLevel(String level) {
    switch (level) {
      case levelDebug:
        return '🐛';
      case levelInfo:
        return 'ℹ️';
      case levelWarning:
        return '⚠️';
      case levelError:
        return '❌';
      case levelCritical:
        return '🔥';
      default:
        return '📝';
    }
  }

  /// Obtiene el color ANSI para el nivel de log
  String _getColorForLevel(String level) {
    if (!kDebugMode) return '';

    switch (level) {
      case levelDebug:
        return '\x1B[90m'; // Gris
      case levelInfo:
        return '\x1B[36m'; // Cyan
      case levelWarning:
        return '\x1B[33m'; // Amarillo
      case levelError:
        return '\x1B[31m'; // Rojo
      case levelCritical:
        return '\x1B[91m'; // Rojo brillante
      default:
        return '\x1B[0m'; // Default
    }
  }

  /// Formatea el stack trace para que sea más legible
  String _formatStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    if (lines.length > 3) {
      return lines.take(3).join('\n    ');
    }
    return stackTrace.toString();
  }

  /// Exporta logs a string (para debugging)
  String exportLogs() {
    if (!kDebugMode) return 'Logs disabled in production';

    final buffer = StringBuffer();
    buffer.writeln('=== OasisTaxi Log Export ===');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${_logHistory.length}');
    buffer.writeln('');

    for (final entry in _logHistory) {
      buffer.writeln(
          '${entry.timestamp.toIso8601String()} [${entry.level}] ${entry.message}');
      if (entry.data != null) {
        buffer.writeln('  Data: ${entry.data}');
      }
    }

    return buffer.toString();
  }
}

/// Entrada de log
class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String? data;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.data,
    this.stackTrace,
  });
}

/// Helper functions para migración fácil de print/debugPrint
class AppLog {
  /// Reemplazo directo de print() - solo funciona en debug
  static void p(dynamic message) {
    if (kDebugMode) {
      SecureLogger.debug(message.toString());
    }
  }

  /// Reemplazo directo de debugPrint() - solo funciona en debug
  static void d(dynamic message) {
    if (kDebugMode) {
      SecureLogger.debug(message.toString());
    }
  }

  /// Log de información
  static void i(String message, [dynamic data]) {
    SecureLogger.info(message, data);
  }

  /// Log de advertencia
  static void w(String message, [dynamic data]) {
    SecureLogger.warning(message, data);
  }

  /// Log de error
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    SecureLogger.error(message, error, stackTrace);
  }

  /// Log crítico
  static void c(String message, [dynamic error, StackTrace? stackTrace]) {
    SecureLogger.critical(message, error, stackTrace);
  }
}

/// Extensión para facilitar el logging en widgets
extension LoggingExtension on Object {
  void logDebug([String? message]) {
    SecureLogger.debug(message ?? toString());
  }

  void logInfo([String? message]) {
    SecureLogger.info(message ?? toString());
  }

  void logWarning([String? message]) {
    SecureLogger.warning(message ?? toString());
  }

  void logError([String? message, StackTrace? stackTrace]) {
    SecureLogger.error(message ?? toString(), this, stackTrace);
  }
}

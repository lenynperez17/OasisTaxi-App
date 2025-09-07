import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _prefix = '🚕 OasisTaxi';
  static bool _debugMode = false; // DESHABILITADO para producción
  
  static void enableDebugMode() {
    _debugMode = true;
  }
  
  static void disableDebugMode() {
    _debugMode = false;
  }
  
  // Log de información general
  static void info(String message, [dynamic data]) {
    if (!_debugMode && !kDebugMode) return;
    
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_prefix [INFO] [$timestamp] $message');
    if (data != null) {
      debugPrint('  📋 Data: $data');
    }
  }
  
  // Log de errores
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_prefix ❌ [ERROR] [$timestamp] $message');
    if (error != null) {
      debugPrint('  ⚠️ Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('  📍 StackTrace: $stackTrace');
    }
  }
  
  // Log de warnings
  static void warning(String message, [dynamic data]) {
    if (!_debugMode && !kDebugMode) return;
    
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_prefix ⚠️ [WARNING] [$timestamp] $message');
    if (data != null) {
      debugPrint('  📋 Data: $data');
    }
  }
  
  // Log crítico (siempre se muestra)
  static void critical(String message, [dynamic data]) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_prefix 🚨 [CRITICAL] [$timestamp] $message');
    if (data != null) {
      debugPrint('  🔴 Critical Data: $data');
    }
    // En producción, esto también podría enviar a un servicio de monitoreo
  }
  
  // Log de debug
  static void debug(String message, [dynamic data]) {
    if (!kDebugMode) return;
    
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_prefix 🔍 [DEBUG] [$timestamp] $message');
    if (data != null) {
      debugPrint('  📋 Data: $data');
    }
  }
  
  // Log de navegación
  static void navigation(String from, String to, [dynamic args]) {
    if (!_debugMode && !kDebugMode) return;
    
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_prefix 🧭 [NAV] [$timestamp] $from → $to');
    if (args != null) {
      debugPrint('  📦 Args: $args');
    }
  }
  
  // Log de API
  static void api(String method, String endpoint, [dynamic data]) {
    if (!_debugMode && !kDebugMode) return;
    
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_prefix 🌐 [API] [$timestamp] $method $endpoint');
    if (data != null) {
      debugPrint('  📤 Data: $data');
    }
  }
  
  // Log de respuesta API
  static void apiResponse(int statusCode, String endpoint, [dynamic data]) {
    if (!_debugMode && !kDebugMode) return;
    
    final timestamp = DateTime.now().toIso8601String();
    final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    debugPrint('$_prefix $emoji [API RESPONSE] [$timestamp] $statusCode - $endpoint');
    if (data != null) {
      debugPrint('  📥 Response: $data');
    }
  }
  
  // Log de Firebase
  static void firebase(String action, [dynamic data]) {
    if (!_debugMode && !kDebugMode) return;
    
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_prefix 🔥 [FIREBASE] [$timestamp] $action');
    if (data != null) {
      debugPrint('  📋 Data: $data');
    }
  }
  
  // Log de Provider/State
  static void state(String provider, String action, [dynamic data]) {
    if (!_debugMode && !kDebugMode) return;
    
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_prefix 📊 [STATE] [$timestamp] $provider.$action');
    if (data != null) {
      debugPrint('  📋 State: $data');
    }
  }
  
  // Log de ciclo de vida
  static void lifecycle(String widget, String event) {
    if (!kDebugMode) return;
    
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_prefix 🔄 [LIFECYCLE] [$timestamp] $widget: $event');
  }
  
  // Log de performance
  static void performance(String operation, int milliseconds) {
    if (!_debugMode && !kDebugMode) return;
    
    final timestamp = DateTime.now().toIso8601String();
    final emoji = milliseconds < 100 ? '⚡' : milliseconds < 500 ? '🐢' : '🐌';
    debugPrint('$_prefix $emoji [PERF] [$timestamp] $operation took ${milliseconds}ms');
  }
  
  // Separador visual para mejor legibilidad
  static void separator([String? title]) {
    if (!kDebugMode) return;
    
    if (title != null) {
      debugPrint('═══════════════ $title ═══════════════');
    } else {
      debugPrint('════════════════════════════════════════');
    }
  }
}
import '../utils/app_logger.dart';

/// Servicio para limitar la tasa de intentos de login y otras operaciones
class RateLimiterService {
  static final RateLimiterService _instance = RateLimiterService._internal();
  factory RateLimiterService() => _instance;
  RateLimiterService._internal();

  final Map<String, List<DateTime>> _attempts = {};
  final Map<String, DateTime> _blockedUntil = {};

  // Configuración
  static const int maxAttempts = 5;
  static const Duration windowDuration = Duration(minutes: 15);
  static const Duration blockDuration = Duration(minutes: 30);

  /// Verifica si se puede hacer un intento para la clave dada
  bool canAttempt(String key) {
    // Verificar si está bloqueado
    if (_blockedUntil.containsKey(key)) {
      final blockTime = _blockedUntil[key]!;
      if (DateTime.now().isBefore(blockTime)) {
        return false;
      } else {
        _blockedUntil.remove(key);
      }
    }

    // Limpiar intentos antiguos
    _cleanOldAttempts(key);

    // Verificar cantidad de intentos
    final attempts = _attempts[key] ?? [];
    return attempts.length < maxAttempts;
  }

  /// Registra un intento
  void recordAttempt(String key) {
    _cleanOldAttempts(key);

    if (!_attempts.containsKey(key)) {
      _attempts[key] = [];
    }

    _attempts[key]!.add(DateTime.now());

    // Si se excedió el límite, bloquear
    if (_attempts[key]!.length >= maxAttempts) {
      _blockedUntil[key] = DateTime.now().add(blockDuration);
      AppLogger.warning(
          'RateLimiter: Clave $key bloqueada por exceder intentos');
    }
  }

  /// Registra un intento exitoso (resetea el contador)
  void recordSuccess(String key) {
    _attempts.remove(key);
    _blockedUntil.remove(key);
  }

  /// Obtiene el tiempo restante de bloqueo
  Duration? getRemainingBlockTime(String key) {
    if (!_blockedUntil.containsKey(key)) {
      return null;
    }

    final blockTime = _blockedUntil[key]!;
    final now = DateTime.now();

    if (now.isBefore(blockTime)) {
      return blockTime.difference(now);
    } else {
      _blockedUntil.remove(key);
      return null;
    }
  }

  /// Obtiene mensaje descriptivo del estado
  String getMessage(String key) {
    final blockTime = getRemainingBlockTime(key);
    if (blockTime != null) {
      final minutes = blockTime.inMinutes;
      final seconds = blockTime.inSeconds % 60;
      return 'Demasiados intentos. Espera ${minutes}m ${seconds}s';
    }

    _cleanOldAttempts(key);
    final attempts = _attempts[key]?.length ?? 0;
    final remaining = maxAttempts - attempts;

    if (remaining <= 2) {
      return 'Te quedan $remaining intentos';
    }

    return '';
  }

  /// Limpia intentos antiguos fuera de la ventana temporal
  void _cleanOldAttempts(String key) {
    if (!_attempts.containsKey(key)) return;

    final cutoff = DateTime.now().subtract(windowDuration);
    _attempts[key] = _attempts[key]!.where((dt) => dt.isAfter(cutoff)).toList();

    if (_attempts[key]!.isEmpty) {
      _attempts.remove(key);
    }
  }

  // Métodos adicionales para compatibilidad con el mixin
  bool checkRateLimit(String key) {
    return canAttempt(key);
  }

  void onFailedAttempt(String key) {
    recordAttempt(key);
  }

  void onSuccessfulAttempt(String key) {
    recordSuccess(key);
  }

  String getRateLimitMessage(String key) {
    return getMessage(key);
  }
}

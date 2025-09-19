import 'package:flutter/material.dart';
import '../../services/rate_limiter_service.dart';

/// Mixin para agregar funcionalidad de rate limiting a pantallas de autenticación
mixin RateLimiterMixin<T extends StatefulWidget> on State<T> {
  final RateLimiterService _rateLimiter = RateLimiterService();

  /// Verifica si se ha alcanzado el límite de intentos
  bool checkRateLimit(String identifier) {
    return _rateLimiter.checkRateLimit(identifier);
  }

  /// Obtiene el mensaje de error de rate limit
  String getRateLimitMessage(String identifier) {
    return _rateLimiter.getRateLimitMessage(identifier);
  }

  /// Registra un intento exitoso
  void onSuccessfulAttempt(String identifier) {
    _rateLimiter.onSuccessfulAttempt(identifier);
  }

  /// Registra un intento fallido
  void onFailedAttempt(String identifier) {
    _rateLimiter.onFailedAttempt(identifier);
  }

  /// Muestra un snackbar con el mensaje de rate limit
  void showRateLimitError(String identifier) {
    if (!checkRateLimit(identifier)) {
      final message = getRateLimitMessage(identifier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Limpia el estado del rate limiter al destruir el widget
  @override
  void dispose() {
    // No es necesario limpiar porque RateLimiterService es singleton
    super.dispose();
  }
}

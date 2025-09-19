import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'secure_storage_service.dart';
import '../utils/app_logger.dart';

/// Servicio de autenticación biométrica para mayor seguridad
/// Soporta Face ID, Touch ID, huella dactilar en Android
class BiometricAuthService {
  static final BiometricAuthService _instance =
      BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorageService _secureStorage = SecureStorageService();

  // Estado del servicio
  bool _isAvailable = false;
  bool _isDeviceSupported = false;
  List<BiometricType> _availableBiometrics = [];

  /// Inicializa el servicio de autenticación biométrica
  Future<void> initialize() async {
    try {
      // Verificar si el dispositivo soporta biometría
      _isDeviceSupported = await _localAuth.isDeviceSupported();

      // Verificar si hay biometría disponible
      _isAvailable = await _localAuth.canCheckBiometrics;

      if (_isAvailable) {
        // Obtener tipos de biometría disponibles
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
      }

      if (kDebugMode) {
        AppLogger.info('Biometría soportada: $_isDeviceSupported');
        AppLogger.info('Biometría disponible: $_isAvailable');
        AppLogger.debug('Tipos disponibles: $_availableBiometrics');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('Error inicializando biometría', e);
      }
      _isAvailable = false;
    }
  }

  /// Verifica si la biometría está disponible
  Future<bool> isBiometricAvailable() async {
    try {
      if (!_isDeviceSupported) {
        await initialize();
      }

      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      return canCheck && isSupported;
    } catch (e) {
      return false;
    }
  }

  /// Alias para mantener compatibilidad con isAvailable()
  Future<bool> isAvailable() async {
    return isBiometricAvailable();
  }

  /// Obtiene los tipos de biometría disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Verifica si Face ID está disponible (iOS)
  Future<bool> hasFaceId() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// Verifica si Touch ID está disponible (iOS)
  Future<bool> hasTouchId() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint);
  }

  /// Verifica si huella dactilar está disponible (Android)
  Future<bool> hasFingerprint() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint);
  }

  /// Autentica al usuario con biometría
  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
    bool sensitiveTransaction = true,
  }) async {
    try {
      // Verificar disponibilidad
      if (!await isBiometricAvailable()) {
        return BiometricAuthResult(
          success: false,
          error: BiometricAuthError.notAvailable,
          message: 'La autenticación biométrica no está disponible',
        );
      }

      // Intentar autenticación
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          sensitiveTransaction: sensitiveTransaction,
          biometricOnly: true, // Solo biometría, no PIN/patrón
        ),
      );

      if (isAuthenticated) {
        // Guardar timestamp de última autenticación exitosa
        await _secureStorage.setSecureString(
          'last_biometric_auth',
          DateTime.now().toIso8601String(),
        );

        return BiometricAuthResult(
          success: true,
          message: 'Autenticación exitosa',
        );
      } else {
        return BiometricAuthResult(
          success: false,
          error: BiometricAuthError.authenticationFailed,
          message: 'Autenticación fallida',
        );
      }
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        error: BiometricAuthError.unknown,
        message: 'Error desconocido: $e',
      );
    }
  }

  /// Autentica para operaciones sensibles (pagos, cambio de contraseña)
  Future<BiometricAuthResult> authenticateForSensitiveOperation({
    required String operation,
  }) async {
    final reason = _getReasonForOperation(operation);

    return await authenticate(
      reason: reason,
      sensitiveTransaction: true,
      stickyAuth: true,
    );
  }

  /// Obtiene el mensaje de razón según la operación
  String _getReasonForOperation(String operation) {
    switch (operation) {
      case 'payment':
        return 'Autoriza el pago con tu huella dactilar o Face ID';
      case 'change_password':
        return 'Confirma tu identidad para cambiar la contraseña';
      case 'view_sensitive_data':
        return 'Verifica tu identidad para ver información sensible';
      case 'delete_account':
        return 'Confirma que eres tú para eliminar tu cuenta';
      case 'export_data':
        return 'Autoriza la exportación de tus datos';
      case 'login':
        return 'Inicia sesión con tu huella dactilar o Face ID';
      default:
        return 'Por favor confirma tu identidad';
    }
  }

  /// Maneja excepciones de plataforma
  BiometricAuthResult _handlePlatformException(PlatformException e) {
    BiometricAuthError error;
    String message;

    switch (e.code) {
      case auth_error.notEnrolled:
        error = BiometricAuthError.notEnrolled;
        message =
            'No hay datos biométricos registrados. Configúralos en ajustes.';
        break;
      case auth_error.lockedOut:
        error = BiometricAuthError.lockedOut;
        message = 'Demasiados intentos fallidos. Intenta más tarde.';
        break;
      case auth_error.permanentlyLockedOut:
        error = BiometricAuthError.permanentlyLockedOut;
        message = 'Biometría bloqueada permanentemente. Usa tu PIN o patrón.';
        break;
      case auth_error.notAvailable:
        error = BiometricAuthError.notAvailable;
        message = 'Autenticación biométrica no disponible.';
        break;
      case auth_error.passcodeNotSet:
        error = BiometricAuthError.passcodeNotSet;
        message = 'No hay PIN o contraseña configurado en el dispositivo.';
        break;
      case auth_error.otherOperatingSystem:
        error = BiometricAuthError.unsupportedOS;
        message = 'Sistema operativo no soportado.';
        break;
      default:
        error = BiometricAuthError.unknown;
        message = e.message ?? 'Error desconocido';
    }

    return BiometricAuthResult(
      success: false,
      error: error,
      message: message,
    );
  }

  /// Verifica si se debe solicitar biometría nuevamente
  Future<bool> shouldRequestBiometric({
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    final lastAuth =
        await _secureStorage.getSecureString('last_biometric_auth');

    if (lastAuth == null) {
      return true; // Nunca se ha autenticado
    }

    try {
      final lastAuthTime = DateTime.parse(lastAuth);
      final timeSinceAuth = DateTime.now().difference(lastAuthTime);

      return timeSinceAuth > maxAge;
    } catch (e) {
      return true; // Error parseando fecha, solicitar autenticación
    }
  }

  /// Registra la biometría para el usuario actual
  Future<bool> enrollBiometric({
    required String userId,
  }) async {
    try {
      // Verificar disponibilidad
      if (!await isBiometricAvailable()) {
        return false;
      }

      // Autenticar primero
      final result = await authenticate(
        reason: 'Registra tu biometría para futuros inicios de sesión',
      );

      if (result.success) {
        // Guardar que el usuario tiene biometría habilitada
        await _secureStorage.setSecureString(
          'biometric_enabled_$userId',
          'true',
        );

        // Guardar timestamp de registro
        await _secureStorage.setSecureString(
          'biometric_enrolled_$userId',
          DateTime.now().toIso8601String(),
        );

        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('Error registrando biometría', e);
      }
      return false;
    }
  }

  /// Desactiva la biometría para el usuario
  Future<void> disableBiometric({
    required String userId,
  }) async {
    await _secureStorage.remove('biometric_enabled_$userId');
    await _secureStorage.remove('biometric_enrolled_$userId');
    await _secureStorage.remove('last_biometric_auth');
  }

  /// Verifica si el usuario tiene biometría habilitada
  Future<bool> isBiometricEnabledForUser(String userId) async {
    final enabled =
        await _secureStorage.getSecureString('biometric_enabled_$userId');
    return enabled == 'true';
  }

  /// Cancela la autenticación en progreso
  Future<bool> cancelAuthentication() async {
    try {
      return await _localAuth.stopAuthentication();
    } catch (e) {
      return false;
    }
  }

  /// Obtiene información sobre el estado de la biometría
  Map<String, dynamic> getBiometricStatus() {
    return {
      'isDeviceSupported': _isDeviceSupported,
      'isAvailable': _isAvailable,
      'availableTypes': _availableBiometrics.map((e) => e.toString()).toList(),
      'hasFaceId': _availableBiometrics.contains(BiometricType.face),
      'hasFingerprint':
          _availableBiometrics.contains(BiometricType.fingerprint),
      'hasIris': _availableBiometrics.contains(BiometricType.iris),
      'hasStrong': _availableBiometrics.contains(BiometricType.strong),
      'hasWeak': _availableBiometrics.contains(BiometricType.weak),
    };
  }
}

/// Resultado de autenticación biométrica
class BiometricAuthResult {
  final bool success;
  final BiometricAuthError? error;
  final String message;

  BiometricAuthResult({
    required this.success,
    this.error,
    required this.message,
  });
}

/// Tipos de error de autenticación biométrica
enum BiometricAuthError {
  notAvailable,
  notEnrolled,
  authenticationFailed,
  userCanceled,
  lockedOut,
  permanentlyLockedOut,
  passcodeNotSet,
  unsupportedOS,
  unknown,
}

/// Extension para facilitar el uso en widgets
extension BiometricAuthExtension on BiometricAuthService {
  /// Login rápido con biometría
  Future<bool> quickLogin() async {
    final result = await authenticate(
      reason: 'Inicia sesión rápidamente',
    );
    return result.success;
  }

  /// Autenticar con biometría (método wrapper)
  /// Método wrapper para compatibilidad con auth_provider
  Future<bool> authenticateWithBiometrics() async {
    try {
      AppLogger.info('BiometricAuth: Autenticando con biometría');

      // Usar el método authenticate existente
      final result = await authenticate(
        reason: 'Autenticación biométrica requerida para acceder',
      );

      AppLogger.info(
          'BiometricAuth: Resultado de autenticación: ${result.success}');
      return result.success;
    } catch (e) {
      AppLogger.error('Error en autenticación biométrica', e);
      return false;
    }
  }

  /// Autorización rápida para pagos
  Future<bool> authorizePayment() async {
    final result = await authenticateForSensitiveOperation(
      operation: 'payment',
    );
    return result.success;
  }
}

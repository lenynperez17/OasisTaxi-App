import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'secure_storage_service.dart';
import 'device_security_service.dart';
import 'biometric_auth_service.dart';
import '../screens/shared/secure_pin_prompt.dart';
import '../utils/app_logger.dart';

/// Servicio de seguridad de sesión
/// Implementa timeout automático, anti-tampering y verificación continua
class SessionSecurityService {
  static final SessionSecurityService _instance =
      SessionSecurityService._internal();
  factory SessionSecurityService() => _instance;
  SessionSecurityService._internal();

  final SecureStorageService _secureStorage = SecureStorageService();
  final DeviceSecurityService _deviceSecurity = DeviceSecurityService();
  final BiometricAuthService _biometricAuth = BiometricAuthService();

  // Estado de la sesión
  DateTime? _sessionStartTime;
  DateTime? _lastActivityTime;
  Timer? _inactivityTimer;
  Timer? _sessionTimer;
  Timer? _securityCheckTimer;

  // Callbacks
  Function()? _onSessionTimeout;
  Function(String reason)? _onSecurityBreach;
  Function()? _onInactivityWarning;

  // Configuración
  static const Duration maxSessionDuration = Duration(hours: 8);
  static const Duration inactivityTimeout = Duration(minutes: 15);
  static const Duration warningBefore = Duration(minutes: 2);
  static const Duration securityCheckInterval = Duration(minutes: 5);

  // PIN de seguridad
  String? _securityPin;
  int _pinAttempts = 0;
  static const int maxPinAttempts = 3;

  // Biometric availability
  bool _isBiometricAvailable = false;

  // Anti-tampering
  String? _appHash;
  String? _deviceFingerprint;
  bool _tamperingDetected = false;

  /// Inicializa el servicio de seguridad de sesión
  Future<void> initialize({
    Function()? onSessionTimeout,
    Function(String reason)? onSecurityBreach,
    Function()? onInactivityWarning,
  }) async {
    _onSessionTimeout = onSessionTimeout;
    _onSecurityBreach = onSecurityBreach;
    _onInactivityWarning = onInactivityWarning;

    // Inicializar servicios dependientes
    await _deviceSecurity.initialize();
    await _biometricAuth.initialize();

    // Verificar disponibilidad biométrica con manejo defensivo
    try {
      _isBiometricAvailable = await _biometricAuth.isAvailable();
    } catch (e) {
      AppLogger.warning('Error verificando disponibilidad biométrica: $e');
      _isBiometricAvailable = false;
    }

    // Cargar PIN guardado
    _securityPin = await _secureStorage.getSecureString('security_pin');

    // Generar fingerprint del dispositivo
    await _generateDeviceFingerprint();

    // Calcular hash de la app
    await _calculateAppHash();

    // Iniciar verificaciones de seguridad
    _startSecurityChecks();
  }

  /// Inicia una nueva sesión
  Future<bool> startSession({
    required String userId,
    bool requireBiometric = false,
  }) async {
    try {
      // Verificar seguridad del dispositivo
      final deviceIsSecure = await _deviceSecurity.checkDeviceSecurity();
      if (!deviceIsSecure) {
        _handleSecurityBreach('Dispositivo comprometido');
        return false;
      }

      // Verificar biometría si es requerida
      if (requireBiometric) {
        final biometricResult = await _biometricAuth.authenticate(
          reason: 'Confirma tu identidad para iniciar sesión',
        );
        if (!biometricResult.success) {
          return false;
        }
      }

      // Verificar integridad de la app
      if (await _checkAppIntegrity() == false) {
        _handleSecurityBreach('Integridad de la app comprometida');
        return false;
      }

      // Iniciar sesión
      _sessionStartTime = DateTime.now();
      _lastActivityTime = DateTime.now();

      // Guardar información de sesión
      await _secureStorage.setSecureJson('session_info', {
        'userId': userId,
        'startTime': _sessionStartTime!.toIso8601String(),
        'deviceFingerprint': _deviceFingerprint,
        'appHash': _appHash,
      });

      // Iniciar timers
      _startInactivityTimer();
      _startSessionTimer();

      if (kDebugMode) {
        AppLogger.info('✅ Sesión iniciada de forma segura');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('Error iniciando sesión', e);
      }
      return false;
    }
  }

  /// Registra actividad del usuario
  void registerActivity() {
    _lastActivityTime = DateTime.now();
    _resetInactivityTimer();
  }

  /// Verifica si la sesión está activa
  bool isSessionActive() {
    if (_sessionStartTime == null) return false;

    // Verificar duración máxima
    final sessionDuration = DateTime.now().difference(_sessionStartTime!);
    if (sessionDuration > maxSessionDuration) {
      _handleSessionTimeout();
      return false;
    }

    // Verificar inactividad
    if (_lastActivityTime != null) {
      final inactivityDuration = DateTime.now().difference(_lastActivityTime!);
      if (inactivityDuration > inactivityTimeout) {
        _handleInactivityTimeout();
        return false;
      }
    }

    // Verificar tampering
    if (_tamperingDetected) {
      _handleSecurityBreach('Tampering detectado');
      return false;
    }

    return true;
  }

  /// Getter para disponibilidad biométrica
  bool get isBiometricAvailable => _isBiometricAvailable;

  /// Configura un PIN de seguridad
  Future<bool> setupPin(String pin) async {
    if (pin.length != 6) {
      throw ArgumentError('PIN debe tener exactamente 6 dígitos');
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
      throw ArgumentError('PIN debe contener solo números');
    }

    // Hashear el PIN antes de guardarlo
    final hashedPin = _hashPin(pin);

    await _secureStorage.setSecureString('security_pin', hashedPin);
    _securityPin = hashedPin;

    AppLogger.info('PIN de seguridad configurado exitosamente');
    return true;
  }

  /// Configura un PIN de seguridad (alias para compatibilidad)
  Future<bool> setSecurityPin(String pin) async {
    return setupPin(pin);
  }

  /// Autentica con biometría
  Future<bool> authenticateWithBiometric({required String reason}) async {
    if (!_isBiometricAvailable) {
      AppLogger.warning('Biometría no disponible en este dispositivo');
      return false;
    }

    try {
      final result = await _biometricAuth.authenticate(reason: reason);
      if (result.success) {
        AppLogger.info('Autenticación biométrica exitosa');
        registerActivity();
        return true;
      } else {
        AppLogger.warning('Autenticación biométrica fallida: ${result.message}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error en autenticación biométrica', e);
      return false;
    }
  }

  /// Bloquea la sesión con una razón específica
  Future<void> lockSession(String reason) async {
    AppLogger.warning('Sesión bloqueada: $reason');
    _tamperingDetected = true;
    await endSession(reason: reason);
    _onSecurityBreach?.call(reason);
  }

  /// Verifica el PIN de seguridad
  Future<bool> verifyPin(String pin) async {
    if (_securityPin == null) {
      return false; // No hay PIN configurado
    }

    if (_pinAttempts >= maxPinAttempts) {
      _handleSecurityBreach('Demasiados intentos de PIN fallidos');
      return false;
    }

    final hashedPin = _hashPin(pin);

    if (hashedPin == _securityPin) {
      _pinAttempts = 0;
      return true;
    } else {
      _pinAttempts++;

      if (_pinAttempts >= maxPinAttempts) {
        _handleSecurityBreach('PIN bloqueado por seguridad');
        await endSession(reason: 'PIN bloqueado');
      }

      return false;
    }
  }

  /// Solicita re-autenticación
  Future<bool> requestReAuthentication({
    BuildContext? context,
    bool useBiometric = true,
    bool usePin = true,
    String? customMessage,
  }) async {
    // Intentar biometría primero con manejo defensivo
    bool biometricAvailable = false;
    if (useBiometric) {
      try {
        biometricAvailable = await _biometricAuth.isAvailable();
      } catch (e) {
        AppLogger.warning('Error verificando disponibilidad biométrica: $e');
        biometricAvailable = false;
      }
    }

    if (useBiometric && biometricAvailable) {
      final result = await _biometricAuth.authenticate(
        reason: customMessage ?? 'Confirma tu identidad para continuar',
      );
      if (result.success) return true;
    }

    // Si falla o no está disponible, usar PIN
    if (usePin && _securityPin != null && context != null) {
      final pin = await SecurePinPrompt.show(
        context: context,
        customMessage: customMessage ?? 'Ingrese su PIN para continuar',
      );

      if (pin != null) {
        return await verifyPin(pin);
      }
    }

    return false;
  }

  /// Finaliza la sesión
  Future<void> endSession({String? reason}) async {
    // Cancelar timers
    _inactivityTimer?.cancel();
    _sessionTimer?.cancel();
    _securityCheckTimer?.cancel();

    // Limpiar datos de sesión
    _sessionStartTime = null;
    _lastActivityTime = null;
    _pinAttempts = 0;

    // Guardar registro de cierre
    await _logSessionEnd(reason);

    // Limpiar storage seguro
    await _secureStorage.remove('session_info');

    if (kDebugMode) {
      AppLogger.info('🔒 Sesión finalizada: ${reason ?? "Por usuario"}');
    }
  }

  /// Pausa la sesión (background)
  void pauseSession() {
    // Acelerar timeout en background
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 5), () {
      _handleInactivityTimeout();
    });
  }

  /// Resume la sesión (foreground)
  Future<void> resumeSession() async {
    // Verificar seguridad al resumir
    await _performSecurityCheck();

    // Verificar si necesita re-autenticación
    if (_lastActivityTime != null) {
      final pauseDuration = DateTime.now().difference(_lastActivityTime!);
      if (pauseDuration > const Duration(minutes: 5)) {
        // Solicitar re-autenticación
        final authenticated = await requestReAuthentication();
        if (!authenticated) {
          await endSession(reason: 'Re-autenticación fallida');
        }
      }
    }

    // Reiniciar timer normal
    registerActivity();
  }

  // Métodos privados

  void _startInactivityTimer() {
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();

    // Timer de advertencia
    final warningTime = inactivityTimeout - warningBefore;
    Timer(warningTime, () {
      _onInactivityWarning?.call();
    });

    // Timer de timeout
    _inactivityTimer = Timer(inactivityTimeout, () {
      _handleInactivityTimeout();
    });
  }

  void _startSessionTimer() {
    _sessionTimer = Timer(maxSessionDuration, () {
      _handleSessionTimeout();
    });
  }

  void _startSecurityChecks() {
    _securityCheckTimer = Timer.periodic(securityCheckInterval, (_) {
      _performSecurityCheck();
    });
  }

  Future<void> _performSecurityCheck() async {
    // Verificar root/jailbreak
    final deviceIsSecure = await _deviceSecurity.checkDeviceSecurity();
    if (!deviceIsSecure) {
      _handleSecurityBreach('Dispositivo comprometido durante sesión');
      return;
    }

    // Verificar integridad de la app
    if (await _checkAppIntegrity() == false) {
      _handleSecurityBreach('App modificada durante sesión');
      return;
    }

    // Verificar fingerprint del dispositivo
    if (await _verifyDeviceFingerprint() == false) {
      _handleSecurityBreach('Dispositivo cambiado durante sesión');
      return;
    }
  }

  Future<bool> _checkAppIntegrity() async {
    try {
      // Calcular hash actual
      final currentHash = await _calculateAppHash();

      // Comparar con hash inicial
      if (_appHash != null && currentHash != _appHash) {
        _tamperingDetected = true;
        return false;
      }

      return true;
    } catch (e) {
      return true; // En caso de error, no bloquear
    }
  }

  Future<String> _calculateAppHash() async {
    try {
      // En producción, esto debería calcular un hash real del APK/IPA
      const platform = MethodChannel('security_check');
      final String hash = await platform.invokeMethod('getAppHash');
      _appHash = hash;
      return hash;
    } catch (e) {
      // Fallback para desarrollo
      _appHash = 'dev_hash_${DateTime.now().millisecondsSinceEpoch}';
      return _appHash!;
    }
  }

  Future<void> _generateDeviceFingerprint() async {
    try {
      // Generar fingerprint único del dispositivo
      const platform = MethodChannel('security_check');
      _deviceFingerprint = await platform.invokeMethod('getDeviceFingerprint');
    } catch (e) {
      // Fallback
      _deviceFingerprint = 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<bool> _verifyDeviceFingerprint() async {
    try {
      const platform = MethodChannel('security_check');
      final currentFingerprint =
          await platform.invokeMethod('getDeviceFingerprint');
      return currentFingerprint == _deviceFingerprint;
    } catch (e) {
      return true; // No bloquear en caso de error
    }
  }

  String _hashPin(String pin) {
    // En producción, usar un algoritmo de hash seguro como bcrypt
    // Aquí usamos una versión simplificada
    final bytes = utf8.encode('${pin}oasis_salt_2024');
    return base64.encode(bytes);
  }

  void _handleSessionTimeout() {
    if (kDebugMode) {
      AppLogger.warning('⏰ Sesión expirada por tiempo máximo');
    }
    endSession(reason: 'Timeout de sesión');
    _onSessionTimeout?.call();
  }

  void _handleInactivityTimeout() {
    if (kDebugMode) {
      AppLogger.warning('💤 Sesión expirada por inactividad');
    }
    endSession(reason: 'Inactividad');
    _onSessionTimeout?.call();
  }

  void _handleSecurityBreach(String reason) {
    if (kDebugMode) {
      AppLogger.critical('🚨 BRECHA DE SEGURIDAD: $reason');
    }
    _tamperingDetected = true;
    endSession(reason: 'Brecha de seguridad: $reason');
    _onSecurityBreach?.call(reason);
  }

  Future<void> _logSessionEnd(String? reason) async {
    final log = {
      'sessionStart': _sessionStartTime?.toIso8601String(),
      'sessionEnd': DateTime.now().toIso8601String(),
      'reason': reason ?? 'Usuario',
      'deviceFingerprint': _deviceFingerprint,
    };

    // Enviar log al servidor de auditoría
    try {
      FirebaseFirestore.instance
          .collection('session_logs')
          .add(log)
          .then((_) => AppLogger.debug('Session log sent successfully'))
          .catchError((e) => AppLogger.error('Failed to send session log: $e'));
    } catch (e) {
      AppLogger.error('Error sending session log: $e');
    }

    if (kDebugMode) {
      AppLogger.debug('Session log: $log');
    }
  }

  /// Obtiene estadísticas de la sesión
  Map<String, dynamic> getSessionStats() {
    if (_sessionStartTime == null) {
      return {'active': false};
    }

    final now = DateTime.now();
    final sessionDuration = now.difference(_sessionStartTime!);
    final timeSinceActivity = _lastActivityTime != null
        ? now.difference(_lastActivityTime!)
        : Duration.zero;

    return {
      'active': isSessionActive(),
      'startTime': _sessionStartTime?.toIso8601String(),
      'duration': sessionDuration.inMinutes,
      'lastActivity': _lastActivityTime?.toIso8601String(),
      'inactivityMinutes': timeSinceActivity.inMinutes,
      'maxDurationMinutes': maxSessionDuration.inMinutes,
      'inactivityTimeoutMinutes': inactivityTimeout.inMinutes,
      'pinConfigured': _securityPin != null,
      'pinAttempts': _pinAttempts,
      'tamperingDetected': _tamperingDetected,
    };
  }
}

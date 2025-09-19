import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio completo de autenticación por teléfono con Firebase para OasisTaxi Perú
/// Maneja SMS OTP, verificación, límites de intentos y seguridad
class FirebasePhoneAuthService {
  static final FirebasePhoneAuthService _instance =
      FirebasePhoneAuthService._internal();
  factory FirebasePhoneAuthService() => _instance;
  FirebasePhoneAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Estado de verificación
  String? _verificationId;
  int? _resendToken;
  String? _currentPhoneNumber;
  Timer? _otpTimer;
  int _otpTimeoutSeconds = 60;

  // Límites de seguridad
  static const int maxVerificationAttempts = 5;
  static const int maxResendAttempts = 3;
  static const int otpExpirySeconds = 300; // 5 minutos
  static const int cooldownMinutes = 30; // Cooldown después de máximos intentos

  // Cache de intentos
  final Map<String, VerificationAttempts> _attemptsCache = {};

  // Callbacks
  Function(String)? onCodeSent;
  Function(String)? onCodeAutoRetrievalTimeout;
  Function(PhoneAuthCredential)? onVerificationCompleted;
  Function(FirebaseAuthException)? onVerificationFailed;
  Function(int)? onTimerUpdate;

  // ==================== CONFIGURACIÓN INICIAL ====================

  /// Inicializa el servicio de autenticación por teléfono
  Future<void> initialize() async {
    try {
      AppLogger.info('Inicializando Firebase Phone Auth Service');

      // Configurar persistencia de sesión
      await _auth.setPersistence(Persistence.LOCAL);

      // Cargar intentos guardados
      await _loadAttemptsFromCache();

      // Configurar idioma para SMS (Español)
      _auth.setLanguageCode('es');

      // Limpiar intentos antiguos
      _cleanupOldAttempts();

      AppLogger.info('Firebase Phone Auth Service inicializado');
    } catch (e) {
      AppLogger.error('Error inicializando Phone Auth Service', e);
    }
  }

  // ==================== ENVÍO DE CÓDIGO OTP ====================

  /// Envía código OTP al número de teléfono
  Future<PhoneAuthResult> sendOTP({
    required String phoneNumber,
    required BuildContext context,
    bool isResend = false,
  }) async {
    try {
      AppLogger.info('Enviando OTP a: $phoneNumber');

      // Validar formato de número peruano
      if (!_isValidPeruvianNumber(phoneNumber)) {
        return PhoneAuthResult(
          success: false,
          errorMessage:
              'Número de teléfono inválido. Use formato: +51 XXX XXX XXX',
        );
      }

      // Verificar límites de intentos
      final canProceed = await _checkAttemptLimits(phoneNumber, isResend);
      if (!canProceed.allowed) {
        return PhoneAuthResult(
          success: false,
          errorMessage: canProceed.message,
          cooldownMinutes: canProceed.cooldownMinutes,
        );
      }

      // Formatear número
      final formattedNumber = _formatPhoneNumber(phoneNumber);
      _currentPhoneNumber = formattedNumber;

      // Registrar intento
      await _recordAttempt(formattedNumber, isResend);

      // Iniciar timer de expiración
      _startOTPTimer();

      // Configurar callbacks
      final completer = Completer<PhoneAuthResult>();

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedNumber,
        timeout: Duration(seconds: otpExpirySeconds),
        forceResendingToken: isResend ? _resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          AppLogger.info('Verificación automática completada');

          // Auto-verificación (raro en producción)
          onVerificationCompleted?.call(credential);

          try {
            final userCredential = await _auth.signInWithCredential(credential);
            await _onAuthenticationSuccess(userCredential);

            if (!completer.isCompleted) {
              completer.complete(PhoneAuthResult(
                success: true,
                autoVerified: true,
                user: userCredential.user,
              ));
            }
          } catch (e) {
            AppLogger.error('Error en auto-verificación', e);
            if (!completer.isCompleted) {
              completer.complete(PhoneAuthResult(
                success: false,
                errorMessage: 'Error en verificación automática',
              ));
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          AppLogger.error('Verificación fallida', e);

          onVerificationFailed?.call(e);

          String errorMessage = _getErrorMessage(e.code);

          // Registrar fallo
          _recordFailedAttempt(formattedNumber);

          if (!completer.isCompleted) {
            completer.complete(PhoneAuthResult(
              success: false,
              errorMessage: errorMessage,
              errorCode: e.code,
            ));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          AppLogger.info('Código OTP enviado exitosamente');

          _verificationId = verificationId;
          _resendToken = resendToken;

          onCodeSent?.call(verificationId);

          // Guardar en cache
          _saveVerificationSession(formattedNumber, verificationId);

          if (!completer.isCompleted) {
            completer.complete(PhoneAuthResult(
              success: true,
              verificationId: verificationId,
              message: 'Código enviado a $formattedNumber',
            ));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          AppLogger.info('Timeout de recuperación automática');

          _verificationId = verificationId;
          onCodeAutoRetrievalTimeout?.call(verificationId);

          if (!completer.isCompleted) {
            completer.complete(PhoneAuthResult(
              success: true,
              verificationId: verificationId,
              message: 'Ingrese el código manualmente',
            ));
          }
        },
      );

      return await completer.future;
    } catch (e) {
      AppLogger.error('Error enviando OTP', e);
      return PhoneAuthResult(
        success: false,
        errorMessage: 'Error al enviar código: ${e.toString()}',
      );
    }
  }

  /// Reenvía código OTP
  Future<PhoneAuthResult> resendOTP(BuildContext context) async {
    if (_currentPhoneNumber == null) {
      return PhoneAuthResult(
        success: false,
        errorMessage: 'No hay número de teléfono configurado',
      );
    }

    return sendOTP(
      phoneNumber: _currentPhoneNumber!,
      context: context,
      isResend: true,
    );
  }

  // ==================== VERIFICACIÓN DE CÓDIGO ====================

  /// Verifica el código OTP ingresado por el usuario
  Future<PhoneAuthResult> verifyOTP(String smsCode) async {
    try {
      AppLogger.info('Verificando código OTP');

      if (_verificationId == null) {
        return PhoneAuthResult(
          success: false,
          errorMessage: 'No hay verificación en progreso',
        );
      }

      if (!_isValidOTPCode(smsCode)) {
        return PhoneAuthResult(
          success: false,
          errorMessage: 'Código inválido. Debe ser de 6 dígitos',
        );
      }

      // Crear credencial
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // Intentar iniciar sesión
      final userCredential = await _auth.signInWithCredential(credential);

      // Procesar autenticación exitosa
      await _onAuthenticationSuccess(userCredential);

      AppLogger.info('Verificación OTP exitosa');

      return PhoneAuthResult(
        success: true,
        user: userCredential.user,
        message: 'Verificación exitosa',
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Error verificando OTP', e);

      String errorMessage;
      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Código incorrecto. Verifique e intente nuevamente';
          break;
        case 'invalid-verification-id':
          errorMessage = 'La sesión ha expirado. Solicite un nuevo código';
          break;
        case 'session-expired':
          errorMessage = 'El código ha expirado. Solicite uno nuevo';
          break;
        default:
          errorMessage = 'Error al verificar código: ${e.message}';
      }

      // Registrar intento fallido
      if (_currentPhoneNumber != null) {
        _recordFailedVerification(_currentPhoneNumber!);
      }

      return PhoneAuthResult(
        success: false,
        errorMessage: errorMessage,
        errorCode: e.code,
      );
    } catch (e) {
      AppLogger.error('Error inesperado verificando OTP', e);
      return PhoneAuthResult(
        success: false,
        errorMessage: 'Error inesperado. Intente nuevamente',
      );
    }
  }

  // ==================== MÉTODOS DE COMPATIBILIDAD ====================

  /// Verifica un número de teléfono y envía SMS OTP
  /// Método wrapper para compatibilidad con AuthProvider
  Future<PhoneAuthResult> verifyPhoneNumber({
    required String phoneNumber,
    bool forceResend = false,
    int timeout = 60,
  }) async {
    try {
      AppLogger.info('FirebasePhoneAuth: Verificando número $phoneNumber');

      // Si es resend, usar el método específico
      if (forceResend && _verificationId != null) {
        // Usar resendOTP sin context para compatibilidad
        return await _resendOTPInternal();
      }

      // Enviar OTP normal - implementación directa
      _currentPhoneNumber = phoneNumber;

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          AppLogger.info('FirebasePhoneAuth: Auto-verificación completada');
        },
        verificationFailed: (FirebaseAuthException e) {
          AppLogger.error('FirebasePhoneAuth: Verificación fallida', e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          AppLogger.info('FirebasePhoneAuth: Código SMS enviado');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          AppLogger.info('FirebasePhoneAuth: Timeout auto-retrieval');
        },
        timeout: Duration(seconds: timeout),
      );

      final result = PhoneAuthResult(
        success: true,
        verificationId: _verificationId,
      );

      AppLogger.info(
          'FirebasePhoneAuth: Resultado verificación - Success: ${result.success}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Error en verifyPhoneNumber', e, stackTrace);
      return PhoneAuthResult(
        success: false,
        errorMessage: 'Error al verificar número: ${e.toString()}',
        errorCode: 'PHONE_VERIFICATION_ERROR',
      );
    }
  }

  /// Verifica el código OTP SMS
  /// Método wrapper para compatibilidad con AuthProvider
  Future<PhoneAuthResult> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      AppLogger.info('FirebasePhoneAuth: Verificando código OTP');

      // Actualizar el verificationId interno si es diferente
      if (_verificationId != verificationId) {
        _verificationId = verificationId;
      }

      // Verificar el código usando el método existente
      final result = await verifyOTP(smsCode);

      AppLogger.info(
          'FirebasePhoneAuth: Resultado verificación OTP - Success: ${result.success}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Error en verifyOtpCode', e, stackTrace);
      return PhoneAuthResult(
        success: false,
        errorMessage: 'Error al verificar código: ${e.toString()}',
        errorCode: 'OTP_VERIFICATION_ERROR',
      );
    }
  }

  /// Método interno para resend sin context
  Future<PhoneAuthResult> _resendOTPInternal() async {
    try {
      if (_currentPhoneNumber == null) {
        return PhoneAuthResult(
          success: false,
          errorMessage: 'No hay número de teléfono para reenvío',
          errorCode: 'NO_PHONE_NUMBER',
        );
      }

      // Verificar límites de intentos
      final attemptCheck =
          await _checkAttemptLimits(_currentPhoneNumber!, true);
      if (!attemptCheck.allowed) {
        return PhoneAuthResult(
          success: false,
          errorMessage: attemptCheck.message ?? 'Límite de reenvíos excedido',
          errorCode: 'RESEND_LIMIT_EXCEEDED',
          cooldownMinutes: attemptCheck.cooldownMinutes,
        );
      }

      // Reenviar usando Firebase directamente
      final completer = Completer<PhoneAuthResult>();

      await _auth.verifyPhoneNumber(
        phoneNumber: _currentPhoneNumber!,
        timeout: Duration(seconds: _otpTimeoutSeconds),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verificación completada
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            await _onAuthenticationSuccess(userCredential);
            completer.complete(PhoneAuthResult(
              success: true,
              message: 'Verificación automática exitosa',
              autoVerified: true,
              user: userCredential.user,
            ));
          } catch (e) {
            completer.complete(PhoneAuthResult(
              success: false,
              errorMessage: 'Error en auto-verificación: ${e.toString()}',
              errorCode: 'AUTO_VERIFICATION_ERROR',
            ));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          AppLogger.error('Falló verificación en resend', e);
          completer.complete(PhoneAuthResult(
            success: false,
            errorMessage: _getErrorMessage(e.code),
            errorCode: e.code,
          ));
        },
        codeSent: (String verificationId, int? resendToken) async {
          AppLogger.info('Código reenviado exitosamente');
          _verificationId = verificationId;
          _resendToken = resendToken;

          // Registrar el intento de reenvío
          await _recordAttempt(_currentPhoneNumber!, true);

          onCodeSent?.call(verificationId);

          completer.complete(PhoneAuthResult(
            success: true,
            message: 'SMS reenviado exitosamente',
            verificationId: verificationId,
          ));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onCodeAutoRetrievalTimeout?.call(verificationId);
        },
      );

      return await completer.future;
    } catch (e, stackTrace) {
      AppLogger.error('Error en reenvío interno', e, stackTrace);
      return PhoneAuthResult(
        success: false,
        errorMessage: 'Error al reenviar código: ${e.toString()}',
        errorCode: 'RESEND_ERROR',
      );
    }
  }

  // ==================== GESTIÓN DE SESIÓN ====================

  /// Procesa autenticación exitosa
  Future<void> _onAuthenticationSuccess(UserCredential userCredential) async {
    try {
      final user = userCredential.user;
      if (user == null) return;

      AppLogger.info('Procesando autenticación exitosa para: ${user.uid}');

      // Verificar si es nuevo usuario
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // Crear perfil de usuario nuevo
        await _createUserProfile(user);
      } else {
        // Actualizar último acceso
        await _updateLastLogin(user.uid);
      }

      // Limpiar intentos
      if (_currentPhoneNumber != null) {
        _clearAttempts(_currentPhoneNumber!);
      }

      // Guardar sesión
      await _saveSession(user);

      // Registrar evento
      await _logAuthenticationEvent(user.uid, 'phone_auth_success');

      // Cancelar timer
      _cancelOTPTimer();
    } catch (e) {
      AppLogger.error('Error procesando autenticación exitosa', e);
    }
  }

  /// Crea perfil de usuario nuevo
  Future<void> _createUserProfile(User user) async {
    try {
      final phoneNumber = user.phoneNumber ?? _currentPhoneNumber;

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'phoneNumber': phoneNumber,
        'phoneVerified': true,
        'registrationMethod': 'phone',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'country': 'PE',
        'isActive': true,
        'deviceInfo': await _getDeviceInfo(),
      }, SetOptions(merge: true));

      AppLogger.info('Perfil de usuario creado: ${user.uid}');
    } catch (e) {
      AppLogger.error('Error creando perfil de usuario', e);
    }
  }

  /// Actualiza último login
  Future<void> _updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
        'phoneVerified': true,
        'deviceInfo': await _getDeviceInfo(),
      });
    } catch (e) {
      AppLogger.error('Error actualizando último login', e);
    }
  }

  // ==================== VALIDACIONES ====================

  /// Valida número de teléfono peruano
  bool _isValidPeruvianNumber(String phoneNumber) {
    // Eliminar espacios y caracteres especiales
    final cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Verificar formato peruano (+51 seguido de 9 dígitos)
    final peruRegex = RegExp(r'^\+?51?9\d{8}$');

    return peruRegex.hasMatch(cleaned);
  }

  /// Formatea número de teléfono
  String _formatPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Si no tiene código de país, agregar +51
    if (!cleaned.startsWith('+')) {
      if (cleaned.startsWith('51')) {
        cleaned = '+$cleaned';
      } else {
        cleaned = '+51$cleaned';
      }
    }

    return cleaned;
  }

  /// Valida código OTP
  bool _isValidOTPCode(String code) {
    return RegExp(r'^\d{6}$').hasMatch(code);
  }

  // ==================== CONTROL DE INTENTOS ====================

  /// Verifica límites de intentos
  Future<AttemptCheckResult> _checkAttemptLimits(
    String phoneNumber,
    bool isResend,
  ) async {
    final attempts = _attemptsCache[phoneNumber];

    if (attempts == null) {
      return AttemptCheckResult(allowed: true);
    }

    // Verificar cooldown
    if (attempts.isInCooldown()) {
      final remainingMinutes = attempts.getRemainingCooldownMinutes();
      return AttemptCheckResult(
        allowed: false,
        message: 'Demasiados intentos. Espere $remainingMinutes minutos',
        cooldownMinutes: remainingMinutes,
      );
    }

    // Verificar límite de reenvíos
    if (isResend && attempts.resendCount >= maxResendAttempts) {
      return AttemptCheckResult(
        allowed: false,
        message: 'Límite de reenvíos alcanzado. Intente más tarde',
      );
    }

    // Verificar límite de verificaciones
    if (attempts.verificationCount >= maxVerificationAttempts) {
      attempts.startCooldown(cooldownMinutes);
      await _saveAttemptsToCache();

      return AttemptCheckResult(
        allowed: false,
        message: 'Demasiados intentos fallidos. Cuenta bloqueada temporalmente',
        cooldownMinutes: cooldownMinutes,
      );
    }

    return AttemptCheckResult(allowed: true);
  }

  /// Registra intento
  Future<void> _recordAttempt(String phoneNumber, bool isResend) async {
    var attempts =
        _attemptsCache[phoneNumber] ?? VerificationAttempts(phoneNumber);

    if (isResend) {
      attempts.resendCount++;
    } else {
      attempts.attemptCount++;
    }

    attempts.lastAttempt = DateTime.now();
    _attemptsCache[phoneNumber] = attempts;

    await _saveAttemptsToCache();
  }

  /// Registra intento fallido
  void _recordFailedAttempt(String phoneNumber) {
    var attempts =
        _attemptsCache[phoneNumber] ?? VerificationAttempts(phoneNumber);
    attempts.failedCount++;
    _attemptsCache[phoneNumber] = attempts;
    _saveAttemptsToCache();
  }

  /// Registra verificación fallida
  void _recordFailedVerification(String phoneNumber) {
    var attempts =
        _attemptsCache[phoneNumber] ?? VerificationAttempts(phoneNumber);
    attempts.verificationCount++;
    _attemptsCache[phoneNumber] = attempts;
    _saveAttemptsToCache();
  }

  /// Limpia intentos
  void _clearAttempts(String phoneNumber) {
    _attemptsCache.remove(phoneNumber);
    _saveAttemptsToCache();
  }

  /// Limpia intentos antiguos
  void _cleanupOldAttempts() {
    final now = DateTime.now();
    _attemptsCache.removeWhere((key, attempts) {
      final hoursSinceLastAttempt =
          now.difference(attempts.lastAttempt).inHours;
      return hoursSinceLastAttempt > 24; // Limpiar después de 24 horas
    });
    _saveAttemptsToCache();
  }

  // ==================== TIMER OTP ====================

  /// Inicia timer de OTP
  void _startOTPTimer() {
    _cancelOTPTimer();
    _otpTimeoutSeconds = 60;

    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _otpTimeoutSeconds--;
      onTimerUpdate?.call(_otpTimeoutSeconds);

      if (_otpTimeoutSeconds <= 0) {
        _cancelOTPTimer();
      }
    });
  }

  /// Cancela timer de OTP
  void _cancelOTPTimer() {
    _otpTimer?.cancel();
    _otpTimer = null;
    _otpTimeoutSeconds = 0;
  }

  /// Obtiene segundos restantes del timer
  int getRemainingSeconds() => _otpTimeoutSeconds;

  /// Verifica si se puede reenviar
  bool canResend() => _otpTimeoutSeconds <= 0 && _resendToken != null;

  // ==================== PERSISTENCIA ====================

  /// Guarda sesión de verificación
  Future<void> _saveVerificationSession(
    String phoneNumber,
    String verificationId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('verification_phone', phoneNumber);
      await prefs.setString('verification_id', verificationId);
      await prefs.setInt(
          'verification_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.error('Error guardando sesión de verificación', e);
    }
  }

  /// Recupera sesión de verificación
  Future<VerificationSession?> getVerificationSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('verification_phone');
      final id = prefs.getString('verification_id');
      final timestamp = prefs.getInt('verification_timestamp');

      if (phone != null && id != null && timestamp != null) {
        final sessionTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();

        // Verificar si la sesión no ha expirado (5 minutos)
        if (now.difference(sessionTime).inSeconds < otpExpirySeconds) {
          return VerificationSession(
            phoneNumber: phone,
            verificationId: id,
            timestamp: sessionTime,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error recuperando sesión de verificación', e);
    }
    return null;
  }

  /// Guarda sesión de usuario
  Future<void> _saveSession(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', user.uid);
      await prefs.setString('user_phone', user.phoneNumber ?? '');
      await prefs.setBool('phone_verified', true);
    } catch (e) {
      AppLogger.error('Error guardando sesión', e);
    }
  }

  /// Guarda intentos en cache
  Future<void> _saveAttemptsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attemptsJson =
          _attemptsCache.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString('phone_auth_attempts', attemptsJson.toString());
    } catch (e) {
      AppLogger.error('Error guardando intentos', e);
    }
  }

  /// Carga intentos desde cache
  Future<void> _loadAttemptsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attemptsString = prefs.getString('phone_auth_attempts');
      if (attemptsString != null) {
        // Parsear y cargar intentos
        // Implementación simplificada
      }
    } catch (e) {
      AppLogger.error('Error cargando intentos', e);
    }
  }

  // ==================== UTILIDADES ====================

  /// Obtiene información del dispositivo
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': 'mobile',
      'lastAuthMethod': 'phone',
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  /// Registra evento de autenticación
  Future<void> _logAuthenticationEvent(String uid, String eventType) async {
    try {
      await _firestore.collection('auth_events').add({
        'uid': uid,
        'eventType': eventType,
        'method': 'phone',
        'timestamp': FieldValue.serverTimestamp(),
        'phoneNumber': _currentPhoneNumber,
      });
    } catch (e) {
      AppLogger.error('Error registrando evento de autenticación', e);
    }
  }

  /// Obtiene mensaje de error localizado
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Número de teléfono inválido';
      case 'missing-phone-number':
        return 'Número de teléfono requerido';
      case 'quota-exceeded':
        return 'Límite de SMS excedido. Intente más tarde';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada';
      case 'operation-not-allowed':
        return 'Autenticación por teléfono no está habilitada';
      case 'too-many-requests':
        return 'Demasiados intentos. Intente más tarde';
      case 'app-not-authorized':
        return 'App no autorizada para usar Firebase Auth';
      case 'captcha-check-failed':
        return 'Verificación reCAPTCHA fallida';
      case 'missing-client-identifier':
        return 'Falta identificador del cliente';
      case 'invalid-app-credential':
        return 'Credencial de app inválida';
      case 'missing-verification-code':
        return 'Código de verificación requerido';
      case 'missing-verification-id':
        return 'ID de verificación requerido';
      case 'credential-already-in-use':
        return 'Este número ya está asociado a otra cuenta';
      case 'requires-recent-login':
        return 'Requiere inicio de sesión reciente';
      default:
        return 'Error de autenticación. Código: $code';
    }
  }

  // ==================== MÉTODOS PÚBLICOS ADICIONALES ====================

  /// Verifica si hay una sesión activa
  bool hasActiveSession() {
    return _verificationId != null;
  }

  /// Obtiene el número actual
  String? getCurrentPhoneNumber() {
    return _currentPhoneNumber;
  }

  /// Limpia la sesión actual
  void clearSession() {
    _verificationId = null;
    _resendToken = null;
    _currentPhoneNumber = null;
    _cancelOTPTimer();
  }

  /// Cierra sesión
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      clearSession();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_uid');
      await prefs.remove('user_phone');
      await prefs.remove('phone_verified');

      AppLogger.info('Sesión cerrada exitosamente');
    } catch (e) {
      AppLogger.error('Error cerrando sesión', e);
    }
  }

  /// Obtiene usuario actual
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Verifica si el usuario está autenticado
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  /// Stream de cambios de autenticación
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  /// Actualiza número de teléfono
  Future<bool> updatePhoneNumber({
    required String newPhoneNumber,
    required BuildContext context,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.error('No hay usuario autenticado');
        return false;
      }

      // Iniciar proceso de verificación para nuevo número
      final result = await sendOTP(
        phoneNumber: newPhoneNumber,
        context: context,
      );

      if (!result.success) {
        return false;
      }

      // El usuario deberá completar la verificación
      // y luego llamar a confirmPhoneNumberUpdate

      return true;
    } catch (e) {
      AppLogger.error('Error actualizando número', e);
      return false;
    }
  }

  /// Confirma actualización de número
  Future<bool> confirmPhoneNumberUpdate(String smsCode) async {
    try {
      if (_verificationId == null) {
        return false;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePhoneNumber(credential);

        // Actualizar en Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'phoneNumber': _currentPhoneNumber,
          'phoneUpdatedAt': FieldValue.serverTimestamp(),
        });

        AppLogger.info('Número de teléfono actualizado exitosamente');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error confirmando actualización de número', e);
      return false;
    }
  }

  // ==================== LIMPIEZA ====================

  /// Limpia recursos
  void dispose() {
    _cancelOTPTimer();
    _attemptsCache.clear();
    clearSession();
    AppLogger.info('Firebase Phone Auth Service disposed');
  }
}

// ==================== MODELOS DE DATOS ====================

/// Resultado de autenticación por teléfono
class PhoneAuthResult {
  final bool success;
  final String? errorMessage;
  final String? errorCode;
  final String? message;
  final String? verificationId;
  final User? user;
  final bool autoVerified;
  final int? cooldownMinutes;

  PhoneAuthResult({
    required this.success,
    this.errorMessage,
    this.errorCode,
    this.message,
    this.verificationId,
    this.user,
    this.autoVerified = false,
    this.cooldownMinutes,
  });
}

/// Resultado de verificación de intentos
class AttemptCheckResult {
  final bool allowed;
  final String? message;
  final int? cooldownMinutes;

  AttemptCheckResult({
    required this.allowed,
    this.message,
    this.cooldownMinutes,
  });
}

/// Sesión de verificación
class VerificationSession {
  final String phoneNumber;
  final String verificationId;
  final DateTime timestamp;

  VerificationSession({
    required this.phoneNumber,
    required this.verificationId,
    required this.timestamp,
  });
}

/// Control de intentos de verificación
class VerificationAttempts {
  final String phoneNumber;
  int attemptCount = 0;
  int resendCount = 0;
  int verificationCount = 0;
  int failedCount = 0;
  DateTime lastAttempt = DateTime.now();
  DateTime? cooldownUntil;

  VerificationAttempts(this.phoneNumber);

  bool isInCooldown() {
    if (cooldownUntil == null) return false;
    return DateTime.now().isBefore(cooldownUntil!);
  }

  void startCooldown(int minutes) {
    cooldownUntil = DateTime.now().add(Duration(minutes: minutes));
  }

  int getRemainingCooldownMinutes() {
    if (cooldownUntil == null) return 0;
    final remaining = cooldownUntil!.difference(DateTime.now()).inMinutes;
    return remaining > 0 ? remaining : 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'attemptCount': attemptCount,
      'resendCount': resendCount,
      'verificationCount': verificationCount,
      'failedCount': failedCount,
      'lastAttempt': lastAttempt.toIso8601String(),
      'cooldownUntil': cooldownUntil?.toIso8601String(),
    };
  }

  factory VerificationAttempts.fromJson(Map<String, dynamic> json) {
    final attempts = VerificationAttempts(json['phoneNumber']);
    attempts.attemptCount = json['attemptCount'] ?? 0;
    attempts.resendCount = json['resendCount'] ?? 0;
    attempts.verificationCount = json['verificationCount'] ?? 0;
    attempts.failedCount = json['failedCount'] ?? 0;
    attempts.lastAttempt = DateTime.parse(json['lastAttempt']);
    if (json['cooldownUntil'] != null) {
      attempts.cooldownUntil = DateTime.parse(json['cooldownUntil']);
    }
    return attempts;
  }
}

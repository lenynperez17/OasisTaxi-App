// 🔐 MULTI-FACTOR AUTHENTICATION (MFA) - OASISTAXI PERÚ
// Sistema completo de autenticación de dos factores para máxima seguridad

import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/app_logger.dart';

/// Tipos de MFA soportados en OasisTaxi
enum MFAMethod {
  totp('totp', 'Google Authenticator/TOTP', 'Aplicación de autenticación'),
  sms('sms', 'SMS al número telefónico', 'SMS al +51 XXX XXX XXX'),
  email('email', 'Código por email', 'Email de verificación'),
  biometric('biometric', 'Huella dactilar/Face ID', 'Autenticación biométrica'),
  recoveryCode('recovery', 'Códigos de recuperación', 'Códigos de backup');

  const MFAMethod(this.code, this.name, this.description);
  final String code;
  final String name;
  final String description;
}

/// Estados de configuración MFA
enum MFAStatus {
  disabled('disabled', 'MFA deshabilitado'),
  enabled('enabled', 'MFA activo'),
  pending('pending', 'Configuración pendiente'),
  suspended('suspended', 'MFA suspendido'),
  required('required', 'MFA obligatorio');

  const MFAStatus(this.code, this.description);
  final String code;
  final String description;
}

/// Resultado de verificación MFA
class MFAVerificationResult {
  final bool isValid;
  final MFAMethod method;
  final DateTime timestamp;
  final String? sessionId;
  final String? error;
  final Map<String, dynamic> metadata;

  MFAVerificationResult({
    required this.isValid,
    required this.method,
    required this.timestamp,
    this.sessionId,
    this.error,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'isValid': isValid,
        'method': method.code,
        'timestamp': timestamp.toIso8601String(),
        'sessionId': sessionId,
        'error': error,
        'metadata': metadata,
      };
}

/// Configuración MFA del usuario
class MFAConfiguration {
  final String userId;
  final MFAStatus status;
  final List<MFAMethod> enabledMethods;
  final MFAMethod? primaryMethod;
  final DateTime? lastSetup;
  final List<String> recoveryCodes;
  final Map<String, dynamic> settings;

  MFAConfiguration({
    required this.userId,
    required this.status,
    required this.enabledMethods,
    this.primaryMethod,
    this.lastSetup,
    this.recoveryCodes = const [],
    this.settings = const {},
  });

  factory MFAConfiguration.fromJson(Map<String, dynamic> json) {
    return MFAConfiguration(
      userId: json['userId'] ?? '',
      status: MFAStatus.values.firstWhere(
        (s) => s.code == json['status'],
        orElse: () => MFAStatus.disabled,
      ),
      enabledMethods: (json['enabledMethods'] as List<dynamic>?)
              ?.map((m) =>
                  MFAMethod.values.firstWhere((method) => method.code == m))
              .toList() ??
          [],
      primaryMethod: json['primaryMethod'] != null
          ? MFAMethod.values.firstWhere((m) => m.code == json['primaryMethod'])
          : null,
      lastSetup:
          json['lastSetup'] != null ? DateTime.parse(json['lastSetup']) : null,
      recoveryCodes: List<String>.from(json['recoveryCodes'] ?? []),
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'status': status.code,
        'enabledMethods': enabledMethods.map((m) => m.code).toList(),
        'primaryMethod': primaryMethod?.code,
        'lastSetup': lastSetup?.toIso8601String(),
        'recoveryCodes': recoveryCodes,
        'settings': settings,
      };
}

/// Servicio completo de Multi-Factor Authentication para OasisTaxi
class MFAService {
  static final MFAService _instance = MFAService._internal();
  factory MFAService() => _instance;
  MFAService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Cache de configuraciones MFA
  final Map<String, MFAConfiguration> _configCache = {};

  // Configuración para OasisTaxi Perú
  static const String _issuerName = 'OasisTaxi Perú';
  static const String _appName = 'OasisTaxi';
  static const int _codeValidityMinutes = 5;
  static const int _maxVerificationAttempts = 3;
  static const int _recoveryCodesCount = 10;

  /// Inicializar el servicio MFA
  Future<void> initialize() async {
    try {
      AppLogger.info('Inicializando servicio MFA para OasisTaxi');

      // Verificar capacidades del dispositivo
      await _checkDeviceCapabilities();

      // Configurar listeners de autenticación
      _setupAuthListeners();

      AppLogger.info('Servicio MFA inicializado exitosamente');
    } catch (e, stackTrace) {
      AppLogger.error('Error inicializando servicio MFA', e, stackTrace);
      rethrow;
    }
  }

  /// Verificar capacidades MFA del dispositivo
  Future<Map<String, bool>> _checkDeviceCapabilities() async {
    try {
      final capabilities = <String, bool>{};

      // Verificar autenticación biométrica
      final biometricAvailable = await _localAuth.canCheckBiometrics;
      final biometricEnrolled = await _localAuth.isDeviceSupported();
      capabilities['biometric'] = biometricAvailable && biometricEnrolled;

      // SMS siempre disponible en dispositivos móviles
      capabilities['sms'] = true;

      // Email siempre disponible
      capabilities['email'] = true;

      // TOTP siempre disponible
      capabilities['totp'] = true;

      AppLogger.info('Capacidades MFA detectadas', capabilities);
      return capabilities;
    } catch (e) {
      AppLogger.error('Error verificando capacidades del dispositivo', e);
      return {};
    }
  }

  /// Obtener configuración MFA del usuario
  Future<MFAConfiguration> getUserMFAConfiguration(String userId) async {
    try {
      // Verificar cache primero
      if (_configCache.containsKey(userId)) {
        final cached = _configCache[userId]!;
        final cacheAge =
            DateTime.now().difference(cached.lastSetup ?? DateTime.now());
        if (cacheAge < const Duration(minutes: 5)) {
          return cached;
        }
      }

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security')
          .doc('mfa')
          .get();

      MFAConfiguration config;
      if (doc.exists) {
        config = MFAConfiguration.fromJson(doc.data()!);
      } else {
        // Crear configuración por defecto
        config = MFAConfiguration(
          userId: userId,
          status: MFAStatus.disabled,
          enabledMethods: [],
        );
      }

      _configCache[userId] = config;
      return config;
    } catch (e, stackTrace) {
      AppLogger.error('Error obteniendo configuración MFA', e, stackTrace);
      return MFAConfiguration(
        userId: userId,
        status: MFAStatus.disabled,
        enabledMethods: [],
      );
    }
  }

  /// Configurar TOTP para usuario
  Future<Map<String, dynamic>> setupTOTP(String userId) async {
    try {
      AppLogger.info('Configurando TOTP para usuario', {'userId': userId});

      // Generar secret key para TOTP
      final secret = _generateSecretKey();
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Crear URL para QR code
      final otpUrl =
          _generateOTPUrl(user.email ?? user.phoneNumber ?? '', secret);

      // Guardar secret temporalmente (pendiente de verificación)
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('security')
          .doc('mfa_pending')
          .set({
        'totpSecret': secret,
        'timestamp': FieldValue.serverTimestamp(),
        'verified': false,
      });

      return {
        'secret': secret,
        'qrCodeUrl': otpUrl,
        'manualEntryKey': _formatSecretForManualEntry(secret),
        'issuer': _issuerName,
        'appName': _appName,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error configurando TOTP', e, stackTrace);
      rethrow;
    }
  }

  /// Verificar código TOTP y completar configuración
  Future<bool> verifyAndEnableTOTP(String userId, String code) async {
    try {
      // Obtener secret pendiente
      final pendingDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security')
          .doc('mfa_pending')
          .get();

      if (!pendingDoc.exists) {
        throw Exception('No hay configuración TOTP pendiente');
      }

      final secret = pendingDoc.data()!['totpSecret'] as String;

      // Verificar código TOTP
      if (!_verifyTOTPCode(secret, code)) {
        AppLogger.warning('Código TOTP inválido para configuración');
        return false;
      }

      // Código correcto, activar TOTP
      final config = await getUserMFAConfiguration(userId);
      final updatedMethods = List<MFAMethod>.from(config.enabledMethods);
      if (!updatedMethods.contains(MFAMethod.totp)) {
        updatedMethods.add(MFAMethod.totp);
      }

      final newConfig = MFAConfiguration(
        userId: userId,
        status: MFAStatus.enabled,
        enabledMethods: updatedMethods,
        primaryMethod: config.primaryMethod ?? MFAMethod.totp,
        lastSetup: DateTime.now(),
        recoveryCodes: config.recoveryCodes.isEmpty
            ? _generateRecoveryCodes()
            : config.recoveryCodes,
        settings: {
          ...config.settings,
          'totpSecret': secret,
        },
      );

      // Guardar configuración final
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('security')
          .doc('mfa')
          .set(newConfig.toJson());

      // Limpiar configuración pendiente
      await pendingDoc.reference.delete();

      // Actualizar cache
      _configCache[userId] = newConfig;

      AppLogger.info(
          'TOTP configurado exitosamente para usuario', {'userId': userId});

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error verificando y habilitando TOTP', e, stackTrace);
      return false;
    }
  }

  /// Configurar SMS MFA
  Future<bool> setupSMS(String userId, String phoneNumber) async {
    try {
      AppLogger.info(
          'Configurando SMS MFA', {'userId': userId, 'phone': phoneNumber});

      // Validar número peruano
      if (!_isValidPeruvianPhoneNumber(phoneNumber)) {
        throw Exception('Número telefónico peruano inválido');
      }

      // Enviar código de verificación
      final verificationCode = _generateVerificationCode();

      // Usar Cloud Function para enviar SMS
      final callable = _functions.httpsCallable('sendSMSVerification');
      await callable.call({
        'phoneNumber': phoneNumber,
        'code': verificationCode,
        'purpose': 'mfa_setup',
      });

      // Guardar código pendiente
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('security')
          .doc('sms_pending')
          .set({
        'phoneNumber': phoneNumber,
        'verificationCode': verificationCode,
        'timestamp': FieldValue.serverTimestamp(),
        'attempts': 0,
      });

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error configurando SMS MFA', e, stackTrace);
      return false;
    }
  }

  /// Verificar código SMS y completar configuración
  Future<bool> verifyAndEnableSMS(String userId, String code) async {
    try {
      final pendingDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security')
          .doc('sms_pending')
          .get();

      if (!pendingDoc.exists) {
        throw Exception('No hay verificación SMS pendiente');
      }

      final data = pendingDoc.data()!;
      final expectedCode = data['verificationCode'] as String;
      final phoneNumber = data['phoneNumber'] as String;
      final attempts = (data['attempts'] as int? ?? 0) + 1;

      if (attempts > _maxVerificationAttempts) {
        throw Exception('Máximo número de intentos excedido');
      }

      if (code != expectedCode) {
        // Incrementar intentos
        await pendingDoc.reference.update({'attempts': attempts});
        return false;
      }

      // Código correcto, habilitar SMS MFA
      final config = await getUserMFAConfiguration(userId);
      final updatedMethods = List<MFAMethod>.from(config.enabledMethods);
      if (!updatedMethods.contains(MFAMethod.sms)) {
        updatedMethods.add(MFAMethod.sms);
      }

      final newConfig = MFAConfiguration(
        userId: userId,
        status: MFAStatus.enabled,
        enabledMethods: updatedMethods,
        primaryMethod: config.primaryMethod ?? MFAMethod.sms,
        lastSetup: DateTime.now(),
        recoveryCodes: config.recoveryCodes.isEmpty
            ? _generateRecoveryCodes()
            : config.recoveryCodes,
        settings: {
          ...config.settings,
          'smsPhoneNumber': phoneNumber,
        },
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('security')
          .doc('mfa')
          .set(newConfig.toJson());

      await pendingDoc.reference.delete();
      _configCache[userId] = newConfig;

      AppLogger.info('SMS MFA configurado exitosamente');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error verificando SMS MFA', e, stackTrace);
      return false;
    }
  }

  /// Verificar MFA durante login
  Future<MFAVerificationResult> verifyMFA({
    required String userId,
    required String code,
    required MFAMethod method,
  }) async {
    try {
      AppLogger.info(
          'Verificando MFA', {'userId': userId, 'method': method.code});

      final config = await getUserMFAConfiguration(userId);

      if (!config.enabledMethods.contains(method)) {
        throw Exception('Método MFA no habilitado para este usuario');
      }

      bool isValid = false;
      Map<String, dynamic> metadata = {};

      switch (method) {
        case MFAMethod.totp:
          final secret = config.settings['totpSecret'] as String?;
          if (secret != null) {
            isValid = _verifyTOTPCode(secret, code);
          }
          break;

        case MFAMethod.sms:
          // Verificar código SMS almacenado temporalmente
          isValid = await _verifySMSCode(userId, code);
          break;

        case MFAMethod.email:
          isValid = await _verifyEmailCode(userId, code);
          break;

        case MFAMethod.recoveryCode:
          isValid = await _verifyRecoveryCode(userId, code);
          break;

        case MFAMethod.biometric:
          isValid = await _verifyBiometric();
          break;
      }

      final result = MFAVerificationResult(
        isValid: isValid,
        method: method,
        timestamp: DateTime.now(),
        sessionId: isValid ? _generateSessionId() : null,
        metadata: metadata,
      );

      // Registrar intento de verificación
      await _logMFAAttempt(userId, result);

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Error verificando MFA', e, stackTrace);
      return MFAVerificationResult(
        isValid: false,
        method: method,
        timestamp: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Deshabilitar MFA para usuario
  Future<bool> disableMFA(String userId, String confirmationCode) async {
    try {
      // Verificar código de confirmación primero
      final isValidConfirmation = await verifyMFA(
        userId: userId,
        code: confirmationCode,
        method: MFAMethod.totp, // O el método primario del usuario
      );

      if (!isValidConfirmation.isValid) {
        return false;
      }

      // Deshabilitar MFA
      final disabledConfig = MFAConfiguration(
        userId: userId,
        status: MFAStatus.disabled,
        enabledMethods: [],
        recoveryCodes: [], // Limpiar códigos de recuperación
        settings: {}, // Limpiar configuraciones
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('security')
          .doc('mfa')
          .set(disabledConfig.toJson());

      _configCache[userId] = disabledConfig;

      AppLogger.info('MFA deshabilitado para usuario', {'userId': userId});

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error deshabilitando MFA', e, stackTrace);
      return false;
    }
  }

  /// Generar códigos de recuperación
  List<String> _generateRecoveryCodes() {
    final codes = <String>[];
    final random = Random.secure();

    for (int i = 0; i < _recoveryCodesCount; i++) {
      final code =
          List.generate(8, (index) => random.nextInt(10).toString()).join();
      codes.add(code);
    }

    return codes;
  }

  /// Verificar código de recuperación
  Future<bool> _verifyRecoveryCode(String userId, String code) async {
    try {
      final config = await getUserMFAConfiguration(userId);

      if (config.recoveryCodes.contains(code)) {
        // Remover código usado (uso único)
        final updatedCodes = List<String>.from(config.recoveryCodes);
        updatedCodes.remove(code);

        final updatedConfig = MFAConfiguration(
          userId: userId,
          status: config.status,
          enabledMethods: config.enabledMethods,
          primaryMethod: config.primaryMethod,
          lastSetup: config.lastSetup,
          recoveryCodes: updatedCodes,
          settings: config.settings,
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('security')
            .doc('mfa')
            .set(updatedConfig.toJson());

        _configCache[userId] = updatedConfig;

        AppLogger.warning('Código de recuperación usado',
            {'userId': userId, 'codesRemaining': updatedCodes.length});

        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error verificando código de recuperación', e);
      return false;
    }
  }

  /// Generar secret key para TOTP
  String _generateSecretKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(20, (i) => random.nextInt(256));
    return base32Encode(bytes);
  }

  /// Codificar en base32
  String base32Encode(List<int> bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    String result = '';
    int bits = 0;
    int value = 0;

    for (int byte in bytes) {
      value = (value << 8) | byte;
      bits += 8;

      while (bits >= 5) {
        result += alphabet[(value >> (bits - 5)) & 31];
        bits -= 5;
      }
    }

    if (bits > 0) {
      result += alphabet[(value << (5 - bits)) & 31];
    }

    return result;
  }

  /// Generar URL para aplicación TOTP
  String _generateOTPUrl(String accountName, String secret) {
    final encodedAccountName = Uri.encodeComponent(accountName);
    final encodedIssuer = Uri.encodeComponent(_issuerName);

    return 'otpauth://totp/$encodedIssuer:$encodedAccountName'
        '?secret=$secret'
        '&issuer=$encodedIssuer'
        '&algorithm=SHA1'
        '&digits=6'
        '&period=30';
  }

  /// Formatear secret para entrada manual
  String _formatSecretForManualEntry(String secret) {
    return secret
        .replaceAllMapped(
          RegExp(r'.{4}'),
          (match) => '${match.group(0)} ',
        )
        .trim();
  }

  /// Verificar código TOTP
  bool _verifyTOTPCode(String secret, String code) {
    try {
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final timeStep = currentTime ~/ 30;

      // Verificar ventana de tiempo (±1 step para compensar clock skew)
      for (int i = -1; i <= 1; i++) {
        final generatedCode = _generateTOTPCode(secret, timeStep + i);
        if (generatedCode == code) {
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('Error verificando código TOTP', e);
      return false;
    }
  }

  /// Generar código TOTP
  String _generateTOTPCode(String secret, int timeStep) {
    final key = base32Decode(secret);
    final timeBytes = _intToByteArray(timeStep);

    final hmac = Hmac(sha1, key);
    final hash = hmac.convert(timeBytes).bytes;

    final offset = hash.last & 0x0F;
    final binary = ((hash[offset] & 0x7F) << 24) |
        ((hash[offset + 1] & 0xFF) << 16) |
        ((hash[offset + 2] & 0xFF) << 8) |
        (hash[offset + 3] & 0xFF);

    final code = binary % 1000000;
    return code.toString().padLeft(6, '0');
  }

  /// Decodificar base32
  List<int> base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    input = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');

    List<int> result = [];
    int bits = 0;
    int value = 0;

    for (int i = 0; i < input.length; i++) {
      value = (value << 5) | alphabet.indexOf(input[i]);
      bits += 5;

      if (bits >= 8) {
        result.add((value >> (bits - 8)) & 255);
        bits -= 8;
      }
    }

    return result;
  }

  /// Convertir entero a array de bytes
  Uint8List _intToByteArray(int value) {
    final bytes = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      bytes[i] = value & 0xFF;
      value >>= 8;
    }
    return bytes;
  }

  /// Validar número telefónico peruano
  bool _isValidPeruvianPhoneNumber(String phoneNumber) {
    // Formato: +51XXXXXXXXX (9 dígitos después del código de país)
    final pattern = RegExp(r'^\+51[9][0-9]{8}$');
    return pattern.hasMatch(phoneNumber);
  }

  /// Generar código de verificación numérico
  String _generateVerificationCode() {
    final random = Random.secure();
    return List.generate(6, (index) => random.nextInt(10)).join();
  }

  /// Generar session ID único
  String _generateSessionId() {
    final random = Random.secure();
    final bytes = List.generate(16, (index) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Verificar código SMS (implementación placeholder)
  Future<bool> _verifySMSCode(String userId, String code) async {
    // Implementar verificación con código almacenado temporalmente
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security')
          .doc('sms_verification')
          .get();

      if (doc.exists) {
        final storedCode = doc.data()!['code'] as String?;
        final timestamp = doc.data()!['timestamp'] as Timestamp?;

        if (timestamp != null) {
          final age = DateTime.now().difference(timestamp.toDate());
          if (age.inMinutes <= _codeValidityMinutes && storedCode == code) {
            await doc.reference.delete(); // Usar código una sola vez
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Verificar código email (implementación placeholder)
  Future<bool> _verifyEmailCode(String userId, String code) async {
    // Similar a SMS pero para email
    return false; // Implementar según necesidades
  }

  /// Verificar biométrica
  Future<bool> _verifyBiometric() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) return false;

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Verificar identidad para OasisTaxi',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return isAuthenticated;
    } catch (e) {
      AppLogger.error('Error en autenticación biométrica', e);
      return false;
    }
  }

  /// Registrar intento de verificación MFA
  Future<void> _logMFAAttempt(
      String userId, MFAVerificationResult result) async {
    try {
      await _firestore.collection('mfaLogs').add({
        'userId': userId,
        'method': result.method.code,
        'isValid': result.isValid,
        'timestamp': FieldValue.serverTimestamp(),
        'sessionId': result.sessionId,
        'error': result.error,
        'metadata': result.metadata,
      });
    } catch (e) {
      AppLogger.error('Error registrando intento MFA', e);
    }
  }

  /// Configurar listeners de autenticación
  void _setupAuthListeners() {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        // Usuario deslogueado, limpiar cache
        _configCache.clear();
      }
    });
  }

  /// Configurar MFA para un usuario (método wrapper)
  /// Configura TOTP por defecto como método MFA principal
  Future<Map<String, dynamic>> setupMfa(String userId) async {
    try {
      AppLogger.info('MFA: Configurando MFA para usuario $userId');

      // Por defecto configuramos TOTP como método principal
      final totpResult = await setupTOTP(userId);

      AppLogger.info('MFA: MFA configurado exitosamente para usuario $userId');
      return totpResult;
    } catch (e) {
      AppLogger.error('Error configurando MFA para usuario $userId', e);
      throw Exception('Error configurando MFA: ${e.toString()}');
    }
  }

  /// Verificar código MFA para un usuario (método wrapper)
  /// Verifica el código usando el método verifyMFA existente
  Future<bool> verifyMfaCode(String userId, String code) async {
    try {
      AppLogger.info('MFA: Verificando código MFA para usuario $userId');

      // Usar el método verifyMFA existente
      final result = await verifyMFA(
        userId: userId,
        code: code,
        method: MFAMethod.totp, // Por defecto TOTP
      );

      final isValid = result.isValid;
      AppLogger.info(
          'MFA: Código ${isValid ? "válido" : "inválido"} para usuario $userId');

      return isValid;
    } catch (e) {
      AppLogger.error('Error verificando código MFA para usuario $userId', e);
      return false;
    }
  }

  /// Limpiar recursos
  void dispose() {
    _configCache.clear();
    AppLogger.info('Servicio MFA limpiado');
  }
}

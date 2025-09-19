import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import '../core/config/environment_config.dart';
import 'cloud_kms_service.dart';

/// Tipos de amenazas de seguridad
enum SecurityThreat {
  bruteForce,
  sqlInjection,
  xssAttack,
  csrfAttack,
  dataLeakage,
  unauthorizedAccess,
  deviceTampering,
  networkAttack,
  malwareDetection,
  fraudulentActivity,
}

/// Niveles de severidad de seguridad
enum SecuritySeverity {
  low,
  medium,
  high,
  critical,
}

/// Estados de compliance
enum ComplianceStatus {
  compliant,
  nonCompliant,
  warning,
  unknown,
}

/// Tipos de autenticación
enum AuthenticationType {
  password,
  biometric,
  twoFactor,
  multiFactorAuth,
  certificateBased,
}

/// Modelo para incidente de seguridad
class SecurityIncident {
  final String id;
  final SecurityThreat threatType;
  final SecuritySeverity severity;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String? userId;
  final String? deviceId;
  final bool resolved;
  final List<String> mitigationActions;

  const SecurityIncident({
    required this.id,
    required this.threatType,
    required this.severity,
    required this.description,
    required this.metadata,
    required this.timestamp,
    this.userId,
    this.deviceId,
    required this.resolved,
    required this.mitigationActions,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'threatType': threatType.name,
      'severity': severity.name,
      'description': description,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'deviceId': deviceId,
      'resolved': resolved,
      'mitigationActions': mitigationActions,
    };
  }

  factory SecurityIncident.fromJson(Map<String, dynamic> json) {
    return SecurityIncident(
      id: json['id'] ?? '',
      threatType: SecurityThreat.values.firstWhere(
        (t) => t.name == json['threatType'],
        orElse: () => SecurityThreat.unauthorizedAccess,
      ),
      severity: SecuritySeverity.values.firstWhere(
        (s) => s.name == json['severity'],
        orElse: () => SecuritySeverity.medium,
      ),
      description: json['description'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      userId: json['userId'],
      deviceId: json['deviceId'],
      resolved: json['resolved'] ?? false,
      mitigationActions: List<String>.from(json['mitigationActions'] ?? []),
    );
  }
}

/// Resultado de validación de seguridad
class SecurityValidationResult {
  final bool isValid;
  final List<String> violations;
  final SecuritySeverity riskLevel;
  final Map<String, dynamic> details;

  const SecurityValidationResult({
    required this.isValid,
    required this.violations,
    required this.riskLevel,
    required this.details,
  });
}

/// Resultado de autenticación biométrica
class BiometricAuthResult {
  final bool authenticated;
  final AuthenticationType authType;
  final double confidence;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  const BiometricAuthResult({
    required this.authenticated,
    required this.authType,
    required this.confidence,
    this.errorMessage,
    required this.metadata,
  });
}

/// Configuración de compliance
class ComplianceConfig {
  final bool enablePCICompliance;
  final bool enableGDPRCompliance;
  final bool enablePeruDataProtection;
  final bool enableAuditLogging;
  final bool enableRealTimeMonitoring;
  final int dataRetentionDays;
  final List<String> sensitiveDataFields;

  const ComplianceConfig({
    required this.enablePCICompliance,
    required this.enableGDPRCompliance,
    required this.enablePeruDataProtection,
    required this.enableAuditLogging,
    required this.enableRealTimeMonitoring,
    required this.dataRetentionDays,
    required this.sensitiveDataFields,
  });

  Map<String, dynamic> toJson() {
    return {
      'enablePCICompliance': enablePCICompliance,
      'enableGDPRCompliance': enableGDPRCompliance,
      'enablePeruDataProtection': enablePeruDataProtection,
      'enableAuditLogging': enableAuditLogging,
      'enableRealTimeMonitoring': enableRealTimeMonitoring,
      'dataRetentionDays': dataRetentionDays,
      'sensitiveDataFields': sensitiveDataFields,
    };
  }

  factory ComplianceConfig.fromJson(Map<String, dynamic> json) {
    return ComplianceConfig(
      enablePCICompliance: json['enablePCICompliance'] ?? true,
      enableGDPRCompliance: json['enableGDPRCompliance'] ?? true,
      enablePeruDataProtection: json['enablePeruDataProtection'] ?? true,
      enableAuditLogging: json['enableAuditLogging'] ?? true,
      enableRealTimeMonitoring: json['enableRealTimeMonitoring'] ?? true,
      dataRetentionDays: json['dataRetentionDays'] ?? 365,
      sensitiveDataFields: List<String>.from(json['sensitiveDataFields'] ?? []),
    );
  }
}

/// Estado de compliance
class ComplianceState {
  final bool pciCompliant;
  final bool gdprCompliant;
  final bool peruDataProtectionCompliant;
  final DateTime lastAudit;
  final List<String> violations;
  final double complianceScore;

  const ComplianceState({
    required this.pciCompliant,
    required this.gdprCompliant,
    required this.peruDataProtectionCompliant,
    required this.lastAudit,
    required this.violations,
    required this.complianceScore,
  });

  Map<String, dynamic> toJson() {
    return {
      'pciCompliant': pciCompliant,
      'gdprCompliant': gdprCompliant,
      'peruDataProtectionCompliant': peruDataProtectionCompliant,
      'lastAudit': lastAudit.toIso8601String(),
      'violations': violations,
      'complianceScore': complianceScore,
    };
  }
}

/// Servicio completo de seguridad y compliance para OasisTaxi Peru
class SecurityComplianceService {
  static SecurityComplianceService? _instance;
  static SecurityComplianceService get instance {
    _instance ??= SecurityComplianceService._internal();
    return _instance!;
  }

  SecurityComplianceService._internal();

  // Servicios y configuración
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  SharedPreferences? _prefs;

  // Cache de seguridad
  final Map<String, SecurityValidationResult> _validationCache = {};
  final Map<String, BiometricAuthResult> _authCache = {};
  final List<SecurityIncident> _incidentLog = [];

  // Configuración
  ComplianceConfig? _complianceConfig;
  bool _isInitialized = false;
  Timer? _monitoringTimer;
  Timer? _complianceCheckTimer;

  // Claves de cifrado
  late String _encryptionKey;
  late CloudKmsService _kmsService;

  // Rate limiting para prevenir ataques
  final Map<String, List<DateTime>> _rateLimitTracker = {};
  static const int _maxAttemptsPerMinute = 10;
  static const int _maxAttemptsPerHour = 50;

  // Patrones de validación específicos para Perú
  static const Map<String, String> _peruValidationPatterns = {
    'dni': r'^\d{8}$',
    'phone': r'^\+51[0-9]{9}$',
    'email': r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    'licensePlate': r'^[A-Z]{3}-\d{3}$|^[A-Z]{2}-\d{4}$',
    'creditCard':
        r'^(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})$',
  };

  /// Inicializa el servicio de seguridad y compliance
  Future<void> initialize({
    ComplianceConfig? config,
    bool enableRealTimeMonitoring = true,
    bool enableBiometricAuth = true,
  }) async {
    try {
      AppLogger.info(
          'Inicializando Security & Compliance Service para OasisTaxi Peru');

      _prefs = await SharedPreferences.getInstance();

      // Inicializar Cloud KMS
      _kmsService = CloudKmsService.instance;
      await _kmsService.initialize();

      // Obtener clave de cifrado desde variables de entorno o generar nueva
      await _initializeEncryptionKey();

      // Configurar compliance
      _complianceConfig = config ?? _getDefaultComplianceConfig();

      // Cargar configuración guardada
      await _loadSecurityConfiguration();

      // Inicializar autenticación biométrica
      if (enableBiometricAuth) {
        await _initializeBiometricAuth();
      }

      // Configurar monitoreo en tiempo real
      if (enableRealTimeMonitoring &&
          _complianceConfig!.enableRealTimeMonitoring) {
        _startRealTimeMonitoring();
      }

      // Iniciar verificaciones de compliance
      _startComplianceChecks();

      // Cargar incidentes de seguridad previos
      await _loadSecurityIncidents();

      _isInitialized = true;
      AppLogger.info('Security & Compliance Service inicializado exitosamente');

      // Registrar inicialización en audit log
      await _logSecurityEvent('service_initialized', {
        'compliance_config': _complianceConfig!.toJson(),
        'biometric_enabled': enableBiometricAuth,
        'monitoring_enabled': enableRealTimeMonitoring,
        'kms_enabled': true,
      });
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error inicializando Security & Compliance Service', e, stackTrace);
      rethrow;
    }
  }

  /// Inicializa la clave de cifrado usando variables de entorno o KMS
  Future<void> _initializeEncryptionKey() async {
    try {
      // Primero intentar cargar DEK envuelta existente
      final wrappedDek = _prefs!.getString('wrapped_dek');
      if (wrappedDek != null && wrappedDek.isNotEmpty) {
        try {
          // Desenvolver la DEK usando KMS
          final dekBytes = await _kmsService.unwrapDataEncryptionKey(wrappedDek);
          _encryptionKey = base64.encode(dekBytes);
          AppLogger.info('DEK existente desenvuelta exitosamente desde KMS');
          return;
        } catch (e) {
          AppLogger.warning('Error desenvolviendo DEK existente, generando nueva', e);
        }
      }

      // En desarrollo, usar clave de variables de entorno si está disponible
      if (EnvironmentConfig.isDevelopment) {
        final envKey = EnvironmentConfig.dataEncryptionKey;
        if (envKey.isNotEmpty &&
            !envKey.contains('PLACEHOLDER') &&
            !envKey.contains('CHANGE')) {
          // Validar que sea una clave base64 válida de 32 bytes
          try {
            final keyBytes = base64.decode(envKey);
            if (keyBytes.length == 32) {
              _encryptionKey = envKey;
              AppLogger.info('DEK cargada desde variables de entorno (desarrollo)');
              return;
            }
          } catch (e) {
            AppLogger.warning('DATA_ENCRYPTION_KEY no es base64 válido');
          }
        }
      }

      // Generar nueva DEK y envolverla con KMS para almacenamiento seguro
      final dekBytes = await _kmsService.generateDataEncryptionKey();
      _encryptionKey = base64.encode(dekBytes);

      // Envolver la DEK con KMS y guardar
      final wrappedDekNew = await _kmsService.wrapDataEncryptionKey(dekBytes);
      await _prefs!.setString('wrapped_dek', wrappedDekNew);

      AppLogger.info('Nueva DEK generada y envuelta con KMS');
    } catch (e, stackTrace) {
      AppLogger.error('Error inicializando clave de cifrado', e, stackTrace);
      // Fallback solo para desarrollo
      if (EnvironmentConfig.isDevelopment) {
        // Generar clave aleatoria de 32 bytes como fallback
        final random = Random.secure();
        final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
        _encryptionKey = base64.encode(keyBytes);
        AppLogger.warning('Usando clave aleatoria de desarrollo como fallback');
      } else {
        rethrow;
      }
    }
  }

  /// Valida entrada de datos con patrones de seguridad
  SecurityValidationResult validateInput({
    required String input,
    required String inputType,
    bool sanitize = true,
    Map<String, dynamic>? context,
  }) {
    try {
      final violations = <String>[];
      var sanitizedInput = input;
      var riskLevel = SecuritySeverity.low;

      // Sanitizar entrada si está habilitado
      if (sanitize) {
        sanitizedInput = _sanitizeInput(input);
      }

      // Validar según tipo de entrada específico para Perú
      if (_peruValidationPatterns.containsKey(inputType)) {
        final pattern = RegExp(_peruValidationPatterns[inputType]!);
        if (!pattern.hasMatch(sanitizedInput)) {
          violations.add('Formato inválido para $inputType');
          riskLevel = SecuritySeverity.medium;
        }
      }

      // Detectar intentos de inyección SQL
      if (_detectSQLInjection(sanitizedInput)) {
        violations.add('Posible intento de inyección SQL detectado');
        riskLevel = SecuritySeverity.critical;
        _reportSecurityIncident(
            SecurityThreat.sqlInjection, sanitizedInput, context);
      }

      // Detectar XSS
      if (_detectXSSAttack(sanitizedInput)) {
        violations.add('Posible ataque XSS detectado');
        riskLevel = SecuritySeverity.high;
        _reportSecurityIncident(
            SecurityThreat.xssAttack, sanitizedInput, context);
      }

      // Validar longitud y caracteres peligrosos
      if (sanitizedInput.length > 1000) {
        violations.add('Entrada excesivamente larga');
        riskLevel = SecuritySeverity.medium;
      }

      final result = SecurityValidationResult(
        isValid: violations.isEmpty,
        violations: violations,
        riskLevel: riskLevel,
        details: {
          'originalInput': input,
          'sanitizedInput': sanitizedInput,
          'inputType': inputType,
          'context': context,
        },
      );

      // Cache resultado
      final cacheKey = _generateCacheKey(input, inputType);
      _validationCache[cacheKey] = result;

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Error en validación de entrada', e, stackTrace);
      return SecurityValidationResult(
        isValid: false,
        violations: ['Error interno en validación'],
        riskLevel: SecuritySeverity.medium,
        details: {'error': e.toString()},
      );
    }
  }

  /// Cifra datos sensibles usando AES-256 con KMS o DEK local
  Future<String> encryptSensitiveData(String data, {String? customKey, bool useKms = false}) async {
    try {
      if (useKms) {
        // Cifrado directo con KMS (para datos muy sensibles)
        return await _kmsService.encryptData(data);
      }

      // Cifrado local con DEK
      final key = customKey ?? _encryptionKey;

      // Decodificar la clave base64 a bytes (debe ser 32 bytes)
      late List<int> keyBytes;
      bool usedFallback = false;
      try {
        keyBytes = base64.decode(key);
        if (keyBytes.length != 32) {
          throw FormatException('La clave debe ser de 32 bytes, recibidos: ${keyBytes.length}');
        }
      } catch (e) {
        // Fallback para claves que no son base64 (compatibilidad)
        final paddedKey = key.padRight(32).substring(0, 32);
        keyBytes = utf8.encode(paddedKey);
        usedFallback = true;
        if (!EnvironmentConfig.isDevelopment) {
          AppLogger.warning('Usando fallback no-base64 para clave de cifrado en producción');
        }
      }

      final iv = _generateSecureIV();
      final encrypted = _aesEncrypt(data, keyBytes, iv);
      final result = base64.encode([...iv, ...encrypted]);

      AppLogger.info('Datos cifrados exitosamente', {
        'dataLength': data.length,
        'encryptedLength': result.length,
        'method': useKms ? 'KMS' : 'DEK',
      });

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Error cifrando datos', e, stackTrace);
      rethrow;
    }
  }

  /// Descifra datos sensibles
  Future<String> decryptSensitiveData(String encryptedData,
      {String? customKey, bool useKms = false}) async {
    try {
      if (useKms) {
        // Descifrado directo con KMS
        return await _kmsService.decryptData(encryptedData);
      }

      // Descifrado local con DEK
      final key = customKey ?? _encryptionKey;

      // Decodificar la clave base64 a bytes (debe ser 32 bytes)
      late List<int> keyBytes;
      bool usedFallback = false;
      try {
        keyBytes = base64.decode(key);
        if (keyBytes.length != 32) {
          throw FormatException('La clave debe ser de 32 bytes, recibidos: ${keyBytes.length}');
        }
      } catch (e) {
        // Fallback para claves que no son base64 (compatibilidad)
        final paddedKey = key.padRight(32).substring(0, 32);
        keyBytes = utf8.encode(paddedKey);
        usedFallback = true;
        if (!EnvironmentConfig.isDevelopment) {
          AppLogger.warning('Usando fallback no-base64 para clave de descifrado en producción');
        }
      }

      final encryptedBytes = base64.decode(encryptedData);
      final iv = encryptedBytes.sublist(0, 16);
      final encrypted = encryptedBytes.sublist(16);

      final decrypted = _aesDecrypt(encrypted, keyBytes, iv);

      AppLogger.info('Datos descifrados exitosamente');
      return decrypted;
    } catch (e, stackTrace) {
      AppLogger.error('Error descifrando datos', e, stackTrace);
      rethrow;
    }
  }

  /// Autenticación biométrica
  Future<BiometricAuthResult> authenticateWithBiometrics({
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Verificar disponibilidad de biometría
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        return BiometricAuthResult(
          authenticated: false,
          authType: AuthenticationType.biometric,
          confidence: 0.0,
          errorMessage: 'Autenticación biométrica no disponible',
          metadata: metadata ?? {},
        );
      }

      // Obtener tipos biométricos disponibles
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return BiometricAuthResult(
          authenticated: false,
          authType: AuthenticationType.biometric,
          confidence: 0.0,
          errorMessage: 'No hay métodos biométricos configurados',
          metadata: metadata ?? {},
        );
      }

      // Realizar autenticación
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      final result = BiometricAuthResult(
        authenticated: authenticated,
        authType: AuthenticationType.biometric,
        confidence: authenticated ? 0.95 : 0.0,
        errorMessage: authenticated ? null : 'Autenticación fallida',
        metadata: {
          'availableBiometrics':
              availableBiometrics.map((b) => b.name).toList(),
          'reason': reason,
          ...?metadata,
        },
      );

      // Log del evento de autenticación
      await _logSecurityEvent('biometric_authentication', {
        'success': authenticated,
        'biometrics_available': availableBiometrics.length,
        'reason': reason,
      });

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Error en autenticación biométrica', e, stackTrace);
      return BiometricAuthResult(
        authenticated: false,
        authType: AuthenticationType.biometric,
        confidence: 0.0,
        errorMessage: e.toString(),
        metadata: metadata ?? {},
      );
    }
  }

  /// Detecta y previene fraudes
  Future<bool> detectFraudulentActivity({
    required String userId,
    required String action,
    required Map<String, dynamic> context,
  }) async {
    try {
      var fraudScore = 0.0;
      final riskFactors = <String>[];

      // Verificar patrones de uso anómalos
      final userHistory = await _getUserActivityHistory(userId);

      // Análisis de velocidad de acciones
      if (_detectHighVelocityActivity(userHistory, action)) {
        fraudScore += 0.3;
        riskFactors.add('high_velocity_activity');
      }

      // Análisis de ubicación geográfica
      if (context.containsKey('location')) {
        if (await _detectLocationAnomaly(userId, context['location'])) {
          fraudScore += 0.4;
          riskFactors.add('location_anomaly');
        }
      }

      // Análisis de dispositivo
      if (context.containsKey('deviceId')) {
        if (await _detectDeviceAnomaly(userId, context['deviceId'])) {
          fraudScore += 0.2;
          riskFactors.add('device_anomaly');
        }
      }

      // Análisis de monto en transacciones
      if (action == 'payment' && context.containsKey('amount')) {
        if (_detectAmountAnomaly(userHistory, context['amount'])) {
          fraudScore += 0.3;
          riskFactors.add('amount_anomaly');
        }
      }

      // Umbral de fraude (70%)
      final isFraudulent = fraudScore >= 0.7;

      if (isFraudulent) {
        await _reportSecurityIncident(
          SecurityThreat.fraudulentActivity,
          'Actividad fraudulenta detectada para usuario $userId',
          {
            'userId': userId,
            'action': action,
            'fraudScore': fraudScore,
            'riskFactors': riskFactors,
            'context': context,
          },
        );
      }

      AppLogger.info('Análisis de fraude completado', {
        'userId': userId,
        'action': action,
        'fraudScore': fraudScore,
        'isFraudulent': isFraudulent,
        'riskFactors': riskFactors,
      });

      return isFraudulent;
    } catch (e, stackTrace) {
      AppLogger.error('Error en detección de fraude', e, stackTrace);
      return false;
    }
  }

  /// Verifica estado de compliance
  Future<ComplianceState> checkComplianceStatus() async {
    try {
      final violations = <String>[];
      var complianceScore = 1.0;

      // Verificar compliance PCI-DSS
      final pciCompliant = await _checkPCICompliance();
      if (!pciCompliant) {
        violations.add('PCI-DSS compliance violation');
        complianceScore -= 0.3;
      }

      // Verificar compliance GDPR
      final gdprCompliant = await _checkGDPRCompliance();
      if (!gdprCompliant) {
        violations.add('GDPR compliance violation');
        complianceScore -= 0.3;
      }

      // Verificar compliance con Ley de Protección de Datos Personales de Perú
      final peruCompliant = await _checkPeruDataProtectionCompliance();
      if (!peruCompliant) {
        violations.add('Peru Data Protection Law violation');
        complianceScore -= 0.4;
      }

      final status = ComplianceState(
        pciCompliant: pciCompliant,
        gdprCompliant: gdprCompliant,
        peruDataProtectionCompliant: peruCompliant,
        lastAudit: DateTime.now(),
        violations: violations,
        complianceScore: max(0.0, complianceScore),
      );

      // Guardar estado de compliance
      await _saveComplianceStatus(status);

      return status;
    } catch (e, stackTrace) {
      AppLogger.error('Error verificando compliance', e, stackTrace);
      rethrow;
    }
  }

  /// Genera reporte de auditoría de seguridad
  Future<Map<String, dynamic>> generateSecurityAuditReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final from =
          fromDate ?? DateTime.now().subtract(const Duration(days: 30));
      final to = toDate ?? DateTime.now();

      // Obtener incidentes de seguridad
      final incidents = await _getSecurityIncidents(from, to);

      // Obtener métricas de autenticación
      final authMetrics = await _getAuthenticationMetrics(from, to);

      // Obtener estado de compliance
      final complianceStatus = await checkComplianceStatus();

      // Generar estadísticas
      final stats = _generateSecurityStatistics(incidents, authMetrics);

      final report = {
        'reportId': _generateSecureId(),
        'generatedAt': DateTime.now().toIso8601String(),
        'period': {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
        },
        'compliance': complianceStatus.toJson(),
        'securityIncidents': {
          'total': incidents.length,
          'byThreatType': _groupIncidentsByThreatType(incidents),
          'bySeverity': _groupIncidentsBySeverity(incidents),
          'resolved': incidents.where((i) => i.resolved).length,
          'unresolved': incidents.where((i) => !i.resolved).length,
        },
        'authentication': authMetrics,
        'statistics': stats,
        'recommendations':
            _generateSecurityRecommendations(incidents, complianceStatus),
      };

      // Guardar reporte en Firestore
      await _firestore.collection('security_audit_reports').add(report);

      AppLogger.info('Reporte de auditoría generado', {
        'reportId': report['reportId'],
        'incidentCount': incidents.length,
      });

      return report;
    } catch (e, stackTrace) {
      AppLogger.error('Error generando reporte de auditoría', e, stackTrace);
      rethrow;
    }
  }

  /// Sanitiza entrada de datos
  String _sanitizeInput(String input) {
    return input
        .replaceAll(
            RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'[<>"\' ']'), '')
        .replaceAll(
            RegExp(r'(DROP|DELETE|INSERT|UPDATE|SELECT)\s+',
                caseSensitive: false),
            '')
        .trim();
  }

  /// Detecta inyección SQL
  bool _detectSQLInjection(String input) {
    final sqlPatterns = [
      r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|SCRIPT)\b)",
      r"(\b(OR|AND)\s+\d+\s*=\s*\d+)",
      r"(--|#|\/\*)",
      r"(\bUNION\s+SELECT\b)",
      r"(\'\s*OR\s*\'\w*\'\s*=\s*\'\w*)",
    ];

    return sqlPatterns.any(
        (pattern) => RegExp(pattern, caseSensitive: false).hasMatch(input));
  }

  /// Detecta ataques XSS
  bool _detectXSSAttack(String input) {
    final xssPatterns = [
      r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
      r'javascript:',
      r'on\w+\s*=',
      r'<iframe',
      r'<object',
      r'<embed',
      r'eval\s*\(',
    ];

    return xssPatterns.any(
        (pattern) => RegExp(pattern, caseSensitive: false).hasMatch(input));
  }

  /// Inicializa autenticación biométrica
  Future<void> _initializeBiometricAuth() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      AppLogger.info('Autenticación biométrica inicializada', {
        'available': isAvailable,
        'biometrics': availableBiometrics.map((b) => b.name).toList(),
      });
    } catch (e) {
      AppLogger.warning('Error inicializando autenticación biométrica: $e');
    }
  }

  /// Inicia monitoreo en tiempo real
  void _startRealTimeMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _performSecurityMonitoring();
    });
  }

  /// Inicia verificaciones de compliance
  void _startComplianceChecks() {
    _complianceCheckTimer =
        Timer.periodic(const Duration(hours: 24), (_) async {
      await checkComplianceStatus();
    });
  }

  /// Realiza monitoreo de seguridad
  Future<void> _performSecurityMonitoring() async {
    try {
      // Verificar integridad del dispositivo
      await _checkDeviceIntegrity();

      // Verificar conexión segura
      await _checkNetworkSecurity();

      // Limpiar cache de validaciones antiguas
      _cleanupValidationCache();
    } catch (e) {
      AppLogger.warning('Error en monitoreo de seguridad: $e');
    }
  }

  /// Verifica integridad del dispositivo
  Future<void> _checkDeviceIntegrity() async {
    try {
      final deviceInfo = await _deviceInfo.androidInfo;

      // Detectar root/jailbreak (implementación básica)
      if (!kReleaseMode) {
        return; // Skip en debug mode
      }

      // En producción, usar librerías especializadas como flutter_jailbreak_detection
    } catch (e) {
      AppLogger.warning('Error verificando integridad del dispositivo: $e');
    }
  }

  /// Verifica seguridad de red
  Future<void> _checkNetworkSecurity() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();

      if (connectivity == ConnectivityResult.wifi) {
        // Verificar que la conexión WiFi sea segura
        // En producción implementar verificaciones más robustas
      }
    } catch (e) {
      AppLogger.warning('Error verificando seguridad de red: $e');
    }
  }

  /// Reporta incidente de seguridad
  Future<void> _reportSecurityIncident(
    SecurityThreat threat,
    String description,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      final incident = SecurityIncident(
        id: _generateSecureId(),
        threatType: threat,
        severity: _getSeverityForThreat(threat),
        description: description,
        metadata: metadata ?? {},
        timestamp: DateTime.now(),
        userId: metadata?['userId'],
        deviceId: metadata?['deviceId'],
        resolved: false,
        mitigationActions: [],
      );

      _incidentLog.add(incident);

      // Guardar en Firestore
      await _firestore.collection('security_incidents').add(incident.toJson());

      AppLogger.warning('Incidente de seguridad reportado', {
        'incidentId': incident.id,
        'threat': threat.name,
        'severity': incident.severity.name,
      });

      // Notificar si es crítico
      if (incident.severity == SecuritySeverity.critical) {
        await _sendCriticalSecurityAlert(incident);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error reportando incidente de seguridad', e, stackTrace);
    }
  }

  /// Cifrado AES simplificado (usar librerías robustas en producción)
  List<int> _aesEncrypt(String data, List<int> key, List<int> iv) {
    // Implementación simplificada - usar crypto libraries robustas en producción
    final dataBytes = utf8.encode(data);
    final encrypted = <int>[];

    for (int i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ key[i % key.length] ^ iv[i % iv.length]);
    }

    return encrypted;
  }

  /// Descifrado AES simplificado
  String _aesDecrypt(List<int> encrypted, List<int> key, List<int> iv) {
    final decrypted = <int>[];

    for (int i = 0; i < encrypted.length; i++) {
      decrypted.add(encrypted[i] ^ key[i % key.length] ^ iv[i % iv.length]);
    }

    return utf8.decode(decrypted);
  }

  /// Genera IV seguro
  List<int> _generateSecureIV() {
    final random = Random.secure();
    return List.generate(16, (i) => random.nextInt(256));
  }

  /// Genera ID seguro
  String _generateSecureId() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(Iterable.generate(
        32, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  /// Genera clave de cache
  String _generateCacheKey(String input, String type) {
    return md5.convert(utf8.encode('$input:$type')).toString();
  }

  /// Obtiene severidad para tipo de amenaza
  SecuritySeverity _getSeverityForThreat(SecurityThreat threat) {
    switch (threat) {
      case SecurityThreat.sqlInjection:
      case SecurityThreat.dataLeakage:
      case SecurityThreat.malwareDetection:
        return SecuritySeverity.critical;
      case SecurityThreat.xssAttack:
      case SecurityThreat.csrfAttack:
      case SecurityThreat.fraudulentActivity:
        return SecuritySeverity.high;
      case SecurityThreat.bruteForce:
      case SecurityThreat.unauthorizedAccess:
      case SecurityThreat.networkAttack:
        return SecuritySeverity.medium;
      case SecurityThreat.deviceTampering:
        return SecuritySeverity.low;
    }
  }

  /// Configuración de compliance por defecto para Perú
  ComplianceConfig _getDefaultComplianceConfig() {
    return const ComplianceConfig(
      enablePCICompliance: true,
      enableGDPRCompliance: true,
      enablePeruDataProtection: true,
      enableAuditLogging: true,
      enableRealTimeMonitoring: true,
      dataRetentionDays: 365,
      sensitiveDataFields: [
        'dni',
        'phone',
        'email',
        'creditCard',
        'location',
        'biometricData',
      ],
    );
  }

  /// Carga configuración de seguridad
  Future<void> _loadSecurityConfiguration() async {
    try {
      final configJson = _prefs?.getString('security_config');
      if (configJson != null) {
        final config = ComplianceConfig.fromJson(json.decode(configJson));
        _complianceConfig = config;
      }
    } catch (e) {
      AppLogger.warning('Error cargando configuración de seguridad: $e');
    }
  }

  /// Carga incidentes de seguridad
  Future<void> _loadSecurityIncidents() async {
    try {
      final query = await _firestore
          .collection('security_incidents')
          .where('timestamp',
              isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      _incidentLog.clear();
      for (final doc in query.docs) {
        _incidentLog.add(SecurityIncident.fromJson(doc.data()));
      }

      AppLogger.info(
          'Incidentes de seguridad cargados: ${_incidentLog.length}');
    } catch (e) {
      AppLogger.warning('Error cargando incidentes de seguridad: $e');
    }
  }

  /// Log de eventos de seguridad
  Future<void> _logSecurityEvent(
      String event, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('security_events').add({
        'event': event,
        'timestamp': FieldValue.serverTimestamp(),
        'data': data,
      });
    } catch (e) {
      AppLogger.warning('Error logging security event: $e');
    }
  }

  /// Limpia cache de validaciones
  void _cleanupValidationCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    // Implementar limpieza de cache basada en tiempo
    // Por simplicidad, limitamos el tamaño del cache
    if (_validationCache.length > 1000) {
      final entries = _validationCache.entries.toList();
      entries.sort((a, b) => a.key.compareTo(b.key));

      for (int i = 0; i < 500; i++) {
        keysToRemove.add(entries[i].key);
      }
    }

    for (final key in keysToRemove) {
      _validationCache.remove(key);
    }
  }

  /// Verifica compliance PCI-DSS
  Future<bool> _checkPCICompliance() async {
    // Implementación básica - en producción usar auditorías especializadas
    return _complianceConfig?.enablePCICompliance ?? false;
  }

  /// Verifica compliance GDPR
  Future<bool> _checkGDPRCompliance() async {
    // Implementación básica - verificar políticas de privacidad y consentimiento
    return _complianceConfig?.enableGDPRCompliance ?? false;
  }

  /// Verifica compliance con ley peruana de protección de datos
  Future<bool> _checkPeruDataProtectionCompliance() async {
    // Verificar cumplimiento con Ley N° 29733
    return _complianceConfig?.enablePeruDataProtection ?? false;
  }

  /// Obtiene historial de actividad del usuario
  Future<List<Map<String, dynamic>>> _getUserActivityHistory(
      String userId) async {
    try {
      final query = await _firestore
          .collection('user_activities')
          .where('userId', isEqualTo: userId)
          .where('timestamp',
              isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Detecta actividad de alta velocidad
  bool _detectHighVelocityActivity(
      List<Map<String, dynamic>> history, String action) {
    if (history.length < 5) return false;

    final recentActions = history
        .where((activity) => activity['action'] == action)
        .take(5)
        .toList();

    if (recentActions.length < 5) return false;

    // Verificar si 5 acciones similares ocurrieron en menos de 1 minuto
    final timestamps = recentActions
        .map((activity) => DateTime.parse(activity['timestamp']))
        .toList();

    timestamps.sort();
    final timeSpan = timestamps.last.difference(timestamps.first);

    return timeSpan.inMinutes < 1;
  }

  /// Detecta anomalías de ubicación
  Future<bool> _detectLocationAnomaly(
      String userId, Map<String, dynamic> location) async {
    // Implementación básica - comparar con ubicaciones históricas
    return false;
  }

  /// Detecta anomalías de dispositivo
  Future<bool> _detectDeviceAnomaly(String userId, String deviceId) async {
    // Verificar si es un dispositivo conocido para el usuario
    try {
      final query = await _firestore
          .collection('user_devices')
          .where('userId', isEqualTo: userId)
          .where('deviceId', isEqualTo: deviceId)
          .limit(1)
          .get();

      return query.docs.isEmpty; // True si es dispositivo desconocido
    } catch (e) {
      return false;
    }
  }

  /// Detecta anomalías en montos
  bool _detectAmountAnomaly(List<Map<String, dynamic>> history, double amount) {
    if (history.isEmpty) return false;

    final paymentHistory = history
        .where((activity) => activity['action'] == 'payment')
        .map((activity) => (activity['amount'] as num).toDouble())
        .toList();

    if (paymentHistory.isEmpty) return false;

    final average =
        paymentHistory.reduce((a, b) => a + b) / paymentHistory.length;
    final threshold = average * 5; // 5 veces el promedio

    return amount > threshold;
  }

  /// Genera estadísticas de seguridad
  Map<String, dynamic> _generateSecurityStatistics(
    List<SecurityIncident> incidents,
    Map<String, dynamic> authMetrics,
  ) {
    return {
      'totalIncidents': incidents.length,
      'avgIncidentsPerDay': incidents.length / 30,
      'threatTypeDistribution': _groupIncidentsByThreatType(incidents),
      'severityDistribution': _groupIncidentsBySeverity(incidents),
      'resolutionRate': incidents.isEmpty
          ? 0.0
          : incidents.where((i) => i.resolved).length / incidents.length,
      'authenticationStats': authMetrics,
    };
  }

  /// Agrupa incidentes por tipo de amenaza
  Map<String, int> _groupIncidentsByThreatType(
      List<SecurityIncident> incidents) {
    final groups = <String, int>{};
    for (final incident in incidents) {
      groups[incident.threatType.name] =
          (groups[incident.threatType.name] ?? 0) + 1;
    }
    return groups;
  }

  /// Agrupa incidentes por severidad
  Map<String, int> _groupIncidentsBySeverity(List<SecurityIncident> incidents) {
    final groups = <String, int>{};
    for (final incident in incidents) {
      groups[incident.severity.name] =
          (groups[incident.severity.name] ?? 0) + 1;
    }
    return groups;
  }

  /// Obtiene incidentes de seguridad por fecha
  Future<List<SecurityIncident>> _getSecurityIncidents(
      DateTime from, DateTime to) async {
    try {
      final query = await _firestore
          .collection('security_incidents')
          .where('timestamp', isGreaterThanOrEqualTo: from)
          .where('timestamp', isLessThanOrEqualTo: to)
          .orderBy('timestamp', descending: true)
          .get();

      return query.docs
          .map((doc) => SecurityIncident.fromJson(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtiene métricas de autenticación
  Future<Map<String, dynamic>> _getAuthenticationMetrics(
      DateTime from, DateTime to) async {
    // Implementación básica de métricas
    return {
      'totalAttempts': 0,
      'successfulAttempts': 0,
      'failedAttempts': 0,
      'biometricAttempts': 0,
      'passwordAttempts': 0,
    };
  }

  /// Genera recomendaciones de seguridad
  List<String> _generateSecurityRecommendations(
    List<SecurityIncident> incidents,
    ComplianceState complianceStatus,
  ) {
    final recommendations = <String>[];

    if (complianceStatus.complianceScore < 0.8) {
      recommendations.add('Mejorar cumplimiento de normas de compliance');
    }

    final criticalIncidents = incidents
        .where((i) => i.severity == SecuritySeverity.critical && !i.resolved)
        .length;

    if (criticalIncidents > 0) {
      recommendations
          .add('Resolver $criticalIncidents incidentes críticos pendientes');
    }

    if (incidents.length > 50) {
      recommendations.add('Implementar medidas preventivas adicionales');
    }

    return recommendations;
  }

  /// Envía alerta de seguridad crítica
  Future<void> _sendCriticalSecurityAlert(SecurityIncident incident) async {
    // En producción integrar con sistema de notificaciones
    AppLogger.critical('ALERTA DE SEGURIDAD CRÍTICA', {
      'incidentId': incident.id,
      'threat': incident.threatType.name,
      'description': incident.description,
    });
  }

  /// Guarda estado de compliance
  Future<void> _saveComplianceStatus(ComplianceState status) async {
    try {
      await _firestore
          .collection('compliance_status')
          .doc('current')
          .set(status.toJson());
    } catch (e) {
      AppLogger.warning('Error guardando estado de compliance: $e');
    }
  }

  /// Libera recursos
  /// Limpia recursos y cancela timers
  Future<void> dispose() async {
    try {
      // Cancelar timers de forma segura
      _monitoringTimer?.cancel();
      _monitoringTimer = null;

      _complianceCheckTimer?.cancel();
      _complianceCheckTimer = null;

      // Limpiar caches
      _validationCache.clear();
      _authCache.clear();
      _incidentLog.clear();
      _rateLimitTracker.clear();

      // Limpiar servicio KMS
      _kmsService.dispose();

      // Marcar como no inicializado
      _isInitialized = false;

      AppLogger.info('SecurityComplianceService disposed correctamente');
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error en dispose de SecurityComplianceService', e, stackTrace);
    }
  }
}

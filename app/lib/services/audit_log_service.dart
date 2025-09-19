import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'secure_storage_service.dart';
import 'cloud_kms_service.dart';
import '../utils/app_logger.dart';

/// Severidad del evento de auditoría
enum AuditSeverity { low, info, medium, high, warning, critical }

/// Formato de exportación para los logs de auditoría
enum AuditExportFormat { json, csv }

/// Servicio de Audit Logging para cumplimiento regulatorio
/// Registra todas las acciones críticas para auditoría y compliance
class AuditLogService {
  static final AuditLogService _instance = AuditLogService._internal();
  factory AuditLogService() => _instance;
  AuditLogService._internal();

  final SecureStorageService _secureStorage = SecureStorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudKmsService _kmsService = CloudKmsService();

  // Buffer local de logs
  final Queue<AuditLog> _localBuffer = Queue<AuditLog>();
  static const int maxBufferSize = 100;

  // Configuración
  static const String collectionName = 'audit_logs';
  static const Duration syncInterval = Duration(minutes: 5);
  bool _isInitialized = false;
  String? _userId;
  String? _deviceId;
  String? _sessionId;

  /// Tipos de eventos auditables
  static const String authLogin = 'AUTH_LOGIN';
  static const String authLogout = 'AUTH_LOGOUT';
  static const String authFailed = 'AUTH_FAILED';
  static const String authRegister = 'AUTH_REGISTER';
  static const String authPasswordChange = 'AUTH_PASSWORD_CHANGE';
  static const String authBiometric = 'AUTH_BIOMETRIC';
  static const String auth2FA = 'AUTH_2FA';

  static const String paymentInitiated = 'PAYMENT_INITIATED';
  static const String paymentCompleted = 'PAYMENT_COMPLETED';
  static const String paymentFailed = 'PAYMENT_FAILED';
  static const String paymentRefunded = 'PAYMENT_REFUNDED';

  static const String dataAccess = 'DATA_ACCESS';
  static const String dataModify = 'DATA_MODIFY';
  static const String dataDelete = 'DATA_DELETE';
  static const String dataExport = 'DATA_EXPORT';

  static const String privacyConsent = 'PRIVACY_CONSENT';
  static const String privacyWithdraw = 'PRIVACY_WITHDRAW';
  static const String privacyDataRequest = 'PRIVACY_DATA_REQUEST';
  static const String privacyDataDelete = 'PRIVACY_DATA_DELETE';

  static const String securityThreat = 'SECURITY_THREAT';
  static const String securityBreach = 'SECURITY_BREACH';
  static const String securityRootDetected = 'SECURITY_ROOT_DETECTED';
  static const String securityTampering = 'SECURITY_TAMPERING';

  static const String rideRequested = 'RIDE_REQUESTED';
  static const String rideAccepted = 'RIDE_ACCEPTED';
  static const String rideStarted = 'RIDE_STARTED';
  static const String rideCompleted = 'RIDE_COMPLETED';
  static const String rideCancelled = 'RIDE_CANCELLED';
  static const String rideEmergency = 'RIDE_EMERGENCY';

  static const String adminAccess = 'ADMIN_ACCESS';
  static const String adminModify = 'ADMIN_MODIFY';
  static const String adminUserSuspend = 'ADMIN_USER_SUSPEND';
  static const String adminUserActivate = 'ADMIN_USER_ACTIVATE';
  static const String adminConfigChange = 'ADMIN_CONFIG_CHANGE';

  /// Inicializa el servicio de auditoría
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {
    _userId = userId;
    _deviceId = deviceId;
    _sessionId = _generateSessionId();
    _isInitialized = true;

    // Inicializar servicio KMS para cifrado
    try {
      await _kmsService.initialize();
      AppLogger.info('✅ Servicio KMS inicializado para audit logs');
    } catch (e) {
      AppLogger.warning('⚠️ KMS no disponible, usando cifrado local: $e');
    }

    // Cargar logs pendientes
    await _loadPendingLogs();

    // Iniciar sincronización periódica
    _startPeriodicSync();

    // Log de inicio de sesión
    await logEvent(
      eventType: authLogin,
      description: 'Sesión iniciada',
      metadata: {
        'deviceId': deviceId,
        'sessionId': _sessionId,
      },
    );
  }

  /// Registra un evento auditable
  Future<void> logEvent({
    required String eventType,
    required String description,
    Map<String, dynamic>? metadata,
    AuditSeverity severity = AuditSeverity.info,
    bool critical = false,
  }) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        AppLogger.warning('⚠️ AuditLogService no inicializado');
      }
      return;
    }

    final log = AuditLog(
      id: _generateLogId(),
      timestamp: DateTime.now(),
      userId: _userId!,
      deviceId: _deviceId!,
      sessionId: _sessionId!,
      eventType: eventType,
      description: description,
      metadata: _sanitizeMetadata(metadata),
      severity: severity,
      ipAddress: await _getIpAddress(),
      userAgent: _getUserAgent(),
      appVersion: await _getAppVersion(),
    );

    // Si es crítico, sincronizar inmediatamente sin agregar al buffer
    if (critical) {
      await _syncSingleLog(log);
    } else {
      // Solo agregar al buffer si no es crítico
      _addToBuffer(log);
    }

    if (kDebugMode) {
      _logFormattedLog(log);
    }
  }

  /// Log de acceso a datos sensibles
  Future<void> logDataAccess({
    required String dataType,
    required String dataId,
    required String purpose,
    Map<String, dynamic>? additionalInfo,
  }) async {
    await logEvent(
      eventType: dataAccess,
      description: 'Acceso a $dataType',
      metadata: {
        'dataType': dataType,
        'dataId': dataId,
        'purpose': purpose,
        ...?additionalInfo,
      },
      severity: AuditSeverity.medium,
    );
  }

  /// Log de transacción de pago
  Future<void> logPaymentTransaction({
    required String transactionId,
    required String type,
    required double amount,
    required String currency,
    required String status,
    String? paymentMethod,
    Map<String, dynamic>? additionalInfo,
  }) async {
    String eventType;
    AuditSeverity severity;

    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        eventType = paymentCompleted;
        severity = AuditSeverity.high;
        break;
      case 'failed':
      case 'error':
        eventType = paymentFailed;
        severity = AuditSeverity.warning;
        break;
      case 'refunded':
        eventType = paymentRefunded;
        severity = AuditSeverity.high;
        break;
      default:
        eventType = paymentInitiated;
        severity = AuditSeverity.medium;
    }

    await logEvent(
      eventType: eventType,
      description: 'Transacción de pago: $type',
      metadata: {
        'transactionId': transactionId,
        'amount': amount,
        'currency': currency,
        'status': status,
        'paymentMethod': paymentMethod ?? 'unknown',
        ...?additionalInfo,
      },
      severity: severity,
      critical: true, // Pagos siempre son críticos
    );
  }

  /// Log de evento de seguridad
  Future<void> logSecurityEvent({
    required String threatType,
    required String description,
    Map<String, dynamic>? threatDetails,
    required AuditSeverity severity,
  }) async {
    String eventType;

    switch (threatType.toLowerCase()) {
      case 'breach':
        eventType = securityBreach;
        break;
      case 'root':
      case 'jailbreak':
        eventType = securityRootDetected;
        break;
      case 'tampering':
        eventType = securityTampering;
        break;
      default:
        eventType = securityThreat;
    }

    await logEvent(
      eventType: eventType,
      description: 'Evento de seguridad: $description',
      metadata: {
        'threatType': threatType,
        'threatDetails': threatDetails,
        'detectionTime': DateTime.now().toIso8601String(),
      },
      severity: severity,
      critical: true,
    );
  }

  /// Log de acción administrativa
  Future<void> logAdminAction({
    required String action,
    required String targetUserId,
    required String description,
    Map<String, dynamic>? changes,
  }) async {
    String eventType;

    switch (action.toLowerCase()) {
      case 'suspend':
        eventType = adminUserSuspend;
        break;
      case 'activate':
        eventType = adminUserActivate;
        break;
      case 'modify':
        eventType = adminModify;
        break;
      case 'config':
        eventType = adminConfigChange;
        break;
      default:
        eventType = adminAccess;
    }

    await logEvent(
      eventType: eventType,
      description: 'Acción administrativa: $description',
      metadata: {
        'action': action,
        'targetUserId': targetUserId,
        'changes': changes,
        'adminId': _userId,
      },
      severity: AuditSeverity.critical,
      critical: true,
    );
  }

  /// Log de consentimiento de privacidad
  Future<void> logPrivacyConsent({
    required String consentType,
    required bool granted,
    required String version,
    Map<String, dynamic>? details,
  }) async {
    await logEvent(
      eventType: granted ? privacyConsent : privacyWithdraw,
      description: 'Consentimiento de privacidad: $consentType',
      metadata: {
        'consentType': consentType,
        'granted': granted,
        'version': version,
        'timestamp': DateTime.now().toIso8601String(),
        ...?details,
      },
      severity: AuditSeverity.high,
      critical: true,
    );
  }

  /// Obtiene logs para auditoría
  Future<List<AuditLog>> getAuditLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? eventType,
    String? userId,
    int limit = 100,
  }) async {
    Query query = _firestore.collection(collectionName);

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: endDate);
    }

    if (eventType != null) {
      query = query.where('eventType', isEqualTo: eventType);
    }

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    query = query.orderBy('timestamp', descending: true).limit(limit);

    final snapshot = await query.get();

    // Descifrar logs antes de retornar
    final logs = await Future.wait(snapshot.docs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;
      final decryptedData = await _decryptLog(data);
      return AuditLog.fromJson(decryptedData);
    }));

    return logs;
  }

  /// Alias para queryLogs (compatibilidad)
  Future<List<AuditLog>> queryLogs({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
    String? eventType,
    AuditSeverity? severity,
    int limit = 100,
  }) async {
    return getAuditLogs(
      startDate: startDate,
      endDate: endDate,
      eventType: eventType,
      userId: userId,
      limit: limit,
    );
  }

  /// Exporta logs para compliance
  Future<String> exportLogsForCompliance({
    required DateTime startDate,
    required DateTime endDate,
    required String format, // 'json', 'csv'
  }) async {
    final logs = await getAuditLogs(
      startDate: startDate,
      endDate: endDate,
      limit: 10000,
    );

    if (format == 'json') {
      return _exportAsJson(logs);
    } else if (format == 'csv') {
      return _exportAsCsv(logs);
    } else {
      throw ArgumentError('Formato no soportado: $format');
    }
  }

  // Métodos privados

  void _addToBuffer(AuditLog log) {
    _localBuffer.add(log);

    // Limitar tamaño del buffer
    while (_localBuffer.length > maxBufferSize) {
      _localBuffer.removeFirst();
    }

    // Guardar en storage local
    _savePendingLogs();
  }

  Future<void> _syncSingleLog(AuditLog log) async {
    try {
      // Cifrar datos sensibles
      final encryptedLog = await _encryptLog(log);

      // Enviar a Firestore
      await _firestore.collection(collectionName).doc(log.id).set(encryptedLog);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('Error sincronizando log', e);
      }
    }
  }

  Future<void> _syncBufferedLogs() async {
    if (_localBuffer.isEmpty) return;

    final batch = _firestore.batch();
    final logsToSync = List<AuditLog>.from(_localBuffer);

    for (final log in logsToSync) {
      try {
        final encryptedLog = await _encryptLog(log);
        final docRef = _firestore.collection(collectionName).doc(log.id);
        batch.set(docRef, encryptedLog);
      } catch (e) {
        if (kDebugMode) {
          AppLogger.error('Error preparando log para sync', e);
        }
      }
    }

    try {
      await batch.commit();
      _localBuffer.clear();
      await _clearPendingLogs();
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('Error en batch sync', e);
      }
    }
  }

  void _startPeriodicSync() {
    Stream.periodic(syncInterval).listen((_) {
      _syncBufferedLogs();
    });
  }

  Future<Map<String, dynamic>> _encryptLog(AuditLog log) async {
    // Sanitizar metadata primero
    final sanitizedMetadata = _sanitizeMetadata(log.metadata);

    // Datos sensibles a cifrar
    final sensitiveData = {
      'metadata': sanitizedMetadata,
      'ipAddress': log.ipAddress,
      'userAgent': log.userAgent,
    };

    // Cifrar datos sensibles usando KMS si está disponible
    String encryptedData;
    bool encryptionUsed = false;

    try {
      // Check if KMS service is available and initialized
      bool kmsAvailable = false;
      try {
        kmsAvailable = _kmsService.isInitialized;
      } catch (e) {
        AppLogger.debug('KMS service not available: $e');
      }

      if (kmsAvailable) {
        // Usar Cloud KMS para cifrado
        final dataBytes = Uint8List.fromList(
          utf8.encode(jsonEncode(sensitiveData)),
        );
        final encrypted = await _kmsService.encryptData(dataBytes);
        encryptedData = base64.encode(encrypted);
        encryptionUsed = true;
        AppLogger.debug('Log cifrado con Cloud KMS');
      } else {
        // Fallback: codificar en base64 (ofuscación básica)
        encryptedData = base64.encode(utf8.encode(jsonEncode(sensitiveData)));
        AppLogger.debug('Log almacenado con codificación base64 (KMS no disponible)');
      }
    } catch (e) {
      AppLogger.warning('Error al cifrar log: $e');
      // Fallback secundario: base64 encoding
      encryptedData = base64.encode(utf8.encode(jsonEncode(sensitiveData)));
    }

    final logData = log.toJson();
    // Replace timestamp string with server timestamp
    logData['timestamp'] = FieldValue.serverTimestamp();
    logData['timestampIso'] = log.timestamp.toIso8601String(); // Keep ISO string as backup

    return {
      ...logData,
      'metadata': null, // Remover metadata sin cifrar
      'ipAddress': null, // Remover IP sin cifrar
      'userAgent': null, // Remover userAgent sin cifrar
      'encryptedData': encryptedData,
      'encrypted': encryptionUsed,
      'encryptionMethod': encryptionUsed ? 'cloud_kms' : 'local',
    };
  }

  Map<String, dynamic>? _sanitizeMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;

    // Remover información muy sensible
    final sanitized = Map<String, dynamic>.from(metadata);

    // Lista de campos a remover o enmascarar
    const sensitiveFields = [
      'password',
      'pin',
      'cvv',
      'securityCode',
      'creditCard',
      'bankAccount',
      'ssn',
    ];

    for (final field in sensitiveFields) {
      if (sanitized.containsKey(field)) {
        sanitized[field] = '***REDACTED***';
      }
    }

    // Enmascarar números de tarjeta
    if (sanitized.containsKey('cardNumber')) {
      final card = sanitized['cardNumber'].toString();
      if (card.length > 4) {
        sanitized['cardNumber'] =
            '**** **** **** ${card.substring(card.length - 4)}';
      }
    }

    return sanitized;
  }

  String _generateLogId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_userId}_${_generateRandomString(8)}';
  }

  String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(12)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(length, (index) {
      return chars[random.nextInt(chars.length)];
    }).join();
  }

  Future<String> _getIpAddress() async {
    // En producción, obtener IP real
    return '0.0.0.0';
  }

  String _getUserAgent() {
    return 'OasisTaxi/1.0 (Flutter)';
  }

  Future<String> _getAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      AppLogger.warning('Could not get app version: $e');
      return '1.0.0+1'; // Fallback version
    }
  }

  Future<void> _savePendingLogs() async {
    final logsJson = _localBuffer.map((log) => log.toJson()).toList();
    await _secureStorage.setSecureJson('pending_audit_logs', {
      'logs': logsJson,
    });
  }

  Future<void> _loadPendingLogs() async {
    final data = await _secureStorage.getSecureJson('pending_audit_logs');
    if (data != null && data['logs'] != null) {
      final logs = (data['logs'] as List).map((json) {
        return AuditLog.fromJson(json);
      }).toList();

      _localBuffer.addAll(logs);
    }
  }

  Future<void> _clearPendingLogs() async {
    await _secureStorage.remove('pending_audit_logs');
  }

  String _exportAsJson(List<AuditLog> logs) {
    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalLogs': logs.length,
      'logs': logs.map((log) => log.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  /// Exportar logs con descifrado
  Future<String> exportLogsDecrypted({
    required DateTime startDate,
    required DateTime endDate,
    AuditExportFormat format = AuditExportFormat.json,
    String? eventType,
  }) async {
    // Obtener logs del período
    final logs = await queryLogs(
      startDate: startDate,
      endDate: endDate,
      eventType: eventType,
    );

    // Los logs ya vienen descifrados del método queryLogs
    switch (format) {
      case AuditExportFormat.json:
        return _exportAsJson(logs);
      case AuditExportFormat.csv:
        return _exportAsCsv(logs);
    }
  }

  String _exportAsCsv(List<AuditLog> logs) {
    final buffer = StringBuffer();

    // Headers
    buffer.writeln(
        'ID,Timestamp,UserID,EventType,Description,Severity,IPAddress');

    // Data
    for (final log in logs) {
      buffer.writeln(
        '${log.id},'
        '${log.timestamp.toIso8601String()},'
        '${log.userId},'
        '${log.eventType},'
        '"${log.description}",'
        '${log.severity.name},'
        '${log.ipAddress}',
      );
    }

    return buffer.toString();
  }

  void _logFormattedLog(AuditLog log) {
    final icon = _getIconForSeverity(log.severity);
    AppLogger.info('$icon [AUDIT] ${log.eventType}: ${log.description}');
    if (log.metadata != null && log.metadata!.isNotEmpty) {
      AppLogger.debug('   Metadata: ${jsonEncode(log.metadata)}');
    }
  }

  String _getIconForSeverity(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.low:
        return '📝';
      case AuditSeverity.info:
        return 'ℹ️';
      case AuditSeverity.medium:
        return '⚠️';
      case AuditSeverity.high:
        return '🔴';
      case AuditSeverity.warning:
        return '⚡';
      case AuditSeverity.critical:
        return '🚨';
    }
  }

  /// Método sobrecargado simple para logSecurityEvent usado por security_monitor_service
  Future<void> logSecurityEventSimple(
      String eventType, Map<String, dynamic> details) async {
    // Mapear el eventType simple a los parámetros requeridos del método principal
    await logSecurityEvent(
      threatType: eventType,
      description: details['description'] ?? 'Evento de seguridad detectado',
      threatDetails: details,
      severity: AuditSeverity.high,
    );
  }

  /// Obtener logs desde una fecha específica
  Future<List<AuditLog>> getLogsSince(DateTime since,
      {String? eventType}) async {
    try {
      // Primero buscar en el buffer local
      final localLogs = _localBuffer.where((log) {
        final matchesTime = log.timestamp.isAfter(since);
        final matchesType = eventType == null || log.eventType == eventType;
        return matchesTime && matchesType;
      }).toList();

      // Si hay suficientes logs locales, retornarlos
      if (localLogs.length >= 10) {
        return localLogs;
      }

      // Buscar en Firestore
      Query query = _firestore
          .collection(collectionName)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('timestamp', descending: true)
          .limit(100);

      if (eventType != null) {
        query = query.where('eventType', isEqualTo: eventType);
      }

      final snapshot = await query.get();

      // Descifrar logs de Firestore
      final firestoreLogs = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        final decryptedData = await _decryptLog(data);
        return AuditLog.fromJson(decryptedData);
      }));

      // Combinar logs locales y de Firestore
      final allLogs = [...localLogs, ...firestoreLogs];

      // Ordenar por timestamp descendente
      allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allLogs;
    } catch (e) {
      AppLogger.error('Error obteniendo logs desde $since', e);
      return [];
    }
  }

  /// Descifrar log encriptado
  Future<Map<String, dynamic>> _decryptLog(Map<String, dynamic> encryptedLog) async {
    try {
      // Si el log no está encriptado, devolverlo tal cual
      if (!encryptedLog.containsKey('encryptedData')) {
        return encryptedLog;
      }

      final encryptedData = encryptedLog['encryptedData'] as String;
      final encryptionMethod = encryptedLog['encryptionMethod'] as String?;

      Map<String, dynamic> decryptedData;

      // Check if KMS is available for decryption
      bool kmsAvailable = false;
      try {
        kmsAvailable = _kmsService.isInitialized;
      } catch (e) {
        AppLogger.debug('KMS service not available for decryption: $e');
      }

      if (encryptionMethod == 'cloud_kms' && kmsAvailable) {
        // Descifrar con Cloud KMS
        try {
          final encryptedBytes = base64.decode(encryptedData);
          final decryptedBytes = await _kmsService.decryptData(Uint8List.fromList(encryptedBytes));
          final decryptedJson = utf8.decode(decryptedBytes);
          decryptedData = jsonDecode(decryptedJson);
          AppLogger.debug('Log descifrado con Cloud KMS');
        } catch (e) {
          // Si falla KMS, intentar con base64
          AppLogger.warning('Error al descifrar con KMS, usando base64: $e');
          final decodedBytes = base64.decode(encryptedData);
          final decodedJson = utf8.decode(decodedBytes);
          decryptedData = jsonDecode(decodedJson);
        }
      } else {
        // Descifrar con base64 (fallback)
        final decodedBytes = base64.decode(encryptedData);
        final decodedJson = utf8.decode(decodedBytes);
        decryptedData = jsonDecode(decodedJson);
        AppLogger.debug('Log decodificado con base64');
      }

      // Reconstruir el log completo con datos descifrados
      final completeLog = Map<String, dynamic>.from(encryptedLog);
      completeLog.remove('encryptedData');
      completeLog.remove('encrypted');
      completeLog.remove('encryptionMethod');

      // Restaurar campos descifrados
      if (decryptedData.containsKey('metadata')) {
        completeLog['metadata'] = decryptedData['metadata'];
      }
      if (decryptedData.containsKey('ipAddress')) {
        completeLog['ipAddress'] = decryptedData['ipAddress'];
      }
      if (decryptedData.containsKey('userAgent')) {
        completeLog['userAgent'] = decryptedData['userAgent'];
      }

      return completeLog;
    } catch (e) {
      AppLogger.error('Error al descifrar log', e);
      // Devolver el log sin los datos sensibles si no se puede descifrar
      final safeLog = Map<String, dynamic>.from(encryptedLog);
      safeLog.remove('encryptedData');
      return safeLog;
    }
  }
}

/// Modelo de log de auditoría
class AuditLog {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String deviceId;
  final String sessionId;
  final String eventType;
  final String description;
  final Map<String, dynamic>? metadata;
  final AuditSeverity severity;
  final String? ipAddress;
  final String? userAgent;
  final String? appVersion;

  AuditLog({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.deviceId,
    required this.sessionId,
    required this.eventType,
    required this.description,
    this.metadata,
    required this.severity,
    this.ipAddress,
    this.userAgent,
    this.appVersion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'userId': userId,
        'deviceId': deviceId,
        'sessionId': sessionId,
        'eventType': eventType,
        'description': description,
        'metadata': metadata,
        'severity': severity.name,
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'appVersion': appVersion,
      };

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    // Handle both Timestamp and String formats for timestamp
    DateTime timestamp;
    if (json['timestamp'] is Timestamp) {
      timestamp = (json['timestamp'] as Timestamp).toDate();
    } else if (json['timestamp'] is String) {
      timestamp = DateTime.parse(json['timestamp']);
    } else if (json['timestampIso'] != null) {
      timestamp = DateTime.parse(json['timestampIso']);
    } else {
      timestamp = DateTime.now();
    }

    return AuditLog(
        id: json['id'],
        timestamp: timestamp,
        userId: json['userId'],
        deviceId: json['deviceId'],
        sessionId: json['sessionId'],
        eventType: json['eventType'],
        description: json['description'],
        metadata: json['metadata'],
        severity: AuditSeverity.values.firstWhere(
          (e) => e.name == json['severity'],
          orElse: () => AuditSeverity.info,
        ),
        ipAddress: json['ipAddress'],
        userAgent: json['userAgent'],
        appVersion: json['appVersion'],
      );
  }


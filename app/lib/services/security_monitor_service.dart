import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/app_logger.dart';
import 'secure_storage_service.dart';
import 'device_security_service.dart';
import 'biometric_auth_service.dart';
import 'audit_log_service.dart';

/// Servicio de monitoreo de seguridad para OasisTaxi Peru
/// Detecta amenazas en tiempo real y mantiene métricas de seguridad
/// Integra todos los sistemas de seguridad para proporcionar una vista unificada
class SecurityMonitorService {
  static final SecurityMonitorService _instance =
      SecurityMonitorService._internal();
  factory SecurityMonitorService() => _instance;
  SecurityMonitorService._internal();

  final SecureStorageService _secureStorage = SecureStorageService();
  final DeviceSecurityService _deviceSecurity = DeviceSecurityService();
  final BiometricAuthService _biometricAuth = BiometricAuthService();
  final AuditLogService _auditLog = AuditLogService();

  // Estado del monitoreo
  bool _isMonitoring = false;
  bool _isInitialized = false;
  Timer? _monitoringTimer;
  Timer? _reportTimer;

  // Callbacks para eventos de seguridad
  Function(SecurityThreat threat)? _threatDetectedCallback;
  Function(SecurityStatus status)? _securityStatusCallback;
  Function(String alert)? _criticalAlertCallback;

  // Métricas de seguridad
  double _currentSecurityScore = 100.0;
  final List<SecurityThreat> _activeThreats = [];
  final List<SecurityThreat> _threatHistory = [];
  int _totalIncidents = 0;
  int _blockedAttempts = 0;
  DateTime? _lastThreatDetection;

  // Configuración de monitoreo
  static const Duration monitoringInterval = Duration(seconds: 30);
  static const Duration reportingInterval = Duration(minutes: 5);
  static const int maxThreatHistory = 100;
  static const double criticalScoreThreshold = 30.0;
  static const double warningScoreThreshold = 60.0;

  // Contadores de eventos por tipo
  final Map<String, int> _threatCounters = {
    'device_tampered': 0,
    'app_tampered': 0,
    'security_bypass': 0,
    'unusual_activity': 0,
    'brute_force': 0,
    'network_attack': 0,
    'malware_detected': 0,
    'permission_abuse': 0,
  };

  // Sistema de scoring dinámico
  final Map<String, double> _threatWeights = {
    'device_tampered': -40.0, // Root/Jailbreak detectado
    'app_tampered': -30.0, // Aplicación modificada
    'security_bypass': -35.0, // Intento de bypass de seguridad
    'unusual_activity': -15.0, // Actividad inusual
    'brute_force': -25.0, // Intentos de fuerza bruta
    'network_attack': -20.0, // Ataques de red
    'malware_detected': -50.0, // Malware en dispositivo
    'permission_abuse': -10.0, // Abuso de permisos
  };

  /// Inicializa el servicio de monitoreo de seguridad
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('Inicializando Security Monitor Service');

      // Inicializar servicios dependientes
      await _deviceSecurity.initialize();
      await _biometricAuth.initialize();
      await _auditLog.initialize(
        userId: 'system',
        deviceId: 'security-monitor',
      );

      // Cargar métricas históricas
      await _loadHistoricalMetrics();

      // Realizar verificación inicial de seguridad
      await _performInitialSecurityCheck();

      _isInitialized = true;
      AppLogger.info('Security Monitor Service inicializado correctamente');
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error inicializando Security Monitor Service', e, stackTrace);
      rethrow;
    }
  }

  /// Carga métricas históricas desde storage seguro
  Future<void> _loadHistoricalMetrics() async {
    try {
      // Cargar contador de incidentes
      final incidentsStr =
          await _secureStorage.getSecureString('total_incidents');
      if (incidentsStr != null) {
        _totalIncidents = int.tryParse(incidentsStr) ?? 0;
      }

      // Cargar intentos bloqueados
      final blockedStr =
          await _secureStorage.getSecureString('blocked_attempts');
      if (blockedStr != null) {
        _blockedAttempts = int.tryParse(blockedStr) ?? 0;
      }

      // Cargar historial de amenazas
      final threatHistoryStr =
          await _secureStorage.getSecureString('threat_history');
      if (threatHistoryStr != null) {
        final historyData = jsonDecode(threatHistoryStr) as List<dynamic>;
        _threatHistory.clear();
        _threatHistory.addAll(
          historyData.map(
              (item) => SecurityThreat.fromJson(item as Map<String, dynamic>)),
        );
      }

      // Cargar contadores por tipo
      final countersStr =
          await _secureStorage.getSecureString('threat_counters');
      if (countersStr != null) {
        final countersData = jsonDecode(countersStr) as Map<String, dynamic>;
        _threatCounters.addAll(
          countersData.map((key, value) => MapEntry(key, value as int)),
        );
      }

      // Recalcular score basado en historial
      _recalculateSecurityScore();
    } catch (e) {
      AppLogger.warning('No se pudieron cargar métricas históricas: $e');
    }
  }

  /// Realiza verificación inicial completa de seguridad
  Future<void> _performInitialSecurityCheck() async {
    AppLogger.info('Realizando verificación inicial de seguridad');

    try {
      // Verificar seguridad del dispositivo
      final deviceStatus = await _deviceSecurity.performSecurityCheck();

      if (!deviceStatus['isSecure']) {
        final issues = deviceStatus['issues'] as List<String>;
        for (final issue in issues) {
          await _reportThreat(SecurityThreat(
            type: 'device_tampered',
            description: issue,
            severity: 'critical',
            timestamp: DateTime.now(),
          ));
        }
      }

      // Verificar integridad de la aplicación
      await _checkApplicationIntegrity();

      // Verificar configuración de biometría
      await _checkBiometricSecurity();

      // Verificar permisos inusuales
      await _checkPermissions();

      AppLogger.info('Verificación inicial de seguridad completada');
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error en verificación inicial de seguridad', e, stackTrace);
    }
  }

  /// Verifica la integridad de la aplicación
  Future<void> _checkApplicationIntegrity() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      // Verificar si la app está en modo debug en producción
      if (kDebugMode && packageInfo.version.contains('1.0')) {
        await _reportThreat(SecurityThreat(
          type: 'app_tampered',
          description: 'Aplicación ejecutándose en modo debug en producción',
          severity: 'high',
          timestamp: DateTime.now(),
        ));
      }

      // Verificar signature de la app (en Android)
      if (Platform.isAndroid) {
        final shouldBlock = await _deviceSecurity.shouldBlockApp();
        if (shouldBlock) {
          await _reportThreat(SecurityThreat(
            type: 'app_tampered',
            description: 'Signature de la aplicación no válida',
            severity: 'critical',
            timestamp: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      AppLogger.error('Error verificando integridad de aplicación', e);
    }
  }

  /// Verifica la configuración de seguridad biométrica
  Future<void> _checkBiometricSecurity() async {
    try {
      final isAvailable = await _biometricAuth.isBiometricAvailable();

      if (!isAvailable) {
        await _reportThreat(SecurityThreat(
          type: 'security_bypass',
          description: 'Biometría no disponible o deshabilitada',
          severity: 'medium',
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      AppLogger.error('Error verificando seguridad biométrica', e);
    }
  }

  /// Verifica permisos sospechosos
  Future<void> _checkPermissions() async {
    try {
      // En una implementación real, verificar permisos usando permission_handler
      // Por ahora, simulamos la verificación
      final suspiciousPermissions = await _detectSuspiciousPermissions();

      if (suspiciousPermissions.isNotEmpty) {
        await _reportThreat(SecurityThreat(
          type: 'permission_abuse',
          description:
              'Permisos sospechosos detectados: ${suspiciousPermissions.join(', ')}',
          severity: 'low',
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      AppLogger.error('Error verificando permisos', e);
    }
  }

  /// Detecta permisos sospechosos
  Future<List<String>> _detectSuspiciousPermissions() async {
    // En una implementación real, usar permission_handler para verificar permisos
    // Por ahora retornamos lista vacía
    return [];
  }

  /// Inicia el monitoreo continuo de seguridad
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      AppLogger.warning('El monitoreo de seguridad ya está activo');
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    AppLogger.info('Iniciando monitoreo continuo de seguridad');

    _isMonitoring = true;

    // Iniciar timer de monitoreo
    _monitoringTimer = Timer.periodic(monitoringInterval, (timer) {
      _performSecurityCheck();
    });

    // Iniciar timer de reportes
    _reportTimer = Timer.periodic(reportingInterval, (timer) {
      _generateSecurityReport();
    });

    // Realizar primera verificación inmediatamente
    await _performSecurityCheck();
  }

  /// Realiza verificación periódica de seguridad
  Future<void> _performSecurityCheck() async {
    if (!_isMonitoring) return;

    try {
      AppLogger.debug('Realizando verificación periódica de seguridad');

      // Verificar estado del dispositivo
      await _checkDeviceStatus();

      // Verificar actividad inusual
      await _checkUnusualActivity();

      // Verificar conexiones de red sospechosas
      await _checkNetworkActivity();

      // Actualizar score de seguridad
      _recalculateSecurityScore();

      // Notificar cambios de estado
      _notifySecurityStatus();
    } catch (e, stackTrace) {
      AppLogger.error(
          'Error en verificación periódica de seguridad', e, stackTrace);
    }
  }

  /// Verifica el estado actual del dispositivo
  Future<void> _checkDeviceStatus() async {
    try {
      // Verificar si el dispositivo sigue siendo seguro
      final deviceStatus = await _deviceSecurity.performSecurityCheck();

      if (!deviceStatus['isSecure']) {
        final issues = deviceStatus['issues'] as List<String>;
        for (final issue in issues) {
          // Solo reportar si es una nueva amenaza
          if (!_isExistingThreat('device_tampered', issue)) {
            await _reportThreat(SecurityThreat(
              type: 'device_tampered',
              description: issue,
              severity: 'critical',
              timestamp: DateTime.now(),
            ));
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error verificando estado del dispositivo', e);
    }
  }

  /// Verifica actividad inusual del usuario
  Future<void> _checkUnusualActivity() async {
    try {
      // Obtener estadísticas de uso reciente
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));

      // Verificar número de intentos de autenticación fallidos
      final failedAttempts = await _getFailedAuthAttempts(last24Hours);

      if (failedAttempts > 10) {
        await _reportThreat(SecurityThreat(
          type: 'brute_force',
          description:
              'Múltiples intentos de autenticación fallidos: $failedAttempts',
          severity: 'high',
          timestamp: DateTime.now(),
        ));
      } else if (failedAttempts > 5) {
        await _reportThreat(SecurityThreat(
          type: 'unusual_activity',
          description:
              'Actividad de autenticación sospechosa: $failedAttempts intentos fallidos',
          severity: 'medium',
          timestamp: DateTime.now(),
        ));
      }

      // Verificar patrones de ubicación inusuales
      await _checkLocationPatterns();
    } catch (e) {
      AppLogger.error('Error verificando actividad inusual', e);
    }
  }

  /// Obtiene número de intentos de autenticación fallidos
  Future<int> _getFailedAuthAttempts(DateTime since) async {
    try {
      // En una implementación real, consultar audit logs
      final logs =
          await _auditLog.getLogsSince(since, eventType: 'auth_failed');
      return logs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Verifica patrones de ubicación inusuales
  Future<void> _checkLocationPatterns() async {
    try {
      // Obtener ubicaciones recientes del audit log
      final now = DateTime.now();
      final last1Hour = now.subtract(const Duration(hours: 1));

      final locationLogs =
          await _auditLog.getLogsSince(last1Hour, eventType: 'location_update');

      if (locationLogs.length > 100) {
        // Demasiadas actualizaciones de ubicación
        await _reportThreat(SecurityThreat(
          type: 'unusual_activity',
          description:
              'Frecuencia de actualización de ubicación inusualmente alta',
          severity: 'low',
          timestamp: DateTime.now(),
        ));
      }

      // Verificar saltos de ubicación imposibles
      await _detectImpossibleLocationJumps(locationLogs);
    } catch (e) {
      AppLogger.error('Error verificando patrones de ubicación', e);
    }
  }

  /// Detecta saltos de ubicación imposibles
  Future<void> _detectImpossibleLocationJumps(
      List<dynamic> locationLogs) async {
    // Implementar detección de teleportación GPS
    // Por ahora es un stub
  }

  /// Verifica actividad de red sospechosa
  Future<void> _checkNetworkActivity() async {
    try {
      // Verificar conexiones a IPs sospechosas
      // En una implementación real, usar network_info_plus

      // Simular verificación de red
      final suspiciousConnections = await _detectSuspiciousConnections();

      if (suspiciousConnections.isNotEmpty) {
        await _reportThreat(SecurityThreat(
          type: 'network_attack',
          description: 'Conexiones de red sospechosas detectadas',
          severity: 'medium',
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      AppLogger.error('Error verificando actividad de red', e);
    }
  }

  /// Detecta conexiones de red sospechosas
  Future<List<String>> _detectSuspiciousConnections() async {
    // En una implementación real, verificar conexiones de red activas
    return [];
  }

  /// Verifica si ya existe una amenaza del mismo tipo
  bool _isExistingThreat(String type, String description) {
    return _activeThreats.any(
        (threat) => threat.type == type && threat.description == description);
  }

  /// Reporta una nueva amenaza de seguridad
  Future<void> _reportThreat(SecurityThreat threat) async {
    try {
      AppLogger.warning(
          'AMENAZA DE SEGURIDAD DETECTADA: ${threat.type} - ${threat.description}');

      // Agregar a amenazas activas
      _activeThreats.add(threat);

      // Agregar al historial
      _threatHistory.add(threat);
      if (_threatHistory.length > maxThreatHistory) {
        _threatHistory.removeAt(0);
      }

      // Actualizar contadores
      _totalIncidents++;
      _threatCounters[threat.type] = (_threatCounters[threat.type] ?? 0) + 1;
      _lastThreatDetection = DateTime.now();

      // Registrar en audit log
      await _auditLog.logSecurityEventSimple(
        'threat_detected',
        {
          'threatType': threat.type,
          'description': threat.description,
          'severity': threat.severity,
        },
      );

      // Recalcular score de seguridad
      _recalculateSecurityScore();

      // Notificar a callbacks
      _threatDetectedCallback?.call(threat);

      // Verificar si requiere alerta crítica
      if (threat.severity == 'critical' ||
          _currentSecurityScore < criticalScoreThreshold) {
        _triggerCriticalAlert(threat);
      }

      // Guardar métricas actualizadas
      await _saveMetricsToStorage();
    } catch (e, stackTrace) {
      AppLogger.error('Error reportando amenaza de seguridad', e, stackTrace);
    }
  }

  /// Recalcula el score de seguridad basado en amenazas activas
  void _recalculateSecurityScore() {
    double score = 100.0;

    // Aplicar penalizaciones por amenazas activas
    for (final threat in _activeThreats) {
      final weight = _threatWeights[threat.type] ?? -10.0;
      score += weight;

      // Penalización adicional por severidad
      switch (threat.severity) {
        case 'critical':
          score -= 10.0;
          break;
        case 'high':
          score -= 5.0;
          break;
        case 'medium':
          score -= 2.0;
          break;
        case 'low':
          score -= 1.0;
          break;
      }
    }

    // Penalización por historial reciente
    final recentThreats = _threatHistory
        .where((threat) =>
            DateTime.now().difference(threat.timestamp).inHours < 24)
        .length;

    score -= recentThreats * 2.0;

    // Bonus por tiempo sin incidentes
    if (_lastThreatDetection != null) {
      final hoursSinceLastThreat =
          DateTime.now().difference(_lastThreatDetection!).inHours;
      if (hoursSinceLastThreat > 168) {
        // 1 semana
        score += 10.0;
      } else if (hoursSinceLastThreat > 24) {
        // 1 día
        score += 5.0;
      }
    }

    // Asegurar que el score esté en el rango 0-100
    _currentSecurityScore = score.clamp(0.0, 100.0);

    AppLogger.debug('Score de seguridad actualizado: $_currentSecurityScore');
  }

  /// Dispara una alerta crítica
  void _triggerCriticalAlert(SecurityThreat threat) {
    final alertMessage = 'ALERTA CRÍTICA: ${threat.description}';
    AppLogger.critical(alertMessage);

    _criticalAlertCallback?.call(alertMessage);

    // En una implementación real, enviar notificación push, email, etc.
    _sendCriticalNotification(threat);
  }

  /// Envía notificación crítica
  void _sendCriticalNotification(SecurityThreat threat) {
    // Implementar envío de notificación crítica
    if (kDebugMode) {
      AppLogger.debug('Notificación crítica enviada para: ${threat.type}');
    }
  }

  /// Genera reporte periódico de seguridad
  void _generateSecurityReport() {
    try {
      AppLogger.info('Generando reporte periódico de seguridad');

      final status = SecurityStatus(
        securityScore: _currentSecurityScore,
        threats: List.from(_activeThreats),
        timestamp: DateTime.now(),
      );

      _securityStatusCallback?.call(status);

      // Log del estado actual
      AppLogger.info('Estado de seguridad actual:');
      AppLogger.info('  Score: $_currentSecurityScore');
      AppLogger.info('  Amenazas activas: ${_activeThreats.length}');
      AppLogger.info('  Total incidentes: $_totalIncidents');
      AppLogger.info('  Intentos bloqueados: $_blockedAttempts');
    } catch (e) {
      AppLogger.error('Error generando reporte de seguridad', e);
    }
  }

  /// Notifica cambios en el estado de seguridad
  void _notifySecurityStatus() {
    final status = SecurityStatus(
      securityScore: _currentSecurityScore,
      threats: List.from(_activeThreats),
      timestamp: DateTime.now(),
    );

    _securityStatusCallback?.call(status);
  }

  /// Guarda métricas actuales en storage seguro
  Future<void> _saveMetricsToStorage() async {
    try {
      await _secureStorage.setSecureString(
          'total_incidents', _totalIncidents.toString());
      await _secureStorage.setSecureString(
          'blocked_attempts', _blockedAttempts.toString());

      final threatHistoryJson =
          _threatHistory.map((threat) => threat.toJson()).toList();
      await _secureStorage.setSecureString(
          'threat_history', jsonEncode(threatHistoryJson));

      await _secureStorage.setSecureString(
          'threat_counters', jsonEncode(_threatCounters));
    } catch (e) {
      AppLogger.error('Error guardando métricas de seguridad', e);
    }
  }

  /// Detiene el monitoreo de seguridad
  void stopMonitoring() {
    if (!_isMonitoring) return;

    AppLogger.info('Deteniendo monitoreo de seguridad');

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _reportTimer?.cancel();

    _monitoringTimer = null;
    _reportTimer = null;
  }

  /// Resuelve una amenaza (la marca como resuelta)
  Future<void> resolveThreat(SecurityThreat threat) async {
    _activeThreats.removeWhere((t) =>
        t.type == threat.type &&
        t.description == threat.description &&
        t.timestamp == threat.timestamp);

    _recalculateSecurityScore();
    _notifySecurityStatus();

    await _auditLog.logSecurityEventSimple(
      'threat_resolved',
      {
        'threatType': threat.type,
        'description': threat.description,
      },
    );

    AppLogger.info('Amenaza resuelta: ${threat.type} - ${threat.description}');
  }

  /// Registra un intento bloqueado
  Future<void> recordBlockedAttempt(String attemptType, String details) async {
    _blockedAttempts++;

    await _auditLog.logSecurityEventSimple(
      'blocked_attempt',
      {
        'attemptType': attemptType,
        'details': details,
      },
    );

    await _saveMetricsToStorage();

    AppLogger.info('Intento bloqueado: $attemptType - $details');
  }

  /// Obtiene el estado actual de seguridad
  SecurityStatus getCurrentStatus() {
    return SecurityStatus(
      securityScore: _currentSecurityScore,
      threats: List.from(_activeThreats),
      timestamp: DateTime.now(),
    );
  }

  /// Obtiene estadísticas de seguridad
  SecurityStatistics getStatistics() {
    final averageScore = _threatHistory.isEmpty
        ? 100.0
        : _threatHistory
                .map((t) => _currentSecurityScore)
                .reduce((a, b) => a + b) /
            _threatHistory.length;

    return SecurityStatistics(
      totalIncidents: _totalIncidents,
      blockedAttempts: _blockedAttempts,
      averageScore: averageScore,
    );
  }

  /// Obtiene historial de amenazas
  List<SecurityThreat> getThreatHistory({int? limit}) {
    final history = List<SecurityThreat>.from(_threatHistory);
    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && limit < history.length) {
      return history.take(limit).toList();
    }

    return history;
  }

  /// Obtiene amenazas activas filtradas por tipo
  List<SecurityThreat> getActiveThreatsByType(String type) {
    return _activeThreats.where((threat) => threat.type == type).toList();
  }

  /// Obtiene contadores de amenazas por tipo
  Map<String, int> getThreatCounters() {
    return Map.from(_threatCounters);
  }

  /// Verifica si el sistema está en estado crítico
  bool isCriticalState() {
    return _currentSecurityScore < criticalScoreThreshold;
  }

  /// Verifica si el sistema necesita atención
  bool needsAttention() {
    return _currentSecurityScore < warningScoreThreshold;
  }

  /// Establece callback para detección de amenazas
  void setThreatDetectedCallback(Function(SecurityThreat threat) callback) {
    _threatDetectedCallback = callback;
  }

  /// Establece callback para cambios de estado de seguridad
  void setSecurityStatusCallback(Function(SecurityStatus status) callback) {
    _securityStatusCallback = callback;
  }

  /// Establece callback para alertas críticas
  void setCriticalAlertCallback(Function(String alert) callback) {
    _criticalAlertCallback = callback;
  }

  /// Realiza un reset completo del sistema de monitoreo
  Future<void> resetSecuritySystem() async {
    AppLogger.warning('Realizando reset completo del sistema de seguridad');

    stopMonitoring();

    // Limpiar todas las amenazas activas
    _activeThreats.clear();

    // Reiniciar score
    _currentSecurityScore = 100.0;

    // Limpiar storage
    await _secureStorage.remove('total_incidents');
    await _secureStorage.remove('blocked_attempts');
    await _secureStorage.remove('threat_history');
    await _secureStorage.remove('threat_counters');

    // Reiniciar contadores
    _totalIncidents = 0;
    _blockedAttempts = 0;
    _threatHistory.clear();
    _threatCounters.clear();
    _lastThreatDetection = null;

    await _auditLog.logSecurityEventSimple('security_system_reset', {});

    AppLogger.info('Sistema de seguridad reiniciado');
  }

  /// Libera recursos del servicio
  void dispose() {
    AppLogger.info('Liberando recursos del Security Monitor Service');

    stopMonitoring();

    _activeThreats.clear();
    _threatHistory.clear();
    _threatCounters.clear();

    _threatDetectedCallback = null;
    _securityStatusCallback = null;
    _criticalAlertCallback = null;

    _isInitialized = false;
  }
}

/// Modelo de amenaza de seguridad
class SecurityThreat {
  final String type;
  final String description;
  final String severity;
  final DateTime timestamp;

  SecurityThreat({
    required this.type,
    required this.description,
    required this.severity,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'description': description,
        'severity': severity,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SecurityThreat.fromJson(Map<String, dynamic> json) {
    return SecurityThreat(
      type: json['type'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() {
    return 'SecurityThreat{type: $type, severity: $severity, description: $description}';
  }
}

/// Estado de seguridad del sistema
class SecurityStatus {
  final double securityScore;
  final List<SecurityThreat> threats;
  final DateTime timestamp;

  SecurityStatus({
    required this.securityScore,
    required this.threats,
    required this.timestamp,
  });

  String get securityLevel {
    if (securityScore >= 80) return 'excellent';
    if (securityScore >= 60) return 'good';
    if (securityScore >= 40) return 'warning';
    if (securityScore >= 20) return 'danger';
    return 'critical';
  }

  bool get isCritical => securityScore < 30;
  bool get needsAttention => securityScore < 60;
}

/// Estadísticas de seguridad
class SecurityStatistics {
  final int totalIncidents;
  final int blockedAttempts;
  final double averageScore;

  SecurityStatistics({
    required this.totalIncidents,
    required this.blockedAttempts,
    required this.averageScore,
  });

  Map<String, dynamic> toJson() => {
        'totalIncidents': totalIncidents,
        'blockedAttempts': blockedAttempts,
        'averageScore': averageScore,
      };
}

/// Extension para facilitar el uso en otros servicios
extension SecurityMonitorExtension on SecurityMonitorService {
  /// Reporta un intento de acceso no autorizado
  Future<void> reportUnauthorizedAccess(String resource, String details) async {
    await recordBlockedAttempt(
        'unauthorized_access', 'Resource: $resource, Details: $details');

    await _reportThreat(SecurityThreat(
      type: 'security_bypass',
      description: 'Intento de acceso no autorizado a: $resource',
      severity: 'high',
      timestamp: DateTime.now(),
    ));
  }

  /// Reporta actividad sospechosa
  Future<void> reportSuspiciousActivity(String activity, String userId) async {
    await _reportThreat(SecurityThreat(
      type: 'unusual_activity',
      description: 'Actividad sospechosa: $activity (Usuario: $userId)',
      severity: 'medium',
      timestamp: DateTime.now(),
    ));
  }
}

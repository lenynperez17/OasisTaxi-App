import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/app_logger.dart';

/// Servicio de seguridad del dispositivo
/// Detecta jailbreak, root, debugging y otras amenazas
class DeviceSecurityService {
  static final DeviceSecurityService _instance =
      DeviceSecurityService._internal();
  factory DeviceSecurityService() => _instance;
  DeviceSecurityService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Verifica si el dispositivo está comprometido
  Future<bool> isDeviceCompromised() async {
    try {
      if (Platform.isAndroid) {
        return await _checkAndroidRoot();
      } else if (Platform.isIOS) {
        return await _checkIOSJailbreak();
      }
      return false;
    } catch (e) {
      AppLogger.error('Error verificando seguridad del dispositivo', e);
      return false;
    }
  }

  /// Detecta root en Android
  Future<bool> _checkAndroidRoot() async {
    try {
      // Verificar archivos y directorios de root comunes
      final rootPaths = [
        '/system/app/Superuser.apk',
        '/sbin/su',
        '/system/bin/su',
        '/system/xbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/system/sd/xbin/su',
        '/system/bin/failsafe/su',
        '/data/local/su',
        '/su/bin/su',
      ];

      for (final path in rootPaths) {
        if (await File(path).exists()) {
          AppLogger.warning('Dispositivo Android rooteado detectado: $path');
          return true;
        }
      }

      // En producción, verificarías si estas apps de root están instaladas:
      // 'com.koushikdutta.superuser', 'com.topjohnwu.magisk',
      // 'eu.chainfire.supersu', 'com.noshufou.android.su',
      // 'com.thirdparty.superuser', 'com.yellowes.su'
      // Por ahora retornamos false
      return false;
    } catch (e) {
      AppLogger.error('Error verificando root en Android', e);
      return false;
    }
  }

  /// Detecta jailbreak en iOS
  Future<bool> _checkIOSJailbreak() async {
    try {
      // Verificar archivos y directorios de jailbreak comunes
      final jailbreakPaths = [
        '/Applications/Cydia.app',
        '/Library/MobileSubstrate/MobileSubstrate.dylib',
        '/bin/bash',
        '/usr/sbin/sshd',
        '/etc/apt',
        '/private/var/lib/apt',
        '/usr/bin/ssh',
        '/usr/libexec/sftp-server',
        '/Applications/blackra1n.app',
        '/Applications/FakeCarrier.app',
        '/Applications/Icy.app',
        '/Applications/IntelliScreen.app',
        '/Applications/MxTube.app',
        '/Applications/RockApp.app',
        '/Applications/SBSettings.app',
        '/Applications/WinterBoard.app',
      ];

      for (final path in jailbreakPaths) {
        if (await File(path).exists()) {
          AppLogger.warning('Dispositivo iOS con jailbreak detectado: $path');
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('Error verificando jailbreak en iOS', e);
      return false;
    }
  }

  /// Detecta si la app está siendo debuggeada
  bool isBeingDebugged() {
    // En debug mode, kDebugMode es true
    // En release mode, kDebugMode es false
    if (kDebugMode) {
      AppLogger.info('App ejecutándose en modo debug');
      return true;
    }
    return false;
  }

  /// Detecta si está ejecutándose en un emulador
  Future<bool> isRunningOnEmulator() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final isEmulator = !androidInfo.isPhysicalDevice;

        if (isEmulator) {
          AppLogger.warning('App ejecutándose en emulador Android');
        }

        return isEmulator;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final isSimulator = !iosInfo.isPhysicalDevice;

        if (isSimulator) {
          AppLogger.warning('App ejecutándose en simulador iOS');
        }

        return isSimulator;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error detectando emulador', e);
      return false;
    }
  }

  /// Obtiene información del dispositivo
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final info = <String, dynamic>{};

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info['platform'] = 'Android';
        info['model'] = androidInfo.model;
        info['manufacturer'] = androidInfo.manufacturer;
        info['androidVersion'] = androidInfo.version.release;
        info['sdkInt'] = androidInfo.version.sdkInt;
        info['isPhysicalDevice'] = androidInfo.isPhysicalDevice;
        info['androidId'] = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info['platform'] = 'iOS';
        info['model'] = iosInfo.model;
        info['systemName'] = iosInfo.systemName;
        info['systemVersion'] = iosInfo.systemVersion;
        info['isPhysicalDevice'] = iosInfo.isPhysicalDevice;
        info['identifierForVendor'] = iosInfo.identifierForVendor;
      }

      return info;
    } catch (e) {
      AppLogger.error('Error obteniendo información del dispositivo', e);
      return {};
    }
  }

  /// Verifica la integridad general del dispositivo
  Future<SecurityCheckResult> performSecurityCheck() async {
    try {
      final isCompromised = await isDeviceCompromised();
      final isEmulator = await isRunningOnEmulator();
      final isDebug = isBeingDebugged();
      final deviceInfo = await getDeviceInfo();

      final result = SecurityCheckResult(
        isSecure: !isCompromised && !isEmulator && !isDebug,
        isRootedOrJailbroken: isCompromised,
        isEmulator: isEmulator,
        isDebugMode: isDebug,
        deviceInfo: deviceInfo,
        timestamp: DateTime.now(),
      );

      if (!result.isSecure) {
        AppLogger.warning('Verificación de seguridad falló', result.toJson());
      }

      return result;
    } catch (e) {
      AppLogger.error('Error en verificación de seguridad', e);
      return SecurityCheckResult(
        isSecure: false,
        isRootedOrJailbroken: false,
        isEmulator: false,
        isDebugMode: false,
        deviceInfo: {},
        timestamp: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Verifica si se están usando herramientas de hacking
  Future<bool> detectHackingTools() async {
    try {
      if (Platform.isAndroid) {
        // En producción, verificarías si estas apps de hacking están instaladas:
        // 'com.saurik.substrate', 'de.robv.android.xposed',
        // 'com.android.vending.billing.InAppBillingService.COIN',
        // 'com.chelpus.lackypatch', 'com.dimonvideo.luckypatcher', etc.
        // Por ahora retornamos false
        return false;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error detectando herramientas de hacking', e);
      return false;
    }
  }

  /// Detecta si hay un proxy configurado
  Future<bool> isProxyConfigured() async {
    try {
      // Verificar configuración de proxy del sistema
      final httpProxy = Platform.environment['HTTP_PROXY'];
      final httpsProxy = Platform.environment['HTTPS_PROXY'];

      if (httpProxy != null || httpsProxy != null) {
        AppLogger.warning(
            'Proxy detectado: HTTP=$httpProxy, HTTPS=$httpsProxy');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error detectando proxy', e);
      return false;
    }
  }

  /// Verifica si hay un VPN activo
  Future<bool> isVPNActive() async {
    try {
      // En una implementación real, verificarías interfaces de red
      // Por ahora retornamos false
      return false;
    } catch (e) {
      AppLogger.error('Error detectando VPN', e);
      return false;
    }
  }

  /// Obtiene el nivel de seguridad del dispositivo
  Future<SecurityLevel> getSecurityLevel() async {
    final check = await performSecurityCheck();

    if (!check.isSecure) {
      if (check.isRootedOrJailbroken) {
        return SecurityLevel.critical;
      } else if (check.isEmulator) {
        return SecurityLevel.high;
      } else if (check.isDebugMode) {
        return SecurityLevel.medium;
      }
    }

    final hasHackingTools = await detectHackingTools();
    if (hasHackingTools) {
      return SecurityLevel.high;
    }

    final hasProxy = await isProxyConfigured();
    if (hasProxy) {
      return SecurityLevel.medium;
    }

    return SecurityLevel.low;
  }

  /// Inicializa el servicio de seguridad del dispositivo
  Future<void> initialize() async {
    try {
      AppLogger.info('Inicializando DeviceSecurityService');
      // Realizar verificación inicial de seguridad
      final securityCheck = await performSecurityCheck();
      if (!securityCheck.isSecure) {
        AppLogger.warning(
            'Dispositivo potencialmente comprometido', securityCheck.toJson());
      }
    } catch (e) {
      AppLogger.error('Error inicializando DeviceSecurityService', e);
    }
  }

  /// Verifica la seguridad del dispositivo (método simplificado)
  Future<bool> checkDeviceSecurity() async {
    try {
      final result = await performSecurityCheck();
      return result.isSecure;
    } catch (e) {
      AppLogger.error('Error verificando seguridad del dispositivo', e);
      return false;
    }
  }

  /// Determina si la app debe ser bloqueada por seguridad
  Future<bool> shouldBlockApp() async {
    try {
      final level = await getSecurityLevel();
      // Bloquear solo en casos críticos
      return level == SecurityLevel.critical;
    } catch (e) {
      AppLogger.error('Error determinando si bloquear app', e);
      return false;
    }
  }
}

/// Resultado de verificación de seguridad
class SecurityCheckResult {
  final bool isSecure;
  final bool isRootedOrJailbroken;
  final bool isEmulator;
  final bool isDebugMode;
  final Map<String, dynamic> deviceInfo;
  final DateTime timestamp;
  final String? error;

  SecurityCheckResult({
    required this.isSecure,
    required this.isRootedOrJailbroken,
    required this.isEmulator,
    required this.isDebugMode,
    required this.deviceInfo,
    required this.timestamp,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'isSecure': isSecure,
        'isRootedOrJailbroken': isRootedOrJailbroken,
        'isEmulator': isEmulator,
        'isDebugMode': isDebugMode,
        'deviceInfo': deviceInfo,
        'timestamp': timestamp.toIso8601String(),
        if (error != null) 'error': error,
      };

  /// Operador [] para acceder a propiedades como un mapa
  dynamic operator [](String key) {
    switch (key) {
      case 'isSecure':
        return isSecure;
      case 'isRootedOrJailbroken':
        return isRootedOrJailbroken;
      case 'isEmulator':
        return isEmulator;
      case 'isDebugMode':
        return isDebugMode;
      case 'deviceInfo':
        return deviceInfo;
      case 'timestamp':
        return timestamp;
      case 'error':
        return error;
      default:
        return null;
    }
  }
}

/// Niveles de seguridad
enum SecurityLevel {
  low, // Sin amenazas detectadas
  medium, // Amenazas menores (debug mode, proxy)
  high, // Amenazas importantes (emulador, herramientas de hacking)
  critical // Amenazas críticas (root/jailbreak)
}

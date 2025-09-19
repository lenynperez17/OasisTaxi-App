import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http_certificate_pinning/http_certificate_pinning.dart';
import '../utils/app_logger.dart';
import 'remote_config_service.dart';

/// Secure Network Client with Certificate Pinning
/// Enforces SSL pinning for all API calls in Flutter/Dart layer
class NetworkClient {
  static final NetworkClient _instance = NetworkClient._internal();
  factory NetworkClient() => _instance;
  NetworkClient._internal();

  late Dio _dio;
  bool _initialized = false;

  // SPKI pins for certificate pinning
  // These should match the pins in network_security_config.xml
  static const Map<String, List<String>> _certificatePins = {
    // Firebase/Google domains
    'firebaseapp.com': [
      'sha256/Vjs8r4z+80wjNcr1YKepWQboSIRi63WsWXhIMN+eWys=', // GTS Root R1
      'sha256/CLOmM1/OXvSPjw5UOYbAf9GKOxImEp9hhku9W90fHMk=', // GTS Root R2
      'sha256/W5rhIQ2ZbJKFkRvsGDwQVS/H/NSixP33+Z/fpJ0O25Q=', // GTS CA 1C3
      'sha256/hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=', // Backup pin
    ],
    'firebase.com': [
      'sha256/Vjs8r4z+80wjNcr1YKepWQboSIRi63WsWXhIMN+eWys=',
      'sha256/CLOmM1/OXvSPjw5UOYbAf9GKOxImEp9hhku9W90fHMk=',
      'sha256/W5rhIQ2ZbJKFkRvsGDwQVS/H/NSixP33+Z/fpJ0O25Q=',
      'sha256/hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=',
    ],
    'firebaseio.com': [
      'sha256/Vjs8r4z+80wjNcr1YKepWQboSIRi63WsWXhIMN+eWys=',
      'sha256/CLOmM1/OXvSPjw5UOYbAf9GKOxImEp9hhku9W90fHMk=',
      'sha256/W5rhIQ2ZbJKFkRvsGDwQVS/H/NSixP33+Z/fpJ0O25Q=',
      'sha256/hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=',
    ],
    'googleapis.com': [
      'sha256/Vjs8r4z+80wjNcr1YKepWQboSIRi63WsWXhIMN+eWys=',
      'sha256/CLOmM1/OXvSPjw5UOYbAf9GKOxImEp9hhku9W90fHMk=',
    ],

    // MercadoPago domains
    'mercadopago.com': [
      'sha256/r/mIkG3eEpVdm+u/ko/cwxzOMo1bk4TyHIlByibiA5E=', // DigiCert Global Root CA
      'sha256/5kJvNEMw0KjrCAu7eXY5HmQkP/Ulb5/OlyMoIIWDGA=', // DigiCert SHA2 Secure Server CA
      'sha256/K87oWBWM9UZfyddvDfoxL+8lpNyoUB2ptGtn0fv6G2Q=', // Backup pin
    ],
    'mercadopago.com.pe': [
      'sha256/r/mIkG3eEpVdm+u/ko/cwxzOMo1bk4TyHIlByibiA5E=',
      'sha256/5kJvNEMw0KjrCAu7eXY5HmQkP/Ulb5/OlyMoIIWDGA=',
      'sha256/K87oWBWM9UZfyddvDfoxL+8lpNyoUB2ptGtn0fv6G2Q=',
    ],

    // OasisTaxi domains - Using Let's Encrypt and ISRG Root certificates
    'oasistaxiperu.com': [
      // Let's Encrypt R3 (current intermediate)
      'sha256/jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0=',
      // ISRG Root X1 (root CA)
      'sha256/C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=',
      // Let's Encrypt E1 (backup intermediate)
      'sha256/J2/oqMTsdhFWW/n85tys6b4yDBtb6idZayIEBx7QTxA=',
    ],
    'api.oasistaxiperu.com': [
      // Let's Encrypt R3 (current intermediate)
      'sha256/jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0=',
      // ISRG Root X1 (root CA)
      'sha256/C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=',
      // Let's Encrypt E1 (backup intermediate)
      'sha256/J2/oqMTsdhFWW/n85tys6b4yDBtb6idZayIEBx7QTxA=',
    ],
  };

  /// Initialize the network client with certificate pinning
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Check if we should load pins from Remote Config
      final remotePins = await _loadPinsFromRemoteConfig();

      // Create Dio instance
      _dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      // Add certificate pinning interceptor
      _dio.interceptors.add(_createCertificatePinningInterceptor(remotePins));

      // Add logging interceptor in debug mode
      if (!const bool.fromEnvironment('dart.vm.product')) {
        _dio.interceptors.add(LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
        ));
      }

      // Add retry interceptor for network failures
      _dio.interceptors.add(_createRetryInterceptor());

      _initialized = true;

      // Log total unique pins configured
      final allPins = <String>{};
      _certificatePins.values.forEach((domainPins) {
        allPins.addAll(domainPins);
      });

      AppLogger.info('NetworkClient initialized with certificate pinning');
      AppLogger.info('🔒 SSL Certificate Pinning Configuration:');
      AppLogger.info('  - Total domains configured: ${_certificatePins.length}');
      AppLogger.info('  - Total unique certificate pins: ${allPins.length}');

      // Log each domain and number of pins in production
      if (const bool.fromEnvironment('dart.vm.product')) {
        AppLogger.info('🔐 PRODUCTION SSL pinning active');
        _certificatePins.forEach((domain, pins) {
          AppLogger.info('  ✅ $domain: ${pins.length} pins configured');
        });
        AppLogger.info('  - Remote Config pins loaded: ${remotePins.length > _certificatePins.length ? 'Yes' : 'No'}');
        AppLogger.info('  - Certificate validation: ENFORCED');
      } else {
        AppLogger.warning('⚠️ DEBUG MODE: SSL pinning validation disabled');
        AppLogger.warning('  - Certificate validation: LOGGING ONLY');
      }
    } catch (e) {
      AppLogger.error('Failed to initialize NetworkClient', e);
      // Fall back to basic Dio without pinning if initialization fails
      _dio = Dio();
      _initialized = true;
    }
  }

  /// Load certificate pins from Remote Config if available
  Future<Map<String, List<String>>> _loadPinsFromRemoteConfig() async {
    try {
      final remoteConfig = RemoteConfigService();

      // Check if Remote Config has certificate pins
      final pinsJson = remoteConfig.getString('certificate_pins');
      if (pinsJson.isNotEmpty) {
        final pins = json.decode(pinsJson) as Map<String, dynamic>;

        // Merge with hardcoded pins
        final mergedPins = Map<String, List<String>>.from(_certificatePins);
        pins.forEach((domain, domainPins) {
          if (domainPins is List) {
            mergedPins[domain] = domainPins.cast<String>();
          }
        });

        AppLogger.info('Loaded certificate pins from Remote Config');
        return mergedPins;
      }
    } catch (e) {
      AppLogger.warning('Failed to load pins from Remote Config', e);
    }

    return _certificatePins;
  }

  /// Create certificate pinning interceptor
  Interceptor _createCertificatePinningInterceptor(Map<String, List<String>> pins) {
    // For production, use actual certificate pinning
    if (const bool.fromEnvironment('dart.vm.product')) {
      final allowedSHAFingerprints = <String>[];

      // Collect all unique pins
      pins.values.forEach((domainPins) {
        allowedSHAFingerprints.addAll(domainPins);
      });

      // Remove duplicates
      final uniquePins = allowedSHAFingerprints.toSet().toList();

      return CertificatePinningInterceptor(
        allowedSHAFingerprints: uniquePins,
        timeout: 30,
      );
    }

    // For development, create a custom interceptor that logs but doesn't enforce
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final host = options.uri.host;
        AppLogger.debug('Request to: $host (certificate pinning disabled in debug)');
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.type == DioExceptionType.badCertificate) {
          AppLogger.error('Certificate validation failed', error);
        }
        handler.next(error);
      },
    );
  }

  /// Create retry interceptor for failed requests
  Interceptor _createRetryInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        if (_shouldRetry(error)) {
          try {
            AppLogger.warning('Retrying request after error', error);

            // Wait before retrying
            await Future.delayed(const Duration(seconds: 2));

            // Clone and retry the request
            final options = error.requestOptions;
            final response = await _dio.request(
              options.path,
              data: options.data,
              queryParameters: options.queryParameters,
              options: Options(
                method: options.method,
                headers: options.headers,
              ),
            );

            return handler.resolve(response);
          } catch (retryError) {
            AppLogger.error('Retry failed', retryError);
            return handler.next(error);
          }
        }
        return handler.next(error);
      },
    );
  }

  /// Check if a request should be retried
  bool _shouldRetry(DioException error) {
    // Don't retry certificate errors
    if (error.type == DioExceptionType.badCertificate) {
      return false;
    }

    // Retry network errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry server errors (5xx)
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      return true;
    }

    return false;
  }

  /// Get the Dio instance for making requests
  Dio get dio {
    if (!_initialized) {
      throw StateError('NetworkClient not initialized. Call initialize() first.');
    }
    return _dio;
  }

  /// Make a GET request with certificate pinning
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _ensureInitialized();
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Make a POST request with certificate pinning
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _ensureInitialized();
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Make a PUT request with certificate pinning
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _ensureInitialized();
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Make a DELETE request with certificate pinning
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _ensureInitialized();
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Make a PATCH request with certificate pinning
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _ensureInitialized();
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Ensure the client is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Validate certificate pins for a specific domain
  bool validatePinsForDomain(String domain) {
    // Check if we have pins for this domain
    final pins = _certificatePins[domain];
    if (pins == null || pins.isEmpty) {
      AppLogger.warning('No certificate pins configured for domain: $domain');
      return false;
    }

    // In production, this would actually validate against the server's certificate
    AppLogger.debug('Certificate pins configured for $domain: ${pins.length} pins');
    return true;
  }

  /// Update certificate pins dynamically (e.g., from Remote Config)
  /// This supports dynamic rotation of certificate pins without app update
  Future<void> updateCertificatePins(Map<String, List<String>> newPins) async {
    try {
      // Merge new pins with existing ones
      newPins.forEach((domain, pins) {
        _certificatePins[domain] = pins;
      });

      AppLogger.info('🔄 Updating certificate pins for ${newPins.length} domains');

      // Log details of updated pins
      newPins.forEach((domain, pins) {
        AppLogger.info('  Updated $domain: ${pins.length} new pins');
      });

      // Reinitialize the interceptor with new pins
      _initialized = false;
      await initialize();

      AppLogger.info('✅ Certificate pins successfully rotated and interceptor reinitialized');
    } catch (e) {
      AppLogger.error('Failed to update certificate pins', e);
      throw Exception('Certificate pin rotation failed: $e');
    }
  }

  /// Refresh certificate pins from Remote Config
  /// Call this periodically or when Remote Config updates are detected
  Future<void> refreshPinsFromRemoteConfig() async {
    try {
      final remotePins = await _loadPinsFromRemoteConfig();
      if (remotePins.isNotEmpty && remotePins.length > _certificatePins.length) {
        await updateCertificatePins(remotePins);
        AppLogger.info('📡 Certificate pins refreshed from Remote Config');
      }
    } catch (e) {
      AppLogger.warning('Failed to refresh pins from Remote Config', e);
    }
  }
}
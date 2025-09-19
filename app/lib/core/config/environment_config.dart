import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../utils/app_logger.dart';

/// Configuración de variables de entorno para OasisTaxi
/// Proporciona acceso tipado y seguro a todas las variables de entorno
class EnvironmentConfig {
  static bool _isInitialized = false;

  /// Verifica si el entorno está inicializado
  static bool get isInitialized => _isInitialized;

  /// Marca como inicializado (llamado desde main.dart)
  static void markAsInitialized() {
    _isInitialized = true;
  }

  // ========================================
  // INFORMACIÓN DEL PROYECTO
  // ========================================
  static String get appName => _getString('APP_NAME', 'OasisTaxi');
  static String get appVersion => _getString('APP_VERSION', '1.0.0');
  static String get appBundleId =>
      _getString('APP_BUNDLE_ID', 'com.oasistaxiperu.app');
  static String get appDisplayName =>
      _getString('APP_DISPLAY_NAME', 'OasisTaxi Perú');
  static String get appDescription => _getString(
      'APP_DESCRIPTION', 'Aplicación de taxi con negociación de precios');
  static String get companyName =>
      _getString('COMPANY_NAME', 'OasisTaxi Perú S.A.C.');
  static String get companyEmail =>
      _getString('COMPANY_EMAIL', 'contacto@oasistaxiperu.com');
  static String get companyPhone => _getString('COMPANY_PHONE', '+51987654321');
  static String get companyWebsite =>
      _getString('COMPANY_WEBSITE', 'https://oasistaxiperu.com');

  // ========================================
  // AMBIENTE Y CONFIGURACIÓN
  // ========================================
  static String get environment => _getString('ENVIRONMENT', 'development');
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get debugMode => _getBool('DEBUG_MODE', !isProduction);
  static String get logLevel =>
      _getString('LOG_LEVEL', debugMode ? 'debug' : 'info');
  static String get sentryDsn => _getString('SENTRY_DSN', '');

  // ========================================
  // FIREBASE
  // ========================================
  static String get firebaseProjectId =>
      _getString('FIREBASE_PROJECT_ID', 'oasis-taxi-peru');
  static String get firebaseApiKey => _getString('FIREBASE_API_KEY', '');
  static String get firebaseAuthDomain =>
      _getString('FIREBASE_AUTH_DOMAIN', '$firebaseProjectId.firebaseapp.com');
  static String get firebaseDatabaseUrl => _getString('FIREBASE_DATABASE_URL',
      'https://$firebaseProjectId-default-rtdb.firebaseio.com');
  static String get firebaseStorageBucket => _getString(
      'FIREBASE_STORAGE_BUCKET', '$firebaseProjectId.firebasestorage.app');
  static String get firebaseMessagingSenderId =>
      _getString('FIREBASE_MESSAGING_SENDER_ID', '');
  static String get firebaseAppId => _getString('FIREBASE_APP_ID', '');
  static String get firebaseMeasurementId =>
      _getString('FIREBASE_MEASUREMENT_ID', '');

  // Firebase Android
  static String get firebaseAndroidApiKey =>
      _getString('FIREBASE_ANDROID_API_KEY', firebaseApiKey);
  static String get firebaseAndroidAppId =>
      _getString('FIREBASE_ANDROID_APP_ID', '');
  static String get firebaseAndroidClientId =>
      _getString('FIREBASE_ANDROID_CLIENT_ID', '');

  // Firebase iOS
  static String get firebaseIosApiKey =>
      _getString('FIREBASE_IOS_API_KEY', firebaseApiKey);
  static String get firebaseIosAppId => _getString('FIREBASE_IOS_APP_ID', '');
  static String get firebaseIosClientId =>
      _getString('FIREBASE_IOS_CLIENT_ID', '');
  static String get firebaseIosBundleId =>
      _getString('FIREBASE_IOS_BUNDLE_ID', appBundleId);

  // Firebase Service Account (sin archivo JSON)
  static String get firebaseServiceAccountEmail =>
      _getString('FIREBASE_SERVICE_ACCOUNT_EMAIL', '');
  static String get firebasePrivateKeyId =>
      _getString('FIREBASE_PRIVATE_KEY_ID', '');
  static String get firebasePrivateKey =>
      _getString('FIREBASE_PRIVATE_KEY', '');
  static String get firebaseClientEmail =>
      _getString('FIREBASE_CLIENT_EMAIL', '');
  static String get firebaseClientId =>
      _getString('FIREBASE_CLIENT_ID', '');
  static String get firebaseAuthUri =>
      _getString('FIREBASE_AUTH_URI', 'https://accounts.google.com/o/oauth2/auth');
  static String get firebaseTokenUri =>
      _getString('FIREBASE_TOKEN_URI', 'https://oauth2.googleapis.com/token');

  // Firebase App Check
  static String get firebaseAppCheckSiteKey =>
      _getString('FIREBASE_APP_CHECK_SITE_KEY', '');
  static String get firebaseAppCheckDebugToken =>
      _getString('FIREBASE_APP_CHECK_DEBUG_TOKEN', '');

  // ========================================
  // GOOGLE CLOUD & MAPS
  // ========================================
  static String get googleCloudProjectId =>
      _getString('GOOGLE_CLOUD_PROJECT_ID', firebaseProjectId);
  static String get googleMapsApiKey => _getString('GOOGLE_MAPS_API_KEY', '');
  static String get googleMapsAndroidApiKey =>
      _getString('GOOGLE_MAPS_ANDROID_API_KEY', googleMapsApiKey);
  static String get googleMapsIosApiKey =>
      _getString('GOOGLE_MAPS_IOS_API_KEY', googleMapsApiKey);
  static String get googlePlacesApiKey =>
      _getString('GOOGLE_PLACES_API_KEY', googleMapsApiKey);
  static String get googleDirectionsApiKey =>
      _getString('GOOGLE_DIRECTIONS_API_KEY', googleMapsApiKey);
  static String get googleGeocodingApiKey =>
      _getString('GOOGLE_GEOCODING_API_KEY', googleMapsApiKey);
  static String get googleRoadsApiKey =>
      _getString('GOOGLE_ROADS_API_KEY', googleMapsApiKey);

  // Google Maps Platform - Advanced Features
  static String get googleMapsStyleId =>
      _getString('GOOGLE_MAPS_STYLE_ID', '');
  static String get googleTrafficApiKey =>
      _getString('GOOGLE_TRAFFIC_API_KEY', googleMapsApiKey);
  static String get googleRoadsSnapApiKey =>
      _getString('GOOGLE_ROADS_SNAP_API_KEY', googleMapsApiKey);
  static String get googleElevationApiKey =>
      _getString('GOOGLE_ELEVATION_API_KEY', googleMapsApiKey);
  static String get googleTimezoneApiKey =>
      _getString('GOOGLE_TIMEZONE_API_KEY', googleMapsApiKey);

  // Route Optimization Configuration
  static bool get routeOptimizationEnabled =>
      _getBool('ROUTE_OPTIMIZATION_ENABLED', true);
  static bool get trafficAwareRouting =>
      _getBool('TRAFFIC_AWARE_ROUTING', true);
  static int get alternativeRoutesCount =>
      _getInt('ALTERNATIVE_ROUTES_COUNT', 3);
  static bool get waypointOptimization =>
      _getBool('WAYPOINT_OPTIMIZATION', true);

  // Real-time Features
  static bool get realTimeTraffic =>
      _getBool('REAL_TIME_TRAFFIC', true);
  static bool get incidentReporting =>
      _getBool('INCIDENT_REPORTING', true);
  static bool get roadClosureAlerts =>
      _getBool('ROAD_CLOSURE_ALERTS', true);
  static bool get constructionAlerts =>
      _getBool('CONSTRUCTION_ALERTS', true);

  // ========================================
  // CLOUD KMS - GESTIÓN SEGURA DE CLAVES
  // ========================================
  static String get cloudKmsProjectId =>
      _getString('CLOUD_KMS_PROJECT_ID', firebaseProjectId);
  static String get cloudKmsLocation =>
      _getString('CLOUD_KMS_LOCATION', 'global');
  static String get cloudKmsKeyRing =>
      _getString('CLOUD_KMS_KEY_RING', 'oasis-taxi-keyring');
  static String get cloudKmsCryptoKey =>
      _getString('CLOUD_KMS_CRYPTO_KEY', 'oasis-taxi-encryption-key');
  static String get cloudKmsServiceAccountEmail =>
      _getString('CLOUD_KMS_SERVICE_ACCOUNT_EMAIL', '');

  // ========================================
  // OAUTH - AUTENTICACIÓN
  // ========================================
  // Google Sign In
  static String get googleWebClientId => _getString('GOOGLE_WEB_CLIENT_ID', '');
  static String get googleAndroidClientId =>
      _getString('GOOGLE_ANDROID_CLIENT_ID', '');
  static String get googleIosClientId => _getString('GOOGLE_IOS_CLIENT_ID', '');
  static String get googleServerClientId =>
      _getString('GOOGLE_SERVER_CLIENT_ID', '');

  // Facebook Login
  static String get facebookAppId => _getString('FACEBOOK_APP_ID', '');
  static String get facebookAppSecret => _getString('FACEBOOK_APP_SECRET', '');
  static String get facebookClientToken =>
      _getString('FACEBOOK_CLIENT_TOKEN', '');

  // Apple Sign In
  static String get appleServiceId =>
      _getString('APPLE_SERVICE_ID', '$appBundleId.signin');
  static String get appleTeamId => _getString('APPLE_TEAM_ID', '');
  static String get appleKeyId => _getString('APPLE_KEY_ID', '');
  static String get applePrivateKeyPath =>
      _getString('APPLE_PRIVATE_KEY_PATH', 'assets/apple_auth_key.p8');

  // ========================================
  // MERCADOPAGO - PAGOS
  // ========================================
  static String get mercadopagoAccessToken =>
      _getString('MERCADOPAGO_ACCESS_TOKEN', '');
  static String get mercadopagoPublicKey =>
      _getString('MERCADOPAGO_PUBLIC_KEY', '');
  static String get mercadopagoClientId =>
      _getString('MERCADOPAGO_CLIENT_ID', '');
  static String get mercadopagoClientSecret =>
      _getString('MERCADOPAGO_CLIENT_SECRET', '');
  static String get mercadopagoUserId => _getString('MERCADOPAGO_USER_ID', '');
  static String get mercadopagoAppNumber =>
      _getString('MERCADOPAGO_APP_NUMBER', '');
  static String get mercadopagoWebhookSecret =>
      _getString('MERCADOPAGO_WEBHOOK_SECRET', '');
  static String get mercadopagoIntegrationType =>
      _getString('MERCADOPAGO_INTEGRATION_TYPE', 'direct');
  static String get mercadopagoApiType =>
      _getString('MERCADOPAGO_API_TYPE', 'checkout_api');
  static String get mercadopagoCountry =>
      _getString('MERCADOPAGO_COUNTRY', 'PE');
  static String get mercadopagoCurrency =>
      _getString('MERCADOPAGO_CURRENCY', 'PEN');
  static bool get mercadopagoSandbox =>
      _getBool('MERCADOPAGO_SANDBOX', !isProduction);

  // ========================================
  // STRIPE - PAGOS ALTERNATIVO
  // ========================================
  static String get stripePublishableKey =>
      _getString('STRIPE_PUBLISHABLE_KEY', '');
  static String get stripeSecretKey => _getString('STRIPE_SECRET_KEY', '');
  static String get stripeWebhookSecret =>
      _getString('STRIPE_WEBHOOK_SECRET', '');
  static String get stripeConnectClientId =>
      _getString('STRIPE_CONNECT_CLIENT_ID', '');

  // ========================================
  // TWILIO - SMS Y VERIFICACIÓN
  // ========================================
  static String get twilioAccountSid => _getString('TWILIO_ACCOUNT_SID', '');
  static String get twilioAuthToken => _getString('TWILIO_AUTH_TOKEN', '');
  static String get twilioPhoneNumber => _getString('TWILIO_PHONE_NUMBER', '');
  static String get twilioVerifyServiceSid =>
      _getString('TWILIO_VERIFY_SERVICE_SID', '');
  static String get twilioMessagingServiceSid =>
      _getString('TWILIO_MESSAGING_SERVICE_SID', '');

  // ========================================
  // URLs Y ENDPOINTS
  // ========================================
  static String get apiBaseUrl =>
      _getString('API_BASE_URL', 'https://api.oasistaxiperu.com');
  static String get frontendUrl =>
      _getString('FRONTEND_URL', 'https://app.oasistaxiperu.com');
  static String get adminUrl =>
      _getString('ADMIN_URL', 'https://admin.oasistaxiperu.com');
  static String get websocketUrl =>
      _getString('WEBSOCKET_URL', 'wss://ws.oasistaxiperu.com');
  static String get cdnUrl =>
      _getString('CDN_URL', 'https://cdn.oasistaxiperu.com');
  static String get staticUrl =>
      _getString('STATIC_URL', 'https://static.oasistaxiperu.com');
  static List<String> get allowedOrigins =>
      _getStringList('ALLOWED_ORIGINS', [frontendUrl]);

  // ========================================
  // CONFIGURACIÓN DE SERVIDOR
  // ========================================
  static String get nodeEnv => _getString('NODE_ENV', environment);
  static int get port => _getInt('PORT', 3000);
  static String get host => _getString('HOST', '0.0.0.0');
  static int get maxConnections => _getInt('MAX_CONNECTIONS', 1000);
  static String get clusterWorkers => _getString('CLUSTER_WORKERS', 'auto');
  static int get rateLimitWindow => _getInt('RATE_LIMIT_WINDOW', 15);
  static int get rateLimitMax => _getInt('RATE_LIMIT_MAX', 100);

  // ========================================
  // SEGURIDAD Y CIFRADO
  // ========================================
  static String get jwtSecret =>
      _getString('JWT_SECRET', 'change-this-in-production');
  static String get jwtExpiresIn => _getString('JWT_EXPIRES_IN', '24h');
  static String get jwtRefreshSecret =>
      _getString('JWT_REFRESH_SECRET', 'change-this-in-production');
  static String get jwtRefreshExpiresIn =>
      _getString('JWT_REFRESH_EXPIRES_IN', '7d');
  static String get sessionSecret =>
      _getString('SESSION_SECRET', 'change-this-in-production');
  static String get encryptionKeyId =>
      _getString('ENCRYPTION_KEY_ID', '');
  static String get securitySalt =>
      _getString('SECURITY_SALT', 'change-this-in-production');
  static String get dataEncryptionKey =>
      _getString('DATA_ENCRYPTION_KEY', '');
  static String get biometricAuthKey =>
      _getString('BIOMETRIC_AUTH_KEY', 'change-this-in-production');
  static String get auditLogEncryptionKey =>
      _getString('AUDIT_LOG_ENCRYPTION_KEY', 'change-this-in-production');
  static String get corsOrigin => _getString('CORS_ORIGIN', frontendUrl);

  // Configuración de administradores
  static String get adminFirestoreCollection =>
      _getString('ADMIN_FIRESTORE_COLLECTION', 'authorized_admins');
  static String get adminDefaultRole =>
      _getString('ADMIN_DEFAULT_ROLE', 'admin');
  static int get adminSessionTimeout =>
      _getInt('ADMIN_SESSION_TIMEOUT', 3600);

  // ========================================
  // GEOLOCALIZACIÓN Y MAPAS
  // ========================================
  static double get defaultLatitude =>
      _getDouble('DEFAULT_LATITUDE', -12.0464); // Lima
  static double get defaultLongitude =>
      _getDouble('DEFAULT_LONGITUDE', -77.0428); // Lima
  static String get defaultCity => _getString('DEFAULT_CITY', 'Lima');
  static String get defaultCountry => _getString('DEFAULT_COUNTRY', 'PE');
  static String get defaultTimezone =>
      _getString('DEFAULT_TIMEZONE', 'America/Lima');
  static String get geocodingProvider =>
      _getString('GEOCODING_PROVIDER', 'google');
  static double get maxSearchRadiusKm =>
      _getDouble('MAX_SEARCH_RADIUS_KM', 50.0);
  static double get minSearchRadiusKm =>
      _getDouble('MIN_SEARCH_RADIUS_KM', 0.5);

  // ========================================
  // CONFIGURACIÓN DE NEGOCIO
  // ========================================
  // Precios
  static double get baseFareAmount => _getDouble('BASE_FARE_AMOUNT', 5.00);
  static double get pricePerKm => _getDouble('PRICE_PER_KM', 1.50);
  static double get pricePerMinute => _getDouble('PRICE_PER_MINUTE', 0.30);
  static double get minimumFare => _getDouble('MINIMUM_FARE', 8.00);
  static double get maximumFare => _getDouble('MAXIMUM_FARE', 500.00);
  static String get currency => _getString('CURRENCY', 'PEN');
  static String get currencySymbol => _getString('CURRENCY_SYMBOL', 'S/');

  // Comisiones
  static double get driverCommissionRate =>
      _getDouble('DRIVER_COMMISSION_RATE', 0.20);
  static double get platformFeePercentage =>
      _getDouble('PLATFORM_FEE_PERCENTAGE', 0.05);
  static double get paymentProcessingFee =>
      _getDouble('PAYMENT_PROCESSING_FEE', 0.035);

  // Timeouts
  static int get driverResponseTimeoutSeconds =>
      _getInt('DRIVER_RESPONSE_TIMEOUT_SECONDS', 45);
  static int get rideRequestTimeoutMinutes =>
      _getInt('RIDE_REQUEST_TIMEOUT_MINUTES', 10);
  static int get paymentTimeoutSeconds =>
      _getInt('PAYMENT_TIMEOUT_SECONDS', 60);
  static int get locationUpdateIntervalSeconds =>
      _getInt('LOCATION_UPDATE_INTERVAL_SECONDS', 5);
  static int get priceNegotiationTimeoutMinutes =>
      _getInt('PRICE_NEGOTIATION_TIMEOUT_MINUTES', 5);

  // ========================================
  // SERVICIOS EXTERNOS
  // ========================================
  // OneSignal
  static String get oneSignalAppId => _getString('ONESIGNAL_APP_ID', '');
  static String get oneSignalRestApiKey =>
      _getString('ONESIGNAL_REST_API_KEY', '');

  // Pusher
  static String get pusherAppId => _getString('PUSHER_APP_ID', '');
  static String get pusherKey => _getString('PUSHER_KEY', '');
  static String get pusherSecret => _getString('PUSHER_SECRET', '');
  static String get pusherCluster => _getString('PUSHER_CLUSTER', 'us2');
  static bool get pusherEncrypted => _getBool('PUSHER_ENCRYPTED', true);

  // ========================================
  // ANÁLISIS Y MONITOREO
  // ========================================
  // Google Analytics
  static String get gaTrackingId => _getString('GA_TRACKING_ID', '');
  static String get gaMeasurementId => _getString('GA_MEASUREMENT_ID', '');

  // Mixpanel
  static String get mixpanelToken => _getString('MIXPANEL_TOKEN', '');

  // Amplitude
  static String get amplitudeApiKey => _getString('AMPLITUDE_API_KEY', '');

  // New Relic
  static String get newRelicLicenseKey =>
      _getString('NEW_RELIC_LICENSE_KEY', '');
  static String get newRelicAppName => _getString(
      'NEW_RELIC_APP_NAME', 'OasisTaxi-${environment.toUpperCase()}');

  // ========================================
  // FEATURES FLAGS
  // ========================================
  static bool get featurePriceNegotiation =>
      _getBool('FEATURE_PRICE_NEGOTIATION', true);
  static bool get featureScheduledRides =>
      _getBool('FEATURE_SCHEDULED_RIDES', false);
  static bool get featureRideSharing => _getBool('FEATURE_RIDE_SHARING', false);
  static bool get featureEmergencyButton =>
      _getBool('FEATURE_EMERGENCY_BUTTON', true);
  static bool get featureChatSupport => _getBool('FEATURE_CHAT_SUPPORT', true);
  static bool get featureQrCodePickup =>
      _getBool('FEATURE_QR_CODE_PICKUP', true);
  static bool get featureBiometricAuth =>
      _getBool('FEATURE_BIOMETRIC_AUTH', true);
  static bool get featureOfflineMode => _getBool('FEATURE_OFFLINE_MODE', false);
  static bool get featureLoyaltyProgram =>
      _getBool('FEATURE_LOYALTY_PROGRAM', false);

  // ========================================
  // CONFIGURACIÓN REGIONAL PERÚ
  // ========================================
  static String get locale => _getString('LOCALE', 'es_PE');
  static String get timezone => _getString('TIMEZONE', 'America/Lima');
  static String get phonePrefix => _getString('PHONE_PREFIX', '+51');
  static String get emergencyNumber => _getString('EMERGENCY_NUMBER', '105');
  static String get policeNumber => _getString('POLICE_NUMBER', '105');
  static String get fireDepartment => _getString('FIRE_DEPARTMENT', '116');
  static String get medicalEmergency => _getString('MEDICAL_EMERGENCY', '106');

  // ========================================
  // CONFIGURACIÓN DE EMERGENCIA
  // ========================================
  static bool get emergencyContactsEnabled =>
      _getBool('EMERGENCY_CONTACTS_ENABLED', true);
  static int get autoEmergencyCallDelay =>
      _getInt('AUTO_EMERGENCY_CALL_DELAY', 30);
  static String get emergencySmsTemplate => _getString('EMERGENCY_SMS_TEMPLATE',
      'Emergencia OasisTaxi: Usuario {name} solicita ayuda. Ubicación: {location}. Contactar: {phone}');
  static bool get panicButtonEnabled => _getBool('PANIC_BUTTON_ENABLED', true);

  // ========================================
  // CONFIGURACIÓN DE CALIDAD
  // ========================================
  static double get minDriverRating => _getDouble('MIN_DRIVER_RATING', 3.0);
  static double get minPassengerRating =>
      _getDouble('MIN_PASSENGER_RATING', 2.5);
  static bool get ratingRequiredAfterTrip =>
      _getBool('RATING_REQUIRED_AFTER_TRIP', true);
  static double get feedbackRequiredBelowRating =>
      _getDouble('FEEDBACK_REQUIRED_BELOW_RATING', 3.0);
  static double get autoSuspendBelowRating =>
      _getDouble('AUTO_SUSPEND_BELOW_RATING', 2.0);

  // ========================================
  // LÍMITES Y RESTRICCIONES
  // ========================================
  static int get maxConcurrentRides => _getInt('MAX_CONCURRENT_RIDES', 1);
  static int get maxDailyRidesDriver => _getInt('MAX_DAILY_RIDES_DRIVER', 20);
  static int get maxWeeklyHoursDriver => _getInt('MAX_WEEKLY_HOURS_DRIVER', 60);
  static int get maxFileUploadSizeMb => _getInt('MAX_FILE_UPLOAD_SIZE_MB', 10);
  static int get maxChatMessageLength =>
      _getInt('MAX_CHAT_MESSAGE_LENGTH', 500);
  static double get maxDriverSearchRadiusKm =>
      _getDouble('MAX_DRIVER_SEARCH_RADIUS_KM', 10.0);

  // ========================================
  // CONFIGURACIÓN DE CACHE
  // ========================================
  static int get cacheTtlSeconds => _getInt('CACHE_TTL_SECONDS', 3600);
  static int get cacheRoutesTtl => _getInt('CACHE_ROUTES_TTL', 7200);
  static int get cachePricesTtl => _getInt('CACHE_PRICES_TTL', 1800);
  static int get cacheDriversTtl => _getInt('CACHE_DRIVERS_TTL', 300);
  static int get cacheUserSessionsTtl =>
      _getInt('CACHE_USER_SESSIONS_TTL', 86400);

  // ========================================
  // CONFIGURACIÓN DE DESARROLLO
  // ========================================
  static bool get devBypassAuth =>
      _getBool('DEV_BYPASS_AUTH', false) && isDevelopment;
  static bool get devMockPayments =>
      _getBool('DEV_MOCK_PAYMENTS', false) && isDevelopment;
  static bool get devSimulateGps =>
      _getBool('DEV_SIMULATE_GPS', false) && isDevelopment;
  static bool get devEnableDebugLogs =>
      _getBool('DEV_ENABLE_DEBUG_LOGS', false) && isDevelopment;
  static bool get devSkipVerification =>
      _getBool('DEV_SKIP_VERIFICATION', false) && isDevelopment;

  // ========================================
  // MÉTODOS HELPER PRIVADOS
  // ========================================

  /// Obtiene un string del entorno con valor por defecto
  static String _getString(String key, String defaultValue) {
    try {
      final value = dotenv.env[key];
      if (value == null || value.isEmpty) {
        if (!_isInitialized || isDevelopment) {
          AppLogger.warning(
              'Variable de entorno faltante: $key, usando valor por defecto: $defaultValue');
        }
        return defaultValue;
      }
      return value;
    } catch (e) {
      AppLogger.error('Error obteniendo variable de entorno $key', e);
      return defaultValue;
    }
  }

  /// Obtiene un bool del entorno con valor por defecto
  static bool _getBool(String key, bool defaultValue) {
    try {
      final value = dotenv.env[key]?.toLowerCase();
      if (value == null || value.isEmpty) {
        return defaultValue;
      }
      return value == 'true' || value == '1' || value == 'yes' || value == 'on';
    } catch (e) {
      AppLogger.error('Error obteniendo bool de entorno $key', e);
      return defaultValue;
    }
  }

  /// Obtiene un int del entorno con valor por defecto
  static int _getInt(String key, int defaultValue) {
    try {
      final value = dotenv.env[key];
      if (value == null || value.isEmpty) {
        return defaultValue;
      }
      return int.parse(value);
    } catch (e) {
      AppLogger.error('Error obteniendo int de entorno $key', e);
      return defaultValue;
    }
  }

  /// Obtiene un double del entorno con valor por defecto
  static double _getDouble(String key, double defaultValue) {
    try {
      final value = dotenv.env[key];
      if (value == null || value.isEmpty) {
        return defaultValue;
      }
      return double.parse(value);
    } catch (e) {
      AppLogger.error('Error obteniendo double de entorno $key', e);
      return defaultValue;
    }
  }

  /// Obtiene una lista de strings del entorno separada por comas
  static List<String> _getStringList(String key, List<String> defaultValue) {
    try {
      final value = dotenv.env[key];
      if (value == null || value.isEmpty) {
        return defaultValue;
      }
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.error('Error obteniendo lista de entorno $key', e);
      return defaultValue;
    }
  }

  // ========================================
  // MÉTODOS DE UTILIDAD
  // ========================================

  /// Verifica si todas las variables críticas están configuradas
  static bool validateCriticalVariables() {
    final criticalVars = [
      'FIREBASE_PROJECT_ID',
      'FIREBASE_API_KEY',
      'GOOGLE_MAPS_API_KEY',
      'ENCRYPTION_KEY_ID',
      'JWT_SECRET',
      'FIREBASE_SERVICE_ACCOUNT_EMAIL',
      'FIREBASE_PRIVATE_KEY',
      'FIREBASE_CLIENT_EMAIL',
      'FIREBASE_CLIENT_ID',
      'CLOUD_KMS_PROJECT_ID',
      'FIREBASE_APP_CHECK_SITE_KEY', // Agregado para Comment 8
    ];

    bool allValid = true;
    for (final varName in criticalVars) {
      final value = dotenv.env[varName];
      if (value == null || value.isEmpty) {
        AppLogger.error('Variable crítica faltante: $varName');
        allValid = false;
        continue;
      }

      // Validación específica para producción
      if (!isDevelopment) {
        // Rechazar placeholders en producción
        if (value.toUpperCase().contains('PLACEHOLDER') ||
            value.toLowerCase().contains('change') ||
            value.toLowerCase().contains('your-') ||
            value.toLowerCase().contains('xxx') ||
            value == 'undefined') {
          AppLogger.error(
              'Variable crítica con placeholder en producción: $varName');
          allValid = false;
        }

        // Validar formato de ENCRYPTION_KEY_ID
        if (varName == 'ENCRYPTION_KEY_ID') {
          final keyIdPattern = RegExp(
              r'^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$');
          if (!keyIdPattern.hasMatch(value)) {
            AppLogger.error(
                'ENCRYPTION_KEY_ID con formato inválido: $value');
            allValid = false;
          }
        }

        // Validar que las claves privadas empiecen correctamente
        if (varName == 'FIREBASE_PRIVATE_KEY') {
          if (!value.contains('-----BEGIN PRIVATE KEY-----')) {
            AppLogger.error(
                'FIREBASE_PRIVATE_KEY no parece ser una clave privada válida');
            allValid = false;
          }
        }
      }
    }

    return allValid;
  }

  /// Obtiene resumen de configuración para debugging
  static Map<String, dynamic> getConfigSummary() {
    return {
      'app_name': appName,
      'app_version': appVersion,
      'environment': environment,
      'debug_mode': debugMode,
      'firebase_project': firebaseProjectId,
      'base_url': apiBaseUrl,
      'features': {
        'price_negotiation': featurePriceNegotiation,
        'emergency_button': featureEmergencyButton,
        'chat_support': featureChatSupport,
        'biometric_auth': featureBiometricAuth,
      },
      'pricing': {
        'base_fare': baseFareAmount,
        'price_per_km': pricePerKm,
        'currency': currency,
      },
      'timeouts': {
        'driver_response': driverResponseTimeoutSeconds,
        'ride_request': rideRequestTimeoutMinutes,
        'payment': paymentTimeoutSeconds,
      }
    };
  }

  /// Log de configuración inicial (sin datos sensibles)
  static void logConfiguration() {
    AppLogger.info('🔧 Configuración de entorno cargada:');
    AppLogger.info('   - App: $appName v$appVersion ($environment)');
    AppLogger.info('   - Firebase: $firebaseProjectId');
    AppLogger.info('   - Región: $defaultCity, $defaultCountry');
    AppLogger.info('   - Features activas: ${_getActiveFeatures().join(', ')}');

    if (isDevelopment) {
      AppLogger.debug('   - URLs: API=$apiBaseUrl, WS=$websocketUrl');
      AppLogger.debug(
          '   - Timeouts: Driver=${driverResponseTimeoutSeconds}s, Payment=${paymentTimeoutSeconds}s');
    }
  }

  /// Obtiene lista de features activas
  static List<String> _getActiveFeatures() {
    final features = <String>[];
    if (featurePriceNegotiation) features.add('price_negotiation');
    if (featureScheduledRides) features.add('scheduled_rides');
    if (featureRideSharing) features.add('ride_sharing');
    if (featureEmergencyButton) features.add('emergency_button');
    if (featureChatSupport) features.add('chat_support');
    if (featureQrCodePickup) features.add('qr_pickup');
    if (featureBiometricAuth) features.add('biometric_auth');
    if (featureOfflineMode) features.add('offline_mode');
    if (featureLoyaltyProgram) features.add('loyalty_program');
    return features;
  }
}

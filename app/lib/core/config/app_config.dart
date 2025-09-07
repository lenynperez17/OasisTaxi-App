class AppConfig {
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment('apiBaseUrl', defaultValue: 'https://api.oasistaxi.com.pe/v1');
  
  // Google Maps API Keys - Configuración centralizada desde .env
  static const String googleMapsApiKey = String.fromEnvironment('googleMapsApiKey', defaultValue: '');
  static const String googlePlacesApiKey = String.fromEnvironment('googlePlacesApiKey', defaultValue: '');
  static const String googleDirectionsApiKey = String.fromEnvironment('googleDirectionsApiKey', defaultValue: '');
  
  // Environment Configuration
  static const String environment = String.fromEnvironment('environment', defaultValue: 'development');
  
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  
  // Configuración de timeouts
  static const int connectionTimeout = 30000; // 30 segundos
  static const int receiveTimeout = 30000; // 30 segundos
  
  // Configuración de reintentos
  static const int maxRetries = 3;
  static const int retryDelay = 1000; // 1 segundo
  
  // Configuración de cache
  static const int cacheMaxAge = 3600; // 1 hora
  static const int locationUpdateInterval = 10; // 10 segundos
  
  // Configuración de mapas
  static const double defaultZoom = 15.0;
  static const double defaultTilt = 0.0;
  static const double defaultBearing = 0.0;
  
  // Configuración de pagos
  static const double minPaymentAmount = 5.0;
  static const double maxPaymentAmount = 500.0;
  
  // Feature flags
  static const bool enableRideSharing = false;
  static const bool enableScheduledRides = false;
  static const bool enableCorporateAccounts = false;
}
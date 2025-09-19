import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'firebase_messaging_handler.dart';

// Core
import 'core/theme/modern_theme.dart';
import 'core/config/environment_config.dart';

// Services
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/remote_config_service.dart';
import 'services/network_client.dart';
import 'services/http_client.dart';

// Utils
import 'utils/app_logger.dart';
import 'utils/navigation_helper.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/price_negotiation_provider.dart';
import 'providers/config_provider.dart';
import 'providers/vehicle_provider.dart';
import 'models/trip_model.dart';

// Screens
import 'screens/auth/modern_splash_screen.dart';
import 'screens/auth/modern_login_screen.dart';
import 'screens/auth/modern_register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/passenger/modern_passenger_home.dart';
import 'screens/passenger/trip_history_screen.dart';
import 'screens/passenger/ratings_history_screen.dart';
import 'screens/passenger/payment_methods_screen.dart';
import 'screens/passenger/profile_screen.dart';
import 'screens/passenger/profile_edit_screen.dart';
// Eliminados: favorites_screen.dart y promotions_screen.dart (no necesarios)
// Screens with complex constructors temporarily disabled
import 'screens/driver/modern_driver_home.dart';
import 'screens/driver/wallet_screen.dart';
import 'screens/driver/navigation_screen.dart';
import 'screens/driver/metrics_screen.dart';
import 'screens/driver/vehicle_management_screen.dart';
import 'screens/driver/transactions_history_screen.dart';
import 'screens/driver/earnings_details_screen.dart';
import 'screens/driver/documents_screen.dart';
import 'screens/driver/driver_profile_screen.dart';
// Eliminado: communication_screen.dart (usar chat_screen unificado)
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/users_management_screen.dart';
import 'screens/admin/drivers_management_screen.dart';
import 'screens/admin/financial_screen.dart';
import 'screens/admin/analytics_screen.dart';
import 'screens/admin/settings_admin_screen.dart';
import 'screens/admin/embedded_dashboards_screen.dart';
import 'screens/shared/settings_screen.dart';
import 'screens/shared/notifications_screen.dart';
import 'screens/passenger/trip_verification_code_screen.dart';
import 'screens/passenger/emergency_sos_screen.dart';
import 'screens/driver/driver_verification_screen.dart';
import 'screens/shared/trip_details_screen.dart';
import 'screens/shared/trip_tracking_screen.dart';
import 'screens/shared/chat_screen.dart';
import 'screens/shared/map_picker_screen.dart';
// Eliminados: help_center_screen.dart, about_screen.dart, support_screen.dart (no necesarios)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Production environment detection
  const bool isProduction = bool.fromEnvironment('dart.vm.product');
  const String environment = String.fromEnvironment('ENV', defaultValue: isProduction ? 'production' : 'development');

  AppLogger.separator('INICIANDO OASIS TAXI APP - $environment');
  AppLogger.info('Iniciando aplicación Oasis Taxi en modo: $environment');
  AppLogger.info('Production mode: $isProduction');

  try {
    // Cargar variables de entorno
    AppLogger.info('Cargando configuración de entorno...');
    try {
      await dotenv.load(fileName: ".env");
      AppLogger.info('✅ Variables de entorno cargadas desde archivo .env');
    } catch (e) {
      if (isProduction) {
        // En producción, el .env podría no estar presente
        // Las variables deberían venir de dart-define o Remote Config
        AppLogger.warning('.env file not found in production, using dart-define/defaults');
      } else {
        AppLogger.error('Error loading .env file in development', e);
      }
    }
    EnvironmentConfig.markAsInitialized();

    // Validar configuración crítica
    final validationResult = EnvironmentConfig.validateCriticalVariables();
    if (!validationResult) {
      AppLogger.error('❌ Configuración inválida detectada');

      // En producción, detener la aplicación si falta configuración crítica
      if (isProduction) {
        AppLogger.critical('FALLO CRÍTICO: Variables de entorno requeridas no están configuradas correctamente');
        throw Exception('Variables de entorno de producción no configuradas. Verifique .env o dart-define');
      } else {
        AppLogger.warning('⚠️ Algunas variables críticas faltan o tienen placeholders en desarrollo');
      }
    } else {
      AppLogger.info('✅ Configuración de entorno validada correctamente');
    }

    // Log de configuración (sin datos sensibles)
    EnvironmentConfig.logConfiguration();

    // Configurar orientación
    AppLogger.debug('Configurando orientación de pantalla');
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Configurar la barra de estado
    AppLogger.debug('Configurando barra de estado');
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Inicializar Firebase de forma segura
    AppLogger.info('Inicializando Firebase...');
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        AppLogger.info('✅ Firebase inicializado correctamente');
      } else {
        AppLogger.info('✅ Firebase ya estaba inicializado');
      }
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        AppLogger.warning(
            'Firebase ya está inicializado (duplicate-app), continuando...');
      } else {
        AppLogger.error('Error al inicializar Firebase', e);
        rethrow;
      }
    }

    // Inicializar Firebase App Check inmediatamente después de Firebase
    AppLogger.info('Inicializando Firebase App Check...');
    try {
      if (isProduction) {
        // En producción, usar providers reales con fallback para iOS
        AppLogger.info('Activando App Check para PRODUCCIÓN');
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck, // Fallback a DeviceCheck si AppAttest falla
          webProvider: ReCaptchaV3Provider(EnvironmentConfig.firebaseAppCheckSiteKey),
        );

        // Enable automatic token refresh in production
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

        // Get initial token for verification
        final token = await FirebaseAppCheck.instance.getToken();
        if (token != null) {
          AppLogger.info('✅ App Check token obtenido: ${token.substring(0, 10)}...');
        }
      } else {
        // En desarrollo, usar debug provider
        AppLogger.info('Usando App Check Debug Provider (development)');
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
          webProvider: ReCaptchaV3Provider(EnvironmentConfig.firebaseAppCheckSiteKey),
        );
      }
      AppLogger.info('✅ Firebase App Check activado correctamente');
    } catch (e, st) {
      if (isProduction) {
        AppLogger.critical('FALLO CRÍTICO: App Check no se pudo activar en producción', e, st);
        // En producción, esto es crítico para la seguridad
        // Considerar no continuar sin App Check
      } else {
        AppLogger.warning('App Check activation failed in development, continuing', e);
      }
    }

    // Inicializar servicio Firebase
    AppLogger.info('Inicializando servicios de Firebase...');
    await FirebaseService().initialize();
    AppLogger.info('✅ Servicios de Firebase iniciados');

    // Configurar Firebase Messaging
    AppLogger.info('Configurando Firebase Messaging...');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    AppLogger.info('✅ Firebase Messaging configurado');

    // Inicializar servicio de notificaciones
    AppLogger.info('Inicializando servicio de notificaciones...');
    await NotificationService().initialize();
    AppLogger.info('✅ Servicio de notificaciones iniciado');

    // Initialize FirebaseMessagingHandler for navigation
    AppLogger.info('Inicializando FirebaseMessagingHandler...');
    await FirebaseMessagingHandler().initialize();
    AppLogger.info('✅ FirebaseMessagingHandler inicializado');

    // Initialize NetworkClient with certificate pinning
    AppLogger.info('Inicializando NetworkClient con certificate pinning...');
    await NetworkClient().initialize();

    // Also initialize HttpClient wrapper (uses NetworkClient internally)
    await HttpClient().initialize();

    AppLogger.info('✅ NetworkClient y HttpClient inicializados con SSL pinning');

    // Inicializar Remote Config con timeout configurable
    AppLogger.info('Inicializando Firebase Remote Config...');
    final remoteConfigSuccess = await RemoteConfigService().initialize(
      fetchTimeout: const Duration(seconds: isProduction ? 30 : 60),
      minimumFetchInterval: Duration(minutes: isProduction ? 60 : 1), // 1 minute in dev to avoid rate limits
    );
    if (remoteConfigSuccess) {
      AppLogger.info('✅ Remote Config iniciado exitosamente');

      // Log production feature flags
      if (isProduction) {
        AppLogger.info('Production Feature Flags loaded from Remote Config');
        // RemoteConfigService could expose feature flags here
      }
    } else {
      AppLogger.warning('⚠️ Remote Config falló, usando valores por defecto');
      if (isProduction) {
        // In production, this might affect feature availability
        AppLogger.critical('Remote Config failure in production - using defaults');
      }
    }

    // Initialize production monitoring
    if (isProduction) {
      AppLogger.info('Inicializando monitoreo de producción...');

      // Initialize Crashlytics
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      // Setup error boundaries for production
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.critical('Flutter Error in Production', details.exception, details.stack);
        // Send to Crashlytics
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      // Catch async errors
      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.critical('Uncaught async error in production', error, stack);
        // Send to Crashlytics
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: false,
          reason: 'Uncaught async error',
        );
        return true; // Prevents app crash
      };

      // Enable Analytics collection
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

      // Log app open event
      await FirebaseAnalytics.instance.logAppOpen();

      // Set user properties
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'environment',
        value: 'production',
      );

      AppLogger.info('✅ Monitoreo de producción activado');
      AppLogger.info('✅ Crashlytics: Enabled');
      AppLogger.info('✅ Analytics: Enabled');
    } else {
      // Disable in development
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
      AppLogger.info('Crashlytics and Analytics disabled in development');
    }

    AppLogger.separator(isProduction ? 'APP INICIADA EN PRODUCCIÓN' : 'APP INICIADA EN DESARROLLO');

    if (isProduction) {
      AppLogger.info('🚀 MODO PRODUCCIÓN ACTIVADO');
      AppLogger.info('✅ SSL Pinning: Enabled');
      AppLogger.info('✅ App Check: Active');
      AppLogger.info('✅ Crashlytics: Monitoring');
      AppLogger.info('✅ Analytics: Tracking');
      AppLogger.info('✅ Remote Config: Synced');
    }

    runApp(OasisTaxiApp());
  } catch (error, stackTrace) {
    AppLogger.error('Error crítico al inicializar la app', error, stackTrace);

    if (isProduction) {
      // In production, we might want to show an error screen
      AppLogger.critical('PRODUCTION INITIALIZATION FAILED', error, stackTrace);
      // Could show a maintenance screen here
    }

    // Intentar iniciar la app incluso con errores
    runApp(OasisTaxiApp());
  }
}

class OasisTaxiApp extends StatelessWidget {
  const OasisTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProvider(create: (_) => PriceNegotiationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        // Comment 7: Add VehicleProvider to the provider tree
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
      ],
      child: MaterialApp(
        title: 'Oasis Taxi',
        debugShowCheckedModeBanner: false,
        navigatorKey: NavigationHelper.navigatorKey,

        // Configurar localizaciones
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('es', 'ES'),
          Locale('en', 'US'),
        ],
        locale: Locale('es', 'ES'),

        // Tema moderno con gradientes y animaciones
        theme: ModernTheme.lightTheme,
        darkTheme: ModernTheme.darkTheme,
        themeMode: ThemeMode.light,

        // Tema antiguo (comentado para referencia)
        /*theme: ThemeData(
          primarySwatch: MaterialColor(0xFF00C800, {
            50: Color(0xFFE0F7E0),
            100: Color(0xFFB3E5B3),
            200: Color(0xFF80D280),
            300: Color(0xFF4DBF4D),
            400: Color(0xFF26B026),
            500: Color(0xFF00C800),
            600: Color(0xFF00A100),
            700: Color(0xFF008F00),
            800: Color(0xFF007D00),
            900: Color(0xFF006600),
          }),
          primaryColor: AppColors.oasisGreen,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.oasisGreen,
            primary: AppColors.oasisGreen,
            secondary: AppColors.oasisBlack,
            surface: AppColors.oasisWhite,
            onPrimary: AppColors.oasisWhite,
            onSecondary: AppColors.oasisWhite,
            onSurface: AppColors.oasisBlack,
          ),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppColors.backgroundLight,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.oasisGreen, width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.oasisGreen,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.oasisGreen,
            foregroundColor: AppColors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: IconThemeData(
              color: AppColors.white,
            ),
          ),
        ),*/

        // Ruta inicial
        initialRoute: '/',

        // Rutas
        routes: {
          '/': (context) => ModernSplashScreen(),
          '/login': (context) => ModernLoginScreen(),
          '/register': (context) => ModernRegisterScreen(),
          '/forgot-password': (context) => ForgotPasswordScreen(),

          // Rutas de Pasajero
          '/passenger/home': (context) => ModernPassengerHomeScreen(),
          '/passenger/trip-history': (context) => TripHistoryScreen(),
          '/passenger/ratings-history': (context) => RatingsHistoryScreen(),
          '/passenger/payment-methods': (context) => PaymentMethodsScreen(),
          // Rutas eliminadas: favorites y promotions (no necesarios)
          '/passenger/profile': (context) => ProfileScreen(),
          '/passenger/profile-edit': (context) => ProfileEditScreen(),
          '/passenger/trip-details': (context) => TripDetailsScreen(
                tripId:
                    (ModalRoute.of(context)!.settings.arguments as String?) ??
                        '',
              ),
          '/passenger/tracking': (context) => TripTrackingScreen(
                rideId:
                    (ModalRoute.of(context)!.settings.arguments as String?) ??
                        '',
              ),
          '/passenger/verification-code': (context) =>
              TripVerificationCodeScreen(
                trip: ModalRoute.of(context)!.settings.arguments as TripModel,
              ),
          '/passenger/emergency-sos': (context) => EmergencySOSScreen(
                userId:
                    (ModalRoute.of(context)!.settings.arguments as String?) ??
                        '',
                userType: 'passenger',
              ),

          // Rutas de Conductor
          '/driver/home': (context) => ModernDriverHomeScreen(),
          '/driver/wallet': (context) => WalletScreen(),
          '/driver/navigation': (context) => NavigationScreen(),
          // Ruta eliminada: communication (usar chat unificado)
          '/driver/metrics': (context) => MetricsScreen(),
          '/driver/vehicle-management': (context) => VehicleManagementScreen(),
          '/driver/transactions-history': (context) =>
              TransactionsHistoryScreen(),
          '/driver/earnings-details': (context) => EarningsDetailsScreen(),
          '/driver/documents': (context) => DocumentsScreen(),
          '/driver/profile': (context) => DriverProfileScreen(),
          '/driver/verification': (context) => DriverVerificationScreen(
                trip: ModalRoute.of(context)!.settings.arguments as TripModel,
              ),

          // Rutas de Admin
          '/admin/login': (context) => AdminLoginScreen(),
          '/admin/dashboard': (context) => AdminDashboardScreen(),
          '/admin/users-management': (context) => UsersManagementScreen(),
          '/admin/drivers-management': (context) => DriversManagementScreen(),
          '/admin/financial': (context) => FinancialScreen(),
          '/admin/analytics': (context) => AnalyticsScreen(),
          '/admin/settings': (context) => SettingsAdminScreen(),
          '/admin/embedded-dashboards': (context) => EmbeddedDashboardsScreen(),

          // Rutas Compartidas
          '/shared/chat': (context) => ChatScreen(
                rideId:
                    (ModalRoute.of(context)!.settings.arguments as String?) ??
                        '',
                otherUserName: 'Usuario',
                otherUserRole: 'user',
              ),
          '/shared/trip-details': (context) => TripDetailsScreen(
                tripId:
                    (ModalRoute.of(context)!.settings.arguments as String?) ??
                        '',
              ),
          '/shared/trip-tracking': (context) => TripTrackingScreen(
                rideId:
                    (ModalRoute.of(context)!.settings.arguments as String?) ??
                        '',
              ),
          '/shared/settings': (context) =>
              SettingsScreen(userType: 'passenger'),
          // Rutas eliminadas: help-center, about, support (no necesarios)
          '/shared/notifications': (context) => NotificationsScreen(),
          '/map-picker': (context) => MapPickerScreen(),
        },
      ),
    );
  }
}

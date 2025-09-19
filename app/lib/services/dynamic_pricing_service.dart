import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'http_client.dart';
import '../core/config/app_config.dart';
import '../models/location_model.dart';
import '../utils/app_logger.dart';

/// Servicio de Precios Dinámicos Avanzado para OasisTaxi Perú
///
/// Características principales:
/// - Tarificación dinámica basada en demanda, tráfico y condiciones
/// - Factores específicos de Perú (geografía, eventos, zonas económicas)
/// - Machine Learning para predicción de demanda
/// - Surge pricing inteligente
/// - Optimización de tarifas por zona
/// - Descuentos dinámicos y promociones
class DynamicPricingService {
  static final DynamicPricingService _instance =
      DynamicPricingService._internal();
  factory DynamicPricingService() => _instance;
  DynamicPricingService._internal();

  final HttpClient _httpClient = HttpClient();

  static const String _collectionPricing = 'dynamic_pricing';
  static const String _collectionDemand = 'demand_analytics';
  static const String _collectionSurge = 'surge_zones';
  static const String _collectionPromos = 'dynamic_promotions';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Caché de precios y configuraciones
  final Map<String, PricingConfiguration> _pricingCache = {};
  final Map<String, DemandData> _demandCache = {};
  final Map<String, SurgeZone> _surgeCache = {};
  Timer? _cacheRefreshTimer;
  Timer? _demandAnalyticsTimer;

  // Configuraciones base para Perú
  static const Map<String, double> _baseRatesPeruPEN = {
    'lima': 2.50, // Lima Metropolitana - S/ por km
    'arequipa': 2.20, // Arequipa - S/ por km
    'cusco': 2.80, // Cusco (turismo) - S/ por km
    'trujillo': 2.10, // Trujillo - S/ por km
    'piura': 2.00, // Piura - S/ por km
    'chiclayo': 2.15, // Chiclayo - S/ por km
    'huancayo': 2.05, // Huancayo - S/ por km
    'iquitos': 2.90, // Iquitos (remoto) - S/ por km
    'tacna': 2.25, // Tacna (frontera) - S/ por km
    'default': 2.30, // Ciudades menores - S/ por km
  };

  // Tarifas base por tipo de vehículo
  static const Map<String, double> _vehicleMultipliers = {
    'economy': 1.0, // Vehículos económicos
    'comfort': 1.3, // Vehículos cómodos
    'premium': 1.8, // Vehículos premium
    'xl': 1.5, // Vehículos grandes
    'moto': 0.7, // Mototaxis (solo provincias)
  };

  // Factores de tiempo específicos para Perú
  static const Map<String, double> _timeFactors = {
    'rush_morning': 1.4, // 7:00-9:00 AM
    'rush_evening': 1.5, // 6:00-8:00 PM
    'night': 1.3, // 10:00 PM-5:00 AM
    'weekend': 1.2, // Fines de semana
    'holiday': 1.6, // Feriados peruanos
    'normal': 1.0, // Horario normal
  };

  /// Inicializar el servicio de precios dinámicos
  Future<void> initialize() async {
    try {
      AppLogger.info('🏷️ Inicializando DynamicPricingService...');

      await _loadPricingConfigurations();
      await _initializeDemandTracking();
      await _setupSurgeZones();
      await _startRealTimeAnalytics();

      _startCacheRefreshTimer();

      AppLogger.info('✅ DynamicPricingService inicializado correctamente');
    } catch (e, stackTrace) {
      AppLogger.error(
          '❌ Error inicializando DynamicPricingService', e, stackTrace);
      rethrow;
    }
  }

  /// Cargar configuraciones de precios desde Firestore
  Future<void> _loadPricingConfigurations() async {
    try {
      final snapshot = await _firestore.collection(_collectionPricing).get();

      for (final doc in snapshot.docs) {
        final config = PricingConfiguration.fromFirestore(doc);
        _pricingCache[doc.id] = config;
      }

      AppLogger.info(
          '📊 Configuraciones de precios cargadas: ${_pricingCache.length}');
    } catch (e) {
      AppLogger.error('❌ Error cargando configuraciones de precios', e);
    }
  }

  /// Inicializar seguimiento de demanda
  Future<void> _initializeDemandTracking() async {
    try {
      // Configurar seguimiento en tiempo real de la demanda
      _firestore
          .collection(_collectionDemand)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .listen((snapshot) {
        _updateDemandCache(snapshot);
      });

      AppLogger.info('📈 Seguimiento de demanda inicializado');
    } catch (e) {
      AppLogger.error('❌ Error inicializando seguimiento de demanda', e);
    }
  }

  /// Configurar zonas de surge pricing
  Future<void> _setupSurgeZones() async {
    try {
      // Cargar zonas de surge activas
      final snapshot = await _firestore.collection(_collectionSurge).get();

      for (final doc in snapshot.docs) {
        final zone = SurgeZone.fromFirestore(doc);
        if (zone.isActive) {
          _surgeCache[doc.id] = zone;
        }
      }

      AppLogger.info('🚨 Zonas de surge cargadas: ${_surgeCache.length}');
    } catch (e) {
      AppLogger.error('❌ Error configurando zonas de surge', e);
    }
  }

  /// Calcular precio dinámico para un viaje
  Future<PriceCalculationResult> calculateDynamicPrice({
    required LocationModel origin,
    required LocationModel destination,
    required String vehicleType,
    required String userId,
    DateTime? requestTime,
    Map<String, dynamic>? additionalFactors,
  }) async {
    try {
      AppLogger.performance('DynamicPricing.calculatePrice', 0);
      final stopwatch = Stopwatch()..start();

      requestTime ??= DateTime.now();

      // 1. Calcular distancia y tiempo estimado
      final routeInfo = await _calculateRouteInfo(origin, destination);

      // 2. Determinar zona geográfica
      final zone = _determineGeographicZone(origin);

      // 3. Obtener tarifa base
      final baseRate = _getBaseRate(zone, vehicleType);

      // 4. Calcular factores dinámicos
      final dynamicFactors = await _calculateDynamicFactors(
        origin: origin,
        destination: destination,
        requestTime: requestTime,
        routeInfo: routeInfo,
      );

      // 5. Aplicar surge pricing si aplica
      final surgeMultiplier = _calculateSurgeMultiplier(origin, requestTime);

      // 6. Calcular descuentos y promociones
      final discounts = await _calculateDiscounts(
        userId: userId,
        origin: origin,
        destination: destination,
        requestTime: requestTime,
      );

      // 7. Calcular precio final
      final calculation = _calculateFinalPrice(
        baseRate: baseRate,
        distance: routeInfo.distanceKm,
        duration: routeInfo.durationMinutes,
        dynamicFactors: dynamicFactors,
        surgeMultiplier: surgeMultiplier,
        discounts: discounts,
        vehicleType: vehicleType,
      );

      // 8. Registrar cálculo para analytics
      await _recordPriceCalculation(calculation);

      stopwatch.stop();
      AppLogger.performance(
          'DynamicPricing.calculatePrice', stopwatch.elapsedMilliseconds);

      return calculation;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Error calculando precio dinámico', e, stackTrace);

      // Fallback a precio fijo en caso de error
      return _calculateFallbackPrice(origin, destination, vehicleType);
    }
  }

  /// Calcular información de ruta (distancia, tiempo, tráfico)
  Future<RouteInfo> _calculateRouteInfo(
      LocationModel origin, LocationModel destination) async {
    try {
      // Usar Google Directions API para obtener información precisa
      final apiKey = AppConfig.googleMapsApiKey;
      final url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&traffic_model=best_guess'
          '&departure_time=now'
          '&key=$apiKey';

      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          return RouteInfo(
            distanceKm: (leg['distance']['value'] / 1000.0),
            durationMinutes: (leg['duration']['value'] / 60.0),
            durationInTrafficMinutes: leg['duration_in_traffic'] != null
                ? (leg['duration_in_traffic']['value'] / 60.0)
                : (leg['duration']['value'] / 60.0),
            polyline: route['overview_polyline']['points'],
          );
        }
      }

      // Fallback a cálculo directo si falla la API
      final distance = Geolocator.distanceBetween(
            origin.latitude,
            origin.longitude,
            destination.latitude,
            destination.longitude,
          ) /
          1000.0; // Convertir a km

      return RouteInfo(
        distanceKm: distance,
        durationMinutes:
            distance * 2.5, // Estimación: 24 km/h promedio en ciudad
        durationInTrafficMinutes: distance * 3.0, // Con tráfico
        polyline: '',
      );
    } catch (e) {
      AppLogger.error('❌ Error calculando información de ruta', e);

      // Fallback básico
      final distance = Geolocator.distanceBetween(
            origin.latitude,
            origin.longitude,
            destination.latitude,
            destination.longitude,
          ) /
          1000.0;

      return RouteInfo(
        distanceKm: distance,
        durationMinutes: distance * 3.0,
        durationInTrafficMinutes: distance * 4.0,
        polyline: '',
      );
    }
  }

  /// Determinar zona geográfica del origen
  String _determineGeographicZone(LocationModel location) {
    // Coordenadas aproximadas de las principales ciudades de Perú
    final cityZones = {
      'lima': {'lat': -12.046374, 'lng': -77.042793, 'radius': 50000},
      'arequipa': {'lat': -16.409047, 'lng': -71.537451, 'radius': 25000},
      'cusco': {'lat': -13.531950, 'lng': -71.967463, 'radius': 20000},
      'trujillo': {'lat': -8.115833, 'lng': -79.029167, 'radius': 20000},
      'piura': {'lat': -5.196111, 'lng': -80.632222, 'radius': 15000},
      'chiclayo': {'lat': -6.777778, 'lng': -79.844444, 'radius': 15000},
      'huancayo': {'lat': -12.066667, 'lng': -75.200000, 'radius': 10000},
      'iquitos': {'lat': -3.749912, 'lng': -73.247314, 'radius': 15000},
      'tacna': {'lat': -18.014444, 'lng': -70.258889, 'radius': 10000},
    };

    for (final entry in cityZones.entries) {
      final cityName = entry.key;
      final cityData = entry.value;

      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        cityData['lat'] as double,
        cityData['lng'] as double,
      );

      if (distance <= (cityData['radius'] as double)) {
        return cityName;
      }
    }

    return 'default';
  }

  /// Obtener tarifa base por zona y tipo de vehículo
  double _getBaseRate(String zone, String vehicleType) {
    final baseRate = _baseRatesPeruPEN[zone] ?? _baseRatesPeruPEN['default']!;
    final vehicleMultiplier = _vehicleMultipliers[vehicleType] ?? 1.0;

    return baseRate * vehicleMultiplier;
  }

  /// Calcular factores dinámicos
  Future<DynamicFactors> _calculateDynamicFactors({
    required LocationModel origin,
    required LocationModel destination,
    required DateTime requestTime,
    required RouteInfo routeInfo,
  }) async {
    try {
      // Factor de tiempo (hora del día, día de la semana)
      final timeFactor = _calculateTimeFactor(requestTime);

      // Factor de demanda local
      final demandFactor = await _calculateDemandFactor(origin, requestTime);

      // Factor de tráfico
      final trafficFactor = _calculateTrafficFactor(routeInfo);

      // Factor climático (lluvia en Lima, por ejemplo)
      final weatherFactor = await _calculateWeatherFactor(origin, requestTime);

      // Factor de eventos especiales
      final eventFactor =
          await _calculateEventFactor(origin, destination, requestTime);

      return DynamicFactors(
        timeFactor: timeFactor,
        demandFactor: demandFactor,
        trafficFactor: trafficFactor,
        weatherFactor: weatherFactor,
        eventFactor: eventFactor,
      );
    } catch (e) {
      AppLogger.error('❌ Error calculando factores dinámicos', e);
      return DynamicFactors.normal();
    }
  }

  /// Calcular factor de tiempo
  double _calculateTimeFactor(DateTime requestTime) {
    final hour = requestTime.hour;
    final dayOfWeek = requestTime.weekday;

    // Verificar si es feriado peruano
    if (_isPeruvianHoliday(requestTime)) {
      return _timeFactors['holiday']!;
    }

    // Fin de semana
    if (dayOfWeek >= 6) {
      return _timeFactors['weekend']!;
    }

    // Horas pico matutinas (7:00-9:00 AM)
    if (hour >= 7 && hour <= 9) {
      return _timeFactors['rush_morning']!;
    }

    // Horas pico vespertinas (6:00-8:00 PM)
    if (hour >= 18 && hour <= 20) {
      return _timeFactors['rush_evening']!;
    }

    // Horas nocturnas (10:00 PM-5:00 AM)
    if (hour >= 22 || hour <= 5) {
      return _timeFactors['night']!;
    }

    return _timeFactors['normal']!;
  }

  /// Verificar si es feriado peruano
  bool _isPeruvianHoliday(DateTime date) {
    final holidays2024 = [
      DateTime(2024, 1, 1), // Año Nuevo
      DateTime(2024, 3, 28), // Jueves Santo (estimado)
      DateTime(2024, 3, 29), // Viernes Santo (estimado)
      DateTime(2024, 5, 1), // Día del Trabajo
      DateTime(2024, 6, 29), // San Pedro y San Pablo
      DateTime(2024, 7, 23), // Día de la Fuerza Aérea
      DateTime(2024, 7, 28), // Fiestas Patrias
      DateTime(2024, 7, 29), // Fiestas Patrias
      DateTime(2024, 8, 30), // Santa Rosa de Lima
      DateTime(2024, 10, 8), // Combate de Angamos
      DateTime(2024, 11, 1), // Todos los Santos
      DateTime(2024, 12, 8), // Inmaculada Concepción
      DateTime(2024, 12, 25), // Navidad
    ];

    return holidays2024.any((holiday) =>
        holiday.year == date.year &&
        holiday.month == date.month &&
        holiday.day == date.day);
  }

  /// Calcular factor de demanda
  Future<double> _calculateDemandFactor(
      LocationModel location, DateTime requestTime) async {
    try {
      // Buscar datos de demanda en caché
      final zoneKey =
          '${location.latitude.toStringAsFixed(2)}_${location.longitude.toStringAsFixed(2)}';
      final demandData = _demandCache[zoneKey];

      if (demandData != null) {
        return demandData.calculateDemandMultiplier(requestTime);
      }

      return 1.0; // Factor neutral si no hay datos
    } catch (e) {
      AppLogger.error('❌ Error calculando factor de demanda', e);
      return 1.0;
    }
  }

  /// Calcular factor de tráfico
  double _calculateTrafficFactor(RouteInfo routeInfo) {
    if (routeInfo.durationInTrafficMinutes > routeInfo.durationMinutes) {
      final trafficDelay =
          routeInfo.durationInTrafficMinutes - routeInfo.durationMinutes;
      final delayPercent = trafficDelay / routeInfo.durationMinutes;

      // Incrementar precio entre 0% y 30% basado en el tráfico
      return 1.0 + (delayPercent * 0.3).clamp(0.0, 0.3);
    }

    return 1.0;
  }

  /// Calcular factor climático
  Future<double> _calculateWeatherFactor(
      LocationModel location, DateTime requestTime) async {
    try {
      // En una implementación completa, se usaría una API meteorológica
      // Por ahora, simulamos condiciones climáticas básicas

      // Factor de lluvia más probable en Lima durante el invierno
      if (location.latitude > -12.5 &&
          location.latitude < -11.5 &&
          location.longitude > -77.5 &&
          location.longitude < -76.5) {
        final month = requestTime.month;
        if (month >= 6 && month <= 9) {
          // Invierno en Lima, posible lluvia/neblina
          return 1.15;
        }
      }

      return 1.0;
    } catch (e) {
      AppLogger.error('❌ Error calculando factor climático', e);
      return 1.0;
    }
  }

  /// Calcular factor de eventos especiales
  Future<double> _calculateEventFactor(LocationModel origin,
      LocationModel destination, DateTime requestTime) async {
    try {
      // Consultar eventos especiales en Firestore
      final eventsQuery = await _firestore
          .collection('special_events')
          .where('date',
              isEqualTo: Timestamp.fromDate(DateTime(
                  requestTime.year, requestTime.month, requestTime.day)))
          .where('isActive', isEqualTo: true)
          .get();

      for (final eventDoc in eventsQuery.docs) {
        final eventData = eventDoc.data();
        final eventLocation = eventData['location'] as GeoPoint;

        // Verificar si el origen o destino están cerca del evento
        final distanceToEvent = Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          eventLocation.latitude,
          eventLocation.longitude,
        );

        if (distanceToEvent <= (eventData['radiusMeters'] as num).toDouble()) {
          return (eventData['pricingMultiplier'] as num).toDouble();
        }
      }

      return 1.0;
    } catch (e) {
      AppLogger.error('❌ Error calculando factor de eventos', e);
      return 1.0;
    }
  }

  /// Calcular multiplicador de surge pricing
  double _calculateSurgeMultiplier(
      LocationModel location, DateTime requestTime) {
    try {
      for (final surgeZone in _surgeCache.values) {
        if (surgeZone.containsLocation(location) &&
            surgeZone.isActiveAt(requestTime)) {
          return surgeZone.multiplier;
        }
      }

      return 1.0;
    } catch (e) {
      AppLogger.error('❌ Error calculando surge multiplier', e);
      return 1.0;
    }
  }

  /// Calcular descuentos y promociones
  Future<DiscountInfo> _calculateDiscounts({
    required String userId,
    required LocationModel origin,
    required LocationModel destination,
    required DateTime requestTime,
  }) async {
    try {
      double totalDiscount = 0.0;
      final appliedDiscounts = <String>[];

      // Consultar promociones activas
      final promoQuery = await _firestore
          .collection(_collectionPromos)
          .where('isActive', isEqualTo: true)
          .where('startDate',
              isLessThanOrEqualTo: Timestamp.fromDate(requestTime))
          .where('endDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(requestTime))
          .get();

      for (final promoDoc in promoQuery.docs) {
        final promo = DynamicPromotion.fromFirestore(promoDoc);

        if (await promo.isApplicable(
            userId, origin, destination, requestTime)) {
          totalDiscount += promo.discountAmount;
          appliedDiscounts.add(promo.name);
        }
      }

      return DiscountInfo(
        totalDiscount: totalDiscount.clamp(0.0, 0.5), // Máximo 50% de descuento
        appliedDiscounts: appliedDiscounts,
      );
    } catch (e) {
      AppLogger.error('❌ Error calculando descuentos', e);
      return DiscountInfo(totalDiscount: 0.0, appliedDiscounts: []);
    }
  }

  /// Calcular precio final
  PriceCalculationResult _calculateFinalPrice({
    required double baseRate,
    required double distance,
    required double duration,
    required DynamicFactors dynamicFactors,
    required double surgeMultiplier,
    required DiscountInfo discounts,
    required String vehicleType,
  }) {
    // Precio base por distancia
    double basePrice = baseRate * distance;

    // Precio mínimo por ciudad (tarifa mínima)
    const double minimumFare = 8.0; // S/ 8.00 mínimo en Perú
    basePrice = math.max(basePrice, minimumFare);

    // Aplicar factores dinámicos
    double dynamicPrice = basePrice * dynamicFactors.combinedFactor;

    // Aplicar surge pricing
    double surgePrice = dynamicPrice * surgeMultiplier;

    // Aplicar descuentos
    double finalPrice = surgePrice * (1.0 - discounts.totalDiscount);

    // Redondear a 2 decimales
    finalPrice = double.parse(finalPrice.toStringAsFixed(2));

    return PriceCalculationResult(
      basePrice: double.parse(basePrice.toStringAsFixed(2)),
      dynamicPrice: double.parse(dynamicPrice.toStringAsFixed(2)),
      surgePrice: double.parse(surgePrice.toStringAsFixed(2)),
      finalPrice: finalPrice,
      currency: 'PEN',
      factors: dynamicFactors,
      surgeMultiplier: surgeMultiplier,
      discounts: discounts,
      vehicleType: vehicleType,
      distance: distance,
      estimatedDuration: duration,
      calculatedAt: DateTime.now(),
    );
  }

  /// Precio de fallback en caso de error
  PriceCalculationResult _calculateFallbackPrice(
      LocationModel origin, LocationModel destination, String vehicleType) {
    final distance = Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          destination.latitude,
          destination.longitude,
        ) /
        1000.0;

    final baseRate = _baseRatesPeruPEN['default']!;
    final vehicleMultiplier = _vehicleMultipliers[vehicleType] ?? 1.0;
    final price = math.max(baseRate * distance * vehicleMultiplier, 8.0);

    return PriceCalculationResult(
      basePrice: price,
      dynamicPrice: price,
      surgePrice: price,
      finalPrice: double.parse(price.toStringAsFixed(2)),
      currency: 'PEN',
      factors: DynamicFactors.normal(),
      surgeMultiplier: 1.0,
      discounts: DiscountInfo(totalDiscount: 0.0, appliedDiscounts: []),
      vehicleType: vehicleType,
      distance: distance,
      estimatedDuration: distance * 3.0,
      calculatedAt: DateTime.now(),
      isFallback: true,
    );
  }

  /// Registrar cálculo de precio para analytics
  Future<void> _recordPriceCalculation(
      PriceCalculationResult calculation) async {
    try {
      await _firestore.collection('price_calculations').add({
        'basePrice': calculation.basePrice,
        'finalPrice': calculation.finalPrice,
        'surgeMultiplier': calculation.surgeMultiplier,
        'vehicleType': calculation.vehicleType,
        'distance': calculation.distance,
        'factors': calculation.factors.toMap(),
        'appliedDiscounts': calculation.discounts.appliedDiscounts,
        'calculatedAt': FieldValue.serverTimestamp(),
        'isFallback': calculation.isFallback,
      });
    } catch (e) {
      AppLogger.error('❌ Error registrando cálculo de precio', e);
    }
  }

  /// Iniciar analytics en tiempo real
  Future<void> _startRealTimeAnalytics() async {
    _demandAnalyticsTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _updateDemandAnalytics();
    });
  }

  /// Actualizar analytics de demanda
  Future<void> _updateDemandAnalytics() async {
    try {
      // Análisis de demanda cada 5 minutos
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

      // Obtener solicitudes recientes por zona
      final recentTrips = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
          .get();

      final demandByZone = <String, int>{};

      for (final tripDoc in recentTrips.docs) {
        final tripData = tripDoc.data();
        final originData = tripData['origin'] as Map<String, dynamic>?;

        if (originData != null) {
          final location = LocationModel(
            latitude: (originData['latitude'] as num).toDouble(),
            longitude: (originData['longitude'] as num).toDouble(),
            address: originData['address'] as String? ?? '',
          );

          final zone = _determineGeographicZone(location);
          demandByZone[zone] = (demandByZone[zone] ?? 0) + 1;
        }
      }

      // Actualizar datos de demanda
      for (final entry in demandByZone.entries) {
        await _firestore
            .collection(_collectionDemand)
            .doc('${entry.key}_$now')
            .set({
          'zone': entry.key,
          'tripCount': entry.value,
          'timestamp': FieldValue.serverTimestamp(),
          'period': '5min',
        });
      }
    } catch (e) {
      AppLogger.error('❌ Error actualizando analytics de demanda', e);
    }
  }

  /// Actualizar caché de demanda
  void _updateDemandCache(QuerySnapshot snapshot) {
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final demandData = DemandData.fromFirestore(doc);

      final zoneKey = data['zone'] as String? ?? 'default';
      _demandCache[zoneKey] = demandData;
    }
  }

  /// Iniciar timer de actualización de caché
  void _startCacheRefreshTimer() {
    _cacheRefreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _refreshCaches();
    });
  }

  /// Refrescar cachés
  Future<void> _refreshCaches() async {
    await Future.wait([
      _loadPricingConfigurations(),
      _setupSurgeZones(),
    ]);
  }

  /// Obtener precio estimado rápido (sin factores dinámicos complejos)
  Future<double> getEstimatedPrice({
    required LocationModel origin,
    required LocationModel destination,
    required String vehicleType,
  }) async {
    try {
      final distance = Geolocator.distanceBetween(
            origin.latitude,
            origin.longitude,
            destination.latitude,
            destination.longitude,
          ) /
          1000.0;

      final zone = _determineGeographicZone(origin);
      final baseRate = _getBaseRate(zone, vehicleType);
      final estimatedPrice = math.max(baseRate * distance, 8.0);

      return double.parse(estimatedPrice.toStringAsFixed(2));
    } catch (e) {
      AppLogger.error('❌ Error obteniendo precio estimado', e);
      return 15.0; // Precio por defecto
    }
  }

  /// Obtener zonas de surge activas
  List<SurgeZone> getActiveSurgeZones() {
    return _surgeCache.values
        .where((zone) => zone.isActiveAt(DateTime.now()))
        .toList();
  }

  /// Limpiar recursos
  void dispose() {
    _cacheRefreshTimer?.cancel();
    _demandAnalyticsTimer?.cancel();
    _pricingCache.clear();
    _demandCache.clear();
    _surgeCache.clear();
  }
}

/// Configuración de precios por zona
class PricingConfiguration {
  final String zone;
  final double baseRate;
  final Map<String, double> vehicleMultipliers;
  final Map<String, double> timeFactors;
  final bool isActive;
  final DateTime updatedAt;

  PricingConfiguration({
    required this.zone,
    required this.baseRate,
    required this.vehicleMultipliers,
    required this.timeFactors,
    required this.isActive,
    required this.updatedAt,
  });

  factory PricingConfiguration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PricingConfiguration(
      zone: doc.id,
      baseRate: (data['baseRate'] as num).toDouble(),
      vehicleMultipliers:
          Map<String, double>.from(data['vehicleMultipliers'] ?? {}),
      timeFactors: Map<String, double>.from(data['timeFactors'] ?? {}),
      isActive: data['isActive'] as bool? ?? true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Información de ruta
class RouteInfo {
  final double distanceKm;
  final double durationMinutes;
  final double durationInTrafficMinutes;
  final String polyline;

  RouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.durationInTrafficMinutes,
    required this.polyline,
  });
}

/// Factores dinámicos
class DynamicFactors {
  final double timeFactor;
  final double demandFactor;
  final double trafficFactor;
  final double weatherFactor;
  final double eventFactor;

  DynamicFactors({
    required this.timeFactor,
    required this.demandFactor,
    required this.trafficFactor,
    required this.weatherFactor,
    required this.eventFactor,
  });

  factory DynamicFactors.normal() => DynamicFactors(
        timeFactor: 1.0,
        demandFactor: 1.0,
        trafficFactor: 1.0,
        weatherFactor: 1.0,
        eventFactor: 1.0,
      );

  double get combinedFactor =>
      timeFactor * demandFactor * trafficFactor * weatherFactor * eventFactor;

  Map<String, dynamic> toMap() => {
        'timeFactor': timeFactor,
        'demandFactor': demandFactor,
        'trafficFactor': trafficFactor,
        'weatherFactor': weatherFactor,
        'eventFactor': eventFactor,
        'combinedFactor': combinedFactor,
      };
}

/// Información de descuentos
class DiscountInfo {
  final double totalDiscount;
  final List<String> appliedDiscounts;

  DiscountInfo({
    required this.totalDiscount,
    required this.appliedDiscounts,
  });
}

/// Zona de surge pricing
class SurgeZone {
  final String id;
  final String name;
  final List<LocationModel> boundaries;
  final double multiplier;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;
  final String reason;

  SurgeZone({
    required this.id,
    required this.name,
    required this.boundaries,
    required this.multiplier,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.reason,
  });

  factory SurgeZone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final boundariesData = data['boundaries'] as List<dynamic>? ?? [];
    final boundaries = boundariesData
        .map((boundary) => LocationModel(
              latitude: (boundary['latitude'] as num).toDouble(),
              longitude: (boundary['longitude'] as num).toDouble(),
              address: '',
            ))
        .toList();

    return SurgeZone(
      id: doc.id,
      name: data['name'] as String? ?? '',
      boundaries: boundaries,
      multiplier: (data['multiplier'] as num).toDouble(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool? ?? false,
      reason: data['reason'] as String? ?? '',
    );
  }

  bool containsLocation(LocationModel location) {
    if (boundaries.length < 3) return false;

    // Algoritmo point-in-polygon simple
    int crossings = 0;
    for (int i = 0; i < boundaries.length; i++) {
      final j = (i + 1) % boundaries.length;

      if (((boundaries[i].latitude <= location.latitude) &&
              (location.latitude < boundaries[j].latitude)) ||
          ((boundaries[j].latitude <= location.latitude) &&
              (location.latitude < boundaries[i].latitude))) {
        final intersection =
            (boundaries[j].longitude - boundaries[i].longitude) *
                    (location.latitude - boundaries[i].latitude) /
                    (boundaries[j].latitude - boundaries[i].latitude) +
                boundaries[i].longitude;

        if (location.longitude < intersection) {
          crossings++;
        }
      }
    }

    return (crossings % 2) == 1;
  }

  bool isActiveAt(DateTime time) {
    return isActive && time.isAfter(startTime) && time.isBefore(endTime);
  }
}

/// Datos de demanda
class DemandData {
  final String zone;
  final int tripCount;
  final DateTime timestamp;
  final String period;

  DemandData({
    required this.zone,
    required this.tripCount,
    required this.timestamp,
    required this.period,
  });

  factory DemandData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return DemandData(
      zone: data['zone'] as String? ?? '',
      tripCount: data['tripCount'] as int? ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      period: data['period'] as String? ?? '5min',
    );
  }

  double calculateDemandMultiplier(DateTime requestTime) {
    // Factor basado en el número de viajes en el período
    if (tripCount <= 2) return 0.9; // Baja demanda: -10%
    if (tripCount <= 5) return 1.0; // Normal
    if (tripCount <= 10) return 1.2; // Alta demanda: +20%
    if (tripCount <= 20) return 1.4; // Muy alta: +40%
    return 1.6; // Extrema: +60%
  }
}

/// Promoción dinámica
class DynamicPromotion {
  final String id;
  final String name;
  final String type;
  final double discountAmount;
  final Map<String, dynamic> conditions;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final List<String> applicableVehicleTypes;
  final List<String> applicableZones;

  DynamicPromotion({
    required this.id,
    required this.name,
    required this.type,
    required this.discountAmount,
    required this.conditions,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.applicableVehicleTypes,
    required this.applicableZones,
  });

  factory DynamicPromotion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return DynamicPromotion(
      id: doc.id,
      name: data['name'] as String? ?? '',
      type: data['type'] as String? ?? '',
      discountAmount: (data['discountAmount'] as num).toDouble(),
      conditions: data['conditions'] as Map<String, dynamic>? ?? {},
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool? ?? false,
      applicableVehicleTypes:
          List<String>.from(data['applicableVehicleTypes'] ?? []),
      applicableZones: List<String>.from(data['applicableZones'] ?? []),
    );
  }

  Future<bool> isApplicable(String userId, LocationModel origin,
      LocationModel destination, DateTime requestTime) async {
    if (!isActive) return false;
    if (requestTime.isBefore(startDate) || requestTime.isAfter(endDate))
      return false;

    // Verificar condiciones específicas
    // En una implementación completa, aquí se verificarían las condiciones de la promoción

    return true;
  }
}

/// Resultado del cálculo de precio
class PriceCalculationResult {
  final double basePrice;
  final double dynamicPrice;
  final double surgePrice;
  final double finalPrice;
  final String currency;
  final DynamicFactors factors;
  final double surgeMultiplier;
  final DiscountInfo discounts;
  final String vehicleType;
  final double distance;
  final double estimatedDuration;
  final DateTime calculatedAt;
  final bool isFallback;

  PriceCalculationResult({
    required this.basePrice,
    required this.dynamicPrice,
    required this.surgePrice,
    required this.finalPrice,
    required this.currency,
    required this.factors,
    required this.surgeMultiplier,
    required this.discounts,
    required this.vehicleType,
    required this.distance,
    required this.estimatedDuration,
    required this.calculatedAt,
    this.isFallback = false,
  });

  Map<String, dynamic> toMap() => {
        'basePrice': basePrice,
        'dynamicPrice': dynamicPrice,
        'surgePrice': surgePrice,
        'finalPrice': finalPrice,
        'currency': currency,
        'factors': factors.toMap(),
        'surgeMultiplier': surgeMultiplier,
        'totalDiscount': discounts.totalDiscount,
        'appliedDiscounts': discounts.appliedDiscounts,
        'vehicleType': vehicleType,
        'distance': distance,
        'estimatedDuration': estimatedDuration,
        'calculatedAt': calculatedAt.toIso8601String(),
        'isFallback': isFallback,
      };
}

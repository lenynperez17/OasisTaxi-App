import '../utils/app_logger.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'http_client.dart';
import 'firebase_service.dart';
import '../core/config/environment_config.dart';

/// Servicio completo para Google Maps
/// ✅ IMPLEMENTACIÓN REAL COMPLETA
/// Incluye: Geocoding, Directions, Places, Distance Matrix, Rutas optimizadas
class GoogleMapsService {
  static final GoogleMapsService _instance = GoogleMapsService._internal();
  factory GoogleMapsService() => _instance;
  GoogleMapsService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final HttpClient _httpClient = HttpClient();

  bool _initialized = false;
  late String _googleMapsApiKey;

  // URLs de la API de Google Maps
  static const String directionsApiUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
  static const String placesApiUrl =
      'https://maps.googleapis.com/maps/api/place';
  static const String geocodingApiUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const String distanceMatrixUrl =
      'https://maps.googleapis.com/maps/api/distancematrix/json';

  /// Inicializar el servicio de Google Maps ✅ IMPLEMENTACIÓN REAL
  Future<void> initialize({
    required String googleMapsApiKey,
  }) async {
    if (_initialized) return;

    try {
      _googleMapsApiKey = googleMapsApiKey;
      await _firebaseService.initialize();

      _initialized = true;
      AppLogger.debug(
          '🗺️ GoogleMapsService: Service initialized successfully');

      await _firebaseService.analytics
          ?.logEvent(name: 'google_maps_service_initialized');
    } catch (e) {
      AppLogger.debug('🗺️ GoogleMapsService: Error initializing - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      rethrow;
    }
  }

  /// Obtener ubicación actual ✅ IMPLEMENTACIÓN REAL
  Future<LocationResult> getCurrentLocation() async {
    try {
      // Verificar permisos
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.error(
            'Los servicios de ubicación están deshabilitados');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.error('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.error(
            'Permisos de ubicación denegados permanentemente');
      }

      // Obtener ubicación
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      await _firebaseService.analytics?.logEvent(
        name: 'location_obtained',
        parameters: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        },
      );

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (e) {
      AppLogger.debug(
          '🗺️ GoogleMapsService: Error getting current location - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return LocationResult.error('Error obteniendo ubicación: $e');
    }
  }

  /// Geocoding: convertir dirección a coordenadas ✅ IMPLEMENTACIÓN REAL
  Future<GeocodingResult> geocodeAddress(String address) async {
    try {
      final url = Uri.parse(geocodingApiUrl).replace(queryParameters: {
        'address': address,
        'key': _googleMapsApiKey,
        'language': 'es',
        'region': EnvironmentConfig.defaultCountry.toLowerCase(), // ${EnvironmentConfig.defaultCountry}
      });

      final response = await _httpClient.get(url.toString());
      final data = response.jsonBody;

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];
        final location = result['geometry']['location'];

        await _firebaseService.analytics?.logEvent(
          name: 'geocoding_success',
          parameters: {
            'address': address,
            'latitude': location['lat'],
            'longitude': location['lng'],
          },
        );

        return GeocodingResult.success(
          latitude: location['lat'].toDouble(),
          longitude: location['lng'].toDouble(),
          formattedAddress: result['formatted_address'],
          placeId: result['place_id'],
        );
      } else {
        AppLogger.debug(
            '🗺️ GoogleMapsService: Geocoding error - ${data['status']}');
        return GeocodingResult.error('No se pudo geocodificar la dirección');
      }
    } catch (e) {
      AppLogger.debug('🗺️ GoogleMapsService: Error geocoding address - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return GeocodingResult.error('Error geocodificando dirección: $e');
    }
  }

  /// Reverse Geocoding: convertir coordenadas a dirección ✅ IMPLEMENTACIÓN REAL
  Future<ReverseGeocodingResult> reverseGeocode(
      double latitude, double longitude) async {
    try {
      final url = Uri.parse(geocodingApiUrl).replace(queryParameters: {
        'latlng': '$latitude,$longitude',
        'key': _googleMapsApiKey,
        'language': 'es',
        'region': EnvironmentConfig.defaultCountry.toLowerCase(),
      });

      final response = await _httpClient.get(url.toString());
      final data = response.jsonBody;

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];

        await _firebaseService.analytics?.logEvent(
          name: 'reverse_geocoding_success',
          parameters: {
            'latitude': latitude,
            'longitude': longitude,
          },
        );

        return ReverseGeocodingResult.success(
          formattedAddress: result['formatted_address'],
          streetNumber:
              _extractComponent(result['address_components'], 'street_number'),
          route: _extractComponent(result['address_components'], 'route'),
          locality: _extractComponent(result['address_components'], 'locality'),
          administrativeArea: _extractComponent(
              result['address_components'], 'administrative_area_level_1'),
          country: _extractComponent(result['address_components'], 'country'),
          postalCode:
              _extractComponent(result['address_components'], 'postal_code'),
          placeId: result['place_id'],
        );
      } else {
        AppLogger.debug(
            '🗺️ GoogleMapsService: Reverse geocoding error - ${data['status']}');
        return ReverseGeocodingResult.error('No se pudo obtener la dirección');
      }
    } catch (e) {
      AppLogger.debug('🗺️ GoogleMapsService: Error reverse geocoding - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return ReverseGeocodingResult.error('Error obteniendo dirección: $e');
    }
  }

  /// Obtener direcciones entre dos puntos ✅ IMPLEMENTACIÓN REAL
  Future<DirectionsResult> getDirections({
    required LatLng origin,
    required LatLng destination,
    TravelMode travelMode = TravelMode.driving,
    bool avoidTolls = false,
    bool avoidHighways = false,
    bool avoidFerries = false,
    List<LatLng>? waypoints,
  }) async {
    try {
      final params = <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': travelMode.name.toLowerCase(),
        'key': _googleMapsApiKey,
        'language': 'es',
        'region': EnvironmentConfig.defaultCountry.toLowerCase(),
      };

      if (avoidTolls) params['avoid'] = 'tolls';
      if (avoidHighways) params['avoid'] = 'highways';
      if (avoidFerries) params['avoid'] = 'ferries';

      if (waypoints != null && waypoints.isNotEmpty) {
        params['waypoints'] =
            waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|');
      }

      final url = Uri.parse(directionsApiUrl).replace(queryParameters: params);
      final response = await _httpClient.get(url.toString());
      final data = response.jsonBody;

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final leg = route['legs'][0];

        await _firebaseService.analytics?.logEvent(
          name: 'directions_success',
          parameters: {
            'distance_meters': leg['distance']['value'],
            'duration_seconds': leg['duration']['value'],
            'travel_mode': travelMode.name,
          },
        );

        return DirectionsResult.success(
          polylinePoints: _decodePolyline(route['overview_polyline']['points']),
          distance: leg['distance']['text'],
          distanceValue: leg['distance']['value'],
          duration: leg['duration']['text'],
          durationValue: leg['duration']['value'],
          startAddress: leg['start_address'],
          endAddress: leg['end_address'],
          steps: _parseSteps(leg['steps']),
        );
      } else {
        AppLogger.debug(
            '🗺️ GoogleMapsService: Directions error - ${data['status']}');
        return DirectionsResult.error('No se pudo obtener la ruta');
      }
    } catch (e) {
      AppLogger.debug('🗺️ GoogleMapsService: Error getting directions - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return DirectionsResult.error('Error obteniendo direcciones: $e');
    }
  }

  /// Buscar lugares cercanos ✅ IMPLEMENTACIÓN REAL
  Future<PlacesSearchResult> searchNearbyPlaces({
    required LatLng location,
    required double radius,
    String? type,
    String? keyword,
  }) async {
    try {
      final params = <String, String>{
        'location': '${location.latitude},${location.longitude}',
        'radius': radius.round().toString(),
        'key': _googleMapsApiKey,
        'language': 'es',
      };

      if (type != null) params['type'] = type;
      if (keyword != null) params['keyword'] = keyword;

      final url = Uri.parse('$placesApiUrl/nearbysearch/json')
          .replace(queryParameters: params);

      final response = await _httpClient.get(url.toString());
      final data = response.jsonBody;

      if (data['status'] == 'OK') {
        final places = (data['results'] as List).map((place) {
          return PlaceInfo(
            placeId: place['place_id'],
            name: place['name'],
            vicinity: place['vicinity'],
            latitude: place['geometry']['location']['lat'].toDouble(),
            longitude: place['geometry']['location']['lng'].toDouble(),
            rating: place['rating']?.toDouble(),
            priceLevel: place['price_level'],
            types: List<String>.from(place['types'] ?? []),
            isOpen: place['opening_hours']?['open_now'],
            photoReference: place['photos']?[0]?['photo_reference'],
          );
        }).toList();

        await _firebaseService.analytics?.logEvent(
          name: 'places_search_success',
          parameters: {
            'results_count': places.length,
            'search_type': type ?? 'general',
          },
        );

        return PlacesSearchResult.success(places);
      } else {
        AppLogger.debug(
            '🗺️ GoogleMapsService: Places search error - ${data['status']}');
        return PlacesSearchResult.error('No se pudieron encontrar lugares');
      }
    } catch (e) {
      AppLogger.debug('🗺️ GoogleMapsService: Error searching places - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return PlacesSearchResult.error('Error buscando lugares: $e');
    }
  }

  /// Autocomplete de direcciones ✅ IMPLEMENTACIÓN REAL
  Future<AutocompleteResult> getPlaceAutocomplete(String input) async {
    try {
      final url = Uri.parse('$placesApiUrl/autocomplete/json').replace(
        queryParameters: {
          'input': input,
          'key': _googleMapsApiKey,
          'language': 'es',
          'components': 'country:${EnvironmentConfig.defaultCountry.toLowerCase()}', // Solo ${EnvironmentConfig.defaultCountry}
          'types': 'address',
        },
      );

      final response = await _httpClient.get(url.toString());
      final data = response.jsonBody;

      if (data['status'] == 'OK') {
        final predictions = (data['predictions'] as List).map((prediction) {
          return PlacePrediction(
            placeId: prediction['place_id'],
            description: prediction['description'],
            mainText: prediction['structured_formatting']['main_text'],
            secondaryText: prediction['structured_formatting']
                ['secondary_text'],
            types: List<String>.from(prediction['types']),
          );
        }).toList();

        await _firebaseService.analytics?.logEvent(
          name: 'autocomplete_success',
          parameters: {
            'input': input,
            'results_count': predictions.length,
          },
        );

        return AutocompleteResult.success(predictions);
      } else {
        AppLogger.debug(
            '🗺️ GoogleMapsService: Autocomplete error - ${data['status']}');
        return AutocompleteResult.error('No se pudieron obtener sugerencias');
      }
    } catch (e) {
      AppLogger.debug('🗺️ GoogleMapsService: Error getting autocomplete - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return AutocompleteResult.error('Error obteniendo sugerencias: $e');
    }
  }

  /// Calcular matriz de distancias ✅ IMPLEMENTACIÓN REAL
  Future<DistanceMatrixResult> getDistanceMatrix({
    required List<LatLng> origins,
    required List<LatLng> destinations,
    TravelMode travelMode = TravelMode.driving,
  }) async {
    try {
      final originsStr = origins
          .map((origin) => '${origin.latitude},${origin.longitude}')
          .join('|');

      final destinationsStr = destinations
          .map((dest) => '${dest.latitude},${dest.longitude}')
          .join('|');

      final url = Uri.parse(distanceMatrixUrl).replace(queryParameters: {
        'origins': originsStr,
        'destinations': destinationsStr,
        'mode': travelMode.name.toLowerCase(),
        'key': _googleMapsApiKey,
        'language': 'es',
        'units': 'metric',
      });

      final response = await _httpClient.get(url.toString());
      final data = response.jsonBody;

      if (data['status'] == 'OK') {
        final elements = <DistanceElement>[];

        for (int i = 0; i < data['rows'].length; i++) {
          final row = data['rows'][i];
          for (int j = 0; j < row['elements'].length; j++) {
            final element = row['elements'][j];
            if (element['status'] == 'OK') {
              elements.add(DistanceElement(
                originIndex: i,
                destinationIndex: j,
                distance: element['distance']['text'],
                distanceValue: element['distance']['value'],
                duration: element['duration']['text'],
                durationValue: element['duration']['value'],
              ));
            }
          }
        }

        await _firebaseService.analytics?.logEvent(
          name: 'distance_matrix_success',
          parameters: {
            'origins_count': origins.length,
            'destinations_count': destinations.length,
          },
        );

        return DistanceMatrixResult.success(elements);
      } else {
        AppLogger.debug(
            '🗺️ GoogleMapsService: Distance matrix error - ${data['status']}');
        return DistanceMatrixResult.error(
            'No se pudo calcular la matriz de distancias');
      }
    } catch (e) {
      AppLogger.debug(
          '🗺️ GoogleMapsService: Error getting distance matrix - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return DistanceMatrixResult.error('Error calculando distancias: $e');
    }
  }

  /// Optimizar ruta con múltiples waypoints
  Future<DirectionsResult> getOptimizedRoute({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
    TravelMode travelMode = TravelMode.driving,
    bool avoidTolls = false,
    bool avoidHighways = false,
  }) async {
    try {
      final params = <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': travelMode.name.toLowerCase(),
        'key': _googleMapsApiKey,
        'language': 'es',
        'region': EnvironmentConfig.defaultCountry.toLowerCase(),
        'traffic_model': 'best_guess',
        'departure_time': 'now',
      };

      if (waypoints.isNotEmpty) {
        params['waypoints'] = 'optimize:true|' +
            waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|');
      }

      if (avoidTolls) params['avoid'] = 'tolls';
      if (avoidHighways) params['avoid'] = 'highways';

      final url = Uri.parse(directionsApiUrl).replace(queryParameters: params);
      final response = await _httpClient.get(url.toString());
      final data = response.jsonBody;

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final legs = route['legs'] as List;

        // Sum distance and duration across all legs when waypoints are present
        int totalDistance = 0;
        int totalDuration = 0;
        List<DirectionStep> allSteps = [];

        for (var leg in legs) {
          totalDistance += leg['distance']['value'] as int;
          totalDuration += leg['duration']['value'] as int;
          allSteps.addAll(_parseSteps(leg['steps']));
        }

        // Get distance and duration text from summed values
        final distanceText = totalDistance >= 1000
            ? '${(totalDistance / 1000).toStringAsFixed(1)} km'
            : '$totalDistance m';
        final durationText = totalDuration >= 3600
            ? '${(totalDuration / 3600).floor()} h ${((totalDuration % 3600) / 60).round()} min'
            : '${(totalDuration / 60).round()} min';

        await _firebaseService.analytics?.logEvent(
          name: 'optimized_route_success',
          parameters: {
            'waypoints_count': waypoints.length,
            'optimized_order': route['waypoint_order']?.join(',') ?? '',
            'total_distance': totalDistance,
            'total_duration': totalDuration,
          },
        );

        return DirectionsResult.success(
          polylinePoints: _decodePolyline(route['overview_polyline']['points']),
          distance: distanceText,
          distanceValue: totalDistance,
          duration: durationText,
          durationValue: totalDuration,
          startAddress: legs.first['start_address'],
          endAddress: legs.last['end_address'],
          steps: allSteps,
        );
      } else {
        return DirectionsResult.error('No se pudo optimizar la ruta');
      }
    } catch (e) {
      AppLogger.debug('🗺️ GoogleMapsService: Error optimizing route - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return DirectionsResult.error('Error optimizando ruta: $e');
    }
  }

  /// Obtener rutas alternativas con información de tráfico
  Future<List<DirectionsResult>> getAlternativeRoutes({
    required LatLng origin,
    required LatLng destination,
    TravelMode travelMode = TravelMode.driving,
    int maxAlternatives = 3,
  }) async {
    try {
      final params = <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': travelMode.name.toLowerCase(),
        'key': _googleMapsApiKey,
        'language': 'es',
        'region': EnvironmentConfig.defaultCountry.toLowerCase(),
        'alternatives': 'true',
        'traffic_model': 'best_guess',
        'departure_time': 'now',
      };

      final url = Uri.parse(directionsApiUrl).replace(queryParameters: params);
      final response = await _httpClient.get(url.toString());
      final data = response.jsonBody;

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final routes = <DirectionsResult>[];
        final routesList = data['routes'] as List;

        for (int i = 0; i < math.min(routesList.length, maxAlternatives); i++) {
          final route = routesList[i];
          final leg = route['legs'][0];

          routes.add(DirectionsResult.success(
            polylinePoints: _decodePolyline(route['overview_polyline']['points']),
            distance: leg['distance']['text'],
            distanceValue: leg['distance']['value'],
            duration: leg['duration']['text'],
            durationValue: leg['duration']['value'],
            startAddress: leg['start_address'],
            endAddress: leg['end_address'],
            steps: _parseSteps(leg['steps']),
          ));
        }

        await _firebaseService.analytics?.logEvent(
          name: 'alternative_routes_success',
          parameters: {
            'routes_count': routes.length,
            'travel_mode': travelMode.name,
          },
        );

        return routes;
      } else {
        return [];
      }
    } catch (e) {
      AppLogger.debug('🗺️ GoogleMapsService: Error getting alternative routes - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return [];
    }
  }

  /// Obtener información de tráfico en tiempo real
  Future<TrafficInfo> getTrafficInfo({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final params = <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': _googleMapsApiKey,
        'departure_time': 'now',
        'traffic_model': 'best_guess',
      };

      final url = Uri.parse(directionsApiUrl).replace(queryParameters: params);
      final response = await _httpClient.get(url.toString());
      final data = response.jsonBody;

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final leg = route['legs'][0];

        final normalDuration = leg['duration']['value'];
        final trafficDuration = leg['duration_in_traffic']?['value'] ?? normalDuration;

        final trafficLevel = _calculateTrafficLevel(normalDuration, trafficDuration);

        return TrafficInfo(
          normalDuration: normalDuration,
          trafficDuration: trafficDuration,
          trafficLevel: trafficLevel,
          delayMinutes: ((trafficDuration - normalDuration) / 60).round(),
          lastUpdated: DateTime.now(),
        );
      } else {
        return TrafficInfo(
          normalDuration: 0,
          trafficDuration: 0,
          trafficLevel: TrafficLevel.unknown,
          delayMinutes: 0,
          lastUpdated: DateTime.now(),
        );
      }
    } catch (e) {
      AppLogger.debug('🗺️ GoogleMapsService: Error getting traffic info - $e');
      return TrafficInfo(
        normalDuration: 0,
        trafficDuration: 0,
        trafficLevel: TrafficLevel.unknown,
        delayMinutes: 0,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Calcular nivel de tráfico basado en duración
  TrafficLevel _calculateTrafficLevel(int normalDuration, int trafficDuration) {
    if (normalDuration <= 0) return TrafficLevel.unknown;
    final ratio = trafficDuration / normalDuration;

    if (ratio <= 1.1) return TrafficLevel.light;
    if (ratio <= 1.3) return TrafficLevel.moderate;
    if (ratio <= 1.6) return TrafficLevel.heavy;
    return TrafficLevel.severe;
  }

  /// Métodos auxiliares

  String _extractComponent(List components, String type) {
    for (var component in components) {
      if (component['types'].contains(type)) {
        return component['long_name'];
      }
    }
    return '';
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  List<DirectionStep> _parseSteps(List steps) {
    return steps.map((step) {
      return DirectionStep(
        instruction: step['html_instructions']
            .replaceAll(RegExp(r'<[^>]*>'), ''), // Remove HTML tags
        distance: step['distance']['text'],
        distanceValue: step['distance']['value'],
        duration: step['duration']['text'],
        durationValue: step['duration']['value'],
        startLocation: LatLng(
          step['start_location']['lat'].toDouble(),
          step['start_location']['lng'].toDouble(),
        ),
        endLocation: LatLng(
          step['end_location']['lat'].toDouble(),
          step['end_location']['lng'].toDouble(),
        ),
      );
    }).toList();
  }

  // Getters
  bool get isInitialized => _initialized;
  String get apiKey => _googleMapsApiKey;
}

/// Enums

enum TravelMode { driving, walking, bicycling, transit }

/// Clases de resultados

class LocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? timestamp;
  final String? error;

  LocationResult.success({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  })  : success = true,
        error = null;

  LocationResult.error(this.error)
      : success = false,
        latitude = null,
        longitude = null,
        accuracy = null,
        timestamp = null;
}

class GeocodingResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final String? formattedAddress;
  final String? placeId;
  final String? error;

  GeocodingResult.success({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.placeId,
  })  : success = true,
        error = null;

  GeocodingResult.error(this.error)
      : success = false,
        latitude = null,
        longitude = null,
        formattedAddress = null,
        placeId = null;
}

class ReverseGeocodingResult {
  final bool success;
  final String? formattedAddress;
  final String? streetNumber;
  final String? route;
  final String? locality;
  final String? administrativeArea;
  final String? country;
  final String? postalCode;
  final String? placeId;
  final String? error;

  ReverseGeocodingResult.success({
    required this.formattedAddress,
    this.streetNumber,
    this.route,
    this.locality,
    this.administrativeArea,
    this.country,
    this.postalCode,
    this.placeId,
  })  : success = true,
        error = null;

  ReverseGeocodingResult.error(this.error)
      : success = false,
        formattedAddress = null,
        streetNumber = null,
        route = null,
        locality = null,
        administrativeArea = null,
        country = null,
        postalCode = null,
        placeId = null;
}

class DirectionsResult {
  final bool success;
  final List<LatLng>? polylinePoints;
  final String? distance;
  final int? distanceValue;
  final String? duration;
  final int? durationValue;
  final String? startAddress;
  final String? endAddress;
  final List<DirectionStep>? steps;
  final String? error;

  DirectionsResult.success({
    required this.polylinePoints,
    required this.distance,
    required this.distanceValue,
    required this.duration,
    required this.durationValue,
    required this.startAddress,
    required this.endAddress,
    required this.steps,
  })  : success = true,
        error = null;

  DirectionsResult.error(this.error)
      : success = false,
        polylinePoints = null,
        distance = null,
        distanceValue = null,
        duration = null,
        durationValue = null,
        startAddress = null,
        endAddress = null,
        steps = null;
}

class PlacesSearchResult {
  final bool success;
  final List<PlaceInfo>? places;
  final String? error;

  PlacesSearchResult.success(this.places)
      : success = true,
        error = null;

  PlacesSearchResult.error(this.error)
      : success = false,
        places = null;
}

class AutocompleteResult {
  final bool success;
  final List<PlacePrediction>? predictions;
  final String? error;

  AutocompleteResult.success(this.predictions)
      : success = true,
        error = null;

  AutocompleteResult.error(this.error)
      : success = false,
        predictions = null;
}

class DistanceMatrixResult {
  final bool success;
  final List<DistanceElement>? elements;
  final String? error;

  DistanceMatrixResult.success(this.elements)
      : success = true,
        error = null;

  DistanceMatrixResult.error(this.error)
      : success = false,
        elements = null;
}

/// Clases de datos

class DirectionStep {
  final String instruction;
  final String distance; // text representation
  final int distanceValue; // value in meters
  final String duration; // text representation
  final int durationValue; // value in seconds
  final LatLng startLocation;
  final LatLng endLocation;

  DirectionStep({
    required this.instruction,
    required this.distance,
    required this.distanceValue,
    required this.duration,
    required this.durationValue,
    required this.startLocation,
    required this.endLocation,
  });
}

class PlaceInfo {
  final String placeId;
  final String name;
  final String? vicinity;
  final double latitude;
  final double longitude;
  final double? rating;
  final int? priceLevel;
  final List<String> types;
  final bool? isOpen;
  final String? photoReference;

  PlaceInfo({
    required this.placeId,
    required this.name,
    this.vicinity,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.priceLevel,
    required this.types,
    this.isOpen,
    this.photoReference,
  });
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String? secondaryText;
  final List<String> types;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText,
    required this.types,
  });
}

class DistanceElement {
  final int originIndex;
  final int destinationIndex;
  final String distance;
  final int distanceValue;
  final String duration;
  final int durationValue;

  DistanceElement({
    required this.originIndex,
    required this.destinationIndex,
    required this.distance,
    required this.distanceValue,
    required this.duration,
    required this.durationValue,
  });
}

class TrafficInfo {
  final int normalDuration;
  final int trafficDuration;
  final TrafficLevel trafficLevel;
  final int delayMinutes;
  final DateTime lastUpdated;

  TrafficInfo({
    required this.normalDuration,
    required this.trafficDuration,
    required this.trafficLevel,
    required this.delayMinutes,
    required this.lastUpdated,
  });
}

enum TrafficLevel {
  light,
  moderate,
  heavy,
  severe,
  unknown,
}

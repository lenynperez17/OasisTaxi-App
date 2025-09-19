import 'dart:convert';
import '../config/app_config.dart';
import '../../utils/app_logger.dart';
import '../../services/http_client.dart';

class PlacesSuggestion {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  PlacesSuggestion({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  factory PlacesSuggestion.fromJson(Map<String, dynamic> json) {
    return PlacesSuggestion(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: json['structured_formatting']?['main_text'],
      secondaryText: json['structured_formatting']?['secondary_text'],
    );
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final location = geometry['location'];

    return PlaceDetails(
      placeId: json['place_id'] as String,
      name: json['name'] ?? json['formatted_address'] as String,
      formattedAddress: json['formatted_address'] as String,
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
    );
  }
}

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static final HttpClient _httpClient = HttpClient();

  // Buscar sugerencias de lugares (SOLO MÓVIL)
  static Future<List<PlacesSuggestion>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    try {
      final url = '$_baseUrl/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=${AppConfig.googleMapsApiKey}'
          '&language=es'
          '&components=country:pe';

      AppLogger.info('Searching places: $query');

      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions
              .map((prediction) => PlacesSuggestion.fromJson(prediction))
              .toList();
        } else {
          AppLogger.warning('Places API error: ${data['status']}');
          return [];
        }
      } else {
        AppLogger.error('HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error searching places', e, stackTrace);
      return [];
    }
  }

  // Obtener detalles de un lugar específico (SOLO MÓVIL)
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = '$_baseUrl/place/details/json'
          '?place_id=$placeId'
          '&key=${AppConfig.googleMapsApiKey}'
          '&language=es'
          '&fields=place_id,name,formatted_address,geometry';

      AppLogger.info('Getting place details: $placeId');

      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        } else {
          AppLogger.warning('Place details API error: ${data['status']}');
          return null;
        }
      } else {
        AppLogger.error('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error getting place details', e, stackTrace);
      return null;
    }
  }

  // Geocodificación inversa (coordenadas a dirección)
  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = '$_baseUrl/geocode/json'
          '?latlng=$latitude,$longitude'
          '&key=${AppConfig.googleMapsApiKey}'
          '&language=es';

      AppLogger.info('Reverse geocoding: $latitude, $longitude');

      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'] as String;
        } else {
          AppLogger.warning('Geocoding API error: ${data['status']}');
          return null;
        }
      } else {
        AppLogger.error('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error in reverse geocoding', e, stackTrace);
      return null;
    }
  }

  // Geocodificación directa (dirección a coordenadas)
  static Future<PlaceDetails?> getCoordinatesFromAddress(String address) async {
    try {
      final url = '$_baseUrl/geocode/json'
          '?address=${Uri.encodeComponent(address)}'
          '&key=${AppConfig.googleMapsApiKey}'
          '&language=es'
          '&components=country:pe';

      AppLogger.info('Geocoding address: $address');

      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final data = response.jsonBody;

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          return PlaceDetails.fromJson(result);
        } else {
          AppLogger.warning('Geocoding API error: ${data['status']}');
          return null;
        }
      } else {
        AppLogger.error('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error geocoding address', e, stackTrace);
      return null;
    }
  }
}

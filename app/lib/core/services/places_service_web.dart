// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:async';
import '../utils/logger.dart';

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

  factory PlacesSuggestion.fromJsObject(js.JsObject prediction) {
    final structuredFormatting = prediction['structured_formatting'];
    
    return PlacesSuggestion(
      placeId: prediction['place_id'],
      description: prediction['description'],
      mainText: structuredFormatting != null ? structuredFormatting['main_text'] : null,
      secondaryText: structuredFormatting != null ? structuredFormatting['secondary_text'] : null,
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

  factory PlaceDetails.fromJsObject(js.JsObject place) {
    final geometry = place['geometry'];
    final location = geometry['location'];
    
    return PlaceDetails(
      placeId: place['place_id'],
      name: place['name'] ?? place['formatted_address'],
      formattedAddress: place['formatted_address'],
      latitude: js_util.callMethod(location, 'lat', []),
      longitude: js_util.callMethod(location, 'lng', []),
    );
  }
}

class PlacesServiceWeb {
  static js.JsObject? _autocompleteService;
  static js.JsObject? _placesService;
  static js.JsObject? _map;

  static void _initializeServices() {
    if (_autocompleteService == null) {
      try {
        // Crear un mapa dummy para el PlacesService
        final mapOptions = js.JsObject.jsify({
          'zoom': 1,
          'center': {'lat': -12.0464, 'lng': -77.0428}
        });
        
        _map = js.JsObject(
          js.context['google']['maps']['Map'], 
          [js.context['document'].callMethod('createElement', ['div']), mapOptions]
        );

        _autocompleteService = js.JsObject(
          js.context['google']['maps']['places']['AutocompleteService']
        );
        
        _placesService = js.JsObject(
          js.context['google']['maps']['places']['PlacesService'],
          [_map]
        );
        
        Logger.info('Google Places services initialized successfully');
      } catch (e) {
        Logger.error('Error initializing Google Places services', e);
      }
    }
  }

  static Future<List<PlacesSuggestion>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    _initializeServices();
    
    if (_autocompleteService == null) {
      Logger.error('AutocompleteService not available');
      return [];
    }

    final completer = Completer<List<PlacesSuggestion>>();

    try {
      final request = js.JsObject.jsify({
        'input': query,
        'language': 'es',
        'componentRestrictions': {'country': 'pe'}
      });

      final callback = js.allowInterop((js.JsArray? predictions, String status) {
        try {
          if (status == 'OK' && predictions != null) {
            final suggestions = <PlacesSuggestion>[];
            
            for (int i = 0; i < predictions.length; i++) {
              final prediction = predictions[i] as js.JsObject;
              suggestions.add(PlacesSuggestion.fromJsObject(prediction));
            }
            
            Logger.info('Found ${suggestions.length} place suggestions');
            completer.complete(suggestions);
          } else {
            Logger.warning('Places search failed with status: $status');
            completer.complete([]);
          }
        } catch (e) {
          Logger.error('Error processing places search results', e);
          completer.completeError(e);
        }
      });

      js_util.callMethod(_autocompleteService!, 'getPlacePredictions', [request, callback]);
      
    } catch (e) {
      Logger.error('Error calling Places Autocomplete service', e);
      completer.completeError(e);
    }

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        Logger.warning('Places search timed out');
        return <PlacesSuggestion>[];
      },
    );
  }

  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    _initializeServices();
    
    if (_placesService == null) {
      Logger.error('PlacesService not available');
      return null;
    }

    final completer = Completer<PlaceDetails?>();

    try {
      final request = js.JsObject.jsify({
        'placeId': placeId,
        'fields': ['place_id', 'name', 'formatted_address', 'geometry'],
        'language': 'es'
      });

      final callback = js.allowInterop((js.JsObject? place, String status) {
        try {
          if (status == 'OK' && place != null) {
            final details = PlaceDetails.fromJsObject(place);
            Logger.info('Got place details for: ${details.name}');
            completer.complete(details);
          } else {
            Logger.warning('Place details failed with status: $status');
            completer.complete(null);
          }
        } catch (e) {
          Logger.error('Error processing place details', e);
          completer.completeError(e);
        }
      });

      js_util.callMethod(_placesService!, 'getDetails', [request, callback]);
      
    } catch (e) {
      Logger.error('Error calling Places Details service', e);
      completer.completeError(e);
    }

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        Logger.warning('Place details request timed out');
        return null;
      },
    );
  }

  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final geocoder = js.JsObject(js.context['google']['maps']['Geocoder']);
      final completer = Completer<String?>();

      final request = js.JsObject.jsify({
        'location': {'lat': latitude, 'lng': longitude},
        'language': 'es'
      });

      final callback = js.allowInterop((js.JsArray? results, String status) {
        try {
          if (status == 'OK' && results != null && results.isNotEmpty) {
            final result = results[0] as js.JsObject;
            final address = result['formatted_address'] as String;
            Logger.info('Reverse geocoding successful');
            completer.complete(address);
          } else {
            Logger.warning('Reverse geocoding failed with status: $status');
            completer.complete(null);
          }
        } catch (e) {
          Logger.error('Error processing reverse geocoding', e);
          completer.completeError(e);
        }
      });

      js_util.callMethod(geocoder, 'geocode', [request, callback]);

      return completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Logger.warning('Reverse geocoding timed out');
          return null;
        },
      );
    } catch (e) {
      Logger.error('Error in reverse geocoding', e);
      return null;
    }
  }

  static Future<PlaceDetails?> getCoordinatesFromAddress(String address) async {
    try {
      final geocoder = js.JsObject(js.context['google']['maps']['Geocoder']);
      final completer = Completer<PlaceDetails?>();

      final request = js.JsObject.jsify({
        'address': address,
        'language': 'es',
        'componentRestrictions': {'country': 'PE'}
      });

      final callback = js.allowInterop((js.JsArray? results, String status) {
        try {
          if (status == 'OK' && results != null && results.isNotEmpty) {
            final result = results[0] as js.JsObject;
            final geometry = result['geometry'];
            final location = geometry['location'];
            
            final details = PlaceDetails(
              placeId: result['place_id'] ?? '',
              name: result['formatted_address'],
              formattedAddress: result['formatted_address'],
              latitude: js_util.callMethod(location, 'lat', []),
              longitude: js_util.callMethod(location, 'lng', []),
            );
            
            Logger.info('Geocoding successful');
            completer.complete(details);
          } else {
            Logger.warning('Geocoding failed with status: $status');
            completer.complete(null);
          }
        } catch (e) {
          Logger.error('Error processing geocoding', e);
          completer.completeError(e);
        }
      });

      js_util.callMethod(geocoder, 'geocode', [request, callback]);

      return completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Logger.warning('Geocoding timed out');
          return null;
        },
      );
    } catch (e) {
      Logger.error('Error in geocoding', e);
      return null;
    }
  }
}
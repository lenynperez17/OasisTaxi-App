import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Servicio de Google Places para plataformas móviles
/// Implementación completa usando HTTP requests
class PlacesSuggestion {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;
  final String? types;

  PlacesSuggestion({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
    this.types,
  });

  factory PlacesSuggestion.fromJson(Map<String, dynamic> json) {
    final structuredFormatting =
        json['structured_formatting'] as Map<String, dynamic>?;
    return PlacesSuggestion(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: structuredFormatting?['main_text'] as String?,
      secondaryText: structuredFormatting?['secondary_text'] as String?,
      types: (json['types'] as List<dynamic>?)?.join(', '),
    );
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? phoneNumber;
  final String? website;
  final double? rating;
  final String? openingHours;
  final List<String>? photos;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.phoneNumber,
    this.website,
    this.rating,
    this.openingHours,
    this.photos,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return PlaceDetails(
      placeId: json['place_id'] as String,
      name: json['name'] as String? ?? '',
      formattedAddress: json['formatted_address'] as String? ?? '',
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
      phoneNumber: json['formatted_phone_number'] as String?,
      website: json['website'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      openingHours: _extractOpeningHours(json['opening_hours']),
      photos: _extractPhotos(json['photos']),
    );
  }

  static String? _extractOpeningHours(dynamic openingHours) {
    if (openingHours == null) return null;
    final weekdayText = openingHours['weekday_text'] as List<dynamic>?;
    return weekdayText?.join('\n');
  }

  static List<String>? _extractPhotos(dynamic photos) {
    if (photos == null) return null;
    final photoList = photos as List<dynamic>;
    return photoList.map((photo) {
      final photoReference = photo['photo_reference'] as String;
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      return 'https://maps.googleapis.com/maps/api/place/photo'
          '?maxwidth=400'
          '&photo_reference=$photoReference'
          '&key=$apiKey';
    }).toList();
  }
}

/// Servicio móvil de Google Places con implementación HTTP completa

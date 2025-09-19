class LocationModel {
  final double latitude;
  final double longitude;
  final String address;
  final String? name;
  final String? placeId;

  const LocationModel({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.name,
    this.placeId,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      address: json['address'] ?? '',
      name: json['name'],
      placeId: json['placeId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'name': name,
      'placeId': placeId,
    };
  }
}

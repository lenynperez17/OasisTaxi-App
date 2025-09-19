import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Modelo de Usuario
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String userType; // 'passenger', 'driver', 'admin'
  final String profilePhotoUrl;
  final bool isActive;
  final bool isVerified;
  final bool emailVerified;
  final bool phoneVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double rating;
  final int totalTrips;
  final double balance;
  final LatLng? location;
  final String? fcmToken;
  final bool? isAvailable; // Solo para conductores
  final Map<String, dynamic>? vehicleInfo; // Solo para conductores

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.userType,
    this.profilePhotoUrl = '',
    this.isActive = true,
    this.isVerified = false,
    this.emailVerified = false,
    this.phoneVerified = false,
    required this.createdAt,
    required this.updatedAt,
    this.rating = 5.0,
    this.totalTrips = 0,
    this.balance = 0.0,
    this.location,
    this.fcmToken,
    this.isAvailable,
    this.vehicleInfo,
  });

  /// Crear desde JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      userType: json['userType'] ?? 'passenger',
      profilePhotoUrl: json['profilePhotoUrl'] ?? '',
      isActive: json['isActive'] ?? true,
      isVerified: json['isVerified'] ?? false,
      emailVerified: json['emailVerified'] ?? false,
      phoneVerified: json['phoneVerified'] ?? false,
      createdAt: json['createdAt'] is DateTime
          ? json['createdAt']
          : DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] is DateTime
          ? json['updatedAt']
          : DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      rating: (json['rating'] ?? 5.0).toDouble(),
      totalTrips: json['totalTrips'] ?? 0,
      balance: (json['balance'] ?? 0.0).toDouble(),
      location: json['location'] != null
          ? LatLng(
              (json['location']['lat'] ?? 0.0).toDouble(),
              (json['location']['lng'] ?? 0.0).toDouble(),
            )
          : null,
      fcmToken: json['fcmToken'],
      isAvailable: json['isAvailable'],
      vehicleInfo: json['vehicleInfo'],
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'userType': userType,
      'profilePhotoUrl': profilePhotoUrl,
      'isActive': isActive,
      'isVerified': isVerified,
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'rating': rating,
      'totalTrips': totalTrips,
      'balance': balance,
      'location': location != null
          ? {
              'lat': location!.latitude,
              'lng': location!.longitude,
            }
          : null,
      'fcmToken': fcmToken,
      'isAvailable': isAvailable,
      'vehicleInfo': vehicleInfo,
    };
  }

  /// Copiar con cambios
  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? userType,
    String? profilePhotoUrl,
    bool? isActive,
    bool? isVerified,
    bool? emailVerified,
    bool? phoneVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    int? totalTrips,
    double? balance,
    LatLng? location,
    String? fcmToken,
    bool? isAvailable,
    Map<String, dynamic>? vehicleInfo,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      balance: balance ?? this.balance,
      location: location ?? this.location,
      fcmToken: fcmToken ?? this.fcmToken,
      isAvailable: isAvailable ?? this.isAvailable,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
    );
  }

  /// Verificar si es conductor
  bool get isDriver => userType == 'driver';

  /// Verificar si es pasajero
  bool get isPassenger => userType == 'passenger';

  /// Verificar si es admin
  bool get isAdmin => userType == 'admin';

  /// Obtener nombre para mostrar
  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (email.isNotEmpty) return email;
    return 'Usuario';
  }

  @override
  String toString() {
    return 'UserModel(id: $id, fullName: $fullName, email: $email, userType: $userType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Constructor para crear desde Firestore Document
  factory UserModel.fromFirestore(
      Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      userType: data['userType'] ?? 'passenger',
      profilePhotoUrl: data['profilePhotoUrl'] ?? '',
      isActive: data['isActive'] ?? true,
      isVerified: data['isVerified'] ?? false,
      emailVerified: data['emailVerified'] ?? false,
      phoneVerified: data['phoneVerified'] ?? false,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      rating: (data['rating'] ?? 5.0).toDouble(),
      totalTrips: data['totalTrips'] ?? 0,
      balance: (data['balance'] ?? 0.0).toDouble(),
      location: data['location'] != null
          ? LatLng(
              (data['location']['lat'] ?? 0.0).toDouble(),
              (data['location']['lng'] ?? 0.0).toDouble(),
            )
          : null,
      fcmToken: data['fcmToken'],
      isAvailable: data['isAvailable'],
      vehicleInfo: data['vehicleInfo'],
    );
  }
}

import 'package:flutter/material.dart';

enum ServiceCategory { transport, delivery, special }

enum ServiceType {
  // Transporte de personas
  taxiEconomico,
  taxiComfort,
  taxiPremium,
  motoTaxi,
  van,

  // Servicios de entrega
  mensajeria,
  compras,
  farmacia,
  comida,
  paquetes,

  // Servicios especiales
  mudanzas,
  grua,
  transporteMedico,
  mascotas,
}

class ServiceInfo {
  final ServiceType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final double basePrice;
  final double pricePerKm;
  final double pricePerMin;
  final ServiceCategory category;
  final int maxPassengers;
  final bool hasLuggage;

  const ServiceInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.basePrice,
    required this.pricePerKm,
    required this.pricePerMin,
    required this.category,
    this.maxPassengers = 1,
    this.hasLuggage = false,
  });
}

class ServiceTypeConfig {
  static final Map<ServiceType, ServiceInfo> services = {
    // TRANSPORTE DE PERSONAS
    ServiceType.taxiEconomico: ServiceInfo(
      type: ServiceType.taxiEconomico,
      name: 'Taxi',
      description: 'Viaje económico y rápido',
      icon: Icons.directions_car,
      color: Color(0xFF2196F3),
      basePrice: 5.0,
      pricePerKm: 1.5,
      pricePerMin: 0.3,
      category: ServiceCategory.transport,
      maxPassengers: 4,
      hasLuggage: true,
    ),
    ServiceType.taxiComfort: ServiceInfo(
      type: ServiceType.taxiComfort,
      name: 'Comfort',
      description: 'Autos más amplios y cómodos',
      icon: Icons.directions_car_filled,
      color: Color(0xFF4CAF50),
      basePrice: 7.0,
      pricePerKm: 2.0,
      pricePerMin: 0.4,
      category: ServiceCategory.transport,
      maxPassengers: 4,
      hasLuggage: true,
    ),
    ServiceType.taxiPremium: ServiceInfo(
      type: ServiceType.taxiPremium,
      name: 'Premium',
      description: 'Vehículos de lujo VIP',
      icon: Icons.local_taxi,
      color: Color(0xFFFFD700),
      basePrice: 12.0,
      pricePerKm: 3.0,
      pricePerMin: 0.6,
      category: ServiceCategory.transport,
      maxPassengers: 4,
      hasLuggage: true,
    ),
    ServiceType.motoTaxi: ServiceInfo(
      type: ServiceType.motoTaxi,
      name: 'Moto',
      description: 'Rápido y económico',
      icon: Icons.two_wheeler,
      color: Color(0xFFFF9800),
      basePrice: 3.0,
      pricePerKm: 1.0,
      pricePerMin: 0.2,
      category: ServiceCategory.transport,
      maxPassengers: 1,
      hasLuggage: false,
    ),
    ServiceType.van: ServiceInfo(
      type: ServiceType.van,
      name: 'Van',
      description: 'Para grupos de 6-8 personas',
      icon: Icons.airport_shuttle,
      color: Color(0xFF9C27B0),
      basePrice: 15.0,
      pricePerKm: 3.5,
      pricePerMin: 0.7,
      category: ServiceCategory.transport,
      maxPassengers: 8,
      hasLuggage: true,
    ),

    // SERVICIOS DE ENTREGA
    ServiceType.mensajeria: ServiceInfo(
      type: ServiceType.mensajeria,
      name: 'Mensajería',
      description: 'Envío de documentos y paquetes pequeños',
      icon: Icons.mail_outline,
      color: Color(0xFF00BCD4),
      basePrice: 5.0,
      pricePerKm: 1.2,
      pricePerMin: 0.25,
      category: ServiceCategory.delivery,
    ),
    ServiceType.compras: ServiceInfo(
      type: ServiceType.compras,
      name: 'Compras',
      description: 'Hacemos tus compras del supermercado',
      icon: Icons.shopping_cart,
      color: Color(0xFF4CAF50),
      basePrice: 8.0,
      pricePerKm: 1.5,
      pricePerMin: 0.3,
      category: ServiceCategory.delivery,
    ),
    ServiceType.farmacia: ServiceInfo(
      type: ServiceType.farmacia,
      name: 'Farmacia',
      description: 'Medicamentos a tu puerta',
      icon: Icons.medical_services,
      color: Color(0xFFE91E63),
      basePrice: 6.0,
      pricePerKm: 1.3,
      pricePerMin: 0.25,
      category: ServiceCategory.delivery,
    ),
    ServiceType.comida: ServiceInfo(
      type: ServiceType.comida,
      name: 'Comida',
      description: 'Delivery de restaurantes',
      icon: Icons.restaurant,
      color: Color(0xFFFF5722),
      basePrice: 5.0,
      pricePerKm: 1.2,
      pricePerMin: 0.25,
      category: ServiceCategory.delivery,
    ),
    ServiceType.paquetes: ServiceInfo(
      type: ServiceType.paquetes,
      name: 'Paquetes',
      description: 'Envío de paquetes grandes',
      icon: Icons.inventory_2,
      color: Color(0xFF795548),
      basePrice: 10.0,
      pricePerKm: 2.0,
      pricePerMin: 0.4,
      category: ServiceCategory.delivery,
    ),

    // SERVICIOS ESPECIALES
    ServiceType.mudanzas: ServiceInfo(
      type: ServiceType.mudanzas,
      name: 'Mudanzas',
      description: 'Transporte de muebles y mudanzas pequeñas',
      icon: Icons.home_work,
      color: Color(0xFF607D8B),
      basePrice: 50.0,
      pricePerKm: 5.0,
      pricePerMin: 1.0,
      category: ServiceCategory.special,
    ),
    ServiceType.grua: ServiceInfo(
      type: ServiceType.grua,
      name: 'Grúa',
      description: 'Auxilio mecánico y remolque',
      icon: Icons.car_repair,
      color: Color(0xFFF44336),
      basePrice: 80.0,
      pricePerKm: 6.0,
      pricePerMin: 1.5,
      category: ServiceCategory.special,
    ),
    ServiceType.transporteMedico: ServiceInfo(
      type: ServiceType.transporteMedico,
      name: 'Médico',
      description: 'Transporte médico no urgente',
      icon: Icons.local_hospital,
      color: Color(0xFF3F51B5),
      basePrice: 40.0,
      pricePerKm: 4.0,
      pricePerMin: 0.8,
      category: ServiceCategory.special,
    ),
    ServiceType.mascotas: ServiceInfo(
      type: ServiceType.mascotas,
      name: 'Mascotas',
      description: 'Transporte seguro para tu mascota',
      icon: Icons.pets,
      color: Color(0xFF8BC34A),
      basePrice: 15.0,
      pricePerKm: 2.5,
      pricePerMin: 0.5,
      category: ServiceCategory.special,
      maxPassengers: 2,
    ),
  };

  static ServiceInfo getServiceInfo(ServiceType type) {
    return services[type] ?? services[ServiceType.taxiEconomico]!;
  }

  static List<ServiceInfo> getServicesByCategory(ServiceCategory category) {
    return services.values
        .where((service) => service.category == category)
        .toList();
  }

  static double calculatePrice(
    ServiceType type,
    double distanceKm,
    int estimatedMinutes,
  ) {
    final service = getServiceInfo(type);
    return service.basePrice +
        (service.pricePerKm * distanceKm) +
        (service.pricePerMin * estimatedMinutes);
  }

  static String formatPrice(double price) {
    return 'S/ ${price.toStringAsFixed(2)}';
  }

  static String getPriceRange(ServiceType type, double distanceKm) {
    // final service = getServiceInfo(type); // Variable no usada
    final minPrice = calculatePrice(type, distanceKm, (distanceKm * 2).round());
    final maxPrice = calculatePrice(type, distanceKm, (distanceKm * 4).round());
    return '${formatPrice(minPrice)} - ${formatPrice(maxPrice)}';
  }
}

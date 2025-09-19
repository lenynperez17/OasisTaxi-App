import '../../utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/notification_service.dart';
import '../../shared/providers/user_provider.dart';
import 'dart:async';

class NotificationHandlerWidget extends StatefulWidget {
  final Widget child;

  const NotificationHandlerWidget({
    super.key,
    required this.child,
  });

  @override
  State<NotificationHandlerWidget> createState() =>
      _NotificationHandlerWidgetState();
}

class _NotificationHandlerWidgetState extends State<NotificationHandlerWidget> {
  final NotificationService _notificationService = NotificationService();
  StreamSubscription? _notificationStreamSubscription;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();

    // Inicializar servicio de notificaciones
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  /// Inicializar servicio de notificaciones con listeners reales
  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();

    // Configurar listener para notificaciones seleccionadas
    _notificationStreamSubscription =
        _notificationService.onNotificationSelected?.listen((payload) {
      if (payload.isNotEmpty) {
        _handleNotificationTap(payload);
      }
    });
  }

  /// Manejar tap en notificación con navegación real
  void _handleNotificationTap(String payload) {
    // Verificar si el widget sigue montado antes de usar context
    if (!mounted) return;

    // Manejar la navegación según el payload
    if (payload.startsWith('ride:')) {
      final rideId = payload.substring(5);
      // Navegar según el tipo de usuario real
      final userType = _getUserType();

      if (userType == 'driver') {
        Navigator.pushNamed(
          context,
          '/driver/ride-details',
          arguments: {'rideId': rideId},
        );
      } else {
        Navigator.pushNamed(
          context,
          '/passenger/ride-details',
          arguments: {'rideId': rideId},
        );
      }

      AppLogger.debug('Navegando al viaje: $rideId');
    } else if (payload == 'ride_request') {
      // Nueva solicitud de viaje para conductores
      _navigateToDriverHome();
    } else if (payload == 'driver_found') {
      // Conductor encontrado para pasajeros
      _navigateToPassengerHome();
    } else if (payload == 'driver_arrived') {
      // Conductor llegó
      _showDriverArrivedDialog();
    } else if (payload == 'trip_completed') {
      // Viaje completado
      _navigateToTripHistory();
    } else if (payload == 'payment_received') {
      // Pago recibido para conductores
      _navigateToDriverEarnings();
    } else if (payload == 'emergency') {
      // Notificación de emergencia
      _handleEmergencyNotification();
    } else if (payload == 'price_negotiation') {
      // Nueva negociación de precio
      _handlePriceNegotiation();
    }
  }

  /// Obtener tipo de usuario real desde Firebase Auth y Provider
  String _getUserType() {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'guest';

      // Verificar si el widget sigue montado antes de acceder al context
      if (!mounted) return 'passenger';

      // Obtener desde UserProvider si está disponible
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.currentUser != null) {
        return userProvider.currentUser!.userType;
      }

      // Fallback: determinar por claims personalizados
      // En producción, esto vendría de Firebase Auth Custom Claims
      return 'passenger'; // Default
    } catch (e) {
      AppLogger.debug('Error obteniendo tipo de usuario: $e');
      return 'passenger';
    }
  }

  void _showDriverArrivedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_taxi, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Text('¡Tu conductor llegó!'),
          ],
        ),
        content: Text(
          'Tu conductor está esperándote en el punto de recogida. Por favor dirígete al vehículo.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/passenger/home');
            },
            child: Text('Ver detalles'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Navegaciones específicas por tipo de notificación
  void _navigateToDriverHome() {
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/driver/home',
      (route) => route.isFirst,
    );
  }

  void _navigateToPassengerHome() {
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/passenger/home',
      (route) => route.isFirst,
    );
  }

  void _navigateToTripHistory() {
    if (!mounted) return;

    final userType = _getUserType();
    final routeName = userType == 'driver'
        ? '/driver/trip-history'
        : '/passenger/trip-history';
    Navigator.pushNamed(context, routeName);
  }

  void _navigateToDriverEarnings() {
    if (!mounted) return;

    Navigator.pushNamed(context, '/driver/earnings-details');
  }

  void _handleEmergencyNotification() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 32),
            const SizedBox(width: 12),
            Text('🚨 EMERGENCIA'),
          ],
        ),
        content: Text(
          'Se ha detectado una situación de emergencia. Por favor, revisa los detalles inmediatamente.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              // Navigator.pushNamed(context, '/emergency/details'); // NO EXISTE
              Navigator.pushNamed(context, '/passenger/emergency-sos');
            },
            child:
                Text('Ver Emergencia', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handlePriceNegotiation() {
    if (!mounted) return;

    final userType = _getUserType();
    if (userType == 'driver') {
      // Navigator.pushNamed(context, '/driver/negotiations'); // NO EXISTE
      Navigator.pushNamed(
          context, '/driver/home'); // Redirigir a home por ahora
    } else {
      // Navigator.pushNamed(context, '/passenger/negotiations'); // NO EXISTE
      Navigator.pushNamed(
          context, '/passenger/home'); // Redirigir a home por ahora
    }
  }

  @override
  void dispose() {
    _notificationStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

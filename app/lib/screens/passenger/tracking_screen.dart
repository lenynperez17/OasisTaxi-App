// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../shared/chat_screen.dart';

class TrackingScreen extends StatefulWidget {
  final String tripId;
  final String driverName;
  final String driverPhoto;
  final String vehicleInfo;
  final double driverRating;
  final String estimatedTime;
  final String pickupAddress;
  final String destinationAddress;
  final double tripPrice;
  
  const TrackingScreen({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.driverPhoto,
    required this.vehicleInfo,
    required this.driverRating,
    required this.estimatedTime,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.tripPrice,
  });
  
  @override
  _TrackingScreenState createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Animaciones
  late AnimationController _bottomSheetController;
  late AnimationController _pulseController;
  late AnimationController _etaController;
  
  // Estado del viaje
  String _tripStatus = 'arriving'; // arriving, arrived, ontrip, completed
  int _minutesRemaining = 5;
  double _distanceRemaining = 2.5;
  
  // Posición del conductor (simulada)
  LatLng _driverPosition = LatLng(-12.0851, -76.9770);
  final LatLng _passengerPosition = LatLng(-12.0951, -76.9870);
  final LatLng _destinationPosition = LatLng(-12.1051, -77.0070);
  
  Timer? _trackingTimer;
  Timer? _etaTimer;
  
  @override
  void initState() {
    super.initState();
    
    _bottomSheetController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _etaController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    
    _setupMap();
    _startTracking();
  }
  
  @override
  void dispose() {
    _bottomSheetController.dispose();
    _pulseController.dispose();
    _etaController.dispose();
    _trackingTimer?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }
  
  void _setupMap() {
    // Configurar marcadores
    _markers.add(
      Marker(
        markerId: MarkerId('driver'),
        position: _driverPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
        infoWindow: InfoWindow(
          title: widget.driverName,
          snippet: widget.vehicleInfo,
        ),
      ),
    );
    
    _markers.add(
      Marker(
        markerId: MarkerId('passenger'),
        position: _passengerPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        ),
        infoWindow: InfoWindow(
          title: 'Tu ubicación',
          snippet: widget.pickupAddress,
        ),
      ),
    );
    
    if (_tripStatus == 'ontrip') {
      _markers.add(
        Marker(
          markerId: MarkerId('destination'),
          position: _destinationPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: 'Destino',
            snippet: widget.destinationAddress,
          ),
        ),
      );
    }
    
    // Configurar ruta
    _polylines.add(
      Polyline(
        polylineId: PolylineId('route'),
        points: [_driverPosition, _passengerPosition],
        color: ModernTheme.oasisGreen,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );
  }
  
  void _startTracking() {
    // Simular movimiento del conductor
    _trackingTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!mounted) return;
      
      setState(() {
        // Mover conductor hacia el pasajero
        if (_tripStatus == 'arriving') {
          _driverPosition = LatLng(
            _driverPosition.latitude + 0.001,
            _driverPosition.longitude + 0.001,
          );
          
          // Actualizar marcador
          _markers.removeWhere((m) => m.markerId.value == 'driver');
          _markers.add(
            Marker(
              markerId: MarkerId('driver'),
              position: _driverPosition,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              rotation: 45, // Simular rotación
            ),
          );
          
          // Verificar si llegó
          final distance = _calculateDistance(
            _driverPosition,
            _passengerPosition,
          );
          
          if (distance < 0.1) {
            _tripStatus = 'arrived';
            _showArrivedNotification();
          }
        } else if (_tripStatus == 'ontrip') {
          // Mover hacia el destino
          _driverPosition = LatLng(
            _driverPosition.latitude + 0.0015,
            _driverPosition.longitude + 0.0015,
          );
          
          // Actualizar ruta
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route'),
              points: [_passengerPosition, _driverPosition, _destinationPosition],
              color: ModernTheme.oasisGreen,
              width: 5,
            ),
          );
        }
        
        // Centrar mapa
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            _getBounds(),
            100,
          ),
        );
      });
    });
    
    // Actualizar ETA
    _etaTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (!mounted) return;
      
      setState(() {
        if (_minutesRemaining > 0) {
          _minutesRemaining--;
          _distanceRemaining = math.max(0, _distanceRemaining - 0.5);
        }
      });
    });
  }
  
  double _calculateDistance(LatLng pos1, LatLng pos2) {
    return math.sqrt(
      math.pow(pos1.latitude - pos2.latitude, 2) +
      math.pow(pos1.longitude - pos2.longitude, 2),
    );
  }
  
  LatLngBounds _getBounds() {
    double minLat = math.min(
      _driverPosition.latitude,
      math.min(_passengerPosition.latitude, _destinationPosition.latitude),
    );
    double maxLat = math.max(
      _driverPosition.latitude,
      math.max(_passengerPosition.latitude, _destinationPosition.latitude),
    );
    double minLng = math.min(
      _driverPosition.longitude,
      math.min(_passengerPosition.longitude, _destinationPosition.longitude),
    );
    double maxLng = math.max(
      _driverPosition.longitude,
      math.max(_passengerPosition.longitude, _destinationPosition.longitude),
    );
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
  
  void _showArrivedNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.directions_car, color: Colors.white),
            SizedBox(width: 12),
            Text('¡Tu conductor ha llegado!'),
          ],
        ),
        backgroundColor: ModernTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa con tracking
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _driverPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Centrar en los marcadores
              Future.delayed(Duration(milliseconds: 500), () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngBounds(_getBounds(), 100),
                );
              });
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // Indicador de posición del conductor con pulso
          if (_tripStatus == 'arriving' || _tripStatus == 'ontrip')
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: MediaQuery.of(context).size.width * 0.45,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 60 + (20 * _pulseController.value),
                    height: 60 + (20 * _pulseController.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ModernTheme.oasisGreen.withValues(alpha: 
                        0.3 * (1 - _pulseController.value),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Header con información del viaje
          SafeArea(
            child: Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: ModernTheme.floatingShadow,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        AnimatedBuilder(
                          animation: _etaController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1 + (0.1 * _etaController.value),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_minutesRemaining min • $_distanceRemaining km',
                                  style: TextStyle(
                                    color: ModernTheme.oasisGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.share_location),
                    onPressed: _shareLocation,
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom sheet con información del conductor
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _bottomSheetController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 300 * (1 - _bottomSheetController.value)),
                  child: _buildDriverInfoSheet(),
                );
              },
            ),
          ),
          
          // Botón de emergencia
          Positioned(
            right: 16,
            bottom: 320,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: ModernTheme.error,
              onPressed: _showEmergencyOptions,
              child: Icon(Icons.warning, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDriverInfoSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: ModernTheme.floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Estado del viaje
          if (_tripStatus == 'arrived')
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ModernTheme.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: ModernTheme.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu conductor te está esperando',
                      style: TextStyle(
                        color: ModernTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _tripStatus = 'ontrip');
                    },
                    child: Text('Iniciar viaje'),
                  ),
                ],
              ),
            ),
          
          // Información del conductor
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    // Foto del conductor
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ModernTheme.oasisGreen,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundImage: NetworkImage(widget.driverPhoto),
                      ),
                    ),
                    SizedBox(width: 16),
                    
                    // Datos del conductor
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.driverName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      widget.driverRating.toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.vehicleInfo,
                            style: TextStyle(
                              color: ModernTheme.textSecondary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ModernTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ABC-123',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Botones de acción
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.call,
                              color: ModernTheme.oasisGreen,
                            ),
                            onPressed: _callDriver,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.message,
                              color: ModernTheme.primaryBlue,
                            ),
                            onPressed: _openChat,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // Detalles del viaje
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ModernTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Origen
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: ModernTheme.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recogida',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ModernTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  widget.pickupAddress,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Línea conectora
                      Container(
                        margin: EdgeInsets.only(left: 4, top: 4, bottom: 4),
                        width: 2,
                        height: 20,
                        color: Colors.grey.shade300,
                      ),
                      
                      // Destino
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: ModernTheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Destino',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ModernTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  widget.destinationAddress,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      Divider(height: 24),
                      
                      // Precio y método de pago
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.attach_money,
                                color: ModernTheme.oasisGreen,
                                size: 20,
                              ),
                              Text(
                                '\$${widget.tripPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ModernTheme.oasisGreen,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.money,
                                  size: 16,
                                  color: ModernTheme.textSecondary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Efectivo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ModernTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                if (_tripStatus == 'ontrip') ...[
                  SizedBox(height: 16),
                  AnimatedPulseButton(
                    text: 'Finalizar Viaje',
                    icon: Icons.check_circle,
                    onPressed: _completeTrip,
                    color: ModernTheme.success,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getStatusText() {
    switch (_tripStatus) {
      case 'arriving':
        return 'Tu conductor está en camino';
      case 'arrived':
        return 'Tu conductor ha llegado';
      case 'ontrip':
        return 'En viaje hacia tu destino';
      case 'completed':
        return 'Viaje completado';
      default:
        return '';
    }
  }
  
  void _shareLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Compartiendo ubicación en tiempo real...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _callDriver() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Llamando a ${widget.driverName}...'),
        backgroundColor: ModernTheme.oasisGreen,
      ),
    );
  }
  
  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserName: 'Conductor',
          otherUserRole: 'driver',
          rideId: widget.tripId,
        ),
      ),
    );
  }
  
  void _showEmergencyOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Opciones de Emergencia',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ModernTheme.error,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.call, color: ModernTheme.error),
              title: Text('Llamar al 911'),
              onTap: () {
                Navigator.pop(context);
                // Llamar emergencia
              },
            ),
            ListTile(
              leading: Icon(Icons.share_location, color: ModernTheme.warning),
              title: Text('Compartir ubicación con contactos'),
              onTap: () {
                Navigator.pop(context);
                // Compartir ubicación
              },
            ),
            ListTile(
              leading: Icon(Icons.report, color: Colors.orange),
              title: Text('Reportar problema'),
              onTap: () {
                Navigator.pop(context);
                // Reportar
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: ModernTheme.textSecondary),
              title: Text('Cancelar viaje'),
              onTap: () {
                Navigator.pop(context);
                _cancelTrip();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _cancelTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Cancelar Viaje'),
        content: Text(
          '¿Estás seguro de que deseas cancelar el viaje? Se aplicará una tarifa de cancelación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Viaje cancelado'),
                  backgroundColor: ModernTheme.warning,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }
  
  void _completeTrip() {
    setState(() => _tripStatus = 'completed');
    Navigator.pop(context);
    // Mostrar dialog de calificación
  }
}
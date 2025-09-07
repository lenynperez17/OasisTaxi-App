// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';

class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  
  TripDetailsScreen({super.key, required this.tripId});
  
  @override
  _TripDetailsScreenState createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  // Trip data
  TripDetail? _tripDetail;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    
    _loadTripDetails();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  void _loadTripDetails() async {
    // Simulate loading trip details
    await Future.delayed(Duration(seconds: 2));
    
    setState(() {
      _tripDetail = TripDetail(
        id: widget.tripId,
        status: TripStatus.completed,
        date: DateTime.now().subtract(Duration(days: 2)),
        pickupLocation: TripLocation(
          address: 'Av. Los Conquistadores 123, San Isidro',
          coordinates: LatLng(-12.0931, -77.0465),
          landmark: 'Frente al banco BCP',
        ),
        destinationLocation: TripLocation(
          address: 'Centro Comercial Jockey Plaza, Surco',
          coordinates: LatLng(-12.0822, -76.9761),
          landmark: 'Puerta principal - Food Court',
        ),
        driver: DriverInfo(
          id: 'DRV_001',
          name: 'Carlos Mendoza',
          rating: 4.8,
          totalTrips: 1247,
          phone: '+51 987 654 321',
          photo: '',
          vehicle: VehicleInfo(
            make: 'Toyota',
            model: 'Yaris',
            year: 2020,
            color: 'Blanco',
            plate: 'ABC-123',
          ),
        ),
        pricing: TripPricing(
          baseFare: 5.00,
          distanceFare: 12.50,
          timeFare: 8.00,
          tip: 5.00,
          discount: 3.00,
          total: 27.50,
          paymentMethod: 'Tarjeta Visa ****1234',
        ),
        timeline: [
          TripEvent(
            time: DateTime.now().subtract(Duration(days: 2, hours: 2, minutes: 30)),
            type: TripEventType.requested,
            description: 'Viaje solicitado',
          ),
          TripEvent(
            time: DateTime.now().subtract(Duration(days: 2, hours: 2, minutes: 28)),
            type: TripEventType.driverAssigned,
            description: 'Conductor asignado: Carlos Mendoza',
          ),
          TripEvent(
            time: DateTime.now().subtract(Duration(days: 2, hours: 2, minutes: 25)),
            type: TripEventType.driverArrived,
            description: 'Conductor llegó al punto de recogida',
          ),
          TripEvent(
            time: DateTime.now().subtract(Duration(days: 2, hours: 2, minutes: 23)),
            type: TripEventType.tripStarted,
            description: 'Viaje iniciado',
          ),
          TripEvent(
            time: DateTime.now().subtract(Duration(days: 2, hours: 1, minutes: 55)),
            type: TripEventType.tripCompleted,
            description: 'Viaje completado',
          ),
          TripEvent(
            time: DateTime.now().subtract(Duration(days: 2, hours: 1, minutes: 53)),
            type: TripEventType.paymentProcessed,
            description: 'Pago procesado exitosamente',
          ),
        ],
        distance: 8.5,
        duration: 28,
        rating: 5,
        comment: 'Excelente servicio, muy puntual y amable.',
        receipt: TripReceipt(
          receiptNumber: 'REC-${widget.tripId}',
          issueDate: DateTime.now().subtract(Duration(days: 2)),
          taxAmount: 4.95,
          subtotal: 22.55,
        ),
      );
      _isLoading = false;
    });
    
    _fadeController.forward();
    _slideController.forward();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Detalles del Viaje',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: Colors.white),
            onPressed: _shareTrip,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'receipt',
                child: Row(
                  children: [
                    Icon(Icons.receipt, size: 18),
                    SizedBox(width: 8),
                    Text('Ver recibo'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'repeat',
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 18),
                    SizedBox(width: 8),
                    Text('Repetir viaje'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report, size: 18, color: ModernTheme.error),
                    SizedBox(width: 8),
                    Text('Reportar problema', style: TextStyle(color: ModernTheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildTripDetails(),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando detalles del viaje...',
            style: TextStyle(
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTripDetails() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Trip status header
                _buildStatusHeader(),
                
                // Route information
                _buildRouteSection(),
                
                // Driver information
                _buildDriverSection(),
                
                // Pricing breakdown
                _buildPricingSection(),
                
                // Trip timeline
                _buildTimelineSection(),
                
                // Rating and feedback
                if (_tripDetail!.status == TripStatus.completed)
                  _buildRatingSection(),
                
                SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusHeader() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getStatusGradient(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusText(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ID: ${_tripDetail!.id}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'S/ ${_tripDetail!.pricing.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      '${_tripDetail!.distance} km',
                      'Distancia',
                      Icons.straighten,
                    ),
                    _buildStatItem(
                      '${_tripDetail!.duration} min',
                      'Duración',
                      Icons.schedule,
                    ),
                    _buildStatItem(
                      _formatDate(_tripDetail!.date),
                      'Fecha',
                      Icons.calendar_today,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRouteSection() {
    return _buildSection(
      'Ruta del Viaje',
      Icons.route,
      ModernTheme.primaryBlue,
      [
        _buildLocationCard(
          'Punto de recogida',
          _tripDetail!.pickupLocation,
          ModernTheme.success,
          Icons.my_location,
        ),
        Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 24),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ModernTheme.success, ModernTheme.error],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 24),
            ],
          ),
        ),
        _buildLocationCard(
          'Destino',
          _tripDetail!.destinationLocation,
          ModernTheme.error,
          Icons.location_on,
        ),
      ],
    );
  }
  
  Widget _buildLocationCard(String title, TripLocation location, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  location.address,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (location.landmark.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    location.landmark,
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDriverSection() {
    return _buildSection(
      'Información del Conductor',
      Icons.person,
      ModernTheme.oasisGreen,
      [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: ModernTheme.oasisGreen,
              child: Text(
                _tripDetail!.driver.name.split(' ').map((n) => n[0]).take(2).join(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tripDetail!.driver.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            Icons.star,
                            size: 16,
                            color: index < _tripDetail!.driver.rating.floor()
                                ? Colors.amber
                                : Colors.grey.shade300,
                          );
                        }),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${_tripDetail!.driver.rating} (${_tripDetail!.driver.totalTrips} viajes)',
                        style: TextStyle(
                          color: ModernTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _callDriver,
              icon: Icon(Icons.phone, color: ModernTheme.primaryBlue),
            ),
            IconButton(
              onPressed: _messageDriver,
              icon: Icon(Icons.message, color: ModernTheme.oasisGreen),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ModernTheme.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_car, color: ModernTheme.textSecondary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_tripDetail!.driver.vehicle.color} ${_tripDetail!.driver.vehicle.make} ${_tripDetail!.driver.vehicle.model} ${_tripDetail!.driver.vehicle.year}',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _tripDetail!.driver.vehicle.plate,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.oasisGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPricingSection() {
    return _buildSection(
      'Desglose del Precio',
      Icons.receipt,
      Colors.orange,
      [
        _buildPriceRow('Tarifa base', _tripDetail!.pricing.baseFare),
        _buildPriceRow('Por distancia (${_tripDetail!.distance} km)', _tripDetail!.pricing.distanceFare),
        _buildPriceRow('Por tiempo (${_tripDetail!.duration} min)', _tripDetail!.pricing.timeFare),
        if (_tripDetail!.pricing.tip > 0)
          _buildPriceRow('Propina', _tripDetail!.pricing.tip),
        if (_tripDetail!.pricing.discount > 0)
          _buildPriceRow('Descuento', -_tripDetail!.pricing.discount, isDiscount: true),
        Divider(),
        _buildPriceRow('Total', _tripDetail!.pricing.total, isTotal: true),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ModernTheme.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.payment, color: ModernTheme.textSecondary),
              SizedBox(width: 12),
              Text(
                'Método de pago: ${_tripDetail!.pricing.paymentMethod}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPriceRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isDiscount ? ModernTheme.success : null,
            ),
          ),
          Text(
            '${amount >= 0 ? '' : '-'}S/ ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color: isTotal 
                  ? ModernTheme.oasisGreen 
                  : isDiscount 
                      ? ModernTheme.success 
                      : null,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimelineSection() {
    return _buildSection(
      'Cronología del Viaje',
      Icons.timeline,
      Colors.purple,
      [
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _tripDetail!.timeline.length,
          itemBuilder: (context, index) {
            final event = _tripDetail!.timeline[index];
            final isLast = index == _tripDetail!.timeline.length - 1;
            
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getEventColor(event.type),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.grey.shade300,
                      ),
                  ],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.description,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _formatTime(event.time),
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildRatingSection() {
    return _buildSection(
      'Tu Calificación',
      Icons.star,
      Colors.amber,
      [
        Row(
          children: [
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  Icons.star,
                  size: 24,
                  color: index < _tripDetail!.rating!
                      ? Colors.amber
                      : Colors.grey.shade300,
                );
              }),
            ),
            SizedBox(width: 12),
            Text(
              '${_tripDetail!.rating}/5',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (_tripDetail!.comment != null && _tripDetail!.comment!.isNotEmpty) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ModernTheme.backgroundLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote, color: ModernTheme.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _tripDetail!.comment!,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor() {
    switch (_tripDetail!.status) {
      case TripStatus.completed:
        return ModernTheme.success;
      case TripStatus.cancelled:
        return ModernTheme.error;
      case TripStatus.inProgress:
        return ModernTheme.warning;
      default:
        return ModernTheme.textSecondary;
    }
  }
  
  List<Color> _getStatusGradient() {
    final color = _getStatusColor();
    return [color, color.withValues(alpha: 0.8)];
  }
  
  IconData _getStatusIcon() {
    switch (_tripDetail!.status) {
      case TripStatus.completed:
        return Icons.check_circle;
      case TripStatus.cancelled:
        return Icons.cancel;
      case TripStatus.inProgress:
        return Icons.directions_car;
      default:
        return Icons.info;
    }
  }
  
  String _getStatusText() {
    switch (_tripDetail!.status) {
      case TripStatus.completed:
        return 'Viaje Completado';
      case TripStatus.cancelled:
        return 'Viaje Cancelado';
      case TripStatus.inProgress:
        return 'Viaje en Progreso';
      default:
        return 'Estado Desconocido';
    }
  }
  
  Color _getEventColor(TripEventType type) {
    switch (type) {
      case TripEventType.requested:
        return Colors.blue;
      case TripEventType.driverAssigned:
        return Colors.orange;
      case TripEventType.driverArrived:
        return Colors.purple;
      case TripEventType.tripStarted:
        return ModernTheme.success;
      case TripEventType.tripCompleted:
        return ModernTheme.oasisGreen;
      case TripEventType.paymentProcessed:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  void _shareTrip() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Compartiendo detalles del viaje...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _handleMenuAction(String action) {
    switch (action) {
      case 'receipt':
        _showReceipt();
        break;
      case 'repeat':
        _repeatTrip();
        break;
      case 'report':
        _reportProblem();
        break;
    }
  }
  
  void _showReceipt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generando recibo...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _repeatTrip() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Solicitando viaje similar...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _reportProblem() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo formulario de reporte...'),
        backgroundColor: ModernTheme.warning,
      ),
    );
  }
  
  void _callDriver() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Llamando a ${_tripDetail!.driver.name}...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _messageDriver() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo chat con ${_tripDetail!.driver.name}...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
}

// Models
class TripDetail {
  final String id;
  final TripStatus status;
  final DateTime date;
  final TripLocation pickupLocation;
  final TripLocation destinationLocation;
  final DriverInfo driver;
  final TripPricing pricing;
  final List<TripEvent> timeline;
  final double distance;
  final int duration;
  final int? rating;
  final String? comment;
  final TripReceipt receipt;
  
  TripDetail({
    required this.id,
    required this.status,
    required this.date,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.driver,
    required this.pricing,
    required this.timeline,
    required this.distance,
    required this.duration,
    this.rating,
    this.comment,
    required this.receipt,
  });
}

class TripLocation {
  final String address;
  final LatLng coordinates;
  final String landmark;
  
  TripLocation({
    required this.address,
    required this.coordinates,
    required this.landmark,
  });
}

class LatLng {
  final double latitude;
  final double longitude;
  
  LatLng(this.latitude, this.longitude);
}

class DriverInfo {
  final String id;
  final String name;
  final double rating;
  final int totalTrips;
  final String phone;
  final String photo;
  final VehicleInfo vehicle;
  
  DriverInfo({
    required this.id,
    required this.name,
    required this.rating,
    required this.totalTrips,
    required this.phone,
    required this.photo,
    required this.vehicle,
  });
}

class VehicleInfo {
  final String make;
  final String model;
  final int year;
  final String color;
  final String plate;
  
  VehicleInfo({
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plate,
  });
}

class TripPricing {
  final double baseFare;
  final double distanceFare;
  final double timeFare;
  final double tip;
  final double discount;
  final double total;
  final String paymentMethod;
  
  TripPricing({
    required this.baseFare,
    required this.distanceFare,
    required this.timeFare,
    required this.tip,
    required this.discount,
    required this.total,
    required this.paymentMethod,
  });
}

class TripEvent {
  final DateTime time;
  final TripEventType type;
  final String description;
  
  TripEvent({
    required this.time,
    required this.type,
    required this.description,
  });
}

class TripReceipt {
  final String receiptNumber;
  final DateTime issueDate;
  final double taxAmount;
  final double subtotal;
  
  TripReceipt({
    required this.receiptNumber,
    required this.issueDate,
    required this.taxAmount,
    required this.subtotal,
  });
}

enum TripStatus { requested, driverAssigned, inProgress, completed, cancelled }

enum TripEventType {
  requested,
  driverAssigned,
  driverArrived,
  tripStarted,
  tripCompleted,
  paymentProcessed,
}
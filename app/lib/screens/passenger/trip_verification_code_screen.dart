// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip_model.dart';
import '../../services/emergency_service.dart';

/// Pantalla que muestra el código de verificación al pasajero
class TripVerificationCodeScreen extends StatefulWidget {
  final TripModel trip;

  const TripVerificationCodeScreen({
    super.key,
    required this.trip,
  });

  @override
  _TripVerificationCodeScreenState createState() => _TripVerificationCodeScreenState();
}

class _TripVerificationCodeScreenState extends State<TripVerificationCodeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Listener para detectar cuando el código sea verificado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTripListener();
    });
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
  }
  
  void _setupTripListener() {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    rideProvider.addListener(_onTripStatusChanged);
  }
  
  void _onTripStatusChanged() {
    if (!mounted) return;
    
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final currentTrip = rideProvider.currentTrip;
    
    if (currentTrip != null && currentTrip.id == widget.trip.id) {
      // Si el código fue verificado (viaje en progreso), volver a la pantalla anterior
      if (currentTrip.status == 'in_progress' && currentTrip.isVerificationCodeUsed) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Código verificado exitosamente! Tu viaje ha comenzado.'),
            backgroundColor: ModernTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // No acceder al context en dispose - el listener se limpiará automáticamente
    // cuando el widget sea desmontado
    
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: OasisAppBar(
        title: 'Código de Verificación',
        showBackButton: true,
      ),
      body: Consumer<RideProvider>(
        builder: (context, rideProvider, child) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Información del conductor
                  _buildDriverInfo(),
                  
                  SizedBox(height: 40),
                  
                  // Código de verificación principal
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildVerificationCode(),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Instrucciones
                  _buildInstructions(),
                  
                  Spacer(),
                  
                  // Estado del viaje
                  _buildTripStatus(),
                  
                  SizedBox(height: 20),
                  
                  // Botón de emergencia
                  _buildEmergencyButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDriverInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Avatar del conductor
          CircleAvatar(
            radius: 30,
            backgroundColor: ModernTheme.oasisGreen.withValues(alpha: 0.1),
            child: Icon(
              Icons.person,
              size: 32,
              color: ModernTheme.oasisGreen,
            ),
          ),
          SizedBox(width: 16),
          // Info del conductor
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trip.driverId ?? 'Conductor asignado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      widget.trip.driverRating?.toStringAsFixed(1) ?? '5.0',
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 16),
                    Icon(Icons.directions_car, size: 16, color: ModernTheme.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      widget.trip.vehicleInfo?['model'] ?? 'Vehículo',
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Estado
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'En camino',
              style: TextStyle(
                color: ModernTheme.oasisGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCode() {
    final code = widget.trip.verificationCode ?? '----';
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ModernTheme.oasisGreen,
                  ModernTheme.oasisGreen.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ModernTheme.oasisGreen.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.security,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 16),
                Text(
                  'Tu Código de Verificación',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: code.split('').map((digit) {
                    return Container(
                      width: 60,
                      height: 60,
                      margin: EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          digit,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ModernTheme.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ModernTheme.oasisGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: ModernTheme.oasisGreen,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Instrucciones de Seguridad',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInstructionItem(
            '1',
            'Muestra este código al conductor cuando llegue',
          ),
          _buildInstructionItem(
            '2',
            'El conductor debe ingresar el código exacto',
          ),
          _buildInstructionItem(
            '3',
            'El viaje solo comenzará con el código correcto',
          ),
          _buildInstructionItem(
            '4',
            'No compartas este código con nadie más',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStatus() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.trip.status == 'driver_arriving' 
                ? Colors.orange.withValues(alpha: 0.1)
                : ModernTheme.oasisGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.trip.status == 'driver_arriving' 
                ? Icons.directions_car
                : Icons.check_circle,
              color: widget.trip.status == 'driver_arriving' 
                ? Colors.orange
                : ModernTheme.oasisGreen,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trip.statusDisplay,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  widget.trip.status == 'driver_arriving' 
                    ? 'Tu conductor está llegando'
                    : 'Esperando verificación',
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleEmergencyPress,
        icon: Icon(Icons.emergency, color: Colors.red),
        label: Text(
          'Emergencia',
          style: TextStyle(color: Colors.red, fontSize: 16),
        ),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.red, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergencia'),
          ],
        ),
        content: Text(
          '¿Necesitas ayuda de emergencia? Esto notificará a las autoridades y cancelará tu viaje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _triggerRealEmergency,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Llamar Emergencia', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Manejar presión del botón de emergencia
  void _handleEmergencyPress() {
    _showEmergencyDialog();
  }

  /// Activar emergencia real con el EmergencyServiceReal
  Future<void> _triggerRealEmergency() async {
    Navigator.pop(context);
    
    // Mostrar loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 16),
            Text('🚨 Activando emergencia...', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Notificando autoridades y contactos', textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    try {
      final emergencyService = EmergencyService();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      
      final response = await emergencyService.triggerSOS(
        userId: currentUser?.id ?? '',
        userType: currentUser?.userType ?? 'passenger',
      );

      // Cerrar loading dialog
      if (mounted) Navigator.pop(context);

      if (response.success) {
        // Mostrar confirmación
        _showEmergencySuccessDialog(response);
        
        // Log para auditoría
        debugPrint('SOS activado - Trip: ${widget.trip.id}');
        
      } else {
        _showEmergencyErrorDialog(response.message ?? 'Error desconocido');
      }

    } catch (e) {
      // Cerrar loading dialog si aún está abierto
      if (mounted) Navigator.pop(context);
      
      debugPrint('Error activando SOS: $e');
      _showEmergencyErrorDialog('Error activando emergencia: $e');
    }
  }

  /// Mostrar diálogo de éxito de emergencia
  void _showEmergencySuccessDialog(dynamic response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('🚨 SOS ACTIVADO'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Emergencia activada exitosamente'),
            SizedBox(height: 8),
            Text('📞 Llamada de emergencia iniciada'),
            SizedBox(height: 8),
            Text('📱 ${response.contactsNotified} contactos notificados'),
            SizedBox(height: 8),
            Text('🎤 Grabación de audio iniciada'),
            SizedBox(height: 8),
            Text('📍 Ubicación enviada a autoridades'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                'ID de Emergencia: ${response.emergencyId ?? 'N/A'}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Regresar a home con estado de emergencia
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/passenger/home',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Entendido', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Mostrar diálogo de error de emergencia
  void _showEmergencyErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('Error de Emergencia'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No se pudo activar completamente el SOS:'),
            SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ RECOMENDACIÓN: Llame directamente al 911 o 105',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
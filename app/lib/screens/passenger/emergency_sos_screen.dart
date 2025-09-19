import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/oasis_button.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../widgets/cards/oasis_card.dart';
import '../../services/emergency_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../utils/app_logger.dart';
import '../../providers/emergency_provider.dart' show EmergencyContact;
// Importar EmergencyType y EmergencyHistory desde emergency_service
export '../../services/emergency_service.dart'
    show EmergencyType, EmergencyHistory;

/// PANTALLA DE EMERGENCIA SOS - OASIS TAXI
/// =======================================
///
/// Funcionalidades críticas:
/// 🚨 Botón de pánico grande y visible
/// 📞 Llamada automática al 911
/// 📱 Notificación a contactos de emergencia
/// 🎙️ Grabación de audio automática
/// 📍 Compartir ubicación en tiempo real
/// 📳 Vibración continua y alertas visuales
/// ❌ Cancelación de emergencia (solo falsa alarma)
/// 📋 Historial de emergencias
class EmergencySOSScreen extends StatefulWidget {
  final String userId;
  final String userType; // 'passenger' o 'driver'
  final String? rideId;

  const EmergencySOSScreen({
    super.key,
    required this.userId,
    required this.userType,
    this.rideId,
  });

  @override
  State<EmergencySOSScreen> createState() => EmergencySOSScreenState();
}

class EmergencySOSScreenState extends State<EmergencySOSScreen>
    with TickerProviderStateMixin {
  final EmergencyService _emergencyService = EmergencyService();
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = false;
  bool _emergencyActive = false;
  Timer? _vibrationTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _warningController;
  late Animation<Color?> _warningAnimation;

  List<EmergencyType> _emergencyTypes = [];
  EmergencyType? _selectedEmergencyType;
  List<EmergencyContact> _emergencyContacts = [];
  List<EmergencyHistory> _emergencyHistory = [];

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('EmergencySOSScreen',
        'initState - Usuario: ${widget.userId}, Tipo: ${widget.userType}, RideId: ${widget.rideId}');
    _initializeServices();
    _setupAnimations();
    _loadEmergencyData();
  }

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    _pulseController.dispose();
    _warningController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    // Animación de pulso para el botón SOS
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Animación de advertencia para el fondo
    _warningController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _warningAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.red.withValues(alpha: 0.3),
    ).animate(_warningController);
  }

  Future<void> _initializeServices() async {
    await _emergencyService.initialize();

    if (!mounted) return;
    setState(() {
      _emergencyActive = _emergencyService.isEmergencyActive;
    });

    if (_emergencyActive) {
      _startEmergencyAnimation();
    }
  }

  Future<void> _loadEmergencyData() async {
    AppLogger.info('Cargando datos de emergencia - Usuario: ${widget.userId}');
    setState(() => _isLoading = true);

    try {
      AppLogger.api('GET', 'EmergencyService - getEmergencyTypes');
      _emergencyTypes = EmergencyService.getEmergencyTypes();
      _selectedEmergencyType = _emergencyTypes.first;

      AppLogger.api('GET',
          'EmergencyService - getEmergencyContacts para usuario: ${widget.userId}');
      _emergencyContacts =
          await _emergencyService.getEmergencyContacts(widget.userId);

      AppLogger.api('GET',
          'EmergencyService - getUserEmergencyHistory para usuario: ${widget.userId}');
      _emergencyHistory =
          await _emergencyService.getUserEmergencyHistory(widget.userId);

      AppLogger.info(
          'Datos de emergencia cargados exitosamente - Contactos: ${_emergencyContacts.length}, Historial: ${_emergencyHistory.length}');
    } catch (e) {
      AppLogger.error(
          'Error cargando datos de emergencia - Usuario: ${widget.userId}', e);
      _showErrorSnackBar('Error cargando datos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================================
  // FUNCIONES DE EMERGENCIA PRINCIPAL
  // ============================================================================

  Future<void> _triggerSOS() async {
    AppLogger.critical(
        'INTENTO DE ACTIVACIÓN SOS - Usuario: ${widget.userId}, Tipo: ${widget.userType}, RideId: ${widget.rideId}, TipoEmergencia: ${_selectedEmergencyType?.id}');

    final confirmed = await _showSOSConfirmation();
    if (!confirmed) {
      AppLogger.info(
          'Usuario canceló activación SOS - Usuario: ${widget.userId}');
      return;
    }

    setState(() => _isLoading = true);

    try {
      AppLogger.critical(
          'ACTIVANDO SOS REAL - Usuario: ${widget.userId}, TipoEmergencia: ${_selectedEmergencyType?.id}');
      AppLogger.api('POST', 'EmergencyService - triggerSOS CRÍTICO');

      final result = await _emergencyService.triggerSOS(
        userId: widget.userId,
        userType: widget.userType,
        rideId: widget.rideId,
        emergencyType: _selectedEmergencyType ??
            EmergencyService.getEmergencyTypes().first,
        description: 'Emergencia activada desde la aplicación Oasis Taxi',
      );

      if (result['success'] == true) {
        AppLogger.critical(
            'SOS ACTIVADO EXITOSAMENTE - Usuario: ${widget.userId}, Servicios contactados: 911, Contactos notificados');

        if (mounted) {
          setState(() {
            _emergencyActive = true;
          });
        }

        _startEmergencyAnimation();
        _startContinuousVibration();

        _showSuccessDialog(
          title: '🚨 SOS ACTIVADO',
          message: result['message'] ?? 'Servicios de emergencia contactados',
        );

        AppLogger.firebase('Analytics - emergency_sos_triggered_from_screen');
        await _firebaseService.analytics?.logEvent(
          name: 'emergency_sos_triggered_from_screen',
          parameters: {
            'user_id': widget.userId,
            'user_type': widget.userType,
            'emergency_type': _selectedEmergencyType?.id ?? 'sos_panic',
            'ride_id': widget.rideId ?? '',
          },
        );
      } else {
        AppLogger.error(
            'FALLÓ ACTIVACIÓN SOS - Usuario: ${widget.userId}, Error: ${result['error']}');
        _showErrorSnackBar(result['error'] ?? 'Error activando SOS');
      }
    } catch (e) {
      AppLogger.critical(
          'ERROR CRÍTICO AL ACTIVAR SOS - Usuario: ${widget.userId}', e);
      _showErrorSnackBar('Error activando SOS: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelEmergency() async {
    AppLogger.critical(
        'INTENTO DE CANCELACIÓN DE EMERGENCIA - Usuario: ${widget.userId}');

    final confirmed = await _showCancelConfirmation();
    if (!confirmed) {
      AppLogger.info(
          'Usuario canceló la cancelación de emergencia - Usuario: ${widget.userId}');
      return;
    }

    setState(() => _isLoading = true);

    try {
      AppLogger.critical(
          'CANCELANDO EMERGENCIA ACTIVA - Usuario: ${widget.userId}, Razón: Falsa alarma');
      AppLogger.api('POST', 'EmergencyService - cancelEmergency');

      final success = await _emergencyService.cancelEmergency(
        'Cancelado por el usuario - Falsa alarma',
      );

      if (success) {
        AppLogger.critical(
            'EMERGENCIA CANCELADA EXITOSAMENTE - Usuario: ${widget.userId}');

        if (mounted) {
          setState(() {
            _emergencyActive = false;
          });
        }

        _stopEmergencyAnimation();
        _stopContinuousVibration();

        _showSuccessDialog(
          title: '✅ EMERGENCIA CANCELADA',
          message: 'La emergencia ha sido cancelada exitosamente',
        );

        AppLogger.info(
            'Recargando historial de emergencias tras cancelación - Usuario: ${widget.userId}');
        await _loadEmergencyData();
      } else {
        AppLogger.error(
            'FALLÓ CANCELACIÓN DE EMERGENCIA - Usuario: ${widget.userId}');
        _showErrorSnackBar('Error cancelando emergencia');
      }
    } catch (e) {
      AppLogger.critical(
          'ERROR CRÍTICO AL CANCELAR EMERGENCIA - Usuario: ${widget.userId}',
          e);
      _showErrorSnackBar('Error cancelando emergencia: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================================
  // FUNCIONES DE ANIMACIÓN Y EFECTOS
  // ============================================================================

  void _startEmergencyAnimation() {
    _pulseController.repeat(reverse: true);
    _warningController.repeat(reverse: true);
  }

  void _stopEmergencyAnimation() {
    _pulseController.stop();
    _warningController.stop();
    _warningController.reset();
  }

  void _startContinuousVibration() {
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      HapticFeedback.heavyImpact();
    });
  }

  void _stopContinuousVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  // ============================================================================
  // DIÁLOGOS DE CONFIRMACIÓN
  // ============================================================================

  Future<bool> _showSOSConfirmation() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Text('🚨 CONFIRMAR SOS'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Estás seguro que quieres activar la emergencia SOS?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                AppSpacing.verticalSpaceMD,
                const Text(
                  'Esto hará lo siguiente:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• 📞 Llamada automática al 911'),
                    Text('• 📱 SMS a tus contactos de emergencia'),
                    Text('• 🎙️ Iniciar grabación de audio'),
                    Text('• 📍 Compartir ubicación en tiempo real'),
                    Text('• 🔔 Alertar a Oasis Taxi Central'),
                  ],
                ),
                AppSpacing.verticalSpaceMD,
                Container(
                  padding: AppSpacing.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    '⚠️ Solo usar en emergencias reales. Uso indebido puede tener consecuencias legales.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              OasisButton.text(
                text: 'CANCELAR',
                onPressed: () => Navigator.of(context).pop(false),
              ),
              OasisButton.danger(
                text: 'SÍ, ACTIVAR SOS',
                onPressed: () => Navigator.of(context).pop(true),
                size: OasisButtonSize.large,
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showCancelConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancelar Emergencia'),
            content: const Text(
              '¿Estás seguro que quieres cancelar la emergencia activa?\n\n'
              'Solo cancela si es una falsa alarma.',
            ),
            actions: [
              OasisButton.text(
                text: 'NO',
                onPressed: () => Navigator.of(context).pop(false),
              ),
              OasisButton.secondary(
                text: 'SÍ, CANCELAR',
                onPressed: () => Navigator.of(context).pop(true),
                size: OasisButtonSize.large,
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    AppLogger.error(
        'Mostrando error al usuario - EmergencySOSScreen: $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ModernTheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================================
  // UI - BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _emergencyActive ? ModernTheme.error : ModernTheme.background,
      appBar: OasisAppBar.elevated(
        title: '🚨 EMERGENCIA SOS',
        backgroundColor:
            _emergencyActive ? ModernTheme.error : ModernTheme.oasisGreen,
        textColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: _warningAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: _warningAnimation.value,
            ),
            child: LoadingOverlay(
              isLoading: _isLoading,
              child: SingleChildScrollView(
                padding: ModernTheme.getResponsivePadding(context),
                child: Column(
                  children: [
                    if (_emergencyActive) _buildActiveEmergencyCard(),
                    if (!_emergencyActive) ...[
                      _buildSOSButton(),
                      AppSpacing.verticalSpaceLG,
                      _buildEmergencyTypeSelector(),
                      AppSpacing.verticalSpaceLG,
                      _buildEmergencyContactsCard(),
                    ],
                    AppSpacing.verticalSpaceLG,
                    _buildEmergencyHistoryCard(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSOSButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.red.shade400,
                  Colors.red.shade600,
                  Colors.red.shade800,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(125),
                onTap: _isLoading ? null : _triggerSOS,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emergency,
                        color: Colors.white,
                        size: 80,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'TOCA PARA ACTIVAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveEmergencyCard() {
    return OasisCard.elevated(
      backgroundColor: Colors.white,
      child: Padding(
        padding: AppSpacing.all(AppSpacing.lg),
        child: Column(
          children: [
            const Icon(
              Icons.emergency,
              color: Colors.red,
              size: 64,
            ),
            AppSpacing.verticalSpaceMD,
            const Text(
              '🚨 EMERGENCIA ACTIVA',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalSpaceSM,
            const Text(
              'Los servicios de emergencia han sido contactados.\n'
              'Tus contactos de emergencia han sido notificados.\n'
              'Se está compartiendo tu ubicación en tiempo real.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Icon(Icons.phone, color: Colors.green, size: 32),
                    Text('911\nLlamado', textAlign: TextAlign.center),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.contacts, color: Colors.blue, size: 32),
                    Text('Contactos\nNotificados', textAlign: TextAlign.center),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.red, size: 32),
                    Text('Ubicación\nCompartida', textAlign: TextAlign.center),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OasisButton.secondary(
                text: 'CANCELAR EMERGENCIA (Solo Falsa Alarma)',
                onPressed: _isLoading ? null : _cancelEmergency,
                icon: Icons.cancel,
                size: OasisButtonSize.large,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyTypeSelector() {
    return Card(
      child: Padding(
        padding: AppSpacing.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo de Emergencia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            AppSpacing.verticalSpaceSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emergencyTypes.map((type) {
                final isSelected = _selectedEmergencyType?.id == type.id;
                return FilterChip(
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedEmergencyType = type;
                    });
                  },
                  label: Text('${type.icon} ${type.name}'),
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: Colors.red.shade100,
                  checkmarkColor: Colors.red,
                );
              }).toList(),
            ),
            if (_selectedEmergencyType != null) ...[
              AppSpacing.verticalSpaceSM,
              Container(
                padding: AppSpacing.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tipo seleccionado: ${_selectedEmergencyType!.name}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsCard() {
    return OasisCard.elevated(
      child: Padding(
        padding: AppSpacing.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contactos de Emergencia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                OasisButton.text(
                  text: 'Agregar',
                  onPressed: () {
                    // Navegar a configurar contactos
                  },
                  icon: Icons.add,
                ),
              ],
            ),
            AppSpacing.verticalSpaceSM,
            if (_emergencyContacts.isEmpty)
              Container(
                padding: AppSpacing.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No tienes contactos de emergencia configurados. '
                        'Es muy importante agregar al menos 3 contactos.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _emergencyContacts.take(3).map((contact) {
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(contact.name),
                    subtitle:
                        Text('${contact.relationship} • ${contact.phone}'),
                    trailing: const Icon(Icons.phone, color: Colors.green),
                    dense: true,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyHistoryCard() {
    return OasisCard.elevated(
      child: Padding(
        padding: AppSpacing.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historial de Emergencias',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            AppSpacing.verticalSpaceSM,
            if (_emergencyHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay emergencias previas',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: _emergencyHistory.take(3).map((emergency) {
                  IconData statusIcon;
                  Color statusColor;

                  switch (emergency.status) {
                    case 'resolved':
                      statusIcon = Icons.check_circle;
                      statusColor = Colors.green;
                      break;
                    case 'cancelled':
                      statusIcon = Icons.cancel;
                      statusColor = Colors.orange;
                      break;
                    default:
                      statusIcon = Icons.warning;
                      statusColor = Colors.red;
                  }

                  return ListTile(
                    leading: Icon(statusIcon, color: statusColor),
                    title: Text(_getEmergencyTypeName(emergency.type)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(emergency.location != null
                            ? 'Ubicación: ${emergency.location?['description'] ?? 'No disponible'}'
                            : 'Sin ubicación'),
                        Text(
                          '${emergency.createdAt.day}/${emergency.createdAt.month}/${emergency.createdAt.year} '
                          '${emergency.createdAt.hour}:${emergency.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    dense: true,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _getEmergencyTypeName(String type) {
    final emergencyType = _emergencyTypes.firstWhere(
      (t) => t.id == type,
      orElse: () => EmergencyService.getEmergencyTypes().first,
    );
    return '${emergencyType.icon} ${emergencyType.name}';
  }
}

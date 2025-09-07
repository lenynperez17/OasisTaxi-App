// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/common/oasis_app_bar.dart';
import '../../providers/ride_provider.dart';
import '../../models/trip_model.dart';

/// Pantalla para que el conductor ingrese el código de verificación
class DriverVerificationScreen extends StatefulWidget {
  final TripModel trip;

  const DriverVerificationScreen({
    super.key,
    required this.trip,
  });

  @override
  _DriverVerificationScreenState createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  List<String> _enteredCode = ['', '', '', ''];
  int _currentIndex = 0;
  bool _isVerifying = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    _shakeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: OasisAppBar(
        title: 'Verificar Pasajero',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Información del pasajero
              _buildPassengerInfo(),
              
              SizedBox(height: 40),
              
              // Instrucciones
              _buildInstructions(),
              
              SizedBox(height: 30),
              
              // Campo de entrada del código
              _buildCodeInput(),
              
              if (_errorMessage.isNotEmpty) ...[
                SizedBox(height: 16),
                _buildErrorMessage(),
              ],
              
              SizedBox(height: 40),
              
              // Teclado numérico
              _buildNumericKeypad(),
              
              Spacer(),
              
              // Botón de verificar
              _buildVerifyButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Avatar del pasajero
          CircleAvatar(
            radius: 30,
            backgroundColor: ModernTheme.primaryBlue.withValues(alpha: 0.1),
            child: Icon(
              Icons.person,
              size: 32,
              color: ModernTheme.primaryBlue,
            ),
          ),
          SizedBox(width: 16),
          // Info del pasajero
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pasajero',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: ModernTheme.textSecondary),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.trip.pickupAddress,
                        style: TextStyle(
                          color: ModernTheme.textSecondary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: ModernTheme.textSecondary),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.trip.destinationAddress,
                        style: TextStyle(
                          color: ModernTheme.textSecondary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tarifa
          Column(
            children: [
              Text(
                '\$${widget.trip.estimatedFare.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.oasisGreen,
                ),
              ),
              Text(
                '${widget.trip.estimatedDistance.toStringAsFixed(1)} km',
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ModernTheme.primaryBlue.withValues(alpha: 0.1),
            ModernTheme.primaryBlue.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ModernTheme.primaryBlue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.security,
              color: ModernTheme.primaryBlue,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Código de Verificación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pide al pasajero su código de 4 dígitos para confirmar que eres su conductor',
                  style: TextStyle(
                    color: ModernTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInput() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final offset = _shakeAnimation.value * 10 * (_shakeAnimation.value < 0.5 ? 1 : -1);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                width: 60,
                height: 60,
                margin: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _currentIndex == index
                        ? ModernTheme.oasisGreen
                        : _errorMessage.isNotEmpty
                            ? Colors.red
                            : Colors.grey.shade300,
                    width: _currentIndex == index ? 2 : 1,
                  ),
                  boxShadow: _currentIndex == index
                      ? [
                          BoxShadow(
                            color: ModernTheme.oasisGreen.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : ModernTheme.cardShadow,
                ),
                child: Center(
                  child: Text(
                    _enteredCode[index],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _enteredCode[index].isNotEmpty
                          ? ModernTheme.textPrimary
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericKeypad() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Fila 1-3
          Row(
            children: [
              _buildKeypadButton('1'),
              _buildKeypadButton('2'),
              _buildKeypadButton('3'),
            ],
          ),
          SizedBox(height: 16),
          // Fila 4-6
          Row(
            children: [
              _buildKeypadButton('4'),
              _buildKeypadButton('5'),
              _buildKeypadButton('6'),
            ],
          ),
          SizedBox(height: 16),
          // Fila 7-9
          Row(
            children: [
              _buildKeypadButton('7'),
              _buildKeypadButton('8'),
              _buildKeypadButton('9'),
            ],
          ),
          SizedBox(height: 16),
          // Fila 0 y borrar
          Row(
            children: [
              Expanded(child: Container()), // Espacio vacío
              _buildKeypadButton('0'),
              _buildKeypadButton('⌫', isDelete: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String text, {bool isDelete = false}) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isDelete ? _deleteDigit : () => _addDigit(text),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: isDelete ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: isDelete ? Colors.grey.shade600 : ModernTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    final isCodeComplete = _enteredCode.every((digit) => digit.isNotEmpty);
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isCodeComplete && !_isVerifying ? _verifyCode : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: ModernTheme.oasisGreen,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isCodeComplete ? 4 : 0,
        ),
        child: _isVerifying
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Verificando...', style: TextStyle(fontSize: 16)),
                ],
              )
            : Text(
                'Verificar Código',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  void _addDigit(String digit) {
    if (_currentIndex < 4) {
      setState(() {
        _enteredCode[_currentIndex] = digit;
        _currentIndex++;
        _errorMessage = '';
      });
      
      // Vibración ligera
      HapticFeedback.lightImpact();
    }
  }

  void _deleteDigit() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _enteredCode[_currentIndex] = '';
        _errorMessage = '';
      });
      
      HapticFeedback.lightImpact();
    }
  }

  void _verifyCode() async {
    final enteredCodeString = _enteredCode.join('');
    final correctCode = widget.trip.verificationCode;
    
    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    // Simular verificación
    await Future.delayed(Duration(milliseconds: 1500));

    if (enteredCodeString == correctCode) {
      // Código correcto
      HapticFeedback.heavyImpact();
      
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }

      // Actualizar el trip con código verificado
      if (!mounted) return;
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      await rideProvider.verifyTripCode(widget.trip.id, enteredCodeString);

      if (!mounted) return;
      // Mostrar éxito y navegar
      _showSuccessDialog();
    } else {
      // Código incorrecto
      HapticFeedback.heavyImpact();
      _shakeController.forward().then((_) {
        _shakeController.reset();
      });
      
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Código incorrecto. Verifica con el pasajero.';
          _enteredCode = ['', '', '', ''];
          _currentIndex = 0;
        });
      }
    }
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 48,
                color: ModernTheme.success,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '¡Verificación Exitosa!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Puedes iniciar el viaje ahora',
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context, true); // Volver con resultado exitoso
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              foregroundColor: Colors.white,
            ),
            child: Text('Iniciar Viaje'),
          ),
        ],
      ),
    );
  }
}
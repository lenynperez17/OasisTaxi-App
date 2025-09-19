import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../utils/app_logger.dart';

/// Pantalla de Verificación de Teléfono con OTP Profesional
class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isRegistration;

  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.isRegistration = false,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      PhoneVerificationScreenState();
}

class PhoneVerificationScreenState extends State<PhoneVerificationScreen>
    with TickerProviderStateMixin {
  final _otpController = TextEditingController();
  StreamController<ErrorAnimationType>? _errorController;

  late AnimationController _animationController;
  late AnimationController _timerAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isLoading = false;
  bool _hasError = false;
  String _currentOTP = "";

  // Timer para reenvío
  Timer? _timer;
  int _resendTimer = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('PhoneVerificationScreen',
        'initState - Teléfono: ${widget.phoneNumber}');
    _errorController = StreamController<ErrorAnimationType>();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _timerAnimationController = AnimationController(
      duration: Duration(seconds: 60),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
    _startResendTimer();

    // Iniciar verificación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPhoneVerification();
    });
  }

  @override
  void dispose() {
    _errorController?.close();
    _otpController.dispose();
    _animationController.dispose();
    _timerAnimationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 60;
    _timer?.cancel();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _startPhoneVerification() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoading = true);

    final success =
        await authProvider.startPhoneVerification(widget.phoneNumber);

    if (!mounted) return;

    if (!success && authProvider.errorMessage != null) {
      _showError(authProvider.errorMessage!);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _verifyOTP() async {
    AppLogger.info(
        'Iniciando verificación OTP para teléfono: ${widget.phoneNumber}');

    if (_currentOTP.length != 6) {
      _errorController!.add(ErrorAnimationType.shake);
      _showError("Por favor ingresa el código completo de 6 dígitos");
      AppLogger.warning('OTP incompleto - longitud: ${_currentOTP.length}');
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyOTP(_currentOTP);

    if (!mounted) return;

    if (success) {
      AppLogger.info(
          'OTP verificado exitosamente para teléfono: ${widget.phoneNumber}');

      // Animación de éxito
      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text("Teléfono verificado exitosamente"),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Navegar según el contexto
      if (widget.isRegistration) {
        AppLogger.navigation('PhoneVerificationScreen', '/welcome');
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/welcome',
          (route) => false,
        );
      } else {
        AppLogger.navigation('PhoneVerificationScreen', '/passenger/home');
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/passenger/home',
          (route) => false,
        );
      }
    } else {
      AppLogger.warning(
          'Falló verificación OTP para teléfono: ${widget.phoneNumber}');
      _errorController!.add(ErrorAnimationType.shake);
      HapticFeedback.heavyImpact();

      setState(() {
        _hasError = true;
        _currentOTP = "";
      });

      _otpController.clear();

      _showError(
          authProvider.errorMessage ?? "Código inválido. Intenta de nuevo.");
    }

    setState(() => _isLoading = false);
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    AppLogger.info('Reenviando OTP para teléfono: ${widget.phoneNumber}');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoading = true);

    final success = await authProvider.resendOTP();

    if (!mounted) return;

    if (success) {
      AppLogger.info(
          'OTP reenviado exitosamente para teléfono: ${widget.phoneNumber}');
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Código reenviado a +51 ${widget.phoneNumber}"),
          backgroundColor: ModernTheme.oasisGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      _showError(authProvider.errorMessage ?? "Error al reenviar código");
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ModernTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: ModernTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icono animado
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.phone_android,
                          size: 60,
                          color: ModernTheme.oasisGreen,
                        ),
                        if (_isLoading)
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ModernTheme.oasisGreen,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Título
                  Text(
                    'Verificación de Teléfono',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtítulo
                  Text(
                    'Ingresa el código de 6 dígitos\nenviado al',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: ModernTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Número de teléfono
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+51 ${widget.phoneNumber}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ModernTheme.oasisGreen,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Campo OTP
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: PinCodeTextField(
                      appContext: context,
                      length: 6,
                      controller: _otpController,
                      animationType: AnimationType.scale,
                      animationDuration: Duration(milliseconds: 200),
                      enableActiveFill: true,
                      errorAnimationController: _errorController,
                      keyboardType: TextInputType.number,
                      hapticFeedbackTypes: HapticFeedbackTypes.selection,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(12),
                        fieldHeight: 55,
                        fieldWidth: 45,
                        activeFillColor: Colors.white,
                        inactiveFillColor: ModernTheme.backgroundLight,
                        selectedFillColor:
                            ModernTheme.oasisGreen.withValues(alpha: 0.1),
                        selectedColor: ModernTheme.oasisGreen,
                        errorBorderColor: ModernTheme.error,
                      ),
                      cursorColor: ModernTheme.oasisGreen,
                      textStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.textPrimary,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _currentOTP = value;
                          _hasError = false;
                        });
                      },
                      onCompleted: (value) {
                        _verifyOTP();
                      },
                    ),
                  ),

                  if (_hasError)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Código incorrecto. Intenta de nuevo.',
                        style: TextStyle(
                          color: ModernTheme.error,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Botón verificar
                  AnimatedPulseButton(
                    text: 'Verificar Código',
                    icon: Icons.check_circle,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _verifyOTP,
                  ),

                  const SizedBox(height: 24),

                  // Timer y reenviar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿No recibiste el código? ',
                        style: TextStyle(
                          color: ModernTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (!_canResend)
                        Text(
                          'Reenviar en ${_resendTimer}s',
                          style: TextStyle(
                            color: ModernTheme.oasisGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _isLoading ? null : _resendOTP,
                          child: Text(
                            'Reenviar ahora',
                            style: TextStyle(
                              color: ModernTheme.oasisGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Información de seguridad
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ModernTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ModernTheme.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: ModernTheme.info,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verificación Segura',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: ModernTheme.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Este código es único y caduca en 10 minutos. No lo compartas con nadie.',
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

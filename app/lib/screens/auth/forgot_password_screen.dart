import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../services/security_integration_service.dart';
import '../../utils/app_logger.dart';
import '../../config/oauth_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentStep = 0; // 0: phone, 1: code, 2: new password
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ForgotPasswordScreen', 'initState');

    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _sendVerificationCode() async {
    AppLogger.info(
        'Iniciando envío de código de recuperación de contraseña - Teléfono: ${_phoneController.text}');

    if (!ValidationPatterns.isValidPeruMobile(_phoneController.text)) {
      AppLogger.warning(
          'Teléfono inválido para recuperación - Teléfono: ${_phoneController.text}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ingrese un número de teléfono válido de 9 dígitos'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final phoneNumber = '+51${_phoneController.text}';

    try {
      AppLogger.api('POST', 'Firebase Auth - sendPasswordResetOTP');
      _verificationId = await authProvider.sendPasswordResetOTP(phoneNumber);

      if (_verificationId != null && mounted) {
        AppLogger.info(
            'Código de recuperación enviado exitosamente - Teléfono: $phoneNumber');
        setState(() {
          _isLoading = false;
          _currentStep = 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código de verificación enviado a $phoneNumber'),
            backgroundColor: ModernTheme.success,
            duration: Duration(seconds: 3),
          ),
        );

        _animationController.reset();
        _animationController.forward();
      } else {
        AppLogger.warning(
            'Falló envío de código de recuperación - Teléfono: $phoneNumber');
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al enviar código. Intente nuevamente.'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error(
          'Error crítico al enviar código de recuperación - Teléfono: $phoneNumber',
          e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _verifyCode() async {
    AppLogger.info(
        'Iniciando verificación de código OTP para recuperación - Código longitud: ${_codeController.text.length}');

    if (_codeController.text.isEmpty || _codeController.text.length != 6) {
      AppLogger.warning(
          'Código OTP inválido para recuperación - Longitud: ${_codeController.text.length}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ingrese el código de 6 dígitos'),
          backgroundColor: ModernTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      AppLogger.api('POST', 'Firebase Auth - verifyPasswordResetOTP');
      final success = await authProvider.verifyPasswordResetOTP(
        _verificationId!,
        _codeController.text,
      );

      if (success && mounted) {
        AppLogger.info(
            'Código OTP verificado exitosamente para recuperación - Teléfono: +51${_phoneController.text}');
        setState(() {
          _isLoading = false;
          _currentStep = 2;
        });

        _animationController.reset();
        _animationController.forward();
      } else {
        AppLogger.warning(
            'Código OTP incorrecto para recuperación - Teléfono: +51${_phoneController.text}');
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Código incorrecto. Verifique e intente nuevamente.'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error(
          'Error crítico al verificar código OTP para recuperación - Teléfono: +51${_phoneController.text}',
          e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar código: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      AppLogger.info(
          'Iniciando actualización de contraseña - Teléfono: +51${_phoneController.text}');
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        AppLogger.api('POST', 'Firebase Auth - updatePassword');
        final success =
            await authProvider.updatePassword(_newPasswordController.text);

        if (mounted) {
          setState(() => _isLoading = false);
        }

        if (success && mounted) {
          AppLogger.info(
              'Contraseña actualizada exitosamente - Teléfono: +51${_phoneController.text}');
          AppLogger.navigation('ForgotPasswordScreen', '/login');
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
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
                      size: 60,
                      color: ModernTheme.success,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '¡Contraseña Actualizada!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu contraseña ha sido actualizada exitosamente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.oasisGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Ir al Login'),
                ),
              ],
            ),
          );
        } else {
          AppLogger.warning(
              'Falló actualización de contraseña - Teléfono: +51${_phoneController.text}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Error al actualizar contraseña. Intente nuevamente.'),
                backgroundColor: ModernTheme.error,
              ),
            );
          }
        }
      } catch (e) {
        AppLogger.error(
            'Error crítico al actualizar contraseña - Teléfono: +51${_phoneController.text}',
            e);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    } else {
      AppLogger.warning(
          'Validación de formulario falló para actualización de contraseña');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ModernTheme.oasisGreen,
              ModernTheme.oasisGreen.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Recuperar Contraseña',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Progress indicator
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildStepIndicator(0, 'Teléfono'),
                    _buildStepConnector(0),
                    _buildStepIndicator(1, 'Verificar'),
                    _buildStepConnector(1),
                    _buildStepIndicator(2, 'Nueva'),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildCurrentStepContent(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCompleted = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? ModernTheme.oasisGreen : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color:
                            isActive ? Colors.white : ModernTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color:
                  isActive ? ModernTheme.oasisGreen : ModernTheme.textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isActive = _currentStep > step;

    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.only(bottom: 28),
        color: isActive ? ModernTheme.oasisGreen : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPhoneStep();
      case 1:
        return _buildCodeStep();
      case 2:
        return _buildPasswordStep();
      default:
        return _buildPhoneStep();
    }
  }

  Widget _buildPhoneStep() {
    return Column(
      children: [
        // Logo
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: EdgeInsets.all(15),
          child: Image.asset(
            'assets/images/logo_oasis_taxi.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 30),

        Text(
          'Ingresa tu número de teléfono',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Te enviaremos un código de verificación por SMS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ModernTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 30),

        // Phone input
        SecurityIntegrationService.buildSecureTextField(
          context: context,
          controller: _phoneController,
          label: 'Número de teléfono',
          fieldType: 'phone',
          prefixIcon: Icon(Icons.phone, color: ModernTheme.oasisGreen),
        ),
        const SizedBox(height: 30),

        // Send button
        AnimatedPulseButton(
          text: 'Enviar Código',
          icon: Icons.send,
          onPressed: _isLoading ? () {} : _sendVerificationCode,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      children: [
        Icon(
          Icons.sms,
          size: 80,
          color: ModernTheme.oasisGreen,
        ),
        const SizedBox(height: 30),

        Text(
          'Verificación por SMS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ingresa el código de 6 dígitos enviado a\n+51 ${_phoneController.text}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ModernTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 30),

        // Code input
        SecurityIntegrationService.buildSecureTextField(
          context: context,
          controller: _codeController,
          label: '',
          fieldType: 'otpcode',
          hintText: '000000',
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        const SizedBox(height: 20),

        // Resend button
        TextButton(
          onPressed: _sendVerificationCode,
          child: Text(
            'Reenviar código',
            style: TextStyle(color: ModernTheme.primaryBlue),
          ),
        ),
        const SizedBox(height: 20),

        // Verify button
        AnimatedPulseButton(
          text: 'Verificar',
          icon: Icons.check,
          onPressed: _isLoading ? () {} : _verifyCode,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Icon(
            Icons.lock_reset,
            size: 80,
            color: ModernTheme.oasisGreen,
          ),
          const SizedBox(height: 30),

          Text(
            'Crear Nueva Contraseña',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ingresa tu nueva contraseña segura',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 30),

          // New password
          SecurityIntegrationService.buildSecureTextField(
            context: context,
            controller: _newPasswordController,
            label: 'Nueva contraseña',
            fieldType: 'password',
            obscureText: _obscureNewPassword,
            prefixIcon: Icon(Icons.lock, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                color: ModernTheme.textSecondary,
              ),
              onPressed: () {
                setState(() => _obscureNewPassword = !_obscureNewPassword);
              },
            ),
          ),
          const SizedBox(height: 20),

          // Confirm password
          SecurityIntegrationService.buildSecureTextField(
            context: context,
            controller: _confirmPasswordController,
            label: 'Confirmar contraseña',
            fieldType: 'password',
            obscureText: _obscureConfirmPassword,
            prefixIcon: Icon(Icons.lock_outline, color: ModernTheme.oasisGreen),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: ModernTheme.textSecondary,
              ),
              onPressed: () {
                setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword);
              },
            ),
          ),
          const SizedBox(height: 30),

          // Reset button
          AnimatedPulseButton(
            text: 'Actualizar Contraseña',
            icon: Icons.check_circle,
            onPressed: _isLoading ? () {} : _resetPassword,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}

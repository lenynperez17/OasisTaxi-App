import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:email_validator/email_validator.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/mixins/rate_limiter_mixin.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../config/oauth_config.dart'; // Para validación estricta
import 'phone_verification_screen.dart';
import '../../services/security_integration_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/validation_patterns.dart' as ValidationUtils;
import '../../widgets/auth/auth_components.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  ModernLoginScreenState createState() => ModernLoginScreenState();
}

class ModernLoginScreenState extends State<ModernLoginScreen>
    with TickerProviderStateMixin, RateLimiterMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _backgroundController;
  late AnimationController _formController;
  late AnimationController _logoController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _formAnimation;
  late Animation<double> _logoAnimation;
  late Animation<double> _floatAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _userType = 'passenger';
  bool _usePhoneLogin = true; // Toggle entre teléfono y email
  // int _failedAttempts = 0; // Para futuras funcionalidades de seguridad
  // DateTime? _lastFailedAttempt; // Para futuras funcionalidades de seguridad

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernLoginScreen', 'initState');

    _backgroundController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _formController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _backgroundAnimation = CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.linear,
    );

    _formAnimation = CurvedAnimation(
      parent: _formController,
      curve: Curves.elasticOut,
    );

    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.bounceOut,
    );

    _floatAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    _formController.forward();
    _logoController.forward();
    _logoController.repeat(reverse: true);
  }


  @override
  void dispose() {
    _backgroundController.dispose();
    _formController.dispose();
    _logoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      // Obtener identificador único para rate limiting
      final identifier = _usePhoneLogin
          ? _phoneController.text.trim()
          : _emailController.text.trim().toLowerCase();

      AppLogger.info(
          'Intento de login - Método: ${_usePhoneLogin ? "teléfono" : "email"}, Usuario: $_userType');

      // Verificar rate limiting
      if (!checkRateLimit(identifier)) {
        final message = getRateLimitMessage(identifier);
        _showErrorMessage(message);
        HapticFeedback.heavyImpact();
        return;
      }

      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        bool success = false;

        if (_usePhoneLogin) {
          // Login con teléfono - VALIDACIÓN ESTRICTA OBLIGATORIA
          final phone = _phoneController.text.trim();

          // VALIDACIÓN CENTRALIZADA: Usar solo ValidationPatterns
          if (!ValidationUtils.ValidationPatterns.isValidPeruMobile(phone)) {
            _showErrorMessage(ValidationUtils.ValidationPatterns.getPhoneError());
            setState(() => _isLoading = false);
            return;
          }

          // Navegar a pantalla de verificación OTP
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhoneVerificationScreen(
                phoneNumber: phone,
                isRegistration: false,
              ),
            ),
          );
          setState(() => _isLoading = false);
          return;
        } else {
          // Login con email
          final email = _emailController.text.trim();

          // Validar email profesional
          if (!EmailValidator.validate(email)) {
            _showErrorMessage('Email inválido');
            setState(() => _isLoading = false);
            return;
          }

          success = await authProvider.login(email, _passwordController.text);
        }

        if (!mounted) return;

        if (success) {
          // Registrar intento exitoso en rate limiter
          onSuccessfulAttempt(identifier);

          // Reset intentos fallidos (legacy - comentado para limpieza)
          // _failedAttempts = 0;
          // _lastFailedAttempt = null;

          // Vibración de éxito
          HapticFeedback.mediumImpact();

          // Verificar si el email está verificado
          if (!authProvider.emailVerified && !_usePhoneLogin) {
            _showErrorMessage(
              'Por favor verifica tu email antes de continuar. Revisa tu bandeja de entrada.',
            );
            setState(() => _isLoading = false);
            return;
          }

          // Navegar según el tipo de usuario
          AppLogger.info('Login exitoso para usuario tipo: $_userType');
          if (_userType == 'passenger') {
            AppLogger.navigation('ModernLoginScreen', '/passenger/home');
            Navigator.pushReplacementNamed(context, '/passenger/home');
          } else if (_userType == 'driver') {
            AppLogger.navigation('ModernLoginScreen', '/driver/home');
            Navigator.pushReplacementNamed(context, '/driver/home');
          } else if (_userType == 'admin') {
            AppLogger.navigation('ModernLoginScreen', '/admin/dashboard');
            Navigator.pushReplacementNamed(context, '/admin/dashboard');
          }
        } else {
          // Registrar intento fallido en rate limiter
          onFailedAttempt(identifier);

          // Incrementar intentos fallidos (legacy)
          // _failedAttempts++; // Para futuras funcionalidades de seguridad
          // _lastFailedAttempt = DateTime.now(); // Para futuras funcionalidades de seguridad

          // Vibración de error
          HapticFeedback.heavyImpact();

          // Mostrar mensaje de error específico
          final errorMsg =
              authProvider.errorMessage ?? 'Error al iniciar sesión';
          AppLogger.warning(
              'Login fallido para usuario tipo $_userType: $errorMsg');
          _showErrorMessage(errorMsg);

          // Si la cuenta está bloqueada
          if (authProvider.isAccountLocked) {
            _showErrorMessage(
              'Tu cuenta ha sido bloqueada temporalmente por seguridad. '
              'Intenta de nuevo más tarde o contacta soporte.',
            );
          }
        }
      } catch (e) {
        if (!mounted) return;
        _showErrorMessage('Error inesperado: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showErrorMessage(String message) {
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

  Future<void> _loginWithGoogle() async {
    AppLogger.info('Intento de login con Google');

    // VERIFICACIÓN DE CONFIGURACIÓN OAUTH
    if (!OAuthConfig.isGoogleConfigured) {
      AppLogger.error('Google Sign-In no configurado');
      _showErrorMessage('Google Sign-In no configurado.\n'
          'Contacta al administrador del sistema.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      setState(() => _isLoading = true);
      HapticFeedback.selectionClick();

      final success = await authProvider.signInWithGoogle();

      if (!mounted) return;

      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.pushReplacementNamed(context, '/passenger/home');
      } else {
        _showErrorMessage(authProvider.errorMessage ??
            'Error al iniciar sesión con Google. Intenta nuevamente.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Error con Google Sign-In: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithFacebook() async {
    // VERIFICACIÓN DE CONFIGURACIÓN OAUTH
    if (!OAuthConfig.isFacebookConfigured) {
      _showErrorMessage('Facebook Login no configurado.\n'
          'Contacta al administrador del sistema.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      setState(() => _isLoading = true);
      HapticFeedback.selectionClick();

      final success = await authProvider.signInWithFacebook();

      if (!mounted) return;

      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.pushReplacementNamed(context, '/passenger/home');
      } else {
        _showErrorMessage(authProvider.errorMessage ??
            'Error al iniciar sesión con Facebook. Intenta nuevamente.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Error al iniciar sesión con Facebook: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithApple() async {
    // VERIFICACIÓN DE CONFIGURACIÓN OAUTH
    if (!OAuthConfig.isAppleConfigured) {
      _showErrorMessage('Apple Sign-In no configurado.\n'
          'Contacta al administrador del sistema.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      setState(() => _isLoading = true);
      HapticFeedback.selectionClick();

      final success = await authProvider.signInWithApple();

      if (!mounted) return;

      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.pushReplacementNamed(context, '/passenger/home');
      } else {
        _showErrorMessage(authProvider.errorMessage ??
            'Error al iniciar sesión con Apple. Intenta nuevamente.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Error al iniciar sesión con Apple: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Autenticación biométrica avanzada
  Future<void> _loginWithBiometrics() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Verificar que hay un usuario previamente autenticado
      if (authProvider.currentUser == null) {
        _showErrorMessage(
            'Primero debes iniciar sesión con otro método para habilitar autenticación biométrica');
        setState(() => _isLoading = false);
        return;
      }

      HapticFeedback.selectionClick();

      // Intentar autenticación biométrica
      final success = await authProvider.authenticateWithBiometrics(
          reason: 'Verifica tu identidad para acceder a OasisTaxi');

      if (!mounted) return;

      if (success) {
        HapticFeedback.lightImpact();

        // Verificación de seguridad adicional
        final securityCheck = await authProvider.performSecurityCheck();
        if (!mounted) return;

        if (!securityCheck) {
          _showErrorMessage(
              'Verificación de seguridad fallida. Intenta con otro método.');
          setState(() => _isLoading = false);
          return;
        }

        // Login exitoso con biometría - navegación según tipo de usuario
        if (authProvider.currentUser?.userType == 'admin') {
          Navigator.of(context).pushReplacementNamed('/admin/dashboard');
        } else if (authProvider.currentUser?.userType == 'driver') {
          Navigator.of(context).pushReplacementNamed('/driver/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/passenger/home');
        }
      } else {
        _showErrorMessage(
            authProvider.errorMessage ?? 'Error en autenticación biométrica');
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Error en autenticación biométrica: $e');
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo animado con gradiente
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ModernTheme.oasisGreen,
                      ModernTheme.oasisBlack,
                      ModernTheme.accentGray,
                    ],
                    transform: GradientRotation(
                        _backgroundAnimation.value * 2 * math.pi),
                  ),
                ),
              );
            },
          ),

          // Burbujas flotantes animadas
          ...List.generate(5, (index) {
            return AnimatedBuilder(
              animation: _backgroundAnimation,
              builder: (context, child) {
                final size = 50.0 + (index * 30);
                final speed = 1 + (index * 0.2);
                return Positioned(
                  left: MediaQuery.of(context).size.width *
                      math.sin((_backgroundAnimation.value * speed + index) *
                          2 *
                          math.pi),
                  top: MediaQuery.of(context).size.height *
                      ((_backgroundAnimation.value * speed + index) % 1),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                );
              },
            );
          }),

          // Contenido principal
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(ModernTheme.getResponsivePadding(context)),
                child: Column(
                  children: [
                    SizedBox(height: ModernTheme.getResponsiveSpacing(context) * 1.5),

                    // Logo animado con AuthComponents
                    AnimatedBuilder(
                      animation: _floatAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0,
                              math.sin(_floatAnimation.value * math.pi) * 10),
                          child: ScaleTransition(
                            scale: _logoAnimation,
                            child: AuthComponents.buildLogo(
                              context: context,
                              size: ModernTheme.isMobile(context) ? 80.0 : (ModernTheme.isTablet(context) ? 100.0 : 120.0),
                            ),
                          ),
                        );
                      },
                    ),

                    AuthComponents.buildSpacer(context: context, multiplier: 0.8),

                    // Header con título y subtítulo
                    AuthComponents.buildAuthHeader(
                      context: context,
                      title: 'OASIS TAXI',
                      subtitle: 'Tu viaje, tu precio',
                    ),

                    AuthComponents.buildSpacer(context: context, multiplier: 1.5),

                    // Formulario con animación
                    AnimatedBuilder(
                      animation: _formAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _formAnimation.value,
                          child: Container(
                            padding: EdgeInsets.all(ModernTheme.getResponsivePadding(context)),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: ModernTheme.floatingShadow,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Selector de tipo de usuario
                                  Container(
                                    decoration: BoxDecoration(
                                      color: ModernTheme.backgroundLight,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(() =>
                                                    _userType = 'passenger'),
                                                child: AnimatedContainer(
                                                  duration: Duration(
                                                      milliseconds: 300),
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 16),
                                                  decoration: BoxDecoration(
                                                    color: _userType ==
                                                            'passenger'
                                                        ? ModernTheme.oasisGreen
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.person,
                                                        color: _userType ==
                                                                'passenger'
                                                            ? Colors.white
                                                            : ModernTheme
                                                                .textSecondary,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Pasajero',
                                                        style: TextStyle(
                                                          color: _userType ==
                                                                  'passenger'
                                                              ? Colors.white
                                                              : ModernTheme
                                                                  .textSecondary,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(
                                                    () => _userType = 'driver'),
                                                child: AnimatedContainer(
                                                  duration: Duration(
                                                      milliseconds: 300),
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 16),
                                                  decoration: BoxDecoration(
                                                    color: _userType == 'driver'
                                                        ? ModernTheme.oasisGreen
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.directions_car,
                                                        color: _userType ==
                                                                'driver'
                                                            ? Colors.white
                                                            : ModernTheme
                                                                .textSecondary,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Conductor',
                                                        style: TextStyle(
                                                          color: _userType ==
                                                                  'driver'
                                                              ? Colors.white
                                                              : ModernTheme
                                                                  .textSecondary,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Opción de Administrador
                                        GestureDetector(
                                          onTap: () => setState(
                                              () => _userType = 'admin'),
                                          child: AnimatedContainer(
                                            duration:
                                                Duration(milliseconds: 300),
                                            margin: EdgeInsets.only(top: 8),
                                            padding: EdgeInsets.symmetric(
                                                vertical: 16),
                                            decoration: BoxDecoration(
                                              color: _userType == 'admin'
                                                  ? ModernTheme.oasisGreen
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.admin_panel_settings,
                                                  color: _userType == 'admin'
                                                      ? Colors.white
                                                      : ModernTheme
                                                          .textSecondary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Administrador',
                                                  style: TextStyle(
                                                    color: _userType == 'admin'
                                                        ? Colors.white
                                                        : ModernTheme
                                                            .textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: ModernTheme.getResponsiveSpacing(context) * 0.8),

                                  // Toggle entre teléfono y email
                                  Container(
                                    decoration: BoxDecoration(
                                      color: ModernTheme.backgroundLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(
                                                () => _usePhoneLogin = true),
                                            child: AnimatedContainer(
                                              duration:
                                                  Duration(milliseconds: 200),
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _usePhoneLogin
                                                    ? ModernTheme.oasisGreen
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.phone_android,
                                                    color: _usePhoneLogin
                                                        ? Colors.white
                                                        : ModernTheme
                                                            .textSecondary,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Teléfono',
                                                    style: TextStyle(
                                                      color: _usePhoneLogin
                                                          ? Colors.white
                                                          : ModernTheme
                                                              .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(
                                                () => _usePhoneLogin = false),
                                            child: AnimatedContainer(
                                              duration:
                                                  Duration(milliseconds: 200),
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12),
                                              decoration: BoxDecoration(
                                                color: !_usePhoneLogin
                                                    ? ModernTheme.oasisGreen
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.email,
                                                    color: !_usePhoneLogin
                                                        ? Colors.white
                                                        : ModernTheme
                                                            .textSecondary,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Email',
                                                    style: TextStyle(
                                                      color: !_usePhoneLogin
                                                          ? Colors.white
                                                          : ModernTheme
                                                              .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: ModernTheme.getResponsiveSpacing(context)),

                                  // Campo de teléfono o email según selección
                                  if (_usePhoneLogin)
                                    AuthComponents.buildTextField(
                                      context: context,
                                      controller: _phoneController,
                                      label: 'Número de teléfono',
                                      fieldType: 'phone',
                                      hintText: '999 999 999',
                                      prefixIcon: Icon(Icons.phone,
                                          color: ModernTheme.primaryOrange),
                                    )
                                  else
                                    AuthComponents.buildTextField(
                                      context: context,
                                      controller: _emailController,
                                      label: 'Email',
                                      fieldType: 'email',
                                      hintText: 'correo@ejemplo.com',
                                      prefixIcon: Icon(Icons.email,
                                          color: ModernTheme.primaryOrange),
                                    ),

                                  const SizedBox(height: 16),

                                  // Campo de contraseña (solo para login con email)
                                  if (!_usePhoneLogin)
                                    AuthComponents.buildTextField(
                                      context: context,
                                      controller: _passwordController,
                                      label: 'Contraseña',
                                      fieldType: 'password',
                                      hintText: 'Mínimo 8 caracteres, al menos 1 letra y 1 número',
                                      obscureText: _obscurePassword,
                                      prefixIcon: Icon(Icons.lock,
                                          color: ModernTheme.primaryOrange),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: ModernTheme.textSecondary,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),

                                  const SizedBox(height: 12),

                                  // Olvidé mi contraseña
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                            context, '/forgot-password');
                                      },
                                      child: Text(
                                        '¿Olvidaste tu contraseña?',
                                        style: TextStyle(
                                          color: ModernTheme.oasisBlack,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: ModernTheme.getResponsiveSpacing(context)),

                                  // Botón de inicio de sesión
                                  AuthComponents.buildPrimaryButton(
                                    context: context,
                                    text: 'Iniciar Sesión',
                                    icon: Icons.arrow_forward,
                                    isLoading: _isLoading,
                                    onPressed: _login,
                                  ),

                                  SizedBox(height: ModernTheme.getResponsiveSpacing(context) * 0.8),

                                  // Divider con texto usando AuthComponents
                                  AuthComponents.buildDivider(
                                    context: context,
                                    text: 'O continúa con',
                                  ),

                                  SizedBox(height: ModernTheme.getResponsiveSpacing(context) * 0.8),

                                  // Botones de redes sociales
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildSocialButton(
                                        icon: Icons.g_mobiledata,
                                        color: Color(0xFFDB4437),
                                        onPressed: _loginWithGoogle,
                                      ),
                                      _buildSocialButton(
                                        icon: Icons.facebook,
                                        color: Color(0xFF1877F2),
                                        onPressed: _loginWithFacebook,
                                      ),
                                      _buildSocialButton(
                                        icon: Icons.apple,
                                        color: Colors.black,
                                        onPressed: _loginWithApple,
                                      ),
                                      _buildSocialButton(
                                        icon: Icons.fingerprint,
                                        color: const Color(0xFF4CAF50),
                                        onPressed: _loginWithBiometrics,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: ModernTheme.getResponsiveSpacing(context)),

                    // Registro usando AuthComponents
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '¿No tienes cuenta? ',
                          style: TextStyle(color: Colors.white),
                        ),
                        AuthComponents.buildTextLink(
                          context: context,
                          text: 'Regístrate',
                          color: Colors.white,
                          onTap: () {
                            Navigator.pushNamed(context, '/register');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
